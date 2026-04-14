import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_windowmanager/flutter_windowmanager.dart';

class AntiCheatService extends WidgetsBindingObserver {
  final VoidCallback onCheatDetected;

  AntiCheatService({required this.onCheatDetected});

  Future<void> startMonitoring() async {
    WidgetsBinding.instance.addObserver(this);
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    await FlutterWindowManager.addFlags(FlutterWindowManager.FLAG_SECURE);
  }

  Future<void> stopMonitoring() async {
    WidgetsBinding.instance.removeObserver(this);
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    await FlutterWindowManager.clearFlags(FlutterWindowManager.FLAG_SECURE);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      // The user has minimized the app or switched to another app!
      onCheatDetected();
    }
  }
}
