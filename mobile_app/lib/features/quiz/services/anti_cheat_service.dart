import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AntiCheatService extends WidgetsBindingObserver {
  final VoidCallback onCheatDetected;

  AntiCheatService({required this.onCheatDetected});

  Future<void> startMonitoring() async {
    WidgetsBinding.instance.addObserver(this);
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  Future<void> stopMonitoring() async {
    WidgetsBinding.instance.removeObserver(this);
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      // The user has minimized the app or switched to another app!
      onCheatDetected();
    }
  }
}
