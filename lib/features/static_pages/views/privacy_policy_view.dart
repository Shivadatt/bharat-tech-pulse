import 'package:flutter/material.dart';
import '../../../shared/components/breadcrumb_widget.dart';
import '../../../shared/layouts/public_scaffold.dart';
import '../../../shared/responsive/responsive_container.dart';

class PrivacyPolicyView extends StatelessWidget {
  const PrivacyPolicyView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return PublicScaffold(
      body: ResponsiveContainer(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const BreadcrumbWidget(items: [BreadcrumbItem(label: 'Privacy Policy')]),
            const SizedBox(height: 12),
            Text('Privacy Policy (DPDP Act 2023 Compliant)',
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
                  Text('Data We Collect',
                      style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(
                    'We do not collect Aadhaar numbers, biometric data, or financial credentials. For newsletter subscribers, we collect only your provided email address, stored with industry standard encryption.',
                    style: theme.textTheme.bodyMedium?.copyWith(height: 1.7),
                  ),
                  const SizedBox(height: 20),
                  Text('Cookie & Analytics Policy',
                      style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(
                    'We utilize anonymized telemetry to gauge story popularity and device screen sizes (e.g. tablet vs mobile) to refine responsive layout rendering. We do not sell user data to advertising brokers.',
                    style: theme.textTheme.bodyMedium?.copyWith(height: 1.7),
                  ),
                  const SizedBox(height: 20),
                  Text('Your Rights Under DPDP Act',
                      style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(
                    'You retain the statutory right to request complete erasure of your subscriber records or revoke newsletter consent at any time via privacy@bharattechpulse.in.',
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
