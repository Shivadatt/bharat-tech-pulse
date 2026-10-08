import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../features/admin/auth/controllers/admin_auth_controller.dart';
import '../routes/app_routes.dart';

/// Guards every admin route except /admin/login.
///
/// NOTE: this is client-side UX gating only. Flutter Web ships all Dart code
/// as public JavaScript, so real protection must be enforced server-side
/// (Supabase Auth + RLS) in Phase 2.
class AdminAuthMiddleware extends GetMiddleware {
  AdminAuthMiddleware();

  @override
  RouteSettings? redirect(String? route) {
    final auth = Get.find<AdminAuthController>();
    if (auth.isLoggedIn.value) return null;
    return const RouteSettings(name: AppRoutes.adminLogin);
  }
}
