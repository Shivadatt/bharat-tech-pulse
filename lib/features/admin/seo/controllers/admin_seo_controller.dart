import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/errors/app_exceptions.dart';
import '../../../../data/models/site_settings_model.dart';
import '../../../../data/repositories/site_settings_repository.dart';

/// SEO defaults live on the `site_settings` row. This controller edits the
/// global meta fields and persists them through the same repository the
/// settings screen uses, so nothing is faked locally.
class AdminSeoController extends GetxController {
  final SiteSettingsRepository siteSettingsRepository;

  AdminSeoController({required this.siteSettingsRepository});

  final RxBool isLoading = true.obs;
  final RxBool isSaving = false.obs;
  final RxnString errorMessage = RxnString();

  final metaTitleController = TextEditingController();
  final metaDescController = TextEditingController();
  final gaIdController = TextEditingController();

  SiteSettingsModel? _loaded;

  @override
  void onInit() {
    super.onInit();
    load();
  }

  @override
  void onClose() {
    metaTitleController.dispose();
    metaDescController.dispose();
    gaIdController.dispose();
    super.onClose();
  }

  Future<void> load() async {
    isLoading.value = true;
    errorMessage.value = null;
    try {
      final s = await siteSettingsRepository.getSettings();
      _loaded = s;
      metaTitleController.text = s?.defaultMetaTitle ?? '';
      metaDescController.text = s?.defaultMetaDescription ?? '';
      gaIdController.text = s?.googleAnalyticsId ?? '';
    } on AppException catch (e) {
      errorMessage.value = e.message;
    } catch (_) {
      errorMessage.value = 'Could not load SEO settings.';
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> save() async {
    isSaving.value = true;
    final base = _loaded ?? const SiteSettingsModel();
    final merged = SiteSettingsModel(
      id: base.id,
      siteName: base.siteName,
      tagline: base.tagline,
      logoUrl: base.logoUrl,
      faviconUrl: base.faviconUrl,
      defaultMetaTitle: metaTitleController.text.trim(),
      defaultMetaDescription: metaDescController.text.trim(),
      contactEmail: base.contactEmail,
      socialLinks: Map.of(base.socialLinks),
      footerText: base.footerText,
      copyrightText: base.copyrightText,
      googleAnalyticsId: gaIdController.text.trim(),
      updatedAt: base.updatedAt,
    );
    try {
      final saved = await siteSettingsRepository.saveSettings(merged);
      _loaded = saved;
      Get.snackbar('Saved', 'SEO defaults updated.',
          backgroundColor: Colors.green, colorText: Colors.white);
    } on AppException catch (e) {
      Get.snackbar('Error', e.message,
          backgroundColor: Colors.red, colorText: Colors.white);
    } catch (_) {
      Get.snackbar('Error', 'Could not save SEO settings.',
          backgroundColor: Colors.red, colorText: Colors.white);
    } finally {
      isSaving.value = false;
    }
  }
}
