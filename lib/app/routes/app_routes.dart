/// Route path constants for Bharat Tech Pulse.
abstract class AppRoutes {
  // Public Routes
  static const String home = '/';
  static const String ai = '/ai/';
  static const String smartphones = '/smartphones/';
  static const String apps = '/apps/';
  static const String howTo = '/how-to/';
  static const String techNews = '/tech-news/';
  static const String comparisons = '/comparisons/';
  static const String cyberSafety = '/cyber-safety/';
  static const String buyingGuides = '/buying-guides/';
  static const String articleDetail = '/article/:slug';
  static const String search = '/search';
  static const String authorDetail = '/author/:slug';
  static const String about = '/about';
  static const String contact = '/contact';
  static const String editorialPolicy = '/editorial-policy';
  static const String privacyPolicy = '/privacy-policy';
  static const String terms = '/terms';
  static const String disclaimer = '/disclaimer';
  static const String notFound = '/404';

  // Admin Routes
  static const String admin = '/admin';
  static const String adminLogin = '/admin/login';
  static const String adminDashboard = '/admin/dashboard';
  static const String adminArticles = '/admin/articles';
  static const String adminArticleCreate = '/admin/articles/create';
  static const String adminArticleEdit = '/admin/articles/edit/:id';
  static const String adminCategories = '/admin/categories';
  static const String adminTags = '/admin/tags';
  static const String adminAuthors = '/admin/authors';
  static const String adminMedia = '/admin/media';
  static const String adminTrending = '/admin/trending';
  static const String adminScheduled = '/admin/scheduled';
  static const String adminSeo = '/admin/seo';
  static const String adminAnalytics = '/admin/analytics';
  static const String adminSettings = '/admin/settings';
}
