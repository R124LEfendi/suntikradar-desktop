import 'dart:io';

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/widgets/page_scaffold.dart';

final profileProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final data = await ref.watch(apiClientProvider).get('/profile');
  return Map<String, dynamic>.from(data as Map);
});

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider);

    return PageScaffold(
      title: 'Profil Admin',
      actions: OutlinedButton(
        onPressed: () => ref.invalidate(profileProvider),
        child: const Text('Refresh'),
      ),
      child: profile.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text(ApiClient.mapError(error).message)),
        data: (data) => _ProfileForm(initial: data),
      ),
    );
  }
}

class _ProfileForm extends ConsumerStatefulWidget {
  const _ProfileForm({required this.initial});

  final Map<String, dynamic> initial;

  @override
  ConsumerState<_ProfileForm> createState() => _ProfileFormState();
}

class _ProfileFormState extends ConsumerState<_ProfileForm> {
  late final TextEditingController _name;
  late final TextEditingController _email;
  late final TextEditingController _phone;
  late final TextEditingController _oldPassword;
  late final TextEditingController _password;
  String? _photoPath;
  bool _obscureOldPassword = true;
  bool _obscurePassword = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.initial['name']?.toString() ?? '');
    _email = TextEditingController(text: widget.initial['email']?.toString() ?? '');
    _phone = TextEditingController(text: widget.initial['phone']?.toString() ?? '');
    _oldPassword = TextEditingController();
    _password = TextEditingController();
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _oldPassword.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
    );
    if (result != null && result.files.isNotEmpty) {
      setState(() => _photoPath = result.files.first.path);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: SizedBox(
          width: 520,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: GestureDetector(
                  onTap: _pickPhoto,
                  child: Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      CircleAvatar(
                        radius: 50,
                        backgroundColor: const Color(0xFFE0E7FF),
                        backgroundImage: _photoPath != null
                            ? FileImage(File(_photoPath!))
                            : (widget.initial['photo'] != null
                                ? NetworkImage(widget.initial['photo']!)
                                : null) as ImageProvider?,
                        child: _photoPath == null && widget.initial['photo'] == null
                            ? const Icon(Icons.person, size: 50, color: Color(0xFF4F46E5))
                            : null,
                      ),
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(
                          color: Color(0xFF4F46E5),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.camera_alt, size: 18, color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              TextField(controller: _name, decoration: const InputDecoration(labelText: 'Nama')),
              const SizedBox(height: 12),
              TextField(controller: _email, decoration: const InputDecoration(labelText: 'Email')),
              const SizedBox(height: 12),
              TextField(controller: _phone, decoration: const InputDecoration(labelText: 'Telepon')),
              const SizedBox(height: 12),
              TextField(
                controller: _oldPassword,
                decoration: InputDecoration(
                  labelText: 'Password lama',
                  suffixIcon: IconButton(
                    icon: Icon(_obscureOldPassword ? Icons.visibility_off_rounded : Icons.visibility_rounded),
                    onPressed: () => setState(() => _obscureOldPassword = !_obscureOldPassword),
                  ),
                ),
                obscureText: _obscureOldPassword,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _password,
                decoration: InputDecoration(
                  labelText: 'Password baru',
                  suffixIcon: IconButton(
                    icon: Icon(_obscurePassword ? Icons.visibility_off_rounded : Icons.visibility_rounded),
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
                obscureText: _obscurePassword,
              ),
              const SizedBox(height: 18),
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton(
                  onPressed: _saving ? null : _save,
                  child: Text(_saving ? 'Menyimpan...' : 'Simpan Profil'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final payload = {
        'name': _name.text.trim(),
        'email': _email.text.trim(),
        'phone': _phone.text.trim(),
        if (_oldPassword.text.isNotEmpty) 'old_password': _oldPassword.text,
        if (_password.text.isNotEmpty) 'password': _password.text,
      };

      dynamic dataToSend;
      if (_photoPath != null) {
        final formData = FormData.fromMap(payload);
        formData.files.add(MapEntry(
          'photo',
          await MultipartFile.fromFile(_photoPath!),
        ));
        dataToSend = formData;
      } else {
        dataToSend = payload;
      }

      await ref.read(apiClientProvider).post('/profile/update', data: dataToSend);
      ref.invalidate(profileProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profil berhasil disimpan')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ApiClient.mapError(error).message)));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
