import 'package:get/get.dart';
import '../../core/seo/seo_meta.dart';
import '../../core/supabase/role_permissions.dart';
import '../../features/admin/analytics/controllers/admin_analytics_controller.dart';
import '../../features/admin/analytics/views/admin_analytics_view.dart';
import '../../features/admin/articles/views/admin_article_editor_view.dart';
import '../../features/admin/articles/views/admin_articles_list_view.dart';
import '../../features/admin/auth/bindings/admin_auth_binding.dart';
import '../../features/admin/auth/views/admin_login_view.dart';
import '../../features/admin/authors/controllers/admin_authors_controller.dart';
import '../../features/admin/authors/views/admin_authors_view.dart';
import '../../features/admin/categories/controllers/admin_categories_controller.dart';
import '../../features/admin/categories/views/admin_categories_view.dart';
import '../../features/admin/dashboard/bindings/admin_dashboard_binding.dart';
import '../../features/admin/dashboard/views/admin_dashboard_view.dart';
import '../../features/admin/media/controllers/admin_media_controller.dart';
import '../../features/admin/media/views/admin_media_view.dart';
import '../../features/admin/scheduled/controllers/admin_scheduled_controller.dart';
import '../../features/admin/scheduled/views/admin_scheduled_view.dart';
import '../../features/admin/seo/controllers/admin_seo_controller.dart';
import '../../features/admin/seo/views/admin_seo_view.dart';
import '../../features/admin/settings/controllers/admin_settings_controller.dart';
import '../../features/admin/settings/views/admin_settings_view.dart';
import '../../features/admin/tags/controllers/admin_tags_controller.dart';
import '../../features/admin/tags/views/admin_tags_view.dart';
import '../../features/admin/trending/controllers/admin_trending_controller.dart';
import '../../features/admin/trending/views/admin_trending_view.dart';
import '../../data/repositories/analytics_repository.dart';
import '../../data/repositories/category_repository.dart';
import '../../data/repositories/media_repository.dart';
import '../../data/repositories/post_admin_repository.dart';
import '../../data/repositories/site_settings_repository.dart';
import '../config/site_config.dart';
import '../middleware/admin_auth_middleware.dart';
import '../../features/articles/bindings/article_binding.dart';
import '../../features/articles/views/article_view.dart';
import '../../features/authors/bindings/author_binding.dart';
import '../../features/authors/views/author_view.dart';
import '../../features/categories/bindings/category_binding.dart';
import '../../features/categories/views/category_view.dart';
import '../../features/home/bindings/home_binding.dart';
import '../../features/home/views/home_view.dart';
import '../../features/search/bindings/search_binding.dart';
import '../../features/search/views/search_view.dart';
import '../../features/static_pages/views/about_view.dart';
import '../../features/static_pages/views/contact_view.dart';
import '../../features/static_pages/views/disclaimer_view.dart';
import '../../features/static_pages/views/editorial_policy_view.dart';
import '../../features/static_pages/views/not_found_view.dart';
import '../../features/static_pages/views/privacy_policy_view.dart';
import '../../features/static_pages/views/terms_view.dart';
import '../../shared/widgets/page_seo_init.dart';
import 'app_routes.dart';

class AppPages {
  static const initial = AppRoutes.home;

  static final routes = <GetPage>[
    // ----------------------------------------------------
    // Public Routes
    // ----------------------------------------------------
    GetPage(
      name: AppRoutes.home,
      page: () => const HomeView(),
      binding: HomeBinding(),
      transition: Transition.fadeIn,
    ),
    GetPage(
      name: AppRoutes.ai,
      page: () => const CategoryView(),
      binding: CategoryBinding(),
      parameters: {'slug': 'ai'},
      transition: Transition.fadeIn,
    ),
    GetPage(
      name: AppRoutes.smartphones,
      page: () => const CategoryView(),
      binding: CategoryBinding(),
      parameters: {'slug': 'smartphones'},
      transition: Transition.fadeIn,
    ),
    GetPage(
      name: AppRoutes.apps,
      page: () => const CategoryView(),
      binding: CategoryBinding(),
      parameters: {'slug': 'apps'},
      transition: Transition.fadeIn,
    ),
    GetPage(
      name: AppRoutes.howTo,
      page: () => const CategoryView(),
      binding: CategoryBinding(),
      parameters: {'slug': 'how-to'},
      transition: Transition.fadeIn,
    ),
    GetPage(
      name: AppRoutes.techNews,
      page: () => const CategoryView(),
      binding: CategoryBinding(),
      parameters: {'slug': 'tech-news'},
      transition: Transition.fadeIn,
    ),
    GetPage(
      name: AppRoutes.comparisons,
      page: () => const CategoryView(),
      binding: CategoryBinding(),
      parameters: {'slug': 'comparisons'},
      transition: Transition.fadeIn,
    ),
    GetPage(
      name: AppRoutes.cyberSafety,
      page: () => const CategoryView(),
      binding: CategoryBinding(),
      parameters: {'slug': 'cyber-safety'},
      transition: Transition.fadeIn,
    ),
    GetPage(
      name: AppRoutes.buyingGuides,
      page: () => const CategoryView(),
      binding: CategoryBinding(),
      parameters: {'slug': 'buying-guides'},
      transition: Transition.fadeIn,
    ),
    GetPage(
      name: AppRoutes.articleDetail,
      page: () => const ArticleView(),
      binding: ArticleBinding(),
      transition: Transition.fadeIn,
    ),
    GetPage(
      name: AppRoutes.search,
      page: () => const SearchView(),
      binding: SearchBinding(),
      transition: Transition.fadeIn,
    ),
    GetPage(
      name: AppRoutes.authorDetail,
      page: () => const AuthorView(),
      binding: AuthorBinding(),
      transition: Transition.fadeIn,
    ),
    // Static pages carry their SEO meta here (not in a GetMiddleware) because
    // GetX skips middleware on the initial deep-linked route — the visit type
    // crawlers make. PageSeoInit's initState runs on every mount. The strings
    // live in `SeoMeta` so the prerenderer's crawler shells stay identical.
    GetPage(
      name: AppRoutes.about,
      page: () => PageSeoInit(
        title: SeoMeta.about.title,
        description: SeoMeta.about.description,
        canonicalPath: SeoMeta.about.path,
        child: const AboutView(),
      ),
      transition: Transition.fadeIn,
    ),
    GetPage(
      name: AppRoutes.contact,
      page: () => PageSeoInit(
        title: SeoMeta.contact.title,
        description: SeoMeta.contact.description,
        canonicalPath: SeoMeta.contact.path,
        child: const ContactView(),
      ),
      transition: Transition.fadeIn,
    ),
    GetPage(
      name: AppRoutes.editorialPolicy,
      page: () => PageSeoInit(
        title: SeoMeta.editorialPolicy.title,
        description: SeoMeta.editorialPolicy.description,
        canonicalPath: SeoMeta.editorialPolicy.path,
        child: const EditorialPolicyView(),
      ),
      transition: Transition.fadeIn,
    ),
    GetPage(
      name: AppRoutes.privacyPolicy,
      page: () => PageSeoInit(
        title: SeoMeta.privacyPolicy.title,
        description: SeoMeta.privacyPolicy.description,
        canonicalPath: SeoMeta.privacyPolicy.path,
        child: const PrivacyPolicyView(),
      ),
      transition: Transition.fadeIn,
    ),
    GetPage(
      name: AppRoutes.terms,
      page: () => PageSeoInit(
        title: SeoMeta.terms.title,
        description: SeoMeta.terms.description,
        canonicalPath: SeoMeta.terms.path,
        child: const TermsView(),
      ),
      transition: Transition.fadeIn,
    ),
    GetPage(
      name: AppRoutes.disclaimer,
      page: () => PageSeoInit(
        title: SeoMeta.disclaimer.title,
        description: SeoMeta.disclaimer.description,
        canonicalPath: SeoMeta.disclaimer.path,
        child: const DisclaimerView(),
      ),
      transition: Transition.fadeIn,
    ),
    // No canonicalPath on purpose: SeoMeta.page turns "noindex + no path" into
    // an omitted canonical instead of pointing every soft-404 at the homepage.
    GetPage(
      name: AppRoutes.notFound,
      page: () => PageSeoInit(
        title: 'Page Not Found',
        description: SiteConfig.description,
        robots: 'noindex, follow',
        child: const NotFoundView(),
      ),
      transition: Transition.fadeIn,
    ),

    // ----------------------------------------------------
    // Admin Routes
    // ----------------------------------------------------
    // Every admin page is wrapped in PageSeoInit with `noindex, follow`:
    // without it a client-side visit keeps the previously viewed article's
    // title/canonical and `index, follow`. No canonicalPath is supplied, so
    // SeoMeta.page emits no canonical for these noindex routes instead of
    // falsely declaring the homepage as their canonical.
    GetPage(
      name: AppRoutes.admin,
      page: () => PageSeoInit(
        title: 'Admin — Dashboard',
        description: 'Private admin area of Bharat Tech Pulse.',
        robots: 'noindex, follow',
        child: const AdminDashboardView(),
      ),
      binding: AdminDashboardBinding(),
      middlewares: [AdminAuthMiddleware()],
    ),
    GetPage(
      name: AppRoutes.adminLogin,
      page: () => PageSeoInit(
        title: 'Admin — Sign In',
        description: 'Private admin area of Bharat Tech Pulse.',
        robots: 'noindex, follow',
        child: const AdminLoginView(),
      ),
      binding: AdminAuthBinding(),
    ),
    GetPage(
      name: AppRoutes.adminDashboard,
      page: () => PageSeoInit(
        title: 'Admin — Dashboard',
        description: 'Private admin area of Bharat Tech Pulse.',
        robots: 'noindex, follow',
        child: const AdminDashboardView(),
      ),
      binding: AdminDashboardBinding(),
      middlewares: [AdminAuthMiddleware()],
    ),
    GetPage(
      name: AppRoutes.adminArticles,
      page: () => PageSeoInit(
        title: 'Admin — Articles',
        description: 'Private admin area of Bharat Tech Pulse.',
        robots: 'noindex, follow',
        child: const AdminArticlesListView(),
      ),
      middlewares: [AdminAuthMiddleware()],
    ),
    GetPage(
      name: AppRoutes.adminArticleCreate,
      page: () => PageSeoInit(
        title: 'Admin — New Article',
        description: 'Private admin area of Bharat Tech Pulse.',
        robots: 'noindex, follow',
        child: const AdminArticleEditorView(),
      ),
      middlewares: [AdminAuthMiddleware()],
    ),
    GetPage(
      name: AppRoutes.adminArticleEdit,
      page: () => PageSeoInit(
        title: 'Admin — Edit Article',
        description: 'Private admin area of Bharat Tech Pulse.',
        robots: 'noindex, follow',
        child: const AdminArticleEditorView(),
      ),
      middlewares: [AdminAuthMiddleware()],
    ),
    GetPage(
      name: AppRoutes.adminCategories,
      page: () => PageSeoInit(
        title: 'Admin — Categories',
        description: 'Private admin area of Bharat Tech Pulse.',
        robots: 'noindex, follow',
        child: const AdminCategoriesView(),
      ),
      binding: BindingsBuilder(() {
        Get.lazyPut(() => AdminCategoriesController(
            categoryRepository: Get.find<CategoryRepository>()));
      }),
      middlewares: [
        AdminRoleMiddleware(canAccess: RolePermissions.canManageContent)
      ],
    ),
    GetPage(
      name: AppRoutes.adminTags,
      page: () => PageSeoInit(
        title: 'Admin — Tags',
        description: 'Private admin area of Bharat Tech Pulse.',
        robots: 'noindex, follow',
        child: const AdminTagsView(),
      ),
      binding: BindingsBuilder(() {
        Get.lazyPut(() =>
            AdminTagsController(categoryRepository: Get.find<CategoryRepository>()));
      }),
      middlewares: [
        AdminRoleMiddleware(canAccess: RolePermissions.canManageContent)
      ],
    ),
    GetPage(
      name: AppRoutes.adminAuthors,
      page: () => PageSeoInit(
        title: 'Admin — Authors',
        description: 'Private admin area of Bharat Tech Pulse.',
        robots: 'noindex, follow',
        child: const AdminAuthorsView(),
      ),
      binding: BindingsBuilder(() {
        Get.lazyPut(() => AdminAuthorsController(
            categoryRepository: Get.find<CategoryRepository>()));
      }),
      // Byline writes are `is_site_admin` in RLS — the same tier as settings.
      middlewares: [
        AdminRoleMiddleware(canAccess: RolePermissions.canManageSettings)
      ],
    ),
    GetPage(
      name: AppRoutes.adminMedia,
      page: () => PageSeoInit(
        title: 'Admin — Media',
        description: 'Private admin area of Bharat Tech Pulse.',
        robots: 'noindex, follow',
        child: const AdminMediaView(),
      ),
      binding: BindingsBuilder(() {
        Get.lazyPut(
            () => AdminMediaController(mediaRepository: Get.find<MediaRepository>()));
      }),
      middlewares: [AdminAuthMiddleware()],
    ),
    GetPage(
      name: AppRoutes.adminTrending,
      page: () => PageSeoInit(
        title: 'Admin — Trending',
        description: 'Private admin area of Bharat Tech Pulse.',
        robots: 'noindex, follow',
        child: const AdminTrendingView(),
      ),
      binding: BindingsBuilder(() {
        Get.lazyPut(() => AdminTrendingController(
            postAdminRepository: Get.find<PostAdminRepository>()));
      }),
      // Curation flags are `posts_update_site_editor`; leaving the route open
      // would advertise buttons RLS refuses.
      middlewares: [
        AdminRoleMiddleware(canAccess: RolePermissions.canManageContent)
      ],
    ),
    GetPage(
      name: AppRoutes.adminScheduled,
      page: () => PageSeoInit(
        title: 'Admin — Scheduled',
        description: 'Private admin area of Bharat Tech Pulse.',
        robots: 'noindex, follow',
        child: const AdminScheduledView(),
      ),
      binding: BindingsBuilder(() {
        Get.lazyPut(() => AdminScheduledController(
            postAdminRepository: Get.find<PostAdminRepository>()));
      }),
      middlewares: [
        AdminRoleMiddleware(canAccess: RolePermissions.canManageContent)
      ],
    ),
    GetPage(
      name: AppRoutes.adminSeo,
      page: () => PageSeoInit(
        title: 'Admin — SEO',
        description: 'Private admin area of Bharat Tech Pulse.',
        robots: 'noindex, follow',
        child: const AdminSeoView(),
      ),
      binding: BindingsBuilder(() {
        Get.lazyPut(() => AdminSeoController(
            siteSettingsRepository: Get.find<SiteSettingsRepository>()));
      }),
      // SEO globals live on `site_settings`, whose writes are `is_site_admin`.
      middlewares: [
        AdminRoleMiddleware(canAccess: RolePermissions.canManageSettings)
      ],
    ),
    GetPage(
      name: AppRoutes.adminAnalytics,
      page: () => PageSeoInit(
        title: 'Admin — Analytics',
        description: 'Private admin area of Bharat Tech Pulse.',
        robots: 'noindex, follow',
        child: const AdminAnalyticsView(),
      ),
      binding: BindingsBuilder(() {
        Get.lazyPut(() => AdminAnalyticsController(
            analyticsRepository: Get.find<AnalyticsRepository>()));
      }),
      // Mirrors the repository-side `canViewReports` guard, so an author is not
      // routed to a panel whose queries RLS will refuse.
      middlewares: [
        AdminRoleMiddleware(canAccess: RolePermissions.canViewReports)
      ],
    ),
    GetPage(
      name: AppRoutes.adminSettings,
      page: () => PageSeoInit(
        title: 'Admin — Settings',
        description: 'Private admin area of Bharat Tech Pulse.',
        robots: 'noindex, follow',
        child: const AdminSettingsView(),
      ),
      binding: BindingsBuilder(() {
        Get.lazyPut(() => AdminSettingsController(
            siteSettingsRepository: Get.find<SiteSettingsRepository>()));
      }),
      middlewares: [
        AdminRoleMiddleware(canAccess: RolePermissions.canManageSettings)
      ],
    ),
  ];
}
