import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../app/config/site_config.dart';

class MobileDrawer extends StatelessWidget {
  const MobileDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Drawer(
      backgroundColor: theme.scaffoldBackgroundColor,
      child: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF06B6D4), Color(0xFF0891B2)],
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.bolt_rounded, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          SiteConfig.siteName,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Digital India Tech Hub',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(),
            // Navigation Links
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  _DrawerItem(
                    icon: Icons.home_outlined,
                    title: 'Home',
                    route: '/',
                  ),
                  _DrawerItem(
                    icon: Icons.psychology_outlined,
                    title: 'AI & AI Tools',
                    route: '/ai/',
                  ),
                  _DrawerItem(
                    icon: Icons.phone_android_outlined,
                    title: 'Smartphones',
                    route: '/smartphones/',
                  ),
                  _DrawerItem(
                    icon: Icons.apps_outlined,
                    title: 'Apps',
                    route: '/apps/',
                  ),
                  _DrawerItem(
                    icon: Icons.menu_book_outlined,
                    title: 'How-To Guides',
                    route: '/how-to/',
                  ),
                  _DrawerItem(
                    icon: Icons.newspaper_outlined,
                    title: 'Tech Updates',
                    route: '/tech-news/',
                  ),
                  _DrawerItem(
                    icon: Icons.compare_arrows_outlined,
                    title: 'Comparisons',
                    route: '/comparisons/',
                  ),
                  _DrawerItem(
                    icon: Icons.security_outlined,
                    title: 'Cyber Safety',
                    route: '/cyber-safety/',
                  ),
                  _DrawerItem(
                    icon: Icons.shopping_bag_outlined,
                    title: 'Buying Guides',
                    route: '/buying-guides/',
                  ),
                  const Divider(),
                  _DrawerItem(
                    icon: Icons.info_outline_rounded,
                    title: 'About Us',
                    route: '/about',
                  ),
                  _DrawerItem(
                    icon: Icons.mail_outline_rounded,
                    title: 'Contact',
                    route: '/contact',
                  ),
                  _DrawerItem(
                    icon: Icons.admin_panel_settings_outlined,
                    title: 'Admin Dashboard',
                    route: '/admin/dashboard',
                  ),
                ],
              ),
            ),
            // Footer notice
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                SiteConfig.copyrightNotice,
                style: theme.textTheme.bodySmall?.copyWith(fontSize: 10),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DrawerItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String route;

  const _DrawerItem({
    required this.icon,
    required this.title,
    required this.route,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isCurrent = Get.currentRoute == route;

    return ListTile(
      leading: Icon(
        icon,
        color: isCurrent ? theme.colorScheme.primary : theme.textTheme.bodyMedium?.color,
        size: 20,
      ),
      title: Text(
        title,
        style: TextStyle(
          color: isCurrent ? theme.colorScheme.primary : theme.textTheme.bodyLarge?.color,
          fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
          fontSize: 14,
        ),
      ),
      onTap: () {
        Navigator.of(context).pop();
        Get.toNamed(route);
      },
    );
  }
}
