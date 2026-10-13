import 'package:flutter/foundation.dart';

/// Environment configuration prepared for upcoming phases (Supabase Auth/DB/Storage).
/// Reads from const String.fromEnvironment for web security.
///
/// Data-source policy (Phase 1 remediation):
///   * `mock` stays the default for development and for `flutter test`, so the
///     suite and local dev keep booting against the in-memory repositories.
///   * A production/release artifact may NEVER silently serve mock data. When
///     the build declares `ENV=production` (or is compiled in release mode) the
///     data source must be `supabase` with real, non-placeholder credentials,
///     and Supabase must actually have initialised. Anything else throws a
///     loud, developer-facing [StateError] at startup instead of rendering
///     fabricated content. See [ensureSafeDataSource].
class EnvironmentConfig {
  EnvironmentConfig._();

  /// Allowed `DATA_SOURCE` values.
  static const String dataSourceMock = 'mock';
  static const String dataSourceSupabase = 'supabase';

  /// The exact, copy-pasteable production invocation. Only the PUBLISHABLE /
  /// anon key belongs in a Flutter Web client — it ships to every browser.
  /// A service_role/secret key or a database password must never be passed
  /// here, in a build, or in source control.
  static const String productionBuildCommand =
      'fvm flutter build web --release '
      '--dart-define=ENV=production '
      '--dart-define=DATA_SOURCE=supabase '
      '--dart-define=SUPABASE_URL=https://<project-ref>.supabase.co '
      '--dart-define=SUPABASE_ANON_KEY=<publishable-anon-key>';

  static const String environment =
      String.fromEnvironment('ENV', defaultValue: 'development');

  static bool get isProduction => environment == 'production';
  static bool get isDevelopment => environment == 'development';

  /// Supabase project credentials (configured via --dart-define during build)
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://placeholder-project.supabase.co',
  );

  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'placeholder-anon-key-public-only',
  );

  /// Selects the data backend: 'mock' (default, in-memory) or 'supabase'.
  static const String dataSource = String.fromEnvironment(
    'DATA_SOURCE',
    defaultValue: dataSourceMock,
  );

  /// True when real Supabase credentials were supplied via --dart-define.
  static bool get supabaseConfigured =>
      !supabaseUrl.contains('placeholder') &&
      !supabaseAnonKey.contains('placeholder');

  /// Supabase mode is active only when requested AND configured. Every
  /// default build/test keeps running against the mock repositories.
  static bool get useSupabase => dataSource == dataSourceSupabase && supabaseConfigured;

  /// Mock data is only ever acceptable in a non-production, non-release
  /// compilation (i.e. `flutter run` in debug and `flutter test`).
  static bool get mockDataAllowed => !isProduction && !kReleaseMode;

  /// Pure, unit-testable data-source rule. Returns `null` when the current
  /// configuration is safe to boot, or a developer-facing explanation when it
  /// is not. [supabaseInitialized] is passed in (instead of importing
  /// `SupabaseService`) to keep this config layer dependency-free.
  static String? dataSourceViolation({
    required String env,
    required String source,
    required String url,
    required String anonKey,
    required bool supabaseInitialized,
    required bool releaseMode,
  }) {
    if (source != dataSourceMock && source != dataSourceSupabase) {
      return 'Unknown DATA_SOURCE="$source". Expected "mock" or "supabase".';
    }

    final productionIntent = env == 'production' || releaseMode;
    if (!productionIntent) return null;

    final who = env == 'production'
        ? 'A production build (ENV=production)'
        : 'A release-mode build';

    if (source != dataSourceSupabase) {
      return '$who was built with DATA_SOURCE="$source". Mock editorial data '
          'must never be served from a production artifact.';
    }
    if (url.trim().isEmpty || url.contains('placeholder')) {
      return '$who selected Supabase but SUPABASE_URL was not provided '
          '(it is still the placeholder default).';
    }
    if (!url.startsWith('https://')) {
      return '$who was built with a non-HTTPS SUPABASE_URL "$url".';
    }
    if (anonKey.trim().isEmpty || anonKey.contains('placeholder')) {
      return '$who selected Supabase but SUPABASE_ANON_KEY was not provided '
          '(it is still the placeholder default). Pass only the PUBLISHABLE / '
          'anon key — never a service_role key, secret key or database password.';
    }
    if (!supabaseInitialized) {
      return '$who requested Supabase, but Supabase failed to initialise. The '
          'URL/anon key pair is most likely invalid; refusing to fall back to '
          'mock data.';
    }
    return null;
  }

  /// Startup guard, called from `InitialBinding.dependencies()` before any
  /// repository is registered. Throws with the exact remediation command
  /// instead of degrading to mock content.
  static void ensureSafeDataSource({required bool supabaseInitialized}) {
    final violation = dataSourceViolation(
      env: environment,
      source: dataSource,
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
      supabaseInitialized: supabaseInitialized,
      releaseMode: kReleaseMode,
    );
    if (violation != null) {
      throw StateError(
        'CONFIGURATION ERROR: $violation\n\n'
        'Rebuild with:\n  $productionBuildCommand\n\n'
        'Or run `tool/build_production.ps1`, which reads SUPABASE_URL and '
        'SUPABASE_ANON_KEY from the environment / tool/live_checks/.env.\n'
        'For local development against mock data, drop ENV=production and '
        'build without --release.',
      );
    }
  }

  /// API base URL if separate
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://api.bharattechpulse.in',
  );
}
