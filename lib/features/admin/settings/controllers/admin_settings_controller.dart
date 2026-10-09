import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/errors/app_exceptions.dart';
import '../../../../data/models/site_settings_model.dart';
import '../../../../data/repositories/site_settings_repository.dart';

/// Site-wide settings editor. Loads the single `site_settings` row through
/// [SiteSettingsRepository]; saving is only confirmed after the backend
/// returns the persisted row.
class AdminSettingsController extends GetxController {
  final SiteSettingsRepository siteSettingsRepository;

  AdminSettingsController({required this.siteSettingsRepository});

  final RxBool isLoading = true.obs;
  final RxBool isSaving = false.obs;
  final RxnString errorMessage = RxnString();

  final siteNameController = TextEditingController();
  final taglineController = TextEditingController();
  final contactEmailController = TextEditingController();
  final footerTextController = TextEditingController();
  final copyrightController = TextEditingController();
  final twitterController = TextEditingController();
  final youtubeController = TextEditingController();
  final telegramController = TextEditingController();
  final linkedinController = TextEditingController();

  SiteSettingsModel? _loaded;

  @override
  void onInit() {
    super.onInit();
    load();
  }

  @override
  void onClose() {
    for (final c in [
      siteNameController,
      taglineController,
      contactEmailController,
      footerTextController,
      copyrightController,
      twitterController,
      youtubeController,
      telegramController,
      linkedinController,
    ]) {
      c.dispose();
    }
    super.onClose();
  }

  Future<void> load() async {
    isLoading.value = true;
    errorMessage.value = null;
    try {
      final settings = await siteSettingsRepository.getSettings();
      _loaded = settings;
      _hydrate(settings ?? const SiteSettingsModel());
    } on AppException catch (e) {
      errorMessage.value = e.message;
    } catch (_) {
      errorMessage.value = 'Could not load site settings.';
    } finally {
      isLoading.value = false;
    }
  }

  void _hydrate(SiteSettingsModel s) {
    siteNameController.text = s.siteName;
    taglineController.text = s.tagline;
    contactEmailController.text = s.contactEmail;
    footerTextController.text = s.footerText;
    copyrightController.text = s.copyrightText;
    twitterController.text = s.socialLinks['twitter'] ?? '';
    youtubeController.text = s.socialLinks['youtube'] ?? '';
    telegramController.text = s.socialLinks['telegram'] ?? '';
    linkedinController.text = s.socialLinks['linkedin'] ?? '';
  }

  SiteSettingsModel _collect() {
    final base = _loaded ?? const SiteSettingsModel();
    return SiteSettingsModel(
      id: base.id,
      siteName: siteNameController.text.trim(),
      tagline: taglineController.text.trim(),
      logoUrl: base.logoUrl,
      faviconUrl: base.faviconUrl,
      defaultMetaTitle: base.defaultMetaTitle,
      defaultMetaDescription: base.defaultMetaDescription,
      contactEmail: contactEmailController.text.trim(),
      socialLinks: {
        'twitter': twitterController.text.trim(),
        'youtube': youtubeController.text.trim(),
        'telegram': telegramController.text.trim(),
        'linkedin': linkedinController.text.trim(),
      },
      footerText: footerTextController.text.trim(),
      copyrightText: copyrightController.text.trim(),
      googleAnalyticsId: base.googleAnalyticsId,
      updatedAt: base.updatedAt,
    );
  }

  Future<void> save() async {
    if (siteNameController.text.trim().isEmpty) {
      Get.snackbar('Validation Error', 'Site name is required.',
          backgroundColor: Colors.red, colorText: Colors.white);
      return;
    }
    isSaving.value = true;
    try {
      final saved = await siteSettingsRepository.saveSettings(_collect());
      _loaded = saved;
      _hydrate(saved);
      Get.snackbar('Saved', 'Site settings updated.',
          backgroundColor: Colors.green, colorText: Colors.white);
    } on AppException catch (e) {
      Get.snackbar('Error', e.message,
          backgroundColor: Colors.red, colorText: Colors.white);
    } catch (_) {
      Get.snackbar('Error', 'Could not save site settings.',
          backgroundColor: Colors.red, colorText: Colors.white);
    } finally {
      isSaving.value = false;
    }
  }
}
