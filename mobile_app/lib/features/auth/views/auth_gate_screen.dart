import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../admin/views/admin_screen.dart';
import '../../dashboard/views/dashboard_screen.dart';
import '../providers/auth_provider.dart';
import 'login_screen.dart';
import 'profile_setup_screen.dart';

class AuthGateScreen extends ConsumerStatefulWidget {
  const AuthGateScreen({super.key});

  @override
  ConsumerState<AuthGateScreen> createState() => _AuthGateScreenState();
}

class _AuthGateScreenState extends ConsumerState<AuthGateScreen> {
  @override
  void initState() {
    super.initState();
    unawaited(
      Future.microtask(() => ref.read(authProvider.notifier).bootstrap()).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          // If bootstrap times out, just proceed - user will see login screen
          debugPrint('Bootstrap timed out, showing login screen');
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    // Show loading screen only for a short time while bootstrapping
    if (authState.isLoading && authState.user == null && authState.token == null) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Loading...'),
            ],
          ),
        ),
      );
    }

    // If not authenticated, show login screen
    if (!authState.isAuthenticated) {
      return const LoginScreen();
    }

    // If authenticated but no user data yet, show loading
    if (authState.user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // If profile not completed, show profile setup
    if (!authState.user!.profileCompleted) {
      return const ProfileSetupScreen();
    }

    final role = authState.user!.role.trim().toLowerCase();
    if (role == 'admin') {
      return const AdminScreen();
    }

    // Otherwise, show dashboard
    return const DashboardScreen();
  }
}
