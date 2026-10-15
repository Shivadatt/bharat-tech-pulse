import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../app/config/site_config.dart';
import '../../../../app/routes/app_routes.dart';
import '../../../../core/errors/app_exceptions.dart';
import '../../../../core/supabase/role_permissions.dart';
import '../../../../core/utils/slug_helper.dart';
import '../../../../data/models/article_model.dart';
import '../../../../data/models/author_model.dart';
import '../../../../data/models/category_model.dart';
import '../../../../data/repositories/article_repository.dart';
import '../../../../data/repositories/category_repository.dart';
import '../../auth/controllers/admin_auth_controller.dart';

class AdminArticleController extends GetxController {
  final ArticleRepository articleRepository;
  final CategoryRepository categoryRepository;

  AdminArticleController({
    required this.articleRepository,
    required this.categoryRepository,
  });

  final RxBool isLoading = true.obs;
  // In-flight guard for saveArticle(): a double click on Save Draft /
  // Schedule / Publish would otherwise write two rows for a new post.
  final RxBool isSaving = false.obs;
  final RxnString loadError = RxnString();
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
    loadError.value = null;
    try {
      isLoading.value = true;
      final arts = await articleRepository.getAllArticlesForAdmin();
      articles.assignAll(arts);

      // Admin dropdowns must see archived categories/authors too, or editing a
      // post filed under one silently drops its category/author.
      final cats = await categoryRepository.getCategoriesForAdmin();
      categories.assignAll(cats);

      final auths = await categoryRepository.getAuthorsForAdmin();
      authors.assignAll(auths);
    } on AppException catch (e) {
      // Without this the list view sat on "loading forever" and the failure
      // only surfaced as an unhandled async exception in the console.
      loadError.value = e.message;
    } catch (_) {
      loadError.value = 'Could not load articles. Check the connection and retry.';
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
    seoTitleController.text =
        article.seoTitle.isNotEmpty ? article.seoTitle : article.title;
    metaDescController.text = article.seoDescription.isNotEmpty
        ? article.seoDescription
        : article.excerpt;
    canonicalUrlController.text = article.canonicalUrl.isNotEmpty
        ? article.canonicalUrl
        : '${SiteConfig.domain}/article/${article.slug}';
    ogTitleController.text =
        article.ogTitle.isNotEmpty ? article.ogTitle : article.title;
    ogDescController.text = article.ogDescription.isNotEmpty
        ? article.ogDescription
        : article.excerpt;
    ogImageController.text =
        article.ogImage.isNotEmpty ? article.ogImage : article.featuredImage;
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
    // A first-party, licensed asset. Hotlinking a stock CDN here would ship an
    // unlicensed image into every new post's og:image.
    featuredImageController.text = SiteConfig.defaultOgImage;
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
    // Re-entrant click guard: while a save is in flight, ignore further saves
    // (the toolbar buttons are disabled too, but the controller is the last
    // line of defence against writing duplicate rows).
    if (isSaving.value) return;
    // Anything that puts text in front of readers is an editorial decision:
    // `posts_insert_staff` only accepts an author-tier status='draft' row, so
    // the toolbar hides these actions and this check backs it up.
    if (newStatus != 'draft' &&
        !AdminAuthController.allows(RolePermissions.canPublish)) {
      Get.snackbar(
        'Not authorized',
        'Only editors and admins can publish or schedule a post. Save it as a draft instead.',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return;
    }
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

    // normalize_slug() deliberately returns NULL for a title with no URL-safe
    // characters so callers raise instead of storing an empty slug, which would
    // make the post unreachable and squat the one free '' slug.
    if (slug.isEmpty) {
      Get.snackbar('Slug Needed',
          'This title has no URL-safe characters. Type a slug before saving.',
          backgroundColor: Colors.red, colorText: Colors.white);
      return;
    }

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

    // getArticleBySlug resolves the first match, so a duplicate slug orphans
    // one row from every link, sitemap entry and redirect.
    if (articles.any((a) => a.slug == slug && a.id != editingArticleId)) {
      Get.snackbar('Slug in use',
          'Another article already lives at /article/$slug. Choose a different slug.',
          backgroundColor: Colors.red, colorText: Colors.white);
      return;
    }

    // Curated flags and long-form extras have no editor in the form. Rebuild
    // them from the stored row, otherwise saving a trending or featured post
    // silently un-trends it and drops its FAQ / key-takeaway blocks.
    final current = editingArticleId == null
        ? null
        : articles.firstWhereOrNull((a) => a.id == editingArticleId);

    String orFallback(String typed, String fallback) =>
        typed.trim().isEmpty ? fallback : typed.trim();

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
      // it to the go-live time rather than the creation moment. Editing an
      // already-published post must keep its original publishedAt (it feeds
      // datePublished / article:published_time); publishDate here is merely
      // this controller's construction time. Only a first publish sets it.
      publishedAt: articleStatus == ArticleStatus.scheduled
          ? scheduleDate.value
          : (current != null && current.status == ArticleStatus.published
              ? current.publishedAt
              : publishDate.value),
      updatedAt: DateTime.now(),
      featuredImage: featuredImageController.text.trim(),
      readingTimeMinutes: current?.readingTimeMinutes ?? 5,
      status: articleStatus,
      scheduledFor:
          articleStatus == ArticleStatus.scheduled ? scheduleDate.value : null,
      isFeatured: current?.isFeatured ?? false,
      isTrending: current?.isTrending ?? false,
      isPopular: current?.isPopular ?? false,
      viewCount: current?.viewCount ?? 0,
      keyTakeaways: current?.keyTakeaways ?? const [],
      faqs: current?.faqs ?? const [],
      toc: current?.toc ?? const [],
      seoTitle: orFallback(seoTitleController.text, title),
      seoDescription:
          orFallback(metaDescController.text, excerptController.text.trim()),
      canonicalUrl: orFallback(
          canonicalUrlController.text, '${SiteConfig.domain}/article/$slug'),
      ogTitle: orFallback(ogTitleController.text, title),
      ogDescription: orFallback(
          ogDescController.text, metaDescController.text.trim()),
      ogImage: orFallback(ogImageController.text, featuredImageController.text.trim()),
    );

    isSaving.value = true;
    try {
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
        final created = await articleRepository.createArticle(article);
        // The Supabase row carries a server-generated uuid; keeping the
        // client-minted id would make the next update/delete key off a row
        // that does not exist.
        editingArticleId = created.id;
        Get.snackbar('Created', 'Article created as $newStatus!',
            backgroundColor: Colors.green, colorText: Colors.white);
      }
    } on AppException catch (e) {
      Get.snackbar('Not Saved', e.message,
          backgroundColor: Colors.red, colorText: Colors.white);
      return;
    } catch (_) {
      Get.snackbar('Not Saved', 'The article could not be written to the backend.',
          backgroundColor: Colors.red, colorText: Colors.white);
      return;
    } finally {
      // Runs on every exit path (including the returns above), so the toolbar
      // re-enables whether the write succeeded or failed.
      isSaving.value = false;
    }

    await loadArticlesAndMeta();
    Get.offNamed('/admin/articles');
  }

  Future<void> deleteArticle(String id) async {
    // RLS gate is `posts_delete_site_admin`; refuse even if a stale widget
    // still shows the button or the drawer was built before a role downgrade.
    if (!AdminAuthController.allows(RolePermissions.canDeleteRecords)) {
      Get.snackbar('Not authorized', 'Only site admins can delete articles.',
          backgroundColor: Colors.red, colorText: Colors.white);
      return;
    }
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

    try {
      await articleRepository.deleteArticle(id);
    } on AppException catch (e) {
      Get.snackbar('Not Deleted', e.message,
          backgroundColor: Colors.red, colorText: Colors.white);
      return;
    } catch (_) {
      Get.snackbar('Not Deleted', 'The article could not be removed.',
          backgroundColor: Colors.red, colorText: Colors.white);
      return;
    }
    await loadArticlesAndMeta();
    Get.snackbar('Deleted', 'Article removed from database',
        backgroundColor: Colors.grey.shade900, colorText: Colors.white);
  }
}
