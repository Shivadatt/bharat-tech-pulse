import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/errors/app_exceptions.dart';
import '../../../../data/models/article_model.dart';
import '../../../../data/repositories/post_admin_repository.dart';

/// Curates the homepage trending slots. Posts are read through
/// [PostAdminRepository] and the toggle writes only the `is_trending` column,
/// never the editorial body.
class AdminTrendingController extends GetxController {
  final PostAdminRepository postAdminRepository;

  AdminTrendingController({required this.postAdminRepository});

  static const int pageSize = 50;

  final RxBool isLoading = true.obs;
  final RxnString errorMessage = RxnString();
  final RxList<ArticleModel> posts = <ArticleModel>[].obs;

  @override
  void onInit() {
    super.onInit();
    load();
  }

  List<ArticleModel> get trending =>
      posts.where((p) => p.isTrending).toList();

  Future<void> load() async {
    isLoading.value = true;
    errorMessage.value = null;
    try {
      posts.assignAll(await postAdminRepository.listAll(limit: pageSize));
    } on AppException catch (e) {
      errorMessage.value = e.message;
    } catch (_) {
      errorMessage.value = 'Could not load posts.';
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> setTrending(ArticleModel post, bool value) async {
    final index = posts.indexWhere((p) => p.id == post.id);
    if (index == -1) return;
    // Optimistic flip so the switch responds immediately; rolled back on
    // failure so the UI never shows a state the backend rejected.
    posts[index] = post.copyWith(isTrending: value);
    try {
      final ok = await postAdminRepository.patch(post.id, isTrending: value);
      if (!ok) {
        posts[index] = post;
        Get.snackbar('Error', 'That post is no longer editable.',
            backgroundColor: Colors.red, colorText: Colors.white);
        return;
      }
      Get.snackbar('Saved',
          value ? 'Added to trending.' : 'Removed from trending.',
          backgroundColor: Colors.green, colorText: Colors.white);
    } on AppException catch (e) {
      posts[index] = post;
      Get.snackbar('Error', e.message,
          backgroundColor: Colors.red, colorText: Colors.white);
    } catch (_) {
      posts[index] = post;
      Get.snackbar('Error', 'Could not update the trending flag.',
          backgroundColor: Colors.red, colorText: Colors.white);
    }
  }
}
