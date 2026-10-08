import 'package:flutter/material.dart';
import '../../../../data/services/mock_data_source.dart';
import '../../layouts/admin_scaffold.dart';

class AdminTrendingView extends StatelessWidget {
  const AdminTrendingView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final trendingArticles = MockDataSource.articles.where((a) => a.isTrending).toList();

    return AdminScaffold(
      title: 'Trending Curation & Algorithm',
      body: Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Top Trending Slots on Homepage',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Drag or toggle active status to influence real-time algorithmic positioning.',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: trendingArticles.length,
                separatorBuilder: (context, index) => const Divider(),
                itemBuilder: (context, index) {
                  final art = trendingArticles[index];
                  return ListTile(
                    leading: Text(
                      '#${index + 1}',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    title: Text(art.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text('${art.categoryName} • ${art.viewCount} views'),
                    trailing: const Switch(value: true, onChanged: null),
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
