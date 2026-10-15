import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../../../core/supabase/role_permissions.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../data/models/article_model.dart';
import '../../../../shared/responsive/responsive_breakpoints.dart';
import '../../auth/controllers/admin_auth_controller.dart';
import '../../layouts/admin_scaffold.dart';
import '../controllers/admin_article_controller.dart';

bool _isPubliclyVisible(ArticleModel art) {
  final now = DateTime.now();
  return art.status == ArticleStatus.published ||
      (art.status == ArticleStatus.scheduled &&
          art.scheduledFor != null &&
          !art.scheduledFor!.isAfter(now));
}

class AdminArticlesListView extends GetView<AdminArticleController> {
  const AdminArticlesListView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AdminScaffold(
      title: 'Article Manager',
      actions: [
        ElevatedButton.icon(
          onPressed: () {
            controller.initializeForCreate();
            Get.toNamed('/admin/articles/create');
          },
          icon: const Icon(Icons.add_rounded, size: 18),
          label: const Text('New Article'),
        ),
      ],
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        'All Articles (${controller.articles.length})',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh_rounded),
                      onPressed: controller.loadArticlesAndMeta,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: controller.articles.length,
                  separatorBuilder: (context, index) => const Divider(),
                  itemBuilder: (context, index) {
                    final art = controller.articles[index];
                    final thumbUrl = art.featuredImage.trim();
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        // Drafts saved without a featured image hand over '',
                        // and Image.network('') throws while resolving rather
                        // than through errorBuilder.
                        child: thumbUrl.isEmpty
                            ? SizedBox(
                                width: 60,
                                height: 48,
                                child: ColoredBox(color: Colors.grey.shade300),
                              )
                            : Image.network(
                                thumbUrl,
                                width: 60,
                                height: 48,
                                fit: BoxFit.cover,
                                cacheWidth: 120,
                                cacheHeight: 96,
                                errorBuilder: (context, error, stackTrace) => Container(
                                    width: 60, height: 48, color: Colors.grey),
                              ),
                      ),
                      title: Text(
                        art.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                      ),
                      subtitle: Text(
                        '${art.categoryName} • by ${art.author.name} • ${DateFormatter.formatShort(art.publishedAt)} • ${NumberFormat.compact().format(art.viewCount)} reads',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.textTheme.bodySmall?.color,
                        ),
                      ),
                      trailing: _ArticleActions(art: art, controller: controller),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      }),
    );
  }
}

/// Per-article actions. The chip plus three icon buttons want ~220px, and a
/// Row child inside ListTile is laid out with unbounded width, so on a
/// 320-375px phone it overflows the tile. Narrow layouts fold the same three
/// commands into an overflow menu instead of dropping functionality.
class _ArticleActions extends StatelessWidget {
  final ArticleModel art;
  final AdminArticleController controller;

  const _ArticleActions({required this.art, required this.controller});

  @override
  Widget build(BuildContext context) {
    final canPreview = _isPubliclyVisible(art);
    // Hard delete is `posts_delete_site_admin` under RLS: authors and editors
    // see no button, and AdminArticleController.deleteArticle refuses too.
    final canDelete =
        AdminAuthController.allows(RolePermissions.canDeleteRecords);
    void edit() {
      controller.initializeForEdit(art.id);
      Get.toNamed('/admin/articles/edit/${art.id}');
    }

    if (ResponsiveBreakpoints.isMobileSmall(context)) {
      return PopupMenuButton<String>(
        tooltip: 'Article actions',
        icon: const Icon(Icons.more_vert_rounded, size: 20),
        onSelected: (value) {
          switch (value) {
            case 'preview':
              if (canPreview) Get.toNamed('/article/${art.slug}');
            case 'edit':
              edit();
            case 'delete':
              if (canDelete) controller.deleteArticle(art.id);
          }
        },
        itemBuilder: (context) => [
          PopupMenuItem<String>(
            enabled: canPreview,
            value: 'preview',
            child: const Text('Preview Live'),
          ),
          const PopupMenuItem<String>(value: 'edit', child: Text('Edit Article')),
          if (canDelete)
            const PopupMenuItem<String>(value: 'delete', child: Text('Delete')),
        ],
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _StatusChip(status: art.status),
        const SizedBox(width: 8),
        IconButton(
          icon: const Icon(Icons.open_in_new_rounded, size: 18),
          tooltip: canPreview ? 'Preview Live' : 'Not visible on the live site yet',
          onPressed: canPreview ? () => Get.toNamed('/article/${art.slug}') : null,
        ),
        IconButton(
          icon: const Icon(Icons.edit_outlined, size: 18),
          tooltip: 'Edit Article',
          onPressed: edit,
        ),
        if (canDelete)
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.red),
            tooltip: 'Delete',
            onPressed: () => controller.deleteArticle(art.id),
          ),
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  final ArticleStatus status;

  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final (String label, MaterialColor color) = switch (status) {
      ArticleStatus.published => ('Published', Colors.green),
      ArticleStatus.scheduled => ('Scheduled', Colors.orange),
      ArticleStatus.draft => ('Draft', Colors.grey),
      ArticleStatus.archived => ('Archived', Colors.blueGrey),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withAlpha(30),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color.shade700,
        ),
      ),
    );
  }
}
