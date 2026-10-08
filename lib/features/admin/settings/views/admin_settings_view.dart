import 'package:flutter/material.dart';
import '../../../../app/config/environment_config.dart';
import '../../../../app/config/site_config.dart';
import '../../layouts/admin_scaffold.dart';

class AdminSettingsView extends StatelessWidget {
  const AdminSettingsView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AdminScaffold(
      title: 'Platform & Backend Settings',
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
                      'Multi-Website Configuration',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      initialValue: SiteConfig.siteId,
                      decoration: const InputDecoration(labelText: 'Site Identifier (siteId)'),
                      readOnly: true,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      initialValue: SiteConfig.siteName,
                      decoration: const InputDecoration(labelText: 'Site Display Name'),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      initialValue: SiteConfig.tagline,
                      decoration: const InputDecoration(labelText: 'Tagline'),
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
                    Row(
                      children: const [
                        Icon(Icons.storage_rounded, color: Colors.green),
                        SizedBox(width: 8),
                        Text(
                          'Supabase Backend Integration (Phase 2 Ready)',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      initialValue: EnvironmentConfig.supabaseUrl,
                      decoration: const InputDecoration(
                        labelText: 'SUPABASE_URL',
                        helperText: 'Configured via --dart-define=SUPABASE_URL=...',
                      ),
                      readOnly: true,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      initialValue: EnvironmentConfig.supabaseAnonKey,
                      decoration: const InputDecoration(
                        labelText: 'SUPABASE_ANON_KEY (Public Key)',
                        helperText: 'Safe for client-side web use. Never expose service_role key.',
                      ),
                      readOnly: true,
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
