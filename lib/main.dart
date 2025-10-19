import 'package:get/get_navigation/src/root/get_material_app.dart';
import 'package:get_x_storage/get_x_storage.dart';
import 'package:grownext/Data/bindings.dart';
import 'package:grownext/Data/routes.dart';
import 'package:grownext/Data/services/background_service.dart';
import 'package:grownext/Data/theme/theme.dart';
import 'package:grownext/service_location.dart';
import 'Data/consts/app_string.dart';
import 'package:flutter/material.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await GetXStorage.init();
  await loadSL();
  await initializeService();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: appName,
      theme: appTheme,
      initialBinding: AuthBinding(),
      getPages: pages,
    );
  }
}
