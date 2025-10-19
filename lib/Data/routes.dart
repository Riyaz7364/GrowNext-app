import 'package:get/get.dart';
import 'package:grownext/Data/bindings.dart';
import 'package:grownext/Screens/login.dart';
import 'package:grownext/Screens/main_screen.dart';

const String loginPage = "/";
const String homePage = "/home";

List<GetPage> pages = [
  GetPage(name: loginPage, page: () => LoginScreen()),
  GetPage(
    name: homePage,
    page: () => MainScreen(),
    bindings: [AttendanceBinding(), HomeBinding()],
  ),
];
