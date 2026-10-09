import 'package:flutter/material.dart';
import 'package:get/get.dart';
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
