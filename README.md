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
| **Run Locally (Chrome)**| `fvm flutter run -d chrome` |
| **Build Web Release** | `fvm flutter build web --release` |
| **Build with CanvasKit/HTML** | `fvm flutter build web --release --web-renderer canvaskit` |

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

## 8. Future Supabase Integration (Phase 2 Preparation)

The architecture isolates the UI from the mock layer through repository interfaces:
- `ArticleRepository` defines the contract for reading, filtering, and CRUD operations.
- `MockArticleRepository` serves data from `MockDataSource`.
- In Phase 2, `SupabaseArticleRepository` can be added without altering a single widget or GetX controller. Simply bind `Get.put<ArticleRepository>(SupabaseArticleRepository())` in `InitialBinding`.
- Environment credentials can be supplied at build time:
  ```powershell
  fvm flutter build web --release --dart-define=SUPABASE_URL=https://xyz.supabase.co --dart-define=SUPABASE_ANON_KEY=your-anon-key
  ```

---

## 9. Verification Summary

- **Flutter SDK**: 3.44.6
- **Analyzer Status**: `0 issues` (`fvm flutter analyze` passed cleanly)
- **Test Status**: `13 / 13 passed` (`fvm flutter test` passed 100%)
- **Release Build**: `build/web` generated successfully with full font and icon tree-shaking
#   b h a r a t - t e c h - p u l s e  
 