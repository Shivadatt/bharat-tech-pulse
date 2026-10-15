import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:india_tech_web/app/app.dart';
import 'package:india_tech_web/app/bindings/initial_binding.dart';
import 'package:india_tech_web/data/repositories/mock_article_repository.dart';
import 'package:india_tech_web/data/repositories/mock_category_repository.dart';
import 'package:india_tech_web/features/articles/controllers/article_controller.dart';
import 'package:india_tech_web/features/authors/controllers/author_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// GetX keys controllers by type, so one `ArticleController` instance serves
/// every `/article/:slug` route. These tests pin the regression where a second
/// article route reused the first article's body, canonical and analytics
/// beacon.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> boot(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    Get.reset();
    InitialBinding().dependencies();
    await tester.pumpWidget(const BharatTechApp());
    await tester.pump(const Duration(milliseconds: 400));
  }

  // The mock repositories resolve after a short delay; fixed pumps advance the
  // fake clock without pumpAndSettle blocking on still-running animations.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 300));
    }
  }

  testWidgets('article-to-article navigation replaces the loaded article',
      (tester) async {
    final seeded = await MockArticleRepository().getLatestArticles(limit: 2);
    expect(seeded.length, greaterThan(1));
    final first = seeded.first.slug;
    final second = seeded[1].slug;

    await boot(tester);
    Get.toNamed('/article/$first');
    await settle(tester);

    final controller = Get.find<ArticleController>();
    expect(controller.article.value?.slug, first);

    Get.toNamed('/article/$second');
    await settle(tester);

    expect(controller.currentSlug, second);
    expect(controller.article.value?.slug, second,
        reason: 'the second URL must not render the first article');
    expect(controller.isLoading.value, false);
  });

  testWidgets('author-to-author navigation replaces the loaded author',
      (tester) async {
    final authors = await MockCategoryRepository().getAuthors();
    expect(authors.length, greaterThan(1));
    final first = authors.first.slug;
    final second = authors[1].slug;

    await boot(tester);
    Get.toNamed('/author/$first');
    await settle(tester);

    final controller = Get.find<AuthorController>();
    expect(controller.author.value?.slug, first);

    Get.toNamed('/author/$second');
    await settle(tester);

    expect(controller.currentSlug, second);
    expect(controller.author.value?.slug, second,
        reason: 'the second URL must not render the first profile');
  });

  testWidgets('a superseded article load cannot paint over the current route',
      (tester) async {
    final seeded = await MockArticleRepository().getLatestArticles(limit: 2);
    final first = seeded.first.slug;
    final second = seeded[1].slug;

    await boot(tester);
    // Both navigations happen before either repository call resolves, so the
    // first response arrives after the reader is already on the second URL.
    Get.toNamed('/article/$first');
    Get.toNamed('/article/$second');
    await settle(tester);

    expect(Get.find<ArticleController>().article.value?.slug, second);
  });
}
