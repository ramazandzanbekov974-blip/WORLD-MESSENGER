import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final usernameController = TextEditingController();
  final passwordController = TextEditingController();

  bool hidePassword = true;
  bool loading = false;
  String diagnostic = 'Ожидание входа';

  @override
  void dispose() {
    usernameController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> login() async {
    final username = usernameController.text.trim();
    final password = passwordController.text;

    if (username.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Заполни все поля')),
      );
      return;
    }

    setState(() {
      loading = true;
      diagnostic = 'Этап 1: отправка запроса на сервер';
    });

    try {
      setState(() => diagnostic = 'TCP: подключаемся к серверу...');
      final result = await ApiService.debugTcpLogin(username, password);
      if (!mounted) return;
      setState(() => diagnostic = result);
    } catch (e) {
      if (!mounted) return;
      setState(() => diagnostic = 'ОШИБКА: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('Вход'),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Column(
            children: [
              const Icon(Icons.public, size: 75, color: Color(0xFF00E5D4)),
              const SizedBox(height: 25),
              const Text(
                'С возвращением!',
                style: TextStyle(fontSize: 27, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 35),
              TextField(
                controller: usernameController,
                decoration: const InputDecoration(
                  labelText: 'Имя пользователя',
                  prefixIcon: Icon(Icons.person_outline),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 18),
              TextField(
                controller: passwordController,
                obscureText: hidePassword,
                decoration: InputDecoration(
                  labelText: 'Пароль',
                  prefixIcon: const Icon(Icons.lock_outline),
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    onPressed: () {
                      setState(() => hidePassword = !hidePassword);
                    },
                    icon: Icon(
                      hidePassword ? Icons.visibility : Icons.visibility_off,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: FilledButton(
                  onPressed: loading ? null : login,
                  child: loading
                      ? const CircularProgressIndicator()
                      : const Text('Войти'),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                diagnostic,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFF00E5D4)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
