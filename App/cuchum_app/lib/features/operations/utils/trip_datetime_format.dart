/// Hiển thị thời gian chuyến / xăng: `YYYY-MM-DD HH:MM` (giờ local).
String formatTripLocalDateTime(String? iso) {
  if (iso == null || iso.isEmpty) return '—';
  try {
    final d = DateTime.parse(iso).toLocal();
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    final h = d.hour.toString().padLeft(2, '0');
    final min = d.minute.toString().padLeft(2, '0');
    return '$y-$m-$day $h:$min';
  } catch (_) {
    return iso;
  }
}

/// Từ [DateTime] (bất kỳ timezone) → `YYYY-MM-DD HH:MM` local.
String formatLocalDateTime(DateTime d) {
  final l = d.toLocal();
  final y = l.year.toString().padLeft(4, '0');
  final m = l.month.toString().padLeft(2, '0');
  final day = l.day.toString().padLeft(2, '0');
  final h = l.hour.toString().padLeft(2, '0');
  final min = l.minute.toString().padLeft(2, '0');
  return '$y-$m-$day $h:$min';
}
