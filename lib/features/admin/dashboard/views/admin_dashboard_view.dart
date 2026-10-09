import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../data/models/article_model.dart';
import '../../../../shared/responsive/responsive_grid.dart';
import '../../layouts/admin_scaffold.dart';
import '../controllers/admin_dashboard_controller.dart';

class AdminDashboardView extends GetView<AdminDashboardController> {
  const AdminDashboardView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final numFormat = NumberFormat.compact();

    return AdminScaffold(
      title: 'Dashboard Overview',
      actions: [
        ElevatedButton.icon(
          onPressed: () => Get.toNamed('/admin/articles/create'),
          icon: const Icon(Icons.add_rounded, size: 18),
          label: const Text('New Article'),
        ),
      ],
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Surface a real backend error instead of silently showing zeros.
            if (controller.errorMessage.value != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                margin: const EdgeInsets.only(bottom: 24),
                decoration: BoxDecoration(
                  color: Colors.red.withAlpha(25),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.withAlpha(100)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline_rounded,
                        color: Colors.red, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        controller.errorMessage.value!,
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w500),
                      ),
                    ),
                    TextButton(
                      onPressed: controller.loadDashboardMetrics,
                      child: const Text('Retry', style: TextStyle(fontSize: 12)),
                    ),
                  ],
                ),
              ),

            // Top Metric Cards (Total, Published, Drafts, Scheduled, Views)
            ResponsiveGrid(
              desktopColumns: 5,
              tabletColumns: 3,
              mobileColumns: 2,
              children: [
                _MetricCard(
                  title: 'Total Articles',
                  value: controller.totalArticles.value.toString(),
                  icon: Icons.article_rounded,
                  color: theme.colorScheme.primary,
                ),
                _MetricCard(
                  title: 'Published',
                  value: controller.publishedArticles.value.toString(),
                  icon: Icons.check_circle_outline_rounded,
                  color: Colors.green,
                ),
                _MetricCard(
                  title: 'Drafts',
                  value: controller.draftArticles.value.toString(),
                  icon: Icons.edit_note_rounded,
                  color: Colors.orange,
                ),
                _MetricCard(
                  title: 'Scheduled',
                  value: controller.scheduledArticles.value.toString(),
                  icon: Icons.schedule_rounded,
                  color: Colors.purple,
                ),
                _MetricCard(
                  title: 'Total Reads',
                  value: numFormat.format(controller.totalViews.value),
                  icon: Icons.visibility_outlined,
                  color: Colors.blueAccent,
                ),
              ],
            ),
            const SizedBox(height: 36),

            // 2 Column Section: Recent Articles & Top Performing
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 900;
                final recentSection = _buildRecentArticlesCard(theme);
                final topSection = _buildTopArticlesCard(theme);

                if (!isWide) {
                  return Column(
                    children: [
                      recentSection,
                      const SizedBox(height: 24),
                      topSection,
                    ],
                  );
                }

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 3, child: recentSection),
                    const SizedBox(width: 24),
                    Expanded(flex: 2, child: topSection),
                  ],
                );
              },
            ),

            const SizedBox(height: 36),

            // Publishing Activity Log Card
            _buildActivityLogCard(theme),
            const SizedBox(height: 40),
          ],
        );
      }),
    );
  }

  Widget _buildRecentArticlesCard(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Recent Editorial Stories',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                TextButton(
                  onPressed: () => Get.toNamed('/admin/articles'),
                  child: const Text('View All', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: controller.recentArticles.length,
              separatorBuilder: (context, index) => const Divider(),
              itemBuilder: (context, index) {
                final art = controller.recentArticles[index];
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Image.network(art.featuredImage,
                        width: 50,
                        height: 40,
                        fit: BoxFit.cover,
                        cacheWidth: 100,
                        cacheHeight: 80),
                  ),
                  title: Text(
                    art.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  subtitle: Text(
                    '${art.categoryName} • ${DateFormatter.formatShort(art.publishedAt)}',
                    style: TextStyle(fontSize: 11, color: theme.textTheme.bodySmall?.color),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    onPressed: () => Get.toNamed('/admin/articles/edit/${art.id}'),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopArticlesCard(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Top Performing Stories',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: controller.topArticles.length,
              separatorBuilder: (context, index) => const Divider(),
              itemBuilder: (context, index) {
                final art = controller.topArticles[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      Text(
                        '#${index + 1}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          art.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${NumberFormat.compact().format(art.viewCount)} reads',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: theme.textTheme.bodySmall?.color,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityLogCard(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Publishing Activity',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            if (controller.recentArticles.isEmpty)
              Text('No recent activity.', style: theme.textTheme.bodySmall)
            else
              for (final art in controller.recentArticles)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: _ActivityItem(
                    time: DateFormatter.formatShort(art.publishedAt),
                    user: art.author.name.isEmpty ? 'Editorial' : art.author.name,
                    action: _statusVerb(art.status),
                    target: art.title,
                  ),
                ),
          ],
        ),
      ),
    );
  }

  static String _statusVerb(ArticleStatus status) {
    switch (status) {
      case ArticleStatus.published:
        return 'published';
      case ArticleStatus.scheduled:
        return 'scheduled';
      case ArticleStatus.draft:
        return 'drafted';
      case ArticleStatus.archived:
        return 'archived';
    }
  }
}

class _MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _MetricCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).textTheme.bodySmall?.color,
                  ),
                ),
                Icon(icon, size: 18, color: color),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActivityItem extends StatelessWidget {
  final String time;
  final String user;
  final String action;
  final String target;

  const _ActivityItem({
    required this.time,
    required this.user,
    required this.action,
    required this.target,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          const Icon(Icons.circle, size: 8, color: Colors.cyan),
          const SizedBox(width: 10),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).textTheme.bodyLarge?.color,
                ),
                children: [
                  TextSpan(text: '$user ', style: const TextStyle(fontWeight: FontWeight.bold)),
                  TextSpan(text: '$action '),
                  TextSpan(text: '"$target"', style: const TextStyle(fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ),
          Text(
            time,
            style: TextStyle(
              fontSize: 11,
              color: Theme.of(context).textTheme.bodySmall?.color,
            ),
          ),
        ],
      ),
    );
  }
}
