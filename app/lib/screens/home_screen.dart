import 'package:flutter/material.dart';
import '../services/api_service.dart';

class HomeScreen extends StatelessWidget {
  final String username;

  const HomeScreen({super.key, required this.username});

  Future<void> logout(BuildContext context) async {
    await ApiService.logout();

    if (!context.mounted) return;

    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('WORLD MESSENGER'),
        actions: [
          IconButton(
            onPressed: () => logout(context),
            icon: const Icon(Icons.logout),
            tooltip: 'Выйти',
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.public,
                size: 90,
                color: Color(0xFF00E5D4),
              ),
              const SizedBox(height: 24),
              const Text(
                'Добро пожаловать!',
                style: TextStyle(fontSize: 25, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Text(
                username,
                style: const TextStyle(
                  fontSize: 20,
                  color: Color(0xFF00E5D4),
                ),
              ),
              const SizedBox(height: 30),
              const Text(
                'Ваш аккаунт WORLD MESSENGER активен.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
