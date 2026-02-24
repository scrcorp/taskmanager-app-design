import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../utils/token_storage.dart';

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService();
});

/// Pure mock auth service — no server communication
class AuthService {
  bool _isLoggedIn = false;

  bool get isLoggedIn => _isLoggedIn;

  Future<void> login(String username, String password) async {
    await Future.delayed(const Duration(milliseconds: 300));
    _isLoggedIn = true;
  }

  Future<void> register({
    required String username,
    required String password,
    required String fullName,
    String? email,
  }) async {
    await Future.delayed(const Duration(milliseconds: 300));
    _isLoggedIn = true;
  }

  Future<Map<String, dynamic>> getMe() async {
    await Future.delayed(const Duration(milliseconds: 100));
    return {
      'id': 'mock-user-001',
      'organization_id': 'mock-org-001',
      'role_id': 'mock-role-001',
      'username': 'demo_user',
      'email': 'demo@example.com',
      'first_name': 'Demo',
      'last_name': 'User',
      'is_active': true,
      'role_name': 'Staff',
      'role_level': 4,
      'created_at': '2026-01-01T00:00:00Z',
    };
  }

  Future<void> logout() async {
    _isLoggedIn = false;
    await TokenStorage.clearTokens();
  }
}
