import 'package:get/state_manager.dart';
import 'package:grownext/Data/Controllers/home_controller.dart';
import 'package:grownext/widgets/buttom_navbar.dart';

import '/Screens/error.dart';
import '../Data/consts/app_string.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'dart:developer' as dev;

class MainScreen extends GetView<HomeController> {
  const MainScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,

      extendBody: true,

      bottomNavigationBar: BottomWebViewControls(
        onHome: () {},
        onTasks: () {
          print("object");
          controller.goto(tasksPage);
        },
        checkInOut: () {},
        onCalendar: () {
          controller.goto(calendarPage);
        },
        onMenu: () {},
      ),

      body: SafeArea(
        child: PopScope(
          canPop: false,
          onPopInvokedWithResult: controller.backHandler,
          child: Stack(
            children: [
              InAppWebView(
                initialUrlRequest: URLRequest(url: WebUri(website)),
                initialSettings: InAppWebViewSettings(
                  useShouldOverrideUrlLoading: true,
                  mediaPlaybackRequiresUserGesture: true,
                  javaScriptEnabled: true,
                  thirdPartyCookiesEnabled: true,
                ),
                onWebViewCreated: controller.onWebViewCreated,
                onPermissionRequest: (controller, permissionRequest) =>
                    Future.value(
                      PermissionResponse(
                        action: PermissionResponseAction.GRANT,
                        resources: permissionRequest.resources,
                      ),
                    ),

                pullToRefreshController: PullToRefreshController(
                  onRefresh: controller.refreshWebView,
                ),
                shouldOverrideUrlLoading: (controller, navigationAction) async {
                  return NavigationActionPolicy.ALLOW;
                },
                onProgressChanged: (webViewController, progress) {
                  if (progress < 100) {
                    controller.progress.value = (progress / 100).toDouble();
                  } else {
                    controller.progress.value = 0.0;
                  }
                },
                onReceivedError: (webViewController, request, error) {
                  if (error.description.contains(
                    'net::ERR_CONNECTION_TIMED_OUT',
                  )) {
                    controller.refreshWebView();
                    return;
                  }
                  dev.log(error.toString());
                  if (error.description.contains(
                        'net::ERR_INTERNET_DISCONNECTED',
                      ) ||
                      error.description.contains(
                        'net::ERR_ADDRESS_UNREACHABLE',
                      )) {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => ErrorPage(errorDetails: error),
                      ),
                    );
                  }
                },
              ),
              Obx(() {
                return controller.progress > 0
                    ? Stack(
                        children: [
                          Center(child: CircularProgressIndicator()),
                          LinearProgressIndicator(
                            value: controller.progress.value,
                            color: Colors.red,
                          ),
                        ],
                      )
                    : SizedBox.shrink();
              }),
            ],
          ),
        ),
      ),
    );
  }
}
