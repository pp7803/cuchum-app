import 'language_provider.dart';

class LoginLanguage {
  static const Map<String, Map<String, String>> _translations = {
    'vi': {
      'app_name': 'CUCHUM',
      'welcome_title': 'Chào mừng trở lại.',
      'welcome_subtitle': 'Đăng nhập để tiếp tục',
      'identifier_label': 'SỐ ĐIỆN THOẠI / EMAIL',
      'identifier_hint': 'Nhập thông tin của bạn',
      'password_label': 'MẬT KHẨU',
      'password_hint': 'Nhập mật khẩu',
      'forgot_password': 'Quên mật khẩu?',
      'login_button': 'Đăng nhập',
      'login_success': 'Đăng nhập thành công',
      'login_failed': 'Đăng nhập thất bại',
      'field_required': 'Vui lòng nhập trường này',
      'invalid_credentials': 'Thông tin đăng nhập không chính xác',
      'saved_greeting': 'Xin chào,',
      'saved_hint': 'Đăng nhập với tài khoản đã lưu',
      'switch_account': 'Đăng xuất',
      'switch_account_confirm': 'Xác nhận đăng xuất?',
      'switch_account_body': 'Bạn có chắc muốn đăng xuất không?',
      'switch_account_yes': 'Đăng xuất',
    },
    'en': {
      'app_name': 'CUCHUM',
      'welcome_title': 'Welcome back.',
      'welcome_subtitle': 'Sign in to continue',
      'identifier_label': 'PHONE NUMBER / EMAIL',
      'identifier_hint': 'Enter your information',
      'password_label': 'PASSWORD',
      'password_hint': 'Enter your password',
      'forgot_password': 'Forgot password?',
      'login_button': 'Sign in',
      'login_success': 'Login successful',
      'login_failed': 'Login failed',
      'field_required': 'Please fill in this field',
      'invalid_credentials': 'Invalid credentials',
      'saved_greeting': 'Hello,',
      'saved_hint': 'Sign in with your saved account',
      'switch_account': 'Sign out',
      'switch_account_confirm': 'Confirm sign out?',
      'switch_account_body': 'Are you sure you want to sign out?',
      'switch_account_yes': 'Sign out',
    },
  };

  static String get(String key, AppLanguage language) {
    final langCode = language == AppLanguage.vi ? 'vi' : 'en';
    return _translations[langCode]?[key] ?? key;
  }
}
