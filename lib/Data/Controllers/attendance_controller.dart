import 'dart:async';
import 'dart:io' show Platform;

import 'package:android_intent_plus/android_intent.dart';
import 'package:android_intent_plus/flag.dart';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

import 'package:grownext/Data/extenstions/duration_to_ago.dart';
import 'package:grownext/Data/models/attendance_model.dart';

import 'package:grownext/Data/repositories/attendance_repo.dart';
import 'package:grownext/Data/services/loading_service.dart';
import 'package:grownext/Data/services/timezone_service.dart';
import 'package:grownext/service_location.dart';

import 'package:logger/logger.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/timezone.dart' as tz;

class AttendanceController extends GetxController {
  final _logger = Logger();
  static const String kClockInId = 'clock_in_id';
  static const String kClockInTime = 'clock_in_time';
  static const String kTotalDistanceKm = 'total_distance_km';
  static const String kClockOutTime = 'clock_out_time';
  static const String kWorkHoursTime = 'work_hours_time';
  static const String kCreatedAt = 'created_at';
  static const String kLastClockInId = 'last_clock_in_id';
  static const Duration maxWorkDuration = Duration(hours: 12);

  // final AttendanceRepository _attendanceRepository = sl<AttendanceRepository>();
  final lastPosition = Rx<Position?>(null);
  final totalDistanceKm = "00".obs;
  final localAreaName = "".obs;
  // Observable variables
  final RxBool isLoading = false.obs;
  final RxBool isCheckedIn = false.obs;

  final checkInDateTime = Rx<tz.TZDateTime?>(null);
  final checkOutDateTime = Rx<tz.TZDateTime?>(null);

  final checkInTime = Rx<String?>(null);
  final checkOutTime = Rx<String?>(null);
  final workHoursTime = Rx<String?>(null);
  final distanceKm = Rx<String?>(null);

  final elapsedTime = Duration(hours: 0, minutes: 0).obs;
  final progressbarColor = Colors.blue;
  final RxString totalHoursToday = '0h 0m'.obs;
  final RxString currentStatus = 'Clock-in'.obs;
  final RxString errorMessage = ''.obs;
  final RxString statusMessage = ''.obs;
  final RxDouble shiftProgress = 0.0.obs;

  final service = FlutterBackgroundService();

  StreamSubscription<dynamic>? streamSubscription;

  GetStorage get _storage => sl<GetStorage>();

  void _debugStorageState() {
    _logger.d('=== GetStorage Debug ===');
    _logger.d('Storage Container: ${kStorageContainer}');
    _logger.d('Clock-in ID: ${_storage.read<String>(kClockInId)}');
    _logger.d('Clock-in Time: ${_storage.read<String>(kClockInTime)}');
    _logger.d('Last Clock-in ID: ${_storage.read<String>(kLastClockInId)}');
    _logger.d('Created At: ${_storage.read<String>(kCreatedAt)}');
    _logger.d('All Keys: ${_storage.getKeys()}');
    _logger.d('========================');
  }

  @override
  void onInit() {
    super.onInit();

    updateAttendance();
    service.on('update').listen((event) {
      if (event != null) {
        final runningSeconds = event['runningSeconds'];
        final formatedTimer = Duration(seconds: runningSeconds);

        elapsedTime.value = formatedTimer;
      }
    });

    service.on("PosUpdate").listen((event) {
      if (event != null &&
          event['distanceKm'] != null &&
          event['lastPosition'] != null) {
        final distanceKm = event['distanceKm'];
        lastPosition.value = Position.fromMap(event['lastPosition']);
        totalDistanceKm.value = distanceKm.toString();
      } else {
        _logger.f(event);
      }
    });
  }

  Future<bool> _checkAndRequestPermissions() async {
    try {
      // Check location permission
      var locationStatus = await Permission.location.status;
      if (!locationStatus.isGranted) {
        LoadingService.instance.hide();
        locationStatus = await Permission.location.request();
        if (!locationStatus.isGranted) {
          Fluttertoast.showToast(msg: "Location permission is required");
          return false;
        }
      }

      // Check background location permission for Android
      if (Platform.isAndroid) {
        var backgroundLocation = await Permission.locationAlways.status;
        if (!backgroundLocation.isGranted) {
          LoadingService.instance.hide();
          backgroundLocation = await Permission.locationAlways.request();
          if (!backgroundLocation.isGranted) {
            LoadingService.instance.hide();
            Fluttertoast.showToast(
              msg: "Background location permission is required",
            );
            return false;
          }
        }
      }

      // Check notification permission
      var notificationStatus = await Permission.notification.status;
      if (!notificationStatus.isGranted) {
        LoadingService.instance.hide();
        notificationStatus = await Permission.notification.request();
        if (!notificationStatus.isGranted) {
          LoadingService.instance.hide();
          Fluttertoast.showToast(msg: "Notification permission is required");
          return false;
        }
      }

      // Request ignore battery optimization
      if (Platform.isAndroid) {
        final ignoreBatteryStatus =
            await Permission.ignoreBatteryOptimizations.status;
        if (!ignoreBatteryStatus.isGranted) {
          // First try the permission request
          final result = await Permission.ignoreBatteryOptimizations.request();
          if (!result.isGranted) {
            LoadingService.instance.hide();
            // Show dialog to explain and redirect to settings
            final dialogResult = await Get.dialog<bool>(
              AlertDialog(
                title: Text('Battery Optimization Required'),
                content: Text(
                  'For reliable background tracking, you must disable battery optimization for GrowNext App. Please open settings and disable battery optimization to continue.',
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      Get.back(result: false);
                    },
                    child: Text('Cancel'),
                  ),
                  TextButton(
                    onPressed: () async {
                      final intent = AndroidIntent(
                        action:
                            'android.settings.IGNORE_BATTERY_OPTIMIZATION_SETTINGS',
                        data: 'package:com.grownext.dev',
                        flags: <int>[Flag.FLAG_ACTIVITY_NEW_TASK],
                      );
                      await intent.launch();
                      Get.back(result: true);
                    },
                    child: Text('Open Settings'),
                  ),
                ],
              ),
              barrierDismissible: false,
            );

            // If user opened settings, check the permission again
            if (dialogResult == true) {
              // Wait a bit to let them change the setting
              await Future.delayed(Duration(seconds: 2));
              final finalCheck =
                  await Permission.ignoreBatteryOptimizations.status;
              if (!finalCheck.isGranted) {
                LoadingService.instance.hide();
                Fluttertoast.showToast(
                  msg: "Battery optimization must be disabled to clock in",
                  toastLength: Toast.LENGTH_LONG,
                );
                return false;
              }
            } else {
              // User cancelled
              LoadingService.instance.hide();
              Fluttertoast.showToast(
                msg: "Battery optimization must be disabled to clock in",
                toastLength: Toast.LENGTH_LONG,
              );
              return false;
            }
          }
        }
      }

      return true;
    } catch (e) {
      _logger.e('Error checking permissions: $e');
      Fluttertoast.showToast(msg: "Error checking permissions");
      return false;
    }
  }

  void checkIn() async {
    LoadingService.instance.show();
    try {
      // Check all required permissions first
      final permissionsGranted = await _checkAndRequestPermissions();
      if (!permissionsGranted) {
        LoadingService.instance.hide();
        return;
      }

      final savedClockInId = _storage.read<String>(kClockInId);
      _logger.d('Current stored clockInId: $savedClockInId');

      // Prevent double clock-in
      if (isCheckedIn.value || savedClockInId != null) {
        Fluttertoast.showToast(msg: "You're already checked in!");
        return;
      }

      errorMessage.value = '';
      statusMessage.value = '';
      _logger.d('Checking in...');

      final position = await determinePosition();
      final now = sl<TimezoneService>().now();
      final createdAt = now;
      final newAttendance = AttendanceModel(
        startTime: now,
        startLat: position.latitude,
        startLng: position.longitude,
        clientCreatedAt: createdAt,
      );

      final response = await sl<IAttendanceRepository>().clockIn([
        newAttendance,
      ]);

      // Save the clock-in ID and time
      if (response.results?.isNotEmpty == true) {
        final result = response.results![0];

        // Check if the operation was skipped
        if (result.status == 'skipped') {
          _logger.w(
            'Clock-in was skipped by server - possibly already clocked in',
          );
          Fluttertoast.showToast(
            msg: "Already clocked in or clock-in skipped",
            toastLength: Toast.LENGTH_LONG,
          );
          return; // Don't update UI state if skipped
        }

        if (result.id != null) {
          final clockInId = result.id!;
          await _storage.write(kClockInId, clockInId);
          await _storage.write(kClockInTime, now.toIso8601String());
          await _storage.write(kCreatedAt, createdAt.toIso8601String());

          // Verify write was successful
          final verifyId = _storage.read<String>(kClockInId);
          final verifyTime = _storage.read<String>(kClockInTime);
          checkInTime.value = now.toAmPmString();
          _logger.d('Saved clockInId: $clockInId, Verified: $verifyId');
          _logger.d(
            'Saved clockInTime: ${now.toIso8601String()}, Verified: $verifyTime',
          );
          _logger.d('All keys after save: ${_storage.getKeys()}');

          if (verifyId == null) {
            throw Exception("Failed to save clock-in ID to storage");
          }
        } else {
          throw Exception("No clock-in ID received from server");
        }
      } else {
        throw Exception("No results received from server");
      }

      checkInDateTime.value = now;
      isCheckedIn.value = true;
      currentStatus.value = 'Clock-out';
      // Don't clear checkInTime - it was already set above
      checkOutTime.value = null;
      workHoursTime.value = null;
      elapsedTime.value = Duration.zero;
      _storage.remove("running_timer");

      Fluttertoast.showToast(msg: "Clocked-in successfully.");

      // Start background location tracking
      await startBackgroundTracking();
    } catch (e, stack) {
      _logger.f(e);
      _logger.f(stack);
      Fluttertoast.showToast(msg: e.toString());
    } finally {
      LoadingService.instance.hide();
    }
  }

  void checkOut() async {
    LoadingService.instance.show();
    try {
      if (!isCheckedIn.value || checkInDateTime.value == null) {
        Fluttertoast.showToast(msg: "You are not clocked-in");
        return;
      }

      final clockInId = _storage.read<String>(kClockInId);
      if (clockInId == null) {
        Fluttertoast.showToast(msg: "No active clock-in session found");
        return;
      }

      _logger.d('Clocking out...');
      final position = await determinePosition();
      final now = sl<TimezoneService>().now();
      final duration = now.difference(checkInDateTime.value!);

      // Read created_at as String and parse it, or use current time
      final createdAtStr = _storage.read<String>(kCreatedAt);
      final createdAt = createdAtStr != null
          ? sl<TimezoneService>().safeParse(createdAtStr)
          : sl<TimezoneService>().now();

      final attendance = AttendanceModel(
        id: clockInId,
        endTime: now,
        endLat: position.latitude,
        endLng: position.longitude,
        duration: duration.inSeconds.toDouble(),
        clientCreatedAt: createdAt,
      );

      final response = await sl<IAttendanceRepository>().clockOut(attendance);

      // Check if the operation was skipped
      if (response.results?.isNotEmpty == true) {
        final result = response.results![0];
        if (result.status == 'skipped') {
          _logger.w(
            'Clock-out was skipped by server - possibly already clocked out',
          );
          Fluttertoast.showToast(
            msg: "Already clocked out or clock-out skipped",
            toastLength: Toast.LENGTH_LONG,
          );
          // Still clear local state even if skipped
        }
      }

      // Clear active session
      _logger.w('REMOVING clock-in data after successful checkout');
      _logger.d('Keys before removal: ${_storage.getKeys()}');
      await _storage.remove(kClockInId); // Remove active clock-in ID
      await _storage.remove(kCreatedAt); // Remove Created at
      _logger.d('Keys after removal: ${_storage.getKeys()}');

      // Save as last session
      await _storage.write(kLastClockInId, clockInId);

      // Update local state
      checkOutDateTime.value = now;
      checkOutTime.value = now.toAmPmString();
      await _storage.write(kClockOutTime, now.toAmPmString());
      await _storage.write(kWorkHoursTime, _formatDuration(duration));

      isCheckedIn.value = false;
      currentStatus.value = 'Clock-in';

      Fluttertoast.showToast(
        msg: "Clocked-out successfully.\nWorked: ${_formatDuration(duration)}.",
      );
      calculateWorkingHours();
      stopBackgroundTracking();
    } catch (e, stack) {
      _logger.f(e);
      _logger.f(stack);
      Fluttertoast.showToast(msg: e.toString());
    } finally {
      LoadingService.instance.hide();
    }
  }

  /// Helper to format duration nicely
  String _formatDuration(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    return "${hours}h ${minutes}m";
  }

  void calculateWorkingHours() {
    if (checkInDateTime.value == null || checkOutDateTime.value == null) {
      print("Check-in or check-out time is missing");
      return;
    }

    final duration = checkOutDateTime.value!.difference(checkInDateTime.value!);
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    workHoursTime.value = _formatDuration(duration);
    _storage.write(kWorkHoursTime, _formatDuration(duration));
    print("Working hours: $hours hours $minutes minutes");
  }

  Future<void> getAreaName(Position? position) async {
    if (position == null) {
      return;
    }
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        // You can use: place.name, place.locality, place.subLocality, place.country
        localAreaName.value = "${place.locality}";
      }
    } catch (error) {
      _logger.e(error);
      localAreaName.value = "unknown";
    }
  }

  Future<bool?> updateAttendance() async {
    _logger.d('Updating attendance state...');
    try {
      final isServiceRunning = await service.isRunning();
      if (!isServiceRunning) {
        _logger.d('Background service is not running');
        cleanUp();
      }

      // Check if we have an active clock-in ID
      final savedClockInId = _storage.read<String>(kClockInId);
      final savedClockInTime = _storage.read<String>(kClockInTime);
      final savedTotalDistanceKm = _storage.read<double>(kTotalDistanceKm);

      // If we have saved state, validate and restore it
      if (savedClockInId != null && savedClockInTime != null) {
        final clockInTime = sl<TimezoneService>().safeParse(savedClockInTime);
        final duration = sl<TimezoneService>().now().difference(clockInTime);

        _logger.d(
          'Found saved clock-in state: $savedClockInId at $clockInTime',
        );

        // Valid clock-in exists - restore complete state
        isCheckedIn.value = true;
        currentStatus.value = 'Clock-out';
        checkInDateTime.value = clockInTime;
        elapsedTime.value = duration;
        checkInTime.value = clockInTime.toAmPmString();
        totalDistanceKm.value = (savedTotalDistanceKm ?? 0.0).toStringAsFixed(
          2,
        );

        _logger.d('Attendance state restored successfully.');
        return true;
      } else {
        if (isServiceRunning) {
          stopBackgroundTracking();
        }
      }

      isCheckedIn.value = false;
      currentStatus.value = 'Clock-in';
      statusMessage.value = '';
      checkInDateTime.value = null;
      elapsedTime.value = Duration.zero;

      _logger.d('No active clock-in found');
      return false;
    } catch (e, stackTrace) {
      _logger.e('Error updating attendance state: $e\n$stackTrace');
      return null;
    }
  }

  Future<void> startBackgroundTracking() async {
    bool isRunning = await service.isRunning();
    _logger.f("startBackgroundTracking $isRunning");

    if (!isRunning) {
      await service.startService();
      _logger.d("Background service started");
    }
  }

  void stopBackgroundTracking() async {
    service.invoke('stopService');
  }

  Future<Position> determinePosition() async {
    bool serviceEnabled;
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw ('Location services are disabled.');
    }
    final position = await Geolocator.getCurrentPosition();
    lastPosition.value = position;
    _logger.f(position);
    getAreaName(position);
    return position;
  }

  List<String> formatDuration(Duration d) {
    final h = d.inHours.toString().padLeft(2, '0');
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return [h, m, s];
  }

  void cleanUp() {
    _storage.remove(kClockInId);
    _storage.remove(kClockInTime);
    _storage.remove(kCreatedAt);
    isCheckedIn.value = false;
    currentStatus.value = 'Clock-in';
  }
}
