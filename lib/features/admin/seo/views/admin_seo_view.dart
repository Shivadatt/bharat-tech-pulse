import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../layouts/admin_scaffold.dart';
import '../../shared/widgets/admin_state_view.dart';
import '../controllers/admin_seo_controller.dart';

class AdminSeoView extends GetView<AdminSeoController> {
  const AdminSeoView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AdminScaffold(
      title: 'SEO & Metadata Manager',
      actions: [
        Obx(() => ElevatedButton.icon(
              onPressed: controller.isSaving.value ? null : controller.save,
              icon: controller.isSaving.value
                  ? const SizedBox(
                      width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.save_rounded, size: 18),
              label: const Text('Save SEO Settings'),
            )),
      ],
      body: Obx(() => AdminStateView(
            isLoading: controller.isLoading.value,
            error: controller.errorMessage.value,
            isEmpty: false,
            emptyMessage: '',
            onRetry: controller.load,
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
                          style: theme.textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 20),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: TextField(
                            controller: controller.metaTitleController,
                            decoration:
                                const InputDecoration(labelText: 'Default Meta Title'),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: TextField(
                            controller: controller.metaDescController,
                            maxLines: 2,
                            decoration: const InputDecoration(
                                labelText: 'Default Meta Description'),
                          ),
                        ),
                        TextField(
                          controller: controller.gaIdController,
                          decoration: const InputDecoration(
                              labelText: 'Google Analytics Measurement ID'),
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
                          style: theme.textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 16),
                        ListTile(
                          leading: const Icon(Icons.code_rounded, color: Colors.cyan),
                          title: const Text('XML Sitemap (/sitemap.xml)'),
                          subtitle: const Text(
                              'Automatically indexes articles, categories, and author profiles.'),
                        ),
                        const Divider(),
                        ListTile(
                          leading:
                              const Icon(Icons.smart_toy_outlined, color: Colors.amber),
                          title: const Text('Robots Rules (/robots.txt)'),
                          subtitle: const Text(
                              'Permits crawlers; blocks admin routes.'),
                        ),
                        const Divider(),
                        ListTile(
                          leading: const Icon(Icons.rss_feed_rounded, color: Colors.orange),
                          title: const Text('RSS 2.0 Feed (/rss.xml)'),
                          subtitle:
                              const Text('Syndicates the latest stories to news readers.'),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 48),
              ],
            ),
          )),
    );
  }
}
