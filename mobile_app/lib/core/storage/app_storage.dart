import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AppStorage {
  static const _tokenKey = 'auth_token';
  static const _attemptIdKey = 'active_attempt_id';
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  Future<void> saveToken(String token) async {
    await _secureStorage.write(key: _tokenKey, value: token);
  }

  Future<String?> readToken() async {
    return _secureStorage.read(key: _tokenKey);
  }

  Future<void> clearToken() async {
    await _secureStorage.delete(key: _tokenKey);
  }

  Future<void> saveAttemptId(int attemptId) async {
    await _secureStorage.write(key: _attemptIdKey, value: attemptId.toString());
  }

  Future<int?> readAttemptId() async {
    final raw = await _secureStorage.read(key: _attemptIdKey);
    if (raw == null) return null;
    return int.tryParse(raw);
  }

  Future<void> clearAttemptId() async {
    await _secureStorage.delete(key: _attemptIdKey);
  }
}

final appStorageProvider = Provider<AppStorage>((ref) => AppStorage());
