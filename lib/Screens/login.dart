import 'package:get/state_manager.dart';
import 'package:grownext/Data/Controllers/auth_controller.dart';
import 'package:logger/logger.dart';

import '/Screens/error.dart';
import '../Data/consts/app_string.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'dart:developer' as dev;

class LoginScreen extends GetView<AuthController> {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: PopScope(
          canPop: false,
          onPopInvokedWithResult: controller.loginBackHandler,
          child: Stack(
            children: [
              InAppWebView(
                initialUrlRequest: URLRequest(url: WebUri(website)),
                initialSettings: InAppWebViewSettings(
                  javaScriptEnabled: true,
                  useShouldOverrideUrlLoading: true,
                  clearCache: false,
                  // incognito: true,
                  thirdPartyCookiesEnabled: true,
                  useOnDownloadStart: true,
                ),
                shouldOverrideUrlLoading: (controller, navigationAction) async {
                  return NavigationActionPolicy.ALLOW;
                },
                onUpdateVisitedHistory:
                    (webController, url, androidIsReload) async {
                      await controller.checkCookieActive();
                    },
                onWebViewCreated: controller.onWebViewCreated,
                onLoadStart: (webController, url) {
                  controller.checkCookieActive();
                },
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
                    Logger().f(error);
                    controller.refreshWebView();
                    return;
                  }

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
