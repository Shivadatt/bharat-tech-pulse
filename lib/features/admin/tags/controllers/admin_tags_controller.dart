import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/errors/app_exceptions.dart';
import '../../../../data/models/tag_model.dart';
import '../../../../data/repositories/category_repository.dart';

/// Repository-backed CMS for topic tags.
class AdminTagsController extends GetxController {
  final CategoryRepository categoryRepository;

  AdminTagsController({required this.categoryRepository});

  final RxBool isLoading = true.obs;
  final RxnString errorMessage = RxnString();
  final RxList<TagModel> tags = <TagModel>[].obs;

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load() async {
    isLoading.value = true;
    errorMessage.value = null;
    try {
      tags.assignAll(await categoryRepository.getTags());
    } on AppException catch (e) {
      errorMessage.value = e.message;
    } catch (_) {
      errorMessage.value = 'Could not load tags.';
    } finally {
      isLoading.value = false;
    }
  }

  bool _validate(TagModel t) {
    if (t.name.trim().isEmpty || t.slug.trim().isEmpty) {
      _fail('Name and slug are required.');
      return false;
    }
    return true;
  }

  Future<bool> createTag(TagModel draft) async {
    if (!_validate(draft)) return false;
    try {
      final created = await categoryRepository.createTag(draft);
      tags.add(created);
      Get.snackbar('Created', 'Tag saved.',
          backgroundColor: Colors.green, colorText: Colors.white);
      return true;
    } on AppException catch (e) {
      _fail(e.message);
    } catch (_) {
      _fail('Could not save the tag.');
    }
    return false;
  }

  Future<bool> deleteTag(String id) async {
    try {
      final ok = await categoryRepository.deleteTag(id);
      if (!ok) {
        _fail('The tag was already removed.');
        return false;
      }
      tags.removeWhere((t) => t.id == id);
      Get.snackbar('Deleted', 'Tag removed.',
          backgroundColor: Colors.grey.shade900, colorText: Colors.white);
      return true;
    } on AppException catch (e) {
      _fail(e.message);
    } catch (_) {
      _fail('Could not delete the tag.');
    }
    return false;
  }

  void _fail(String message) => Get.snackbar('Error', message,
      backgroundColor: Colors.red, colorText: Colors.white);
}
