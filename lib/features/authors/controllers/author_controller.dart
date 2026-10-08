import 'package:get/get.dart';
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

      final auth = await categoryRepository.getAuthorBySlug(slug);
      if (auth == null) {
        errorMessage.value = 'Author not found.';
        return;
      }
      author.value = auth;

      final articles = await articleRepository.getArticlesByAuthor(slug);
      authorArticles.assignAll(articles);

      seoService.updateMeta(
        title: '${auth.name} — Author Profile',
        description: auth.bio,
        canonicalPath: '/author/$slug',
      );
    } catch (e) {
      errorMessage.value = e.toString();
    } finally {
      isLoading.value = false;
    }
  }
}
