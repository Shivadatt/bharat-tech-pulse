import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../layouts/admin_scaffold.dart';
import '../controllers/admin_article_controller.dart';

class AdminArticlesListView extends GetView<AdminArticleController> {
  const AdminArticlesListView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AdminScaffold(
      title: 'Article Manager',
      actions: [
        ElevatedButton.icon(
          onPressed: () {
            controller.initializeForCreate();
            Get.toNamed('/admin/articles/create');
          },
          icon: const Icon(Icons.add_rounded, size: 18),
          label: const Text('New Article'),
        ),
      ],
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'All Articles (${controller.articles.length})',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh_rounded),
                      onPressed: controller.loadArticlesAndMeta,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: controller.articles.length,
                  separatorBuilder: (context, index) => const Divider(),
                  itemBuilder: (context, index) {
                    final art = controller.articles[index];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: Image.network(
                          art.featuredImage,
                          width: 60,
                          height: 48,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              Container(width: 60, height: 48, color: Colors.grey),
                        ),
                      ),
                      title: Text(
                        art.title,
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                      ),
                      subtitle: Text(
                        '${art.categoryName} • by ${art.author.name} • ${DateFormatter.formatShort(art.publishedAt)} • ${NumberFormat.compact().format(art.viewCount)} reads',
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.textTheme.bodySmall?.color,
                        ),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.open_in_new_rounded, size: 18),
                            tooltip: 'Preview Live',
                            onPressed: () => Get.toNamed('/article/${art.slug}'),
                          ),
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, size: 18),
                            tooltip: 'Edit Article',
                            onPressed: () {
                              controller.initializeForEdit(art.id);
                              Get.toNamed('/admin/articles/edit/${art.id}');
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline_rounded,
                                size: 18, color: Colors.red),
                            tooltip: 'Delete',
                            onPressed: () => controller.deleteArticle(art.id),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      }),
    );
  }
}
