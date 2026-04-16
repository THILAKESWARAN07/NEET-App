import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../../core/api/api_client.dart';
import '../../../core/storage/app_storage.dart';

const String _webGoogleClientId =
  String.fromEnvironment(
    'GOOGLE_WEB_CLIENT_ID',
    defaultValue: '66902840466-r6o7qpk98tuem8j1ljnmqi9rg2i854vs.apps.googleusercontent.com',
  );

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref.read(dioProvider), ref.read(appStorageProvider));
});

class UserProfile {
  final int id;
  final String email;
  final String fullName;
  final String role;
  final bool profileCompleted;
  final int? targetExamYear;
  final String? preferredLanguage;

  UserProfile({
    required this.id,
    required this.email,
    required this.fullName,
    required this.role,
    required this.profileCompleted,
    this.targetExamYear,
    this.preferredLanguage,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as int,
      email: json['email'] as String,
      fullName: (json['full_name'] as String?) ?? 'Student',
      role: (json['role'] as String?) ?? 'user',
      profileCompleted: (json['profile_completed'] as bool?) ?? false,
      targetExamYear: json['target_exam_year'] as int?,
      preferredLanguage: json['preferred_language'] as String?,
    );
  }
}

class AuthState {
  final bool isLoading;
  final String? error;
  final String? token;
  final UserProfile? user;

  const AuthState({this.isLoading = false, this.error, this.token, this.user});

  AuthState copyWith({bool? isLoading, String? error, String? token, UserProfile? user}) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
      token: token ?? this.token,
      user: user ?? this.user,
    );
  }

  bool get isAuthenticated => token != null && token!.isNotEmpty;
}

class AuthNotifier extends StateNotifier<AuthState> {
  final Dio dio;
  final AppStorage storage;
  final GoogleSignIn _googleSignIn =
      kIsWeb
          ? GoogleSignIn(
            scopes: ['email'],
            clientId: _webGoogleClientId.isNotEmpty ? _webGoogleClientId : null,
          )
          : GoogleSignIn(scopes: ['email']);

  AuthNotifier(this.dio, this.storage) : super(const AuthState());

  Future<void> bootstrap() async {
    final token = await storage.readToken();
    if (token == null || token.isEmpty) return;
    state = state.copyWith(token: token);
    await fetchCurrentUser();
  }

  Future<void> fetchCurrentUser() async {
    try {
      final response = await dio.get('/auth/me');
      state = state.copyWith(user: UserProfile.fromJson(response.data), error: null);
    } catch (e) {
      await signOut();
    }
  }

  Future<void> signInWithGoogle() async {
    try {
      state = state.copyWith(isLoading: true, error: null);

      if (kIsWeb && _webGoogleClientId.isEmpty) {
        state = state.copyWith(
          isLoading: false,
          error:
              'Google Sign-In is not configured for web. Set GOOGLE_WEB_CLIENT_ID and restart the app.',
        );
        return;
      }

      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        state = state.copyWith(isLoading: false);
        return; // User canceled sign-in
      }

      // We simulate sending the google auth details to our FastAPI backend
      final authData = {
        "email": googleUser.email,
        "google_id": googleUser.id,
        "full_name": googleUser.displayName ?? "Student",
      };

      final response = await dio.post('/auth/google', data: authData);

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        final token = (data['access_token'] as String?)?.trim();
        if (token == null || token.isEmpty) {
          state = state.copyWith(
            isLoading: false,
            error: 'Authentication token missing in server response',
          );
          return;
        }
        final user = UserProfile.fromJson(response.data['user'] as Map<String, dynamic>);
        if (kDebugMode) {
          debugPrint('[Auth] Received access token. Saving to secure storage.');
        }
        await storage.saveToken(token);
        if (kDebugMode) {
          final persisted = await storage.readToken();
          debugPrint(
            '[Auth] Token saved. persistedTokenPresent=${persisted != null && persisted.isNotEmpty}',
          );
        }
        state = state.copyWith(isLoading: false, token: token, user: user);
      } else {
        state = state.copyWith(isLoading: false, error: 'Server authentication failed');
      }

    } catch (e) {
      final rawError = e.toString();
      final normalizedError =
          rawError.toLowerCase().contains('clientid not set')
              ? 'Google Sign-In is not configured for web. Set GOOGLE_WEB_CLIENT_ID and restart the app.'
              : rawError;
      state = state.copyWith(isLoading: false, error: normalizedError);
    }
  }

  Future<void> completeProfile({
    required String fullName,
    required String dob,
    int? targetExamYear,
    String? preferredLanguage,
  }) async {
    try {
      state = state.copyWith(isLoading: true, error: null);
      final response = await dio.post('/auth/profile/complete', data: {
        'full_name': fullName,
        'dob': dob,
        'target_exam_year': targetExamYear,
        'preferred_language': preferredLanguage,
      });
      state = state.copyWith(
        isLoading: false,
        user: UserProfile.fromJson(response.data),
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> signOut() async {
    try {
      await dio.post('/auth/logout');
    } catch (_) {
      // Ignore backend logout failures and continue with local sign-out.
    }
    await _googleSignIn.signOut();
    await storage.clearToken();
    state = const AuthState();
  }
}
