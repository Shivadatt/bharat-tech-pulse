import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/errors/app_exceptions.dart';
import '../../../../core/supabase/auth_service.dart';
import '../../../../core/supabase/role_permissions.dart';
import '../../../../core/supabase/supabase_service.dart';
import '../../../../data/models/profile_model.dart';
import '../../../../data/repositories/profile_repository.dart';

/// Admin authentication state.
///
/// With Supabase configured this is real auth: sign-in verifies credentials
/// server-side, the `profiles` row gates access (inactive accounts are
/// signed out immediately), and auth state events keep the session reactive.
/// Without Supabase the controller stays inert and [login] refuses to accept
/// credentials.
class AdminAuthController extends GetxController {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  final RxBool isLoggedIn = false.obs;
  final RxBool isLoading = false.obs;
  final RxString errorMessage = ''.obs;
  final Rx<ProfileModel?> profile = Rx<ProfileModel?>(null);

  /// Effective role of the signed-in user; defaults to the least-privileged
  /// [AdminRole.author] when no profile is loaded.
  AdminRole get role => profile.value?.role ?? AdminRole.author;

  final AuthService? _injectedAuth;
  final ProfileRepository? _injectedProfiles;
  StreamSubscription<AuthState>? _authSubscription;

  AdminAuthController({AuthService? authService, ProfileRepository? profileRepository})
      : _injectedAuth = authService,
        _injectedProfiles = profileRepository;

  bool get _supabaseReady => SupabaseService.initialized;

  AuthService? get _auth => _injectedAuth ??
      (_supabaseReady ? Get.find<AuthService>() : null);

  ProfileRepository? get _profiles => _injectedProfiles ??
      (_supabaseReady ? Get.find<ProfileRepository>() : null);

  @override
  void onInit() {
    super.onInit();
    if (_supabaseReady) {
      _authSubscription =
          _auth?.onAuthStateChange(_onAuthStateChanged);
    }
  }

  @override
  void onClose() {
    _authSubscription?.cancel();
    emailController.dispose();
    passwordController.dispose();
    super.onClose();
  }

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  Future<void> login() async {
    final email = emailController.text.trim();
    final password = passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      errorMessage.value = 'Please enter email and password';
      return;
    }

    final auth = _auth;
    if (auth == null) {
      // Backend not configured — never accept credentials in this state.
      errorMessage.value = 'Backend is not configured.';
      return;
    }

    isLoading.value = true;
    errorMessage.value = '';
    try {
      await auth.signIn(email, password);
      final loaded = await _loadProfile();
      if (!loaded) return; // errorMessage already set; force-signed-out.
      Get.offNamed('/admin/dashboard');
    } on AppException catch (e) {
      errorMessage.value = e.message;
    } catch (_) {
      errorMessage.value = 'Sign in failed. Please try again.';
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> logout() async {
    try {
      await _auth?.signOut();
    } catch (_) {
      // Local reset proceeds even when the network sign-out fails.
    }
    _reset();
    await Get.offAllNamed('/admin/login');
  }

  /// Rehydrates state from a persisted session. Called once from
  /// [InitialBinding] after Supabase initialization.
  ///
  /// The persisted session is trusted for routing immediately: [restoreSession]
  /// is fired unawaited while the router evaluates [AdminAuthMiddleware]
  /// synchronously, so waiting for the profile round-trip would bounce a valid
  /// cold-boot deep link to the login page. [_loadProfile] revokes the flag when
  /// the account is missing or deactivated.
  Future<void> restoreSession() async {
    if (!_supabaseReady) return;
    final session = _auth?.currentSession;
    if (session == null) {
      isLoggedIn.value = false;
      return;
    }
    isLoggedIn.value = true;
    await _loadProfile();
  }

  // ---------------------------------------------------------------------------
  // Internals
  // ---------------------------------------------------------------------------

  void _onAuthStateChanged(AuthState state) {
    switch (state.event) {
      case AuthChangeEvent.signedOut:
        _reset();
        Get.offAllNamed('/admin/login');
        break;
      case AuthChangeEvent.tokenRefreshed:
      case AuthChangeEvent.userUpdated:
        unawaited(_loadProfile());
        break;
      default:
        break;
    }
  }

  /// Loads the current profile and applies the active-account gate.
  /// Returns false (and signs out) when missing or deactivated.
  Future<bool> _loadProfile() async {
    final profiles = _profiles;
    if (profiles == null) {
      isLoggedIn.value = false;
      return false;
    }
    try {
      final loaded = await profiles.loadCurrentProfile();
      if (loaded == null || !loaded.isActive) {
        await _auth?.signOut();
        _reset();
        errorMessage.value = 'Account deactivated.';
        return false;
      }
      profile.value = loaded;
      isLoggedIn.value = true;
      errorMessage.value = '';
      return true;
    } on AppException catch (e) {
      isLoggedIn.value = false;
      errorMessage.value = e.message;
      return false;
    } catch (_) {
      isLoggedIn.value = false;
      errorMessage.value = 'Failed to load profile.';
      return false;
    }
  }

  void _reset() {
    isLoggedIn.value = false;
    profile.value = null;
    errorMessage.value = '';
  }
}
