import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../layouts/admin_scaffold.dart';
import '../controllers/admin_article_controller.dart';

class AdminArticleEditorView extends GetView<AdminArticleController> {
  const AdminArticleEditorView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEdit = controller.editingArticleId != null;

    return AdminScaffold(
      title: isEdit ? 'Edit Article' : 'Compose New Article',
      actions: [
        OutlinedButton(
          onPressed: () => controller.saveArticle(newStatus: 'draft'),
          child: const Text('Save Draft'),
        ),
        const SizedBox(width: 8),
        OutlinedButton(
          onPressed: () => controller.saveArticle(newStatus: 'scheduled'),
          child: const Text('Schedule'),
        ),
        const SizedBox(width: 8),
        ElevatedButton.icon(
          onPressed: () => controller.saveArticle(newStatus: 'published'),
          icon: const Icon(Icons.publish_rounded, size: 16),
          label: const Text('Publish Now'),
        ),
      ],
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Core Article Content Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Editorial Content',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 20),

                    // Title
                    TextField(
                      controller: controller.titleController,
                      onChanged: controller.onTitleChanged,
                      decoration: const InputDecoration(
                        labelText: 'Headline / Title *',
                        hintText: 'Enter a punchy, accurate Indian tech headline...',
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Slug
                    TextField(
                      controller: controller.slugController,
                      decoration: const InputDecoration(
                        labelText: 'URL Slug *',
                        hintText: 'e.g. sarvam-ai-indic-llm-breakthrough',
                        prefixText: '/article/',
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Excerpt
                    TextField(
                      controller: controller.excerptController,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Deck / Excerpt *',
                        hintText: 'Summary for social previews, RSS feed, and header deck...',
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Main Content
                    TextField(
                      controller: controller.contentController,
                      maxLines: 10,
                      decoration: const InputDecoration(
                        labelText: 'Article Body (Markdown supported) *',
                        hintText: 'Write in markdown with ### Headings, bullet points, and steps...',
                        alignLabelWithHint: true,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Metadata & Media Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Categorization & Taxonomy',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 20),

                    // Category dropdown & Author dropdown
                    Obx(() {
                      return Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: controller.selectedCategorySlug.value,
                              decoration: const InputDecoration(labelText: 'Primary Category'),
                              items: controller.categories.map((c) {
                                return DropdownMenuItem(value: c.slug, child: Text(c.name));
                              }).toList(),
                              onChanged: (v) {
                                if (v != null) controller.selectedCategorySlug.value = v;
                              },
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: controller.selectedAuthorId.value,
                              decoration: const InputDecoration(labelText: 'Author / Byline'),
                              items: controller.authors.map((a) {
                                return DropdownMenuItem(value: a.id, child: Text(a.name));
                              }).toList(),
                              onChanged: (v) {
                                if (v != null) controller.selectedAuthorId.value = v;
                              },
                            ),
                          ),
                        ],
                      );
                    }),
                    const SizedBox(height: 16),

                    // Tags
                    TextField(
                      controller: controller.tagsController,
                      decoration: const InputDecoration(
                        labelText: 'Topic Tags (comma-separated)',
                        hintText: 'upi, 5g-india, sarvam-ai, cyber-safety',
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Featured Image & Alt Text
                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: TextField(
                            controller: controller.featuredImageController,
                            decoration: const InputDecoration(
                              labelText: 'Featured Image URL',
                              hintText: 'https://...',
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          flex: 2,
                          child: TextField(
                            controller: controller.altTextController,
                            decoration: const InputDecoration(
                              labelText: 'Accessibility Alt Text',
                              hintText: 'Describe image for screen readers...',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // SEO Metadata Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.travel_explore_rounded, color: Colors.cyan, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'SEO & Social Meta Configuration',
                          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    TextField(
                      controller: controller.seoTitleController,
                      decoration: const InputDecoration(
                        labelText: 'Custom SEO Meta Title (max 60 chars)',
                      ),
                    ),
                    const SizedBox(height: 16),

                    TextField(
                      controller: controller.metaDescController,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Meta Description (max 160 chars)',
                      ),
                    ),
                    const SizedBox(height: 16),

                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: controller.ogTitleController,
                            decoration: const InputDecoration(labelText: 'Open Graph Title'),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextField(
                            controller: controller.ogImageController,
                            decoration: const InputDecoration(labelText: 'Open Graph Image URL'),
                          ),
                        ),
                      ],
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
