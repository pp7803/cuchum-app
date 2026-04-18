import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../operations/widgets/operations_style.dart';

/// Nền, header, thẻ — đồng bộ màn hình quản trị với [OperationsStyle].
abstract final class AdminTheme {
  static Color canvas(bool isDark) => OperationsStyle.bg(isDark);

  static Color fg(bool isDark) => OperationsStyle.fg(isDark);

  static Color fgMuted(bool isDark) => OperationsStyle.fgMuted(isDark);

  /// Viền nhẹ cho thẻ / ô phân đoạn.
  static Color outline(bool isDark) =>
      isDark ? Colors.white.withValues(alpha: 0.08) : AppColors.lightBorder;

  static List<BoxShadow> cardShadow(bool isDark) => [
        BoxShadow(
          color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.07),
          blurRadius: 20,
          offset: const Offset(0, 8),
        ),
      ];

  static BoxDecoration welcomeCard(bool isDark) => BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: outline(isDark)),
        boxShadow: cardShadow(isDark),
      );

  static BoxDecoration statCard(bool isDark, Color accent) => BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: outline(isDark)),
        boxShadow: cardShadow(isDark),
      );

  static BoxDecoration segmentedShell(bool isDark) => BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: outline(isDark)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      );

  static LinearGradient accentBar(Color c) => LinearGradient(
        colors: [c, c.withValues(alpha: 0.65)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      );

  /// Thẻ danh sách (bán kính 14) — dùng chung màn admin.
  static BoxDecoration cardDecoration(bool isDark) => BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: outline(isDark)),
        boxShadow: cardShadow(isDark),
      );
}

/// Header chuẩn màn quản trị (back + tiêu đề + hành động phải).
class AdminScreenHeader extends StatelessWidget {
  const AdminScreenHeader({
    super.key,
    required this.title,
    required this.isDark,
    this.subtitle,
    this.onBack,
    this.onRefresh,
    this.refreshBusy = false,
    this.trailing,
  });

  final String title;
  final bool isDark;
  final String? subtitle;
  /// Mặc định [Navigator.maybePop] nếu null.
  final VoidCallback? onBack;
  final VoidCallback? onRefresh;
  final bool refreshBusy;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final fg = AdminTheme.fg(isDark);
    final sub = AdminTheme.fgMuted(isDark);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 16, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconButton(
            onPressed: () {
              if (onBack != null) {
                onBack!();
              } else {
                Navigator.maybePop(context);
              }
            },
            icon: Icon(Icons.arrow_back_ios_new_rounded, color: fg, size: 20),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.4,
                      height: 1.15,
                      color: fg,
                    ),
                  ),
                  if (subtitle != null && subtitle!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      subtitle!,
                      style: TextStyle(
                        fontSize: 13,
                        color: sub,
                        height: 1.25,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (trailing != null) trailing!,
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

/// Dòng công cụ trên dashboard (icon màu + tiêu đề + mũi tên).
class AdminDashboardToolTile extends StatelessWidget {
  const AdminDashboardToolTile({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.isDark,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = AdminTheme.fg(isDark);
    final muted = AdminTheme.fgMuted(isDark);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AdminTheme.outline(isDark)),
            boxShadow: AdminTheme.cardShadow(isDark),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: isDark ? 0.2 : 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: fg,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: muted,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: muted,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
