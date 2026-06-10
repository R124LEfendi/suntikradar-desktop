String readValue(Map<String, dynamic> item, String path) {
  dynamic value = item;
  for (final part in path.split('.')) {
    if (value is Map && value[part] != null) {
      value = value[part];
    } else {
      return '-';
    }
  }
  if (path.contains('created_at') ||
      path.contains('updated_at') ||
      path.contains('tanggal')) {
    final date = DateTime.tryParse(value?.toString() ?? '');
    if (date != null) {
      final local = date.toLocal();
      String two(int number) => number.toString().padLeft(2, '0');
      return '${two(local.day)}/${two(local.month)}/${local.year} ${two(local.hour)}:${two(local.minute)}';
    }
  }
  return value?.toString() ?? '-';
}
