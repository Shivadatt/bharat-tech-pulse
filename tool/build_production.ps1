<#
.SYNOPSIS
  Production build for Bharat Tech Pulse: always builds a Supabase-backed
  Flutter Web bundle, never a mock one.

.DESCRIPTION
  Reads SUPABASE_URL and SUPABASE_ANON_KEY with the EXISTING repository
  convention (tool/live_checks/lib/config.js): real environment variables take
  priority, then the git-ignored tool/live_checks/.env file. No second loader
  is invented, and no credential value is ever printed to the console - only
  its presence and length.

  Only the PUBLISHABLE / anon key may be used here: a Flutter Web bundle is
  public by definition. A service_role key, a secret key, or a database
  password must NEVER be passed to this script.

  The build always passes --dart-define=ENV=production, which makes the app
  throw at startup instead of serving mock content when credentials are
  missing/placeholder or when Supabase fails to initialise
  (see lib/app/config/environment_config.dart).

.EXAMPLE
  powershell -NoProfile -ExecutionPolicy Bypass -File tool\build_production.ps1

.EXAMPLE
  powershell -NoProfile -ExecutionPolicy Bypass -File tool\build_production.ps1 -ExpectedProjectRef <project-ref>

.PARAMETER ExpectedProjectRef
  Optional. The Supabase project ref this release MUST target: the
  project-ref part of https://<project-ref>.supabase.co. Checked twice -
  before the build against SUPABASE_URL (a typo in .env fails before any
  compiler work) and after the build against every Supabase host that actually
  appears in build\web, which also catches a bundle whose prerendered shells
  point at a different project than main.dart.js does. A sibling project lives
  in the same free-plan org and one of them already shows "Project is paused",
  so a valid-looking URL is not the same thing as the intended URL.

.NOTES
  Windows quirks handled here: the FVM shim must be invoked as `fvm.bat`, and
  the repo path contains a space which breaks Windows native assets, so the
  build runs from a temporary `subst` drive letter.
#>
[CmdletBinding()]
param(
  [string]$ExpectedProjectRef = ''
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$configJs = Join-Path $repoRoot 'tool\live_checks\lib\config.js'

Write-Host '== Bharat Tech Pulse :: production web build =='
Write-Host "repo root       : $repoRoot"

foreach ($tool in @('node', 'fvm.bat')) {
  if (-not (Get-Command $tool -ErrorAction SilentlyContinue)) {
    Write-Error "$tool is not on PATH. Install it and re-run."
  }
}
if (-not (Test-Path $configJs)) {
  Write-Error "credential loader not found: $configJs"
}

# ---------------------------------------------------------------------------
# 1. Resolve credentials through the existing live_checks loader (env > .env).
#    The key is captured into a variable only; it is never displayed.
# ---------------------------------------------------------------------------
$loaderJs = @'
const cfg = require(process.env.BTP_CONFIG_JS).load({ required: false });
process.stdout.write(JSON.stringify({
  url: cfg.url || '',
  urlSource: cfg.urlSource || '',
  key: cfg.anonKey || '',
  keyLength: (cfg.anonKey || '').length,
  keySource: cfg.anonKeySource || '',
  gaId: cfg.gaMeasurementId || '',
  siteVerification: cfg.googleSiteVerification || ''
}));
'@

$env:BTP_CONFIG_JS = $configJs
try {
  $captured = (& node -e $loaderJs) | Out-String
} finally {
  Remove-Item Env:\BTP_CONFIG_JS -ErrorAction SilentlyContinue
}

$parsed = $captured | ConvertFrom-Json
$url = [string]$parsed.url
$anonKey = [string]$parsed.key
$keyLength = [int]$parsed.keyLength

Write-Host "SUPABASE_URL      : $(if ($url) { $url } else { '<missing>' })"
Write-Host "SUPABASE_ANON_KEY : $(if ($keyLength -gt 0) { "present (length $keyLength, source $($parsed.keySource))" } else { '<missing>' })"
$gaId = [string]$parsed.gaId
$siteVerification = [string]$parsed.siteVerification
Write-Host "GA_MEASUREMENT_ID : $(if ($gaId) { 'present' } else { '<absent: GA stays inert>' })"
Write-Host "GOOGLE_SITE_VERIF : $(if ($siteVerification) { 'present' } else { '<absent: Search Console meta slot stays empty>' })"

$problems = @()
if (-not $url) {
  $problems += 'SUPABASE_URL is not available.'
} else {
  if ($url -match 'placeholder') { $problems += 'SUPABASE_URL is still the placeholder default.' }
  if ($url -notmatch '^https://[^/]+\.supabase\.(co|in)$') {
    $problems += 'SUPABASE_URL must be an https://<project-ref>.supabase.co project URL.'
  }
}
if (-not $anonKey) {
  $problems += 'SUPABASE_ANON_KEY is not available.'
} else {
  if ($anonKey -match 'placeholder') { $problems += 'SUPABASE_ANON_KEY is still the placeholder default.' }
  if ($anonKey -match 'service_role') {
    $problems += 'SUPABASE_ANON_KEY looks like a service_role key - refusing to bundle it into a public client.'
  }
  # The legacy secret key is a JWT containing "service_role" (caught above); the
  # current format is an opaque sb_secret_ token that contains no such substring,
  # so it needs its own prefix check before it can reach a public bundle.
  if ($anonKey -match '^sb_secret_' -or $anonKey -match '^sb_admin') {
    $problems += 'SUPABASE_ANON_KEY carries a secret-key prefix (sb_secret_/sb_admin) - refusing to bundle it into a public client.'
  }
}

# --- Gate 1b: the ref inside SUPABASE_URL, pinned by the operator ------------
# Every Supabase host that ends up in the bundle is derived from this one value,
# so a wrong-but-valid ref compiles fine and then silently reads the wrong
# project at runtime. Pinned here because the org has more than one project and
# one of them is already paused.
$configuredRef = ''
if ($url -match '^https://([a-z0-9][a-z0-9-]*)\.supabase\.(co|in)$') {
  $configuredRef = $Matches[1].ToLowerInvariant()
}
$expectedRef = $ExpectedProjectRef.Trim().ToLowerInvariant()
if ($expectedRef -ne '') {
  Write-Host "expected ref      : $expectedRef (pinned by -ExpectedProjectRef)"
  if ($configuredRef -ne $expectedRef) {
    $problems += "SUPABASE_URL resolves to project ref '$configuredRef' but this release was pinned to '$expectedRef'."
  }
}

# --- Gate 1c: recognisable non-live sentinels (warn, never block) -------------
# A dummy config passes every marker check below, so a test bundle is
# indistinguishable from a release bundle unless it is labelled. The build only
# WARNS - toolchain testing against a fake host must stay possible - but
# deploy_cloudflare.ps1 refuses to publish anything carrying these sentinels.
$sentinels = @()
if ($url -match 'zzz-not-live') { $sentinels += 'SUPABASE_URL host is the non-live sentinel zzz-not-live' }
if ($anonKey -match 'FAKE|NOT_LIVE|CHANGEME|REPLACE_ME|DUMMY|XXXXXXXX') {
  $sentinels += 'SUPABASE_ANON_KEY contains a fake/placeholder sentinel token'
}
if ($gaId -match 'FAKE|XXXXXXXX') { $sentinels += 'GA_MEASUREMENT_ID is a fake/placeholder id, not a real GA4 stream' }
if ($siteVerification -match 'fake') { $sentinels += 'GOOGLE_SITE_VERIFICATION is the fake test token' }
if ($sentinels.Count -gt 0) {
  Write-Host ''
  Write-Host 'WARNING - NON-LIVE CONFIG DETECTED. This bundle is a pipeline test'
  Write-Host 'artifact and is NOT releasable; deploy_cloudflare.ps1 will refuse it:'
  foreach ($s in $sentinels) { Write-Host "  - $s" }
}

if ($problems.Count -gt 0) {
  Write-Host ''
  Write-Host 'REFUSING TO BUILD (a production bundle must never fall back to mock data):'
  foreach ($p in $problems) { Write-Host "  - $p" }
  Write-Host @'

Fix: put these two lines in the git-ignored tool/live_checks/.env file, or
export them in the shell before running this script:

  SUPABASE_URL=https://<project-ref>.supabase.co
  SUPABASE_ANON_KEY=<publishable/anon key>

Optional (both are public by design, never secrets):
  GA_MEASUREMENT_ID=G-XXXXXXXXXX
  GOOGLE_SITE_VERIFICATION=<search console token>

Only the PUBLISHABLE / anon key belongs here. Never a service_role key, a
secret key, or a database password.
'@
  exit 2
}

# ---------------------------------------------------------------------------
# 2. Build from a drive-mapped path (the space in the repo path breaks Windows
#    native assets) through the FVM shim.
# ---------------------------------------------------------------------------
$buildDir = $repoRoot
$substDrive = $null
if ($repoRoot -match ' ') {
  $taken = (& subst) | Out-String
  foreach ($letter in @('Z', 'Y', 'V', 'U', 'T')) {
    $candidate = "${letter}:"
    if (-not $taken.Contains($candidate)) {
      & subst $candidate $repoRoot | Out-Null
      if ($LASTEXITCODE -eq 0) {
        $substDrive = $candidate
        $buildDir = "$candidate\"
        break
      }
    }
  }
  if (-not $substDrive) { Write-Error 'No free drive letter for subst (Z/Y/V/U/T all mapped).' }
  Write-Host "build cwd       : $buildDir (subst of the repo root)"
}

# `flutter build web` merges into build\web, it does not wipe it. A directory
# left over from an earlier round therefore ships stale and new files together
# (verified 2026-10-13: a stale build\web had no robots.txt/sitemap.xml/
# og-default.jpg/favicon.png/manifest.json at all, while _redirects, article
# shells from an older prerender run, and a different index.html were present).
# Publishing such a mix passes every marker check, so clear it first.
$webOut = Join-Path $repoRoot 'build\web'
if (Test-Path -LiteralPath $webOut) {
  $resolved = (Resolve-Path -LiteralPath $webOut).Path
  if ($resolved -notmatch '[\\/]build[\\/]web$') {
    Write-Error "refusing to delete unexpected path: $resolved"
  }
  Remove-Item -LiteralPath $resolved -Recurse -Force
  Write-Host "cleaned         : $resolved"
}

$defines = @(
  '--dart-define=ENV=production',
  '--dart-define=DATA_SOURCE=supabase',
  "--dart-define=SUPABASE_URL=$url",
  "--dart-define=SUPABASE_ANON_KEY=$anonKey"
)
if ($gaId) { $defines += "--dart-define=GA_MEASUREMENT_ID=$gaId" }
if ($siteVerification) { $defines += "--dart-define=GOOGLE_SITE_VERIFICATION=$siteVerification" }

Push-Location $buildDir
try {
  Write-Host ''
  Write-Host 'command         : fvm flutter build web --release --dart-define=ENV=production \'
  Write-Host '                                 --dart-define=DATA_SOURCE=supabase \'
  Write-Host "                                 --dart-define=SUPABASE_URL=$url \"
  Write-Host "                                 --dart-define=SUPABASE_ANON_KEY=<redacted, length $keyLength>"
  & fvm.bat flutter build web --release @defines
  $buildExit = $LASTEXITCODE
} finally {
  Pop-Location
  if ($substDrive) { & subst $substDrive '/d' | Out-Null }
}

if ($buildExit -ne 0) { Write-Error "flutter build web failed with exit code $buildExit." }

# ---------------------------------------------------------------------------
# 3. Prerender crawler-visible shells. Must run AFTER the build (step 2 cleared
#    build\web and the build repopulates it), otherwise the shells are erased.
#    The full stdout is kept, not just its last line: step 5 parses the shell
#    counts it reports and cross-checks them against what landed on disk.
# ---------------------------------------------------------------------------
$prerender = Join-Path $repoRoot 'tool\generate_prerender.dart'
if (-not (Test-Path $prerender)) { Write-Error "prerenderer not found: $prerender" }
Push-Location $repoRoot
try {
  $prerenderOut = @(& fvm.bat dart run 'tool/generate_prerender.dart')
  $prerenderExit = $LASTEXITCODE
} finally {
  Pop-Location
}
if ($prerenderExit -ne 0) {
  Write-Error "prerender generation failed with exit code $prerenderExit."
}
if ($prerenderOut.Count -gt 0) {
  Write-Host ("prerender report : {0}" -f $prerenderOut[($prerenderOut.Count - 1)])
}
$shells = @(Get-ChildItem -LiteralPath (Join-Path $repoRoot 'build\web\article') -Directory -ErrorAction SilentlyContinue)
Write-Host "prerendered      : $($shells.Count) article shells under build\web\article"
if ($shells.Count -lt 1) { Write-Error 'No prerendered article shells were produced.' }

# ---------------------------------------------------------------------------
# 4. Prove the Supabase repositories survived tree-shaking.
# ---------------------------------------------------------------------------
$bundle = Join-Path $repoRoot 'build\web\main.dart.js'
if (-not (Test-Path $bundle)) { Write-Error "expected bundle not found: $bundle" }

$bundleText = Get-Content -Raw -LiteralPath $bundle
$markers = [ordered]@{
  'post_revisions'      = ([regex]::Matches($bundleText, 'post_revisions')).Count
  'analytics_events'    = ([regex]::Matches($bundleText, 'analytics_events')).Count
  'placeholder-project' = ([regex]::Matches($bundleText, 'placeholder-project')).Count
  'Aravind Sharma'      = ([regex]::Matches($bundleText, 'Aravind Sharma')).Count
}
Write-Host ''
Write-Host "bundle          : $bundle ($((Get-Item $bundle).Length) bytes)"
foreach ($k in $markers.Keys) { Write-Host ('  {0,-20} {1}' -f $k, $markers[$k]) }

if ($markers['post_revisions'] -lt 1 -or $markers['analytics_events'] -lt 1) {
  Write-Error 'Supabase repositories were tree-shaken out of the bundle - the build is NOT Supabase-backed.'
}
if ($markers['placeholder-project'] -gt 0) {
  Write-Error 'The bundle still contains the placeholder project URL - mock mode leaked into the build.'
}
$projectRef = $url -replace '^https://', '' -replace '\.supabase\.(co|in)$', ''
if (-not $bundleText.Contains($projectRef)) {
  Write-Error "The bundle does not contain the live project ref ($projectRef)."
}

# A dummy config passes every marker check above: a fake `zzz-not-live` ref is a
# syntactically valid project ref, so the pipeline test bundle is otherwise
# indistinguishable from a release bundle on disk. Stamp the sentinel list so
# tool\deploy_cloudflare.ps1 can refuse it deterministically instead of relying
# on a human remembering which host was fake.
# The stamp lives in build\, NOT in build\web\: build\web is the upload tree and
# a file published there is public. build\ itself is gitignored and never
# uploaded (git ls-files build -> 0 tracked files).
$nonLiveMarker = Join-Path $repoRoot 'build\.btp-non-live-bundle'
if ($sentinels.Count -gt 0) {
  $sentinels | Set-Content -LiteralPath $nonLiveMarker -Encoding ASCII
  Write-Host '  non-live stamp   : wrote build\.btp-non-live-bundle (deploy gate will refuse this bundle)'
  Write-Host '                     (outside the build\web upload tree on purpose)'
} elseif (Test-Path -LiteralPath $nonLiveMarker) {
  Remove-Item -LiteralPath $nonLiveMarker -Force
  Write-Host '  non-live stamp   : cleared (live config)'
}

# ---------------------------------------------------------------------------
# 5. Prerender coverage must equal what the bundle PROMISES, not merely be > 0.
#    build\web\sitemap.xml is the crawler-facing list of URLs that exist; every
#    <loc> for an article must have a shell on disk and every shell must be in
#    the sitemap. A count-only check passes when a retracted post leaves a stale
#    shell behind and a new post gets none, which is exactly the drift that
#    produces indexed 404-shaped pages. Categories are checked against the
#    trailing-slash 301 sources in build\web\_redirects for the same reason.
# ---------------------------------------------------------------------------
$sitemapPath = Join-Path $repoRoot 'build\web\sitemap.xml'
$redirectsPath = Join-Path $repoRoot 'build\web\_redirects'
$shellSlugs = @($shells | ForEach-Object { $_.Name } | Sort-Object -Unique)

if (Test-Path -LiteralPath $sitemapPath) {
  $sitemapText = Get-Content -Raw -LiteralPath $sitemapPath
  $sitemapSlugs = @(([regex]::Matches($sitemapText, '/article/([a-z0-9-]+)') |
      ForEach-Object { $_.Groups[1].Value }) | Sort-Object -Unique)
  Write-Host ''
  Write-Host ("sitemap articles : {0}" -f $sitemapSlugs.Count)
  Write-Host ("shell articles   : {0}" -f $shellSlugs.Count)
  if ($sitemapSlugs.Count -lt 1) {
    Write-Error 'build\web\sitemap.xml advertises no article URLs - the copied sitemap is stale or empty.'
  }
  $onlyInSitemap = @($sitemapSlugs | Where-Object { $shellSlugs -notcontains $_ })
  $onlyInShells = @($shellSlugs | Where-Object { $sitemapSlugs -notcontains $_ })
  if ($onlyInSitemap.Count -gt 0) {
    Write-Error ("sitemap advertises articles with no prerendered shell: {0}" -f ($onlyInSitemap -join ', '))
  }
  if ($onlyInShells.Count -gt 0) {
    Write-Error ("prerendered shells exist for slugs absent from the sitemap: {0}" -f ($onlyInShells -join ', '))
  }
  Write-Host 'shell/sitemap    : sets match exactly'
} else {
  Write-Error "build\web\sitemap.xml is missing - the bundle is stale (build_production clears build\web)."
}

$categoryDirs = @(Get-ChildItem -LiteralPath (Join-Path $repoRoot 'build\web') -Directory |
    ForEach-Object { $_.Name })
$missingCats = @()
if (Test-Path -LiteralPath $redirectsPath) {
  $redirectText = Get-Content -Raw -LiteralPath $redirectsPath
  $slashTargets = @(([regex]::Matches($redirectText, '(?m)^/([a-z0-9-]+)\s+/([a-z0-9-]+)/\s+301\s*$') |
      ForEach-Object { $_.Groups[2].Value }) | Sort-Object -Unique)
  Write-Host ("category shells  : {0} declared by _redirects 301 rules" -f $slashTargets.Count)
  foreach ($c in $slashTargets) {
    if ($categoryDirs -notcontains $c) { $missingCats += $c }
  }
  if ($missingCats.Count -gt 0) {
    Write-Error ("_redirects 301s point at category paths with no prerendered shell: {0}" -f ($missingCats -join ', '))
  }
  # The catch-all must be the LAST rule: Pages applies the top-most matching
  # redirect, so a '/*' above a specific rule would shadow it.
  $ruleLines = @($redirectText -split "`n" | Where-Object { $_ -match '^\s*[^#\s]' })
  if ($ruleLines.Count -lt 1) { Write-Error 'build\web\_redirects has no rules.' }
  $lastRule = ($ruleLines[($ruleLines.Count - 1)]).Trim()
  if ($lastRule -notmatch '^/\*[ ]+/index\.html[ ]+200$') {
    Write-Error "the SPA fallback '/* /index.html 200' is not the last rule in _redirects (found: $lastRule)."
  }
  Write-Host ("redirect rules   : {0}, SPA fallback is last" -f $ruleLines.Count)
} else {
  Write-Error "build\web\_redirects is missing - the bundle is stale (build_production clears build\web)."
}

foreach ($line in $prerenderOut) {
  if ($line -match 'WARNING|MISS') { Write-Host "  prerender flagged: $line" }
}

# ---------------------------------------------------------------------------
# 6. Single-project consistency: every Supabase host anywhere in the tree must
#    be the configured project. tool\generate_prerender.dart takes the image
#    hosts from supabase\migrations\006_seed_data.sql, which hard-codes the seed
#    project ref, while main.dart.js takes its host from --dart-define. Those two
#    can disagree, and when they do the article og:image URLs 404 in production
#    even though every marker check passes.
# ---------------------------------------------------------------------------
$scanTargets = @()
$scanTargets += (Get-Item -LiteralPath $bundle)
$bootPath = Join-Path $repoRoot 'build\web\flutter_bootstrap.js'
if (Test-Path -LiteralPath $bootPath) { $scanTargets += (Get-Item -LiteralPath $bootPath) }
foreach ($n in @('index.html', 'robots.txt', 'sitemap.xml', 'manifest.json')) {
  $p = Join-Path $repoRoot ('build\web\' + $n)
  if (Test-Path -LiteralPath $p) { $scanTargets += (Get-Item -LiteralPath $p) }
}
# Every index.html under build\web: the Flutter entry shell plus all 23
# prerendered shells. This is what makes a seed/bundle ref disagreement visible.
$scanTargets += @(Get-ChildItem -LiteralPath (Join-Path $repoRoot 'build\web') -Recurse -File -Filter 'index.html')

$hostsSeen = @()
foreach ($f in $scanTargets) {
  $t = Get-Content -Raw -LiteralPath $f.FullName
  if ([string]::IsNullOrEmpty($t)) { continue }
  foreach ($m in [regex]::Matches($t, 'https://[a-z0-9][a-z0-9-]*\.supabase\.(co|in)')) {
    $hostsSeen += $m.Value
  }
}
$distinctHosts = @($hostsSeen | Sort-Object -Unique)
$refsSeen = @($distinctHosts | ForEach-Object {
    ($_ -replace '^https://', '') -replace '\.supabase\.(co|in)$', ''
  } | Sort-Object -Unique)
Write-Host ''
Write-Host ("supabase refs in : {0} (configured: {1})" -f ($refsSeen -join ', '), $configuredRef)
if ($refsSeen.Count -eq 0) {
  Write-Error 'no Supabase host appears anywhere in build\web - the bundle is not wired to a project.'
}
if ($refsSeen -notcontains $configuredRef) {
  Write-Error "build\web does not contain the configured project ref ($configuredRef)."
}
if ($refsSeen.Count -gt 1) {
  if ($expectedRef -ne '') {
    Write-Error ("build\web references more than one Supabase project ({0}) while this release is pinned to {1}." -f ($refsSeen -join ', '), $expectedRef)
  }
  Write-Host 'WARNING - MIXED SUPABASE PROJECT REFS IN THE BUNDLE.'
  Write-Host '          main.dart.js and the prerendered shells disagree about which'
  Write-Host '          project serves the content/images. Re-check SUPABASE_URL against'
  Write-Host '          the ref hard-coded in supabase\migrations\006_seed_data.sql before'
  Write-Host '          publishing, or pass -ExpectedProjectRef to make this a hard error.'
}

# ---------------------------------------------------------------------------
# 7. Upload-tree hygiene: a file in build\web is public by definition. Anything
#    that looks like source, migration SQL, a map file or a key is a leak, and
#    an accidental `flutter build web` from a dirty tree can produce exactly that.
# ---------------------------------------------------------------------------
$allBundleFiles = @(Get-ChildItem -LiteralPath (Join-Path $repoRoot 'build\web') -Recurse -File)
$forbiddenPatterns = @('\.sql$', '\.dart$', '\.env$', '^\.env', '\.pem$', '\.key$', '\.keystore$',
  '\.p12$', '\.jks$', '^app\..*\.symbols$', '\.map\.json$', '^\.git$', '\.part\.js$')
$leaks = @()
foreach ($f in $allBundleFiles) {
  foreach ($pat in $forbiddenPatterns) {
    if ($f.Name -match $pat) { $leaks += ('{0}  ->  {1}' -f $f.Name, $pat) }
  }
}
if ($leaks.Count -gt 0) {
  foreach ($l in $leaks) { Write-Host "  LEAK: $l" }
  Write-Error 'build\web contains files that must never be published.'
}
Write-Host ("upload tree      : {0} files, {1} bytes, no source/key/map files" -f $allBundleFiles.Count, ($allBundleFiles | Measure-Object -Sum Length | Select-Object -ExpandProperty Sum))

# ---------------------------------------------------------------------------
# 8. Fingerprint, so the operator can prove the bytes they published are the
#    bytes that were verified. Compare against deploy_cloudflare.ps1 output.
# ---------------------------------------------------------------------------
$sha = [System.Security.Cryptography.SHA256]::Create()
$fpEntry = Join-Path $repoRoot 'build\web\index.html'
$fpIndex = ''
if (Test-Path -LiteralPath $fpEntry) {
  $fpIndex = -join ($sha.ComputeHash([System.IO.File]::ReadAllBytes($fpEntry)) | ForEach-Object { $_.ToString('x2') })
}
$fpBundle = -join ($sha.ComputeHash([System.IO.File]::ReadAllBytes($bundle)) | ForEach-Object { $_.ToString('x2') })
Write-Host ''
Write-Host 'bundle fingerprint (must match the deployed artifact):'
Write-Host ('  main.dart.js sha256 : {0}' -f $fpBundle)
Write-Host ('  index.html   sha256 : {0}' -f $fpIndex)
Write-Host ('  file count          : {0}' -f $allBundleFiles.Count)

Write-Host ''
Write-Host 'OK: Supabase-backed production bundle written to build\web.'
if ($sentinels.Count -gt 0) {
  Write-Host 'STATUS: NOT RELEASABLE - built from a non-live config (see the WARNING above).'
} else {
  Write-Host 'Reminder: this bundle is only releasable when built with the real publishable/anon key.'
}
