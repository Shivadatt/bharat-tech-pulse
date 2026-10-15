import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../layouts/admin_scaffold.dart';
import '../../shared/widgets/admin_state_view.dart';
import '../controllers/admin_trending_controller.dart';

class AdminTrendingView extends GetView<AdminTrendingController> {
  const AdminTrendingView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AdminScaffold(
      title: 'Trending Curation & Algorithm',
      body: Obx(() {
        final posts = controller.posts;
        return AdminStateView(
          isLoading: controller.isLoading.value,
          error: controller.errorMessage.value,
          isEmpty: posts.isEmpty,
          emptyMessage: 'No posts available to curate.',
          onRetry: controller.load,
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // The admin body is ~208-263px wide below 1024px, so the
                      // title must ellipsize beside the refresh button.
                      Flexible(
                        child: Text(
                          'Trending slots: ${controller.trending.length}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Reload trending posts',
                        icon: const Icon(Icons.refresh_rounded),
                        onPressed: controller.load,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Toggle active status to influence real-time algorithmic positioning.',
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 16),
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: posts.length,
                    separatorBuilder: (context, index) => const Divider(),
                    itemBuilder: (context, index) {
                      final art = posts[index];
                      return ListTile(
                        title: Text(art.title,
                            style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text('${art.categoryName} • ${art.viewCount} views'),
                        trailing: Switch(
                          value: art.isTrending,
                          onChanged: (v) => controller.setTrending(art, v),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }
}
