import 'language_provider.dart';

class CommonLanguage {
  static const Map<String, Map<String, String>> _translations = {
    'vi': {
      'loading': 'Đang tải...',
      'error': 'Lỗi',
      'success': 'Thành công',
      'cancel': 'Hủy',
      'confirm': 'Xác nhận',
      'ok': 'OK',
      'yes': 'Có',
      'no': 'Không',
      'retry': 'Thử lại',
      'close': 'Đóng',
      'save': 'Lưu',
      'delete': 'Xóa',
      'edit': 'Sửa',
      'search': 'Tìm kiếm',
      'no_data': 'Không có dữ liệu',
      'network_error': 'Lỗi kết nối mạng',
      'server_error': 'Lỗi máy chủ',
      'unknown_error': 'Lỗi không xác định',
    },
    'en': {
      'loading': 'Loading...',
      'error': 'Error',
      'success': 'Success',
      'cancel': 'Cancel',
      'confirm': 'Confirm',
      'ok': 'OK',
      'yes': 'Yes',
      'no': 'No',
      'retry': 'Retry',
      'close': 'Close',
      'save': 'Save',
      'delete': 'Delete',
      'edit': 'Edit',
      'search': 'Search',
      'no_data': 'No data',
      'network_error': 'Network error',
      'server_error': 'Server error',
      'unknown_error': 'Unknown error',
    },
  };

  static String get(String key, AppLanguage language) {
    final langCode = language == AppLanguage.vi ? 'vi' : 'en';
    return _translations[langCode]?[key] ?? key;
  }
}
