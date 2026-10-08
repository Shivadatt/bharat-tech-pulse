import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../shared/components/newsletter_card.dart';
import '../../../shared/components/section_header.dart';
import '../../../shared/layouts/content_with_sidebar.dart';
import '../../../shared/layouts/public_scaffold.dart';
import '../../../shared/responsive/responsive_container.dart';
import '../../../shared/responsive/responsive_grid.dart';
import '../../../shared/skeletons/error_state.dart';
import '../../../shared/skeletons/loading_skeleton.dart';
import '../../../shared/widgets/article_card.dart';
import '../../../shared/widgets/featured_article_card.dart';
import '../../../shared/widgets/popular_article_card.dart';
import '../../../shared/widgets/trending_card.dart';
import '../controllers/home_controller.dart';

class HomeView extends GetView<HomeController> {
  const HomeView({super.key});

  @override
  Widget build(BuildContext context) {
    return PublicScaffold(
      body: Obx(() {
        if (controller.isLoading.value) {
          return const _HomeLoadingView();
        }

        if (controller.errorMessage.value.isNotEmpty) {
          return ErrorState(
            message: controller.errorMessage.value,
            onRetry: controller.loadHomeData,
          );
        }

        return ResponsiveContainer(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Hero / Featured Article
              if (controller.featuredArticle.value != null) ...[
                FeaturedArticleCard(article: controller.featuredArticle.value!),
                const SizedBox(height: 48),
              ],

              // 2. Trending Now & Sidebar layout
              ContentWithSidebar(
                content: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 3. Latest Technology
                    SectionHeader(
                      title: 'Latest Technology',
                      subtitle: 'Fresh stories, hardware teardowns & digital updates',
                      icon: Icons.flash_on_rounded,
                      actionLabel: 'View All News',
                      onActionTap: () => Get.toNamed('/tech-news/'),
                    ),
                    ResponsiveGrid(
                      desktopColumns: 2,
                      tabletColumns: 2,
                      mobileColumns: 1,
                      children: controller.latestArticles
                          .map((a) => ArticleCard(article: a))
                          .toList(),
                    ),
                  ],
                ),
                sidebar: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SectionHeader(
                      title: 'Trending Now',
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
                    // 11. Newsletter in sidebar
                    const NewsletterCard(compact: true),
                  ],
                ),
              ),

              const SizedBox(height: 56),

              // 4. AI & AI Tools
              SectionHeader(
                title: 'AI & Indic Tools',
                subtitle: 'Sovereign LLMs, conversational agents & productivity workflows',
                icon: Icons.psychology_rounded,
                actionLabel: 'Explore AI Hub',
                onActionTap: () => Get.toNamed('/ai/'),
              ),
              ResponsiveGrid(
                desktopColumns: 3,
                tabletColumns: 2,
                mobileColumns: 1,
                children: controller.aiArticles
                    .map((a) => ArticleCard(article: a))
                    .toList(),
              ),

              const SizedBox(height: 56),

              // 5. Apps Ecosystem
              SectionHeader(
                title: 'Apps & UPI Ecosystem',
                subtitle: 'Fintech advancements, ONDC utilities & citizen software',
                icon: Icons.apps_rounded,
                actionLabel: 'View All Apps',
                onActionTap: () => Get.toNamed('/apps/'),
              ),
              ResponsiveGrid(
                desktopColumns: 3,
                tabletColumns: 2,
                mobileColumns: 1,
                children: controller.appArticles
                    .map((a) => ArticleCard(article: a))
                    .toList(),
              ),

              const SizedBox(height: 56),

              // 6. How-To Guides
              SectionHeader(
                title: 'Verified How-To Guides',
                subtitle: 'DigiLocker, IRCTC booking, Aadhaar security & digital tricks',
                icon: Icons.menu_book_rounded,
                actionLabel: 'All How-To Guides',
                onActionTap: () => Get.toNamed('/how-to/'),
              ),
              ResponsiveGrid(
                desktopColumns: 3,
                tabletColumns: 2,
                mobileColumns: 1,
                children: controller.howToArticles
                    .map((a) => ArticleCard(article: a))
                    .toList(),
              ),

              const SizedBox(height: 56),

              // 7. Smartphones
              SectionHeader(
                title: 'Smartphones & Hardware',
                subtitle: 'Real Indian benchmarks, thermal stability & battery tests',
                icon: Icons.phone_android_rounded,
                actionLabel: 'All Phone Reviews',
                onActionTap: () => Get.toNamed('/smartphones/'),
              ),
              ResponsiveGrid(
                desktopColumns: 3,
                tabletColumns: 2,
                mobileColumns: 1,
                children: controller.smartphoneArticles
                    .map((a) => ArticleCard(article: a))
                    .toList(),
              ),

              const SizedBox(height: 56),

              // 8. Comparisons & 9. Cyber Safety Showdown
              ContentWithSidebar(
                content: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SectionHeader(
                      title: 'Comparisons & Showdowns',
                      subtitle: 'Head-to-head testing for Indian consumers',
                      icon: Icons.compare_arrows_rounded,
                      actionLabel: 'More Comparisons',
                      onActionTap: () => Get.toNamed('/comparisons/'),
                    ),
                    ResponsiveGrid(
                      desktopColumns: 2,
                      tabletColumns: 2,
                      mobileColumns: 1,
                      children: controller.comparisonArticles
                          .map((a) => ArticleCard(article: a))
                          .toList(),
                    ),
                  ],
                ),
                sidebar: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SectionHeader(
                      title: 'Cyber Safety Alerts',
                      subtitle: 'Digital arrest alerts & 1930 reporting',
                      icon: Icons.security_rounded,
                      actionLabel: 'Safety Hub',
                      onActionTap: () => Get.toNamed('/cyber-safety/'),
                    ),
                    Column(
                      children: controller.cyberSafetyArticles
                          .map((a) => Padding(
                                padding: const EdgeInsets.only(bottom: 16),
                                child: ArticleCard(article: a),
                              ))
                          .toList(),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 56),

              // 10. Popular Articles
              SectionHeader(
                title: 'Most Read Across India',
                subtitle: 'The stories readers spent the most time on this month',
                icon: Icons.local_fire_department_rounded,
              ),
              ResponsiveGrid(
                desktopColumns: 2,
                tabletColumns: 2,
                mobileColumns: 1,
                children: controller.popularArticles
                    .map((a) => PopularArticleCard(article: a))
                    .toList(),
              ),

              const SizedBox(height: 56),

              // 11. Full-width Newsletter Banner
              const NewsletterCard(),
              const SizedBox(height: 48),
            ],
          ),
        );
      }),
    );
  }
}

class _HomeLoadingView extends StatelessWidget {
  const _HomeLoadingView();

  @override
  Widget build(BuildContext context) {
    return ResponsiveContainer(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Column(
        children: const [
          LoadingSkeleton(height: 380, borderRadius: 20),
          SizedBox(height: 36),
          Row(
            children: [
              Expanded(child: LoadingSkeleton(height: 240, borderRadius: 14)),
              SizedBox(width: 20),
              Expanded(child: LoadingSkeleton(height: 240, borderRadius: 14)),
            ],
          ),
        ],
      ),
    );
  }
}
