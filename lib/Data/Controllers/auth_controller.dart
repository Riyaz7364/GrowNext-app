import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:get/get.dart';
import 'package:get_x_storage/get_x_storage.dart';
import 'package:grownext/Data/consts/app_string.dart';
import 'package:grownext/Data/repositories/auth_repo.dart';
import 'package:grownext/Data/routes.dart';
import 'package:grownext/service_location.dart';
import 'package:logger/logger.dart';
import 'package:uuid/uuid.dart';

class AuthController extends GetxService {
  InAppWebViewController? _loginWebviewController;
  final _cookieManager = CookieManager();
  final progress = 0.0.obs;
  final cookies = "".obs;
  final isLoggedIn = false.obs;
  final userEmail = ''.obs;
  final _logger = Logger();
  final uuid = "".obs;
  final _storage = sl<GetXStorage>();

  @override
  void onInit() {
    super.onInit();
    checkCookieActive();
    InAppWebViewController.setWebContentsDebuggingEnabled(true);
    uuid.value = Uuid().v4();
  }

  // Handle back navigation inside WebView
  Future<void> loginBackHandler(bool didPop, Object? result) async {
    if (_loginWebviewController != null) {
      final canGoBack = await _loginWebviewController!.canGoBack();
      if (canGoBack) {
        _loginWebviewController!.goBack();
      } else {
        Get.back();
      }
    } else {
      Get.back();
    }
  }

  Future<void> checkCookieActive() async {
    final cookies = await _cookieManager.getCookies(url: WebUri(website));
    final token = cookies.whereType<Cookie?>().firstWhere(
      (cookie) => cookie?.name == "grownext_auth",
      orElse: () => null,
    );

    if (token != null && isLoggedIn.value == false) {
      _storage.write(key: "token", value: token.value);
      isLoggedIn.value = true;
      checkAuthStatus();
    }
  }

  // JavaScript handler to receive login token
  Future<void> injectLoginHandler() async {
    _loginWebviewController?.addJavaScriptHandler(
      handlerName: "loginWithToken",
      callback: (arguments) {
        if (arguments.isEmpty) return;

        final token = arguments.first;
        _logger.i("Received token: $token");

        if (token != null &&
            token.toString().isNotEmpty &&
            isLoggedIn.value == false) {
          _storage.write(key: "token", value: token);
          isLoggedIn.value = true;
          checkAuthStatus();
        }
      },
    );
  }

  // When WebView is created
  void onWebViewCreated(InAppWebViewController controller) {
    _loginWebviewController = controller;

    injectLoginHandler();
  }

  // Refresh WebView safely
  void refreshWebView() {
    _loginWebviewController?.reload();
  }

  // Logout
  void logout() {
    _storage.remove(key: "token");
    isLoggedIn.value = false;
    userEmail.value = '';
    _logger.w("User logged out");
  }

  // Check saved login state
  void checkAuthStatus() async {
    try {
      await sl<IAuthRepository>().getUser();
      Get.offAndToNamed(homePage);
    } catch (error) {
      Fluttertoast.showToast(msg: error.toString());
      // CookieManager().deleteAllCookies().then((value) {
      //   _loginWebviewController!.goBack();
      // });
    }
  }

  Map<String, dynamic> get userInfo => {
    'email': userEmail.value,
    'isLoggedIn': isLoggedIn.value,
    'token': _storage.read(key: "token"),
  };
}
