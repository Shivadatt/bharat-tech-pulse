import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../data/models/tag_model.dart';
import '../../layouts/admin_scaffold.dart';
import '../../shared/widgets/admin_state_view.dart';
import '../controllers/admin_tags_controller.dart';

class AdminTagsView extends GetView<AdminTagsController> {
  const AdminTagsView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AdminScaffold(
      title: 'Topic Tags Manager',
      actions: [
        ElevatedButton.icon(
          onPressed: () => _openForm(context),
          icon: const Icon(Icons.add_rounded, size: 18),
          label: const Text('Add Tag'),
        ),
      ],
      body: Obx(() {
        final tags = controller.tags;
        return AdminStateView(
          isLoading: controller.isLoading.value,
          error: controller.errorMessage.value,
          isEmpty: tags.isEmpty,
          emptyMessage: 'No tags yet.',
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
                      Text(
                        'Indexed Tags (${tags.length})',
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        icon: const Icon(Icons.refresh_rounded),
                        onPressed: controller.load,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: tags.map((t) {
                      return Chip(
                        avatar: const Icon(Icons.tag_rounded, size: 14),
                        label: Text('${t.name} (${t.count})'),
                        backgroundColor: theme.colorScheme.surface,
                        deleteIcon: const Icon(Icons.close_rounded, size: 14),
                        onDeleted: () => _confirmDelete(t),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }

  Future<void> _confirmDelete(TagModel t) async {
    final confirmed = await Get.dialog<bool>(
      AlertDialog(
        title: const Text('Delete Tag?'),
        content: Text('Remove "${t.name}" permanently?'),
        actions: [
          TextButton(onPressed: () => Get.back(result: false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Get.back(result: true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) await controller.deleteTag(t.id);
  }

  Future<void> _openForm(BuildContext context) async {
    final nameC = TextEditingController();
    final slugC = TextEditingController();

    Future<void> save() async {
      final draft = TagModel(
        id: '',
        slug: slugC.text.trim().isEmpty
            ? nameC.text.trim().toLowerCase().replaceAll(' ', '-')
            : slugC.text.trim(),
        name: nameC.text.trim(),
      );
      if (await controller.createTag(draft)) Get.back();
    }

    await Get.dialog(
      AlertDialog(
        title: const Text('Add Tag'),
        content: SizedBox(
          width: 320,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameC, decoration: const InputDecoration(labelText: 'Name')),
              const SizedBox(height: 12),
              TextField(controller: slugC, decoration: const InputDecoration(labelText: 'Slug (optional)')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('Cancel')),
          ElevatedButton(onPressed: save, child: const Text('Save')),
        ],
      ),
    );
  }
}
