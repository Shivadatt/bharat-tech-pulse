import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../app/config/site_config.dart';
import '../responsive/responsive_breakpoints.dart';
import '../responsive/responsive_container.dart';

class AppFooter extends StatelessWidget {
  const AppFooter({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDesktop = ResponsiveBreakpoints.isDesktop(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          top: BorderSide(color: theme.colorScheme.outline, width: 1),
        ),
      ),
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: ResponsiveContainer(
        child: Column(
          children: [
            isDesktop ? _buildDesktopColumns(context, theme) : _buildMobileColumns(context, theme),
            const SizedBox(height: 40),
            const Divider(),
            const SizedBox(height: 24),
            // The tagline is ~235px of unbreakable text; beside an Expanded
            // copyright it squeezes the legal line to a few characters per
            // line on a phone, so the pair stacks there.
            ResponsiveBreakpoints.isMobileSmall(context)
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        SiteConfig.copyrightNotice,
                        style: theme.textTheme.bodySmall,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Independent • Unbiased • Made in India',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          SiteConfig.copyrightNotice,
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                      Flexible(
                        child: Text(
                          'Independent • Unbiased • Made in India',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.end,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildDesktopColumns(BuildContext context, ThemeData theme) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Col 1: Brand
        Expanded(
          flex: 4,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.bolt_rounded, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      SiteConfig.siteName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                SiteConfig.description,
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              Text(
                'Contact: ${SiteConfig.contactEmail}',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
        const SizedBox(width: 40),
        // Col 2: Categories
        Expanded(
          flex: 3,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'COVERAGE',
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 12),
              _FooterLink(label: 'AI & Tools', route: '/ai/'),
              _FooterLink(label: 'Smartphones', route: '/smartphones/'),
              _FooterLink(label: 'Apps Ecosystem', route: '/apps/'),
              _FooterLink(label: 'How-To Guides', route: '/how-to/'),
              _FooterLink(label: 'Tech Updates', route: '/tech-news/'),
              _FooterLink(label: 'Comparisons', route: '/comparisons/'),
              _FooterLink(label: 'Cyber Safety', route: '/cyber-safety/'),
              _FooterLink(label: 'Buying Guides', route: '/buying-guides/'),
            ],
          ),
        ),
        // Col 3: Legal & Editorial
        Expanded(
          flex: 3,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'EDITORIAL & LEGAL',
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 12),
              _FooterLink(label: 'About Our Team', route: '/about'),
              _FooterLink(label: 'Contact Us', route: '/contact'),
              _FooterLink(label: 'Editorial Policy', route: '/editorial-policy'),
              _FooterLink(label: 'Privacy Policy', route: '/privacy-policy'),
              _FooterLink(label: 'Terms of Use', route: '/terms'),
              _FooterLink(label: 'Disclaimer', route: '/disclaimer'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMobileColumns(BuildContext context, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          SiteConfig.siteName,
          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        Text(SiteConfig.tagline, style: theme.textTheme.bodyMedium),
        const SizedBox(height: 24),
        Text(
          'MAIN SECTIONS',
          style: theme.textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.bold,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: [
            _FooterLink(label: 'AI & Tools', route: '/ai/'),
            _FooterLink(label: 'Smartphones', route: '/smartphones/'),
            _FooterLink(label: 'Apps', route: '/apps/'),
            _FooterLink(label: 'How-To', route: '/how-to/'),
            _FooterLink(label: 'Tech News', route: '/tech-news/'),
            _FooterLink(label: 'Comparisons', route: '/comparisons/'),
            _FooterLink(label: 'Cyber Safety', route: '/cyber-safety/'),
            _FooterLink(label: 'Buying Guides', route: '/buying-guides/'),
          ],
        ),
        const SizedBox(height: 24),
        Text(
          'POLICIES & ABOUT',
          style: theme.textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.bold,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: [
            _FooterLink(label: 'About', route: '/about'),
            _FooterLink(label: 'Contact', route: '/contact'),
            _FooterLink(label: 'Editorial Policy', route: '/editorial-policy'),
            _FooterLink(label: 'Privacy', route: '/privacy-policy'),
            _FooterLink(label: 'Terms', route: '/terms'),
            _FooterLink(label: 'Disclaimer', route: '/disclaimer'),
          ],
        ),
      ],
    );
  }
}

class _FooterLink extends StatelessWidget {
  final String label;
  final String route;

  const _FooterLink({required this.label, required this.route});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: () => Get.toNamed(route),
      // A bare Text gives a ~20px tap box, under this app's own 40px mobile
      // touch minimum (see share_buttons_widget.dart). The spacing has to sit
      // INSIDE the InkWell to be part of the hit box — the old EdgeInsets.only
      // (bottom: 8) wrapped the InkWell from outside, so it never grew the
      // tappable area.
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
        child: Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.textTheme.bodyMedium?.color?.withAlpha(220),
          ),
        ),
      ),
    );
  }
}
