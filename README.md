# Bharat Tech Pulse — Website #1 (India Tech, AI, Apps & How-To)

> Built with **Flutter Web 3.44.6**, **FVM**, **GetX**, and **Material 3**. Engineered for high-speed editorial journalism, comprehensive responsive layouts, and ready for future Supabase multi-tenant scaling.

---

## 1. Project Overview

**Bharat Tech Pulse** is the flagship publication in the multi-website workspace located under `D:\personal blog websites\`. It is built with zero hardcoded site names, using a centralized configuration pattern (`SiteConfig`, `AppTheme`, `InitialBinding`) so that sibling websites (such as `india_travel_web`, `food_web`, `lifestyle_web`) can replicate the exact same architecture.

### Key Pillars:
- **Audience**: Everyday Indian tech enthusiasts, developers, and families.
- **Coverage**: Indic LLMs, 5G networks, smartphone benchmark shootouts, UPI ecosystems, DigiLocker tutorials, and cyber defense against digital arrest scams.
- **Visual Aesthetic**: Editorial dark/light modes with Material 3, cyan/teal neon accents, Indian saffron badges, smooth hover feedback, and strict horizontal overflow protection across all viewport widths.

---

## 2. Flutter Version & FVM Setup

**Flutter Version**: `3.44.6` (Dart `3.12.2`)  
Managed strictly via **FVM** (`.fvm/fvm_config.json`).

### Non-Negotiable CLI Rule
Never use global system Flutter for this project. Always run commands through FVM:

```powershell
cd "D:\personal blog websites\india_tech_web"
fvm use 3.44.6
fvm flutter --version
```

---

## 3. Quick Run & Build Commands

All commands must be executed from inside `D:\personal blog websites\india_tech_web`:

| Task | Command |
| :--- | :--- |
| **Fetch Dependencies** | `fvm flutter pub get` |
| **Code Analyzer** | `fvm flutter analyze` |
| **Run Test Suite** | `fvm flutter test` |
| **Run Locally (Chrome)**| `fvm flutter run -d chrome` (mock data) |
| **Build Production Web** | `powershell -NoProfile -ExecutionPolicy Bypass -File tool\build_production.ps1` |

> **A release build can no longer ship mock data.** `fvm flutter build web --release`
> without `ENV=production` + `DATA_SOURCE=supabase` + real credentials produces a
> bundle that throws a `CONFIGURATION ERROR` at startup instead of rendering
> fabricated articles (see §8). Use `tool/build_production.ps1`, or
> `fvm flutter run -d chrome` / `fvm flutter build web --debug` for a local mock preview.

---

## 4. Architecture & Directory Structure

```
D:\personal blog websites\india_tech_web\
├── .fvm/
│   └── fvm_config.json
├── android/
├── ios/
├── web/
│   ├── index.html           # Full SEO meta tags, title, OG tags
│   └── manifest.json
├── lib/
│   ├── main.dart            # Clean entrypoint with InitialBinding()
│   ├── app/
│   │   ├── app.dart         # GetMaterialApp with responsive theme
│   │   ├── config/
│   │   │   ├── site_config.dart          # Centralized brand, URLs, meta
│   │   │   ├── environment_config.dart   # Env variables for Supabase
│   │   │   └── app_constants.dart        # Breakpoints & spacing tokens
│   │   ├── routes/
│   │   │   ├── app_routes.dart           # Route name constants
│   │   │   └── app_pages.dart            # GetPage route declarations
│   │   ├── theme/
│   │   │   ├── app_theme.dart            # Material 3 light & dark themes
│   │   │   ├── theme_colors.dart         # Exact brand hex color palette
│   │   │   ├── theme_text.dart           # Outfit + Inter typography
│   │   │   └── theme_controller.dart     # Reactive ThemeController + SharedPreferences
│   │   └── bindings/
│   │       └── initial_binding.dart      # Root dependency injection container
│   ├── core/
│   │   ├── errors/          # AppException, NetworkException, etc.
│   │   ├── network/         # ApiResult (Success / Failure sealed classes)
│   │   ├── storage/         # StorageService abstraction
│   │   ├── seo/             # SeoService for dynamic meta tags & JSON-LD
│   │   ├── analytics/       # AnalyticsService for route & story telemetry
│   │   ├── utils/           # DateFormatter (Indian style), SlugHelper
│   │   └── extensions/      # BuildContext ergonomic extensions
│   ├── data/
│   │   ├── models/          # ArticleModel, CategoryModel, AuthorModel, TagModel
│   │   ├── repositories/    # ArticleRepository, MockArticleRepository, etc.
│   │   └── services/        # MockDataSource (21+ authentic Indian stories)
│   ├── features/
│   │   ├── home/            # 12-section editorial homepage
│   │   ├── categories/      # Reusable template for all 8 categories + subcategory filters
│   │   ├── articles/        # Editorial article reader with sidebar & TOC
│   │   ├── search/          # Search bar, query filter & state management
│   │   ├── authors/         # Contributor profile & author story grid
│   │   ├── static_pages/    # About, Contact, Editorial Policy, Privacy, Terms, Disclaimer, 404
│   │   └── admin/           # Comprehensive CMS backend
│   │       ├── auth/        # Admin login view & controller
│   │       ├── layouts/     # AdminScaffold (Sidebar + Topbar + Content)
│   │       ├── dashboard/   # Metric cards, recent articles, top performing
│   │       ├── articles/    # Article listing & Full metadata + SEO editor
│   │       ├── categories/  # Category manager
│   │       ├── tags/        # Tag indexing manager
│   │       ├── authors/     # Contributor manager
│   │       ├── media/       # Storage asset grid
│   │       ├── trending/    # Algorithmic trending toggle
│   │       ├── scheduled/   # Publishing queue
│   │       ├── seo/         # Sitemap/robots/RSS manager
│   │       ├── analytics/   # Geo & engagement stats
│   │       └── settings/    # Multi-site & Supabase config
│   └── shared/
│       ├── responsive/      # Breakpoints, ResponsiveBuilder, Container, Grid
│       ├── layouts/         # PublicScaffold, ContentWithSidebar
│       ├── components/      # AppNavbar, MobileDrawer, AppFooter, SectionHeader, etc.
│       ├── widgets/         # ArticleCard, FeaturedArticleCard, TrendingCard, etc.
│       └── skeletons/       # LoadingSkeleton, EmptyState, ErrorState
├── test/
│   ├── models_test.dart       # JSON serialization & entity tests
│   ├── repositories_test.dart # In-memory CRUD & filter tests
│   ├── controllers_test.dart  # GetX controllers & theme toggle tests
│   └── widget_test.dart       # App bootstrap & reactive theme switching tests
└── pubspec.yaml
```

---

## 5. Routes Registered

### Public Routes
- `/` — Homepage (12 comprehensive editorial sections)
- `/ai/` — AI & Indic Tools Hub
- `/smartphones/` — Smartphone Benchmarks & Reviews
- `/apps/` — Apps, UPI & ONDC Ecosystem
- `/how-to/` — Step-by-step Tech & Govt Portal Guides
- `/tech-news/` — Telecom, 5G & Hardware News
- `/comparisons/` — Head-to-Head Gadget & App Battles
- `/cyber-safety/` — Scam Alerts & Helpline 1930 Guides
- `/buying-guides/` — Value Purchase Recommendations
- `/article/:slug` — Article View with Sticky Sidebar & TOC
- `/search?q=` — Real-time Article Search
- `/author/:slug` — Editorial Contributor Profile
- `/about` — About Bharat Tech Pulse & Editorial Mission
- `/contact` — Contact Form & Editorial Tips
- `/editorial-policy` — Independent Testing & Verification Code
- `/privacy-policy` — DPDP Act 2023 Compliant Policy
- `/terms` — Terms of Use & Copyright
- `/disclaimer` — Affiliate & Legal Disclaimer
- `/404` — Page Not Found Handler

### Admin Routes
- `/admin` & `/admin/dashboard` — Metric dashboard
- `/admin/login` — Authentication screen

> **Status:** Admin sign-in is real Supabase Auth **only when the backend is
> configured** (`ENV=production` + `DATA_SOURCE=supabase` + credentials). In mock
> mode `AdminAuthController.login()` **refuses every credential** with
> `Backend is not configured.` and never sets `isLoggedIn` — the CMS is
> unreachable rather than falsely open. The GetX middleware is client-side UX
> gating only; real authorization is enforced server-side (Supabase Auth + RLS),
> because everything in a Flutter Web bundle is public.
- `/admin/articles` — Article list & quick actions
- `/admin/articles/create` — Composition editor
- `/admin/articles/edit/:id` — Edit existing story
- `/admin/categories` — Categories manager
- `/admin/tags` — Topic tags index
- `/admin/authors` — Contributor bylines
- `/admin/media` — Media assets gallery
- `/admin/trending` — Trending prioritization
- `/admin/scheduled` — Scheduled queue
- `/admin/seo` — Sitemap, robots & RSS management
- `/admin/analytics` — Geo and traffic metrics
- `/admin/settings` — Multi-site & Supabase parameters

---

## 6. Theme & Design Tokens

Designed in strict compliance with the project brief:

### Dark Theme (Default)
- **Background**: `#0B0F19`
- **Surface**: `#111827`
- **Card**: `#151D2E`
- **Border**: `#263244`
- **Primary**: `#06B6D4` (Cyan neon)
- **Primary Dark**: `#0891B2`
- **Text**: `#F8FAFC`
- **Secondary**: `#94A3B8`
- **Muted**: `#64748B`

### Light Theme
- **Background**: `#F8FAFC`
- **Surface**: `#FFFFFF`
- **Card**: `#FFFFFF`
- **Border**: `#E2E8F0`
- **Primary**: `#0891B2`
- **Text**: `#0F172A`
- **Secondary**: `#475569`
- **Muted**: `#64748B`

### Functional Accents
- **Success**: `#22C55E`
- **Warning**: `#F59E0B`
- **Error**: `#EF4444`
- **Saffron Indian Accent**: `#FF9933`

---

## 7. Responsive Breakpoints Supported

The application includes responsive layout builders without horizontal scrollbar overflows:
- `1440px+` (Desktop Large): 5-column admin grids, 3-column article grids, dual sidebars
- `1280px` (Desktop): Multi-column layouts with fixed-width sidebars
- `1024px` (Laptop): Dynamic content flexing with responsive sidebars
- `900px` (Tablet Landscape): 2-column stacked grids
- `768px` (Tablet Portrait): Single-column sidebar collapse, sticky navbar
- `650px` (Mobile Large): Dual-column compact cards
- `480px` (Mobile Standard): Full-width cards with mobile drawer
- `425px` & `375px` (Mobile Small): Fluid typography and touch-optimized touch targets

---

## 8. Data Source: Mock vs Supabase (Production Wiring)

Repository interfaces isolate the UI from the data layer:

- `ArticleRepository` defines the contract for reading, filtering, and CRUD operations.
- `MockArticleRepository` serves data from `MockDataSource` (development and tests only).
- `SupabaseArticleRepository` implements the same contract against Postgres/RLS and is
  bound by `InitialBinding` whenever `EnvironmentConfig.useSupabase` is true — no widget
  or GetX controller changes.

### Selection rules (`lib/app/config/environment_config.dart`)

| Build | Result |
| :--- | :--- |
| `fvm flutter test`, `flutter run`, `build web --debug` | mock repositories (default `DATA_SOURCE=mock`) |
| `build web --release` **or** `ENV=production`, with `DATA_SOURCE=supabase` + real credentials | Supabase repositories, live backend |
| `build web --release` **or** `ENV=production` without them | **startup `StateError`** with the exact remediation command — never silent mock content |

The signal is `--dart-define=ENV=production` (explicit developer intent) plus a
`kReleaseMode` backstop. `kReleaseMode` alone is not used as the trigger because it is
`false` under `flutter test`, and the mock path must keep working there; in a release
compilation it is `true`, so forgetting `ENV=production` fails loudly too. Because the
mock branch is statically unreachable in a production build, the mock fixtures are
tree-shaken out of the shipped bundle entirely.

### The correct production command

```powershell
fvm flutter build web --release `
  --dart-define=ENV=production `
  --dart-define=DATA_SOURCE=supabase `
  --dart-define=SUPABASE_URL=https://<project-ref>.supabase.co `
  --dart-define=SUPABASE_ANON_KEY=<publishable key>
```

`SUPABASE_ANON_KEY` must be the **publishable / anon** key (`sb_publishable_...` or the
legacy anon JWT). It is public by design: a Flutter Web bundle is readable by every
visitor. **Never** put a `service_role` key, any secret key, or a database password in
Flutter source, frontend config, git, a `--dart-define`, or the bundle.

Prefer the script, which reads the two values with the existing toolkit loader
(`tool/live_checks/lib/config.js`: real env vars first, then the git-ignored
`tool/live_checks/.env`), refuses to build when either is missing or still a
placeholder, prints only the key's presence/length, and verifies the bundle afterwards:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tool\build_production.ps1
```

---

## 9. Verification Summary

Last verified: Phase 1 (production data-source selection), Flutter 3.44.6 / Dart 3.12.2 via FVM.

- **Analyzer**: `fvm flutter analyze --no-pub` → `No issues found!`
- **Tests**: `fvm flutter test` → `All tests passed!` — **62** tests
  (the 49 pre-existing tests plus 13 new Phase 1 tests in
  `test/production_data_source_test.dart`)
- **Bundle markers** (`build/web/main.dart.js` occurrence counts):

| Marker | default `--release` mock build (before) | production wiring proof (`ENV=production DATA_SOURCE=supabase`, dummy key) | dev `--debug` build (restored) |
| :--- | ---:| ---:| ---:|
| `post_revisions` | 0 | 2 | 0 |
| `analytics_events` | 0 | 4 | 0 |
| `ylzwuwfhlqomjqcdrpxk` (live project ref) | 0 | 4 | 0 |
| `placeholder-project` | 1 | 0 | 2 |
| `Aravind Sharma` (mock fixture) | 1 | 0 | 1 |
| bundle size | 3,291,528 B | 3,436,722 B | 12,927,991 B |

  The dummy-key artifact proves the Supabase repositories survive tree-shaking when
  `DATA_SOURCE=supabase`, and that no mock fixture data ships with it. It is **not**
  releasable — it carries a fake key. A releasable bundle requires the owner's real
  publishable/anon key via `tool/build_production.ps1`.
- **Release Build**: `build/web` regenerates cleanly with full font/icon tree-shaking.
