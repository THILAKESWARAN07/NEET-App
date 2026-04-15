import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neet_app/features/quiz/services/anti_cheat_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const MethodChannel channel = MethodChannel('neet_app/screen_security');
  final List<MethodCall> calls = <MethodCall>[];

  setUp(() {
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
          calls.add(call);
          return null;
        });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform,
            (MethodCall call) async {
          if (call.method == 'SystemChrome.setEnabledSystemUIMode') {
            return null;
          }
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  testWidgets('startMonitoring enables screen-capture protection',
      (WidgetTester tester) async {
    final service = AntiCheatService(onCheatDetected: () {});

    await service.startMonitoring();
    await service.stopMonitoring();

    expect(calls.length, 2);
    expect(calls[0].method, 'setScreenCaptureProtection');
    expect((calls[0].arguments as Map<Object?, Object?>)['enabled'], true);
    expect(calls[1].method, 'setScreenCaptureProtection');
    expect((calls[1].arguments as Map<Object?, Object?>)['enabled'], false);
  });

  testWidgets('paused or inactive state triggers cheat callback',
      (WidgetTester tester) async {
    var detections = 0;
    final service = AntiCheatService(onCheatDetected: () => detections++);

    service.didChangeAppLifecycleState(AppLifecycleState.resumed);
    service.didChangeAppLifecycleState(AppLifecycleState.inactive);
    service.didChangeAppLifecycleState(AppLifecycleState.paused);

    expect(detections, 2);
  });
}
