import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/errors/app_exceptions.dart';
import '../../../../core/supabase/role_permissions.dart';
import '../../../../data/models/author_model.dart';
import '../../../../data/repositories/category_repository.dart';
import '../../auth/controllers/admin_auth_controller.dart';

/// Repository-backed CMS for author bylines. Reads use
/// [CategoryRepository.getAuthorsForAdmin] (archived bylines included).
class AdminAuthorsController extends GetxController {
  final CategoryRepository categoryRepository;

  AdminAuthorsController({required this.categoryRepository});

  final RxBool isLoading = true.obs;
  final RxnString errorMessage = RxnString();
  final RxList<AuthorModel> authors = <AuthorModel>[].obs;

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load() async {
    isLoading.value = true;
    errorMessage.value = null;
    try {
      authors.assignAll(await categoryRepository.getAuthorsForAdmin());
    } on AppException catch (e) {
      errorMessage.value = e.message;
    } catch (_) {
      errorMessage.value = 'Could not load authors.';
    } finally {
      isLoading.value = false;
    }
  }

  bool _validate(AuthorModel a) {
    if (a.name.trim().isEmpty || a.slug.trim().isEmpty) {
      _fail('Name and slug are required.');
      return false;
    }
    return true;
  }

  /// `authors_insert/update/delete_site_admin` is the enforcement; this keeps
  /// the panel from advertising a write the server would reject.
  bool _blocked(
    bool Function(AdminRole role) capability,
    String message,
  ) {
    if (AdminAuthController.allows(capability)) return false;
    _fail(message);
    return true;
  }

  Future<bool> createAuthor(AuthorModel draft) async {
    if (_blocked(RolePermissions.canManageSettings,
        'Only site admins can add contributor bylines.')) {
      return false;
    }
    if (!_validate(draft)) return false;
    try {
      final created = await categoryRepository.createAuthor(draft);
      authors.add(created);
      Get.snackbar('Created', 'Author saved.',
          backgroundColor: Colors.green, colorText: Colors.white);
      return true;
    } on AppException catch (e) {
      _fail(e.message);
    } catch (_) {
      _fail('Could not save the author.');
    }
    return false;
  }

  Future<bool> updateAuthor(AuthorModel author) async {
    if (_blocked(RolePermissions.canManageSettings,
        'Only site admins can edit contributor bylines.')) {
      return false;
    }
    if (!_validate(author)) return false;
    try {
      final ok = await categoryRepository.updateAuthor(author);
      if (!ok) {
        _fail('The author no longer exists.');
        return false;
      }
      final index = authors.indexWhere((a) => a.id == author.id);
      if (index != -1) authors[index] = author;
      Get.snackbar('Updated', 'Author saved.',
          backgroundColor: Colors.green, colorText: Colors.white);
      return true;
    } on AppException catch (e) {
      _fail(e.message);
    } catch (_) {
      _fail('Could not update the author.');
    }
    return false;
  }

  Future<bool> deleteAuthor(String id) async {
    if (_blocked(RolePermissions.canDeleteRecords,
        'Only site admins can delete contributor bylines.')) {
      return false;
    }
    try {
      final ok = await categoryRepository.deleteAuthor(id);
      if (!ok) {
        _fail('The author was already removed.');
        return false;
      }
      authors.removeWhere((a) => a.id == id);
      Get.snackbar('Deleted', 'Author removed.',
          backgroundColor: Colors.grey.shade900, colorText: Colors.white);
      return true;
    } on AppException catch (e) {
      _fail(e.message);
    } catch (_) {
      _fail('Could not delete the author.');
    }
    return false;
  }

  void _fail(String message) => Get.snackbar('Error', message,
      backgroundColor: Colors.red, colorText: Colors.white);
}
