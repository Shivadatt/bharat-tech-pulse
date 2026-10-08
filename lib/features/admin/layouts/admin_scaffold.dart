import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../app/config/app_constants.dart';
import '../../../app/config/site_config.dart';
import '../../../app/theme/theme_controller.dart';
import '../../../shared/responsive/responsive_breakpoints.dart';

class AdminScaffold extends StatelessWidget {
  final String title;
  final Widget body;
  final List<Widget>? actions;
  final Widget? floatingActionButton;

  const AdminScaffold({
    super.key,
    required this.title,
    required this.body,
    this.actions,
    this.floatingActionButton,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDesktop = ResponsiveBreakpoints.isDesktop(context);

    return Scaffold(
      appBar: isDesktop ? null : _buildMobileAppBar(context, theme),
      drawer: isDesktop ? null : Drawer(child: _buildSidebarContent(context, theme)),
      body: Row(
        children: [
          if (isDesktop)
            Container(
              width: AppConstants.adminSidebarWidth,
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                border: Border(
                  right: BorderSide(color: theme.colorScheme.outline, width: 1),
                ),
              ),
              child: _buildSidebarContent(context, theme),
            ),
          Expanded(
            child: Column(
              children: [
                if (isDesktop) _buildDesktopTopbar(context, theme),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: body,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: floatingActionButton,
    );
  }

  PreferredSizeWidget _buildMobileAppBar(BuildContext context, ThemeData theme) {
    return AppBar(
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
      actions: actions,
    );
  }

  Widget _buildDesktopTopbar(BuildContext context, ThemeData theme) {
    final themeController = Get.find<ThemeController>();

    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          bottom: BorderSide(color: theme.colorScheme.outline, width: 1),
        ),
      ),
      child: Row(
        children: [
          Text(
            title,
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              letterSpacing: -0.2,
            ),
          ),
          const Spacer(),
          ...?actions,
          const SizedBox(width: 12),
          IconButton(
            tooltip: 'View Live Website',
            icon: const Icon(Icons.open_in_new_rounded, size: 20),
            onPressed: () => Get.toNamed('/'),
          ),
          Obx(() {
            final isDark = themeController.isDarkMode;
            return IconButton(
              tooltip: isDark ? 'Switch to Light' : 'Switch to Dark',
              icon: Icon(
                isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                size: 20,
              ),
              onPressed: themeController.toggleTheme,
            );
          }),
          const SizedBox(width: 8),
          const CircleAvatar(
            radius: 16,
            backgroundImage: NetworkImage(
              'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=150&q=80',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarContent(BuildContext context, ThemeData theme) {
    return SafeArea(
      child: Column(
        children: [
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
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        SiteConfig.siteName,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'Editorial CMS',
                        style: TextStyle(color: theme.colorScheme.primary, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              children: [
                _AdminNavItem(
                  icon: Icons.dashboard_outlined,
                  title: 'Dashboard',
                  route: '/admin/dashboard',
                ),

                const _AdminNavHeader(title: 'CONTENT'),
                _AdminNavItem(
                  icon: Icons.article_outlined,
                  title: 'Articles',
                  route: '/admin/articles',
                ),
                _AdminNavItem(
                  icon: Icons.category_outlined,
                  title: 'Categories',
                  route: '/admin/categories',
                ),
                _AdminNavItem(
                  icon: Icons.tag_rounded,
                  title: 'Tags',
                  route: '/admin/tags',
                ),
                _AdminNavItem(
                  icon: Icons.people_outline_rounded,
                  title: 'Authors',
                  route: '/admin/authors',
                ),
                _AdminNavItem(
                  icon: Icons.perm_media_outlined,
                  title: 'Media Assets',
                  route: '/admin/media',
                ),

                const _AdminNavHeader(title: 'PUBLISHING PIPELINE'),
                _AdminNavItem(
                  icon: Icons.trending_up_rounded,
                  title: 'Trending Articles',
                  route: '/admin/trending',
                ),
                _AdminNavItem(
                  icon: Icons.schedule_rounded,
                  title: 'Scheduled Posts',
                  route: '/admin/scheduled',
                ),

                const _AdminNavHeader(title: 'GROWTH & CONFIG'),
                _AdminNavItem(
                  icon: Icons.search_rounded,
                  title: 'SEO Manager',
                  route: '/admin/seo',
                ),
                _AdminNavItem(
                  icon: Icons.bar_chart_rounded,
                  title: 'Analytics',
                  route: '/admin/analytics',
                ),
                _AdminNavItem(
                  icon: Icons.settings_outlined,
                  title: 'Site Settings',
                  route: '/admin/settings',
                ),
              ],
            ),
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.all(12),
            child: ListTile(
              leading: const Icon(Icons.logout_rounded, size: 20, color: Colors.red),
              title: const Text('Logout', style: TextStyle(color: Colors.red, fontSize: 14)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              onTap: () => Get.offAllNamed('/admin/login'),
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminNavHeader extends StatelessWidget {
  final String title;
  const _AdminNavHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 12, top: 16, bottom: 6),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.0,
          color: Theme.of(context).textTheme.bodySmall?.color,
        ),
      ),
    );
  }
}

class _AdminNavItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String route;

  const _AdminNavItem({
    required this.icon,
    required this.title,
    required this.route,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isSelected = Get.currentRoute == route;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: ListTile(
        leading: Icon(
          icon,
          size: 19,
          color: isSelected ? theme.colorScheme.primary : theme.textTheme.bodyMedium?.color,
        ),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? theme.colorScheme.primary : theme.textTheme.bodyLarge?.color,
          ),
        ),
        tileColor: isSelected ? theme.colorScheme.primary.withAlpha(25) : Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        dense: true,
        onTap: () {
          if (!isSelected) {
            Get.toNamed(route);
          }
        },
      ),
    );
  }
}
