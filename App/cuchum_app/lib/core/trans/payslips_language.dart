import 'language_provider.dart';

class PayslipsLanguage {
  static const Map<String, Map<String, String>> _t = {
    'vi': {
      'title': 'Bảng lương',
      'month_filter': 'Tháng',
      'all_months': 'Tất cả',
      'empty': 'Chưa có bảng lương',
      'view_pdf': 'Xem PDF',
      'status_pending': 'Chờ xem',
      'status_viewed': 'Đã xem',
      'status_confirmed': 'Đã xác nhận',
      'status_complained': 'Khiếu nại',
      'confirm': 'Xác nhận đúng',
      'complain': 'Khiếu nại',
      'complain_hint': 'Mô tả vấn đề (bắt buộc)',
      'complain_send': 'Gửi khiếu nại',
      'select_driver': 'Tài xế',
      'tap_to_select_driver': 'Chạm để chọn tài xế',
      'search_driver': 'Tìm theo tên hoặc SĐT',
      'no_drivers': 'Không có tài xế',
      'salary_month': 'Kỳ lương (YYYY-MM)',
      'pick_pdf': 'Chọn file PDF',
      'create': 'Tạo bảng lương',
      'created': 'Đã tạo bảng lương',
      'load_error': 'Không tải được danh sách',
      'driver_short': 'Tài xế',
      'fill_driver_pdf': 'Chọn tài xế và file PDF',
      'admin_pick_driver': 'Chọn tài xế',
      'admin_pick_driver_sub': 'Chạm vào tài xế để xem bảng lương và phân trang.',
      'admin_back_drivers': 'Tài xế',
      'admin_driver_payslips': 'Bảng lương',
    },
    'en': {
      'title': 'Payslips',
      'month_filter': 'Month',
      'all_months': 'All',
      'empty': 'No payslips yet',
      'view_pdf': 'View PDF',
      'status_pending': 'Pending',
      'status_viewed': 'Viewed',
      'status_confirmed': 'Confirmed',
      'status_complained': 'Complaint',
      'confirm': 'Confirm OK',
      'complain': 'Dispute',
      'complain_hint': 'Describe the issue (required)',
      'complain_send': 'Submit dispute',
      'select_driver': 'Driver',
      'tap_to_select_driver': 'Tap to select driver',
      'search_driver': 'Search by name or phone',
      'no_drivers': 'No drivers found',
      'salary_month': 'Salary month (YYYY-MM)',
      'pick_pdf': 'Pick PDF file',
      'create': 'Create payslip',
      'created': 'Payslip created',
      'load_error': 'Failed to load list',
      'driver_short': 'Driver',
      'fill_driver_pdf': 'Select a driver and PDF file',
      'admin_pick_driver': 'Select driver',
      'admin_pick_driver_sub': 'Tap a driver to view payslips with pagination.',
      'admin_back_drivers': 'Drivers',
      'admin_driver_payslips': 'Payslips',
    },
  };

  static String get(String key, AppLanguage lang) {
    final code = lang == AppLanguage.vi ? 'vi' : 'en';
    return _t[code]?[key] ?? key;
  }

  static String statusLabel(String status, AppLanguage lang) {
    switch (status.toUpperCase()) {
      case 'VIEWED':
        return get('status_viewed', lang);
      case 'CONFIRMED':
        return get('status_confirmed', lang);
      case 'COMPLAINED':
        return get('status_complained', lang);
      default:
        return get('status_pending', lang);
    }
  }
}
