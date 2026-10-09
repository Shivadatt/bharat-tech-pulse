import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/errors/app_exceptions.dart';
import '../../../../data/models/article_model.dart';
import '../../../../data/repositories/post_admin_repository.dart';

/// Scheduled publishing queue. Reads come from [PostAdminRepository.listScheduled]
/// and rescheduling patches only the go-live time.
class AdminScheduledController extends GetxController {
  final PostAdminRepository postAdminRepository;

  AdminScheduledController({required this.postAdminRepository});

  static const int pageSize = 50;

  final RxBool isLoading = true.obs;
  final RxnString errorMessage = RxnString();
  final RxList<ArticleModel> scheduled = <ArticleModel>[].obs;

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load() async {
    isLoading.value = true;
    errorMessage.value = null;
    try {
      final rows = <ArticleModel>[];
      rows.addAll(await postAdminRepository.listScheduled(
          upcomingOnly: true, limit: pageSize));
      rows.addAll(await postAdminRepository.listScheduled(
          upcomingOnly: false, limit: pageSize));
      final seen = <String>{};
      scheduled.assignAll(rows.where((a) => seen.add(a.id)).toList());
    } on AppException catch (e) {
      errorMessage.value = e.message;
    } catch (_) {
      errorMessage.value = 'Could not load the schedule.';
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> publishNow(ArticleModel post) async {
    try {
      final ok = await postAdminRepository.patch(
        post.id,
        status: ArticleStatus.published,
        publishedAt: DateTime.now(),
        clearScheduledFor: true,
      );
      if (!ok) {
        _fail('The post is no longer editable.');
        return;
      }
      scheduled.removeWhere((a) => a.id == post.id);
      Get.snackbar('Published', 'The post is now live.',
          backgroundColor: Colors.green, colorText: Colors.white);
    } on AppException catch (e) {
      _fail(e.message);
    } catch (_) {
      _fail('Could not publish the post.');
    }
  }

  Future<void> reschedule(ArticleModel post, DateTime when) async {
    try {
      final ok = await postAdminRepository.patch(
        post.id,
        status: ArticleStatus.scheduled,
        scheduledFor: when,
      );
      if (!ok) {
        _fail('The post is no longer editable.');
        return;
      }
      scheduled.assignAll(
          scheduled.map((a) => a.id == post.id ? a.copyWith(scheduledFor: when) : a));
      Get.snackbar('Rescheduled', 'New go-live time saved.',
          backgroundColor: Colors.green, colorText: Colors.white);
    } on AppException catch (e) {
      _fail(e.message);
    } catch (_) {
      _fail('Could not reschedule the post.');
    }
  }

  void _fail(String message) => Get.snackbar('Error', message,
      backgroundColor: Colors.red, colorText: Colors.white);
}
