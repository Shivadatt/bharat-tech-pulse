import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../app/config/environment_config.dart';
import '../../../../app/config/site_config.dart';
import '../../layouts/admin_scaffold.dart';
import '../../shared/widgets/admin_state_view.dart';
import '../controllers/admin_settings_controller.dart';

class AdminSettingsView extends GetView<AdminSettingsController> {
  const AdminSettingsView({super.key});

  @override
  Widget build(BuildContext context) {
    return AdminScaffold(
      title: 'Platform & Backend Settings',
      actions: [
        Obx(() => ElevatedButton.icon(
              onPressed: controller.isSaving.value ? null : controller.save,
              icon: controller.isSaving.value
                  ? const SizedBox(
                      width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.save_rounded, size: 18),
              label: const Text('Save'),
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
                          'Site Identity',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          initialValue: SiteConfig.siteId,
                          decoration:
                              const InputDecoration(labelText: 'Site Identifier (siteId)'),
                          readOnly: true,
                        ),
                        const SizedBox(height: 16),
                        _field('Site Display Name', controller.siteNameController),
                        _field('Tagline', controller.taglineController),
                        _field('Contact Email', controller.contactEmailController),
                        _field('Footer Text', controller.footerTextController),
                        _field('Copyright Text', controller.copyrightController),
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
                          'Social Links',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 16),
                        _field('Twitter / X', controller.twitterController),
                        _field('YouTube', controller.youtubeController),
                        _field('Telegram', controller.telegramController),
                        _field('LinkedIn', controller.linkedinController),
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
                        Row(
                          children: const [
                            Icon(Icons.storage_rounded, color: Colors.green),
                            SizedBox(width: 8),
                            Text(
                              'Backend Integration',
                              style:
                                  TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          initialValue: EnvironmentConfig.supabaseUrl,
                          decoration: const InputDecoration(
                            labelText: 'SUPABASE_URL',
                            helperText:
                                'Configured via --dart-define=SUPABASE_URL=...',
                          ),
                          readOnly: true,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          initialValue: EnvironmentConfig.useSupabase
                              ? 'Supabase (live)'
                              : 'In-memory mock (no backend configured)',
                          decoration: const InputDecoration(labelText: 'Data Source'),
                          readOnly: true,
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

  Widget _field(String label, TextEditingController c) => Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: TextField(
          controller: c,
          decoration: InputDecoration(labelText: label),
        ),
      );
}
