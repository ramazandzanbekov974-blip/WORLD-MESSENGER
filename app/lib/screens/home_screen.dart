import 'package:flutter/material.dart';
import '../services/api_service.dart';

class HomeScreen extends StatefulWidget {
  final String username;

  const HomeScreen({super.key, required this.username});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Map<String, dynamic>> chats = [];
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    loadChats();
  }

  Future<void> loadChats() async {
    setState(() {
      loading = true;
      error = null;
    });

    try {
      final result = await ApiService.getChats();

      if (!mounted) return;

      setState(() {
        chats = result;
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        error = e.toString();
        loading = false;
      });
    }
  }

  Future<void> logout() async {
    await ApiService.logout();

    if (!mounted) return;

    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  String chatPreview(Map<String, dynamic> chat) {
    final message = chat['last_message'];

    if (message == null || message.toString().isEmpty) {
      return 'Начните общение';
    }

    return message.toString();
  }

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFF00E5D4);

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.public, color: accent),
            SizedBox(width: 10),
            Text('WORLD MESSENGER'),
          ],
        ),
        actions: [
          IconButton(
            onPressed: loadChats,
            icon: const Icon(Icons.refresh),
            tooltip: 'Обновить',
          ),
          IconButton(
            onPressed: logout,
            icon: const Icon(Icons.logout),
            tooltip: 'Выйти',
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Сообщения',
                  style: TextStyle(
                    fontSize: 27,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Вы вошли как ${widget.username}',
                  style: const TextStyle(color: Colors.white60),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Colors.white12),
          Expanded(
            child: loading
                ? const Center(
                    child: CircularProgressIndicator(color: accent),
                  )
                : error != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.cloud_off,
                                size: 55,
                                color: Colors.white38,
                              ),
                              const SizedBox(height: 15),
                              const Text('Не удалось загрузить чаты'),
                              const SizedBox(height: 8),
                              Text(
                                error!,
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: Colors.white54),
                              ),
                              const SizedBox(height: 18),
                              FilledButton(
                                onPressed: loadChats,
                                child: const Text('Повторить'),
                              ),
                            ],
                          ),
                        ),
                      )
                    : chats.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(30),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.forum_outlined,
                                    size: 75,
                                    color: accent,
                                  ),
                                  const SizedBox(height: 18),
                                  const Text(
                                    'Пока нет переписок',
                                    style: TextStyle(
                                      fontSize: 21,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    'Когда вы создадите первый чат, он появится здесь.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(color: Colors.white54),
                                  ),
                                  const SizedBox(height: 18),
                                  OutlinedButton.icon(
                                    onPressed: loadChats,
                                    icon: const Icon(Icons.refresh),
                                    label: const Text('Обновить'),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : RefreshIndicator(
                            color: accent,
                            onRefresh: loadChats,
                            child: ListView.separated(
                              itemCount: chats.length,
                              separatorBuilder: (_, __) => const Divider(
                                height: 1,
                                indent: 84,
                                color: Colors.white10,
                              ),
                              itemBuilder: (context, index) {
                                final chat = chats[index];
                                final name =
                                    chat['username']?.toString() ?? 'Пользователь';

                                return ListTile(
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 18,
                                    vertical: 7,
                                  ),
                                  leading: CircleAvatar(
                                    radius: 26,
                                    backgroundColor: accent.withValues(
                                      alpha: 0.15,
                                    ),
                                    child: Text(
                                      name.isNotEmpty
                                          ? name[0].toUpperCase()
                                          : '?',
                                      style: const TextStyle(
                                        color: accent,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 20,
                                      ),
                                    ),
                                  ),
                                  title: Text(
                                    name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  subtitle: Text(
                                    chatPreview(chat),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white54,
                                    ),
                                  ),
                                  trailing: const Icon(
                                    Icons.chevron_right,
                                    color: Colors.white38,
                                  ),
                                );
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }
}
