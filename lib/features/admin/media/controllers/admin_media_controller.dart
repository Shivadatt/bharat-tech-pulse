import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/errors/app_exceptions.dart';
import '../../../../core/platform/file_selector.dart';
import '../../../../data/models/media_model.dart';
import '../../../../data/repositories/media_repository.dart';

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
  bool get hasMore => _offset >= items.length;

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
    } on AppException catch (e) {
      errorMessage.value = e.message;
    } catch (_) {
      errorMessage.value = 'Could not load media.';
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> loadMore() async {
    if (isLoading.value) return;
    isLoading.value = true;
    try {
      final page =
          await mediaRepository.listMedia(limit: pageSize, offset: _offset);
      items.addAll(page);
      _offset += page.length;
    } on AppException catch (e) {
      errorMessage.value = e.message;
    } catch (_) {
      errorMessage.value = 'Could not load more media.';
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> upload() async {
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
    try {
      final ok = await mediaRepository.deleteMedia(id);
      if (!ok) {
        Get.snackbar('Error', 'That asset was already removed.',
            backgroundColor: Colors.red, colorText: Colors.white);
        return;
      }
      items.removeWhere((m) => m.id == id);
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
