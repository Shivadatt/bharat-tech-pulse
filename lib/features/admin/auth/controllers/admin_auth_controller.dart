import 'package:flutter/material.dart';
import 'package:get/get.dart';

class AdminAuthController extends GetxController {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  /// MOCK-ONLY AUTHENTICATION. Any non-empty email/password combination is
  /// accepted and no credential is verified. This is NOT production auth;
  /// real enforcement must move server-side (Supabase Auth + RLS) in Phase 2.
  final RxBool isLoggedIn = false.obs;
  final RxBool isLoading = false.obs;
  final RxString errorMessage = ''.obs;

  @override
  void onClose() {
    emailController.dispose();
    passwordController.dispose();
    super.onClose();
  }

  Future<void> login() async {
    final email = emailController.text.trim();
    final password = passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      errorMessage.value = 'Please enter email and password';
      return;
    }

    isLoading.value = true;
    errorMessage.value = '';

    await Future.delayed(const Duration(milliseconds: 300));
    isLoggedIn.value = true;
    isLoading.value = false;
    Get.offNamed('/admin/dashboard');
  }

  void logout() {
    isLoggedIn.value = false;
    Get.offNamed('/admin/login');
  }
}
