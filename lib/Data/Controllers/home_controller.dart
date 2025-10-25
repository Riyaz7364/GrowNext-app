import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:get/get.dart';
import 'package:grownext/Data/Controllers/attendance_controller.dart';
import 'package:grownext/Data/theme/colors.dart';
import 'package:permission_handler/permission_handler.dart';

class HomeController extends GetxController {
  final attendanceController = Get.find<AttendanceController>();

  final progress = 0.0.obs;
  InAppWebViewController? _webviewController;

  PullToRefreshController? pullToRefreshController;

  @override
  void onInit() {
    super.onInit();

    // Initialize pull to refresh controller immediately (synchronously)
    pullToRefreshController = PullToRefreshController(
      onRefresh: refreshWebView,
      settings: PullToRefreshSettings(color: primaryColor),
    );

    // Run async operations separately
    _initAsync();
  }

  Future<void> _initAsync() async {
    await requestPermissions();
    await attendanceController.determinePosition();
  }

  Future<void> requestPermissions() async {
    if (await Permission.notification.isDenied) {
      await Permission.notification.request();
    }
    if (await Permission.location.isDenied) {
      await Permission.location.request();
    }
    if (await Permission.locationAlways.isDenied) {
      await Permission.locationAlways.request();
    }
    if (await Permission.ignoreBatteryOptimizations.isDenied) {
      await Permission.ignoreBatteryOptimizations.request();
    }
  }

  Future<void> goto(String path) async {
    _webviewController!.loadUrl(urlRequest: URLRequest(url: WebUri(path)));
  }

  Future<void> runJavascript(String script) async {
    _webviewController!.evaluateJavascript(source: script);
  }

  Future<void> backHandler(bool didPop, Object? result) async {
    if (_webviewController != null) {
      final canGoBack = await _webviewController!.canGoBack();
      if (canGoBack) {
        _webviewController!.goBack();
      } else {
        Get.back();
      }
    } else {
      Get.back();
    }
  }

  // When WebView is created
  void onWebViewCreated(InAppWebViewController controller) {
    _webviewController = controller;
  }

  // Refresh WebView safely
  void refreshWebView() async {
    await _webviewController?.reload();
    pullToRefreshController?.endRefreshing();
  }
}
