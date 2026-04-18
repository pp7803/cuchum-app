import 'language_provider.dart';

class FuelPricesLanguage {
  static const Map<String, Map<String, String>> _t = {
    'vi': {
      'title': 'Giá xăng dầu',
      'updated_at': 'Cập nhật',
      'zone1': 'Vùng 1',
      'zone2': 'Vùng 2',
      'loading': 'Đang tải giá...',
      'error': 'Không thể tải giá xăng dầu',
      'retry': 'Thử lại',
      'unit': 'đ/lít',
      'source': 'Nguồn',
      'both_zones': '{{z1}} / {{z2}}',
      'diesel': 'Dầu',
      'petrol': 'Xăng',
    },
    'en': {
      'title': 'Fuel Prices',
      'updated_at': 'Updated',
      'zone1': 'Zone 1',
      'zone2': 'Zone 2',
      'loading': 'Loading prices...',
      'error': 'Unable to load fuel prices',
      'retry': 'Retry',
      'unit': 'VND/L',
      'source': 'Source',
      'both_zones': '{{z1}} / {{z2}}',
      'diesel': 'Diesel',
      'petrol': 'Petrol',
    },
  };

  static String get(String key, AppLanguage lang) {
    final code = lang == AppLanguage.vi ? 'vi' : 'en';
    return _t[code]?[key] ?? key;
  }
}
