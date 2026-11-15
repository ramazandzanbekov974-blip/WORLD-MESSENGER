
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static const String baseUrl = 'http://127.0.0.1:8000';

  static Future<Map<String, dynamic>> _request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    String? token,
  }) async {
    final uri = Uri.parse('$baseUrl$path');

    try {
      late http.Response response;

      if (method == 'GET') {
        response = await http.get(
          uri,
          headers: token == null
              ? null
              : {'Authorization': 'Bearer $token'},
        ).timeout(const Duration(seconds: 20));
      } else {
        response = await http.post(
          uri,
          headers: {
            'Content-Type': 'application/json',
            if (token != null) 'Authorization': 'Bearer $token',
          },
          body: jsonEncode(body ?? {}),
        ).timeout(const Duration(seconds: 20));
      }

      debugPrint('WM: $method $path -> ${response.statusCode}');

      final dynamic decoded;
      try {
        decoded = jsonDecode(utf8.decode(response.bodyBytes));
      } catch (_) {
        throw Exception('Сервер вернул некорректный ответ');
      }

      if (decoded is! Map<String, dynamic>) {
        throw Exception('Некорректный ответ сервера');
      }

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception(
          decoded['error']?.toString() ??
          decoded['message']?.toString() ??
          'Ошибка сервера: ${response.statusCode}',
        );
      }

      return decoded;
    } on TimeoutException {
      throw Exception('Сервер не ответил за 20 секунд');
    } on http.ClientException catch (e) {
      debugPrint('WM HTTP ERROR: $e');
      throw Exception('Не удалось связаться с сервером');
    } on FormatException {
      throw Exception('Ошибка формата ответа сервера');
    }
  }

  static Future<void> checkHealth() async {
    await _request('GET', '/health');
  }

  static Future<Map<String, dynamic>> register(
    String username,
    String password,
  ) async {
    return _request(
      'POST',
      '/register',
      body: {
        'username': username,
        'password': password,
      },
    );
  }

  static Future<Map<String, dynamic>> login(
    String username,
    String password,
  ) async {
    debugPrint('WM: LOGIN START');

    final data = await _request(
      'POST',
      '/login',
      body: {
        'username': username,
        'password': password,
      },
    );

    final token = data['token'];

    if (token is! String || token.isEmpty) {
      throw Exception('Сервер не вернул токен');
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);

    debugPrint('WM: TOKEN SAVED');
    return data;
  }

  static Future<Map<String, dynamic>> getProfile() async {
    final token = await getToken();

    if (token == null || token.isEmpty) {
      throw Exception('Необходимо войти в аккаунт');
    }

    final data = await _request('GET', '/me', token: token);
    final user = data['user'];

    if (user is! Map<String, dynamic>) {
      throw Exception('Некорректный профиль');
    }

    return user;
  }

  static Future<Map<String, dynamic>> updateProfile({
    required String username,
    required String displayName,
    required String phone,
    required String bio,
  }) async {
    final token = await getToken();

    if (token == null || token.isEmpty) {
      throw Exception('Необходимо войти в аккаунт');
    }

    final data = await _request(
      'POST',
      '/profile',
      token: token,
      body: {
        'username': username,
        'display_name': displayName,
        'phone': phone,
        'bio': bio,
      },
    );

    final user = data['user'];

    if (user is! Map<String, dynamic>) {
      throw Exception('Сервер не вернул обновлённый профиль');
    }

    return user;
  }

  static Future<List<Map<String, dynamic>>> getChats() async {
    final token = await getToken();

    if (token == null || token.isEmpty) {
      throw Exception('Необходимо войти в аккаунт');
    }

    final data = await _request(
      'GET',
      '/chats',
      token: token,
    );

    final chats = data['chats'];

    if (chats is! List) {
      throw Exception('Некорректный список чатов');
    }

    return chats.whereType<Map<String, dynamic>>().toList();
  }

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
  }
}
