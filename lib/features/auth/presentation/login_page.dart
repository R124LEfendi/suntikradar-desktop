import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_controller.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _loginController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _loginController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final controller = ref.read(authControllerProvider.notifier);
    final isCompact = MediaQuery.of(context).size.width < 900;

    return Scaffold(
      body: Container(
        color: const Color(0xFFF5F6FF),
        child: Row(
          children: [
            if (!isCompact)
              Expanded(
                flex: 5,
                child: Container(
                  margin: const EdgeInsets.all(18),
                  padding: const EdgeInsets.all(34),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF4F46E5), Color(0xFF312E81)],
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Image.asset('assets/lahaula.png',
                          height: 58, fit: BoxFit.contain),
                      const Spacer(),
                      const Text(
                        'Admin Console',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 34,
                            fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Kelola data kendaraan, pencarian unit, paket, dan riwayat operasional dalam satu aplikasi desktop.',
                        style: TextStyle(
                            color: Color(0xFFE0E7FF),
                            fontSize: 15,
                            height: 1.5),
                      ),
                      const SizedBox(height: 28),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: const [
                          _LoginPill('Admin Console'),
                          _LoginPill('Fast Search'),
                          _LoginPill('Master Data'),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            Expanded(
              flex: 4,
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 430),
                    padding: const EdgeInsets.all(30),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: const [
                        BoxShadow(
                            color: Color(0x1A111827),
                            blurRadius: 30,
                            offset: Offset(0, 18))
                      ],
                      border: Border.all(color: const Color(0xFFE5EAF0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (isCompact) ...[
                          Image.asset('assets/lahaula.png',
                              height: 58, fit: BoxFit.contain),
                          const SizedBox(height: 20),
                        ],
                        const Text('Masuk Admin',
                            style: TextStyle(
                                fontSize: 28, fontWeight: FontWeight.w900)),
                        const SizedBox(height: 6),
                        const Text('Gunakan akun admin/operator internal.',
                            style: TextStyle(color: Color(0xFF64748B))),
                        const SizedBox(height: 24),
                        TextField(
                          controller: _loginController,
                          decoration: const InputDecoration(
                              prefixIcon: Icon(Icons.person_outline),
                              labelText: 'Email atau nomor telepon'),
                          onSubmitted: (_) => _submit(),
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          controller: _passwordController,
                          decoration: const InputDecoration(
                              prefixIcon: Icon(Icons.lock_outline),
                              labelText: 'Password'),
                          obscureText: true,
                          onSubmitted: (_) => _submit(),
                        ),
                        if (controller.errorText() != null) ...[
                          const SizedBox(height: 12),
                          Text(controller.errorText()!,
                              style: TextStyle(
                                  color: Theme.of(context).colorScheme.error)),
                        ],
                        const SizedBox(height: 22),
                        FilledButton(
                          onPressed: auth.isLoading ? null : _submit,
                          child: auth.isLoading
                              ? const SizedBox.square(
                                  dimension: 18,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2))
                              : const Text('Masuk ke Dashboard'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _submit() {
    ref.read(authControllerProvider.notifier).login(
          _loginController.text.trim(),
          _passwordController.text,
        );
  }
}

class _LoginPill extends StatelessWidget {
  const _LoginPill(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.24)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
        child: Text(label,
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 12)),
      ),
    );
  }
}
