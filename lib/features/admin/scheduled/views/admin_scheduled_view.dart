import 'package:flutter/material.dart';
import '../../layouts/admin_scaffold.dart';

class AdminScheduledView extends StatelessWidget {
  const AdminScheduledView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final mockScheduled = [
      {
        'title': 'Diwali Gadget Deals 2026: Bank Discount Breakdown on HDFC & ICICI Cards',
        'category': 'Buying Guides',
        'scheduledFor': 'Tomorrow at 09:00 AM IST',
        'author': 'Rohit Deshmukh',
      },
      {
        'title': 'How to Port Mobile Number via SMS Without Losing 5G VoNR Balance',
        'category': 'How-To Guides',
        'scheduledFor': 'Oct 12, 2026 at 11:30 AM IST',
        'author': 'Sneha Kulkarni',
      },
      {
        'title': 'Sarvam AI Speech API Benchmark vs Google Cloud Speech-to-Text',
        'category': 'AI & AI Tools',
        'scheduledFor': 'Oct 14, 2026 at 02:00 PM IST',
        'author': 'Aravind Sharma',
      },
    ];

    return AdminScaffold(
      title: 'Scheduled Publishing Queue',
      body: Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Queued Stories (${mockScheduled.length})',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: mockScheduled.length,
                separatorBuilder: (context, index) => const Divider(),
                itemBuilder: (context, index) {
                  final item = mockScheduled[index];
                  return ListTile(
                    leading: const Icon(Icons.alarm_on_rounded, color: Colors.purple),
                    title: Text(item['title']!, style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text('${item['category']} • Scheduled: ${item['scheduledFor']} • By ${item['author']}'),
                    trailing: OutlinedButton(
                      onPressed: () {},
                      child: const Text('Reschedule'),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
