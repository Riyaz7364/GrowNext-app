import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:battery_plus/battery_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_signal_strength/flutter_signal_strength.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get_storage/get_storage.dart';
import 'package:grownext/Data/api.dart';
import 'package:grownext/Data/extenstions/duration_to_ago.dart';
import 'package:grownext/Data/models/attendance_model.dart';
import 'package:grownext/Data/repositories/attendance_repo.dart';
import 'package:grownext/Data/services/timezone_service.dart';
import 'package:grownext/service_location.dart';
import 'package:nb_utils/nb_utils.dart';
import 'package:timezone/timezone.dart' as tz;

Position? lastPosition;
double totalDistanceKm = 0.0;
int runningMinuts = 1;
const String kClockInId = 'clock_in_id';
const String kClockInTime = 'clock_in_time';
const String kLastClockInId = 'last_clock_in_id';
const String kClockOutTime = 'clock_out_time';
const String kWorkHoursTime = 'work_hours_time';

// Global instance for notifications
FlutterLocalNotificationsPlugin? _flutterLocalNotificationsPlugin;
@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  return true;
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

  await GetStorage.init(kStorageContainer);
  final storage = GetStorage(kStorageContainer);
  await loadSL();
  final timezone = storage.read<String>('timezone') ?? 'Asia/Kolkata';
  sl<TimezoneService>().setTimeZone(timezone);

  // Initialize Flutter Local Notifications
  await _initializeLocalNotifications();

  // Initialize running timer from storage
  int runningMinutes = storage.read<int>('running_timer') ?? 0;

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

  // Single 1-minute timer to handle all operations
  int gpsTrackingCounter = 0; // Counter for GPS tracking (every 5 minutes)
  int offlineCounter = 0; // Counter for offline time tracking
  // Get initial position to set lastPosition for first distance calculation
  final initialPosition = await getCurrentPosition();
  if (initialPosition != null) {
    lastPosition = initialPosition;
    debugPrint("Initial position set: ${initialPosition.toString()}");
  }
  await _updateTrackingNotification(runningMinutes);
  Timer.periodic(Duration(minutes: 1), (timer) async {
    // try {
    runningMinutes += 60; // Increment by 60 seconds (1 minute)
    await storage.write('running_timer', runningMinutes);

    await _updateTrackingNotification(runningMinutes);

    // Check internet connection
    final hasConnection = await _checkInternet();

    // GPS tracking every 5 minutes
    gpsTrackingCounter++;
    if (gpsTrackingCounter >= 5) {
      await _performTrackOnce(service, storage, runningMinutes, hasConnection);
      gpsTrackingCounter = 0; // Reset counter
      await _updateTrackingNotification(runningMinutes);
    }

    // Handle offline/online state
    if (hasConnection) {
      // Reset offline counter when back online
      if (offlineCounter > 0) {
        debugPrint("🌐 Back online after ${offlineCounter} minutes offline");
        offlineCounter = 0;
      }

      // Sync any pending locations when online
      await _syncPendingLocations(storage);
      await _sendTimerToServer(runningMinutes, storage);
      final duration = runningMinutes / 60; //Total duration in minutes
      final maxWorkDuration = 12 * 60; // 12 hours in minutes
      // Check if over max duration
      if (duration >= maxWorkDuration) {
        debugPrint('Clock-in duration exceeded max time, forcing clock-out');
        await forceClockOut(service: service, storage: storage);
      }

      // Update notification using Flutter Local Notifications
    } else {
      // Increment offline counter
      offlineCounter++;
      debugPrint("📵 Offline for $offlineCounter minutes");
    }

    service.invoke('update', {"runningSeconds": runningMinutes});
    service.invoke('PosUpdate', {
      "distanceKm": totalDistanceKm.toStringAsFixed(2),
      "lastPosition": lastPosition?.toJson(),
    });
    // } catch (e) {
    //   debugPrint('Error in periodic timer: $e');
    // }
  });
}

Future<Position?> getCurrentPosition() async {
  final position = await Geolocator.getCurrentPosition(
    locationSettings: const LocationSettings(
      accuracy: LocationAccuracy.best,
      distanceFilter: 0,
    ),
  );

  // Skip inaccurate readings
  if (position.accuracy > 50) {
    debugPrint("Skipping inaccurate GPS reading: ${position.accuracy}m");
    return null;
  }
  debugPrint("Current position: ${position.toString()}");
  // Don't update lastPosition here - let _performTrackOnce handle it after distance calculation

  return position;
}

Future<void> _performTrackOnce(
  ServiceInstance service,
  GetStorage storage,
  int runningSeconds,
  bool hasConnection,
) async {
  try {
    final position = await getCurrentPosition();
    if (position == null) return;
    double distanceMeters = 0;

    debugPrint("lastPosition (${lastPosition.toString()})");

    if (lastPosition != null) {
      distanceMeters = Geolocator.distanceBetween(
        lastPosition!.latitude,
        lastPosition!.longitude,
        position.latitude,
        position.longitude,
      );
      debugPrint(
        "Distance calculated: ${distanceMeters.toStringAsFixed(2)}m between last(${lastPosition!.latitude},${lastPosition!.longitude}) and current(${position.latitude},${position.longitude})",
      );

      // Skip tiny GPS noise (<50m)
      if (distanceMeters < 50) {
        debugPrint(
          "Skipping small movement (${distanceMeters.toStringAsFixed(2)}m)",
        );
        return;
      }

      totalDistanceKm += distanceMeters / 1000.0;

      storage.write('total_distance_km', totalDistanceKm.toStringAsFixed(2));
    } else {
      debugPrint(
        "No previous position available - this is the first GPS reading",
      );
    }

    // Update lastPosition only after successful distance calculation
    lastPosition = position;

    // Get additional device info for the new endpoint
    final batteryLevel = await _getBatteryLevel();
    final signalStrength = await _getSignalStrength();
    final clockInOutId = storage.read<String>(kClockInId);

    final locationData = {
      "clock_in_out_id": clockInOutId,
      "latitude": position.latitude,
      "longitude": position.longitude,
      "travel_mode": "walking", // You can make this dynamic based on speed
      "battery_percentage": batteryLevel,
      "signal_strength": signalStrength,
      "recorded_at": sl<TimezoneService>().now().toIso8601String(),
    };

    if (hasConnection) {
      await _syncPendingLocations(storage);
      await _sendLocationToServer([locationData]);
    } else {
      await _storeLocationOffline(storage, locationData);
    }

    debugPrint(
      "Distance added: ${(distanceMeters / 1000).toStringAsFixed(3)} km | Total: ${totalDistanceKm.toStringAsFixed(2)} km",
    );
  } catch (e) {
    debugPrint('Location tracking error: $e');
  }
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

// Send running timer to server
Future<void> _sendTimerToServer(int seconds, GetStorage storage) async {
  debugPrint("Sending running timer to server: $seconds s");
  final createdAt = storage.read<String>("created_at");
  final clockInid = storage.read<String>(kClockInId) ?? '';
  final newAttendance = AttendanceModel(
    id: clockInid,
    duration: seconds.toDouble(),
    clientCreatedAt: sl<TimezoneService>().safeParse(createdAt ?? ''),
  );
  await sl<IAttendanceRepository>().clockIn([newAttendance]);
  // TODO: Replace with your API call
}

// Store location data offline with max 3 items
Future<void> _storeLocationOffline(
  GetStorage storage,
  Map<String, dynamic> locationData,
) async {
  try {
    final List<String> pending =
        storage.read<List<String>>('pending_locations') ?? [];

    // Add new location data
    pending.add(jsonEncode(locationData));

    // Keep only the last 3 items (remove oldest if more than 3)
    while (pending.length > 3) {
      pending.removeAt(0); // Remove the oldest item
    }

    await storage.write('pending_locations', pending);
    debugPrint("📵 Offline: stored location locally (${pending.length}/3 max)");

    if (pending.length == 3) {
      debugPrint("⚠️ Offline storage full - keeping only last 3 locations");
    }
  } catch (e) {
    debugPrint("❌ Error storing location offline: $e");
  }
}

// Initialize local notifications
Future<void> _initializeLocalNotifications() async {
  _flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@drawable/ic_notification');

  const DarwinInitializationSettings initializationSettingsIOS =
      DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

  const InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
    iOS: initializationSettingsIOS,
  );

  await _flutterLocalNotificationsPlugin?.initialize(initializationSettings);

  // Create notification channel for Android
  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'tracking_channel',
    'Location Tracking',
    description: 'Notifications for location tracking status',
    importance: Importance.low,
    playSound: false,
    enableVibration: false,
  );

  await _flutterLocalNotificationsPlugin
      ?.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >()
      ?.createNotificationChannel(channel);
}

// Update tracking notification
Future<void> _updateTrackingNotification(int runningSeconds) async {
  if (_flutterLocalNotificationsPlugin == null) return;

  const AndroidNotificationDetails androidNotificationDetails =
      AndroidNotificationDetails(
        'tracking_channel',
        'Location Tracking',
        channelDescription: 'Notifications for location tracking status',
        importance: Importance.low,
        priority: Priority.low,
        ongoing: true,
        autoCancel: false,
        playSound: false,
        enableVibration: false,
        showWhen: false,
        icon: '@drawable/ic_notification',
      );

  const DarwinNotificationDetails iOSNotificationDetails =
      DarwinNotificationDetails(
        presentAlert: false,
        presentBadge: false,
        presentSound: false,
      );

  const NotificationDetails notificationDetails = NotificationDetails(
    android: androidNotificationDetails,
    iOS: iOSNotificationDetails,
  );

  final String title = "GrowNext - Tracking Active";
  final String body =
      "Duration: ${_formatDuration(Duration(seconds: runningSeconds))} | Distance: ${totalDistanceKm.toStringAsFixed(2)} KM";

  await _flutterLocalNotificationsPlugin?.show(
    888, // Same ID as foreground service
    title,
    body,
    notificationDetails,
  );
}

// Send location data to the new endpoint
Future<void> _sendLocationToServer(List<Map<String, dynamic>> locations) async {
  try {
    final dio = sl<Dio>();
    final payload = {"locations": locations};
    debugPrint(locations[0].toString());
    debugPrint("Sending location data to server: $payload");

    final response = await dio.post(Api.locationsSync, data: payload);

    if (response.statusCode == 200) {
      debugPrint("✅ Location data sent successfully");
    } else {
      debugPrint("❌ Failed to send location data: ${response.statusCode}");
    }
  } catch (e) {
    debugPrint("❌ Error sending location data: $e");
    rethrow;
  }
}

// Sync pending offline locations with new endpoint
Future<void> _syncPendingLocations(GetStorage storage) async {
  final List<String>? pending = storage.read<List<String>>('pending_locations');
  if (pending == null || pending.isEmpty) return;

  debugPrint("🔁 Syncing ${pending.length} pending locations...");

  try {
    final List<Map<String, dynamic>> locations = [];
    for (var record in pending) {
      final locationData = Map<String, dynamic>.from(jsonDecode(record));
      locations.add(locationData);
    }

    await _sendLocationToServer(locations);
    await storage.remove('pending_locations');
    debugPrint("✅ All pending locations synced");
  } catch (e) {
    debugPrint("❌ Failed to sync pending locations: $e");
  }
}

// Get battery level (placeholder - requires battery_plus package)
Future<int> _getBatteryLevel() async {
  try {
    var battery = Battery();
    var batteryLevel = await battery.batteryLevel;
    return batteryLevel;
  } catch (e) {
    debugPrint("Error getting battery level: $e");
    return 0;
  }
}

// Get signal strength (placeholder - requires platform channels) // Only for android
Future<int> _getSignalStrength() async {
  final signalStrength = FlutterSignalStrength();
  try {
    final level = await signalStrength.getCellularSignalStrength();
    return level;
  } catch (e) {
    debugPrint("Error getting signal strength: $e");
    return 0;
  }
}

// Format duration as hh:mm:ss
String _formatDuration(Duration d) {
  final h = d.inHours.toString().padLeft(2, '0');
  final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
  return "$h:$m";
}

Future<void> forceClockOut({
  required GetStorage storage,
  required ServiceInstance service,
}) async {
  try {
    final now = sl<TimezoneService>().now();
    final clockInTime = sl<TimezoneService>().safeParse(
      storage.read<String>(kClockInTime),
    );
    final clockInId = storage.read<String>(kClockInId);
    final duration = now.difference(clockInTime);

    final attendance = AttendanceModel(
      endTime: now,
      endLat: lastPosition!.latitude,
      endLng: lastPosition!.longitude,
      duration: duration.inSeconds.toDouble(),
      id: clockInId,
    );

    await sl<IAttendanceRepository>().clockOut(attendance);

    // Clear saved state
    debugPrint('Keys before removal: ${storage.getKeys()}');
    await storage.remove(kClockInTime);
    await storage.remove(kClockInId);
    debugPrint('Keys after removal: ${storage.getKeys()}');

    // Save as last clock-in ID
    await storage.write(kLastClockInId, clockInId);

    // Update stored time
    await storage.write(kClockOutTime, now.toAmPmString());
    await storage.write(kWorkHoursTime, _formatDuration(duration));

    storage.write(kWorkHoursTime, _formatDuration(duration));
    // Stop tracking
    service.invoke('stopService');
  } catch (e) {
    debugPrint('Error in force clock-out: $e');
  }
}
