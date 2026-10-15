import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:india_tech_web/app/middleware/admin_auth_middleware.dart';
import 'package:india_tech_web/app/routes/app_pages.dart';
import 'package:india_tech_web/app/routes/app_routes.dart';
import 'package:india_tech_web/core/supabase/role_permissions.dart';
import 'package:india_tech_web/data/models/profile_model.dart';
import 'package:india_tech_web/features/admin/auth/controllers/admin_auth_controller.dart';

/// Route-level role gating.
///
/// These tests pin the UI contract only. Supabase RLS is what actually refuses
/// a write from an under-privileged account, so a passing suite here does not
/// prove the CMS is safe — it proves an author is not offered the settings page.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final settingsGate =
      AdminRoleMiddleware(canAccess: RolePermissions.canManageSettings);
  final reportsGate =
      AdminRoleMiddleware(canAccess: RolePermissions.canViewReports);

  void signIn({
    AdminRole globalRole = AdminRole.author,
    AdminRole? siteRole,
    bool isActive = true,
    bool loggedIn = true,
  }) {
    final auth = Get.put(AdminAuthController());
    auth.isLoggedIn.value = loggedIn;
    auth.profile.value = ProfileModel(
      id: 'profile-1',
      email: 'staff@bharattechpulse.test',
      fullName: 'Test Staff',
      role: globalRole,
      siteRole: siteRole,
      isActive: isActive,
    );
  }

  setUp(() => Get.reset());
  tearDown(() => Get.reset());

  group('AdminRoleMiddleware on the site settings route', () {
    test('an author is bounced to the dashboard, never to the settings page',
        () {
      signIn(siteRole: AdminRole.author);
      expect(settingsGate.redirect(AppRoutes.adminSettings)?.name,
          AppRoutes.adminDashboard);
    });

    test('an editor is bounced too — settings are the admin tier', () {
      signIn(siteRole: AdminRole.editor);
      expect(settingsGate.redirect(AppRoutes.adminSettings)?.name,
          AppRoutes.adminDashboard);
    });

    test('a site admin and a global super_admin pass', () {
      signIn(siteRole: AdminRole.admin);
      expect(settingsGate.redirect(AppRoutes.adminSettings), isNull);

      Get.reset();
      signIn(globalRole: AdminRole.superAdmin);
      expect(settingsGate.redirect(AppRoutes.adminSettings), isNull,
          reason: 'the global super_admin tier wins over a missing membership');
    });

    test('a session whose profile has not landed is treated as the least tier',
        () {
      final auth = Get.put(AdminAuthController());
      auth.isLoggedIn.value = true;
      auth.profile.value = null;
      expect(settingsGate.redirect(AppRoutes.adminSettings)?.name,
          AppRoutes.adminDashboard,
          reason: 'an unknown role must not render an admin-only page');
    });

    test('the sign-in checks are kept, not weakened', () {
      signIn(loggedIn: false);
      expect(settingsGate.redirect(AppRoutes.adminSettings)?.name,
          AppRoutes.adminLogin);

      Get.reset();
      signIn(siteRole: AdminRole.admin, isActive: false);
      expect(settingsGate.redirect(AppRoutes.adminSettings)?.name,
          AppRoutes.adminLogin,
          reason: 'a deactivated account still goes to login, not the dashboard');
    });
  });

  group('Report gate', () {
    test('an editor may open analytics, an author may not', () {
      signIn(siteRole: AdminRole.editor);
      expect(reportsGate.redirect(AppRoutes.adminAnalytics), isNull);

      Get.reset();
      signIn(siteRole: AdminRole.author);
      expect(reportsGate.redirect(AppRoutes.adminAnalytics)?.name,
          AppRoutes.adminDashboard);
    });
  });

  group('Declared route table', () {
    List<GetMiddleware> gateFor(String routeName) => AppPages.routes
        .firstWhere((page) => page.name == routeName)
        .middlewares!;

    test('admin-only routes carry the role gate; the bounce target does not',
        () {
      for (final route in [
        AppRoutes.adminSettings,
        AppRoutes.adminSeo,
        AppRoutes.adminAuthors,
        AppRoutes.adminCategories,
        AppRoutes.adminAnalytics,
        AppRoutes.adminTrending,
        AppRoutes.adminScheduled,
      ]) {
        expect(gateFor(route).whereType<AdminRoleMiddleware>(), isNotEmpty,
            reason: '$route needs the role gate, not only the sign-in gate');
      }
      expect(gateFor(AppRoutes.adminDashboard).whereType<AdminRoleMiddleware>(),
          isEmpty,
          reason: 'the bounce target must stay reachable by every staff tier');
    });
  });
}
