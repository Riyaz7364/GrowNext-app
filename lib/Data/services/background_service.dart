import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get_x_storage/get_x_storage.dart';

Position? lastPosition;
double totalDistanceKm = 0.0;

@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  return true;
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();
  await GetXStorage.init();
  final storage = GetXStorage();

  // Initialize running timer from storage
  int runningSeconds = storage.read<int>(key: 'running_timer') ?? 0;

  // Android foreground/background setup
  if (service is AndroidServiceInstance) {
    service
        .on('setAsForeground')
        .listen((event) => service.setAsForegroundService());
    service
        .on('setAsBackground')
        .listen((event) => service.setAsBackgroundService());
    service.on('stopService').listen((event) => service.stopSelf());
  }

  // 1-second timer for notification update
  Timer.periodic(Duration(seconds: 1), (timer) async {
    runningSeconds++;
    await storage.write(key: 'running_timer', value: runningSeconds);

    if (service is AndroidServiceInstance) {
      service.setForegroundNotificationInfo(
        title: "Attendance Tracker",
        content:
            "Running: ${_formatDuration(Duration(seconds: runningSeconds))}, Distance: ${totalDistanceKm.toStringAsFixed(2)} km",
      );
    }

    service.invoke('update', {"runningSeconds": runningSeconds});
  });

  // Timer to run every minute
  Timer.periodic(Duration(minutes: 1), (timer) async {
    try {
      final hasConnection = await _checkInternet();
      if (hasConnection) {
        await _sendTimerToServer(runningSeconds);
      }

      // Every 5 minutes, send location + distance
      if (runningSeconds % 5 == 0) {
        // Todo Send Location to server
        await _performTrackOnce(service, storage, runningSeconds);
      }

      service.invoke('PosUpdate', {
        "distanceKm": totalDistanceKm,
        "lastPosition": lastPosition?.toJson(),
      });
    } catch (e) {
      debugPrint('Error in periodic timer: $e');
    }
  });
}

Future<void> _performTrackOnce(
  ServiceInstance service,
  GetXStorage storage,
  int runningSeconds,
) async {
  try {
    final position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.best,
    );

    // Skip inaccurate readings
    if (position.accuracy > 50) {
      debugPrint("Skipping inaccurate GPS reading: ${position.accuracy}m");
      return;
    }

    double distanceMeters = 0;

    if (lastPosition != null) {
      distanceMeters = Geolocator.distanceBetween(
        lastPosition!.latitude,
        lastPosition!.longitude,
        position.latitude,
        position.longitude,
      );

      // Skip tiny GPS noise (<10m)
      if (distanceMeters < 10) {
        debugPrint(
          "Skipping small movement (${distanceMeters.toStringAsFixed(2)}m)",
        );
        return;
      }

      // Skip unrealistic jumps (>1km in one minute)
      if (distanceMeters > 1000) {
        debugPrint(
          "Skipping unrealistic jump (${distanceMeters.toStringAsFixed(2)}m)",
        );
        return;
      }

      totalDistanceKm += distanceMeters / 1000.0;
    }

    lastPosition = position;

    final data = {
      "timestamp": DateTime.now().toIso8601String(),
      "lat": position.latitude,
      "lng": position.longitude,
      "duration": runningSeconds,
      "distanceKm": totalDistanceKm,
    };

    final hasConnection = await _checkInternet();
    if (hasConnection) {
      await _syncPendingData(storage);
      await _sendToServer(data);
    } else {
      final List<String> pending =
          storage.read<List<String>>(key: 'pending_locations') ?? [];
      pending.add(jsonEncode(data));
      await storage.write(key: 'pending_locations', value: pending);
      debugPrint("Offline: stored location locally (${pending.length})");
    }

    debugPrint(
      "Distance added: ${(distanceMeters / 1000).toStringAsFixed(3)} km | Total: ${totalDistanceKm.toStringAsFixed(2)} km",
    );
  } catch (e) {
    debugPrint('Location tracking error: $e');
  }
}

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
        android: AndroidInitializationSettings('ic_bg_service_small'),
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
      initialNotificationTitle: 'Attendance Tracker',
      initialNotificationContent: 'Service running.',
      foregroundServiceNotificationId: 888,
      foregroundServiceTypes: [AndroidForegroundType.location],
    ),
    iosConfiguration: IosConfiguration(
      autoStart: false,
      onForeground: onStart,
      onBackground: onIosBackground,
    ),
  );
}

// Check internet connectivity
Future<bool> _checkInternet() async {
  try {
    final result = await Dio()
        .get('https://google.com')
        .timeout(const Duration(seconds: 5));
    return result.statusCode == 200;
  } catch (_) {
    return false;
  }
}

// Send location to server
Future<void> _sendToServer(Map<String, dynamic> data) async {
  debugPrint("Sending data to server: $data");
  // TODO: Replace with your API call
}

// Send running timer to server
Future<void> _sendTimerToServer(int seconds) async {
  debugPrint("Sending running timer to server: $seconds s");
  // TODO: Replace with your API call
}

// Sync pending offline locations
Future<void> _syncPendingData(GetXStorage storage) async {
  final List<String>? pending = storage.read<List<String>>(
    key: 'pending_locations',
  );
  if (pending == null || pending.isEmpty) return;

  debugPrint("🔁 Syncing ${pending.length} pending records...");
  for (var record in pending) {
    final map = Map<String, dynamic>.from(jsonDecode(record));
    await _sendToServer(map);
  }
  await storage.remove(key: 'pending_locations');
  debugPrint("✅ All pending data synced");
}

// Format duration as hh:mm:ss
String _formatDuration(Duration d) {
  final h = d.inHours.toString().padLeft(2, '0');
  final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return "$h:$m:$s";
}
