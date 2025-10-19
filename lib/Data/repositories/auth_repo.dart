import 'package:dio/dio.dart';
import 'package:get_x_storage/get_x_storage.dart';
import 'package:grownext/Data/api.dart';
import 'package:grownext/Data/models/user_model.dart';
import 'package:grownext/service_location.dart';

abstract class IAuthRepository {
  Future<UserModel> getUser();
}

class AuthRepositoryImpl implements IAuthRepository {
  @override
  Future<UserModel> getUser() async {
    final response = await sl<Dio>().get(Api.getUser);
    final data = response.data;
    if (data['success'] == true) {
      final user = UserModel.fromJson(data['data']);
      sl<GetXStorage>().write(key: 'user', value: user.toJson());
      return user;
    }

    throw data['message'];
  }
}
