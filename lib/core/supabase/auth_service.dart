import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart' hide AuthException;

import '../errors/app_exceptions.dart';
import 'supabase_service.dart';

/// Thin wrapper around Supabase Auth. Only usable when
/// [SupabaseService.initialized] is true; every error is mapped to the
/// app-wide [AppException] family so raw provider messages never reach the UI.
class AuthService {
  StreamSubscription<AuthState>? _subscription;

  SupabaseClient get _client => SupabaseService.client;

  Session? get currentSession => _client.auth.currentSession;

  User? get currentUser => _client.auth.currentUser;

  Future<void> signIn(String email, String password) async {
    try {
      await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );
    } on AuthApiException catch (e) {
      throw _mapAuthError(e);
    } on AuthException catch (e) {
      // Gotrue's generic auth failure — keep the message user-safe.
      throw AuthException(_safeAuthMessage(e.message));
    }
  }

  Future<void> signOut() async {
    try {
      await _client.auth.signOut();
    } on AuthApiException catch (e) {
      throw _mapAuthError(e);
    } on AuthException catch (e) {
      throw AuthException(_safeAuthMessage(e.message));
    }
  }

  /// Subscribes to auth state changes. Only one subscription is held at a
  /// time; the previous one is cancelled. Cancel via [dispose].
  StreamSubscription<AuthState> onAuthStateChange(
    void Function(AuthState state) callback,
  ) {
    _subscription?.cancel();
    _subscription = _client.auth.onAuthStateChange.listen(callback);
    return _subscription!;
  }

  void dispose() {
    _subscription?.cancel();
    _subscription = null;
  }

  AuthException _mapAuthError(AuthApiException e) {
    final code = e.code ?? '';
    final message = e.message.toLowerCase();
    if (code == 'invalid_credentials' ||
        code == 'invalid_grant' ||
        message.contains('invalid login credentials') ||
        message.contains('invalid_credentials')) {
      return const AuthException('Invalid email or password.');
    }
    if (code == 'email_not_confirmed') {
      return const AuthException(
        'Please confirm your email address before signing in.',
      );
    }
    if (code == 'too_many_requests' || message.contains('too many requests')) {
      return const AuthException(
        'Too many attempts. Please wait a moment and try again.',
      );
    }
    return const AuthException('Sign in failed. Please try again.');
  }

  /// Never leak arbitrary gotrue internals to the UI.
  String _safeAuthMessage(String message) {
    final lower = message.toLowerCase();
    if (lower.contains('network') || lower.contains('fetch')) {
      return 'Network error. Please check your connection and try again.';
    }
    return 'Authentication failed. Please try again.';
  }
}
