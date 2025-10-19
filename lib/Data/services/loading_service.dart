import 'package:flutter/material.dart';
import 'package:get/get.dart';

class LoadingService {
  LoadingService._privateConstructor();
  static final LoadingService _instance = LoadingService._privateConstructor();
  static LoadingService get instance => _instance;

  OverlayEntry? _overlayEntry;
  bool _isShowing = false;

  void show() {
    if (_isShowing) return;

    _overlayEntry = OverlayEntry(builder: (_) => const _FullScreenLoader());

    final overlayContext = Get.overlayContext;
    if (overlayContext == null) {
      debugPrint("❌ No overlay context available yet");
      return;
    }

    Overlay.of(overlayContext).insert(_overlayEntry!);

    _isShowing = true;
  }

  void hide() {
    if (!_isShowing) return;

    _overlayEntry?.remove();
    _overlayEntry = null;
    _isShowing = false;
  }
}

class _FullScreenLoader extends StatelessWidget {
  const _FullScreenLoader();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ModalBarrier(color: Colors.black.withOpacity(0.5), dismissible: false),
        const Center(child: CircularProgressIndicator()),
      ],
    );
  }
}
