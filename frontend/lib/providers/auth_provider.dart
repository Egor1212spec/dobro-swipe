import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';
import '../core/network.dart';
import '../data/models.dart';

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier();
});

class AuthState {
  final bool isLoading;
  final User? user;
  final String? error;

  AuthState({this.isLoading = false, this.user, this.error});
}

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier() : super(AuthState(isLoading: true)) {
    _loadUser();
  }

  Future<void> _loadUser() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getString('access_token') != null) {
      try {
        final response = await apiClient.dio.get('/auth/me');
        state = AuthState(user: User.fromJson(response.data));
        return;
      } catch (e) {
        await prefs.remove('access_token');
      }
    }
    state = AuthState();
  }

  Future<void> refreshUser() async {
    try {
      final response = await apiClient.dio.get('/auth/me');
      state = AuthState(user: User.fromJson(response.data));
    } catch (_) {}
  }

  Future<bool> login(String email, String password) async {
    state = AuthState(isLoading: true);
    try {
      final response = await apiClient.dio.post(
        '/auth/login',
        data: {'username': email, 'password': password},
        options: Options(contentType: 'application/x-www-form-urlencoded'),
      );
      final token = response.data['access_token'];
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('access_token', token);

      final userResponse = await apiClient.dio.get('/auth/me');
      state = AuthState(user: User.fromJson(userResponse.data));
      return true;
    } on DioException catch (e) {
      String errorMessage = 'Ошибка входа';
      if (e.response?.data is Map && e.response?.data['detail'] != null) {
        errorMessage = e.response!.data['detail'].toString();
      }
      state = AuthState(error: errorMessage);
      return false;
    } catch (e) {
      state = AuthState(error: 'Ошибка входа');
      return false;
    }
  }

  Future<bool> register(String email, String password, String name, String role) async {
    state = AuthState(isLoading: true);
    try {
      await apiClient.dio.post('/auth/register', data: {
        'email': email,
        'password': password,
        'name': name,
        'role': role,
      });
      return await login(email, password);
    } on DioException catch (e) {
      String errorMessage = 'Ошибка регистрации';
      if (e.response?.data is Map && e.response?.data['detail'] != null) {
        final detail = e.response?.data['detail'];
        if (detail is String) {
          errorMessage = detail;
        } else if (detail is List && detail.isNotEmpty) {
          errorMessage = detail[0]['msg'] ?? 'Ошибка валидации';
        }
      }
      state = AuthState(error: errorMessage);
      return false;
    } catch (e) {
      state = AuthState(error: 'Ошибка регистрации');
      return false;
    }
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('access_token');
    state = AuthState();
  }
}
