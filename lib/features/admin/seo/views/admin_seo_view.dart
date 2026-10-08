import 'package:flutter/material.dart';
import '../../../../app/config/site_config.dart';
import '../../layouts/admin_scaffold.dart';

class AdminSeoView extends StatelessWidget {
  const AdminSeoView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AdminScaffold(
      title: 'SEO & Metadata Manager',
      actions: [
        ElevatedButton.icon(
          onPressed: () {},
          icon: const Icon(Icons.save_rounded, size: 18),
          label: const Text('Save SEO Settings'),
        ),
      ],
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Global Search Engine Optimization',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      initialValue: SiteConfig.siteName,
                      decoration: const InputDecoration(labelText: 'Default Site Title'),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      initialValue: SiteConfig.description,
                      maxLines: 2,
                      decoration: const InputDecoration(labelText: 'Default Meta Description'),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      initialValue: SiteConfig.domain,
                      decoration: const InputDecoration(labelText: 'Canonical Domain URL'),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      initialValue: SiteConfig.defaultOgImage,
                      decoration: const InputDecoration(labelText: 'Default Open Graph / Social Image URL'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Search Indexation Files (Architecture Ready)',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    ListTile(
                      leading: const Icon(Icons.code_rounded, color: Colors.cyan),
                      title: const Text('XML Sitemap (/sitemap.xml)'),
                      subtitle: const Text('Automatically indexes all 21+ articles, categories, and author profiles.'),
                      trailing: OutlinedButton(onPressed: () {}, child: const Text('Regenerate')),
                    ),
                    const Divider(),
                    ListTile(
                      leading: const Icon(Icons.smart_toy_outlined, color: Colors.amber),
                      title: const Text('Robots Rules (/robots.txt)'),
                      subtitle: const Text('Permits Googlebot, Bingbot, and ClaudeBot; blocks admin routes.'),
                      trailing: OutlinedButton(onPressed: () {}, child: const Text('Edit Rules')),
                    ),
                    const Divider(),
                    ListTile(
                      leading: const Icon(Icons.rss_feed_rounded, color: Colors.orange),
                      title: const Text('RSS 2.0 Feed (/rss.xml)'),
                      subtitle: const Text('Syndicates latest Indian tech stories to news readers.'),
                      trailing: OutlinedButton(onPressed: () {}, child: const Text('View XML')),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }
}
