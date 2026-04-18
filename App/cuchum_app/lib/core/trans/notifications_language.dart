import 'language_provider.dart';

class NotificationsLanguage {
  static const Map<String, Map<String, String>> _t = {
    'vi': {
      'title': 'Thông báo',
      'admin_title': 'Thông báo Quản trị',
      'empty': 'Không có thông báo',
      'empty_admin': 'Không có thông báo quản trị',
      'mark_all': 'Đọc tất cả',
      'just_now': 'Vừa xong',
      'new_notification': 'Thông báo mới',
      'unread_prompt_title': 'Bạn có thông báo mới',
      'unread_prompt_subtitle': 'thông báo chưa đọc',
      'unread_prompt_view': 'Xem ngay',
      'unread_prompt_later': 'Để sau',
      'connected': 'Đã kết nối thông báo real-time',
    },
    'en': {
      'title': 'Notifications',
      'admin_title': 'Admin Notifications',
      'empty': 'No notifications',
      'empty_admin': 'No admin notifications',
      'mark_all': 'Mark all read',
      'just_now': 'Just now',
      'new_notification': 'New Notification',
      'unread_prompt_title': 'You have new notifications',
      'unread_prompt_subtitle': 'unread',
      'unread_prompt_view': 'View now',
      'unread_prompt_later': 'Later',
      'connected': 'Real-time notifications connected',
    },
  };

  static String get(String key, AppLanguage lang) {
    final code = lang == AppLanguage.vi ? 'vi' : 'en';
    return _t[code]?[key] ?? key;
  }

  /// Human-readable relative time
  static String relativeTime(String iso, AppLanguage lang) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      final diff = DateTime.now().difference(dt);
      if (lang == AppLanguage.vi) {
        if (diff.inSeconds < 60) return 'Vừa xong';
        if (diff.inMinutes < 60) return '${diff.inMinutes} phút trước';
        if (diff.inHours < 24) return '${diff.inHours} giờ trước';
        if (diff.inDays < 7) return '${diff.inDays} ngày trước';
        return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
      } else {
        if (diff.inSeconds < 60) return 'Just now';
        if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
        if (diff.inHours < 24) return '${diff.inHours}h ago';
        if (diff.inDays < 7) return '${diff.inDays}d ago';
        return '${dt.month}/${dt.day}/${dt.year}';
      }
    } catch (_) {
      return '';
    }
  }
}
