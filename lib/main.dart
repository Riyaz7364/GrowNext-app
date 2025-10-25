import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:grownext/Data/bindings.dart';
import 'package:grownext/Data/routes.dart';
import 'package:grownext/Data/services/background_service.dart';
// import 'package:grownext/Data/services/background_service.dart'; // Temporarily disabled for debugging
import 'package:grownext/Data/theme/theme.dart';
import 'package:grownext/service_location.dart';
import 'Data/consts/app_string.dart';
import 'package:timezone/data/latest.dart' as tz;

// Initialize background service
Future<void> initializeService() async {
  final service = FlutterBackgroundService();

  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'my_foreground',
    'MY FOREGROUND SERVICE',
    description: 'This channel is used for important notifications.',
    importance: Importance.low,
  );

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  if (Platform.isAndroid || Platform.isIOS) {
    await flutterLocalNotificationsPlugin.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@drawable/ic_notification'),

        iOS: DarwinInitializationSettings(),
      ),
    );
  }

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >()
      ?.createNotificationChannel(channel);

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      autoStart: false,
      isForegroundMode: true,
      notificationChannelId: 'my_foreground',
      initialNotificationTitle: 'GrowNext App',
      initialNotificationContent: 'Starting background service',
      foregroundServiceNotificationId: 888,
      foregroundServiceTypes: [AndroidForegroundType.location],
    ),
    iosConfiguration: IosConfiguration(
      autoStart: false,
      onForeground: onStart,
      onBackground: onIosBackground,
    ),
  );

  flutterLocalNotificationsPlugin.getNotificationAppLaunchDetails().then((
    details,
  ) {
    if (details != null && details.didNotificationLaunchApp) {
      // Handle notification click when app is terminated
      print('App launched from notification');
      sl<GetStorage>().write("notification_clicked", true);
    }
  });
}

void main() async {
  print('🚀 Starting app initialization...');
  WidgetsFlutterBinding.ensureInitialized();
  print('✅ Flutter binding initialized');
  tz.initializeTimeZones();

  await loadSL();
  print('✅ GetStorage initialized & Service locator loaded');

  initializeService();

  print('🎯 Running app...');
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    print('🎨 Building MyApp...');
    return GetMaterialApp(
      title: appName,
      theme: appTheme,
      initialRoute: loginPage,
      initialBinding: AuthBinding(),
      getPages: pages,
      debugShowCheckedModeBanner: false,
      unknownRoute: GetPage(
        name: '/unknown',
        page: () => Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 64),
                SizedBox(height: 16),
                Text('Unknown Route'),
                SizedBox(height: 8),
                Text('Debug: Route not found'),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
