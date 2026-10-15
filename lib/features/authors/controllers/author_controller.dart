import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import '../../../app/config/site_config.dart';
import '../../../core/errors/app_exceptions.dart';
import '../../../core/seo/seo_service.dart';
import '../../../data/models/article_model.dart';
import '../../../data/models/author_model.dart';
import '../../../data/repositories/article_repository.dart';
import '../../../data/repositories/category_repository.dart';

class AuthorController extends GetxController {
  final ArticleRepository articleRepository;
  final CategoryRepository categoryRepository;
  final SeoService seoService;

  AuthorController({
    required this.articleRepository,
    required this.categoryRepository,
    required this.seoService,
  });

  final RxBool isLoading = true.obs;
  final RxString errorMessage = ''.obs;

  final Rx<AuthorModel?> author = Rx<AuthorModel?>(null);
  final RxList<ArticleModel> authorArticles = <ArticleModel>[].obs;

  String get currentSlug => Get.parameters['slug'] ?? '';

  /// Type-keyed controller: the same instance serves every `/author/:slug`
  /// route, so the loaded slug has to be tracked or one profile bleeds into
  /// the next.
  String? _loadedSlug;

  void ensureCurrentRouteLoaded() {
    final slug = currentSlug;
    if (slug.isNotEmpty && slug != _loadedSlug) {
      loadAuthor(slug);
    }
  }

  /// False once a newer author route has superseded this load.
  bool _isCurrent(String slug) => _loadedSlug == slug;

  @override
  void onInit() {
    super.onInit();
    final slug = currentSlug;
    if (slug.isNotEmpty) {
      loadAuthor(slug);
    }
  }

  Future<void> loadAuthor(String slug) async {
    try {
      isLoading.value = true;
      errorMessage.value = '';
      _loadedSlug = slug;

      // The slug's own canonical is declared before the request: a failed
      // lookup must not leave the SPA shell's homepage canonical + `index,
      // follow` on this URL.
      seoService.updateMeta(
        title: SiteConfig.siteName,
        description: SiteConfig.description,
        canonicalPath: '/author/$slug',
        robots: 'noindex, follow',
      );

      final auth = await categoryRepository.getAuthorBySlug(slug);
      if (!_isCurrent(slug)) return;
      if (auth == null) {
        errorMessage.value = 'Author not found.';
        author.value = null;
        authorArticles.clear();
        // Without this the page keeps the metadata of whatever loaded before
        // it, so a misspelled author URL indexes as somebody else's profile.
        seoService.updateMeta(
          title: 'Author not found',
          description: SiteConfig.description,
          canonicalPath: '/author/$slug',
          robots: 'noindex, follow',
        );
        return;
      }
      author.value = auth;

      final articles = await articleRepository.getArticlesByAuthor(slug);
      if (!_isCurrent(slug)) return;
      authorArticles.assignAll(articles);

      seoService.updateAuthorSeo(auth);
    } catch (e) {
      if (!_isCurrent(slug)) return;
      debugPrint('AuthorController.loadAuthor($slug) failed: $e');
      errorMessage.value =
          e is AppException ? e.message : 'We could not load this profile.';
    } finally {
      if (_isCurrent(slug)) isLoading.value = false;
    }
  }
}
