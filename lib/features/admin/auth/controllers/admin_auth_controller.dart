import 'package:flutter/material.dart';
import 'package:get/get.dart';

class AdminAuthController extends GetxController {
  final emailController = TextEditingController(text: 'editor@bharattechpulse.in');
  final passwordController = TextEditingController(text: 'admin123');

  final RxBool isLoggedIn = true.obs; // Mock default logged in for dev convenience
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
