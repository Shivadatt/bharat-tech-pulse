import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../../app/config/site_config.dart';
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

  static final RegExp _emailPattern =
      RegExp(r'^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$');

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

  String get _draft {
    return 'From: ${_nameController.text.trim()} <${_emailController.text.trim()}>\n'
        'Subject: ${_subjectController.text.trim()}\n\n'
        '${_messageController.text.trim()}';
  }

  void _copyDraft() {
    Clipboard.setData(ClipboardData(text: _draft));
    Get.snackbar(
      'Draft Copied',
      'Paste it into an email to ${SiteConfig.contactEmail}.',
      snackPosition: SnackPosition.BOTTOM,
      duration: const Duration(seconds: 2),
      margin: const EdgeInsets.all(16),
      maxWidth: 400,
    );
  }

  void _copyContactEmail() {
    Clipboard.setData(const ClipboardData(text: SiteConfig.contactEmail));
    Get.snackbar(
      'Email Copied',
      '${SiteConfig.contactEmail} copied to your clipboard.',
      snackPosition: SnackPosition.BOTTOM,
      duration: const Duration(seconds: 2),
      margin: const EdgeInsets.all(16),
      maxWidth: 400,
    );
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
                        color: theme.colorScheme.primary.withAlpha(20),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          Icon(Icons.mark_email_unread_outlined,
                              color: theme.colorScheme.primary, size: 48),
                          const SizedBox(height: 16),
                          Text(
                            'Finish by Email',
                            style: theme.textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Heads up: this form does not transmit anything — your message was '
                            'not sent or stored anywhere. Copy the draft below and email it to '
                            '${SiteConfig.contactEmail}, or write to ${SiteConfig.editorialEmail} '
                            'for editorial tips and corrections.',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 20),
                          Wrap(
                            spacing: 12,
                            runSpacing: 8,
                            alignment: WrapAlignment.center,
                            children: [
                              ElevatedButton.icon(
                                onPressed: _copyDraft,
                                icon: const Icon(Icons.copy_rounded, size: 18),
                                label: const Text('Copy My Draft'),
                              ),
                              OutlinedButton.icon(
                                onPressed: _copyContactEmail,
                                icon: const Icon(Icons.mail_outline_rounded, size: 18),
                                label: Text(SiteConfig.contactEmail),
                              ),
                            ],
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
                            validator: (v) => (v == null || v.trim().isEmpty)
                                ? 'Please enter your name'
                                : null,
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            decoration: const InputDecoration(labelText: 'Email Address *'),
                            validator: (v) =>
                                (v == null || !_emailPattern.hasMatch(v.trim()))
                                    ? 'Please enter a valid email'
                                    : null,
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _subjectController,
                            maxLength: 150,
                            decoration: const InputDecoration(
                                labelText: 'Subject / Department *',
                                hintText: 'Editorial Tip, Correction, Partnership...'),
                            validator: (v) => (v == null || v.trim().isEmpty)
                                ? 'Please enter a subject'
                                : null,
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _messageController,
                            maxLines: 5,
                            maxLength: 2000,
                            decoration: const InputDecoration(
                              labelText: 'Your Message *',
                              hintText: 'Share your perspective or query...',
                            ),
                            validator: (v) => (v == null || v.trim().isEmpty)
                                ? 'Please enter your message'
                                : null,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'This page does not transmit messages — on the next step you can copy '
                            'your draft and send it to our editorial email.',
                            style: theme.textTheme.bodySmall,
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton.icon(
                            onPressed: _submit,
                            icon: const Icon(Icons.drafts_rounded, size: 18),
                            label: const Text('Review & Send by Email'),
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
