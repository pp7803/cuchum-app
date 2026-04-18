import 'language_provider.dart';

/// Human-readable trip status (API still uses enums like SCHEDULED_PENDING).
class TripStatusLanguage {
  static const Map<String, Map<String, String>> _t = {
    'vi': {
      'SCHEDULED_PENDING': 'Chờ xác nhận',
      'DRIVER_ACCEPTED': 'Đã nhận lịch',
      'DRIVER_DECLINED': 'Đã từ chối',
      'IN_PROGRESS': 'Đang chạy',
      'ONGOING': 'Đang chạy',
      'COMPLETED': 'Hoàn thành',
      'CANCELLED': 'Đã hủy',
    },
    'en': {
      'SCHEDULED_PENDING': 'Awaiting confirmation',
      'DRIVER_ACCEPTED': 'Accepted',
      'DRIVER_DECLINED': 'Declined',
      'IN_PROGRESS': 'In progress',
      'ONGOING': 'In progress',
      'COMPLETED': 'Completed',
      'CANCELLED': 'Cancelled',
    },
  };

  static String label(String status, AppLanguage lang) {
    final code = lang == AppLanguage.vi ? 'vi' : 'en';
    final key = status.trim().toUpperCase();
    return _t[code]?[key] ?? _t['en']?[key] ?? status;
  }
}
