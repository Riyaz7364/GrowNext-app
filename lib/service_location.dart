import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';
import 'package:get_x_storage/get_x_storage.dart';
import 'package:grownext/Data/api.dart';
import 'package:grownext/Data/models/user_model.dart';
import 'package:grownext/Data/repositories/attendance_repo.dart';
import 'package:grownext/Data/repositories/auth_repo.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';

final sl = GetIt.instance;
final box = GetXStorage();

Future<void> loadSL() async {
  sl.registerFactory<GetXStorage>(() => box);
  sl.registerLazySingleton<IAttendanceRepository>(
    () => AttendanceRepositoryImpl(),
  );
  sl.registerLazySingleton<IAuthRepository>(() => AuthRepositoryImpl());

  sl.registerCachedFactory<UserModel>(() {
    final userData = box.read(key: 'user');
    if (userData == null) return UserModel.empty();

    // If saved as JSON string
    if (userData is String) {
      return UserModel.fromJson(jsonDecode(userData));
    }

    // If already saved as Map
    return UserModel.fromJson(Map<String, dynamic>.from(userData));
  });

  // Serup Dio -> base url and bearer token
  sl.registerFactory<Dio>(() {
    final sessionTOken = box.read(key: "token") ?? "";
    return Dio(
        BaseOptions(
          validateStatus: (status) => true,
          baseUrl: Api.baseUrl,
          headers: {
            'Cache-Control': 'no-cache',
            'Pragma': 'no-cache',
            'Content-Type': 'application/json',
            'Cookie': 'grownext_auth=$sessionTOken',
          },
        ),
      )
      ..interceptors.add(
        PrettyDioLogger(
          requestHeader: true,
          requestBody: true,
          responseBody: true,
          responseHeader: false,
          error: true,
          compact: true,
          maxWidth: 90,
          enabled: kDebugMode,
          filter: (options, args) {
            // don't print requests with uris containing '/posts'
            if (options.path.contains('/posts')) {
              return false;
            }
            // don't print responses with unit8 list data
            return !args.isResponse || !args.hasUint8ListData;
          },
        ),
      );
  });
}
