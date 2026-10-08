import 'package:get/get.dart';
import '../../features/admin/articles/views/admin_article_editor_view.dart';
import '../../features/admin/articles/views/admin_articles_list_view.dart';
import '../../features/admin/analytics/views/admin_analytics_view.dart';
import '../../features/admin/auth/bindings/admin_auth_binding.dart';
import '../../features/admin/auth/views/admin_login_view.dart';
import '../../features/admin/authors/views/admin_authors_view.dart';
import '../../features/admin/categories/views/admin_categories_view.dart';
import '../../features/admin/dashboard/bindings/admin_dashboard_binding.dart';
import '../../features/admin/dashboard/views/admin_dashboard_view.dart';
import '../../features/admin/media/views/admin_media_view.dart';
import '../../features/admin/scheduled/views/admin_scheduled_view.dart';
import '../../features/admin/seo/views/admin_seo_view.dart';
import '../../features/admin/settings/views/admin_settings_view.dart';
import '../../features/admin/tags/views/admin_tags_view.dart';
import '../../features/admin/trending/views/admin_trending_view.dart';
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
    // crawlers make. PageSeoInit's initState runs on every mount.
    GetPage(
      name: AppRoutes.about,
      page: () => PageSeoInit(
        title: 'About Us',
        description:
            'Meet the Bharat Tech Pulse editorial team and our mission of jargon-free, high-integrity technology journalism for India.',
        canonicalPath: AppRoutes.about,
        child: const AboutView(),
      ),
      transition: Transition.fadeIn,
    ),
    GetPage(
      name: AppRoutes.contact,
      page: () => PageSeoInit(
        title: 'Contact Us',
        description:
            'Get in touch with the Bharat Tech Pulse team for tips, corrections, feedback, and partnership enquiries.',
        canonicalPath: AppRoutes.contact,
        child: const ContactView(),
      ),
      transition: Transition.fadeIn,
    ),
    GetPage(
      name: AppRoutes.editorialPolicy,
      page: () => PageSeoInit(
        title: 'Editorial Policy',
        description:
            'How Bharat Tech Pulse tests, reviews, and fact-checks technology for Indian readers.',
        canonicalPath: AppRoutes.editorialPolicy,
        child: const EditorialPolicyView(),
      ),
      transition: Transition.fadeIn,
    ),
    GetPage(
      name: AppRoutes.privacyPolicy,
      page: () => PageSeoInit(
        title: 'Privacy Policy',
        description:
            'How Bharat Tech Pulse collects, uses, and protects visitor information.',
        canonicalPath: AppRoutes.privacyPolicy,
        child: const PrivacyPolicyView(),
      ),
      transition: Transition.fadeIn,
    ),
    GetPage(
      name: AppRoutes.terms,
      page: () => PageSeoInit(
        title: 'Terms of Use',
        description: 'Terms governing the use of the Bharat Tech Pulse website.',
        canonicalPath: AppRoutes.terms,
        child: const TermsView(),
      ),
      transition: Transition.fadeIn,
    ),
    GetPage(
      name: AppRoutes.disclaimer,
      page: () => PageSeoInit(
        title: 'Disclaimer',
        description:
            'Editorial, affiliate, and accuracy disclaimers for Bharat Tech Pulse content.',
        canonicalPath: AppRoutes.disclaimer,
        child: const DisclaimerView(),
      ),
      transition: Transition.fadeIn,
    ),
    GetPage(
      name: AppRoutes.notFound,
      page: () => PageSeoInit(
        title: 'Page Not Found',
        description: SiteConfig.description,
        child: const NotFoundView(),
      ),
      transition: Transition.fadeIn,
    ),

    // ----------------------------------------------------
    // Admin Routes
    // ----------------------------------------------------
    GetPage(
      name: AppRoutes.admin,
      page: () => const AdminDashboardView(),
      binding: AdminDashboardBinding(),
      middlewares: [AdminAuthMiddleware()],
    ),
    GetPage(
      name: AppRoutes.adminLogin,
      page: () => const AdminLoginView(),
      binding: AdminAuthBinding(),
    ),
    GetPage(
      name: AppRoutes.adminDashboard,
      page: () => const AdminDashboardView(),
      binding: AdminDashboardBinding(),
      middlewares: [AdminAuthMiddleware()],
    ),
    GetPage(
      name: AppRoutes.adminArticles,
      page: () => const AdminArticlesListView(),
      middlewares: [AdminAuthMiddleware()],
    ),
    GetPage(
      name: AppRoutes.adminArticleCreate,
      page: () => const AdminArticleEditorView(),
      middlewares: [AdminAuthMiddleware()],
    ),
    GetPage(
      name: AppRoutes.adminArticleEdit,
      page: () => const AdminArticleEditorView(),
      middlewares: [AdminAuthMiddleware()],
    ),
    GetPage(
      name: AppRoutes.adminCategories,
      page: () => const AdminCategoriesView(),
      middlewares: [AdminAuthMiddleware()],
    ),
    GetPage(
      name: AppRoutes.adminTags,
      page: () => const AdminTagsView(),
      middlewares: [AdminAuthMiddleware()],
    ),
    GetPage(
      name: AppRoutes.adminAuthors,
      page: () => const AdminAuthorsView(),
      middlewares: [AdminAuthMiddleware()],
    ),
    GetPage(
      name: AppRoutes.adminMedia,
      page: () => const AdminMediaView(),
      middlewares: [AdminAuthMiddleware()],
    ),
    GetPage(
      name: AppRoutes.adminTrending,
      page: () => const AdminTrendingView(),
      middlewares: [AdminAuthMiddleware()],
    ),
    GetPage(
      name: AppRoutes.adminScheduled,
      page: () => const AdminScheduledView(),
      middlewares: [AdminAuthMiddleware()],
    ),
    GetPage(
      name: AppRoutes.adminSeo,
      page: () => const AdminSeoView(),
      middlewares: [AdminAuthMiddleware()],
    ),
    GetPage(
      name: AppRoutes.adminAnalytics,
      page: () => const AdminAnalyticsView(),
      middlewares: [AdminAuthMiddleware()],
    ),
    GetPage(
      name: AppRoutes.adminSettings,
      page: () => const AdminSettingsView(),
      middlewares: [AdminAuthMiddleware()],
    ),
  ];
}
