import 'package:flutter/material.dart';
import '../../../shared/components/breadcrumb_widget.dart';
import '../../../shared/layouts/public_scaffold.dart';
import '../../../shared/responsive/responsive_container.dart';

class ContactView extends StatefulWidget {
  const ContactView({super.key});

  @override
  State<ContactView> createState() => _ContactViewState();
}

class _ContactViewState extends State<ContactView> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _subjectController = TextEditingController();
  final _messageController = TextEditingController();
  bool _isSent = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _subjectController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState?.validate() ?? false) {
      setState(() => _isSent = true);
    }
  }

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
              items: [BreadcrumbItem(label: 'Contact Us')],
            ),
            const SizedBox(height: 12),
            Text(
              'Contact Our Editorial Desk',
              style: theme.textTheme.displayMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              'Tips, corrections, product review requests, or whistleblower leads.',
              style: theme.textTheme.bodyLarge,
            ),
            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: theme.colorScheme.outline),
              ),
              child: _isSent
                  ? Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: const Color(0xFF22C55E).withAlpha(20),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          const Icon(Icons.check_circle_rounded,
                              color: Color(0xFF22C55E), size: 48),
                          const SizedBox(height: 16),
                          Text(
                            'Message Delivered',
                            style: theme.textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF22C55E),
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Thank you for reaching out to Bharat Tech Pulse. Our editors review incoming tips within 24 hours.',
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    )
                  : Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextFormField(
                            controller: _nameController,
                            decoration: const InputDecoration(labelText: 'Full Name *'),
                            validator: (v) =>
                                (v == null || v.isEmpty) ? 'Please enter your name' : null,
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _emailController,
                            decoration: const InputDecoration(labelText: 'Email Address *'),
                            validator: (v) => (v == null || !v.contains('@'))
                                ? 'Please enter a valid email'
                                : null,
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _subjectController,
                            decoration: const InputDecoration(
                                labelText: 'Subject / Department *',
                                hintText: 'Editorial Tip, Correction, Partnership...'),
                            validator: (v) =>
                                (v == null || v.isEmpty) ? 'Please enter a subject' : null,
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _messageController,
                            maxLines: 5,
                            decoration: const InputDecoration(
                              labelText: 'Your Message *',
                              hintText: 'Share your perspective or query...',
                            ),
                            validator: (v) =>
                                (v == null || v.isEmpty) ? 'Please enter your message' : null,
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton.icon(
                            onPressed: _submit,
                            icon: const Icon(Icons.send_rounded, size: 18),
                            label: const Text('Send Message'),
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
