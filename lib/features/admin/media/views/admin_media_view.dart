import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../data/models/media_model.dart';
import '../../layouts/admin_scaffold.dart';
import '../../shared/widgets/admin_state_view.dart';
import '../controllers/admin_media_controller.dart';

class AdminMediaView extends GetView<AdminMediaController> {
  const AdminMediaView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AdminScaffold(
      title: 'Media Assets & Storage',
      actions: [
        Obx(() => ElevatedButton.icon(
              onPressed: controller.isUploading.value ? null : controller.upload,
              icon: controller.isUploading.value
                  ? const SizedBox(
                      width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.cloud_upload_outlined, size: 18),
              label: const Text('Upload Media'),
            )),
      ],
      body: Obx(() {
        final items = controller.items;
        return AdminStateView(
          isLoading: controller.isLoading.value && items.isEmpty,
          error: controller.errorMessage.value,
          isEmpty: items.isEmpty,
          emptyMessage: 'No media uploaded yet.',
          onRetry: controller.load,
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Media Library',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 4,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                    ),
                    itemCount: items.length,
                    itemBuilder: (context, index) => _MediaTile(item: items[index]),
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

class _MediaTile extends StatelessWidget {
  final MediaModel item;
  const _MediaTile({required this.item});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.network(
            item.publicUrl,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) =>
                Container(color: Colors.grey.shade300, child: const Icon(Icons.broken_image)),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              color: Colors.black54,
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      item.fileName,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontSize: 10),
                    ),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    iconSize: 16,
                    color: Colors.white,
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: () => _editAlt(context),
                  ),
                  const SizedBox(width: 6),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    iconSize: 16,
                    color: Colors.white,
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () =>
                        Get.find<AdminMediaController>().deleteMedia(item.id),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _editAlt(BuildContext context) async {
    final c = TextEditingController(text: item.altText ?? '');
    await Get.dialog(
      AlertDialog(
        title: const Text('Alt text'),
        content: TextField(
          controller: c,
          maxLines: 2,
          decoration: const InputDecoration(labelText: 'Accessibility description'),
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Get.find<AdminMediaController>().updateAltText(item.id, c.text.trim());
              Get.back();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
