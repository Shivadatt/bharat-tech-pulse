<#
.SYNOPSIS
  Publish Bharat Tech Pulse to Cloudflare Pages from the operator's machine.

.DESCRIPTION
  Plan / gate / publish helper for the Cloudflare Pages hosting target.

  Default behaviour is DRY RUN: it validates the environment, inspects the
  existing build\web bundle, prints the exact Cloudflare Pages settings the
  deployment expects, prints the wrangler command line it WOULD run, and then
  exits WITHOUT touching the network and WITHOUT starting a build.

  Nothing is built and nothing is uploaded until you pass -Execute.

  Guards, in order:
    1. CLOUDFLARE_API_TOKEN and CLOUDFLARE_ACCOUNT_ID must be present in the
       environment, otherwise the script refuses immediately (exit 1). A project
       name is also required (-ProjectName or CLOUDFLARE_PAGES_PROJECT). The
       token value is never printed, never written to a file and never passed as
       a command-line argument - wrangler reads it from the environment.
    2. The bundle must be production-shaped: build\web\index.html plus
       _redirects and _headers (copied out of web\ by `flutter build web`), and
       main.dart.js must be Supabase-backed. A bundle that still contains the
       placeholder project URL, or that lost the Supabase table names to
       tree-shaking, is refused. Deploying that artifact would serve fabricated
       editorial content from the production hostname.
    2b. Release integrity (see the section itself): web\ must equal build\web\
        byte-for-byte for every copied file; build\web\index.html may differ from
        web\index.html only by the base-href substitution; exactly ONE Supabase
        project ref may appear anywhere in the tree (and it must be
        -ExpectedProjectRef when pinned); no non-live sentinel may be present;
        article shells must equal the sitemap set and the seed's published-post
        count; no source/SQL/key/source-map file may sit in the upload tree; and
        _headers is structurally audited for the Cloudflare comma-join trap and
        the 100-rule / 2,000-character ceilings.
    3. On -Execute for the PRODUCTION branch, an explicit
        -ConfirmRelease bharat-tech-pulse-production plus -ExpectedProjectRef is
        required (exit 5) before anything is built or uploaded.
    4. With -Execute, tool\build_production.ps1 runs first (it has its own
       credential + tree-shaking guards), then `wrangler pages deploy` publishes
       build\web. A bundle that fails gate 2/2b is refused even with -SkipBuild.

  Exit codes: 1 credential gate, 3 bundle/release-integrity gate, 4 no publisher
  available, 5 missing production acknowledgement, build script exit code is
  propagated. A dry run reports the bundle gate and exits 0 either way - read the
  "Bundle gate status" line, do not rely on the exit code.

  Why wrangler instead of a git-integrated Pages build: a Flutter Web bundle
  needs SUPABASE_URL / SUPABASE_ANON_KEY at COMPILE time via --dart-define, and
  this repo's FVM/`subst` Windows build (see tool\build_production.ps1) cannot be
  reproduced inside the Pages build image. Feeding those values into Pages build
  environment variables would also put them in build logs. So the artifact is
  built here and uploaded.

.EXAMPLE
  # 1. See the plan, the expected Pages settings and any gate failures:
  powershell -NoProfile -ExecutionPolicy Bypass -File tool\deploy_cloudflare.ps1 -ProjectName bharat-tech-pulse

.EXAMPLE
  # 2. Actually build and publish to the production branch (the only path that
  #    uploads, and the one the owner has NOT authorised this round):
  $env:CLOUDFLARE_API_TOKEN = '<api token>'      # paste, never store in a file
  $env:CLOUDFLARE_ACCOUNT_ID = '<account id>'
  ... tool\deploy_cloudflare.ps1 -ProjectName bharat-tech-pulse -ExpectedProjectRef <project-ref> -ConfirmRelease bharat-tech-pulse-production -Execute

.EXAMPLE
  # 3. Publish the already-verified bundle to a preview branch (no build, no
  #    production acknowledgement needed - gate 2b still has to pass):
  ... tool\deploy_cloudflare.ps1 -ProjectName bharat-tech-pulse -SkipBuild -Branch preview-remediation -Execute

.EXAMPLE
  # 4. Read-only rehearsal against the bundle already on disk:
  ... tool\deploy_cloudflare.ps1 -ProjectName bharat-tech-pulse -ExpectedProjectRef <project-ref>
  # prints every gate result and exits 0 WITHOUT -Execute; nothing is uploaded.

.NOTES
  Windows PowerShell 5.1 compatible (this machine has no pwsh on PATH - verified).
  Does NOT deploy anything when run without -Execute. No DNS, domain, TLS or
  dashboard setting is changed by this script; those are manual owner steps
  documented in docs\DEPLOYMENT.md.
#>
[CmdletBinding()]
param(
  [string]$ProjectName = '',
  [string]$Branch = '',
  [string]$ProductionBranch = 'main',
  [string]$SiteName = '',
  [switch]$Execute,
  [switch]$SkipBuild,
  [string]$WranglerCommand = '',
  [string]$ExpectedProjectRef = '',
  [string]$ConfirmRelease = '',
  [int]$ExpectedFileCount = 0
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$buildScript = Join-Path $repoRoot 'tool\build_production.ps1'
$webOut = Join-Path $repoRoot 'build\web'
$indexHtml = Join-Path $webOut 'index.html'
$entryJs = Join-Path $webOut 'main.dart.js'
$redirectsFile = Join-Path $webOut '_redirects'
$headersFile = Join-Path $webOut '_headers'
$sitemapFile = Join-Path $webOut 'sitemap.xml'
# Files web\ holds for the crawler and the brand. `flutter build web` merges into
# build\web instead of wiping it, so a stale directory can ship without them while
# every other marker still looks correct (observed 2026-10-13).
$publicFiles = @(
  'robots.txt',
  'sitemap.xml',
  'og-default.jpg',
  'favicon.png',
  'manifest.json'
)

function Write-Section([string]$text) {
  Write-Host ''
  Write-Host ('-' * 78)
  Write-Host $text
  Write-Host ('-' * 78)
}

# Presence only - a credential value is never echoed, only its length.
function Describe-Secret([string]$name) {
  $value = [Environment]::GetEnvironmentVariable($name)
  if ([string]::IsNullOrWhiteSpace($value)) {
    return $null
  }
  return [pscustomobject]@{
    Name = $name
    Length = $value.Length
    LooksLikeSupabaseSecret = ($value.StartsWith('eyJ') -and $value.Contains('service_role'))
  }
}

# sha256 of a file, lowercase hex, or the literal <missing>. Used to prove that
# build\web really was produced from the CURRENT web\ tree (flutter copies web\
# verbatim, so any byte of divergence means the bundle predates an edit).
function Get-Sha256Hex([string]$path) {
  if (-not (Test-Path -LiteralPath $path)) { return '<missing>' }
  $sha = [System.Security.Cryptography.SHA256]::Create()
  try {
    $bytes = [System.IO.File]::ReadAllBytes($path)
    $hex = ([System.BitConverter]::ToString($sha.ComputeHash($bytes))).Replace('-', '')
    return $hex.ToLowerInvariant()
  } finally {
    $sha.Dispose()
  }
}

function Get-ShortHash([string]$hash) {
  if ($hash.Length -le 16) { return $hash }
  return $hash.Substring(0, 16)
}

$modeSummary = 'DRY RUN (no build, no upload, no network calls)'
if ($Execute) { $modeSummary = 'EXECUTE (will build and upload)' }

Write-Host '== Bharat Tech Pulse :: Cloudflare Pages deploy helper =='
Write-Host "repo root   : $repoRoot"
Write-Host ('mode        : {0}' -f $modeSummary)
if ($Execute) {
  Write-Host 'WARNING       : -Execute is set. This publishes to Cloudflare Pages.'
}

# ---------------------------------------------------------------------------
# Gate 1 - credentials and project identity. Refuse before doing any work.
# ---------------------------------------------------------------------------
$token = Describe-Secret 'CLOUDFLARE_API_TOKEN'
$account = Describe-Secret 'CLOUDFLARE_ACCOUNT_ID'
$projectEnv = Describe-Secret 'CLOUDFLARE_PAGES_PROJECT'

$resolvedProject = $ProjectName
if ([string]::IsNullOrWhiteSpace($resolvedProject)) {
  $envProject = [Environment]::GetEnvironmentVariable('CLOUDFLARE_PAGES_PROJECT')
  if (-not [string]::IsNullOrWhiteSpace($envProject)) {
    $resolvedProject = $envProject.Trim()
  } else {
    $resolvedProject = ''
  }
}

Write-Section '1. Cloudflare credentials (presence only, values never printed)'
# Pre-computed summaries: no nested quoting inside a double-quoted string, so the
# file stays parseable on Windows PowerShell 5.1.
$tokenSummary = '<missing>'
if ($null -ne $token) { $tokenSummary = 'present (length ' + $token.Length + ')' }
$accountSummary = '<missing>'
if ($null -ne $account) { $accountSummary = 'present (length ' + $account.Length + ')' }
$projectEnvSummary = '<missing>'
if ($null -ne $projectEnv) { $projectEnvSummary = 'present' }
$projectSummary = '<missing>'
if (-not [string]::IsNullOrWhiteSpace($resolvedProject)) { $projectSummary = $resolvedProject }

Write-Host ('CLOUDFLARE_API_TOKEN    : {0}' -f $tokenSummary)
Write-Host ('CLOUDFLARE_ACCOUNT_ID   : {0}' -f $accountSummary)
Write-Host ('CLOUDFLARE_PAGES_PROJECT: {0}' -f $projectEnvSummary)
Write-Host ('pages project name      : {0}' -f $projectSummary)

$blockers = @()
if ($null -ne $token -and $token.LooksLikeSupabaseSecret) {
  $blockers += 'CLOUDFLARE_API_TOKEN starts with eyJ and contains service_role - that looks like a Supabase secret key, not a Cloudflare token. Refusing.'
}
if ($null -eq $token) {
  $blockers += 'CLOUDFLARE_API_TOKEN is not set in the environment. Create a Pages:Edit scoped API token in the Cloudflare dashboard (My Account -> API Tokens) and paste it into the shell; never commit it and never put it in a Pages build environment variable.'
}
if ($null -eq $account) {
  $blockers += 'CLOUDFLARE_ACCOUNT_ID is not set in the environment. It is the 32-char id shown in the dashboard right-hand URL bar.'
}
if ([string]::IsNullOrWhiteSpace($resolvedProject)) {
  $blockers += 'No Cloudflare Pages project name. Pass -ProjectName <slug> or set CLOUDFLARE_PAGES_PROJECT.'
}

if ($blockers.Count -gt 0) {
  Write-Host ''
  Write-Host 'REFUSING TO RUN - credential gate:'
  foreach ($b in $blockers) { Write-Host "  - $b" }
  Write-Host ''
  Write-Host 'Nothing was built and nothing was uploaded. Fix the environment and re-run.'
  Write-Host '(Run without -Execute first: the dry run still stops here, by design.)'
  exit 1
}

# ---------------------------------------------------------------------------
# Gate 2 - bundle inspection (read-only).
# ---------------------------------------------------------------------------
Write-Section '2. Deployable bundle (build\web)'
$bundleProblems = @()
$bundleNotes = @()

foreach ($required in @($indexHtml, $redirectsFile, $headersFile, $entryJs)) {
  if (-not (Test-Path -LiteralPath $required)) {
    $bundleProblems += "missing required deployable file: $required"
  }
}

foreach ($name in $publicFiles) {
  $path = Join-Path $webOut $name
  if (-not (Test-Path -LiteralPath $path)) {
    $bundleProblems += "build\web is missing $name - the bundle is stale or partial; rebuild through tool\build_production.ps1 (it clears build\web first)"
  }
}

$entryBytes = 0
if (Test-Path -LiteralPath $entryJs) {
  $entryBytes = (Get-Item -LiteralPath $entryJs).Length
  $entryText = Get-Content -Raw -LiteralPath $entryJs
  $mockHits = ([regex]::Matches($entryText, 'placeholder-project')).Count
  $postHits = ([regex]::Matches($entryText, 'post_revisions')).Count
  $analyticsHits = ([regex]::Matches($entryText, 'analytics_events')).Count
  Write-Host ("main.dart.js      : {0} bytes" -f $entryBytes)
  Write-Host ("  placeholder-project : {0}" -f $mockHits)
  Write-Host ("  post_revisions      : {0}" -f $postHits)
  Write-Host ("  analytics_events    : {0}" -f $analyticsHits)
  if ($mockHits -gt 0) {
    $bundleProblems += 'the bundle still contains the mock placeholder project URL (ENV/DATA_SOURCE defaults) - this is a MOCK build and must never be published'
  }
  if ($postHits -lt 1 -or $analyticsHits -lt 1) {
    $bundleProblems += 'Supabase table names are absent from the bundle, so the Supabase repositories were tree-shaken out - this is not a live-backed build'
  }
  # A syntactically valid project ref is NOT a live project ref: the pipeline is
  # tested against https://zzz-not-live.supabase.co with an sb_publishable_FAKE_*
  # key, and that bundle passes every marker above. Refuse it here, where a real
  # upload would otherwise happen.
  $nonLiveHits = ([regex]::Matches($entryText, 'zzz-not-live|FAKE_NOT_LIVE|CHANGEME|REPLACE_ME|DUMMY|XXXXXXXX')).Count
  Write-Host ("  non-live sentinels  : {0}" -f $nonLiveHits)
  if ($nonLiveHits -gt 0) {
    $bundleProblems += "main.dart.js carries $nonLiveHits non-live sentinel hit(s), so it was built against a fake project (zzz-not-live / FAKE_NOT_LIVE). This is a pipeline-test artifact and must never be published."
  }
  if ($mockHits -eq 0 -and $postHits -gt 0 -and $analyticsHits -gt 0 -and $nonLiveHits -eq 0) {
    $bundleNotes += 'bundle looks Supabase-backed (markers present, placeholder absent, no non-live sentinels)'
  }
} else {
  Write-Host 'main.dart.js      : <missing>'
}

# tool\build_production.ps1 stamps this file whenever it builds with a non-live
# config. It sits in build\, deliberately OUTSIDE the build\web upload tree, so
# the refusal survives re-minification or sentinel rotation without ever
# publishing a marker file.
$nonLiveMarker = Join-Path $repoRoot 'build\.btp-non-live-bundle'
if (Test-Path -LiteralPath $nonLiveMarker) {
  $stampReasons = @(Get-Content -LiteralPath $nonLiveMarker | Where-Object { $_ -match '\S' })
  $bundleProblems += ('build\web is stamped NON-LIVE by tool\build_production.ps1: ' + ($stampReasons -join '; '))
}

if (Test-Path -LiteralPath $redirectsFile) {
  $rCount = @(Get-Content -LiteralPath $redirectsFile | Where-Object { $_ -match '^\s*[^#\s]' }).Count
  Write-Host ('_redirects        : present, {0} routing rule(s) (SPA fallback + 8 trailing-slash 301s)' -f $rCount)
  if ($rCount -lt 1) { $bundleProblems += 'web\_redirects has no rules - deep links would 404' }
  if ($rCount -lt 2) { $bundleProblems += 'web\_redirects has no SPA fallback rule (/* /index.html 200)' }
} else {
  Write-Host '_redirects        : <missing - build\web predates the web\_redirects fix, rebuild before deploying>'
}

if (Test-Path -LiteralPath $headersFile) {
  $hCount = @(Get-Content -LiteralPath $headersFile | Where-Object { $_ -match '^/[^\s]*' }).Count
  Write-Host ('_headers          : present, {0} header rule block(s)' -f $hCount)
  if ($hCount -lt 1) { $bundleProblems += 'web\_headers has no rule blocks - cache policy would fall back to platform defaults' }
} else {
  Write-Host '_headers          : <missing - build\web predates the web\_headers fix, rebuild before deploying>'
}

$presentPublic = @($publicFiles | Where-Object { Test-Path -LiteralPath (Join-Path $webOut $_) })
Write-Host ('public files      : {0}/{1} present ({2})' -f $presentPublic.Count, $publicFiles.Count, ($presentPublic -join ', '))

$shellText = ''
if (Test-Path -LiteralPath $indexHtml) {
  $shellText = Get-Content -Raw -LiteralPath $indexHtml
  if ($shellText -match '\$FLUTTER_BASE_HREF') {
    $bundleNotes += 'index.html still carries the literal $FLUTTER_BASE_HREF placeholder; with a root-based deploy Flutter substitutes "/" at build time, so confirm the deployed <base href> is "/" (docs\DEPLOYMENT.md section 7)'
  }
}

# Prerendered crawler-visible shells. tool\build_production.ps1 runs
# tool\generate_prerender.dart after the build and fails if it produced none, so an
# upload without them means the bundle predates that step.
$articleShellDir = Join-Path $webOut 'article'
$shellCount = @(Get-ChildItem -Path $articleShellDir -Directory -ErrorAction SilentlyContinue).Count
Write-Host ('article shells    : {0} under build\web\article' -f $shellCount)
if ($shellCount -lt 1) {
  $bundleProblems += 'the bundle has no prerendered article shells, so a crawler that does not run JavaScript gets the generic home <head> on every /article/<slug> deep link'
}

# ---------------------------------------------------------------------------
# Gate 2b - release-integrity gates. Every one of these is read-only and each
# catches a concrete way an artifact that passes the marker checks above is
# still the WRONG bytes to publish.
# ---------------------------------------------------------------------------
Write-Section '2b. Release integrity (source vs bundle, refs, headers, hygiene)'

$expectedRef = $ExpectedProjectRef.Trim().ToLowerInvariant()
$releasePhrase = 'bharat-tech-pulse-production'
if ($expectedRef -ne '') {
  Write-Host ('pinned ref       : {0}' -f $expectedRef)
} else {
  Write-Host 'pinned ref       : <not pinned - pass -ExpectedProjectRef to make the target project a hard gate>'
}

# (i) web\ must equal build\web\ for the files flutter copies verbatim. A
#     mismatch means build\web is from an earlier round: the one failure mode
#     `flutter build web` cannot report, because it MERGES rather than wipes.
$mirrorNames = @('_headers', '_redirects', 'robots.txt', 'sitemap.xml', 'og-default.jpg', 'favicon.png', 'manifest.json')
foreach ($name in $mirrorNames) {
  $srcPath = Join-Path $repoRoot ('web\' + $name)
  $bldPath = Join-Path $webOut $name
  $hs = Get-Sha256Hex $srcPath
  $hb = Get-Sha256Hex $bldPath
  if (($hs -ne '<missing>') -and ($hs -eq $hb)) {
    Write-Host ('  {0,-18} == web\  sha256 {1}' -f $name, (Get-ShortHash $hs))
  } else {
    $shortSrc = Get-ShortHash $hs
    $shortBld = Get-ShortHash $hb
    $bundleProblems += ('build\web\' + $name + ' does not match web\' + $name + ' (web=' + $shortSrc + ' bundle=' + $shortBld + ') - STALE OR FOREIGN BUNDLE, rebuild')
  }
}

# (ii) build\web\index.html may differ from web\index.html ONLY by the
#      $FLUTTER_BASE_HREF substitution. Anything else means the shipped shell is
#      not the reviewed shell (extra/removed meta, duplicated canonical, an
#      injected tag) - and the shell is what every crawler reads first.
$srcIndex = Join-Path $repoRoot 'web\index.html'
$baseSrc = '<base href="$FLUTTER_BASE_HREF">'
$baseDst = '<base href="/">'
if ((Test-Path -LiteralPath $srcIndex) -and (Test-Path -LiteralPath $indexHtml)) {
  $srcLines = @(Get-Content -LiteralPath $srcIndex)
  $bldLines = @(Get-Content -LiteralPath $indexHtml)
  $indexDiffs = @()
  if ($srcLines.Count -ne $bldLines.Count) {
    $indexDiffs += ('line count web=' + $srcLines.Count + ' bundle=' + $bldLines.Count)
  } else {
    for ($i = 0; $i -lt $srcLines.Count; $i++) {
      if ($srcLines[$i] -cne $bldLines[$i]) {
        $normalised = $srcLines[$i].Replace($baseSrc, $baseDst)
        if ($normalised -cne $bldLines[$i]) { $indexDiffs += ('line ' + ($i + 1)) }
      }
    }
  }
  if ($indexDiffs.Count -gt 0) {
    $bundleProblems += ('build\web\index.html differs from web\index.html beyond the base-href substitution at: ' + ($indexDiffs -join ', '))
  } else {
    Write-Host '  index.html         : differs from web\ only by <base href> (expected)'
  }
}

# (iii) One Supabase project, the pinned one. The prerendered shells take their
#       image hosts from supabase\migrations\006_seed_data.sql while main.dart.js
#       takes its host from --dart-define, so a bundle can legitimately contain
#       TWO different refs - and then every og:image 404s in production while all
#       marker checks pass (observed on the 2026-10-13 test bundle).
$refScan = @()
if (Test-Path -LiteralPath $entryJs) { $refScan += (Get-Item -LiteralPath $entryJs) }
$bootFile = Join-Path $webOut 'flutter_bootstrap.js'
if (Test-Path -LiteralPath $bootFile) { $refScan += (Get-Item -LiteralPath $bootFile) }
$refScan += @(Get-ChildItem -LiteralPath $webOut -Recurse -File -Filter 'index.html')
$refsSeen = @()
$fakeHits = @()
$fakePatterns = @('zzz-not-live', 'FAKE_NOT_LIVE', 'G-FAKE0000', 'fake-verification-token', 'CHANGEME', 'REPLACE_ME', 'DUMMY')
foreach ($f in $refScan) {
  $t = Get-Content -Raw -LiteralPath $f.FullName
  if ([string]::IsNullOrEmpty($t)) { continue }
  foreach ($m in [regex]::Matches($t, 'https://[a-z0-9][a-z0-9-]*\.supabase\.(co|in)')) {
    $bare = ($m.Value -replace '^https://', '') -replace '\.supabase\.(co|in)$', ''
    $refsSeen += $bare
  }
  foreach ($pat in $fakePatterns) {
    $c = ([regex]::Matches($t, [regex]::Escape($pat))).Count
    if ($c -gt 0) { $fakeHits += ($f.Name + ' contains ' + $pat + ' x' + $c) }
  }
}
$refsSeen = @($refsSeen | Sort-Object -Unique)
Write-Host ('  supabase refs      : {0}' -f ($refsSeen -join ', '))
if ($refsSeen.Count -eq 0) {
  $bundleProblems += 'no Supabase project host appears anywhere in build\web - the artifact is not wired to a project'
}
if ($refsSeen.Count -gt 1) {
  $joinedRefs = ($refsSeen -join ', ')
  $bundleProblems += ('build\web references ' + $refsSeen.Count + ' different Supabase projects (' + $joinedRefs + '). main.dart.js and the prerendered shells disagree, so seeded image URLs point at a project the app never talks to.')
}
if ($expectedRef -ne '') {
  if ($refsSeen -notcontains $expectedRef) {
    $bundleProblems += ('build\web does not reference the pinned project ref (' + $expectedRef + ')')
  }
  foreach ($r in $refsSeen) {
    if ($r -ne $expectedRef) { $bundleProblems += ('build\web references an unexpected Supabase project: ' + $r) }
  }
}
if ($fakeHits.Count -gt 0) {
  foreach ($h in $fakeHits) { Write-Host ('  FAKE MARKER        : ' + $h) }
  $bundleProblems += ('the bundle carries ' + $fakeHits.Count + ' recognisable non-live marker(s), so it is a pipeline-test artifact and must never be published')
}

# (iv) Prerender coverage: shells == sitemap promises == published posts in the
#      seed. Three independent sources of truth; a count-only "> 0" check passes
#      when a retracted post leaves a stale shell and a new post has none.
$shellSlugs = @()
if (Test-Path -LiteralPath $articleShellDir) {
  $shellSlugs = @(Get-ChildItem -LiteralPath $articleShellDir -Directory | ForEach-Object { $_.Name } | Sort-Object -Unique)
}
if (Test-Path -LiteralPath $sitemapFile) {
  $sitemapText = Get-Content -Raw -LiteralPath $sitemapFile
  $sitemapSlugs = @(([regex]::Matches($sitemapText, '/article/([a-z0-9-]+)') |
      ForEach-Object { $_.Groups[1].Value }) | Sort-Object -Unique)
  $orphanShells = @($shellSlugs | Where-Object { $sitemapSlugs -notcontains $_ })
  $missingShells = @($sitemapSlugs | Where-Object { $shellSlugs -notcontains $_ })
  Write-Host ('  shells / sitemap   : {0} shells, {1} sitemap article URLs' -f $shellSlugs.Count, $sitemapSlugs.Count)
  if ($sitemapSlugs.Count -lt 1) {
    $bundleProblems += 'build\web\sitemap.xml advertises zero article URLs'
  }
  if ($orphanShells.Count -gt 0) {
    $bundleProblems += ('prerendered shells with no sitemap entry (stale content): ' + ($orphanShells -join ', '))
  }
  if ($missingShells.Count -gt 0) {
    $bundleProblems += ('sitemap advertises articles with no prerendered shell: ' + ($missingShells -join ', '))
  }
}
$seedSql = Join-Path $repoRoot 'supabase\migrations\006_seed_data.sql'
if (Test-Path -LiteralPath $seedSql) {
  $seedText = Get-Content -Raw -LiteralPath $seedSql
  $postsAt = $seedText.IndexOf('INSERT INTO public.posts')
  $seedPublished = -1
  if ($postsAt -ge 0) {
    $nextInsert = $seedText.IndexOf('INSERT INTO ', ($postsAt + 10))
    $regionLen = $seedText.Length - $postsAt
    if ($nextInsert -gt $postsAt) { $regionLen = $nextInsert - $postsAt }
    $region = $seedText.Substring($postsAt, $regionLen)
    $seedPublished = @(([regex]::Matches($region, "(?m)^ ?'published', "))).Count
  }
  if ($seedPublished -lt 1) {
    $bundleProblems += 'the published-post count could not be read from supabase\migrations\006_seed_data.sql - the seed format changed and tool\generate_prerender.dart must be re-checked before publishing'
  } else {
    Write-Host ('  seed published     : {0}' -f $seedPublished)
    if ($seedPublished -ne $shellSlugs.Count) {
      $bundleProblems += ('article shell count ({0}) does not equal the published-post count in the seed ({1}) - prerender ran against different editorial data' -f $shellSlugs.Count, $seedPublished)
    }
  }
} else {
  Write-Host '  seed published     : <seed file not found - skipped>'
}

# (v) Nothing that must never be public may sit in the upload tree.
$bundleFiles = @(Get-ChildItem -LiteralPath $webOut -Recurse -File -ErrorAction SilentlyContinue)
# Never-public file shapes. Note canvaskit\*.js.symbols IS legitimate Flutter
# engine output and is deliberately NOT matched here - only app symbol maps and
# dart2js source maps, which expose the Dart source of this app.
$forbiddenPatterns = @('\.sql$', '\.dart$', '\.env$', '^\.env', '\.pem$', '\.key$', '\.keystore$', '\.p12$',
  '\.jks$', '^app\..*\.symbols$', '\.map$', '\.map\.json$', '\.part\.js$', '^\.btp-')
$leaks = @()
foreach ($f in $bundleFiles) {
  foreach ($pat in $forbiddenPatterns) {
    if ($f.Name -match $pat) { $leaks += ($f.Name + ' -> ' + $pat) }
  }
}
if ($ExpectedFileCount -gt 0 -and $bundleFiles.Count -ne $ExpectedFileCount) {
  $bundleProblems += ('build\web holds {0} files but this release was pinned to {1} - the artifact tree differs from the reviewed one' -f $bundleFiles.Count, $ExpectedFileCount)
}
$totalBytes = 0
foreach ($f in $bundleFiles) { $totalBytes = $totalBytes + $f.Length }
Write-Host ('  upload tree        : {0} files, {1} bytes' -f $bundleFiles.Count, $totalBytes)
if ($leaks.Count -gt 0) {
  foreach ($l in $leaks) { Write-Host ('  LEAK               : ' + $l) }
  $bundleProblems += ('the upload tree contains ' + $leaks.Count + ' file(s) that must never be published (source, SQL, keys, symbols or map files)')
}

# (vi) _headers structural audit - the comma-join trap and the platform ceilings.
if (Test-Path -LiteralPath $headersFile) {
  $hLines = @(Get-Content -LiteralPath $headersFile)
  $blocks = @()
  $cur = $null
  foreach ($ln in $hLines) {
    if ($ln -match '^\s*#' -or $ln -match '^\s*$') { continue }
    if ($ln -match '^(/[^\s]*)$') {
      if ($null -ne $cur) { $blocks += ,$cur }
      $cur = [pscustomobject]@{ Path = $Matches[1]; Names = @() }
      continue
    }
    if (($null -ne $cur) -and ($ln -match '^\s+([A-Za-z0-9\-]+):')) {
      $cur.Names += $Matches[1]
    }
  }
  if ($null -ne $cur) { $blocks += ,$cur }
  Write-Host ('  _headers blocks    : {0} (documented ceiling 100)' -f $blocks.Count)
  if ($blocks.Count -gt 100) {
    $bundleProblems += ('_headers has {0} rule blocks, above the documented 100 ceiling - the surplus rules would be ignored' -f $blocks.Count)
  }
  $longLines = @($hLines | Where-Object { $_.Length -gt 2000 })
  if ($longLines.Count -gt 0) {
    $bundleProblems += ('_headers has {0} line(s) over the documented 2,000-character limit' -f $longLines.Count)
  }
  foreach ($b in $blocks) {
    foreach ($grp in ($b.Names | Group-Object)) {
      if ($grp.Count -gt 1) {
        $bundleProblems += ('_headers path {0} sets {1} {2} times - Cloudflare JOINS duplicate header values with commas, so the response carries "{3}, {3}"' -f $b.Path, $grp.Name, $grp.Count, $grp.Name)
      }
    }
  }
  $catchAll = @($blocks | Where-Object { $_.Path -eq '/*' })
  foreach ($b in $catchAll) {
    if ($b.Names -contains 'Cache-Control') {
      $bundleProblems += 'the /* block in _headers sets Cache-Control - it comma-joins with every asset rule below it, which is the documented reason /* must carry no Cache-Control'
    }
  }
  $cspEnforcing = @($hLines | Where-Object { $_ -match '^\s+Content-Security-Policy:' })
  $cspReport = @($hLines | Where-Object { $_ -match '^\s+Content-Security-Policy-Report-Only:' })
  if ($cspEnforcing.Count -gt 0) {
    $bundleNotes += ('_headers has an ENFORCING Content-Security-Policy on {0} line(s) while report-only is present on {1} - verify the promotion procedure in web\_headers before publishing (a wrong directive white-screens Flutter Web)' -f $cspEnforcing.Count, $cspReport.Count)
  } else {
    Write-Host ('  CSP                : report-only only ({0} line(s))' -f $cspReport.Count)
  }
}

# Fingerprint: compare these against the build log to prove the uploaded bytes
# are the bytes that were verified.
$fpBundle = Get-ShortHash (Get-Sha256Hex $entryJs)
$fpIndex = Get-ShortHash (Get-Sha256Hex $indexHtml)
Write-Host ('  fingerprint        : main.dart.js ' + $fpBundle + ' / index.html ' + $fpIndex)

foreach ($n in $bundleNotes) { Write-Host "NOTE : $n" }
if ($bundleProblems.Count -gt 0) {
  foreach ($p in $bundleProblems) { Write-Host "PROBLEM: $p" }
}

# Refuse on -Execute whatever the build choice is: -SkipBuild means THIS bundle is
# the artifact being uploaded, so it must clear the same gate. The previous
# version of this script only refused when it was about to rebuild, which let
# `-SkipBuild -Execute` publish a bundle it had just labelled unusable.
if ($Execute -and $bundleProblems.Count -gt 0) {
  Write-Host ''
  Write-Host 'REFUSING TO PUBLISH: the bundle fails the production-shape / release-integrity gate.'
  Write-Host 'Rebuild through tool\build_production.ps1 (it re-checks the same markers).'
  exit 3
}

# ---------------------------------------------------------------------------
# Gate 3 - wrangler availability (checked, never installed by this script).
# ---------------------------------------------------------------------------
Write-Section '3. Publisher (wrangler)'
$resolvedWrangler = $WranglerCommand
$wranglerArgsPre = @()
if ([string]::IsNullOrWhiteSpace($resolvedWrangler)) {
  if (Get-Command 'wrangler' -ErrorAction SilentlyContinue) {
    $resolvedWrangler = 'wrangler'
  } elseif (Get-Command 'npx' -ErrorAction SilentlyContinue) {
    $resolvedWrangler = 'npx'
    $wranglerArgsPre = @('--yes', 'wrangler')
  } else {
    $resolvedWrangler = ''
  }
}
if ([string]::IsNullOrWhiteSpace($resolvedWrangler)) {
  Write-Host 'wrangler          : NOT AVAILABLE (neither `wrangler` nor `npx` is on PATH)'
  if ($Execute) {
    Write-Host 'REFUSING: install the wrangler CLI (npm i -g wrangler) or Node so npx can fetch it, then re-run.'
    exit 4
  }
} else {
  Write-Host ("wrangler          : {0} {1}" -f $resolvedWrangler, ($wranglerArgsPre -join ' '))
}

# ---------------------------------------------------------------------------
# 4. The exact Cloudflare Pages settings this deployment expects.
# ---------------------------------------------------------------------------
$gitSha = '<unknown>'
if (Get-Command 'git' -ErrorAction SilentlyContinue) {
  try {
    Push-Location $repoRoot
    $shaOut = (& git rev-parse --short HEAD) | Out-String
    if ($LASTEXITCODE -eq 0 -and $shaOut.Trim()) { $gitSha = $shaOut.Trim() }
  } catch {
    $gitSha = '<unknown>'
  } finally {
    Pop-Location
  }
}

$targetBranch = $Branch
$branchKind = 'preview'
if ([string]::IsNullOrWhiteSpace($targetBranch)) {
  $targetBranch = $ProductionBranch
}
if ($targetBranch -eq $ProductionBranch) { $branchKind = 'PRODUCTION' }
# Defined here because section 5 reports it and section 6b enforces it.
$isProductionPublish = ($branchKind -eq 'PRODUCTION')

$siteSummary = '<not supplied>'
if (-not [string]::IsNullOrWhiteSpace($SiteName)) { $siteSummary = $SiteName }

Write-Section '4. Required Cloudflare Pages project settings (dashboard, manual)'
Write-Host @"
Project name (Pages)     : $resolvedProject
Account id               : present (length $($account.Length)) - value not printed
Deployment mode          : Direct Upload via wrangler (NOT git-integrated)
Build system             : OFF / unused for this project. If git build is enabled,
                           Root directory = repository root and
                           Build command  = n/a (Cloudflare Pages has no Flutter or
                           fvm in its image; this repo's build also needs the local
                           subst-drive workaround - see tool\build_production.ps1).
Build output directory   : build/web   (this is the directory wrangler uploads)
Production branch        : $ProductionBranch  (GitHub default branch is 'main' - verified locally)
Custom domain / alias    : $siteSummary
Commit this upload       : $gitSha ($branchKind branch '$targetBranch')

Environment variables in the Pages dashboard:
  * DO NOT store secrets here. The token/account id must never become a Pages
    build environment variable, and no Cloudflare credential belongs in Pages at all.
  * SUPABASE_URL and SUPABASE_ANON_KEY are COMPILE-TIME inputs, not runtime ones:
    they enter the bundle only through --dart-define at build time
    (tool\build_production.ps1 reads them from the environment or the git-ignored
    tool\live_checks\.env). A Pages runtime environment variable would be inert for a
    static Flutter Web bundle and would still be public once compiled in.
  * The anon/publishable key is the only Supabase credential that may ever appear in
    a build. service_role / secret keys and the database password are forbidden; the
    build script already rejects them.
  * GA_MEASUREMENT_ID and GOOGLE_SITE_VERIFICATION are COMPILE-TIME defines too
    (lib/core/analytics/analytics_service.dart:23, lib/core/seo/seo_service.dart:15).
    tool\build_production.ps1 appends them only when the operator environment supplies
    them; with no id the GA4 tag never loads and no Google origin is contacted. They
    are not Pages runtime variables either, and a GA4 id is not a secret but still
    does not belong in a committed file.
  * After the site is live, rotate this token if it was ever pasted into a shared
    terminal, and prefer a Pages-only scoped token.
"@

Write-Section '5. Commands this helper runs under -Execute'
$planArgs = @()
if ($wranglerArgsPre.Count -gt 0) { $planArgs += $wranglerArgsPre }
$planArgs += @('pages', 'deploy', 'build/web', "--project-name=$resolvedProject", "--branch=$targetBranch", '--commit-dirty=true')
$buildPlan = 'powershell -NoProfile -ExecutionPolicy Bypass -File tool\build_production.ps1'
if ($expectedRef -ne '') { $buildPlan = $buildPlan + ' -ExpectedProjectRef ' + $expectedRef }
Write-Host ('  step 1 (build)   : {0}' -f $buildPlan)
Write-Host ("  step 2 (publish) : {0}" -f (($resolvedWrangler + ' ' + ($planArgs -join ' ')).Trim()))
Write-Host '  CLOUDFLARE_API_TOKEN / CLOUDFLARE_ACCOUNT_ID are inherited from the environment;'
Write-Host '  they are never passed as arguments and never written to disk by this script.'
if ($isProductionPublish) {
  $confirmPlan = '-ConfirmRelease ' + $releasePhrase
  if ($expectedRef -eq '') { $confirmPlan = $confirmPlan + ' -ExpectedProjectRef <project-ref>' }
  Write-Host ('  step 0 (gate)    : this PRODUCTION publish also needs ' + $confirmPlan)
}

# ---------------------------------------------------------------------------
# 6. Optional post-deploy verification hints (nothing is probed here).
# ---------------------------------------------------------------------------
Write-Section '6. After a deploy, verify by hand (see docs\DEPLOYMENT.md section 7)'
Write-Host '  Every line below is UNVERIFIED until it is run against a real URL.'
Write-Host '  curl -I  https://<deployment-url>/                 -> 200, text/html, Cache-Control: no-cache'
Write-Host '  curl -I  https://<deployment-url>/robots.txt        -> 200 text/plain. If this returns text/html,'
Write-Host '           the "/* /index.html 200" rewrite is beating the static asset and the whole bundle is'
Write-Host '           being shadowed - stop and remove the catch-all.'
Write-Host '  curl -I  https://<deployment-url>/sitemap.xml       -> 200 application/xml, NOT the index.html shell'
Write-Host '  curl -I  https://<deployment-url>/main.dart.js      -> 200 application/javascript, max-age=0, must-revalidate'
Write-Host '  curl -I  https://<deployment-url>/og-default.jpg    -> 200 image/jpeg (never immutable)'
Write-Host '  curl -I  https://<deployment-url>/favicon.ico       -> expect 200 text/html today (no .ico asset exists):'
Write-Host '           the SPA rewrite answers missing files with the shell. Soft-200 on asset paths is a real cost.'
Write-Host '  curl -I  https://<deployment-url>/article/<slug>    -> 200 + Content-Length ~= the shell file size'
Write-Host '  curl -I  https://<deployment-url>/article/<slug>/   -> compare the two: Pages may 301 the slashed form'
Write-Host '  curl -sS https://<deployment-url>/article/<slug> | grep -o "<title>.*</title>"  -> THAT article, not home'
Write-Host '  curl -I  https://<deployment-url>/ai                -> 301 Location: /ai/'
Write-Host '  curl -I  https://<deployment-url>/ai/               -> 200 text/html no-cache (category shell)'
Write-Host '  curl -I  https://<deployment-url>/admin             -> 200 + X-Robots-Tag: noindex once web\_headers adds it'
Write-Host '  curl -sI https://<deployment-url>/ | grep -i "^link:"  -> preconnect hints for www.gstatic.com once added'
Write-Host '  curl -I  https://www.gstatic.com/flutter-canvaskit/<engineRevision>/canvaskit.js -> the engine this'
Write-Host '           bundle actually loads (buildConfig has engineRevision and no useLocalCanvasKit), so'
Write-Host '           build/web/canvaskit/* is a fallback that is never requested over our own origin.'

# ---------------------------------------------------------------------------
# 7. Execution. Only reachable with -Execute.
# ---------------------------------------------------------------------------
if (-not $Execute) {
  Write-Section 'DRY RUN COMPLETE'
  Write-Host 'No build was started, no wrangler process was launched, no upload happened.'
  if ($bundleProblems.Count -gt 0) {
    Write-Host ("Bundle gate status: FAIL ({0} problem(s)) - a real deploy would be refused." -f $bundleProblems.Count)
    Write-Host 'Fix: run tool\build_production.ps1 with real Supabase credentials, then re-run this helper.'
    exit 0
  }
  Write-Host 'Bundle gate status: PASS'
  Write-Host 'Re-run with -Execute to build (unless -SkipBuild) and publish.'
  exit 0
}

# ---------------------------------------------------------------------------
# 6b. Production acknowledgement. A publish to the production branch is the one
# action here that the owner has not authorised, so it needs an explicit,
# copy-pasted phrase rather than the absence of a flag. Preview branches keep the
# old behaviour so test uploads stay cheap.
# ---------------------------------------------------------------------------
# $releasePhrase and $isProductionPublish are defined earlier (sections 2b and 4)
# so that section 5 can report the requirement before anyone tries to satisfy it.
if ($Execute -and $isProductionPublish) {
  $confirm = $ConfirmRelease.Trim().ToLowerInvariant()
  $refusals = @()
  if ($confirm -ne $releasePhrase) {
    $refusals += ('-ConfirmRelease is missing or wrong. Re-run with -ConfirmRelease {0}' -f $releasePhrase)
  }
  if ($expectedRef -eq '') {
    $refusals += '-ExpectedProjectRef is required for a production publish: name the Supabase project this release talks to. The org has more than one project and one of them already shows "Project is paused".'
  }
  if ($refusals.Count -gt 0) {
    Write-Section 'REFUSING: production acknowledgement gate'
    foreach ($r in $refusals) { Write-Host "  - $r" }
    Write-Host 'Nothing was built and nothing was uploaded.'
    Write-Host 'To publish to a NON-production branch instead, add -Branch <name>.'
    exit 5
  }
  Write-Section 'Production acknowledgement accepted'
  Write-Host ('  branch            : {0} (production for project "{1}")' -f $targetBranch, $resolvedProject)
  Write-Host ('  supabase project  : {0}' -f $expectedRef)
  Write-Host ('  confirmation      : accepted')
}

if ($SkipBuild) {
  Write-Section '7. Build skipped (-SkipBuild); publishing the bundle already on disk'
} else {
  Write-Section '7. Building through tool\build_production.ps1'
  if (-not (Test-Path -LiteralPath $buildScript)) {
    Write-Error "build script not found: $buildScript"
  }
  $shell = 'powershell.exe'
  if (-not (Get-Command $shell -ErrorAction SilentlyContinue)) { $shell = 'powershell' }
  $buildArgList = @()
  if ($expectedRef -ne '') { $buildArgList += @('-ExpectedProjectRef', $expectedRef) }
  if ($buildArgList.Count -gt 0) {
    & $shell -NoProfile -ExecutionPolicy Bypass -File $buildScript @buildArgList
  } else {
    & $shell -NoProfile -ExecutionPolicy Bypass -File $buildScript
  }
  $buildExit = $LASTEXITCODE
  if ($buildExit -ne 0) {
    Write-Host ''
    Write-Host "ABORT: build_production.ps1 exited with code $buildExit. Nothing was uploaded."
    exit $buildExit
  }
}

# Re-run the bundle gate after a fresh build so a changed artifact is re-checked.
if (-not (Test-Path -LiteralPath $indexHtml)) {
  Write-Error "index.html missing after build: $indexHtml"
}
foreach ($must in @($redirectsFile, $headersFile)) {
  if (-not (Test-Path -LiteralPath $must)) {
    Write-Error "deployable routing/header file missing after build: $must (web\ must contain _redirects and _headers)"
  }
}
foreach ($name in $publicFiles) {
  $path = Join-Path $webOut $name
  if (-not (Test-Path -LiteralPath $path)) {
    Write-Error "required public file missing after build: $path (it must exist in web\ before deploying)"
  }
}
$freshText = Get-Content -Raw -LiteralPath $entryJs
if (([regex]::Matches($freshText, 'placeholder-project')).Count -gt 0) {
  Write-Host 'ABORT: freshly built bundle still contains the mock placeholder project URL.'
  exit 3
}
# A freshly built artifact has to clear the SAME release-integrity gates as a
# pre-built one; the checks above ran against the bytes that existed before the
# build replaced them.
$freshNonLive = ([regex]::Matches($freshText, 'zzz-not-live|FAKE_NOT_LIVE|G-FAKE0000|fake-verification-token')).Count
if ($freshNonLive -gt 0) {
  Write-Host 'ABORT: the freshly built bundle still carries a non-live sentinel, so SUPABASE_URL / SUPABASE_ANON_KEY are test values.'
  exit 3
}
if (Test-Path -LiteralPath $nonLiveMarker) {
  Write-Host 'ABORT: build_production.ps1 stamped this build as NON-LIVE (build\.btp-non-live-bundle).'
  exit 3
}
$freshRefs = @(([regex]::Matches($freshText, 'https://[a-z0-9][a-z0-9-]*\.supabase\.(co|in)')) |
    ForEach-Object { (($_.Value -replace '^https://', '') -replace '\.supabase\.(co|in)$', '') } |
    Sort-Object -Unique)
if ($expectedRef -ne '') {
  foreach ($r in $freshRefs) {
    if ($r -ne $expectedRef) {
      Write-Host ('ABORT: the freshly built main.dart.js references project ' + $r + ' but this release is pinned to ' + $expectedRef + '.')
      exit 3
    }
  }
}
Write-Host ('  post-build refs    : {0}' -f ($freshRefs -join ', '))

if ([string]::IsNullOrWhiteSpace($resolvedWrangler)) {
  Write-Error 'No wrangler publisher available; cannot deploy.'
}

Push-Location $repoRoot
try {
  $deployArgs = @()
  if ($wranglerArgsPre.Count -gt 0) { $deployArgs += $wranglerArgsPre }
  $deployArgs += @('pages', 'deploy', 'build/web', "--project-name=$resolvedProject", "--branch=$targetBranch", '--commit-dirty=true')
  Write-Section '8. Publishing build\web'
  Write-Host ("running: {0} {1}" -f $resolvedWrangler, ($deployArgs -join ' '))
  & $resolvedWrangler @deployArgs
  $deployExit = $LASTEXITCODE
} finally {
  Pop-Location
}

if ($deployExit -ne 0) {
  Write-Host ''
  Write-Host "ABORT: wrangler pages deploy exited with code $deployExit."
  exit $deployExit
}

Write-Host ''
Write-Host 'Uploaded. wrangler prints the deployment URL above.'
Write-Host ('Branch "{0}" is treated as {1} for project "{2}".' -f $targetBranch, $branchKind, $resolvedProject)
Write-Host 'Then run the curl checks in section 6 against that URL, and finish the'
Write-Host 'manual owner steps in docs\DEPLOYMENT.md (custom domain, SSL mode, sitemap).'
