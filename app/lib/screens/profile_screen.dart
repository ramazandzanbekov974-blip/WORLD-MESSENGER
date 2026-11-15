import 'package:flutter/material.dart';
import '../services/api_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final usernameController = TextEditingController();
  final nameController = TextEditingController();
  final phoneController = TextEditingController();
  final bioController = TextEditingController();

  bool loading = true;
  bool saving = false;
  String? error;

  @override
  void initState() {
    super.initState();
    loadProfile();
  }

  Future<void> loadProfile() async {
    try {
      final user = await ApiService.getProfile();
      if (!mounted) return;

      usernameController.text = user['username']?.toString() ?? '';
      nameController.text = user['display_name']?.toString() ?? '';
      phoneController.text = user['phone']?.toString() ?? '';
      bioController.text = user['bio']?.toString() ?? '';

      setState(() {
        loading = false;
        error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        loading = false;
        error = e.toString();
      });
    }
  }

  Future<void> saveProfile() async {
    setState(() {
      saving = true;
      error = null;
    });

    try {
      await ApiService.updateProfile(
        username: usernameController.text.trim(),
        displayName: nameController.text.trim(),
        phone: phoneController.text.trim(),
        bio: bioController.text.trim(),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Профиль сохранён')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  void dispose() {
    usernameController.dispose();
    nameController.dispose();
    phoneController.dispose();
    bioController.dispose();
    super.dispose();
  }

  Widget field(String label, TextEditingController controller,
      {String? hint, int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFF00E5D4);

    return Scaffold(
      appBar: AppBar(title: const Text('Мой профиль')),
      body: loading
          ? const Center(child: CircularProgressIndicator(color: accent))
          : error != null && usernameController.text.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(error!, textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: () {
                            setState(() {
                              loading = true;
                              error = null;
                            });
                            loadProfile();
                          },
                          child: const Text('Повторить'),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    const Center(
                      child: CircleAvatar(
                        radius: 46,
                        backgroundColor: Color(0xFF163B3A),
                        child: Icon(Icons.person, size: 48, color: accent),
                      ),
                    ),
                    const SizedBox(height: 28),
                    field('Имя', nameController, hint: 'Как вас зовут'),
                    field('@username', usernameController,
                        hint: 'Например: ramazan_17'),
                    field('Телефон', phoneController,
                        hint: 'Номер телефона'),
                    field('О себе', bioController,
                        hint: 'Расскажите немного о себе', maxLines: 3),
                    if (error != null) ...[
                      Text(
                        error!,
                        style: const TextStyle(color: Colors.redAccent),
                      ),
                      const SizedBox(height: 12),
                    ],
                    FilledButton(
                      onPressed: saving ? null : saveProfile,
                      style: FilledButton.styleFrom(
                        backgroundColor: accent,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                      ),
                      child: saving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.black,
                              ),
                            )
                          : const Text('Сохранить изменения'),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Номер телефона пока не подтверждён по SMS.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                  ],
                ),
    );
  }
}
