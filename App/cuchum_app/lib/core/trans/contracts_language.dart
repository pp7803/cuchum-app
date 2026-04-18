import 'language_provider.dart';

class ContractsLanguage {
  static const Map<String, Map<String, String>> _t = {
    'vi': {
      'title': 'Hợp đồng lao động',
      'tab_short': 'Hợp đồng',
      'my_contracts': 'Hợp đồng của tôi',
      'empty': 'Chưa có hợp đồng nào',
      'status_active': 'Còn hiệu lực',
      'status_expired': 'Hết hạn',
      'status_no_end': 'Không thời hạn',
      'contract_number': 'Số hợp đồng',
      'start_date': 'Ngày bắt đầu',
      'end_date': 'Ngày kết thúc',
      'no_end_date': 'Không xác định',
      'open_pdf': 'Xem hợp đồng',
      'open_pdf_error': 'Không thể mở file',
      'create': 'Tạo hợp đồng',
      'create_title': 'Tạo hợp đồng mới',
      'driver': 'Tài xế',
      'select_driver': 'Chọn tài xế...',
      'contract_number_hint': 'Ví dụ: HD2026001',
      'start_date_hint': 'Chọn ngày bắt đầu',
      'end_date_hint': 'Chọn ngày kết thúc (tùy chọn)',
      'upload_pdf': 'Chọn file PDF',
      'uploading': 'Đang tải file...',
      'file_selected': 'Đã chọn',
      'field_required': 'Vui lòng điền trường này',
      'file_required': 'Vui lòng chọn file hợp đồng',
      'created_success': 'Đã tạo hợp đồng thành công',
      'cancel': 'Hủy',
      'confirm': 'Tạo hợp đồng',
      'created_at': 'Ngày tạo',
      'admin_board_title': 'Bảng hợp đồng',
      'admin_board_subtitle':
          'Mỗi tài xế có danh sách hợp đồng riêng và thanh phân trang ngay bên dưới.',
      'admin_board_empty': 'Không có tài xế hoạt động.',
      'admin_full_manager': 'Quản lý đầy đủ / tạo mới',
      'admin_contracts_loading': 'Đang tải hợp đồng…',
      'admin_contracts_none': 'Chưa có hợp đồng',
      'admin_menu_contracts': 'Bảng hợp đồng',
      'admin_tools': 'Phản hồi pháp lý (lọc)',
      'filter_all': 'Tất cả',
      'filter_pending': 'Chờ phản hồi',
      'filter_ack': 'Đã xác nhận',
      'filter_declined': 'Không xác nhận',
      'ack_section': 'Trạng thái pháp lý',
      'ack_pending': 'Chờ xác nhận',
      'ack_yes': 'Đã xác nhận',
      'ack_no': 'Không xác nhận',
      'viewed_badge': 'Đã xem PDF',
      'reason_label': 'Lý do',
      'ack_confirm_title': 'Xác nhận hợp đồng',
      'ack_confirm_body':
          'Bạn xác nhận đã đọc và đồng ý với nội dung hợp đồng (PDF) này?',
      'ack_btn': 'Xác nhận',
      'decline_title': 'Không xác nhận hợp đồng',
      'decline_hint': 'Nêu rõ lý do (bắt buộc)',
      'decline_send': 'Gửi',
      'responded_ok': 'Đã ghi nhận phản hồi',
    },
    'en': {
      'title': 'Employment Contracts',
      'tab_short': 'Contracts',
      'my_contracts': 'My contracts',
      'empty': 'No contracts found',
      'status_active': 'Active',
      'status_expired': 'Expired',
      'status_no_end': 'Open-ended',
      'contract_number': 'Contract No.',
      'start_date': 'Start Date',
      'end_date': 'End Date',
      'no_end_date': 'Not specified',
      'open_pdf': 'View Contract',
      'open_pdf_error': 'Cannot open file',
      'create': 'New Contract',
      'create_title': 'Create New Contract',
      'driver': 'Driver',
      'select_driver': 'Select driver...',
      'contract_number_hint': 'e.g. HD2026001',
      'start_date_hint': 'Select start date',
      'end_date_hint': 'Select end date (optional)',
      'upload_pdf': 'Select PDF file',
      'uploading': 'Uploading file...',
      'file_selected': 'Selected',
      'field_required': 'This field is required',
      'file_required': 'Please select a contract file',
      'created_success': 'Contract created successfully',
      'cancel': 'Cancel',
      'confirm': 'Create Contract',
      'created_at': 'Created',
      'admin_board_title': 'Contracts board',
      'admin_board_subtitle':
          'Each driver has their own contract list with pagination below.',
      'admin_board_empty': 'No active drivers.',
      'admin_full_manager': 'Full manager / create',
      'admin_contracts_loading': 'Loading contracts…',
      'admin_contracts_none': 'No contracts yet',
      'admin_menu_contracts': 'Contracts board',
      'admin_tools': 'Legal response (filter)',
      'filter_all': 'All',
      'filter_pending': 'Pending',
      'filter_ack': 'Acknowledged',
      'filter_declined': 'Declined',
      'ack_section': 'Legal status',
      'ack_pending': 'Awaiting response',
      'ack_yes': 'Acknowledged',
      'ack_no': 'Not acknowledged',
      'viewed_badge': 'PDF viewed',
      'reason_label': 'Reason',
      'ack_confirm_title': 'Acknowledge contract',
      'ack_confirm_body':
          'You confirm you have read and agree to the terms in this contract (PDF)?',
      'ack_btn': 'I acknowledge',
      'decline_title': 'Decline contract',
      'decline_hint': 'Explain why (required)',
      'decline_send': 'Submit',
      'responded_ok': 'Response recorded',
    },
  };

  static String get(String key, AppLanguage lang) {
    final code = lang == AppLanguage.vi ? 'vi' : 'en';
    return _t[code]?[key] ?? key;
  }

  static String ackLabel(String status, AppLanguage lang) {
    switch (status.toUpperCase()) {
      case 'ACKNOWLEDGED':
        return get('ack_yes', lang);
      case 'DECLINED':
        return get('ack_no', lang);
      case 'PENDING':
      default:
        return get('ack_pending', lang);
    }
  }

  static String formatDate(String iso, AppLanguage lang) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
    } catch (_) {
      return iso;
    }
  }
}
