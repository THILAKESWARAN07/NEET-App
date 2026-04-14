import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/views/splash_screen.dart';

void main() {
  runApp(
    const ProviderScope(
      child: NeetApp(),
    ),
  );
}

class NeetApp extends ConsumerWidget {
  const NeetApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'NEET Prep Pro',
      themeMode: ThemeMode.system, // Supports automatic dark/light mode
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      home: const SplashScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
