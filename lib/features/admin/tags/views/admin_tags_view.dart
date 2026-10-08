import 'package:flutter/material.dart';
import '../../../../data/services/mock_data_source.dart';
import '../../layouts/admin_scaffold.dart';

class AdminTagsView extends StatelessWidget {
  const AdminTagsView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tags = MockDataSource.tags;

    return AdminScaffold(
      title: 'Topic Tags Manager',
      actions: [
        ElevatedButton.icon(
          onPressed: () {},
          icon: const Icon(Icons.add_rounded, size: 18),
          label: const Text('Add Tag'),
        ),
      ],
      body: Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Indexed Tags (${tags.length})',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
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
                    onDeleted: () {},
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
