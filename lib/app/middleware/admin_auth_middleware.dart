import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/supabase/role_permissions.dart';
import '../../features/admin/auth/controllers/admin_auth_controller.dart';
import '../routes/app_routes.dart';

/// Guards every admin route except /admin/login.
///
/// NOTE: this is client-side UX gating only. Flutter Web ships all Dart code
/// as public JavaScript; real protection is enforced server-side
/// (Supabase Auth + RLS).
class AdminAuthMiddleware extends GetMiddleware {
  AdminAuthMiddleware();

  @override
  RouteSettings? redirect(String? route) {
    final auth = Get.find<AdminAuthController>();
    if (!auth.isLoggedIn.value) {
      return const RouteSettings(name: AppRoutes.adminLogin);
    }
    // A logged-in session whose profile was deactivated is force-signed-out
    // by the auth controller; bounce any in-flight navigation to login too.
    final current = auth.profile.value;
    if (current != null && !current.isActive) {
      return const RouteSettings(name: AppRoutes.adminLogin);
    }
    return null;
  }
}

/// Adds a capability requirement on top of [AdminAuthMiddleware]'s
/// sign-in/active checks, so a route the signed-in role cannot use does not
/// render.
///
/// NOTE: same boundary as the base class — this is UI routing, not a security
/// control. Every capability it hides is enforced again by Supabase RLS
/// (`is_site_editor` / `is_site_admin`), and a caller who hand-edits the URL
/// still reaches the server, where the write is rejected.
class AdminRoleMiddleware extends AdminAuthMiddleware {
  AdminRoleMiddleware({
    required this.canAccess,
    this.redirectTo = AppRoutes.adminDashboard,
  });

  /// Capability predicate from [RolePermissions], e.g.
  /// [RolePermissions.canManageSettings].
  final bool Function(AdminRole role) canAccess;

  /// Where a rejected visit lands. Defaults to the dashboard, which every
  /// staff tier can open; sending it to the login page would imply the session
  /// is missing when it is the role that is short.
  final String redirectTo;

  @override
  RouteSettings? redirect(String? route) {
    final base = super.redirect(route);
    if (base != null) return base;
    // No profile yet (cold deep link) resolves to the least-privileged role,
    // so such a visit is bounced to the dashboard and the drawer re-offers the
    // route once the profile lands.
    if (!canAccess(Get.find<AdminAuthController>().role)) {
      return RouteSettings(name: redirectTo);
    }
    return null;
  }
}
