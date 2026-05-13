import 'package:flutter/material.dart';
import '../../core/services/api_models.dart';
import '../../features/operations/screens/driver_trip_detail_screen.dart';
import '../../features/operations/screens/admin_trip_detail_screen.dart';
import '../../features/payslips/screens/payslips_screen.dart';

/// Dẫn hướng khi người dùng bấm vào notification (in-app hoặc từ Notification Center).
abstract final class NotificationNavigation {
  /// Gọi [navigate] với [BuildContext] hiện tại.
  /// [isAdmin] dùng để chọn màn hình admin/driver cho trip detail.
  static void navigate(BuildContext context, NotificationData notif, {required bool isAdmin}) {
    if (notif.resourceType == null || notif.resourceId == null) return;

    final type = notif.resourceType!;
    final id = notif.resourceId!;

    switch (type) {
      case 'trip':
        if (isAdmin) {
          Navigator.push(context, MaterialPageRoute(
            builder: (_) => AdminTripDetailScreen(tripId: id),
          ));
        } else {
          Navigator.push(context, MaterialPageRoute(
            builder: (_) => DriverTripDetailScreen(tripId: id),
          ));
        }
        break;
      case 'payslip':
        // Mở màn Payslips (current version does not have individual payslip detail)
        Navigator.push(context, MaterialPageRoute(
          builder: (_) => const PayslipsScreen(),
        ));
        break;
      case 'contract':
        // Fallback — không có màn hình contract detail riêng, mở ContractPdfScreen nếu có fileUrl
        // Navigator.push(context, ...);
        break;
      default:
        // Không crash — resource type không nhận dạng thì chỉ mark read
        break;
    }
  }

  /// Dùng khi không có [BuildContext] (e.g., FCM terminated-state background tap).
  /// Yêu cầu [GlobalKey<NavigatorState>] đã được gán vào [MaterialApp].
  static void navigateWithKey(GlobalKey<NavigatorState> navKey, NotificationData notif, {required bool isAdmin}) {
    final c = navKey.currentContext;
    if (c == null) return;
    navigate(c, notif, isAdmin: isAdmin);
  }
}
