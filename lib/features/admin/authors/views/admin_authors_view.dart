import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../data/models/author_model.dart';
import '../../layouts/admin_scaffold.dart';
import '../../shared/widgets/admin_state_view.dart';
import '../controllers/admin_authors_controller.dart';

class AdminAuthorsView extends GetView<AdminAuthorsController> {
  const AdminAuthorsView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AdminScaffold(
      title: 'Authors & Contributors',
      actions: [
        ElevatedButton.icon(
          onPressed: () => _openForm(context),
          icon: const Icon(Icons.person_add_rounded, size: 18),
          label: const Text('Add Contributor'),
        ),
      ],
      body: Obx(() {
        final authors = controller.authors;
        return AdminStateView(
          isLoading: controller.isLoading.value,
          error: controller.errorMessage.value,
          isEmpty: authors.isEmpty,
          emptyMessage: 'No contributors yet.',
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
                        'Editorial Staff (${authors.length})',
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
                    itemCount: authors.length,
                    separatorBuilder: (context, index) => const Divider(),
                    itemBuilder: (context, index) {
                      final a = authors[index];
                      return ListTile(
                        leading: a.avatarUrl.isEmpty
                            ? CircleAvatar(child: Text(a.name.isEmpty ? '?' : a.name[0]))
                            : CircleAvatar(
                                backgroundImage: NetworkImage(a.avatarUrl),
                                child: const SizedBox.shrink(),
                              ),
                        title: Text(a.name,
                            style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(
                          '${a.role} • ${a.email}'
                          '${a.isActive ? '' : ' • archived'}',
                          style: TextStyle(
                              fontSize: 12,
                              color: theme.textTheme.bodySmall?.color),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, size: 18),
                              onPressed: () => _openForm(context, existing: a),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline_rounded,
                                  size: 18, color: Colors.red),
                              onPressed: () => _confirmDelete(a),
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

  Future<void> _confirmDelete(AuthorModel a) async {
    final confirmed = await Get.dialog<bool>(
      AlertDialog(
        title: const Text('Delete Author?'),
        content: Text('Remove the byline "${a.name}" permanently?'),
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
    if (confirmed == true) await controller.deleteAuthor(a.id);
  }

  Future<void> _openForm(BuildContext context, {AuthorModel? existing}) async {
    final nameC = TextEditingController(text: existing?.name ?? '');
    final slugC = TextEditingController(text: existing?.slug ?? '');
    final roleC = TextEditingController(text: existing?.role ?? 'Tech Writer');
    final emailC = TextEditingController(text: existing?.email ?? '');
    final bioC = TextEditingController(text: existing?.bio ?? '');
    final avatarC = TextEditingController(text: existing?.avatarUrl ?? '');

    Future<void> save() async {
      final draft = AuthorModel(
        id: existing?.id ?? '',
        slug: slugC.text.trim(),
        name: nameC.text.trim(),
        role: roleC.text.trim(),
        bio: bioC.text.trim(),
        avatarUrl: avatarC.text.trim(),
        twitter: existing?.twitter ?? '',
        linkedin: existing?.linkedin ?? '',
        email: emailC.text.trim(),
        isActive: existing?.isActive ?? true,
        linkedUserId: existing?.linkedUserId,
      );
      final ok = existing == null
          ? await controller.createAuthor(draft)
          : await controller.updateAuthor(draft);
      if (ok) Get.back();
    }

    await Get.dialog(
      _FormDialog(
        title: existing == null ? 'Add Contributor' : 'Edit Contributor',
        fields: [
          ('Name', nameC),
          ('Slug', slugC),
          ('Role', roleC),
          ('Email', emailC),
          ('Avatar URL', avatarC),
        ],
        onSave: save,
        bioController: bioC,
      ),
    );
  }
}

class _FormDialog extends StatelessWidget {
  final String title;
  final List<(String, TextEditingController)> fields;
  final Future<void> Function() onSave;
  final TextEditingController? bioController;

  const _FormDialog({
    required this.title,
    required this.fields,
    required this.onSave,
    this.bioController,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(title),
      content: SizedBox(
        width: 360,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final (label, c) in fields)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: TextField(controller: c, decoration: InputDecoration(labelText: label)),
                ),
              if (bioController != null)
                TextField(
                  controller: bioController,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Bio'),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Get.back(), child: const Text('Cancel')),
        ElevatedButton(onPressed: onSave, child: const Text('Save')),
      ],
    );
  }
}
