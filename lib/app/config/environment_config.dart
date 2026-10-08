/// Environment configuration prepared for upcoming phases (Supabase Auth/DB/Storage).
/// Reads from const String.fromEnvironment for web security.
class EnvironmentConfig {
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

  /// API base URL if separate
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://api.bharattechpulse.in',
  );
}
