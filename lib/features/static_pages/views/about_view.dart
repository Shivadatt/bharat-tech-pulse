import 'package:flutter/material.dart';
import '../../../data/services/mock_data_source.dart';
import '../../../shared/components/breadcrumb_widget.dart';
import '../../../shared/layouts/public_scaffold.dart';
import '../../../shared/responsive/responsive_container.dart';
import '../../../shared/widgets/author_info_widget.dart';

class AboutView extends StatelessWidget {
  const AboutView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return PublicScaffold(
      body: ResponsiveContainer(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const BreadcrumbWidget(
              items: [BreadcrumbItem(label: 'About Us')],
            ),
            const SizedBox(height: 12),
            Text(
              'About Bharat Tech Pulse',
              style: theme.textTheme.displayMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              'Democratizing technology journalism for 1.4 billion citizens.',
              style: theme.textTheme.headlineSmall?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: theme.colorScheme.outline),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Our Mission',
                    style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Bharat Tech Pulse was created to provide high-integrity, technically rigorous, and jargon-free technology journalism tailored to Indian consumers. From navigating digital arrest cybercrimes to selecting the right smartphone for extreme summer heat, we test products under real Indian conditions.',
                    style: theme.textTheme.bodyLarge?.copyWith(height: 1.7),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Core Pillars',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '• Zero Sponsored Benchmarks: We never accept vendor money to bias speed tests or camera rankings.\n'
                    '• Indian Context First: We benchmark UPI fail rates, IRCTC servers, local service centers, and Indian language LLMs.\n'
                    '• Cyber Safety Advocacy: We actively educate families on combating WhatsApp scams and reporting on the 1930 helpline.',
                    style: theme.textTheme.bodyMedium?.copyWith(height: 1.8),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
            Text(
              'Meet Our Editorial Team',
              style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            for (final author in MockDataSource.authors) ...[
              AuthorInfoWidget(author: author),
              const SizedBox(height: 16),
            ],
            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }
}
