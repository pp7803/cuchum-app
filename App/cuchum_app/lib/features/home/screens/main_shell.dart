import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/trans/language_provider.dart';
import '../../../core/trans/dashboard_language.dart';
import '../../../core/trans/profile_language.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/sse_service.dart';
import '../../../core/services/api_models.dart';
import '../../../core/utils/alert_utils.dart';
import '../../dashboard/screens/admin_dashboard_screen.dart';
import '../../dashboard/screens/driver_dashboard_screen.dart';
import '../../profile/screens/profile_screen.dart';
import '../../settings/screens/settings_screen.dart';
import '../../contracts/screens/contracts_screen.dart';
import '../../../core/trans/contracts_language.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;
  int _unreadCount = 0;
  StreamSubscription<NotificationData>? _sseSub;

  @override
  void initState() {
    super.initState();
    _startSSE();
  }

  @override
  void dispose() {
    _sseSub?.cancel();
    SSEService.stop();
    super.dispose();
  }

  void _startSSE() {
    final authService = Provider.of<AuthService>(context, listen: false);
    final token = authService.accessToken;
    if (token != null && token.isNotEmpty) {
      SSEService.start(token);
    }

    // Listen: update unread badge + show in-app toast
    _sseSub = SSEService.stream.listen((notif) {
      if (!mounted) return;
      setState(() => _unreadCount++);
      AlertUtils.info(context, notif.body, title: notif.title);
    });
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context, listen: false);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final languageProvider = Provider.of<LanguageProvider>(context);
    final lang = languageProvider.language;
    final isDark = themeProvider.isDarkMode;
    final isAdmin = authService.currentUser?.isAdmin ?? false;

    final List<Widget> screens = isAdmin
        ? [
            const AdminDashboardScreen(),
            const ProfileScreen(),
            const SettingsScreen(),
          ]
        : [
            const DriverDashboardScreen(),
            const ContractsScreen(embeddedInShell: true),
            const ProfileScreen(),
            const SettingsScreen(),
          ];

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : const Color(0xFFF0F4FF),
      body: IndexedStack(index: _currentIndex, children: screens),
      bottomNavigationBar: _buildBottomNav(lang, isDark, isAdmin),
      // ignore screens — used just for type hints above
    );
  }

  Widget _buildBottomNav(AppLanguage lang, bool isDark, bool isAdmin) {
    final bgColor = isDark ? AppColors.darkSurface : AppColors.lightBackground;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    final List<_NavItem> navItems;
    if (isAdmin) {
      navItems = [
        _NavItem(Icons.dashboard_outlined, Icons.dashboard_rounded,
            DashboardLanguage.get('dashboard', lang), 0),
        _NavItem(Icons.person_outline_rounded, Icons.person_rounded,
            ProfileLanguage.get('profile', lang), 1),
        _NavItem(Icons.tune_outlined, Icons.tune_rounded,
            ProfileLanguage.get('settings', lang), 2),
      ];
    } else {
      navItems = [
        _NavItem(Icons.dashboard_outlined, Icons.dashboard_rounded,
            DashboardLanguage.get('dashboard', lang), 0),
        _NavItem(Icons.description_outlined, Icons.description_rounded,
            ContractsLanguage.get('tab_short', lang), 1),
        _NavItem(Icons.person_outline_rounded, Icons.person_rounded,
            ProfileLanguage.get('profile', lang), 2),
        _NavItem(Icons.tune_outlined, Icons.tune_rounded,
            ProfileLanguage.get('settings', lang), 3),
      ];
    }

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        border: Border(top: BorderSide(color: borderColor, width: 1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Row(
            children: [
              _buildNavItem(navItems[0], isDark),
              if (!isAdmin) _buildNavItem(navItems[1], isDark),
              _buildCameraButton(isDark),
              _buildNavItem(navItems[isAdmin ? 1 : 2], isDark),
              _buildNavItem(navItems[isAdmin ? 2 : 3], isDark),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(_NavItem item, bool isDark) {
    final isSelected = _currentIndex == item.tabIndex;
    final color = isSelected
        ? AppColors.primary
        : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary);

    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _currentIndex = item.tabIndex),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Icon(
                  isSelected ? item.activeIcon : item.icon,
                  key: ValueKey(isSelected),
                  color: color,
                  size: 26,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                item.label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  color: color,
                ),
              ),
              const SizedBox(height: 2),
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: isSelected ? 20 : 0,
                height: 3,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Prominent Camera FAB button in the center of the bottom nav
  Widget _buildCameraButton(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: GestureDetector(
        onTap: () {
          // TODO: implement camera feature
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Tính năng Camera sẽ sớm được ra mắt'),
              duration: Duration(seconds: 2),
            ),
          );
        },
        child: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.primary, AppColors.primaryLight],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.4),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Icon(
            Icons.camera_alt_rounded,
            color: Colors.white,
            size: 26,
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final int tabIndex;
  const _NavItem(this.icon, this.activeIcon, this.label, this.tabIndex);
}
