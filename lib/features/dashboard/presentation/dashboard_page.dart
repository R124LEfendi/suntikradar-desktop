import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/network/api_client.dart';
import '../../../core/widgets/page_scaffold.dart';

final dashboardProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final data = await ref.watch(apiClientProvider).get('/admin/dashboard');
  return _normalizeDashboardData(Map<String, dynamic>.from(data as Map));
});

Map<String, dynamic> _normalizeDashboardData(Map<String, dynamic> data) {
  for (final wrapperKey in ['dashboard', 'summary', 'stats', 'statistics']) {
    if (data[wrapperKey] is Map) {
      data = {
        ...data,
        ...Map<String, dynamic>.from(data[wrapperKey] as Map),
      };
      break;
    }
  }

  final counts = data['counts'] is Map
      ? Map<String, dynamic>.from(data['counts'] as Map)
      : <String, dynamic>{};

  dynamic pick(List<String> keys) {
    for (final key in keys) {
      if (counts.containsKey(key)) return counts[key];
      if (data.containsKey(key)) return data[key];
    }
    return 0;
  }

  return {
    ...data,
    'counts': {
      'kendaraan': pick([
        'kendaraan',
        'total_kendaraan',
        'kendaraan_count',
        'vehicles',
        'vehicle_count',
        'units',
        'unit_count',
      ]),
      'cabangs': pick([
        'cabangs',
        'cabang',
        'total_cabang',
        'cabang_count',
        'branches',
        'branch_count',
      ]),
      'users': pick([
        'users',
        'total_users',
        'user_count',
        'pengguna',
        'total_pengguna',
      ]),
      'search_today': pick([
        'search_today',
        'today_search',
        'history_today',
        'log_today',
        'pencarian_hari_ini',
      ]),
      'search_total': pick([
        'search_total',
        'total_search',
        'history_total',
        'log_total',
        'total_pencarian',
      ]),
    },
    'settings': data['settings'] is Map
        ? Map<String, dynamic>.from(data['settings'] as Map)
        : data['website_settings'] is Map
            ? Map<String, dynamic>.from(data['website_settings'] as Map)
            : <String, dynamic>{},
  };
}

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboard = ref.watch(dashboardProvider);

    return PageScaffold(
      title: 'Dashboard',
      subtitle: 'Ringkasan Sistem',
      actions: OutlinedButton.icon(
        onPressed: () => ref.invalidate(dashboardProvider),
        icon: const Icon(Icons.refresh_rounded),
        label: const Text('Refresh'),
      ),
      child: dashboard.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) =>
            Center(child: Text(ApiClient.mapError(error).message)),
        data: (data) {
          final counts = Map<String, dynamic>.from(data['counts'] as Map);
          final settings = data['settings'] is Map
              ? Map<String, dynamic>.from(data['settings'] as Map)
              : <String, dynamic>{};

          return LayoutBuilder(
            builder: (context, constraints) {
              final metricCols = constraints.maxWidth >= 980
                  ? 3
                  : constraints.maxWidth >= 680
                      ? 2
                      : 1;
              return SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: metricCols,
                      crossAxisSpacing: 14,
                      mainAxisSpacing: 14,
                      childAspectRatio: metricCols == 1 ? 2.9 : 2.25,
                      children: [
                        _MetricCard(
                          title: 'Total Data Unit',
                          value: counts['kendaraan'],
                          badge: 'Tersimpan',
                          note:
                              'Tersebar di ${_number(counts['cabangs'])} cabang aktif',
                          icon: Icons.directions_bike_rounded,
                          color: const Color(0xFF4F46E5),
                        ),
                        _MetricCard(
                          title: 'Total Pengguna',
                          value: counts['users'],
                          badge: 'Aktif',
                          note: 'Pengguna terdaftar dalam jaringan',
                          icon: Icons.group_rounded,
                          color: const Color(0xFFF59E0B),
                        ),
                        _MetricCard(
                          title: 'Riwayat Hari Ini',
                          value: counts['search_today'],
                          badge: 'Data Akses',
                          note:
                              'Total ${_number(counts['search_total'])} akses pencarian tercatat',
                          icon: Icons.history_rounded,
                          color: const Color(0xFF06B6D4),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    LayoutBuilder(
                      builder: (context, inner) {
                        final twoCols = inner.maxWidth >= 980;
                        final security = _SecurityPanel(
                            onSearch: () => context.go('/pencarian'));
                        final info = _SystemInfo(
                            appName: settings['app_name']?.toString() ??
                                'Admin Console');
                        if (!twoCols) {
                          return Column(children: [
                            security,
                            const SizedBox(height: 14),
                            info
                          ]);
                        }
                        return IntrinsicHeight(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(flex: 2, child: security),
                              const SizedBox(width: 14),
                              Expanded(child: info),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  static String _number(dynamic value) {
    return NumberFormat.decimalPattern('id_ID')
        .format(num.tryParse(value?.toString() ?? '0') ?? 0);
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.title,
    required this.value,
    required this.badge,
    required this.note,
    required this.icon,
    required this.color,
  });

  final String title;
  final dynamic value;
  final String badge;
  final String note;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                      color: color, borderRadius: BorderRadius.circular(14)),
                  child: Icon(icon, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Expanded(
                    child: Text(title.toUpperCase(),
                        style: const TextStyle(
                            color: Color(0xFF64748B),
                            fontSize: 11,
                            fontWeight: FontWeight.w900))),
              ],
            ),
            const Spacer(),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                    NumberFormat.decimalPattern('id_ID')
                        .format(num.tryParse(value?.toString() ?? '0') ?? 0),
                    style: const TextStyle(
                        fontSize: 30, fontWeight: FontWeight.w900)),
                const SizedBox(width: 8),
                Container(
                  margin: const EdgeInsets.only(bottom: 5),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999)),
                  child: Text(badge,
                      style: TextStyle(
                          color: color,
                          fontSize: 11,
                          fontWeight: FontWeight.w900)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 10),
            Text(note,
                style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 12,
                    fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}

class _SecurityPanel extends StatelessWidget {
  const _SecurityPanel({required this.onSearch});

  final VoidCallback onSearch;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Stack(
          children: [
            const Positioned(
                right: -10,
                top: -20,
                child: Icon(Icons.manage_search_rounded,
                    size: 160, color: Color(0x144F46E5))),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('STATUS KEAMANAN SISTEM',
                    style: TextStyle(
                        color: Color(0xFF4F46E5),
                        fontSize: 12,
                        fontWeight: FontWeight.w900)),
                const SizedBox(height: 14),
                const Text(
                  'Selamat datang di sistem manajemen data. Gunakan platform ini untuk verifikasi data unit secara akurat dan instan melalui basis data kami. Seluruh aktivitas pencarian dicatat otomatis untuk menjaga keamanan dan integritas data.',
                  style: TextStyle(color: Color(0xFF64748B), height: 1.55),
                ),
                const SizedBox(height: 18),
                FilledButton.icon(
                    onPressed: onSearch,
                    icon: const Icon(Icons.search_rounded),
                    label: const Text('Cari Kendaraan')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SystemInfo extends StatelessWidget {
  const _SystemInfo({required this.appName});

  final String appName;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('INFORMASI SISTEM',
                style: TextStyle(
                    color: Color(0xFF4F46E5),
                    fontSize: 12,
                    fontWeight: FontWeight.w900)),
            const SizedBox(height: 18),
            _InfoRow('Status Server', 'Aktif', badge: true),
            const Divider(height: 26),
            const _InfoRow('Versi Aplikasi', 'v2.4.0'),
            const Divider(height: 26),
            _InfoRow('Aplikasi', appName),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(this.label, this.value, {this.badge = false});

  final String label;
  final String value;
  final bool badge;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
            child: Text(label,
                style: const TextStyle(
                    color: Color(0xFF64748B), fontWeight: FontWeight.w800))),
        if (badge)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
                color: const Color(0xFFE0E7FF),
                borderRadius: BorderRadius.circular(999)),
            child: Text(value,
                style: const TextStyle(
                    color: Color(0xFF4F46E5),
                    fontWeight: FontWeight.w900,
                    fontSize: 12)),
          )
        else
          Text(value, style: const TextStyle(fontWeight: FontWeight.w900)),
      ],
    );
  }
}
