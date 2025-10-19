import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:get_x_storage/get_x_storage.dart';
import 'package:grownext/Data/Controllers/auth_controller.dart';
import 'package:grownext/Data/extenstions/duration_to_ago.dart';
import 'package:grownext/Data/models/attendance_model.dart';
import 'package:grownext/Data/models/user_model.dart';
import 'package:grownext/Data/repositories/attendance_repo.dart';
import 'package:grownext/Data/services/loading_service.dart';
import 'package:grownext/service_location.dart';

import 'package:logger/logger.dart';
import 'package:permission_handler/permission_handler.dart';

class AttendanceController extends GetxController {
  final _logger = Logger();

  // final AttendanceRepository _attendanceRepository = sl<AttendanceRepository>();
  final lastPosition = Rx<Position?>(null);
  final totalDistanceKm = "".obs;
  final localAreaName = "".obs;
  // Observable variables
  final RxBool isLoading = false.obs;
  final RxBool isCheckedIn = false.obs;

  final checkInDateTime = Rx<DateTime?>(null);
  final checkOutDateTime = Rx<DateTime?>(null);

  final checkInTime = Rx<String?>(null);
  final checkOutTime = Rx<String?>(null);
  final workHoursTime = Rx<String?>(null);

  final elapsedTime = Duration(hours: 0, minutes: 0).obs;
  final RxString todayCheckOut = ''.obs;
  final progressbarColor = Colors.blue;
  final RxString totalHoursToday = '0h 0m'.obs;
  final RxString currentStatus = 'Clock-in'.obs;
  final RxString errorMessage = ''.obs;
  final RxString statusMessage = ''.obs;
  final RxDouble shiftProgress = 0.0.obs;

  final RxInt currentWeekHours = 32.obs;
  final RxInt currentMonthHours = 128.obs;
  final RxDouble attendancePercentage = 95.5.obs;
  final service = FlutterBackgroundService();

  StreamSubscription<dynamic>? streamSubscription;

  @override
  void onInit() {
    // TODO: implement onInit
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
      if (event != null) {
        final distanceKm = event['distanceKm'];
        final lastPos = Position.fromMap(event['lastPosition']);
        _logger.f(lastPos);
        totalDistanceKm.value = distanceKm.toString();
      }
    });
  }

  void checkIn() async {
    LoadingService.instance.show();
    try {
      errorMessage.value = '';
      statusMessage.value = '';

      _logger.d('Checking in...');
      final user = sl<UserModel>();
      // Get current position
      final position = await determinePosition();

      // Create attendance record
      final newAttendance = AttendanceModel(
        id: user.id,
        startTime: DateTime.now(),
        startLat: position.latitude,
        startLng: position.longitude,
        clientCreatedAt: DateTime.timestamp(),
      );

      final response = await sl<IAttendanceRepository>().clockIn([
        newAttendance,
      ]);
      return;
      // Check if already checked in
      final isAlreadyCheckedIn = await updateAttendance();
      if (isAlreadyCheckedIn == true) {
        Fluttertoast.showToast(msg: "You're already checked in!");
        return;
      }

      checkInDateTime.value = newAttendance.startTime;
      isCheckedIn.value = true;
      currentStatus.value = 'Clock-out';

      // Persist locally
      sl<GetXStorage>().write(
        key: "check_in",
        value: checkInDateTime.value!.toAmPmString(),
      );

      Fluttertoast.showToast(msg: "You clock-in successfully");

      // Start background location tracking
      startBackgroundTracking();
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
        Fluttertoast.showToast(msg: "You are not clocked-in yet");
        return;
      }

      _logger.d('Clocking out...');

      final position = await determinePosition();

      checkOutDateTime.value = DateTime.now();

      // Create attendance record
      final attendance = AttendanceModel(
        endTime: checkOutDateTime.value,
        endLat: position.latitude,
        endLng: position.longitude,
      );

      // Optionally save to API
      // await sl<IAttendanceRepository>().clockIn(attendance);

      // Persist locally

      final workingDuration = checkOutDateTime.value!.difference(
        checkInDateTime.value!,
      );

      sl<GetXStorage>().write(
        key: "check_out",
        value: checkOutDateTime.value!.toAmPmString(),
      );
      sl<GetXStorage>().write(
        key: "work_hours",
        value: workingDuration.inHours,
      );

      isCheckedIn.value = false;
      currentStatus.value = 'Clocked-out';

      Fluttertoast.showToast(
        msg:
            "Clocked-out successfully.\nWorked: ${_formatDuration(workingDuration)}",
      );

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
    bool isRunning = await service.isRunning();

    sl<GetXStorage>().listenKey(
      key: "check_in",
      callback: (checkIn) => checkInTime.value = checkIn,
    );
    sl<GetXStorage>().listenKey(
      key: "check_out",
      callback: (checkOut) => checkOutTime.value = checkOut,
    );
    sl<GetXStorage>().listenKey(
      key: "work_hours",
      callback: (workHours) => workHoursTime.value = workHours,
    );

    if (checkInDateTime.value != null) {
      final isSameDay =
          checkInDateTime.value!.difference(DateTime.now()).inDays < 1;
      if (isSameDay) {
        isCheckedIn.value = false;
        currentStatus.value = 'Already Check-out';
        statusMessage.value = 'You already check-in/out today';
        return false;
      }
    }

    if (isRunning) {
      isCheckedIn.value = true;
      currentStatus.value = 'Punch out';
      statusMessage.value = 'Check-in successful';
      return true;
    }

    return null;
  }

  void startBackgroundTracking() async {
    bool isRunning = await service.isRunning();
    _logger.f("startBackgroundTracking $isRunning");

    if (!isRunning) {
      await service.startService();
    } else {}
  }

  void stopBackgroundTracking() async {
    final service = FlutterBackgroundService();
    service.invoke('stopService');
  }

  // void runStreamDuration() {
  //   elapsedTime.value = Duration.zero;
  //   if (streamSubscription != null) streamSubscription!.cancel();
  //   final now = DateTime.now();
  //   final differenceInSeconds = now.difference(checkInTime.value);
  //   elapsedTime.value = differenceInSeconds;
  //   // Start a periodic timer to update the elapsed time
  //   streamSubscription = Stream.periodic(Duration(seconds: 1)).listen((_) {
  //     if (isCheckedIn.value) {
  //       elapsedTime.value += Duration(seconds: 1);
  //     }
  //   });
  // }

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
}
//   void workingProgress(List<Duration> shift) {
//     final now = DateTime.now();
//     final baseTime = Duration(hours: now.hour, minutes: now.minute);

//     final start = shift[0];
//     final end = shift[1];

//     // Calculate how much time has passed since shift started
//     final timePassed = baseTime - start;

//     // Clamp: if before start, it's 0
//     if (timePassed.isNegative) {
//       _logger.d("Working progress: 0 hours (shift not started yet)");
//       return;
//     }

//     // Clamp: if after end, cap at total shift duration
//     final totalShift = end - start;
//     final effectivePassed = timePassed > totalShift ? totalShift : timePassed;
//     final progress =
//         (timePassed.inMilliseconds / totalShift.inMilliseconds).clamp(0, 1)
//             as double;
//     shiftProgress.value = progress;
//     _logger.d(
//       "Working progress: ${effectivePassed.inHours}h "
//       "${effectivePassed.inMinutes.remainder(60)}m "
//       "out of ${totalShift.inHours}h "
//       "Difference ${totalShift.compareTo(effectivePassed)}h "
//       "Progress: ${progress * 100}%",
//     );
//   }

//   // Attendance history
//   final RxList<Map<String, dynamic>> attendanceHistory = <Map<String, dynamic>>[
//     {
//       'date': '2025-08-13',
//       'checkIn': '09:00',
//       'checkOut': '18:00',
//       'totalHours': '8h 0m',
//       'status': 'present',
//     },
//     {
//       'date': '2025-08-12',
//       'checkIn': '09:15',
//       'checkOut': '18:00',
//       'totalHours': '7h 45m',
//       'status': 'present',
//     },
//     {
//       'date': '2025-08-11',
//       'checkIn': '10:30',
//       'checkOut': '18:30',
//       'totalHours': '8h 0m',
//       'status': 'late',
//     },
//     {
//       'date': '2025-08-10',
//       'checkIn': '',
//       'checkOut': '',
//       'totalHours': '0h 0m',
//       'status': 'absent',
//     },
//     {
//       'date': '2025-08-09',
//       'checkIn': '09:00',
//       'checkOut': '17:30',
//       'totalHours': '7h 30m',
//       'status': 'present',
//     },
//   ].obs;

//   // Weekly attendance chart data
//   final RxList<Map<String, dynamic>> weeklyData = <Map<String, dynamic>>[
//     {'day': 'Mon', 'hours': 8.0},
//     {'day': 'Tue', 'hours': 7.5},
//     {'day': 'Wed', 'hours': 8.0},
//     {'day': 'Thu', 'hours': 0.0},
//     {'day': 'Fri', 'hours': 8.5},
//     {'day': 'Sat', 'hours': 0.0},
//     {'day': 'Sun', 'hours': 0.0},
//   ].obs;

//   DateTime? checkInTime;
//   DateTime? checkOutTime;

//   @override
//   void onInit() {
//     super.onInit();
//   }

//   void loadTodayAttendance(AttendanceModel? attendanceModel) async {
//     // _logger.d('Loading today attendance...${attendanceModel!.toJson()}');
//     if (attendanceModel == null) return;

//     if (attendanceModel.outTime != null &&
//         attendanceModel.outTime!.inSeconds != 0) {
//       currentStatus.value = 'Punch Out';
//       streamSubscription?.cancel();
//       final progress = sl<GetStorage>().read<double>("shift_progress");
//       final seconds = sl<GetStorage>().read<int>("elapsed_time");
//       elapsedTime.value = Duration(seconds: seconds ?? 0);
//       shiftProgress.value = progress ?? 0.0;
//       isCheckedIn.value = false;
//       currentStatus.value = "You already punched out";
//       progressbarColor.value = Colors.red;

//       return;
//     }

//     isCheckedIn.value = true;

//     if (attendanceModel.inTime != null) {
//       currentStatus.value = "Punch Out";

//       final inTimeStr = attendanceModel.inTime;
//       todayCheckIn.value = inTimeStr!; // Format HH:MM

//       // Update checkInTime for calculations
//       final dateStr = attendanceModel.attendanceDate!.toHumanReadable();
//       // throw inTimeStr;
//       checkInTime = DateTime.parse('$dateStr $inTimeStr');
//     } else {
//       checkInTime = DateTime.now();
//       todayCheckIn.value = Duration.zero;
//     }

//     runStreamDuration();
//   }

//   void checkIn() async {
//     _logger.f(sl<GetStorage>().read<int>("elapsed_time"));
//     if (isCheckedIn.value) {
//       Fluttertoast.showToast(
//         msg: 'Error: You are already checked in',
//         toastLength: Toast.LENGTH_SHORT,
//         gravity: ToastGravity.BOTTOM,
//         backgroundColor: Colors.red[100],
//         textColor: Colors.red[800],
//       );
//       return;
//     }

//     try {
//       isLoading.value = true;
//       errorMessage.value = '';
//       statusMessage.value = '';

//       _logger.d('Checking in...');

//       final response = await _attendanceRepository.checkIn();
//       // _logger.d('Check-in response: $response');

//       isCheckedIn.value = true;
//       currentStatus.value = 'Punch out';
//       statusMessage.value = 'Check-in successful';

//       // Get the check-in time from the response
//       if (response.inTime != null) {
//         final inTimeStr = response.inTime;
//         todayCheckIn.value = inTimeStr!; // Format HH:MM

//         // Update checkInTime for calculations
//         final dateStr = response.attendanceDate!.toHumanReadable();
//         // throw inTimeStr;
//         checkInTime = DateTime.parse('$dateStr $inTimeStr');
//       } else {
//         checkInTime = DateTime.now();
//         todayCheckIn.value = Duration.zero;
//       }

//       // Get.snackbar(
//       //   'Success',
//       //   statusMessage.value,
//       //   snackPosition: SnackPosition.BOTTOM,
//       //   backgroundColor: Colors.green[100],
//       //   colorText: Colors.green[800],
//       // );

//       runStreamDuration();
//     } catch (e) {
//       // _logger.e('Error during check-in: $e');
//       errorMessage.value = AppUtils.extractErrorMessage(e);
//       _logger.e(errorMessage.value);

//       Fluttertoast.showToast(
//         msg: AppUtils.extractErrorMessage(e),
//         toastLength: Toast.LENGTH_SHORT,
//         gravity: ToastGravity.BOTTOM,
//         backgroundColor: Colors.red[100],
//         textColor: Colors.red[800],
//       );
//     } finally {
//       isLoading.value = false;
//     }
//   }

//   void checkOut() async {
//     if (!isCheckedIn.value) {
//       Get.snackbar('Error', 'You need to check in first');
//       return;
//     }

//     try {
//       isLoading.value = true;
//       errorMessage.value = '';
//       statusMessage.value = '';

//       _logger.d('Checking out...');

//       final response = await _attendanceRepository.checkOut();
//       _logger.d('Check-out response: $response');

//       isCheckedIn.value = false;
//       currentStatus.value = 'Punched Out';
//       statusMessage.value = 'Punched-out successful';

//       if (response.inTime != null) {
//         checkInTime = null;
//         progressbarColor.value = AppColors.error;
//         sl<GetStorage>().write("elapsed_time", elapsedTime.value.inSeconds);
//         sl<GetStorage>().write("shift_progress", shiftProgress.value);
//         streamSubscription?.cancel();
//       }
//     } catch (e) {
//       _logger.e('Error during check-out: $e');
//       errorMessage.value = e.toString();
//       Get.snackbar(
//         'Error',
//         'Failed to check out: $e',
//         snackPosition: SnackPosition.BOTTOM,
//         backgroundColor: Colors.red[100],
//         colorText: Colors.red[800],
//       );
//     } finally {
//       isLoading.value = false;
//     }
//   }

//   String _getAttendanceStatus(Duration checkInTime) {
//     // Assuming office starts at 9:00 AM
//     final hour = checkInTime.inHours;
//     final minute = checkInTime.inMinutes % 60;
//     final seconds = checkInTime.inSeconds % 60;

//     if (hour > 9 || (hour == 9 && minute > 15)) {
//       return 'late';
//     }
//     return 'present';
//   }

//   Color getStatusColor(String status) {
//     switch (status.toLowerCase()) {
//       case 'present':
//         return Colors.green;
//       case 'late':
//         return Colors.orange;
//       case 'absent':
//         return Colors.red;
//       default:
//         return Colors.grey;
//     }
//   }

//   String getStatusText(String status) {
//     switch (status.toLowerCase()) {
//       case 'present':
//         return 'Present';
//       case 'late':
//         return 'Late';
//       case 'absent':
//         return 'Absent';
//       default:
//         return 'Unknown';
//     }
//   }

//   IconData getStatusIcon(String status) {
//     switch (status.toLowerCase()) {
//       case 'present':
//         return Icons.check_circle;
//       case 'late':
//         return Icons.access_time;
//       case 'absent':
//         return Icons.cancel;
//       default:
//         return Icons.help;
//     }
//   }

//   void refreshAttendance() {
//     // Simulate refreshing attendance data
//     Get.snackbar(
//       'Refreshed',
//       'Attendance data updated',
//       snackPosition: SnackPosition.BOTTOM,
//     );
//   }

//   void viewAttendanceReport() {
//     Get.toNamed('/attendance/report');
//   }

//   void requestAttendanceCorrection() {
//     Get.toNamed('/attendance/correction');
//   }

//   @override
//   void onClose() {
//     // TODO: implement onClose
//     super.onClose();
//     streamSubscription?.cancel();
//   }
// }
