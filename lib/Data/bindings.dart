import 'package:get/get.dart';
import 'package:grownext/Data/Controllers/attendance_controller.dart';
import 'package:grownext/Data/Controllers/auth_controller.dart';
import 'package:grownext/Data/Controllers/home_controller.dart';

class AuthBinding implements Bindings {
  @override
  void dependencies() {
    Get.lazyPut<AuthController>(() => AuthController());
  }
}

class HomeBinding implements Bindings {
  @override
  void dependencies() {
    Get.lazyPut<HomeController>(() => HomeController());
  }
}

class AttendanceBinding implements Bindings {
  @override
  void dependencies() {
    Get.lazyPut<AttendanceController>(() => AttendanceController());
  }
}
