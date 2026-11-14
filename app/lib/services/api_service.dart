import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static const String baseUrl = 'http://127.0.0.1:8000';

  static Future<Map<String, dynamic>> register(
    String username,
    String password,
  ) async {
    debugPrint('WM: REGISTER START');

    final response = await http.post(
      Uri.parse('$baseUrl/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'username': username,
        'password': password,
      }),
    ).timeout(const Duration(seconds: 30));

    debugPrint('WM: REGISTER RESPONSE ${response.statusCode}');
    return _decode(response);
  }

  static Future<Map<String, dynamic>> login(
    String username,
    String password,
  ) async {
    debugPrint('WM: LOGIN START');

    final response = await http.post(
      Uri.parse('$baseUrl/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'username': username,
        'password': password,
      }),
    ).timeout(const Duration(seconds: 30));

    debugPrint('WM: LOGIN RESPONSE ${response.statusCode}');

    final data = _decode(response);
    final token = data['token'];

    if (token is! String || token.isEmpty) {
      throw Exception('Сервер не вернул токен');
    }

    debugPrint('WM: TOKEN RECEIVED');
    final prefs = await SharedPreferences.getInstance();
    debugPrint('WM: PREFERENCES READY');

    await prefs.setString('auth_token', token);
    debugPrint('WM: TOKEN SAVED');

    return data;
  }

  static Future<List<Map<String, dynamic>>> getChats() async {
    debugPrint('WM: GET CHATS START');

    final token = await getToken();

    if (token == null || token.isEmpty) {
      throw Exception('Необходимо войти в аккаунт');
    }

    debugPrint('WM: TOKEN FOUND');

    final response = await http.get(
      Uri.parse('$baseUrl/chats'),
      headers: {'Authorization': 'Bearer $token'},
    ).timeout(const Duration(seconds: 30));

    debugPrint('WM: CHATS RESPONSE ${response.statusCode}');

    final data = _decode(response);
    final chats = data['chats'];

    if (chats is! List) {
      throw Exception('Некорректный список чатов');
    }

    debugPrint('WM: CHATS LOADED: ${chats.length}');
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

  static Map<String, dynamic> _decode(http.Response response) {
    final dynamic decoded;

    try {
      decoded = jsonDecode(response.body);
    } catch (_) {
      throw Exception('Сервер вернул некорректный ответ');
    }

    if (decoded is! Map<String, dynamic>) {
      throw Exception('Некорректный ответ сервера');
    }

    if (response.statusCode >= 400) {
      throw Exception(
        decoded['error'] ?? decoded['message'] ?? 'Ошибка запроса',
      );
    }

    return decoded;
  }
}
