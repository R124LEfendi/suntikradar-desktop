import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/auth_controller.dart';
import '../config/app_config.dart';
import '../network/api_client.dart';

final globalSettingsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  try {
    final data = await ref.watch(apiClientProvider).get('/admin/website-settings');
    return Map<String, dynamic>.from(data as Map);
  } catch (_) {}
  return const <String, dynamic>{};
});

class AdminShell extends ConsumerWidget {
  const AdminShell({super.key, required this.child});

  final Widget child;

  static const _items = [
    _NavItem('Ringkasan Sistem', '/dashboard', Icons.grid_view_rounded),
    _NavItem('Pencarian Unit', '/pencarian', Icons.manage_search_rounded),
    _NavItem('Kelola Pengguna', '/resource/users', Icons.group_rounded),
    _NavItem(
        'Kelola Perusahaan', '/resource/perusahaan', Icons.apartment_rounded),
    _NavItem(
        'Kelola Leasing', '/resource/leasing', Icons.business_center_rounded),
    _NavItem('Kelola Paket', '/resource/paket', Icons.inventory_2_rounded),
    _NavItem(
        'Data Kendaraan', '/resource/kendaraan', Icons.two_wheeler_rounded),
    _NavSection('Layanan & Akses'),
    _NavItem('Riwayat Pencarian', '/resource/history', Icons.history_rounded),
    _NavItem('Transaksi & Billing', '/resource/transactions',
        Icons.receipt_long_rounded),
    _NavSection('Konfigurasi'),
    _NavItem('Pengaturan Website', '/resource/settings', Icons.tune_rounded),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final width = MediaQuery.of(context).size.width;
    final compact = width < 980;
    final drawer = _Sidebar(items: _items, compact: compact);

    return Scaffold(
      drawer: compact ? Drawer(width: 280, child: drawer) : null,
      backgroundColor: const Color(0xFFF5F6FF),
      body: Row(
        children: [
          if (!compact) drawer,
          Expanded(
            child: Column(
              children: [
                _TopBar(compact: compact),
                Expanded(child: child),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Sidebar extends ConsumerWidget {
  const _Sidebar({required this.items, required this.compact});

  final List<_NavEntry> items;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = GoRouterState.of(context).uri.path;
    final settings = ref.watch(globalSettingsProvider).valueOrNull ?? {};

    String? logoUrl;
    if (settings['logo_path'] != null && settings['logo_path'].toString().isNotEmpty) {
      final path = settings['logo_path'].toString();
      if (path.startsWith('http')) {
        logoUrl = path;
      } else {
        final apiUrl = AppConfig.apiBaseUrl;
        final baseUrl = apiUrl.endsWith('/api') ? apiUrl.substring(0, apiUrl.length - 4) : apiUrl;
        final cleanPath = path.startsWith('/') ? path : '/$path';
        logoUrl = '$baseUrl$cleanPath';
      }
    }

    return Container(
      width: compact ? double.infinity : 282,
      color: Colors.white,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                      color: const Color(0xFFE0E7FF),
                      borderRadius: BorderRadius.circular(12)),
                  child: logoUrl != null
                      ? Image.network(logoUrl, fit: BoxFit.contain, errorBuilder: (_, __, ___) => Image.asset('assets/lahaula.png', fit: BoxFit.contain))
                      : Image.asset('assets/lahaula.png', fit: BoxFit.contain),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(settings['app_name']?.toString() ?? 'Admin Console',
                          style: const TextStyle(
                              color: Color(0xFF111827),
                              fontWeight: FontWeight.w900,
                              fontSize: 16)),
                      const SizedBox(height: 2),
                      Text(settings['app_title']?.toString() ?? 'Desktop Admin',
                          style: const TextStyle(
                              color: Color(0xFF64748B), fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(14, 4, 14, 18),
              children: items.map((item) {
                if (item is _NavSection) {
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(18, 24, 18, 8),
                    child: Text(
                      item.label.toUpperCase(),
                      style: const TextStyle(
                        color: Color(0xFFB7C0D1),
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.4,
                      ),
                    ),
                  );
                }
                final nav = item as _NavItem;
                final active = location == nav.path;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: ListTile(
                    dense: true,
                    minLeadingWidth: 0,
                    minTileHeight: 46,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                    leading: Icon(nav.icon, size: 20),
                    title: Text(nav.label,
                        style: const TextStyle(fontWeight: FontWeight.w800)),
                    iconColor: active ? Colors.white : const Color(0xFF7383A1),
                    textColor: active ? Colors.white : const Color(0xFF64748B),
                    selected: active,
                    selectedTileColor: const Color(0xFF4F46E5),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(13)),
                    onTap: () {
                      if (compact) Navigator.maybePop(context);
                      context.go(nav.path);
                    },
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _TopBar extends ConsumerWidget {
  const _TopBar({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).valueOrNull;

    return Container(
      height: 66,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE5EAF0))),
      ),
      child: Row(
        children: [
          if (compact)
            IconButton(
              onPressed: () => Scaffold.of(context).openDrawer(),
              icon: const Icon(Icons.menu_rounded),
              tooltip: 'Menu',
            ),
          const SizedBox(width: 6),
          const _ConnectionBadge(),
          const Spacer(),
          InkWell(
            onTap: () => context.go('/profile'),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE5EAF0)),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                      radius: 14,
                      backgroundColor: const Color(0xFFE0E7FF),
                      backgroundImage: user?.photo != null
                          ? NetworkImage(user!.photo!)
                          : null,
                      child: user?.photo == null
                          ? const Icon(Icons.person, size: 16, color: Color(0xFF4F46E5))
                          : null),
                  const SizedBox(width: 8),
                  if (!compact)
                    Text('${user?.name ?? '-'}  •  ${user?.role ?? '-'}',
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          IconButton(
            onPressed: () async {
              await ref.read(authControllerProvider.notifier).logout();
              if (context.mounted) context.go('/login');
            },
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Logout',
          ),
        ],
      ),
    );
  }
}

class _ConnectionBadge extends StatelessWidget {
  const _ConnectionBadge();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFE0E7FF),
        borderRadius: BorderRadius.circular(999),
      ),
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        child: Text('API tersambung',
            style: TextStyle(
                fontSize: 12,
                color: Color(0xFF4F46E5),
                fontWeight: FontWeight.w800)),
      ),
    );
  }
}

sealed class _NavEntry {
  const _NavEntry();
}

class _NavItem extends _NavEntry {
  const _NavItem(this.label, this.path, this.icon);

  final String label;
  final String path;
  final IconData icon;
}

class _NavSection extends _NavEntry {
  const _NavSection(this.label);

  final String label;
}
