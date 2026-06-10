class ResourceField {
  const ResourceField(this.key, this.label,
      {this.required = false, this.password = false});

  final String key;
  final String label;
  final bool required;
  final bool password;
}

class ResourceConfig {
  const ResourceConfig({
    required this.key,
    required this.title,
    required this.path,
    required this.columns,
    this.fields = const [],
    this.searchable = true,
    this.canCreate = true,
    this.canDelete = true,
    this.canEdit = true,
  });

  final String key;
  final String title;
  final String path;
  final List<ResourceField> columns;
  final List<ResourceField> fields;
  final bool searchable;
  final bool canCreate;
  final bool canDelete;
  final bool canEdit;
}

const resourceConfigs = <String, ResourceConfig>{
  'kendaraan': ResourceConfig(
    key: 'kendaraan',
    title: 'Data Kendaraan',
    path: '/admin/kendaraan',
    columns: [
      ResourceField('no_polisi', 'No. Polisi'),
      ResourceField('type_motor', 'Tipe Unit'),
      ResourceField('no_mesin', 'No. Mesin'),
      ResourceField('no_rangka', 'No. Rangka'),
      ResourceField('ovd', 'OVD'),
      ResourceField('nomor_kontrak', 'Nomor Kontrak'),
      ResourceField('cabang.nama_cabang', 'Cabang'),
      ResourceField('leasing.nama_leasing', 'Leasing'),
      ResourceField('updated_at', 'Updated Date'),
    ],
    fields: [
      ResourceField('no_polisi', 'No Polisi', required: true),
      ResourceField('type_motor', 'Jenis Kendaraan', required: true),
      ResourceField('no_mesin', 'No Mesin', required: true),
      ResourceField('no_rangka', 'No Rangka', required: true),
      ResourceField('nama_stnk', 'Nama STNK'),
      ResourceField('email_notif', 'Email Notif'),
      ResourceField('leasing_id', 'ID Leasing'),
      ResourceField('cabang_id', 'ID Cabang', required: true),
      ResourceField('ovd', 'OVD'),
      ResourceField('nomor_kontrak', 'Nomor Kontrak'),
    ],
  ),
  'perusahaan': ResourceConfig(
    key: 'perusahaan',
    title: 'Data Perusahaan',
    path: '/admin/perusahaan',
    columns: [
      ResourceField('name', 'Nama'),
      ResourceField('phone', 'Telepon'),
      ResourceField('address', 'Alamat'),
    ],
    fields: [
      ResourceField('name', 'Nama', required: true),
      ResourceField('phone', 'Telepon'),
      ResourceField('address', 'Alamat'),
    ],
  ),
  'users': ResourceConfig(
    key: 'users',
    title: 'Data User',
    path: '/admin/users',
    columns: [
      ResourceField('photo', 'Foto'),
      ResourceField('name', 'Nama'),
      ResourceField('email', 'Email'),
      ResourceField('phone', 'Telepon'),
      ResourceField('role', 'Role'),
      ResourceField('status', 'Status'),
      ResourceField('perusahaan.name', 'Perusahaan'),
    ],
    fields: [
      ResourceField('name', 'Nama', required: true),
      ResourceField('email', 'Email', required: true),
      ResourceField('phone', 'Telepon'),
      ResourceField('role', 'Role', required: true),
      ResourceField('status', 'Status'),
      ResourceField('company', 'ID Perusahaan'),
      ResourceField('nik', 'NIK'),
      ResourceField('alamat', 'Alamat'),
      ResourceField('domisili', 'Domisili'),
      ResourceField('password', 'Password', password: true),
    ],
  ),
  'paket': ResourceConfig(
    key: 'paket',
    title: 'Data Paket',
    path: '/admin/paket',
    columns: [
      ResourceField('nama_paket', 'Nama Paket'),
      ResourceField('jumlah_hari', 'Durasi Hari'),
      ResourceField('harga_total', 'Harga'),
      ResourceField('status', 'Status'),
    ],
    fields: [
      ResourceField('nama_paket', 'Nama Paket', required: true),
      ResourceField('jumlah_hari', 'Durasi Hari', required: true),
      ResourceField('harga_total', 'Harga', required: true),
      ResourceField('status', 'Status'),
    ],
  ),
  'leasing': ResourceConfig(
    key: 'leasing',
    title: 'Data Leasing',
    path: '/admin/leasing',
    columns: [
      ResourceField('kode_leasing', 'Kode'),
      ResourceField('nama_leasing', 'Nama Leasing'),
      ResourceField('cabangs_count', 'Cabang'),
    ],
    fields: [
      ResourceField('kode_leasing', 'Kode Leasing', required: true),
      ResourceField('nama_leasing', 'Nama Leasing', required: true),
    ],
  ),
  'cabang': ResourceConfig(
    key: 'cabang',
    title: 'Data Cabang',
    path: '/admin/cabang',
    columns: [
      ResourceField('kode_cabang', 'Kode'),
      ResourceField('nama_cabang', 'Nama Cabang'),
      ResourceField('leasing.nama_leasing', 'Leasing'),
    ],
    fields: [
      ResourceField('leasing_id', 'ID Leasing', required: true),
      ResourceField('kode_cabang', 'Kode Cabang', required: true),
      ResourceField('nama_cabang', 'Nama Cabang', required: true),
    ],
  ),
  'narasumber': ResourceConfig(
    key: 'narasumber',
    title: 'Data Narasumber',
    path: '/admin/narasumber',
    columns: [
      ResourceField('name', 'Nama'),
      ResourceField('phone', 'Telepon'),
      ResourceField('email', 'Email'),
      ResourceField('telegram_id', 'Telegram'),
    ],
    fields: [
      ResourceField('name', 'Nama', required: true),
      ResourceField('phone', 'Telepon', required: true),
      ResourceField('email', 'Email', required: true),
      ResourceField('telegram_id', 'Telegram ID'),
    ],
  ),
  'history': ResourceConfig(
    key: 'history',
    title: 'Riwayat Pencarian',
    path: '/admin/history-log',
    columns: [
      ResourceField('query', 'Query'),
      ResourceField('user.name', 'User'),
      ResourceField('results_count', 'Hasil'),
      ResourceField('source', 'Source'),
      ResourceField('channel', 'Channel'),
      ResourceField('created_at', 'Waktu'),
    ],
    canCreate: false,
    canEdit: false,
    canDelete: false,
  ),
  'transactions': ResourceConfig(
    key: 'transactions',
    title: 'Transaksi Paket',
    path: '/admin/transactions',
    columns: [
      ResourceField('invoice', 'Invoice'),
      ResourceField('user.name', 'User'),
      ResourceField('nama_paket', 'Paket'),
      ResourceField('harga', 'Harga'),
      ResourceField('status', 'Status'),
      ResourceField('tanggal_expired', 'Expired'),
    ],
    canCreate: false,
    canEdit: false,
    canDelete: false,
  ),
  'settings': ResourceConfig(
    key: 'settings',
    title: 'Setting Aplikasi',
    path: '/admin/website-settings',
    columns: [
      ResourceField('app_name', 'App Name'),
      ResourceField('app_title', 'Title'),
      ResourceField('login_start', 'Login Mulai'),
      ResourceField('login_end', 'Login Selesai'),
      ResourceField('footer_text', 'Footer'),
    ],
    fields: [
      ResourceField('app_name', 'App Name'),
      ResourceField('app_title', 'Title'),
      ResourceField('login_start', 'Login Mulai'),
      ResourceField('login_end', 'Login Selesai'),
      ResourceField('disclaimer', 'Disclaimer'),
      ResourceField('terms_conditions', 'Terms'),
      ResourceField('whatsapp_share_template', 'Template WhatsApp'),
      ResourceField('footer_text', 'Footer'),
    ],
    searchable: false,
    canCreate: false,
    canDelete: false,
  ),
};
