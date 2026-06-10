import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/page_scaffold.dart';

class KendaraanSearchPage extends ConsumerStatefulWidget {
  const KendaraanSearchPage({super.key});

  @override
  ConsumerState<KendaraanSearchPage> createState() =>
      _KendaraanSearchPageState();
}

class _KendaraanSearchPageState extends ConsumerState<KendaraanSearchPage> {
  final _queryController = TextEditingController();
  Timer? _timer;
  String _field = 'no_polisi';
  bool _loading = false;
  String? _error;
  Map<String, dynamic>? _meta;
  List<Map<String, dynamic>> _rows = [];

  @override
  void dispose() {
    _timer?.cancel();
    _queryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PageScaffold(
      title: 'Pencarian Kendaraan',
      subtitle:
          'Lacak data kendaraan berdasarkan nomor polisi, nomor mesin, atau nomor rangka.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.manage_search_rounded,
                          color: Color(0xFF4F46E5)),
                      const SizedBox(width: 10),
                      const Expanded(
                          child: Text('Lacak data kendaraan',
                              style: TextStyle(
                                  fontWeight: FontWeight.w900, fontSize: 18))),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(999)),
                        child: const Text('Prefix search',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF64748B))),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final compact = constraints.maxWidth < 760;
                      final fieldSelect = DropdownButtonFormField<String>(
                        initialValue: _field,
                        isExpanded: true,
                        items: const [
                          DropdownMenuItem(
                              value: 'no_polisi', child: Text('Nomor Polisi')),
                          DropdownMenuItem(
                              value: 'no_mesin', child: Text('Nomor Mesin')),
                          DropdownMenuItem(
                              value: 'no_rangka', child: Text('Nomor Rangka')),
                        ],
                        onChanged: (value) {
                          if (value == null) return;
                          setState(() => _field = value);
                          _scheduleSearch(_queryController.text);
                        },
                        decoration: const InputDecoration(labelText: 'Field'),
                      );
                      final searchInput = TextField(
                        controller: _queryController,
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.manage_search_rounded),
                          suffixIcon: _loading
                              ? const Padding(
                                  padding: EdgeInsets.all(13),
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2))
                              : null,
                          hintText: 'Nomor polisi, mesin, atau rangka...',
                        ),
                        textCapitalization: TextCapitalization.characters,
                        onChanged: _scheduleSearch,
                      );

                      if (compact) {
                        return Column(children: [
                          fieldSelect,
                          const SizedBox(height: 10),
                          searchInput
                        ]);
                      }
                      return Row(children: [
                        SizedBox(width: 230, child: fieldSelect),
                        const SizedBox(width: 12),
                        Expanded(child: searchInput)
                      ]);
                    },
                  ),
                ],
              ),
            ),
          ),
          if (_meta != null) ...[
            const SizedBox(height: 12),
            _MetaBar(meta: _meta!),
          ],
          const SizedBox(height: 14),
          Expanded(child: _content()),
        ],
      ),
    );
  }

  Widget _content() {
    if (_loading && _rows.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return EmptyState(
          title: 'Pencarian gagal',
          message: _error,
          icon: Icons.error_outline_rounded);
    }
    if (_rows.isEmpty) {
      return const EmptyState(
          title: 'Mulai pencarian',
          message:
              'Masukkan minimal 1 karakter untuk menampilkan data kendaraan yang cocok.',
          icon: Icons.manage_search_rounded);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1080
            ? 3
            : constraints.maxWidth >= 720
                ? 2
                : 1;
        return GridView.builder(
          padding: const EdgeInsets.only(bottom: 16),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: columns == 1 ? 5.4 : 4.2,
          ),
          itemCount: _rows.length,
          itemBuilder: (context, index) => _ResultCard(
            row: _rows[index],
            onDetail: () async {
              final row = _rows[index];
              final template = await _loadWhatsappTemplate();
              await _log(row, action: 'detail');
              if (!mounted) return;
              showDialog<void>(
                context: this.context,
                builder: (context) =>
                    _VehicleDetailDialog(row: row, shareTemplate: template),
              );
            },
          ),
        );
      },
    );
  }

  void _scheduleSearch(String value) {
    _timer?.cancel();
    _timer =
        Timer(const Duration(milliseconds: 300), () => _search(value.trim()));
  }

  Future<void> _search(String value) async {
    if (value.isEmpty) {
      setState(() {
        _rows = [];
        _meta = null;
        _error = null;
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final response = await ref
          .read(apiClientProvider)
          .dio
          .get('/cari/kendaraan', queryParameters: {
        'q': value,
        'field': _field,
        'limit': 50,
      });
      final body = Map<String, dynamic>.from(response.data as Map);
      setState(() {
        _rows = (body['data'] as List)
            .map((item) => Map<String, dynamic>.from(item as Map))
            .toList();
        _meta = body['meta'] is Map
            ? Map<String, dynamic>.from(body['meta'] as Map)
            : null;
      });
      await _logSearch(value, _rows.length);
    } catch (error) {
      setState(() => _error = ApiClient.mapError(error).message);
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _logSearch(String query, int resultsCount) async {
    try {
      final location = await _readLocation();
      await ref.read(apiClientProvider).post('/log-lokasi', data: {
        'query': query,
        'results_count': resultsCount,
        'source': 'database',
        'response_time_ms': _meta?['response_time_ms'] ?? 0,
        'channel': 'api',
        ...location.toPayload(),
      });
    } catch (_) {
      // Riwayat pencarian tidak boleh mengganggu hasil search.
    }
  }

  Future<void> _log(Map<String, dynamic> row,
      {String action = 'detail'}) async {
    try {
      final location = await _readLocation();
      await ref.read(apiClientProvider).post('/log-lokasi', data: {
        'query': row['no_polisi'],
        'results_count': 1,
        'source': 'database',
        'response_time_ms': _meta?['response_time_ms'] ?? 0,
        'channel': 'api',
        'action': action,
        ...location.toPayload(),
        'vehicle_id': row['id'],
        'no_polisi': row['no_polisi'],
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Pencarian tercatat')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ApiClient.mapError(error).message)));
    }
  }

  Future<String?> _loadWhatsappTemplate() async {
    try {
      final data =
          await ref.read(apiClientProvider).get('/admin/website-settings');
      if (data is! Map) return null;
      final map = Map<String, dynamic>.from(data);
      final template = map['whatsapp_share_template']?.toString().trim();
      return template?.isNotEmpty == true ? template : null;
    } catch (_) {
      return null;
    }
  }
}

class _MetaBar extends StatelessWidget {
  const _MetaBar({required this.meta});

  final Map<String, dynamic> meta;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5EAF0)),
      ),
      child: Row(
        children: [
          Text(meta['field_label']?.toString() ?? '-',
              style: const TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(width: 8),
          Text(meta['source']?.toString() ?? 'Database',
              style: const TextStyle(color: Color(0xFF64748B), fontSize: 12)),
          const Spacer(),
          Text('${meta['response_time_ms'] ?? 0}ms',
              style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(width: 14),
          Text('${meta['count'] ?? 0} hasil',
              style: const TextStyle(fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.row, required this.onDetail});

  final Map<String, dynamic> row;
  final VoidCallback onDetail;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 16, 16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_text(row['no_polisi']),
                          style: const TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF0E6EA8),
                              letterSpacing: 0)),
                      const SizedBox(height: 6),
                      const Row(
                        children: [
                          Icon(Icons.lock_outline_rounded,
                              size: 15, color: Color(0xFF718096)),
                          SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Data lengkap tersedia di halaman detail',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  color: Color(0xFF718096),
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton.tonalIcon(
                  onPressed: null,
                  icon: const Icon(Icons.check_circle_outline_rounded),
                  label: const Text('Ditemukan'),
                  style: FilledButton.styleFrom(
                    disabledBackgroundColor: const Color(0xFFE6F7FF),
                    disabledForegroundColor: const Color(0xFF0369A1),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 13),
                  ),
                ),
                const SizedBox(width: 10),
                FilledButton.icon(
                  onPressed: onDetail,
                  icon: const Icon(Icons.visibility_outlined),
                  label: const Text('Lihat Detail'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF111827),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 15),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _VehicleDetailDialog extends StatelessWidget {
  const _VehicleDetailDialog({required this.row, this.shareTemplate});

  final Map<String, dynamic> row;
  final String? shareTemplate;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(18),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1180),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Material(
            color: Colors.white,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.fromLTRB(32, 28, 32, 32),
                    color: const Color(0xFFF6FBFF),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(_text(row['no_polisi']),
                                  style: const TextStyle(
                                      fontSize: 58,
                                      height: 1,
                                      fontWeight: FontWeight.w900,
                                      color: Color(0xFF111827),
                                      letterSpacing: 0)),
                              const SizedBox(height: 12),
                              Text(
                                  '${_text(row['nama_leasing'])} / ${_text(row['nama_cabang'])}',
                                  style: const TextStyle(
                                      color: Color(0xFF64748B),
                                      fontSize: 16,
                                      fontWeight: FontWeight.w900)),
                            ],
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            OutlinedButton.icon(
                              onPressed: null,
                              icon: const Icon(Icons.verified_user_outlined,
                                  size: 16),
                              label: const Text('Data kendaraan'),
                              style: OutlinedButton.styleFrom(
                                disabledForegroundColor:
                                    const Color(0xFF64748B),
                                side:
                                    const BorderSide(color: Color(0xFFDDE6F0)),
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton.filledTonal(
                              onPressed: () => Navigator.of(context).pop(),
                              icon: const Icon(Icons.close_rounded),
                              tooltip: 'Tutup',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final twoCols = constraints.maxWidth >= 880;
                        final details = _VehicleDetailGrid(row: row);
                        final side = _VehicleSidePanel(
                            row: row, shareTemplate: shareTemplate);
                        if (!twoCols) {
                          return Column(
                            children: [
                              details,
                              const SizedBox(height: 16),
                              side,
                            ],
                          );
                        }
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(flex: 2, child: details),
                            const SizedBox(width: 20),
                            SizedBox(width: 360, child: side),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _VehicleDetailGrid extends StatelessWidget {
  const _VehicleDetailGrid({required this.row});

  final Map<String, dynamic> row;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 640 ? 2 : 1;
            return GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: columns,
              crossAxisSpacing: 14,
              mainAxisSpacing: 14,
              childAspectRatio: columns == 1 ? 3.2 : 2.8,
              children: [
                _DetailTile(
                    icon: Icons.two_wheeler_rounded,
                    label: 'Tipe Kendaraan',
                    value: _text(row['type_motor'])),
                _DetailTile(
                    icon: Icons.business_rounded,
                    label: 'Finance',
                    value: _text(row['nama_leasing'])),
                _DetailTile(
                    icon: Icons.location_on_outlined,
                    label: 'Cabang',
                    value: _text(row['nama_cabang'])),
                _DetailTile(
                    icon: Icons.memory_rounded,
                    label: 'No Mesin',
                    value: _text(row['no_mesin'])),
                _DetailTile(
                    icon: Icons.qr_code_scanner_rounded,
                    label: 'No Rangka',
                    value: _text(row['no_rangka'])),
                _DetailTile(
                    icon: Icons.flag_outlined,
                    label: 'OVD',
                    value: _text(row['ovd'])),
              ],
            );
          },
        ),
        const SizedBox(height: 14),
        _DetailTile(
          icon: Icons.description_outlined,
          label: 'Nomor Kontrak',
          value: _text(row['nomor_kontrak']),
          wide: true,
        ),
        const SizedBox(height: 20),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: const Color(0xFFFFFBEB),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFFDE68A)),
          ),
          child: const Row(
            children: [
              Icon(Icons.warning_amber_rounded,
                  color: Color(0xFF92400E), size: 18),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Data yang ditampilkan hanya sebagai informasi dan tidak dapat digunakan sebagai dasar penarikan kendaraan.',
                  style: TextStyle(
                      color: Color(0xFF92400E), fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DetailTile extends StatelessWidget {
  const _DetailTile({
    required this.icon,
    required this.label,
    required this.value,
    this.wide = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(minHeight: wide ? 122 : 112),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Icon(icon, color: const Color(0xFF0F172A), size: 19),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label.toUpperCase(),
                    style: const TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 11,
                        fontWeight: FontWeight.w900)),
                const SizedBox(height: 6),
                Text(value,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: Color(0xFF020617),
                        fontSize: 16,
                        fontWeight: FontWeight.w900)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _VehicleSidePanel extends StatelessWidget {
  const _VehicleSidePanel({required this.row, this.shareTemplate});

  final Map<String, dynamic> row;
  final String? shareTemplate;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _SideBox(
          title: 'Lokasi Pengakses',
          icon: Icons.location_on_outlined,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Lokasi belum diizinkan oleh pengakses',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
              const SizedBox(height: 12),
              _MutedLine(Icons.person_outline_rounded,
                  _text(row['accessed_by'] ?? row['admin'] ?? 'Admin')),
              const SizedBox(height: 8),
              _MutedLine(Icons.access_time_rounded,
                  _text(row['accessed_at'] ?? row['created_at'])),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: null,
                icon: const Icon(Icons.map_outlined),
                label: const Text('Lihat di Maps'),
                style: FilledButton.styleFrom(
                  disabledBackgroundColor: const Color(0xFF6B7280),
                  disabledForegroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _SideBox(
          title: 'Share Informasi',
          icon: Icons.send_outlined,
          child: FilledButton.icon(
            onPressed: () => _shareWhatsApp(context, row, shareTemplate),
            icon: const Icon(Icons.chat_outlined),
            label: const Text('Share ke Whatsapp'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF16A34A),
              foregroundColor: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 14),
        _SideBox(
          title: 'Kirim Notifikasi',
          icon: Icons.notifications_none_rounded,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const TextField(
                maxLines: 4,
                decoration:
                    InputDecoration(hintText: 'Tulis pesan untuk admin...'),
              ),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Notifikasi belum tersedia')),
                ),
                icon: const Icon(Icons.send_outlined),
                label: const Text('Kirim Notifikasi'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF111827),
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SideBox extends StatelessWidget {
  const _SideBox(
      {required this.title, required this.icon, required this.child});

  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 15, color: const Color(0xFF64748B)),
              const SizedBox(width: 7),
              Text(title.toUpperCase(),
                  style: const TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 12,
                      fontWeight: FontWeight.w900)),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _MutedLine extends StatelessWidget {
  const _MutedLine(this.icon, this.text);

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 15, color: const Color(0xFF64748B)),
        const SizedBox(width: 6),
        Expanded(
          child: Text(text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  color: Color(0xFF64748B), fontWeight: FontWeight.w800)),
        ),
      ],
    );
  }
}

Future<void> _shareWhatsApp(
    BuildContext context, Map<String, dynamic> row, String? template) async {
  final message = _renderWhatsappMessage(row, template);
  final url = 'https://wa.me/?text=${Uri.encodeComponent(message)}';

  try {
    if (Platform.isWindows) {
      await Process.start('rundll32', ['url.dll,FileProtocolHandler', url]);
    } else if (Platform.isMacOS) {
      await Process.start('open', [url]);
    } else {
      await Process.start('xdg-open', [url]);
    }
  } catch (error) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Gagal membuka WhatsApp: $error')),
    );
  }
}

String _renderWhatsappMessage(Map<String, dynamic> row, String? template) {
  final fallback = [
    'Data Kendaraan',
    'No Polisi: {no_polisi}',
    'Tipe: {type_motor}',
    'Finance: {nama_leasing}',
    'Cabang: {nama_cabang}',
    'No Mesin: {no_mesin}',
    'No Rangka: {no_rangka}',
    'OVD: {ovd}',
    'Nomor Kontrak: {nomor_kontrak}',
  ].join('\n');
  var message =
      template?.trim().isNotEmpty == true ? template!.trim() : fallback;
  final values = {
    'no_polisi': _text(row['no_polisi']),
    'type_motor': _text(row['type_motor']),
    'nama_leasing': _text(row['nama_leasing']),
    'nama_cabang': _text(row['nama_cabang']),
    'no_mesin': _text(row['no_mesin']),
    'no_rangka': _text(row['no_rangka']),
    'ovd': _text(row['ovd']),
    'nomor_kontrak': _text(row['nomor_kontrak']),
  };
  for (final entry in values.entries) {
    message = message
        .replaceAll('{${entry.key}}', entry.value)
        .replaceAll('{{${entry.key}}}', entry.value);
  }
  return message;
}

Future<_LocationSnapshot> _readLocation() async {
  if (!Platform.isWindows) return const _LocationSnapshot();
  try {
    final result = await Process.run('powershell', [
      '-NoProfile',
      '-ExecutionPolicy',
      'Bypass',
      '-Command',
      r'''
Add-Type -AssemblyName System.Device
$watcher = New-Object System.Device.Location.GeoCoordinateWatcher
$watcher.TryStart($false, [TimeSpan]::FromMilliseconds(3000)) | Out-Null
$coord = $watcher.Position.Location
if ($coord -and -not $coord.IsUnknown) {
  @{ latitude = $coord.Latitude; longitude = $coord.Longitude; accuracy = $coord.HorizontalAccuracy; location_permission = $true } | ConvertTo-Json -Compress
} else {
  @{ latitude = $null; longitude = $null; accuracy = $null; location_permission = $false } | ConvertTo-Json -Compress
}
''',
    ]).timeout(const Duration(seconds: 5));
    final output = result.stdout?.toString().trim();
    if (output == null || output.isEmpty) return const _LocationSnapshot();
    final map = Map<String, dynamic>.from(jsonDecode(output) as Map);
    return _LocationSnapshot(
      latitude: num.tryParse(map['latitude']?.toString() ?? '')?.toDouble(),
      longitude: num.tryParse(map['longitude']?.toString() ?? '')?.toDouble(),
      accuracy: num.tryParse(map['accuracy']?.toString() ?? '')?.toDouble(),
      permission: map['location_permission'] == true,
    );
  } catch (_) {
    return const _LocationSnapshot();
  }
}

class _LocationSnapshot {
  const _LocationSnapshot({
    this.latitude,
    this.longitude,
    this.accuracy,
    this.permission = false,
  });

  final double? latitude;
  final double? longitude;
  final double? accuracy;
  final bool permission;

  Map<String, dynamic> toPayload() => {
        'latitude': latitude,
        'longitude': longitude,
        'accuracy': accuracy,
        'location_permission': permission,
      };
}

String _text(dynamic value) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? '-' : text;
}
