import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AntiCheatService extends WidgetsBindingObserver {
  static const MethodChannel _screenSecurityChannel =
      MethodChannel('neet_app/screen_security');

  final VoidCallback onCheatDetected;

  AntiCheatService({required this.onCheatDetected});

  Future<void> startMonitoring() async {
    WidgetsBinding.instance.addObserver(this);
    await _setScreenCaptureProtection(enabled: true);
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  Future<void> stopMonitoring() async {
    WidgetsBinding.instance.removeObserver(this);
    await _setScreenCaptureProtection(enabled: false);
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  Future<void> _setScreenCaptureProtection({required bool enabled}) async {
    try {
      await _screenSecurityChannel.invokeMethod<void>(
        'setScreenCaptureProtection',
        {'enabled': enabled},
      );
    } on MissingPluginException {
      // Non-Android platforms may not provide this channel.
    } on PlatformException {
      // Ignore platform errors to avoid interrupting the quiz flow.
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      // The user has minimized the app or switched to another app!
      onCheatDetected();
    }
  }
}
