import 'package:get/get.dart';

import '../../../../core/errors/app_exceptions.dart';
import '../../../../data/models/analytics_summary_model.dart';
import '../../../../data/repositories/analytics_repository.dart';

/// Audience analytics. Numbers come only from [AnalyticsRepository.getSummary]
/// (server-side counts); an unauthorised caller sees a locked state rather
/// than invented figures.
class AdminAnalyticsController extends GetxController {
  final AnalyticsRepository analyticsRepository;

  AdminAnalyticsController({required this.analyticsRepository});

  final RxBool isLoading = true.obs;
  final RxnString errorMessage = RxnString();
  final Rx<AnalyticsSummary?> summary = Rx<AnalyticsSummary?>(null);

  bool get hasAccess => summary.value?.hasAccess ?? false;

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load({int days = 30}) async {
    isLoading.value = true;
    errorMessage.value = null;
    try {
      summary.value = await analyticsRepository.getSummary(days: days);
    } on AppException catch (e) {
      summary.value = null;
      errorMessage.value = e.message;
    } catch (_) {
      summary.value = null;
      errorMessage.value = 'Could not load analytics.';
    } finally {
      isLoading.value = false;
    }
  }
}
