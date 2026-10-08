import 'package:flutter/material.dart';
import '../../../shared/components/breadcrumb_widget.dart';
import '../../../shared/layouts/public_scaffold.dart';
import '../../../shared/responsive/responsive_container.dart';

class EditorialPolicyView extends StatelessWidget {
  const EditorialPolicyView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return PublicScaffold(
      body: ResponsiveContainer(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const BreadcrumbWidget(items: [BreadcrumbItem(label: 'Editorial Policy')]),
            const SizedBox(height: 12),
            Text('Editorial Policy & Standards',
                style: theme.textTheme.displayMedium?.copyWith(fontWeight: FontWeight.w800)),
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
                  Text('1. Editorial Independence',
                      style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(
                    'Bharat Tech Pulse maintains strict editorial firewalls between editorial staff and commercial partners. Our gadget ratings, benchmark comparisons, and buying recommendations cannot be purchased.',
                    style: theme.textTheme.bodyMedium?.copyWith(height: 1.7),
                  ),
                  const SizedBox(height: 20),
                  Text('2. Testing Methodology',
                      style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(
                    'We test consumer smartphones and electronics in authentic Indian climates—accounting for 40°C+ ambient thermal loads, 5G signal handover on suburban trains, and fluctuating voltage chargers common in Indian households.',
                    style: theme.textTheme.bodyMedium?.copyWith(height: 1.7),
                  ),
                  const SizedBox(height: 20),
                  Text('3. Corrections & Verification',
                      style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(
                    'When factual errors occur, we publish transparent corrections with a timestamp note at the top of the article stating exactly what was corrected.',
                    style: theme.textTheme.bodyMedium?.copyWith(height: 1.7),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }
}
