import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../app/config/app_constants.dart';
import '../../../app/config/site_config.dart';
import '../../../app/theme/theme_controller.dart';
import '../../../shared/responsive/responsive_breakpoints.dart';
import '../auth/controllers/admin_auth_controller.dart';

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
      title: Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
      ),
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
          Flexible(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                letterSpacing: -0.2,
              ),
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
          _AdminAvatar(),
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
            child: _buildNavList(),
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.all(12),
            child: ListTile(
              leading: const Icon(Icons.logout_rounded, size: 20, color: Colors.red),
              title: const Text('Logout', style: TextStyle(color: Colors.red, fontSize: 14)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              // logout() clears the session and routes to the login page.
              // Jumping straight to the route left isLoggedIn (and the cached
              // profile) set, so AdminAuthMiddleware bounced the user back in.
              onTap: () {
                if (Get.isRegistered<AdminAuthController>()) {
                  Get.find<AdminAuthController>().logout();
                } else {
                  Get.offAllNamed('/admin/login');
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  /// Entries the signed-in role can open.
  ///
  /// Hiding here is presentation only — the `AdminRoleMiddleware` on each route
  /// and Supabase RLS are what actually stop a visit or a write. `Obx` so the
  /// drawer re-filters when the profile (or its site role) changes.
  Widget _buildNavList() {
    final auth = AdminAuthController.maybe();
    if (auth == null) {
      // No session mounted (admin views pumped directly by tests): the
      // middleware already bounced every real caller, so show the full tree.
      return _navItems(
        canManageContent: true,
        canManageSettings: true,
        canViewReports: true,
      );
    }
    return Obx(() => _navItems(
          canManageContent: auth.canManageContent,
          canManageSettings: auth.canManageSettings,
          canViewReports: auth.canViewReports,
        ));
  }

  Widget _navItems({
    required bool canManageContent,
    required bool canManageSettings,
    required bool canViewReports,
  }) {
    return ListView(
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
        if (canManageContent)
          _AdminNavItem(
            icon: Icons.category_outlined,
            title: 'Categories',
            route: '/admin/categories',
          ),
        if (canManageContent)
          _AdminNavItem(
            icon: Icons.tag_rounded,
            title: 'Tags',
            route: '/admin/tags',
          ),
        if (canManageSettings)
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

        // Both panels write post rows (`is_site_editor`), so the group is
        // dropped whole for the author tier rather than leaving a header over
        // an empty section.
        if (canManageContent) ...[
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
        ],

        // The tier that owns reports also owns at least one panel here, so the
        // section header disappears with them instead of standing over an
        // empty group.
        if (canManageSettings || canViewReports) ...[
          const _AdminNavHeader(title: 'GROWTH & CONFIG'),
          if (canManageSettings)
            _AdminNavItem(
              icon: Icons.search_rounded,
              title: 'SEO Manager',
              route: '/admin/seo',
            ),
          if (canViewReports)
            _AdminNavItem(
              icon: Icons.bar_chart_rounded,
              title: 'Analytics',
              route: '/admin/analytics',
            ),
          if (canManageSettings)
            _AdminNavItem(
              icon: Icons.settings_outlined,
              title: 'Site Settings',
              route: '/admin/settings',
            ),
        ],
      ],
    );
  }
}

/// Signed-in editor avatar. The picture comes from the loaded profile (our own
/// storage bucket); a missing or broken URL degrades to initials rather than
/// pointing at a third-party CDN, which would leak CMS sessions to it and ship
/// an image the site has no rights record for.
class _AdminAvatar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (!Get.isRegistered<AdminAuthController>()) {
      return const CircleAvatar(radius: 16, child: Icon(Icons.person_rounded, size: 18));
    }
    final controller = Get.find<AdminAuthController>();
    return Obx(() {
      final profile = controller.profile.value;
      final url = profile?.avatarUrl;
      final initials = _initialsFor(profile?.fullName ?? controller.emailController.text);
      if (url == null || url.isEmpty) {
        return _initials(theme, initials);
      }
      return ClipOval(
        child: SizedBox(
          width: 32,
          height: 32,
          child: Image.network(
            url,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => _initials(theme, initials),
          ),
        ),
      );
    });
  }

  static Widget _initials(ThemeData theme, String initials) {
    return CircleAvatar(
      radius: 16,
      backgroundColor: theme.colorScheme.primary.withAlpha(40),
      child: Text(
        initials,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: theme.colorScheme.primary,
        ),
      ),
    );
  }

  static String _initialsFor(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      final word = parts.first;
      return (word.length > 2 ? word.substring(0, 2) : word).toUpperCase();
    }
    return (parts[0][0] + parts[1][0]).toUpperCase();
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
