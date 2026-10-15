import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/errors/app_exceptions.dart';
import '../../../../core/platform/file_selector.dart';
import '../../../../core/supabase/role_permissions.dart';
import '../../../../data/models/media_model.dart';
import '../../../../data/repositories/media_repository.dart';
import '../../auth/controllers/admin_auth_controller.dart';

/// Media library CMS. Lists Storage-backed rows, uploads via the browser
/// picker and keeps alt-text/delete scoped to the repository result.
class AdminMediaController extends GetxController {
  final MediaRepository mediaRepository;
  final PlatformFileSelector _selector;

  AdminMediaController({
    required this.mediaRepository,
    PlatformFileSelector? selector,
  }) : _selector = selector ?? const WebFileSelector();

  static const int pageSize = 24;

  final RxBool isLoading = true.obs;
  final RxBool isUploading = false.obs;
  final RxnString errorMessage = RxnString();
  final RxList<MediaModel> items = <MediaModel>[].obs;

  int _offset = 0;

  /// True only when the last fetch filled a whole page, which is the only
  /// signal the repository gives that more rows remain. `_offset >= items.length`
  /// was always true, so the library looked endlessly pageable. Reactive so the
  /// Load more control disappears once the tail page has been fetched.
  final RxBool hasMore = false.obs;

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load({bool refresh = true}) async {
    if (refresh) _offset = 0;
    isLoading.value = true;
    errorMessage.value = null;
    try {
      final page =
          await mediaRepository.listMedia(limit: pageSize, offset: _offset);
      if (refresh) {
        items.assignAll(page);
      } else {
        items.addAll(page);
      }
      _offset += page.length;
      hasMore.value = page.length == pageSize;
    } on AppException catch (e) {
      errorMessage.value = e.message;
    } catch (_) {
      errorMessage.value = 'Could not load media.';
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> loadMore() async {
    if (isLoading.value || !hasMore.value) return;
    isLoading.value = true;
    try {
      final page =
          await mediaRepository.listMedia(limit: pageSize, offset: _offset);
      items.addAll(page);
      _offset += page.length;
      hasMore.value = page.length == pageSize;
    } on AppException catch (e) {
      errorMessage.value = e.message;
    } catch (_) {
      errorMessage.value = 'Could not load more media.';
    } finally {
      isLoading.value = false;
    }
  }

  /// `media_insert/update/delete_site_editor` are the rule; refusing here keeps
  /// a stale widget from being the only check.
  bool _blocked(bool Function(AdminRole role) capability, String message) {
    if (AdminAuthController.allows(capability)) return false;
    Get.snackbar('Not Allowed', message,
        backgroundColor: Colors.red, colorText: Colors.white);
    return true;
  }

  Future<void> upload() async {
    if (_blocked(
        RolePermissions.canManageContent, 'Only editors and admins can upload media.')) {
      return;
    }
    final PickedFile? picked;
    try {
      picked = await _selector.pickImage();
    } on UnsupportedError {
      Get.snackbar('Unavailable',
          'File picking only works when the site runs in a browser.',
          backgroundColor: Colors.orange, colorText: Colors.white);
      return;
    } catch (_) {
      Get.snackbar('Error', 'The file picker failed to open.',
          backgroundColor: Colors.red, colorText: Colors.white);
      return;
    }
    if (picked == null) return;

    isUploading.value = true;
    try {
      final created = await mediaRepository.uploadMedia(
        fileName: picked.name,
        bytes: Uint8List.fromList(picked.bytes),
        mimeType: _mimeFor(picked.name),
      );
      items.insert(0, created);
      // Newest-first ordering means this row pushes every older row one slot
      // down; without the bump the next page re-fetches the last asset we have.
      _offset += 1;
      Get.snackbar('Uploaded', 'Media added to the library.',
          backgroundColor: Colors.green, colorText: Colors.white);
    } on AppException catch (e) {
      Get.snackbar('Error', e.message,
          backgroundColor: Colors.red, colorText: Colors.white);
    } catch (e) {
      Get.snackbar('Error', '$e',
          backgroundColor: Colors.red, colorText: Colors.white);
    } finally {
      isUploading.value = false;
    }
  }

  Future<void> updateAltText(String id, String altText) async {
    if (_blocked(RolePermissions.canManageContent,
        'Only editors and admins can edit media.')) {
      return;
    }
    try {
      final updated =
          await mediaRepository.updateMediaMetadata(id, altText: altText);
      if (updated == null) {
        Get.snackbar('Error', 'That asset no longer exists.',
            backgroundColor: Colors.red, colorText: Colors.white);
        return;
      }
      final index = items.indexWhere((m) => m.id == id);
      if (index != -1) items[index] = updated;
      Get.snackbar('Saved', 'Alt text updated.',
          backgroundColor: Colors.green, colorText: Colors.white);
    } on AppException catch (e) {
      Get.snackbar('Error', e.message,
          backgroundColor: Colors.red, colorText: Colors.white);
    } catch (_) {
      Get.snackbar('Error', 'Could not update the asset.',
          backgroundColor: Colors.red, colorText: Colors.white);
    }
  }

  Future<void> deleteMedia(String id) async {
    if (_blocked(RolePermissions.canManageContent,
        'Only editors and admins can delete media.')) {
      return;
    }
    try {
      final ok = await mediaRepository.deleteMedia(id);
      if (!ok) {
        Get.snackbar('Error', 'That asset was already removed.',
            backgroundColor: Colors.red, colorText: Colors.white);
        return;
      }
      items.removeWhere((m) => m.id == id);
      // Removing a row from the fetched window pulls every older row up one
      // slot, so the next page would otherwise jump past one asset.
      if (_offset > 0) _offset -= 1;
      Get.snackbar('Deleted', 'Asset removed.',
          backgroundColor: Colors.grey.shade900, colorText: Colors.white);
    } on AppException catch (e) {
      Get.snackbar('Error', e.message,
          backgroundColor: Colors.red, colorText: Colors.white);
    } catch (_) {
      Get.snackbar('Error', 'Could not delete the asset.',
          backgroundColor: Colors.red, colorText: Colors.white);
    }
  }

  static String _mimeFor(String fileName) {
    final ext =
        fileName.contains('.') ? fileName.split('.').last.toLowerCase() : '';
    switch (ext) {
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'gif':
        return 'image/gif';
      case 'svg':
        return 'image/svg+xml';
      case 'avif':
        return 'image/avif';
      default:
        return 'image/jpeg';
    }
  }
}
