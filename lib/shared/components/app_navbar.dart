import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../app/theme/theme_controller.dart';
import '../responsive/responsive_breakpoints.dart';

class AppNavbar extends StatelessWidget implements PreferredSizeWidget {
  const AppNavbar({super.key});

  @override
  Size get preferredSize => const Size.fromHeight(70);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDesktop = ResponsiveBreakpoints.isDesktop(context);
    final themeController = Get.find<ThemeController>();

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withAlpha(245),
        border: Border(
          bottom: BorderSide(color: theme.colorScheme.outline, width: 1),
        ),
      ),
      child: SafeArea(
        child: Container(
          height: 70,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: isDesktop
              ? _buildDesktopNavbar(context, theme, themeController)
              : _buildMobileNavbar(context, theme, themeController),
        ),
      ),
    );
  }

  Widget _buildBrandLogo(BuildContext context, ThemeData theme) {
    return InkWell(
      onTap: () => Get.toNamed('/'),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF06B6D4), Color(0xFF0891B2)],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.bolt_rounded, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 10),
            RichText(
              text: TextSpan(
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
                children: [
                  const TextSpan(text: 'BHARAT'),
                  TextSpan(
                    text: 'TECH',
                    style: TextStyle(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDesktopNavbar(
      BuildContext context, ThemeData theme, ThemeController themeController) {
    return Row(
      children: [
        _buildBrandLogo(context, theme),
        const SizedBox(width: 32),
        // Primary Navigation Items
        _NavLink(label: 'AI & Tools', route: '/ai/'),
        _NavLink(label: 'Smartphones', route: '/smartphones/'),
        _NavLink(label: 'Apps', route: '/apps/'),
        _NavLink(label: 'How-To', route: '/how-to/'),
        _NavLink(label: 'Tech Updates', route: '/tech-news/'),

        // More Dropdown Menu
        PopupMenuButton<String>(
          tooltip: 'More categories & info',
          onSelected: (route) => Get.toNamed(route),
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: '/comparisons/',
              child: Text('Comparisons'),
            ),
            const PopupMenuItem(
              value: '/cyber-safety/',
              child: Text('Cyber Safety'),
            ),
            const PopupMenuItem(
              value: '/buying-guides/',
              child: Text('Buying Guides'),
            ),
            const PopupMenuDivider(),
            const PopupMenuItem(
              value: '/about',
              child: Text('About Us'),
            ),
            const PopupMenuItem(
              value: '/contact',
              child: Text('Contact'),
            ),
          ],
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'More',
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.keyboard_arrow_down_rounded, size: 18),
              ],
            ),
          ),
        ),

        const Spacer(),

        // Search Action
        IconButton(
          tooltip: 'Search Bharat Tech Pulse',
          icon: const Icon(Icons.search_rounded, size: 20),
          onPressed: () => Get.toNamed('/search'),
        ),
        const SizedBox(width: 8),

        // Theme Toggle
        Obx(() {
          final isDark = themeController.isDarkMode;
          return IconButton(
            tooltip: isDark ? 'Switch to Light Mode' : 'Switch to Dark Mode',
            icon: Icon(
              isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
              size: 20,
            ),
            onPressed: themeController.toggleTheme,
          );
        }),
      ],
    );
  }

  Widget _buildMobileNavbar(
      BuildContext context, ThemeData theme, ThemeController themeController) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _buildBrandLogo(context, theme),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.search_rounded),
              onPressed: () => Get.toNamed('/search'),
            ),
            Obx(() {
              final isDark = themeController.isDarkMode;
              return IconButton(
                icon: Icon(
                  isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                  size: 20,
                ),
                onPressed: themeController.toggleTheme,
              );
            }),
            IconButton(
              icon: const Icon(Icons.menu_rounded),
              onPressed: () {
                Scaffold.of(context).openEndDrawer();
              },
            ),
          ],
        ),
      ],
    );
  }
}

class _NavLink extends StatelessWidget {
  final String label;
  final String route;

  const _NavLink({required this.label, required this.route});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentRoute = Get.currentRoute;
    final isActive = currentRoute == route;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: TextButton(
        onPressed: () => Get.toNamed(route),
        style: TextButton.styleFrom(
          foregroundColor: isActive
              ? theme.colorScheme.primary
              : theme.textTheme.bodyMedium?.color,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}
