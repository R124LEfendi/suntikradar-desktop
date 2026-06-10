import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/storage/token_storage.dart';
import 'auth_models.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
      ref.watch(apiClientProvider), ref.watch(tokenStorageProvider));
});

class AuthRepository {
  AuthRepository(this._api, this._storage);

  final ApiClient _api;
  final TokenStorage _storage;

  Future<AuthSession> login(String login, String password) async {
    await _storage.clear();

    final response = await _api.dio.post('/auth/login', data: {
      'login': login,
      'email': login,
      'password': password,
      'device_type': 'desktop',
      'device_name': Platform.localHostname,
    });

    final map = _normalizeLoginResponse(response.data);
    final token = _extractToken(map);
    if (token.isEmpty) {
      throw Exception('Token login tidak ditemukan di respons server.');
    }
    final user = _extractUser(map);
    if (!user.canUseDesktop) {
      throw Exception(
          'Aplikasi desktop hanya untuk admin/operator. Role akun ini: ${user.role}.');
    }

    await _storage.saveToken(token);
    return AuthSession(user: user, token: token);
  }

  Future<AuthUser?> me() async {
    final token = await _storage.readToken();
    if (token == null || token.isEmpty) return null;

    final data = await _api.get('/auth/me');
    final user = _extractUser(Map<String, dynamic>.from(data as Map));
    if (!user.canUseDesktop) {
      await _storage.clear();
      return null;
    }
    return user;
  }

  Future<void> logout() async {
    try {
      await _api.post('/auth/logout');
    } finally {
      await _storage.clear();
    }
  }

  Map<String, dynamic> _normalizeLoginResponse(dynamic body) {
    if (body is! Map) {
      throw Exception('Format respons login tidak dikenali.');
    }

    final map = Map<String, dynamic>.from(body);
    if (map['success'] == false) {
      throw Exception(map['message']?.toString() ?? 'Login gagal.');
    }

    final data = map['data'];
    if (data is Map) {
      return {
        ...Map<String, dynamic>.from(data),
        for (final entry in map.entries)
          if (entry.key != 'data') entry.key: entry.value,
      };
    }

    return map;
  }

  String _extractToken(Map<String, dynamic> map) {
    final candidates = [
      map['token'],
      map['access_token'],
      map['plain_text_token'],
      map['plainTextToken'],
      map['bearer_token'],
      if (map['auth'] is Map) (map['auth'] as Map)['token'],
      if (map['auth'] is Map) (map['auth'] as Map)['access_token'],
    ];

    for (final candidate in candidates) {
      final value = candidate?.toString().trim();
      if (value != null && value.isNotEmpty) {
        return value.replaceFirst(
            RegExp(r'^Bearer\s+', caseSensitive: false), '');
      }
    }
    return '';
  }

  AuthUser _extractUser(Map<String, dynamic> map) {
    final rawUser = map['user'] is Map ? map['user'] : map;
    return AuthUser.fromJson(Map<String, dynamic>.from(rawUser as Map));
  }
}
