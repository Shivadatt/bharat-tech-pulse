import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../shared/responsive/responsive_grid.dart';
import '../../layouts/admin_scaffold.dart';
import '../../shared/widgets/admin_state_view.dart';
import '../controllers/admin_analytics_controller.dart';

class AdminAnalyticsView extends GetView<AdminAnalyticsController> {
  const AdminAnalyticsView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AdminScaffold(
      title: 'Audience & Engagement Analytics',
      body: Obx(() {
        final summary = controller.summary.value;
        return AdminStateView(
          isLoading: controller.isLoading.value,
          error: controller.errorMessage.value,
          isEmpty: summary == null || !summary.hasAccess,
          emptyMessage: controller.errorMessage.value ??
              'Analytics are available to site editors and above.',
          onRetry: controller.load,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ResponsiveGrid(
                desktopColumns: 4,
                tabletColumns: 2,
                mobileColumns: 1,
                children: [
                  _StatTile(label: 'Page Views', val: _fmt(summary?.pageViews), color: Colors.cyan),
                  _StatTile(label: 'Article Views', val: _fmt(summary?.articleViews), color: Colors.green),
                  _StatTile(label: 'Unique Sessions', val: _fmt(summary?.uniqueSessions), color: Colors.purple),
                  _StatTile(label: 'Subscribers', val: _fmt(summary?.subscribers), color: Colors.orange),
                ],
              ),
              const SizedBox(height: 24),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Most-read Posts',
                            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          IconButton(
                            icon: const Icon(Icons.refresh_rounded),
                            onPressed: controller.load,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (summary == null || summary.topPosts.isEmpty)
                        Text('No post activity recorded yet.', style: theme.textTheme.bodySmall)
                      else
                        for (final post in summary.topPosts)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(post.title,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontWeight: FontWeight.w500)),
                                ),
                                Text('${post.viewCount} reads',
                                    style: const TextStyle(fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 48),
            ],
          ),
        );
      }),
    );
  }

  String _fmt(int? value) => value == null ? '—' : value.toString();
}

class _StatTile extends StatelessWidget {
  final String label;
  final String val;
  final Color color;

  const _StatTile({required this.label, required this.val, required this.color});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: TextStyle(
                    fontSize: 12, color: Theme.of(context).textTheme.bodySmall?.color)),
            const SizedBox(height: 8),
            Text(val,
                style: TextStyle(
                    fontSize: 28, fontWeight: FontWeight.w800, color: color)),
          ],
        ),
      ),
    );
  }
}
