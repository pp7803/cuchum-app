import 'language_provider.dart';

class ProfileLanguage {
  static const Map<String, Map<String, String>> _translations = {
    'vi': {
      'profile': 'Hồ sơ',
      'my_profile': 'Hồ sơ của tôi',
      'edit_profile': 'Chỉnh sửa hồ sơ',
      'save_changes': 'Lưu thay đổi',
      'cancel': 'Hủy',

      // Account info
      'account_info': 'Thông tin tài khoản',
      'full_name': 'Họ và tên',
      'phone_number': 'Số điện thoại',
      'email': 'Email',
      'role': 'Vai trò',
      'status': 'Trạng thái',
      'member_since': 'Thành viên từ',
      'status_active': 'Hoạt động',
      'status_inactive': 'Đã khóa',

      // Driver info
      'driver_info': 'Thông tin tài xế',
      'citizen_id': 'CMND / CCCD',
      'license_class': 'Hạng bằng lái',
      'license_number': 'Số bằng lái (GPLX)',
      'address': 'Địa chỉ',
      'not_updated': 'Chưa cập nhật',

      // Settings
      'settings': 'Cài đặt',
      'appearance': 'Giao diện',
      'dark_mode': 'Chế độ tối',
      'language': 'Ngôn ngữ',
      'change_password': 'Đổi mật khẩu',
      'logout': 'Đăng xuất',
      'logout_confirm': 'Bạn có chắc muốn đăng xuất?',
      'logout_confirm_yes': 'Đăng xuất',

      // Change password
      'current_password': 'Mật khẩu hiện tại',
      'new_password': 'Mật khẩu mới',
      'confirm_password': 'Xác nhận mật khẩu mới',
      'password_hint': 'Tối thiểu 6 ký tự',
      'passwords_not_match': 'Mật khẩu không khớp',
      'field_required': 'Vui lòng điền trường này',
      'password_changed': 'Đổi mật khẩu thành công',
      'profile_updated': 'Cập nhật hồ sơ thành công',

      // Placeholders
      'citizen_id_invalid': 'CMND/CCCD phải có đúng 12 chữ số',
      'enter_citizen_id': 'Nhập số CMND/CCCD (12 chữ số)',
      'enter_license_class': 'Ví dụ: B2, C, D',
      'enter_license_number': 'Số in trên bằng lái',
      'enter_address': 'Nhập địa chỉ thường trú',
      'take_photo': 'Chụp ảnh',
      'pick_from_gallery': 'Chọn từ thư viện',

      // Proof (profile update)
      'proof_optional': 'Minh chứng cập nhật (tuỳ chọn)',
      'proof_hint': 'Ảnh hoặc PDF minh chứng cho thông tin thay đổi',
      'proof_pick': 'Chọn tệp',
      'proof_remove': 'Gỡ',
      'proof_selected': 'Đã chọn',
      'pending_proof': 'Minh chứng',

      // Pending request
      'pending_request': 'Đang chờ duyệt',
      'pending_request_submitted':
          'Yêu cầu cập nhật đã được gửi, đang chờ Admin duyệt.',
      'pending_citizen_id': 'CMND/CCCD mới',
      'pending_license_class': 'Hạng bằng mới',
      'pending_license_number': 'Số bằng mới',
      'pending_address': 'Địa chỉ mới',
      'pending_rejected': 'Yêu cầu bị từ chối',
      'pending_rejected_reason': 'Lý do',
      'pending_cancel': 'Hủy yêu cầu',

      // Section headers
      'section_profile': 'HỒ SƠ',
      'section_settings': 'CÀI ĐẶT',
      'section_security': 'BẢO MẬT',
      'section_appearance': 'GIAO DIỆN',

      // Biometric
      'biometric_auth': 'Đăng nhập sinh trắc học',
      'biometric_subtitle': 'Sử dụng vân tay / Face ID để đăng nhập',
      'biometric_enable_confirm':
          'Xác thực sinh trắc học để kích hoạt tính năng này',
      'biometric_disable_confirm':
          'Xác thực sinh trắc học để tắt tính năng này',
      'biometric_enabled': 'Đăng nhập sinh trắc học đã được bật',
      'biometric_disabled': 'Đăng nhập sinh trắc học đã được tắt',
      'biometric_not_available': 'Thiết bị không hỗ trợ sinh trắc học',
      'biometric_not_enrolled':
          'Chưa đăng ký Face ID / vân tay trên thiết bị. Hãy thêm trong Cài đặt hệ thống rồi thử lại.',
      'biometric_auth_failed': 'Xác thực sinh trắc học thất bại',
    },
    'en': {
      'profile': 'Profile',
      'my_profile': 'My Profile',
      'edit_profile': 'Edit Profile',
      'save_changes': 'Save Changes',
      'cancel': 'Cancel',

      'account_info': 'Account Information',
      'full_name': 'Full Name',
      'phone_number': 'Phone Number',
      'email': 'Email',
      'role': 'Role',
      'status': 'Status',
      'member_since': 'Member since',
      'status_active': 'Active',
      'status_inactive': 'Inactive',

      'driver_info': 'Driver Information',
      'citizen_id': 'ID / Passport',
      'license_class': 'License Class',
      'license_number': 'License number (ID)',
      'address': 'Address',
      'not_updated': 'Not updated',

      'settings': 'Settings',
      'appearance': 'Appearance',
      'dark_mode': 'Dark Mode',
      'language': 'Language',
      'change_password': 'Change Password',
      'logout': 'Logout',
      'logout_confirm': 'Are you sure you want to logout?',
      'logout_confirm_yes': 'Logout',

      'current_password': 'Current Password',
      'new_password': 'New Password',
      'confirm_password': 'Confirm New Password',
      'password_hint': 'At least 6 characters',
      'passwords_not_match': 'Passwords do not match',
      'field_required': 'This field is required',
      'password_changed': 'Password changed successfully',
      'profile_updated': 'Profile updated successfully',

      'citizen_id_invalid': 'ID must be exactly 12 digits',
      'enter_citizen_id': 'Enter 12-digit ID number',
      'enter_license_class': 'e.g. B2, C, D',
      'enter_license_number': 'Number printed on license',
      'enter_address': 'Enter your address',
      'take_photo': 'Take photo',
      'pick_from_gallery': 'Choose from library',

      // Proof (profile update)
      'proof_optional': 'Supporting document (optional)',
      'proof_hint': 'Image or PDF as proof for your changes',
      'proof_pick': 'Choose file',
      'proof_remove': 'Remove',
      'proof_selected': 'Selected',
      'pending_proof': 'Proof',

      // Pending request
      'pending_request': 'Pending approval',
      'pending_request_submitted':
          'Your update request has been submitted and is awaiting admin review.',
      'pending_citizen_id': 'New ID number',
      'pending_license_class': 'New license class',
      'pending_license_number': 'New license number',
      'pending_address': 'New address',
      'pending_rejected': 'Request rejected',
      'pending_rejected_reason': 'Reason',
      'pending_cancel': 'Cancel request',

      // Section headers
      'section_profile': 'PROFILE',
      'section_settings': 'SETTINGS',
      'section_security': 'SECURITY',
      'section_appearance': 'APPEARANCE',

      // Biometric
      'biometric_auth': 'Biometric Login',
      'biometric_subtitle': 'Use fingerprint / Face ID to sign in',
      'biometric_enable_confirm': 'Authenticate to enable this feature',
      'biometric_disable_confirm': 'Authenticate to disable this feature',
      'biometric_enabled': 'Biometric login enabled',
      'biometric_disabled': 'Biometric login disabled',
      'biometric_not_available': 'Biometric not available on this device',
      'biometric_not_enrolled':
          'No Face ID / fingerprint enrolled. Add one in system Settings, then try again.',
      'biometric_auth_failed': 'Biometric authentication failed',
    },
  };

  static String get(String key, AppLanguage language) {
    final langCode = language == AppLanguage.vi ? 'vi' : 'en';
    return _translations[langCode]?[key] ?? key;
  }
}
