import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static const String baseUrl = 'http://127.0.0.1:8000';

  static Future<Map<String, dynamic>> register(
    String username,
    String password,
  ) async {
    final response = await http.post(
      Uri.parse('$baseUrl/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'username': username,
        'password': password,
      }),
    );

    return _decode(response);
  }

  static Future<Map<String, dynamic>> login(
    String username,
    String password,
  ) async {
    final response = await http.post(
      Uri.parse('$baseUrl/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'username': username,
        'password': password,
      }),
    );

    final data = _decode(response);
    final token = data['token'];

    if (token is! String || token.isEmpty) {
      throw Exception('Сервер не вернул токен');
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);

    return data;
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
    final data = jsonDecode(response.body);

    if (data is! Map<String, dynamic>) {
      throw Exception('Некорректный ответ сервера');
    }

    if (response.statusCode >= 400) {
      throw Exception(
        data['error'] ?? data['message'] ?? 'Ошибка запроса',
      );
    }

    return data;
  }
}
