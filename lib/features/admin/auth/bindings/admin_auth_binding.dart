import 'package:get/get.dart';
import '../controllers/admin_auth_controller.dart';

class AdminAuthBinding extends Bindings {
  @override
  void dependencies() {
    // InitialBinding may have already instantiated the controller (session
    // restore); never replace that registration or restored state is lost.
    if (!Get.isRegistered<AdminAuthController>()) {
      Get.lazyPut<AdminAuthController>(() => AdminAuthController());
    }
  }
}
