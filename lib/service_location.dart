import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';
import 'package:get_storage/get_storage.dart';
import 'package:grownext/Data/api.dart';
import 'package:grownext/Data/models/user_model.dart';
import 'package:grownext/Data/repositories/attendance_repo.dart';
import 'package:grownext/Data/repositories/auth_repo.dart';
import 'package:grownext/Data/services/timezone_service.dart';
import 'package:grownext/firebase_options.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';

final sl = GetIt.instance;
const String kStorageContainer = 'grownext_storage';

Future<void> loadSL() async {
  await GetStorage.init(kStorageContainer);
  final box = GetStorage(kStorageContainer);

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;

  sl.registerLazySingleton<TimezoneService>(() => TimezoneService());

  sl.registerLazySingleton<GetStorage>(() => box);
  sl.registerLazySingleton<IAttendanceRepository>(
    () => AttendanceRepositoryImpl(),
  );
  sl.registerLazySingleton<IAuthRepository>(() => AuthRepositoryImpl());

  sl.registerCachedFactory<UserModel>(() {
    final userData = box.read('user');
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
    final sessionTOken = box.read("token") ?? "";
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
