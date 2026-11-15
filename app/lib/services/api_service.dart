import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static const String baseUrl = 'http://192.168.0.16:8000';

  static Future<void> checkHealth() async {
    debugPrint('WM: HEALTH START');

    final response = await http.get(
      Uri.parse('$baseUrl/health'),
    ).timeout(const Duration(seconds: 5));

    debugPrint('WM: HEALTH RESPONSE ${response.statusCode}');
    _decode(response);
  }

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
      headers: {
        'Content-Type': 'application/json',
      },
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


  static Future<String> debugTcpLogin(
    String username,
    String password,
  ) async {
    const host = '192.168.0.16';
    const port = 8000;

    Socket? socket;
    StreamSubscription? subscription;
    final result = Completer<String>();
    final buffer = <int>[];

    int findHeaderEnd(List<int> bytes) {
      for (var i = 0; i <= bytes.length - 4; i++) {
        if (bytes[i] == 13 &&
            bytes[i + 1] == 10 &&
            bytes[i + 2] == 13 &&
            bytes[i + 3] == 10) {
          return i;
        }
      }
      return -1;
    }

    try {
      final connected = await Socket.connect(
        host,
        port,
        timeout: const Duration(seconds: 5),
      );
      socket = connected;

      subscription = connected.listen(
        (chunk) {
          if (result.isCompleted) return;

          buffer.addAll(chunk);
          final headerEnd = findHeaderEnd(buffer);
          if (headerEnd < 0) return;

          final headerText = ascii.decode(
            buffer.sublist(0, headerEnd),
            allowInvalid: true,
          );

          final match = RegExp(
            r'Content-Length:\s*(\d+)',
            caseSensitive: false,
          ).firstMatch(headerText);

          if (match == null) {
            result.completeError(
              Exception('В ответе нет Content-Length'),
            );
            return;
          }

          final contentLength = int.parse(match.group(1)!);
          final bodyStart = headerEnd + 4;

          if (buffer.length < bodyStart + contentLength) return;

          final bodyBytes = buffer.sublist(
            bodyStart,
            bodyStart + contentLength,
          );

          final statusLine = headerText.split('\r\n').first;
          var jsonValid = false;
          var success = false;
          var tokenPresent = false;

          try {
            final decoded = jsonDecode(
              utf8.decode(bodyBytes, allowMalformed: true),
            );

            if (decoded is Map) {
              jsonValid = true;
              success = decoded['success'] == true;
              final token = decoded['token'];
              tokenPresent = token is String && token.isNotEmpty;
            }
          } catch (_) {
            jsonValid = false;
          }

          result.complete(
            '$statusLine\n'
            'Получено байтов: ${buffer.length}\n'
            'JSON корректен: $jsonValid\n'
            'Успешный вход: $success\n'
            'Токен присутствует: $tokenPresent',
          );
        },
        onError: (Object error) {
          if (!result.isCompleted) result.completeError(error);
        },
        onDone: () {
          if (!result.isCompleted) {
            result.completeError(
              Exception('Соединение закрылось до полного ответа'),
            );
          }
        },
      );

      final bodyBytes = utf8.encode(
        jsonEncode({
          'username': username,
          'password': password,
        }),
      );

      final headers = utf8.encode(
        'POST /login HTTP/1.1\r\n'
        'Host: $host:$port\r\n'
        'Content-Type: application/json\r\n'
        'Content-Length: ${bodyBytes.length}\r\n'
        'Connection: close\r\n'
        '\r\n',
      );

      connected.add(headers);
      connected.add(bodyBytes);
      await connected.flush().timeout(const Duration(seconds: 10));

      return await result.future.timeout(
        const Duration(seconds: 10),
      );
    } finally {
      await subscription?.cancel();
      socket?.destroy();
    }
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
