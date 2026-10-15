import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/supabase/role_permissions.dart';
import '../../../../data/models/media_model.dart';
import '../../../../shared/responsive/responsive_breakpoints.dart';
import '../../auth/controllers/admin_auth_controller.dart';
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
        if (AdminAuthController.allows(RolePermissions.canManageContent))
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
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final columns =
                          (constraints.maxWidth / 150).floor().clamp(2, 6);
                      return GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: columns,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                        ),
                        itemCount: items.length,
                        itemBuilder: (context, index) =>
                            _MediaTile(item: items[index]),
                      );
                    },
                  ),
                  if (controller.hasMore.value) ...[
                    const SizedBox(height: 16),
                    Center(
                      child: OutlinedButton.icon(
                        onPressed: controller.isLoading.value
                            ? null
                            : controller.loadMore,
                        icon: const Icon(Icons.expand_more_rounded, size: 18),
                        label: const Text('Load more assets'),
                      ),
                    ),
                  ],
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
    // `media_insert/update/delete_site_editor` — editors and above, i.e. one tier wider than
    // the site-admin gate on content deletes.
    final canManage =
        AdminAuthController.allows(RolePermissions.canManageContent);
    final fallback = Container(
      color: Colors.grey.shade300,
      child: const Icon(Icons.broken_image),
    );
    final url = item.publicUrl.trim();
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // A media row can carry a blank public_url, and Image.network('')
          // throws while resolving rather than through errorBuilder.
          if (url.isEmpty)
            fallback
          else
            Image.network(
              url,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => fallback,
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
                  if (canManage) ...[
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      iconSize: 16,
                      color: Colors.white,
                      icon: const Icon(Icons.edit_outlined),
                      onPressed: _editAlt,
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
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _editAlt() async {
    // A second dialog stacked over this one would keep two alt-text controllers
    // alive at once and save onto whichever tile was tapped last.
    if (_altDialogOpen) return;
    _altDialogOpen = true;
    try {
      await Get.dialog(_AltTextDialog(item: item));
    } finally {
      _altDialogOpen = false;
    }
  }
}

bool _altDialogOpen = false;

/// Owns its controller so the text field is unmounted before it is disposed,
/// instead of leaking one controller per dialog opened.
class _AltTextDialog extends StatefulWidget {
  final MediaModel item;

  const _AltTextDialog({required this.item});

  @override
  State<_AltTextDialog> createState() => _AltTextDialogState();
}

class _AltTextDialogState extends State<_AltTextDialog> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.item.altText ?? '');

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    void save() {
      Get.find<AdminMediaController>()
          .updateAltText(widget.item.id, _controller.text.trim());
      Get.back();
    }

    return AlertDialog(
      title: const Text('Alt text'),
      content: SizedBox(
        width: ResponsiveBreakpoints.dialogWidth(context, 320),
        child: TextField(
          controller: _controller,
          maxLines: 2,
          decoration:
              const InputDecoration(labelText: 'Accessibility description'),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Get.back(), child: const Text('Cancel')),
        ElevatedButton(onPressed: save, child: const Text('Save')),
      ],
    );
  }
}
