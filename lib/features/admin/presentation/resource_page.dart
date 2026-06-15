import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/page_scaffold.dart';
import '../../../core/widgets/responsive_table.dart';
import '../../../core/widgets/value_reader.dart';
import 'resource_config.dart';

final adminLookupsProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final data = await ref.watch(apiClientProvider).get('/admin/lookups');
  return Map<String, dynamic>.from(data as Map);
});

final resourceProvider = FutureProvider.autoDispose.family<Map<String, dynamic>,
    ({String key, String q, int page, int perPage})>((ref, args) async {
  final config = resourceConfigs[args.key]!;
  final data = await ref.watch(apiClientProvider).get(
    config.path,
    query: {
      if (args.q.isNotEmpty) 'q': args.q,
      'per_page': args.perPage,
      'page': args.page,
    },
  );
  if (config.key == 'settings') {
    return {
      'items': [Map<String, dynamic>.from(data as Map)],
      'meta': {'total': 1},
    };
  }
  if (data is List) {
    return {
      'items': data,
      'meta': {'total': data.length},
    };
  }
  return Map<String, dynamic>.from(data as Map);
});

class ResourcePage extends ConsumerStatefulWidget {
  const ResourcePage({super.key, required this.resourceKey});

  final String resourceKey;

  @override
  ConsumerState<ResourcePage> createState() => _ResourcePageState();
}

class _ResourcePageState extends ConsumerState<ResourcePage> {
  final _searchController = TextEditingController();
  Timer? _timer;
  String _query = '';
  int _page = 1;
  int _perPage = 10;
  Map<String, dynamic>? _editing;
  Map<String, dynamic>? _lastResourceData;
  bool _creating = false;

  ResourceConfig get config => resourceConfigs[widget.resourceKey]!;
  bool get _formOpen =>
      _creating || _editing != null || config.key == 'settings';
  bool get _isSettings => config.key == 'settings';

  @override
  void didUpdateWidget(covariant ResourcePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.resourceKey != widget.resourceKey) {
      _query = '';
      _page = 1;
      _perPage = 10;
      _searchController.clear();
      _editing = null;
      _lastResourceData = null;
      _creating = false;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  ({String key, String q, int page, int perPage}) get _resourceArgs =>
      (key: widget.resourceKey, q: _query, page: _page, perPage: _perPage);

  @override
  Widget build(BuildContext context) {
    final resource = ref.watch(resourceProvider(_resourceArgs));

    return PageScaffold(
      title: config.title,
      subtitle: _subtitle,
      actions: _Toolbar(
        config: config,
        searchController: _searchController,
        onSearch: (value) {
          _timer?.cancel();
          _timer = Timer(
              const Duration(milliseconds: 300),
              () => setState(() {
                    _query = value.trim();
                    _page = 1;
                  }));
        },
        onRefresh: () => ref.invalidate(resourceProvider(_resourceArgs)),
        onCreate: config.canCreate
            ? () => setState(() {
                  _creating = true;
                  _editing = null;
                })
            : null,
        onImport: config.key == 'kendaraan' ? _openImport : null,
        perPage: _perPage,
        onPerPageChanged: (value) => setState(() {
          _perPage = value;
          _page = 1;
        }),
      ),
      child: _resourceBody(resource),
    );
  }

  Widget _resourceBody(AsyncValue<Map<String, dynamic>> resource) {
    final latest = resource.valueOrNull;
    if (latest != null) _lastResourceData = latest;
    final data = latest ?? _lastResourceData;

    if (data == null) {
      return resource.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) =>
            Center(child: Text(ApiClient.mapError(error).message)),
        data: _resourceContent,
      );
    }

    return Stack(
      children: [
        _resourceContent(data),
        if (resource.isLoading)
          const Positioned(
            left: 0,
            top: 0,
            right: 0,
            child: LinearProgressIndicator(minHeight: 3),
          ),
        if (resource.hasError)
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: _InlineError(
                message: ApiClient.mapError(resource.error!).message),
          ),
      ],
    );
  }

  Widget _resourceContent(Map<String, dynamic> data) {
    final items = (data['items'] as List? ?? const [])
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
    final meta = data['meta'] is Map
        ? Map<String, dynamic>.from(data['meta'] as Map)
        : <String, dynamic>{};
    final settingsItem =
        config.key == 'settings' && items.isNotEmpty ? items.first : null;

    if (_isSettings) {
      return Center(
        child: SizedBox(
          width: 720,
          child: _ResourceFormPage(
            key: ValueKey('${config.key}-${settingsItem?['id'] ?? 'settings'}'),
            config: config,
            item: settingsItem,
            onCancel: null,
            onSubmit: _save,
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final sideBySide = constraints.maxWidth >= 1180 && _formOpen;
        final list = _ResourceList(
          config: config,
          items: items,
          meta: meta,
          perPage: _perPage,
          searchController: _searchController,
          onSearch: (value) {
            _timer?.cancel();
            _timer = Timer(
                const Duration(milliseconds: 300),
                () => setState(() {
                      _query = value.trim();
                      _page = 1;
                    }));
          },
          onPerPageChanged: (value) => setState(() {
            _perPage = value;
            _page = 1;
          }),
          onEdit: (item) => setState(() {
            _editing = item;
            _creating = false;
          }),
          onDelete: _delete,
          onApprove: (item) => _transactionAction(item, 'approve'),
          onCancel: (item) => _transactionAction(item, 'cancel'),
          onHistory: _showNopolHistory,
          onView: (item) {
            if (config.key == 'history') {
              _showNopolHistory(item);
            } else {
              _view(item);
            }
          },
          onPage: (page) => setState(() => _page = page),
        );
        final form = _formOpen
            ? _ResourceFormPage(
                key: ValueKey('${config.key}-${_editing?['id'] ?? 'new'}'),
                config: config,
                item: _editing,
                onCancel: () => setState(() {
                  _creating = false;
                  _editing = null;
                }),
                onSubmit: _save,
              )
            : null;

        if (sideBySide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(flex: 7, child: list),
              const SizedBox(width: 14),
              Expanded(flex: 4, child: form!),
            ],
          );
        }

        if (form != null && constraints.maxWidth < 1180) {
          return form;
        }

        return list;
      },
    );
  }

  String get _subtitle {
    return switch (config.key) {
      'kendaraan' =>
        'Kelola unit, relasi leasing/cabang, dan import data kendaraan.',
      'transactions' => 'Pantau transaksi paket dan approval akses.',
      'history' => 'Lihat riwayat pencarian pengguna.',
      'settings' =>
        'Atur konfigurasi aplikasi, jadwal, disclaimer, dan template.',
      _ => 'Kelola data master dengan tampilan tabel dan form desktop.',
    };
  }

  Future<void> _save(Map<String, dynamic> payload) async {
    try {
      if (_editing != null) {
        payload['id'] = _editing!['id'];
      }
      
      await ref.read(apiClientProvider).post(config.path, data: payload);
      setState(() {
        _creating = false;
        _editing = null;
      });
      ref.invalidate(resourceProvider(_resourceArgs));
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _delete(Map<String, dynamic> item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Row(
          children: [
            const Expanded(child: Text('Hapus data?')),
            IconButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              icon: const Icon(Icons.close_rounded),
              tooltip: 'Tutup',
            ),
          ],
        ),
        content: const Text('Data yang dihapus tidak dapat dikembalikan.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Batal')),
          FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Hapus')),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(apiClientProvider).delete('${config.path}/${item['id']}');
      ref.invalidate(resourceProvider(_resourceArgs));
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _transactionAction(
      Map<String, dynamic> item, String action) async {
    try {
      await ref
          .read(apiClientProvider)
          .post('/admin/transactions/${item['id']}/$action');
      ref.invalidate(resourceProvider(_resourceArgs));
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _openImport() async {
    final result = await showDialog<_ImportPayload>(
      context: context,
      builder: (_) => const _ImportDialog(),
    );
    if (result == null) return;

    try {
      final formData = FormData.fromMap({
        'leasing_id': result.leasingId,
        'cabang_id': result.cabangId,
        'upload_type': result.uploadType,
        'file': await MultipartFile.fromFile(result.filePath,
            filename: result.fileName),
      });
      final response = await ref
          .read(apiClientProvider)
          .post('/admin/kendaraan/import', data: formData);
      if (!mounted) return;
      ref.invalidate(resourceProvider(_resourceArgs));
      final importId = _extractImportId(response);
      if (importId != null) {
        await showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (_) => _ImportProgressDialog(importId: importId),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Import kendaraan sedang diproses')));
      }
    } catch (error) {
      _showError(error);
    }
  }

  String? _extractImportId(dynamic response) {
    if (response is! Map) return null;
    final map = Map<String, dynamic>.from(response);
    for (final key in ['id', 'import_id', 'job_id', 'batch_id']) {
      final value = map[key]?.toString();
      if (value != null && value.isNotEmpty) return value;
    }
    final progress = map['progress'];
    if (progress is Map) {
      final nested = Map<String, dynamic>.from(progress);
      for (final key in ['id', 'import_id', 'job_id', 'batch_id']) {
        final value = nested[key]?.toString();
        if (value != null && value.isNotEmpty) return value;
      }
    }
    return null;
  }

  void _showError(Object error) {
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ApiClient.mapError(error).message)));
  }

  void _view(Map<String, dynamic> item) {
    final config = resourceConfigs[widget.resourceKey]!;
    if (config.key == 'history') {
      showDialog(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Row(
            children: [
              const Expanded(
                  child: Text('Detail Pencarian',
                      style: TextStyle(fontWeight: FontWeight.bold))),
              IconButton(
                onPressed: () => Navigator.pop(dialogContext),
                icon: const Icon(Icons.close_rounded),
                tooltip: 'Tutup',
              ),
            ],
          ),
          content: SizedBox(
            width: 880,
            child: SingleChildScrollView(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final twoCols = constraints.maxWidth >= 880;
                  final details = Column(
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
                              // _DetailTile(icon: Icons.search_rounded, label: 'Query', value: item['query']?.toString() ?? '-'),
                              _DetailTile(
                                  icon: Icons.two_wheeler_rounded,
                                  label: 'No Polisi',
                                  value: item['no_polisi']?.toString() ?? '-'),
                              _DetailTile(
                                  icon: Icons.memory_rounded,
                                  label: 'No Mesin',
                                  value: item['no_mesin']?.toString() ?? '-'),
                              _DetailTile(
                                  icon: Icons.qr_code_scanner_rounded,
                                  label: 'No Rangka',
                                  value: item['no_rangka']?.toString() ?? '-'),
                              _DetailTile(
                                  icon: Icons.business_rounded,
                                  label: 'Finance / Leasing',
                                  value:
                                      item['nama_leasing']?.toString() ?? '-'),
                              _DetailTile(
                                  icon: Icons.location_city_rounded,
                                  label: 'Cabang',
                                  value:
                                      item['nama_cabang']?.toString() ?? '-'),
                              _DetailTile(
                                  icon: Icons.domain_rounded,
                                  label: 'Perusahaan Pengakses',
                                  value:
                                      item['user_company']?.toString() ?? '-'),
                              _DetailTile(
                                  icon: Icons.person_rounded,
                                  label: 'User Pengakses',
                                  value: item['user_name']?.toString() ?? '-'),
                            ],
                          );
                        },
                      ),
                      if (item['disclaimer'] != null &&
                          item['disclaimer'].toString().isNotEmpty) ...[
                        const SizedBox(height: 20),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFFBEB),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFFFDE68A)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.warning_amber_rounded,
                                  color: Color(0xFF92400E), size: 18),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  item['disclaimer'].toString(),
                                  style: const TextStyle(
                                      color: Color(0xFF92400E),
                                      fontWeight: FontWeight.w800),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  );

                  final side = Column(
                    children: [
                      _SideBox(
                        title: 'Lokasi Pengakses',
                        icon: Icons.location_on_outlined,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (item['latitude'] != null &&
                                item['longitude'] != null)
                              Text("${item['latitude']}, ${item['longitude']}",
                                  style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w900))
                            else
                              const Text(
                                  'Lokasi belum diizinkan oleh pengakses',
                                  style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w900)),
                            const SizedBox(height: 12),
                            _MutedLine(Icons.person_outline_rounded,
                                item['user_name']?.toString() ?? 'Admin'),
                            const SizedBox(height: 8),
                            _MutedLine(Icons.access_time_rounded,
                                item['created_at']?.toString() ?? '-'),
                            const SizedBox(height: 16),
                            FilledButton.icon(
                              onPressed: (item['latitude'] != null &&
                                      item['longitude'] != null)
                                  ? () async {
                                      final url =
                                          'https://www.google.com/maps/search/?api=1&query=${item['latitude']},${item['longitude']}';
                                      try {
                                        if (Platform.isWindows) {
                                          await Process.start('rundll32', [
                                            'url.dll,FileProtocolHandler',
                                            url
                                          ]);
                                        } else if (Platform.isMacOS) {
                                          await Process.start('open', [url]);
                                        } else {
                                          await Process.start(
                                              'xdg-open', [url]);
                                        }
                                      } catch (e) {
                                        // ignore
                                      }
                                    }
                                  : null,
                              icon: const Icon(Icons.map_outlined),
                              label: const Text('Lihat di Maps'),
                              style: FilledButton.styleFrom(
                                disabledBackgroundColor:
                                    const Color(0xFF6B7280),
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
                          onPressed: () async {
                            final phone = item['user_phone']?.toString();
                            final url = 'https://wa.me/${phone ?? ''}';
                            try {
                              if (Platform.isWindows) {
                                await Process.start('rundll32',
                                    ['url.dll,FileProtocolHandler', url]);
                              } else if (Platform.isMacOS) {
                                await Process.start('open', [url]);
                              } else {
                                await Process.start('xdg-open', [url]);
                              }
                            } catch (e) {
                              // ignore
                            }
                          },
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
                              decoration: InputDecoration(
                                  hintText: 'Tulis pesan untuk admin...',
                                  hintStyle: TextStyle(fontSize: 13)),
                            ),
                            const SizedBox(height: 14),
                            FilledButton.icon(
                              onPressed: () =>
                                  ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text('Notifikasi belum tersedia')),
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
                      const SizedBox(width: 24),
                      Expanded(flex: 1, child: side),
                    ],
                  );
                },
              ),
            ),
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Tutup'),
            ),
          ],
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Row(
          children: [
            const Expanded(
                child: Text('Detail Data',
                    style: TextStyle(fontWeight: FontWeight.bold))),
            IconButton(
              onPressed: () => Navigator.pop(dialogContext),
              icon: const Icon(Icons.close_rounded),
              tooltip: 'Tutup',
            ),
          ],
        ),
        content: SizedBox(
          width: 720,
          child: SingleChildScrollView(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth >= 640 ? 2 : 1;
                return GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: columns,
                  crossAxisSpacing: 14,
                  mainAxisSpacing: 14,
                  childAspectRatio: columns == 1 ? 3.2 : 2.8,
                  children: (() {
                    if (config.key == 'transactions') {
                      final rows = [
                        ['Invoice', item['invoice']?.toString() ?? '-'],
                        ['Pembeli', item['user_name']?.toString() ?? (item['user'] is Map ? item['user']['name']?.toString() : null) ?? '-'],
                        ['Kontak', item['user_phone']?.toString() ?? (item['user'] is Map ? item['user']['phone']?.toString() : null) ?? '-'],
                        ['Perusahaan', item['user_company']?.toString() ?? (item['user'] is Map ? item['user']['company']?.toString() : null) ?? '-'],
                        ['Paket', item['nama_paket']?.toString() ?? '-'],
                        ['Harga', item['harga']?.toString() ?? '-'],
                        ['Status', item['status']?.toString() ?? '-'],
                        ['Tanggal Order', item['created_at']?.toString() ?? '-'],
                        ['Mulai Aktif', item['tanggal_mulai']?.toString() ?? '-'],
                        ['Expired', item['tanggal_expired']?.toString() ?? '-'],
                      ];
                      return rows.map((row) {
                        return _DetailTile(
                          icon: Icons.info_outline_rounded,
                          label: row[0],
                          value: row[1],
                        );
                      }).toList();
                    }

                    return item.entries.map((e) {
                      return _DetailTile(
                        icon: Icons.info_outline_rounded,
                        label: e.key.replaceAll('_', ' '),
                        value: e.value?.toString() ?? '-',
                      );
                    }).toList();
                  })(),
                );
              },
            ),
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Tutup'),
          ),
        ],
      ),
    );
  }

  Future<void> _showNopolHistory(Map<String, dynamic> item) async {
    final id = item['id']?.toString();
    if (id == null || id.isEmpty) return;

    try {
      final data =
          await ref.read(apiClientProvider).get('/history-log/detail/$id');
      final detail = Map<String, dynamic>.from(data as Map);
      if (!mounted) return;
      _view(detail);
    } catch (error) {
      _showError(error);
    }
  }
}

class _Toolbar extends StatelessWidget {
  const _Toolbar({
    required this.config,
    required this.searchController,
    required this.onSearch,
    required this.onRefresh,
    this.onCreate,
    this.onImport,
    required this.perPage,
    required this.onPerPageChanged,
  });

  final ResourceConfig config;
  final TextEditingController searchController;
  final ValueChanged<String> onSearch;
  final VoidCallback onRefresh;
  final VoidCallback? onCreate;
  final VoidCallback? onImport;
  final int perPage;
  final ValueChanged<int> onPerPageChanged;

  @override
  Widget build(BuildContext context) {
    // Settings tidak butuh toolbar biasa
    if (config.key == 'settings') {
      return Wrap(
        spacing: 10,
        runSpacing: 10,
        alignment: WrapAlignment.end,
        children: [
          OutlinedButton.icon(
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Refresh')),
        ],
      );
    }

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      alignment: WrapAlignment.end,
      children: [
        OutlinedButton.icon(
            onPressed: onRefresh,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Refresh')),
        if (onImport != null)
          OutlinedButton.icon(
              onPressed: onImport,
              icon: const Icon(Icons.upload_file_rounded),
              label: const Text('Import')),
        if (onCreate != null)
          FilledButton.icon(
              onPressed: onCreate,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Tambah')),
      ],
    );
  }
}

class _ResourceList extends StatelessWidget {
  const _ResourceList({
    required this.config,
    required this.items,
    required this.meta,
    required this.perPage,
    required this.searchController,
    required this.onSearch,
    required this.onPerPageChanged,
    required this.onEdit,
    required this.onDelete,
    required this.onApprove,
    required this.onCancel,
    required this.onHistory,
    required this.onPage,
    required this.onView,
  });

  final ResourceConfig config;
  final List<Map<String, dynamic>> items;
  final Map<String, dynamic> meta;
  final int perPage;
  final TextEditingController searchController;
  final ValueChanged<String> onSearch;
  final ValueChanged<int> onPerPageChanged;
  final ValueChanged<Map<String, dynamic>> onEdit;
  final ValueChanged<Map<String, dynamic>> onDelete;
  final ValueChanged<Map<String, dynamic>> onApprove;
  final ValueChanged<Map<String, dynamic>> onCancel;
  final ValueChanged<Map<String, dynamic>> onHistory;
  final ValueChanged<int> onPage;
  final ValueChanged<Map<String, dynamic>> onView;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const EmptyState(
          title: 'Data belum tersedia',
          message: 'Gunakan tombol tambah atau refresh untuk memuat data.');
    }

    return Card(
      child: Column(
        children: [
          _TableControls(
            config: config,
            perPage: perPage,
            searchController: searchController,
            onSearch: onSearch,
            onPerPageChanged: onPerPageChanged,
          ),
          const Divider(height: 1),
          Expanded(
            child: config.useCardLayout
                ? _ResourceCardGrid(
                    config: config,
                    items: items,
                    onEdit: onEdit,
                    onDelete: onDelete,
                    onApprove: onApprove,
                    onCancel: onCancel,
                    onView: onView,
                  )
                : ResponsiveTable(
                    columns: config.columns.map((field) {
                      return ResponsiveTableColumn(
                        label: field.label,
                        minWidth: _widthFor(field.key),
                        value: (row) => readValue(row, field.key),
                        cell: _cellFor(field, onHistory),
                      );
                    }).toList(),
                    rows: items,
                    actions: (row) => _Actions(
                      config: config,
                      item: row,
                      onEdit: () => onEdit(row),
                      onDelete: () => onDelete(row),
                      onApprove: () => onApprove(row),
                      onCancel: () => onCancel(row),
                      onView: () => onView(row),
                    ),
                  ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            child: _Pagination(
              meta: meta,
              perPage: perPage,
              visibleCount: items.length,
              itemLabel: _itemLabel,
              onPage: onPage,
            ),
          ),
        ],
      ),
    );
  }

  String get _itemLabel {
    return switch (config.key) {
      'users' => 'pengguna',
      'kendaraan' => 'data',
      'history' => 'riwayat',
      'transactions' => 'transaksi',
      _ => 'data',
    };
  }

  double _widthFor(String key) {
    if (key == 'photo') return 92;
    if (key.contains('email') || key.contains('nama') || key.contains('name')) {
      return 220;
    }
    if (key.contains('created') ||
        key.contains('updated') ||
        key.contains('tanggal')) {
      return 190;
    }
    if (key.contains('no_rangka') ||
        key.contains('no_mesin') ||
        key.contains('nomor')) {
      return 190;
    }
    return 145;
  }

  Widget Function(Map<String, dynamic>)? _cellFor(
      ResourceField field, ValueChanged<Map<String, dynamic>> onHistory) {
    if (config.key == 'kendaraan' && field.key == 'no_polisi') {
      return (row) => TextButton(
            onPressed: () => onHistory(row),
            child: Text(row['no_polisi']?.toString() ?? '-'),
          );
    }
    if (config.key == 'users' && field.key == 'photo') {
      return (row) {
        final photo = row['photo']?.toString();
        final name = row['name']?.toString() ?? '-';
        final initial =
            name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();
        if (photo != null &&
            photo.isNotEmpty &&
            (photo.startsWith('http://') || photo.startsWith('https://'))) {
          return CircleAvatar(
            radius: 18,
            backgroundColor: const Color(0xFFE0E7FF),
            backgroundImage: NetworkImage(photo),
          );
        }
        return CircleAvatar(
          radius: 18,
          backgroundColor: const Color(0xFFE0E7FF),
          child: Text(initial,
              style: const TextStyle(
                  color: Color(0xFF4F46E5), fontWeight: FontWeight.w900)),
        );
      };
    }
    return null;
  }
}

class _Actions extends StatelessWidget {
  const _Actions({
    required this.config,
    required this.item,
    required this.onEdit,
    required this.onDelete,
    required this.onApprove,
    required this.onCancel,
    required this.onView,
  });

  final ResourceConfig config;
  final Map<String, dynamic> item;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onApprove;
  final VoidCallback onCancel;
  final VoidCallback onView;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _TableActionButton(
            onPressed: onView,
            icon: Icons.visibility_outlined,
            tooltip: 'Lihat Data'),
        if (config.canEdit)
          _TableActionButton(
              onPressed: onEdit, icon: Icons.edit_outlined, tooltip: 'Edit'),
        if (config.canDelete)
          _TableActionButton(
              onPressed: onDelete,
              icon: Icons.delete_outline_rounded,
              tooltip: 'Hapus'),
        if (config.key == 'transactions' && item['status'] == 'pending') ...[
          IconButton(
              onPressed: onApprove,
              icon: const Icon(Icons.check_circle_rounded),
              tooltip: 'Approve'),
          IconButton(
              onPressed: onCancel,
              icon: const Icon(Icons.cancel_rounded),
              tooltip: 'Cancel'),
        ],
      ],
    );
  }
}

class _TableActionButton extends StatelessWidget {
  const _TableActionButton({
    required this.onPressed,
    required this.icon,
    required this.tooltip,
  });

  final VoidCallback onPressed;
  final IconData icon;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: Tooltip(
        message: tooltip,
        child: SizedBox(
          width: 40,
          height: 40,
          child: IconButton(
            onPressed: onPressed,
            icon: Icon(icon, size: 18),
            color: Colors.white,
            style: IconButton.styleFrom(
              backgroundColor: const Color(0xFF4F46E5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(11),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ResourceFormPage extends ConsumerStatefulWidget {
  const _ResourceFormPage({
    super.key,
    required this.config,
    this.item,
    this.onCancel,
    required this.onSubmit,
  });

  final ResourceConfig config;
  final Map<String, dynamic>? item;
  final VoidCallback? onCancel;
  final ValueChanged<Map<String, dynamic>> onSubmit;

  @override
  ConsumerState<_ResourceFormPage> createState() => _ResourceFormPageState();
}

class _ResourceFormPageState extends ConsumerState<_ResourceFormPage> {
  late final Map<String, TextEditingController> _controllers;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _controllers = {
      for (final field in widget.config.fields)
        field.key: TextEditingController(
            text: widget.item?[field.key]?.toString() ?? ''),
    };
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.item != null;
    final lookups = ref.watch(adminLookupsProvider).valueOrNull ??
        const <String, dynamic>{};
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
            child: Row(
              children: [
                Icon(
                    editing
                        ? Icons.edit_rounded
                        : Icons.add_circle_outline_rounded,
                    color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    editing
                        ? 'Edit ${widget.config.title}'
                        : 'Tambah ${widget.config.title}',
                    style: const TextStyle(
                        fontWeight: FontWeight.w900, fontSize: 18),
                  ),
                ),
                if (widget.onCancel != null)
                  IconButton(
                      onPressed: widget.onCancel,
                      icon: const Icon(Icons.close_rounded)),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(18),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final twoCols = constraints.maxWidth >= 680;
                  return Wrap(
                    spacing: 14,
                    runSpacing: 14,
                    children: widget.config.fields.map((field) {
                      final wide = field.key.contains('terms') ||
                          field.key.contains('template') ||
                          field.key.contains('disclaimer') ||
                          field.key.contains('alamat');
                      return SizedBox(
                        width: twoCols && !wide
                            ? (constraints.maxWidth - 14) / 2
                            : constraints.maxWidth,
                        child: _fieldWidget(field, wide, lookups),
                      );
                    }).toList(),
                  );
                },
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (widget.onCancel != null)
                  OutlinedButton(
                      onPressed: widget.onCancel, child: const Text('Batal')),
                if (widget.onCancel != null) const SizedBox(width: 10),
                FilledButton.icon(
                  onPressed: () {
                    final data = <String, dynamic>{
                      if (widget.item?['id'] != null) 'id': widget.item!['id'],
                      for (final entry in _controllers.entries)
                        if (entry.value.text.trim().isNotEmpty)
                          entry.key: entry.value.text.trim(),
                    };
                    widget.onSubmit(data);
                  },
                  icon: const Icon(Icons.save_rounded),
                  label: const Text('Simpan'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _fieldWidget(
      ResourceField field, bool wide, Map<String, dynamic> lookups) {
    final controller = _controllers[field.key]!;
    final options = _optionsFor(field.key, lookups, widget.config.key);
    if (options.isNotEmpty) {
      final value = options.any((option) => option.value == controller.text)
          ? controller.text
          : null;
      return _SearchableSelectField(
        label: field.required ? '${field.label} *' : field.label,
        value: value,
        options: options,
        onChanged: (value) => setState(() {
          controller.text = value ?? '';
          if (field.key == 'leasing_id' &&
              _controllers.containsKey('cabang_id')) {
            _controllers['cabang_id']!.clear();
          }
        }),
      );
    }

    return TextField(
      controller: controller,
      obscureText: field.password && _obscurePassword,
      minLines: wide ? 4 : 1,
      maxLines: wide ? 7 : 1,
      decoration: InputDecoration(
        labelText: field.required ? '${field.label} *' : field.label,
        suffixIcon: field.password
            ? IconButton(
                icon: Icon(_obscurePassword ? Icons.visibility_off_rounded : Icons.visibility_rounded),
                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
              )
            : null,
      ),
    );
  }

  List<_SelectOption> _optionsFor(String key, Map<String, dynamic> lookups, String configKey) {
    if (key == 'role') {
      return const [
        _SelectOption('Admin', 'Admin'),
        _SelectOption('Super Admin', 'Super Admin'),
        _SelectOption('Leasing', 'Leasing'),
      ];
    }
    if (key == 'status') {
      if (configKey == 'paket') {
        return const [
          _SelectOption('Aktif', 'Aktif'),
          _SelectOption('Tidak Aktif', 'Tidak Aktif'),
          _SelectOption('Cancel', 'Cancel'),
        ];
      }
      return const [
        _SelectOption('active', 'Aktif'),
        _SelectOption('pending', 'Pending'),
        _SelectOption('blocked', 'Blocked'),
      ];
    }
    if (key == 'leasing_id') {
      return _lookupOptions(lookups['leasings'], 'nama_leasing',
          prefixKey: 'kode_leasing');
    }
    if (key == 'cabang_id') {
      final selectedLeasing = _controllers['leasing_id']?.text;
      final cabangs = (lookups['cabangs'] as List? ?? const []).where((item) {
        if (selectedLeasing == null || selectedLeasing.isEmpty) return true;
        final map = Map<String, dynamic>.from(item as Map);
        return map['leasing_id']?.toString() == selectedLeasing;
      }).toList();
      return _lookupOptions(cabangs, 'nama_cabang', prefixKey: 'kode_cabang');
    }
    if (key == 'company') return _lookupOptions(lookups['perusahaans'], 'name');
    if (key == 'paket_id') {
      return _lookupOptions(lookups['pakets'], 'nama_paket');
    }
    return const [];
  }

  List<_SelectOption> _lookupOptions(dynamic source, String labelKey,
      {String? prefixKey}) {
    final rows = source is List ? source : const [];
    return rows.map((item) {
      final row = Map<String, dynamic>.from(item as Map);
      final prefix = prefixKey == null
          ? ''
          : (row[prefixKey]?.toString().isNotEmpty == true
              ? '${row[prefixKey]} - '
              : '');
      return _SelectOption(
          row['id'].toString(), '$prefix${row[labelKey] ?? '-'}');
    }).toList();
  }
}

class _TableControls extends StatelessWidget {
  const _TableControls({
    required this.config,
    required this.perPage,
    required this.searchController,
    required this.onSearch,
    required this.onPerPageChanged,
  });

  final ResourceConfig config;
  final int perPage;
  final TextEditingController searchController;
  final ValueChanged<String> onSearch;
  final ValueChanged<int> onPerPageChanged;

  static const _perPageOptions = [10, 25, 50, 100];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(18),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 760;
          final countSelect = SizedBox(
            width: 92,
            child: DropdownButtonFormField<int>(
              initialValue: perPage,
              isExpanded: true,
              items: _perPageOptions
                  .map((value) => DropdownMenuItem(
                        value: value,
                        child: Text(value.toString(),
                            style:
                                const TextStyle(fontWeight: FontWeight.w900)),
                      ))
                  .toList(),
              onChanged: (value) {
                if (value != null) onPerPageChanged(value);
              },
              decoration: const InputDecoration(
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              ),
            ),
          );
          final search = config.searchable
              ? SizedBox(
                  width: compact ? constraints.maxWidth : 360,
                  child: TextField(
                    controller: searchController,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search_rounded),
                      hintText: config.key == 'kendaraan'
                          ? 'Cari unit (Nopol/Mesin/Rangka)...'
                          : 'Cari data...',
                    ),
                    onChanged: onSearch,
                  ),
                )
              : const SizedBox.shrink();

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                countSelect,
                if (config.searchable) ...[
                  const SizedBox(height: 12),
                  search,
                ],
              ],
            );
          }

          return Row(
            children: [
              countSelect,
              const Spacer(),
              if (config.searchable) search,
            ],
          );
        },
      ),
    );
  }
}

class _Pagination extends StatelessWidget {
  const _Pagination({
    required this.meta,
    required this.perPage,
    required this.visibleCount,
    required this.itemLabel,
    required this.onPage,
  });

  final Map<String, dynamic> meta;
  final int perPage;
  final int visibleCount;
  final String itemLabel;
  final ValueChanged<int> onPage;

  @override
  Widget build(BuildContext context) {
    final current = int.tryParse(meta['current_page']?.toString() ?? '1') ?? 1;
    final last = int.tryParse(meta['last_page']?.toString() ?? '1') ?? 1;
    final total = int.tryParse(meta['total']?.toString() ?? '0') ?? 0;
    final from = total == 0 ? 0 : ((current - 1) * perPage) + 1;
    final to = total == 0 ? 0 : (from + visibleCount - 1).clamp(from, total);
    final pages = _visiblePages(current, last);

    return LayoutBuilder(
      builder: (context, constraints) {
        final controls = Wrap(
          spacing: 6,
          runSpacing: 8,
          alignment: WrapAlignment.end,
          children: [
            _PageButton(
              label: 'Sebelumnya',
              enabled: current > 1,
              onPressed: () => onPage(current - 1),
            ),
            for (final page in pages)
              _PageButton(
                label: page.toString(),
                active: page == current,
                enabled: page != current,
                square: true,
                onPressed: () => onPage(page),
              ),
            _PageButton(
              label: 'Berikutnya',
              enabled: current < last,
              onPressed: () => onPage(current + 1),
            ),
          ],
        );
        final info = Text(
          'Menampilkan $from - $to dari $total $itemLabel',
          style: const TextStyle(
            color: Color(0xFF94A3B8),
            fontWeight: FontWeight.w900,
            fontSize: 12,
          ),
        );

        if (constraints.maxWidth < 760) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              info,
              const SizedBox(height: 12),
              controls,
            ],
          );
        }

        return Row(
          children: [
            Expanded(child: info),
            controls,
          ],
        );
      },
    );
  }

  List<int> _visiblePages(int current, int last) {
    if (last <= 5) return [for (var page = 1; page <= last; page++) page];
    if (current <= 3) return [1, 2, 3, 4, 5];
    if (current >= last - 2) {
      return [last - 4, last - 3, last - 2, last - 1, last];
    }
    return [current - 2, current - 1, current, current + 1, current + 2];
  }
}

class _PageButton extends StatelessWidget {
  const _PageButton({
    required this.label,
    required this.enabled,
    required this.onPressed,
    this.active = false,
    this.square = false,
  });

  final String label;
  final bool enabled;
  final VoidCallback onPressed;
  final bool active;
  final bool square;

  @override
  Widget build(BuildContext context) {
    final bg = active
        ? const Color(0xFF111827)
        : enabled
            ? Colors.white
            : const Color(0xFFEFF3F8);
    final fg = active
        ? Colors.white
        : enabled
            ? const Color(0xFF111827)
            : const Color(0xFFB8C0CC);
    return SizedBox(
      height: 36,
      width: square ? 38 : null,
      child: TextButton(
        onPressed: enabled ? onPressed : null,
        style: TextButton.styleFrom(
          backgroundColor: bg,
          foregroundColor: fg,
          disabledBackgroundColor: bg,
          disabledForegroundColor: fg,
          padding: EdgeInsets.symmetric(horizontal: square ? 0 : 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
        ),
        child: Text(label,
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
      ),
    );
  }
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFEE2E2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: Color(0xFFDC2626)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Color(0xFF991B1B),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ImportDialog extends ConsumerStatefulWidget {
  const _ImportDialog();

  @override
  ConsumerState<_ImportDialog> createState() => _ImportDialogState();
}

class _ImportDialogState extends ConsumerState<_ImportDialog> {
  String? leasingId;
  String? cabangId;
  String uploadType = 'tambah';
  PlatformFile? file;

  @override
  Widget build(BuildContext context) {
    final lookups = ref.watch(adminLookupsProvider);
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      insetPadding: const EdgeInsets.all(24),
      title: Row(
        children: [
          const Expanded(
            child: Text('Import Data Kendaraan',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
          ),
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close_rounded),
            tooltip: 'Tutup',
          ),
        ],
      ),
      content: SizedBox(
        width: 500,
        child: lookups.when(
          loading: () => const SizedBox(
              height: 180, child: Center(child: CircularProgressIndicator())),
          error: (error, _) => Text(ApiClient.mapError(error).message),
          data: (data) {
            final leasings = (data['leasings'] as List? ?? const [])
                .map((item) => Map<String, dynamic>.from(item as Map))
                .toList();
            final cabangs = (data['cabangs'] as List? ?? const [])
                .map((item) => Map<String, dynamic>.from(item as Map))
                .where((item) =>
                    leasingId != null &&
                    item['leasing_id']?.toString() == leasingId)
                .toList();
            final leasingOptions = leasings.map((item) {
              final kode = item['kode_leasing']?.toString();
              final label =
                  '${kode?.isNotEmpty == true ? '$kode - ' : ''}${item['nama_leasing'] ?? '-'}';
              return _SelectOption(item['id'].toString(), label);
            }).toList();
            final cabangOptions = cabangs.map((item) {
              final kode = item['kode_cabang']?.toString();
              final leasing = item['leasing'] is Map
                  ? Map<String, dynamic>.from(item['leasing'] as Map)
                  : <String, dynamic>{};
              final label =
                  '${kode?.isNotEmpty == true ? '$kode - ' : ''}${item['nama_cabang'] ?? '-'} (${leasing['nama_leasing'] ?? '-'})';
              return _SelectOption(item['id'].toString(), label);
            }).toList();

            final metadata = Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('PARAMETER METADATA',
                    style: TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 12,
                        fontWeight: FontWeight.w900)),
                const SizedBox(height: 12),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final compact = constraints.maxWidth < 460;
                    final leasing = _SearchableSelectField(
                      label: 'Pilih Leasing',
                      showLabel: false,
                      value: leasingId,
                      options: leasingOptions,
                      onChanged: (value) => setState(() {
                        leasingId = value;
                        cabangId = null;
                      }),
                    );
                    final cabang = _SearchableSelectField(
                      label: 'Pilih Cabang',
                      showLabel: false,
                      value: cabangId,
                      options: cabangOptions,
                      onChanged: (value) => setState(() => cabangId = value),
                    );
                    if (compact) {
                      return Column(
                        children: [
                          leasing,
                          const SizedBox(height: 12),
                          cabang,
                        ],
                      );
                    }
                    return Row(
                      children: [
                        Expanded(child: leasing),
                        const SizedBox(width: 16),
                        Expanded(child: cabang),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 12),
                _SearchableSelectField(
                  label: 'Pilih Metode Upload',
                  showLabel: false,
                  value: uploadType,
                  options: const [
                    _SelectOption(
                        'tambah', 'Tambah unit, abaikan nopol yang sudah ada'),
                    _SelectOption(
                        'replace', 'Replace data untuk nopol yang sama'),
                  ],
                  onChanged: (value) =>
                      setState(() => uploadType = value ?? 'tambah'),
                ),
                const SizedBox(height: 24),
                InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: _pickFile,
                  child: Container(
                    width: double.infinity,
                    height: 246,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                          color: const Color(0xFFDDE6F0), width: 1.5),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.cloud_upload_rounded,
                            size: 42, color: Color(0xFF9B8CF5)),
                        const SizedBox(height: 18),
                        FilledButton(
                          onPressed: _pickFile,
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF4F46E5),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 28, vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text('Pilih File Excel',
                              style: TextStyle(fontWeight: FontWeight.w900)),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          file == null
                              ? 'Format standar (.xlsx, .xls, .csv)'
                              : '${file!.name} - ${_formatBytes(file!.size)}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              color: Color(0xFF475569),
                              fontSize: 12,
                              fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
            return metadata;
          },
        ),
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: Row(
            children: [
              TextButton(
                onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Template import belum tersedia')),
                ),
                child: const Text('UNDUH TEMPLATE',
                    style: TextStyle(fontWeight: FontWeight.w900)),
              ),
              const Spacer(),
              FilledButton(
                onPressed:
                    file?.path == null || leasingId == null || cabangId == null
                        ? null
                        : () => Navigator.pop(
                              context,
                              _ImportPayload(
                                filePath: file!.path!,
                                fileName: file!.name,
                                leasingId: leasingId!,
                                cabangId: cabangId!,
                                uploadType: uploadType,
                              ),
                            ),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF4F46E5),
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('MULAI IMPORT',
                    style: TextStyle(fontWeight: FontWeight.w900)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls', 'csv', 'txt']);
    if (result != null && result.files.isNotEmpty) {
      setState(() => file = result.files.first);
    }
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

class _ImportPayload {
  const _ImportPayload({
    required this.filePath,
    required this.fileName,
    required this.leasingId,
    required this.cabangId,
    required this.uploadType,
  });

  final String filePath;
  final String fileName;
  final String leasingId;
  final String cabangId;
  final String uploadType;
}

class _SelectOption {
  const _SelectOption(this.value, this.label);

  final String value;
  final String label;
}

class _SearchableSelectField extends StatelessWidget {
  const _SearchableSelectField({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
    this.showLabel = true,
  });

  final String label;
  final String? value;
  final List<_SelectOption> options;
  final ValueChanged<String?> onChanged;
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    _SelectOption? selected;
    for (final option in options) {
      if (option.value == value) {
        selected = option;
        break;
      }
    }
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () async {
        final result = await showDialog<String>(
          context: context,
          builder: (_) => _SearchableSelectDialog(
            title: label.replaceAll(' *', ''),
            value: value,
            options: options,
          ),
        );
        if (result != null) onChanged(result);
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: showLabel ? label : null,
          hintText: showLabel ? null : label,
          suffixIcon: const Icon(Icons.keyboard_arrow_down_rounded),
        ),
        child: Text(
          selected?.label ??
              'Pilih ${label.replaceAll(' *', '').toLowerCase()}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: selected == null ? const Color(0xFF64748B) : null,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _SearchableSelectDialog extends StatefulWidget {
  const _SearchableSelectDialog({
    required this.title,
    required this.value,
    required this.options,
  });

  final String title;
  final String? value;
  final List<_SelectOption> options;

  @override
  State<_SearchableSelectDialog> createState() =>
      _SearchableSelectDialogState();
}

class _SearchableSelectDialogState extends State<_SearchableSelectDialog> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = widget.options.where((option) {
      final query = _query.toLowerCase();
      return option.label.toLowerCase().contains(query) ||
          option.value.toLowerCase().contains(query);
    }).toList();

    return AlertDialog(
      title: Row(
        children: [
          Expanded(child: Text(widget.title)),
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close_rounded),
            tooltip: 'Tutup',
          ),
        ],
      ),
      content: SizedBox(
        width: 520,
        height: 460,
        child: Column(
          children: [
            TextField(
              controller: _searchController,
              autofocus: true,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search_rounded),
                hintText: 'Cari data...',
              ),
              onChanged: (value) => setState(() => _query = value.trim()),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: filtered.isEmpty
                  ? const EmptyState(title: 'Opsi tidak ditemukan')
                  : ListView.separated(
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 6),
                      itemBuilder: (context, index) {
                        final option = filtered[index];
                        final selected = option.value == widget.value;
                        return ListTile(
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          selected: selected,
                          selectedTileColor: const Color(0xFFE0E7FF),
                          leading: Icon(
                            selected
                                ? Icons.check_circle_rounded
                                : Icons.circle_outlined,
                            color: selected
                                ? const Color(0xFF4F46E5)
                                : const Color(0xFF94A3B8),
                          ),
                          title: Text(option.label,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w800)),
                          onTap: () => Navigator.pop(context, option.value),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ImportProgressDialog extends ConsumerStatefulWidget {
  const _ImportProgressDialog({required this.importId});

  final String importId;

  @override
  ConsumerState<_ImportProgressDialog> createState() =>
      _ImportProgressDialogState();
}

class _ImportProgressDialogState extends ConsumerState<_ImportProgressDialog> {
  Timer? _timer;
  bool _loading = true;
  String? _error;
  Map<String, dynamic> _progress = const {};

  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(const Duration(seconds: 2), (_) => _load());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final percent = _percent;
    final status = _progress['status']?.toString() ??
        (_loading ? 'Memuat progress...' : 'Diproses');
    final processed = _progress['processed'] ??
        _progress['processed_rows'] ??
        _progress['done'] ??
        0;
    final total = _progress['total'] ?? _progress['total_rows'] ?? 0;

    return AlertDialog(
      title: Row(
        children: [
          const Expanded(child: Text('Progress Import')),
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close_rounded),
            tooltip: 'Tutup',
          ),
        ],
      ),
      content: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_error != null)
              Text(_error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error))
            else ...[
              Text(status,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w900)),
              const SizedBox(height: 12),
              LinearProgressIndicator(value: percent / 100),
              const SizedBox(height: 10),
              Text('${percent.toStringAsFixed(0)}% selesai',
                  style: const TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              Text('$processed / $total baris diproses',
                  style: const TextStyle(color: Color(0xFF64748B))),
            ],
          ],
        ),
      ),
      actions: [
        OutlinedButton.icon(
          onPressed: _load,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Refresh'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Tutup'),
        ),
      ],
    );
  }

  double get _percent {
    final raw = _progress['percent'] ??
        _progress['percentage'] ??
        _progress['progress'] ??
        _progress['progress_percent'];
    final direct = double.tryParse(raw?.toString() ?? '');
    if (direct != null) return direct.clamp(0, 100);
    final processed = double.tryParse((_progress['processed'] ??
                _progress['processed_rows'] ??
                _progress['done'] ??
                0)
            .toString()) ??
        0;
    final total = double.tryParse(
            (_progress['total'] ?? _progress['total_rows'] ?? 0).toString()) ??
        0;
    if (total <= 0) return _loading ? 0 : 100;
    return ((processed / total) * 100).clamp(0, 100);
  }

  Future<void> _load() async {
    try {
      final data = await ref
          .read(apiClientProvider)
          .get('/admin/kendaraan/import-progress/${widget.importId}');
      final progress = Map<String, dynamic>.from(data as Map);
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = null;
        _progress = progress;
      });
      final status = progress['status']?.toString().toLowerCase();
      if (status == 'completed' ||
          status == 'complete' ||
          status == 'finished' ||
          status == 'failed' ||
          status == 'error') {
        _timer?.cancel();
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = ApiClient.mapError(error).message;
      });
    }
  }
}

class _ResourceCardGrid extends StatelessWidget {
  const _ResourceCardGrid({
    required this.config,
    required this.items,
    required this.onEdit,
    required this.onDelete,
    required this.onApprove,
    required this.onCancel,
    required this.onView,
  });

  final ResourceConfig config;
  final List<Map<String, dynamic>> items;
  final ValueChanged<Map<String, dynamic>> onEdit;
  final ValueChanged<Map<String, dynamic>> onDelete;
  final ValueChanged<Map<String, dynamic>> onApprove;
  final ValueChanged<Map<String, dynamic>> onCancel;
  final ValueChanged<Map<String, dynamic>> onView;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(18),
      child: Wrap(
        spacing: 16,
        runSpacing: 16,
        children: items.map((item) {
          return SizedBox(
            width: 320,
            child: _ResourceCard(
              config: config,
              item: item,
              onEdit: () => onEdit(item),
              onDelete: () => onDelete(item),
              onApprove: () => onApprove(item),
              onCancel: () => onCancel(item),
              onView: () => onView(item),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _ResourceCard extends StatelessWidget {
  const _ResourceCard({
    required this.config,
    required this.item,
    required this.onEdit,
    required this.onDelete,
    required this.onApprove,
    required this.onCancel,
    required this.onView,
  });

  final ResourceConfig config;
  final Map<String, dynamic> item;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onApprove;
  final VoidCallback onCancel;
  final VoidCallback onView;

  @override
  Widget build(BuildContext context) {
    if (config.columns.isEmpty) return const SizedBox();

    final titleCol = config.columns.first;
    final otherCols = config.columns.skip(1).toList();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5EAF0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              borderRadius: BorderRadius.vertical(top: Radius.circular(15)),
              border: Border(bottom: BorderSide(color: Color(0xFFE5EAF0))),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    readValue(item, titleCol.key),
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                      color: Color(0xFF1E293B),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (item['status'] != null) ...[
                  const SizedBox(width: 8),
                  _StatusBadge(status: item['status'].toString()),
                ],
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              children: otherCols.map((col) {
                if (col.key == 'status') return const SizedBox();

                var valueStr = readValue(item, col.key);
                if (col.key.contains('harga') || col.key.contains('price')) {
                  final numVal = double.tryParse(valueStr);
                  if (numVal != null) {
                    valueStr = 'Rp ${numVal.toStringAsFixed(0)}';
                  }
                }
                if (col.key.contains('hari') || col.key.contains('day')) {
                  valueStr = '$valueStr Hari';
                }

                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 2,
                        child: Text(
                          col.label,
                          style: const TextStyle(
                            color: Color(0xFF64748B),
                            fontSize: 13,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: Text(
                          valueStr,
                          style: const TextStyle(
                            color: Color(0xFF334155),
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                          textAlign: TextAlign.right,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: onView,
                  icon: const Icon(Icons.visibility_outlined, size: 16),
                  label: const Text('Lihat Data'),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF64748B),
                  ),
                ),
                if (config.canEdit)
                  TextButton.icon(
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit_outlined, size: 16),
                    label: const Text('Edit'),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF4F46E5),
                    ),
                  ),
                if (config.canDelete) ...[
                  const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete_outline_rounded, size: 16),
                    label: const Text('Hapus'),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFFEF4444),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});
  final String status;
  @override
  Widget build(BuildContext context) {
    Color bg = const Color(0xFFE2E8F0);
    Color fg = const Color(0xFF475569);
    String text = status.toUpperCase();

    if (status.toLowerCase() == 'active' || status.toLowerCase() == 'aktif') {
      bg = const Color(0xFFDCFCE7);
      fg = const Color(0xFF16A34A);
    } else if (status.toLowerCase() == 'pending') {
      bg = const Color(0xFFFEF9C3);
      fg = const Color(0xFFCA8A04);
    } else if (status.toLowerCase() == 'blocked' ||
        status.toLowerCase() == 'inactive') {
      bg = const Color(0xFFFEE2E2);
      fg = const Color(0xFFDC2626);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: fg,
          fontSize: 10,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.5,
        ),
      ),
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
                        fontWeight: FontWeight.w800, fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SideBox extends StatelessWidget {
  const _SideBox({
    required this.title,
    required this.icon,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5EAF0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              borderRadius: BorderRadius.vertical(top: Radius.circular(15)),
              border: Border(bottom: BorderSide(color: Color(0xFFE5EAF0))),
            ),
            child: Row(
              children: [
                Icon(icon, color: const Color(0xFF4F46E5), size: 20),
                const SizedBox(width: 12),
                Text(title,
                    style: const TextStyle(
                        fontWeight: FontWeight.w900, color: Color(0xFF1E293B))),
              ],
            ),
          ),
          Padding(padding: const EdgeInsets.all(18), child: child),
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
        Icon(icon, color: const Color(0xFF94A3B8), size: 16),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text,
              style: const TextStyle(
                  color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }
}
