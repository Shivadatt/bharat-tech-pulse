import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../../shared/components/breadcrumb_widget.dart';
import '../../../shared/components/section_header.dart';
import '../../../shared/layouts/public_scaffold.dart';
import '../../../shared/responsive/responsive_breakpoints.dart';
import '../../../shared/responsive/responsive_container.dart';
import '../../../shared/responsive/responsive_grid.dart';
import '../../../shared/skeletons/error_state.dart';
import '../../../shared/skeletons/loading_skeleton.dart';
import '../../../shared/widgets/article_card.dart';
import '../../../shared/widgets/author_avatar.dart';
import '../controllers/author_controller.dart';

class AuthorView extends StatefulWidget {
  const AuthorView({super.key});

  @override
  State<AuthorView> createState() => _AuthorViewState();
}

class _AuthorViewState extends State<AuthorView> {
  AuthorController get controller => Get.find<AuthorController>();

  @override
  void initState() {
    super.initState();
    // GetX keeps the type-keyed controller alive across author routes, so
    // moving profile-to-profile would otherwise reuse the first profile.
    controller.ensureCurrentRouteLoaded();
  }

  void _copyEmail(String email) {
    Clipboard.setData(ClipboardData(text: email));
    Get.snackbar(
      'Email Copied',
      '$email copied to your clipboard.',
      snackPosition: SnackPosition.BOTTOM,
      duration: const Duration(seconds: 2),
      margin: const EdgeInsets.all(16),
      maxWidth: 400,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // GetX can hand the same page object to a different `/author/:slug` URL, in
    // which case `initState` never re-runs and the previous profile stays on
    // screen under the new URL.
    if (controller.currentSlug.isNotEmpty &&
        controller.currentSlug != controller.loadedSlug) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) controller.ensureCurrentRouteLoaded();
      });
    }

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
                  BreadcrumbItem(label: author.name),
                ],
              ),
              const SizedBox(height: 16),

              // Author Header Profile Card
              Builder(builder: (context) {
                // An 88px avatar plus a 24px gap inside 32px of padding leaves
                // ~104px of text column on a 320px phone, which the email chip
                // cannot fit. Stack vertically instead.
                final compact = ResponsiveBreakpoints.isMobileSmall(context);
                final avatar = AuthorAvatar(
                  name: author.name,
                  avatarUrl: author.avatarUrl,
                  radius: compact ? 32 : 44,
                );
                final details = Column(
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
                      runSpacing: 8,
                      children: [
                        // No url_launcher in this project: the handle is a
                        // display-only chip so it never advertises a dead link.
                        if (author.twitter.isNotEmpty)
                          Chip(
                            avatar: const Icon(Icons.chat_bubble_outline_rounded, size: 14),
                            label: Text(author.twitter,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 12)),
                          ),
                        if (author.email.isNotEmpty)
                          ActionChip(
                            avatar: const Icon(Icons.email_outlined, size: 14),
                            label: Text(author.email,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 12)),
                            onPressed: () => _copyEmail(author.email),
                          ),
                      ],
                    ),
                  ],
                );

                return Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(compact ? 16 : 32),
                  decoration: BoxDecoration(
                    color: theme.cardColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: theme.colorScheme.outline),
                  ),
                  child: compact
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            avatar,
                            const SizedBox(height: 16),
                            details,
                          ],
                        )
                      : Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            avatar,
                            const SizedBox(width: 24),
                            Expanded(child: details),
                          ],
                        ),
                );
              }),

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
