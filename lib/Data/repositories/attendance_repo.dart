import 'package:dio/dio.dart';
import 'package:get_x_storage/get_x_storage.dart';
import 'package:grownext/Data/api.dart';
import 'package:grownext/Data/models/attendance_model.dart';
import 'package:grownext/Data/models/user_model.dart';
import 'package:grownext/service_location.dart';
import 'package:logger/logger.dart';

abstract class IAttendanceRepository {
  Future<bool> clockIn(List<AttendanceModel> attendances);
}

class AttendanceRepositoryImpl implements IAttendanceRepository {
  final _logger = Logger();
  @override
  Future<bool> clockIn(List<AttendanceModel> attendances) async {
    final response = await sl<Dio>().post(
      Api.workLogsSync,
      data: {
        "logs": List.generate(attendances.length, (index) {
          _logger.f(attendances[index].toJson());
          return attendances[index].toJson();
        }),
      },
    );
    final data = response.data;
    if (response.statusCode == 200 && data['success'] == true) {
      final user = UserModel.fromJson(data['data']);
      sl<GetXStorage>().write(key: 'user', value: user.toJson());
    }
    return false;

    throw data['message'];
  }
}
