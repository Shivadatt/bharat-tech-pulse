import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../shared/components/breadcrumb_widget.dart';
import '../../../shared/components/newsletter_card.dart';
import '../../../shared/components/section_header.dart';
import '../../../shared/layouts/content_with_sidebar.dart';
import '../../../shared/layouts/public_scaffold.dart';
import '../../../shared/responsive/responsive_container.dart';
import '../../../shared/responsive/responsive_grid.dart';
import '../../../shared/skeletons/empty_state.dart';
import '../../../shared/skeletons/error_state.dart';
import '../../../shared/skeletons/loading_skeleton.dart';
import '../../../shared/widgets/article_card.dart';
import '../../../shared/widgets/featured_article_card.dart';
import '../../../shared/widgets/popular_article_card.dart';
import '../../../shared/widgets/trending_card.dart';
import '../controllers/category_controller.dart';

class CategoryView extends GetView<CategoryController> {
  const CategoryView({super.key});

  @override
  Widget build(BuildContext context) {
    return PublicScaffold(
      body: Obx(() {
        if (controller.isLoading.value) {
          return const _CategoryLoading();
        }

        if (controller.errorMessage.value.isNotEmpty) {
          return ErrorState(
            message: controller.errorMessage.value,
            onRetry: () => controller.loadCategory(controller.currentSlug),
          );
        }

        final cat = controller.category.value;
        final title = cat?.name ?? 'Category';
        final description = cat?.description ?? '';
        final subcategories = cat?.subcategories ?? [];

        return ResponsiveContainer(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Breadcrumb
              BreadcrumbWidget(
                items: [
                  BreadcrumbItem(label: title),
                ],
              ),
              const SizedBox(height: 12),

              // Category Header Banner
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Theme.of(context).colorScheme.primary.withAlpha(20),
                      Theme.of(context).cardColor,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Theme.of(context).colorScheme.outline),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.displayMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 10),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 800),
                      child: Text(
                        description,
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ),
                    if (subcategories.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: subcategories.map((sub) {
                          final isSelected =
                              controller.selectedSubcategory.value == sub;
                          return ChoiceChip(
                            label: Text(sub),
                            selected: isSelected,
                            onSelected: (_) => controller.filterSubcategory(sub),
                            selectedColor: Theme.of(context).colorScheme.primary,
                            labelStyle: TextStyle(
                              color: isSelected ? Colors.white : null,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                              fontSize: 12,
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 40),

              // Featured Article in Category
              if (controller.featuredArticle.value != null &&
                  controller.selectedSubcategory.value.isEmpty) ...[
                FeaturedArticleCard(article: controller.featuredArticle.value!),
                const SizedBox(height: 48),
              ],

              // Content & Sidebar
              ContentWithSidebar(
                content: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SectionHeader(
                      title: 'Latest in $title',
                      icon: Icons.grid_view_rounded,
                    ),
                    if (controller.filteredArticles.isEmpty)
                      const EmptyState(
                        title: 'No Articles Under This Subcategory',
                        message: 'Try switching to another subcategory filter above.',
                      )
                    else
                      ResponsiveGrid(
                        desktopColumns: 2,
                        tabletColumns: 2,
                        mobileColumns: 1,
                        children: controller.filteredArticles
                            .map((a) => ArticleCard(article: a))
                            .toList(),
                      ),
                  ],
                ),
                sidebar: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SectionHeader(
                      title: 'Trending',
                      icon: Icons.trending_up_rounded,
                    ),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Theme.of(context).colorScheme.outline),
                      ),
                      child: Column(
                        children: [
                          for (int i = 0; i < controller.trendingArticles.length; i++) ...[
                            TrendingCard(
                              rank: i + 1,
                              article: controller.trendingArticles[i],
                            ),
                            if (i < controller.trendingArticles.length - 1) const Divider(),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                    SectionHeader(
                      title: 'Most Read',
                      icon: Icons.local_fire_department_rounded,
                    ),
                    ...controller.popularArticles
                        .map((a) => PopularArticleCard(article: a)),
                    const SizedBox(height: 32),
                    const NewsletterCard(compact: true),
                  ],
                ),
              ),
              const SizedBox(height: 48),
            ],
          ),
        );
      }),
    );
  }
}

class _CategoryLoading extends StatelessWidget {
  const _CategoryLoading();

  @override
  Widget build(BuildContext context) {
    return ResponsiveContainer(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          LoadingSkeleton(width: 200, height: 20),
          SizedBox(height: 24),
          LoadingSkeleton(height: 140, borderRadius: 16),
          SizedBox(height: 36),
          LoadingSkeleton(height: 360, borderRadius: 20),
        ],
      ),
    );
  }
}
