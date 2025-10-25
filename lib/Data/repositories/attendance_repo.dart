import 'package:dio/dio.dart';
import 'package:grownext/Data/api.dart';
import 'package:grownext/Data/models/attendance_model.dart';
import 'package:grownext/Data/services/timezone_service.dart';
import 'package:grownext/service_location.dart';
import 'package:logger/logger.dart';
import 'package:timezone/timezone.dart' as tz;

abstract class IAttendanceRepository {
  Future<ClockInResponse> clockIn(List<AttendanceModel> attendances);
  Future<ClockInResponse> clockOut(AttendanceModel attendance);
}

class AttendanceRepositoryImpl implements IAttendanceRepository {
  final _logger = Logger();

  @override
  Future<ClockInResponse> clockIn(List<AttendanceModel> attendances) async {
    try {
      final response = await sl<Dio>().post(
        Api.workLogsSync,
        data: {"logs": attendances.map((e) => e.toJson()).toList()},
      );
      _logger.d('Clock-in response: ${response.data}');

      final clockInResponse = ClockInResponse.fromJson(response.data);

      // Check if the operation was skipped
      if (clockInResponse.results != null &&
          clockInResponse.results!.isNotEmpty) {
        final firstResult = clockInResponse.results!.first;
        if (firstResult.status == 'skipped') {
          _logger.w('Clock-in was skipped by server: ${response.data}');
          // Still return success=true if server says success=true, but log the skip
        }
      }

      return clockInResponse;
    } catch (e, st) {
      _logger.e('Clock-in error: $e\n$st');
      return ClockInResponse(success: false);
    }
  }

  @override
  Future<ClockInResponse> clockOut(AttendanceModel attendance) async {
    try {
      final response = await sl<Dio>().post(
        Api.workLogsSync,
        data: {
          "logs": [attendance.toJson()],
        },
      );
      _logger.d('Clock-out response: ${response.data}');

      final clockOutResponse = ClockInResponse.fromJson(response.data);

      // Check if the operation was skipped
      if (clockOutResponse.results != null &&
          clockOutResponse.results!.isNotEmpty) {
        final firstResult = clockOutResponse.results!.first;
        if (firstResult.status == 'skipped') {
          _logger.w('Clock-out was skipped by server: ${response.data}');
        }
      }

      return clockOutResponse;
    } catch (e, st) {
      _logger.e('Clock-out error: $e\n$st');
      return ClockInResponse(success: false);
    }
  }
}

class ClockInResponse {
  final bool success;
  final List<ClockInResult>? results;

  ClockInResponse({required this.success, this.results});

  factory ClockInResponse.fromJson(Map<String, dynamic> json) {
    return ClockInResponse(
      success: json['success'] ?? false,
      results: json['results'] != null
          ? (json['results'] as List)
                .map((e) => ClockInResult.fromJson(e))
                .toList()
          : null,
    );
  }
}

class ClockInResult {
  final String? id;
  final tz.TZDateTime? startTime;
  final String? status;

  ClockInResult({this.id, this.startTime, this.status});

  factory ClockInResult.fromJson(Map<String, dynamic> json) {
    return ClockInResult(
      id: json['id'],
      startTime:
          json['startTime'] != null && json['startTime'].toString().isNotEmpty
          ? sl<TimezoneService>().safeParse(json['startTime'].toString())
          : null,
      status: json['status'],
    );
  }
}
