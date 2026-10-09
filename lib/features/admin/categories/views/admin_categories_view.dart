import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../data/models/category_model.dart';
import '../../layouts/admin_scaffold.dart';
import '../../shared/widgets/admin_state_view.dart';
import '../controllers/admin_categories_controller.dart';

class AdminCategoriesView extends GetView<AdminCategoriesController> {
  const AdminCategoriesView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AdminScaffold(
      title: 'Categories & Taxonomies',
      actions: [
        ElevatedButton.icon(
          onPressed: () => _openForm(context),
          icon: const Icon(Icons.add_rounded, size: 18),
          label: const Text('New Category'),
        ),
      ],
      body: Obx(() {
        final cats = controller.categories;
        return AdminStateView(
          isLoading: controller.isLoading.value,
          error: controller.errorMessage.value,
          isEmpty: cats.isEmpty,
          emptyMessage: 'No categories yet.',
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
                        'Editorial Hubs (${cats.length})',
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
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: cats.length,
                    separatorBuilder: (context, index) => const Divider(),
                    itemBuilder: (context, index) {
                      final cat = cats[index];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: theme.colorScheme.primary.withAlpha(25),
                          child: Text(
                            (index + 1).toString(),
                            style: TextStyle(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        title: Text(cat.name,
                            style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(
                          'Slug: /${cat.slug}/ • Subcategories: '
                          '${cat.subcategories.join(', ')}'
                          '${cat.isActive ? '' : ' • archived'}',
                          style: TextStyle(
                              fontSize: 12, color: theme.textTheme.bodySmall?.color),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, size: 18),
                              onPressed: () => _openForm(context, existing: cat),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline_rounded,
                                  size: 18, color: Colors.red),
                              onPressed: () => _confirmDelete(cat),
                            ),
                          ],
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

  Future<void> _confirmDelete(CategoryModel cat) async {
    final confirmed = await Get.dialog<bool>(
      AlertDialog(
        title: const Text('Delete Category?'),
        content: Text('Remove "${cat.name}" permanently?'),
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
    if (confirmed == true) await controller.deleteCategory(cat.id);
  }

  Future<void> _openForm(BuildContext context, {CategoryModel? existing}) async {
    final nameC = TextEditingController(text: existing?.name ?? '');
    final slugC = TextEditingController(text: existing?.slug ?? '');
    final descC = TextEditingController(text: existing?.description ?? '');
    final subC =
        TextEditingController(text: existing?.subcategories.join(', ') ?? '');
    final iconC = TextEditingController(
        text: existing?.iconCode ?? 'folder');

    Future<void> save() async {
      final draft = CategoryModel(
        id: existing?.id ?? '',
        slug: slugC.text.trim(),
        name: nameC.text.trim(),
        description: descC.text.trim(),
        iconCode: iconC.text.trim().isEmpty ? 'folder' : iconC.text.trim(),
        subcategories: subC.text
            .split(',')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList(),
        isActive: existing?.isActive ?? true,
      );
      final ok = existing == null
          ? await controller.createCategory(draft)
          : await controller.updateCategory(draft);
      if (ok) Get.back();
    }

    await Get.dialog(
      AlertDialog(
        title: Text(existing == null ? 'New Category' : 'Edit Category'),
        content: SizedBox(
          width: 360,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nameC, decoration: const InputDecoration(labelText: 'Name')),
                const SizedBox(height: 12),
                TextField(controller: slugC, decoration: const InputDecoration(labelText: 'Slug')),
                const SizedBox(height: 12),
                TextField(controller: iconC, decoration: const InputDecoration(labelText: 'Icon code')),
                const SizedBox(height: 12),
                TextField(controller: subC, decoration: const InputDecoration(labelText: 'Subcategories (comma-separated)')),
                const SizedBox(height: 12),
                TextField(controller: descC, maxLines: 3, decoration: const InputDecoration(labelText: 'Description')),
              ],
            ),
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
