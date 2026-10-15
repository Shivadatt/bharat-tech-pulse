import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/errors/app_exceptions.dart';
import '../../../../core/supabase/role_permissions.dart';
import '../../../../data/models/category_model.dart';
import '../../../../data/repositories/category_repository.dart';
import '../../auth/controllers/admin_auth_controller.dart';

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

  /// UI gating is the courtesy; `categories_insert/update_site_editor` and
  /// `categories_delete_site_admin` are the rule. Refuse locally too, so a
  /// stale widget is never the only check.
  bool _blocked(
    bool Function(AdminRole role) capability,
    String message,
  ) {
    if (AdminAuthController.allows(capability)) return false;
    _fail(message);
    return true;
  }

  Future<bool> createCategory(CategoryModel draft) async {
    if (_blocked(RolePermissions.canManageContent,
            'Only editors and admins can change the category taxonomy.')) {
      return false;
    }
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
    if (_blocked(RolePermissions.canManageContent,
            'Only editors and admins can change the category taxonomy.')) {
      return false;
    }
    if (!_validate(category, ignoreId: category.id)) return false;
    try {
      final ok = await categoryRepository.updateCategory(category);
      if (!ok) {
        _fail('The category no longer exists.');
        return false;
      }
      final index = categoryIndex(category.id);
      // A -1 index here threw RangeError on `categories[-1] = ...`: the write
      // had already succeeded remotely, but the CMS showed a red error and
      // kept the stale row on screen.
      if (index == -1) {
        categories.add(category);
      } else {
        categories[index] = category;
      }
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
    if (_blocked(RolePermissions.canDeleteRecords,
        'Only site admins can delete categories.')) {
      return false;
    }
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
