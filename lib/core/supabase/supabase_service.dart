import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../app/config/environment_config.dart';

/// Central Supabase bootstrap. The app must boot in mock mode when no
/// credentials are provided, so initialization is a no-op unless
/// [EnvironmentConfig.useSupabase] is true, and any failure is swallowed
/// (logged) leaving [initialized] false so the DI layer falls back to mocks.
class SupabaseService {
  SupabaseService._();

  static bool initialized = false;

  static Future<void> initialize() async {
    if (initialized) return;
    if (!EnvironmentConfig.useSupabase) return;
    try {
      await Supabase.initialize(
        url: EnvironmentConfig.supabaseUrl,
        // supabase_flutter 2.18 renamed anonKey -> publishableKey; the value
        // still comes from the SUPABASE_ANON_KEY environment slot.
        publishableKey: EnvironmentConfig.supabaseAnonKey,
        authOptions: const FlutterAuthClientOptions(
          autoRefreshToken: true,
        ),
      );
      initialized = true;
    } catch (e, stackTrace) {
      debugPrint(
        'Supabase initialization failed; continuing in mock mode. Error: $e\n$stackTrace',
      );
      initialized = false;
    }
  }

  /// The shared client. Throws a friendly [StateError] when the backend was
  /// never initialized so callers never surface a raw null-check failure.
  static SupabaseClient get client {
    if (!initialized) {
      throw StateError(
        'Supabase is not initialized. Provide SUPABASE_URL and '
        'SUPABASE_ANON_KEY via --dart-define with DATA_SOURCE=supabase, '
        'or run in the default mock mode.',
      );
    }
    return Supabase.instance.client;
  }
}
