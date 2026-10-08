import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../app/routes/app_routes.dart';
import '../../../../core/utils/slug_helper.dart';
import '../../../../data/models/article_model.dart';
import '../../../../data/models/author_model.dart';
import '../../../../data/models/category_model.dart';
import '../../../../data/repositories/article_repository.dart';
import '../../../../data/repositories/category_repository.dart';

class AdminArticleController extends GetxController {
  final ArticleRepository articleRepository;
  final CategoryRepository categoryRepository;

  AdminArticleController({
    required this.articleRepository,
    required this.categoryRepository,
  });

  final RxBool isLoading = true.obs;
  final RxList<ArticleModel> articles = <ArticleModel>[].obs;
  final RxList<CategoryModel> categories = <CategoryModel>[].obs;
  final RxList<AuthorModel> authors = <AuthorModel>[].obs;

  // Editor form fields
  final titleController = TextEditingController();
  final slugController = TextEditingController();
  final excerptController = TextEditingController();
  final contentController = TextEditingController();
  final tagsController = TextEditingController();
  final featuredImageController = TextEditingController();
  final altTextController = TextEditingController();
  final seoTitleController = TextEditingController();
  final metaDescController = TextEditingController();
  final canonicalUrlController = TextEditingController();
  final ogTitleController = TextEditingController();
  final ogDescController = TextEditingController();
  final ogImageController = TextEditingController();

  final RxString selectedCategorySlug = 'ai'.obs;
  final RxString selectedAuthorId = 'author-1'.obs;
  final RxString status = 'published'.obs; // draft, published, scheduled
  final Rx<DateTime> publishDate = DateTime.now().obs;
  final Rx<DateTime> scheduleDate = DateTime.now().add(const Duration(days: 1)).obs;

  String? editingArticleId;
  final RxBool isEditingMode = false.obs;
  final RxString editorError = ''.obs;

  @override
  void onInit() {
    super.onInit();
    loadArticlesAndMeta();
  }

  @override
  void onClose() {
    titleController.dispose();
    slugController.dispose();
    excerptController.dispose();
    contentController.dispose();
    tagsController.dispose();
    featuredImageController.dispose();
    altTextController.dispose();
    seoTitleController.dispose();
    metaDescController.dispose();
    canonicalUrlController.dispose();
    ogTitleController.dispose();
    ogDescController.dispose();
    ogImageController.dispose();
    super.onClose();
  }

  Future<void> loadArticlesAndMeta() async {
    try {
      isLoading.value = true;
      final arts = await articleRepository.getAllArticlesForAdmin();
      articles.assignAll(arts);

      final cats = await categoryRepository.getCategories();
      categories.assignAll(cats);

      final auths = await categoryRepository.getAuthors();
      authors.assignAll(auths);
    } finally {
      isLoading.value = false;
    }
  }

  /// Hydrates the editor from the current admin route. Called by the editor
  /// view on arrival so deep links (F5 on /admin/articles/edit/:id) and
  /// direct navigations that skip the list view still load the right article.
  Future<void> initializeFromRoute() async {
    final route = Get.currentRoute;
    if (route == AppRoutes.adminArticleCreate) {
      initializeForCreate();
      return;
    }
    if (route.startsWith('/admin/articles/edit')) {
      final editId = Get.parameters['id'];
      if (editId == null || editId.isEmpty) {
        editorError.value = 'No article ID was specified in the URL.';
        return;
      }
      await initializeForEdit(editId);
    }
  }

  Future<void> initializeForEdit(String id) async {
    if (isEditingMode.value && editingArticleId == id && editorError.value.isEmpty) {
      return;
    }
    editingArticleId = id;
    if (articles.isEmpty) {
      await loadArticlesAndMeta();
    }
    final article = articles.firstWhereOrNull((a) => a.id == id);
    if (article == null) {
      editingArticleId = null;
      isEditingMode.value = false;
      editorError.value = 'The article "$id" does not exist.';
      return;
    }
    editorError.value = '';
    isEditingMode.value = true;
    titleController.text = article.title;
    slugController.text = article.slug;
    excerptController.text = article.excerpt;
    contentController.text = article.content;
    tagsController.text = article.tags.join(', ');
    featuredImageController.text = article.featuredImage;
    altTextController.text = article.title;
    selectedCategorySlug.value = article.categorySlug;
    selectedAuthorId.value = article.author.id;
    seoTitleController.text = article.title;
    metaDescController.text = article.excerpt;
    canonicalUrlController.text = 'https://bharattechpulse.in/article/${article.slug}';
    ogTitleController.text = article.title;
    ogDescController.text = article.excerpt;
    ogImageController.text = article.featuredImage;
  }

  void initializeForCreate() {
    editingArticleId = null;
    isEditingMode.value = false;
    editorError.value = '';
    titleController.clear();
    slugController.clear();
    excerptController.clear();
    contentController.clear();
    tagsController.clear();
    featuredImageController.text =
        'https://images.unsplash.com/photo-1518770660439-4636190af475?auto=format&fit=crop&w=1200&q=80';
    altTextController.clear();
    seoTitleController.clear();
    metaDescController.clear();
    canonicalUrlController.clear();
    ogTitleController.clear();
    ogDescController.clear();
    ogImageController.clear();
  }

  void onTitleChanged(String title) {
    if (editingArticleId == null) {
      slugController.text = SlugHelper.toSlug(title);
      seoTitleController.text = title;
      ogTitleController.text = title;
    }
  }

  Future<void> saveArticle({required String newStatus}) async {
    if (editorError.value.isNotEmpty) {
      Get.snackbar('Cannot Save', 'Resolve the editor error before saving.',
          backgroundColor: Colors.red, colorText: Colors.white);
      return;
    }
    status.value = newStatus;
    final title = titleController.text.trim();
    if (title.isEmpty) {
      Get.snackbar('Validation Error', 'Title cannot be empty',
          backgroundColor: Colors.red, colorText: Colors.white);
      return;
    }

    final slug = slugController.text.trim().isNotEmpty
        ? slugController.text.trim()
        : SlugHelper.toSlug(title);

    // Deep links to /admin/articles/create can land before onInit's metadata
    // load finishes; categories.first/authors.first below would then throw.
    if (categories.isEmpty || authors.isEmpty) {
      Get.snackbar('Not Ready Yet', 'Article metadata is still loading. Try again in a moment.',
          backgroundColor: Colors.orange, colorText: Colors.white);
      return;
    }

    final cat = categories.firstWhere(
      (c) => c.slug == selectedCategorySlug.value,
      orElse: () => categories.first,
    );

    final author = authors.firstWhere(
      (a) => a.id == selectedAuthorId.value,
      orElse: () => authors.first,
    );

    final tags = tagsController.text
        .split(',')
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .toList();

    final articleStatus = ArticleStatus.values.firstWhere(
      (s) => s.name == newStatus,
      orElse: () => ArticleStatus.published,
    );

    final article = ArticleModel(
      id: editingArticleId ?? 'art-${DateTime.now().millisecondsSinceEpoch}',
      slug: slug,
      title: title,
      excerpt: excerptController.text.trim(),
      content: contentController.text.trim(),
      categorySlug: cat.slug,
      categoryName: cat.name,
      subcategory: cat.subcategories.isNotEmpty ? cat.subcategories.first : '',
      tags: tags,
      author: author,
      // Scheduled articles surface in feeds sorted by publishedAt, so anchor
      // it to the go-live time rather than the creation moment.
      publishedAt:
          articleStatus == ArticleStatus.scheduled ? scheduleDate.value : publishDate.value,
      updatedAt: DateTime.now(),
      featuredImage: featuredImageController.text.trim(),
      readingTimeMinutes: 5,
      status: articleStatus,
      scheduledFor:
          articleStatus == ArticleStatus.scheduled ? scheduleDate.value : null,
    );

    if (editingArticleId != null) {
      final updated = await articleRepository.updateArticle(article);
      if (!updated) {
        Get.snackbar('Not Found', 'The article being edited no longer exists.',
            backgroundColor: Colors.red, colorText: Colors.white);
        return;
      }
      Get.snackbar('Updated', 'Article updated successfully!',
          backgroundColor: Colors.green, colorText: Colors.white);
    } else {
      await articleRepository.createArticle(article);
      Get.snackbar('Created', 'Article created as $newStatus!',
          backgroundColor: Colors.green, colorText: Colors.white);
    }

    await loadArticlesAndMeta();
    Get.offNamed('/admin/articles');
  }

  Future<void> deleteArticle(String id) async {
    final confirmed = await Get.dialog<bool>(
      AlertDialog(
        title: const Text('Delete Article?'),
        content: const Text(
          'This will permanently remove the article from the database. '
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back<bool>(result: false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Get.back<bool>(result: true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await articleRepository.deleteArticle(id);
    await loadArticlesAndMeta();
    Get.snackbar('Deleted', 'Article removed from database',
        backgroundColor: Colors.grey.shade900, colorText: Colors.white);
  }
}
