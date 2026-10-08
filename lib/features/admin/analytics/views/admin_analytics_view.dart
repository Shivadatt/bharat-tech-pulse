import 'package:flutter/material.dart';
import '../../../../shared/responsive/responsive_grid.dart';
import '../../layouts/admin_scaffold.dart';

class AdminAnalyticsView extends StatelessWidget {
  const AdminAnalyticsView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AdminScaffold(
      title: 'Audience & Engagement Analytics',
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ResponsiveGrid(
              desktopColumns: 4,
              tabletColumns: 2,
              mobileColumns: 1,
              children: [
                _StatTile(label: 'Monthly Unique Visitors', val: '184.2K', change: '+24.5% vs last mo', color: Colors.cyan),
                _StatTile(label: 'Avg. Time on Page', val: '3m 48s', change: '+12.1% depth', color: Colors.green),
                _StatTile(label: 'Newsletter Open Rate', val: '46.8%', change: 'Top quartile', color: Colors.orange),
                _StatTile(label: 'Mobile Traffic Share', val: '81.4%', change: 'Android majority', color: Colors.purple),
              ],
            ),
            const SizedBox(height: 24),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Top Traffic Geographies (India Breakdown)',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    const _CityRow(city: 'Bengaluru (Karnataka)', share: '28.4%'),
                    const Divider(),
                    const _CityRow(city: 'Delhi NCR (Delhi / Noida / Gurugram)', share: '24.1%'),
                    const Divider(),
                    const _CityRow(city: 'Mumbai & Pune (Maharashtra)', share: '19.8%'),
                    const Divider(),
                    const _CityRow(city: 'Hyderabad (Telangana)', share: '14.2%'),
                    const Divider(),
                    const _CityRow(city: 'Chennai (Tamil Nadu)', share: '8.6%'),
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

class _StatTile extends StatelessWidget {
  final String label;
  final String val;
  final String change;
  final Color color;

  const _StatTile({required this.label, required this.val, required this.change, required this.color});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: 12, color: Theme.of(context).textTheme.bodySmall?.color)),
            const SizedBox(height: 8),
            Text(val, style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: color)),
            const SizedBox(height: 4),
            Text(change, style: const TextStyle(fontSize: 11, color: Colors.green, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

class _CityRow extends StatelessWidget {
  final String city;
  final String share;

  const _CityRow({required this.city, required this.share});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(city, style: const TextStyle(fontWeight: FontWeight.w500)),
          Text(share, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
