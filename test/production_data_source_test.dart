import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:india_tech_web/app/bindings/initial_binding.dart';
import 'package:india_tech_web/app/config/environment_config.dart';
import 'package:india_tech_web/core/supabase/supabase_service.dart';
import 'package:india_tech_web/data/repositories/article_repository.dart';
import 'package:india_tech_web/data/repositories/mock_article_repository.dart';
import 'package:india_tech_web/features/admin/auth/controllers/admin_auth_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Phase 1: production data-source selection.
///
/// These tests pin the fail-safe rule — mock data is allowed for development
/// and tests, but a production/release configuration must throw loudly rather
/// than boot on fabricated editorial content.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const realUrl = 'https://ylzwuwfhlqomjqcdrpxk.supabase.co';
  const realKey = 'sb_publishable_anon_key_value_never_committed';

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    Get.reset();
  });

  String? violationFor({
    String env = 'development',
    String source = 'mock',
    String url = 'https://placeholder-project.supabase.co',
    String anonKey = 'placeholder-anon-key-public-only',
    bool supabaseInitialized = true,
    bool releaseMode = false,
  }) =>
      EnvironmentConfig.dataSourceViolation(
        env: env,
        source: source,
        url: url,
        anonKey: anonKey,
        supabaseInitialized: supabaseInitialized,
        releaseMode: releaseMode,
      );

  group('EnvironmentConfig defaults stay on mock for dev/test', () {
    test('no dart-define means mock data source and placeholder credentials',
        () {
      expect(EnvironmentConfig.environment, 'development');
      expect(EnvironmentConfig.dataSource, 'mock');
      expect(EnvironmentConfig.isProduction, isFalse);
      expect(EnvironmentConfig.supabaseConfigured, isFalse);
      expect(EnvironmentConfig.useSupabase, isFalse);
      expect(EnvironmentConfig.mockDataAllowed, isTrue);
    });

    test('the development configuration passes the guard without throwing',
        () {
      expect(
        () => EnvironmentConfig.ensureSafeDataSource(
          supabaseInitialized: SupabaseService.initialized,
        ),
        returnsNormally,
      );
    });

    test('a default (dev) binding still registers the in-memory repositories',
        () {
      InitialBinding().dependencies();
      expect(SupabaseService.initialized, isFalse);
      expect(Get.find<ArticleRepository>(), isA<MockArticleRepository>());
      Get.reset();
    });
  });

  group('dataSourceViolation: production/release must not serve mock', () {
    test('development + mock is allowed', () {
      expect(violationFor(), isNull);
    });

    test('ENV=production + mock is refused', () {
      final v = violationFor(env: 'production');
      expect(v, contains('ENV=production'));
      expect(v, contains('DATA_SOURCE="mock"'));
    });

    test('a release-mode build + mock is refused even without ENV=production',
        () {
      expect(violationFor(releaseMode: true), contains('release-mode build'));
    });

    test('ENV=production + supabase but placeholder url/key is refused', () {
      expect(
        violationFor(env: 'production', source: 'supabase'),
        contains('SUPABASE_URL was not provided'),
      );
      expect(
        violationFor(
          env: 'production',
          source: 'supabase',
          url: realUrl,
        ),
        contains('SUPABASE_ANON_KEY was not provided'),
      );
    });

    test('ENV=production + supabase with a non-https url is refused', () {
      expect(
        violationFor(
          env: 'production',
          source: 'supabase',
          url: 'http://insecure.example.com',
          anonKey: realKey,
        ),
        contains('non-HTTPS'),
      );
    });

    test('ENV=production + supabase that failed to initialise is refused', () {
      final v = violationFor(
        env: 'production',
        source: 'supabase',
        url: realUrl,
        anonKey: realKey,
        supabaseInitialized: false,
      );
      expect(v, contains('failed to initialise'));
    });

    test('a fully configured production build is accepted', () {
      expect(
        violationFor(
          env: 'production',
          source: 'supabase',
          url: realUrl,
          anonKey: realKey,
        ),
        isNull,
      );
    });

    test('an unknown DATA_SOURCE is refused in every mode', () {
      expect(violationFor(source: 'postgre'), contains('Unknown DATA_SOURCE'));
      expect(
        violationFor(
          env: 'production',
          source: 'postgre',
          url: realUrl,
          anonKey: realKey,
        ),
        contains('Unknown DATA_SOURCE'),
      );
    });

    test('the error message carries the exact remediation command', () {
      expect(EnvironmentConfig.productionBuildCommand,
          contains('--dart-define=DATA_SOURCE=supabase'));
      expect(EnvironmentConfig.productionBuildCommand,
          contains('--dart-define=ENV=production'));
    });
  });

  group('Admin sign-in stays refused without a real backend', () {
    test('mock mode rejects credentials instead of appearing to succeed',
        () async {
      final controller = AdminAuthController();
      controller.emailController.text = 'editor@example.com';
      controller.passwordController.text = 'any-password';
      await controller.login();
      expect(controller.isLoggedIn.value, isFalse);
      expect(controller.errorMessage.value, 'Backend is not configured.');
      controller.emailController.dispose();
      controller.passwordController.dispose();
    });
  });
}
