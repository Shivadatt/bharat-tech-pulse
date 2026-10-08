import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../shared/components/breadcrumb_widget.dart';
import '../../../shared/components/section_header.dart';
import '../../../shared/layouts/public_scaffold.dart';
import '../../../shared/responsive/responsive_container.dart';
import '../../../shared/responsive/responsive_grid.dart';
import '../../../shared/skeletons/error_state.dart';
import '../../../shared/skeletons/loading_skeleton.dart';
import '../../../shared/widgets/article_card.dart';
import '../controllers/author_controller.dart';

class AuthorView extends GetView<AuthorController> {
  const AuthorView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return PublicScaffold(
      body: Obx(() {
        if (controller.isLoading.value) {
          return const _AuthorLoadingView();
        }

        if (controller.errorMessage.value.isNotEmpty || controller.author.value == null) {
          return ErrorState(
            title: 'Author Not Found',
            message: controller.errorMessage.value.isNotEmpty
                ? controller.errorMessage.value
                : 'Could not load this contributor profile.',
            onRetry: () => controller.loadAuthor(controller.currentSlug),
          );
        }

        final author = controller.author.value!;

        return ResponsiveContainer(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              BreadcrumbWidget(
                items: [
                  const BreadcrumbItem(label: 'Authors', route: '/about'),
                  BreadcrumbItem(label: author.name),
                ],
              ),
              const SizedBox(height: 16),

              // Author Header Profile Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: theme.colorScheme.outline),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 44,
                      backgroundImage: NetworkImage(author.avatarUrl),
                      backgroundColor: theme.colorScheme.primary.withAlpha(50),
                    ),
                    const SizedBox(width: 24),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            author.name,
                            style: theme.textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            author.role,
                            style: theme.textTheme.titleSmall?.copyWith(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            author.bio,
                            style: theme.textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 16),
                          Wrap(
                            spacing: 12,
                            children: [
                              if (author.twitter.isNotEmpty)
                                ActionChip(
                                  avatar: const Icon(Icons.chat_bubble_outline_rounded, size: 14),
                                  label: Text(author.twitter, style: const TextStyle(fontSize: 12)),
                                  onPressed: () {},
                                ),
                              if (author.email.isNotEmpty)
                                ActionChip(
                                  avatar: const Icon(Icons.email_outlined, size: 14),
                                  label: Text(author.email, style: const TextStyle(fontSize: 12)),
                                  onPressed: () {},
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 48),

              // Author Stories
              SectionHeader(
                title: 'Articles by ${author.name}',
                subtitle: 'Published investigations, analysis & buying advice',
                icon: Icons.article_outlined,
              ),

              if (controller.authorArticles.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: Text('No articles published yet by this author.'),
                )
              else
                ResponsiveGrid(
                  desktopColumns: 3,
                  tabletColumns: 2,
                  mobileColumns: 1,
                  children: controller.authorArticles
                      .map((a) => ArticleCard(article: a))
                      .toList(),
                ),

              const SizedBox(height: 56),
            ],
          ),
        );
      }),
    );
  }
}

class _AuthorLoadingView extends StatelessWidget {
  const _AuthorLoadingView();

  @override
  Widget build(BuildContext context) {
    return ResponsiveContainer(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Column(
        children: const [
          LoadingSkeleton(height: 160, borderRadius: 16),
          SizedBox(height: 36),
          LoadingSkeleton(height: 300),
        ],
      ),
    );
  }
}
