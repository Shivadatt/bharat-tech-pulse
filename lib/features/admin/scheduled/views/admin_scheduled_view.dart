import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../data/models/article_model.dart';
import '../../../../shared/responsive/responsive_breakpoints.dart';
import '../../layouts/admin_scaffold.dart';
import '../../shared/widgets/admin_state_view.dart';
import '../controllers/admin_scheduled_controller.dart';

class AdminScheduledView extends GetView<AdminScheduledController> {
  const AdminScheduledView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AdminScaffold(
      title: 'Scheduled Publishing Queue',
      body: Obx(() {
        final items = controller.scheduled;
        return AdminStateView(
          isLoading: controller.isLoading.value,
          error: controller.errorMessage.value,
          isEmpty: items.isEmpty,
          emptyMessage: 'Nothing is queued for publishing.',
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
                          'Queued Stories (${items.length})',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Reload scheduled queue',
                        icon: const Icon(Icons.refresh_rounded),
                        onPressed: controller.load,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: items.length,
                    separatorBuilder: (context, index) => const Divider(),
                    itemBuilder: (context, index) {
                      final post = items[index];
                      return ListTile(
                        leading: const Icon(Icons.alarm_on_rounded, color: Colors.purple),
                        title: Text(post.title,
                            style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text(
                          '${post.categoryName} • ${_when(post.scheduledFor)} • '
                          'By ${post.author.name}',
                        ),
                        trailing: _ScheduledActions(
                          post: post,
                          controller: controller,
                          onReschedule: () => _reschedule(post),
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

  String _when(DateTime? at) {
    if (at == null) return 'no date set';
    return '${at.year}-${at.month.toString().padLeft(2, '0')}-'
        '${at.day.toString().padLeft(2, '0')} '
        '${at.hour.toString().padLeft(2, '0')}:'
        '${at.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _reschedule(ArticleModel post) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: Get.context!,
      initialDate: post.scheduledFor ?? now.add(const Duration(days: 1)),
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 365 * 3)),
    );
    if (picked == null) return;
    await controller.reschedule(post, picked);
  }
}

/// 'Reschedule' plus 'Publish now' want ~230px and a ListTile lays its trailing
/// out beside the title, so on a phone the buttons spill past the tile edge and
/// squeeze the title away. Narrow screens fold the same two commands into an
/// overflow menu, like the article manager does.
class _ScheduledActions extends StatelessWidget {
  final ArticleModel post;
  final AdminScheduledController controller;
  final VoidCallback onReschedule;

  const _ScheduledActions({
    required this.post,
    required this.controller,
    required this.onReschedule,
  });

  @override
  Widget build(BuildContext context) {
    if (ResponsiveBreakpoints.isMobileSmall(context)) {
      return PopupMenuButton<String>(
        tooltip: 'Schedule actions',
        icon: const Icon(Icons.more_vert_rounded, size: 20),
        onSelected: (value) {
          switch (value) {
            case 'reschedule':
              onReschedule();
            case 'publish':
              controller.publishNow(post);
          }
        },
        itemBuilder: (context) => const [
          PopupMenuItem<String>(
              value: 'reschedule', child: Text('Reschedule')),
          PopupMenuItem<String>(value: 'publish', child: Text('Publish now')),
        ],
      );
    }

    return Wrap(
      spacing: 6,
      children: [
        OutlinedButton(
          onPressed: onReschedule,
          child: const Text('Reschedule'),
        ),
        TextButton(
          onPressed: () => controller.publishNow(post),
          child: const Text('Publish now'),
        ),
      ],
    );
  }
}
