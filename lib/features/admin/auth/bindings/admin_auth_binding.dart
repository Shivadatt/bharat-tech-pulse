import 'package:get/get.dart';
import '../controllers/admin_auth_controller.dart';

class AdminAuthBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<AdminAuthController>(() => AdminAuthController());
  }
}
