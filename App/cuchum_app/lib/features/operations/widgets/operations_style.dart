import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// Typography, màu nền, ô nhập và thẻ — đồng bộ với [PayslipsScreen].
abstract final class OperationsStyle {
  static Color bg(bool isDark) =>
      isDark ? AppColors.darkBackground : const Color(0xFFF0F4FF);

  static Color fg(bool isDark) =>
      isDark ? AppColors.darkText : AppColors.lightText;

  static Color fgMuted(bool isDark) => fg(isDark).withValues(alpha: 0.7);

  static InputDecoration inputDeco(
    bool isDark, {
    String? labelText,
    String? hintText,
  }) {
    return InputDecoration(
      labelText: labelText,
      hintText: hintText,
      labelStyle: TextStyle(color: fg(isDark).withValues(alpha: 0.85)),
      hintStyle: TextStyle(color: fg(isDark).withValues(alpha: 0.45)),
      filled: true,
      fillColor: isDark ? AppColors.darkSurface : Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: isDark ? Colors.white24 : Colors.grey.shade300,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    );
  }

  static BoxDecoration card(bool isDark) => BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      );

  static ButtonStyle primaryFilled(bool isDark) => FilledButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      );
}

/// Màu badge theo `TripData.status` (enum API).
abstract final class TripStatusStyle {
  static Color accent(String rawStatus) {
    switch (rawStatus.trim().toUpperCase()) {
      case 'SCHEDULED_PENDING':
        return AppColors.warning;
      case 'DRIVER_ACCEPTED':
        return const Color(0xFF0D9488);
      case 'DRIVER_DECLINED':
        return AppColors.error;
      case 'IN_PROGRESS':
      case 'ONGOING':
        return AppColors.primaryLight;
      case 'COMPLETED':
        return AppColors.success;
      case 'CANCELLED':
        return const Color(0xFF64748B);
      default:
        return AppColors.primary;
    }
  }

  static Color badgeBackground(String rawStatus, {required bool isDark}) {
    final a = isDark ? 0.28 : 0.14;
    return accent(rawStatus).withValues(alpha: a);
  }
}

/// Giống header Payslips: back + tiêu đề 20 bold + refresh tùy chọn.
class OperationsScreenHeader extends StatelessWidget {
  const OperationsScreenHeader({
    super.key,
    required this.title,
    required this.isDark,
    this.onRefresh,
    this.refreshBusy = false,
  });

  final String title;
  final bool isDark;
  final VoidCallback? onRefresh;
  final bool refreshBusy;

  @override
  Widget build(BuildContext context) {
    final fg = OperationsStyle.fg(isDark);
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 12, 20, 16),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: Icon(Icons.arrow_back_ios_new_rounded, color: fg),
          ),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: fg,
              ),
            ),
          ),
          if (onRefresh != null)
            IconButton(
              onPressed: refreshBusy ? null : onRefresh,
              icon: Icon(Icons.refresh_rounded, color: fg),
            ),
        ],
      ),
    );
  }
}
