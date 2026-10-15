import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import '../../../app/config/site_config.dart';
import '../../../core/analytics/analytics_service.dart';
import '../../../core/seo/seo_service.dart';
import '../../../data/models/article_model.dart';
import '../../../data/repositories/article_repository.dart';

class ArticleController extends GetxController {
  final ArticleRepository articleRepository;
  final SeoService seoService;
  final AnalyticsService analyticsService;

  ArticleController({
    required this.articleRepository,
    required this.seoService,
    required this.analyticsService,
  });

  final RxBool isLoading = true.obs;
  final RxString errorMessage = ''.obs;

  final Rx<ArticleModel?> article = Rx<ArticleModel?>(null);
  final RxList<ArticleModel> relatedArticles = <ArticleModel>[].obs;
  final RxList<ArticleModel> trendingArticles = <ArticleModel>[].obs;
  final RxList<ArticleModel> popularArticles = <ArticleModel>[].obs;

  String get currentSlug => Get.parameters['slug'] ?? '';

  /// The controller is type-keyed, so GetX keeps this same instance alive when
  /// a reader goes from one article route straight into another. Without this,
  /// URL B renders article A's body, A's canonical/OG tags and fires A's
  /// `article_view` beacon.
  String? _loadedSlug;

  void ensureCurrentRouteLoaded() {
    final slug = currentSlug;
    if (slug.isNotEmpty && slug != _loadedSlug) {
      loadArticle(slug);
    }
  }

  /// False once a newer article route has superseded this load, so a slow
  /// response for article A cannot paint over the article being read.
  bool _isCurrent(String slug) => _loadedSlug == slug;

  @override
  void onInit() {
    super.onInit();
    final slug = currentSlug;
    if (slug.isNotEmpty) {
      loadArticle(slug);
    }
  }

  Future<void> loadArticle(String slug) async {
    try {
      isLoading.value = true;
      errorMessage.value = '';
      _loadedSlug = slug;

      // Declared before the request: if the fetch throws, this URL keeps its
      // own canonical and stays out of the index instead of permanently
      // inheriting the shell's homepage canonical with `index, follow`.
      seoService.updateMeta(
        title: SiteConfig.siteName,
        description: SiteConfig.description,
        canonicalPath: '/article/$slug',
        robots: 'noindex, follow',
      );

      final art = await articleRepository.getArticleBySlug(slug);
      if (!_isCurrent(slug)) return;
      if (art == null) {
        errorMessage.value = 'Article not found.';
        article.value = null;
        // A soft-404 must not keep whatever metadata the previous page wrote:
        // index crawlers would treat the URL as a duplicate of a real article.
        seoService.updateMeta(
          title: 'Article not found',
          description: SiteConfig.description,
          canonicalPath: '/article/$slug',
          robots: 'noindex, follow',
        );
        return;
      }
      article.value = art;

      // Update SEO and Analytics
      seoService.updateArticleSeo(art);

      analyticsService.trackArticleRead(art.slug, art.categorySlug,
          postId: art.id);

      final related = await articleRepository.getRelatedArticles(art.slug, art.categorySlug);
      if (!_isCurrent(slug)) return;
      relatedArticles.assignAll(related);

      // Side rails are independent lists: awaited serially they cost three
      // round trips after the article itself.
      final rails = await Future.wait([
        articleRepository.getTrendingArticles(limit: 5),
        articleRepository.getPopularArticles(limit: 4),
      ]);
      if (!_isCurrent(slug)) return;
      trendingArticles.assignAll(rails[0]);
      popularArticles.assignAll(rails[1]);
    } catch (e) {
      if (!_isCurrent(slug)) return;
      // The raw exception text reaches a visitor in `ErrorState`, and a
      // PostgREST message can name tables and columns.
      debugPrint('ArticleController.loadArticle($slug) failed: $e');
      errorMessage.value = 'We could not load this story. Please try again.';
    } finally {
      if (_isCurrent(slug)) isLoading.value = false;
    }
  }
}
