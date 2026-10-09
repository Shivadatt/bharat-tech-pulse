import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/errors/app_exceptions.dart';
import '../../../../data/models/category_model.dart';
import '../../../../data/repositories/category_repository.dart';

/// Repository-backed CMS for categories. Reads go through
/// [CategoryRepository.getCategoriesForAdmin] so archived rows are visible;
/// every mutation is confirmed against the repository result before a toast.
class AdminCategoriesController extends GetxController {
  final CategoryRepository categoryRepository;

  AdminCategoriesController({required this.categoryRepository});

  final RxBool isLoading = true.obs;
  final RxnString errorMessage = RxnString();
  final RxList<CategoryModel> categories = <CategoryModel>[].obs;

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load() async {
    isLoading.value = true;
    errorMessage.value = null;
    try {
      final rows = await categoryRepository.getCategoriesForAdmin();
      categories.assignAll(rows);
    } on AppException catch (e) {
      errorMessage.value = e.message;
    } catch (_) {
      errorMessage.value = 'Could not load categories.';
    } finally {
      isLoading.value = false;
    }
  }

  bool _validate(CategoryModel c, {String? ignoreId}) {
    if (c.name.trim().isEmpty || c.slug.trim().isEmpty) {
      _fail('Name and slug are required.');
      return false;
    }
    return true;
  }

  Future<bool> createCategory(CategoryModel draft) async {
    if (!_validate(draft)) return false;
    try {
      final created = await categoryRepository.createCategory(draft);
      categories.add(created);
      Get.snackbar('Created', 'Category saved.',
          backgroundColor: Colors.green, colorText: Colors.white);
      return true;
    } on AppException catch (e) {
      _fail(e.message);
    } catch (_) {
      _fail('Could not save the category.');
    }
    return false;
  }

  Future<bool> updateCategory(CategoryModel category) async {
    if (!_validate(category, ignoreId: category.id)) return false;
    try {
      final ok = await categoryRepository.updateCategory(category);
      if (!ok) {
        _fail('The category no longer exists.');
        return false;
      }
      categories[categoryIndex(category.id)] = category;
      Get.snackbar('Updated', 'Category saved.',
          backgroundColor: Colors.green, colorText: Colors.white);
      return true;
    } on AppException catch (e) {
      _fail(e.message);
    } catch (_) {
      _fail('Could not update the category.');
    }
    return false;
  }

  int categoryIndex(String id) =>
      categories.indexWhere((c) => c.id == id);

  Future<bool> deleteCategory(String id) async {
    try {
      final ok = await categoryRepository.deleteCategory(id);
      if (!ok) {
        _fail('The category was already removed.');
        return false;
      }
      categories.removeWhere((c) => c.id == id);
      Get.snackbar('Deleted', 'Category removed.',
          backgroundColor: Colors.grey.shade900, colorText: Colors.white);
      return true;
    } on AppException catch (e) {
      _fail(e.message);
    } catch (_) {
      _fail('Could not delete the category.');
    }
    return false;
  }

  void _fail(String message) => Get.snackbar('Error', message,
      backgroundColor: Colors.red, colorText: Colors.white);
}
