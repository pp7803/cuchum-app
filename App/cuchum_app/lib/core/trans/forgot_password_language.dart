import 'language_provider.dart';

class ForgotPasswordLanguage {
  static const Map<String, Map<String, String>> _translations = {
    'vi': {
      'app_name': 'CUCHUM',
      'forgot_password_title': 'Quên mật khẩu?',
      'forgot_password_subtitle': 'Nhập email để nhận mã OTP',
      'email_label': 'EMAIL',
      'email_hint': 'Nhập địa chỉ email của bạn',
      'send_otp_button': 'Gửi mã OTP',
      'back_to_login': 'Quay lại đăng nhập',
      'otp_sent': 'Mã OTP đã được gửi đến email',
      'field_required': 'Vui lòng nhập trường này',
      'invalid_email': 'Email không hợp lệ',

      'reset_password_title': 'Đặt lại mật khẩu',
      'reset_password_subtitle': 'Nhập mã OTP và mật khẩu mới',
      'otp_label': 'MÃ OTP',
      'otp_hint': 'Nhập mã OTP 6 số',
      'new_password_label': 'MẬT KHẨU MỚI',
      'new_password_hint': 'Nhập mật khẩu mới',
      'confirm_password_label': 'XÁC NHẬN MẬT KHẨU',
      'confirm_password_hint': 'Nhập lại mật khẩu mới',
      'reset_button': 'Đặt lại mật khẩu',
      'resend_otp': 'Gửi lại mã OTP',
      'password_min_length': 'Mật khẩu tối thiểu 6 ký tự',
      'password_mismatch': 'Mật khẩu không khớp',
      'invalid_otp': 'Mã OTP phải là 6 số',
      'reset_success': 'Đặt lại mật khẩu thành công',
    },
    'en': {
      'app_name': 'CUCHUM',
      'forgot_password_title': 'Forgot password?',
      'forgot_password_subtitle': 'Enter your email to receive OTP',
      'email_label': 'EMAIL',
      'email_hint': 'Enter your email address',
      'send_otp_button': 'Send OTP',
      'back_to_login': 'Back to login',
      'otp_sent': 'OTP has been sent to your email',
      'field_required': 'Please fill in this field',
      'invalid_email': 'Invalid email address',

      'reset_password_title': 'Reset password',
      'reset_password_subtitle': 'Enter OTP and new password',
      'otp_label': 'OTP CODE',
      'otp_hint': 'Enter 6-digit OTP',
      'new_password_label': 'NEW PASSWORD',
      'new_password_hint': 'Enter new password',
      'confirm_password_label': 'CONFIRM PASSWORD',
      'confirm_password_hint': 'Re-enter new password',
      'reset_button': 'Reset password',
      'resend_otp': 'Resend OTP',
      'password_min_length': 'Password must be at least 6 characters',
      'password_mismatch': 'Passwords do not match',
      'invalid_otp': 'OTP must be 6 digits',
      'reset_success': 'Password reset successfully',
    },
  };

  static String get(String key, AppLanguage language) {
    final langCode = language == AppLanguage.vi ? 'vi' : 'en';
    return _translations[langCode]?[key] ?? key;
  }
}
