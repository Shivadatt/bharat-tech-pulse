import 'package:flutter/material.dart';
import 'package:get/get.dart';
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

  void initializeForEdit(String id) {
    editingArticleId = id;
    final article = articles.firstWhereOrNull((a) => a.id == id);
    if (article != null) {
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
  }

  void initializeForCreate() {
    editingArticleId = null;
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
      publishedAt: publishDate.value,
      updatedAt: DateTime.now(),
      featuredImage: featuredImageController.text.trim(),
      readingTimeMinutes: 5,
    );

    if (editingArticleId != null) {
      await articleRepository.updateArticle(article);
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
    await articleRepository.deleteArticle(id);
    await loadArticlesAndMeta();
    Get.snackbar('Deleted', 'Article removed from database',
        backgroundColor: Colors.grey.shade900, colorText: Colors.white);
  }
}
