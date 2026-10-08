import 'package:flutter/material.dart';
import '../../../../data/services/mock_data_source.dart';
import '../../layouts/admin_scaffold.dart';

class AdminAuthorsView extends StatelessWidget {
  const AdminAuthorsView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authors = MockDataSource.authors;

    return AdminScaffold(
      title: 'Authors & Contributors',
      actions: [
        ElevatedButton.icon(
          onPressed: () {},
          icon: const Icon(Icons.person_add_rounded, size: 18),
          label: const Text('Add Contributor'),
        ),
      ],
      body: Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Editorial Staff (${authors.length})',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
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
                    leading: CircleAvatar(
                      backgroundImage: NetworkImage(a.avatarUrl),
                    ),
                    title: Text(a.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('${a.role} • ${a.email}',
                        style: TextStyle(fontSize: 12, color: theme.textTheme.bodySmall?.color)),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(icon: const Icon(Icons.edit_outlined, size: 18), onPressed: () {}),
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
  }
}
