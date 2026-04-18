import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/trans/language_provider.dart';
import '../../../core/trans/profile_language.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/biometric_service.dart';
import '../../../core/utils/alert_utils.dart';
import '../../auth/screens/login_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with WidgetsBindingObserver {
  bool _biometricEnabled = false;
  bool _biometricAvailable = false;
  bool _isTogglingBiometric = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkBiometricState();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkBiometricState();
    }
  }

  Future<void> _checkBiometricState() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final available = await BiometricService.isAvailable();
    if (mounted) {
      setState(() {
        _biometricAvailable = available;
        _biometricEnabled = authService.hasBiometricToken;
      });
    }
  }

  Future<void> _handleBiometricToggle(bool enable) async {
    if (_isTogglingBiometric) return;
    final lang = Provider.of<LanguageProvider>(context, listen: false).language;
    final authService = Provider.of<AuthService>(context, listen: false);

    if (enable) {
      final ready = await BiometricService.isAvailable();
      if (!mounted) return;
      if (!ready) {
        setState(() => _biometricAvailable = false);
        AlertUtils.error(
          context,
          ProfileLanguage.get('biometric_not_enrolled', lang),
        );
        return;
      }
      setState(() => _biometricAvailable = true);

      final authenticated = await BiometricService.authenticate(
        reason: ProfileLanguage.get('biometric_enable_confirm', lang),
      );
      if (!mounted) return;
      if (!authenticated) {
        AlertUtils.error(
          context,
          ProfileLanguage.get('biometric_auth_failed', lang),
        );
        return;
      }
      setState(() => _isTogglingBiometric = true);
      final result = await authService.enableBiometric();
      if (!mounted) return;
      setState(() => _isTogglingBiometric = false);
      if (result.success) {
        setState(() => _biometricEnabled = true);
        AlertUtils.success(
          context,
          ProfileLanguage.get('biometric_enabled', lang),
        );
      } else {
        AlertUtils.error(context, result.displayMessage);
      }
    } else {
      final authenticated = await BiometricService.authenticate(
        reason: ProfileLanguage.get('biometric_disable_confirm', lang),
      );
      if (!mounted) return;
      if (!authenticated) {
        AlertUtils.error(
          context,
          ProfileLanguage.get('biometric_auth_failed', lang),
        );
        return;
      }

      setState(() => _isTogglingBiometric = true);
      final result = await authService.disableBiometric();
      if (!mounted) return;
      setState(() => _isTogglingBiometric = false);
      if (result.success) {
        setState(() => _biometricEnabled = false);
        AlertUtils.success(
          context,
          ProfileLanguage.get('biometric_disabled', lang),
        );
      } else {
        AlertUtils.error(context, result.displayMessage);
      }
    }
  }

  Future<void> _handleLogout() async {
    final lang = Provider.of<LanguageProvider>(context, listen: false).language;
    final isDark = Provider.of<ThemeProvider>(
      context,
      listen: false,
    ).isDarkMode;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          ProfileLanguage.get('logout', lang),
          style: TextStyle(
            color: isDark ? AppColors.darkText : AppColors.lightText,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          ProfileLanguage.get('logout_confirm', lang),
          style: TextStyle(
            color: isDark
                ? AppColors.darkTextSecondary
                : AppColors.lightTextSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(ProfileLanguage.get('cancel', lang)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              minimumSize: Size.zero,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
            child: Text(ProfileLanguage.get('logout_confirm_yes', lang)),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      final authService = Provider.of<AuthService>(context, listen: false);
      await authService.logout();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (_) => false,
      );
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final languageProvider = Provider.of<LanguageProvider>(context);
    final lang = languageProvider.language;
    final isDark = themeProvider.isDarkMode;

    return Scaffold(
      backgroundColor: isDark
          ? AppColors.darkBackground
          : const Color(0xFFF0F4FF),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // ── Page title ──────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 4),
                child: Text(
                  ProfileLanguage.get('settings', lang),
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppColors.darkText : AppColors.lightText,
                  ),
                ),
              ),
            ),

            // ── Giao diện ───────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionLabel(
                      ProfileLanguage.get('section_appearance', lang),
                      isDark,
                    ),
                    const SizedBox(height: 10),
                    _buildAppearanceCard(
                      lang,
                      isDark,
                      themeProvider,
                      languageProvider,
                    ),
                  ],
                ),
              ),
            ),

            // ── Bảo mật ─────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionLabel(
                      ProfileLanguage.get('section_security', lang),
                      isDark,
                    ),
                    const SizedBox(height: 10),
                    _buildSecurityCard(lang, isDark),
                  ],
                ),
              ),
            ),

            // ── Đăng xuất ───────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
                child: _buildLogoutButton(lang),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // APPEARANCE CARD
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildAppearanceCard(
    AppLanguage lang,
    bool isDark,
    ThemeProvider themeProvider,
    LanguageProvider languageProvider,
  ) {
    return _card(
      isDark: isDark,
      child: Column(
        children: [
          // Dark mode
          _switchRow(
            icon: isDark ? Icons.dark_mode_rounded : Icons.wb_sunny_outlined,
            label: ProfileLanguage.get('dark_mode', lang),
            value: isDark,
            onChanged: (_) => themeProvider.toggleTheme(),
            isDark: isDark,
          ),
          _divider(isDark),
          // Language
          InkWell(
            onTap: () => languageProvider.toggleLanguage(),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                children: [
                  _rowIcon(Icons.language_outlined, isDark),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      ProfileLanguage.get('language', lang),
                      style: _rowLabelStyle(isDark),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      languageProvider.languageDisplay,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SECURITY CARD
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildSecurityCard(AppLanguage lang, bool isDark) {
    return _card(
      isDark: isDark,
      child: Column(
        children: [
          if (_biometricAvailable)
            _buildBiometricRow(lang, isDark)
          else
            _buildBiometricUnavailableRow(lang, isDark),
        ],
      ),
    );
  }

  Widget _buildBiometricUnavailableRow(AppLanguage lang, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.fingerprint_rounded,
            color: isDark
                ? AppColors.darkTextSecondary
                : AppColors.lightTextSecondary,
            size: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              ProfileLanguage.get('biometric_not_available', lang),
              style: TextStyle(
                fontSize: 13,
                height: 1.35,
                color: isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.lightTextSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBiometricRow(AppLanguage lang, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.fingerprint_rounded,
              color: AppColors.primary,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  ProfileLanguage.get('biometric_auth', lang),
                  style: _rowLabelStyle(isDark),
                ),
                const SizedBox(height: 2),
                Text(
                  ProfileLanguage.get('biometric_subtitle', lang),
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.lightTextSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _isTogglingBiometric
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.primary,
                  ),
                )
              : Switch(
                  value: _biometricEnabled,
                  onChanged: _handleBiometricToggle,
                  activeColor: AppColors.primary,
                ),
        ],
      ),
    );
  }

  Widget _buildLogoutButton(AppLanguage lang) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton.icon(
        onPressed: _handleLogout,
        icon: const Icon(Icons.logout_rounded, color: AppColors.error),
        label: Text(
          ProfileLanguage.get('logout', lang),
          style: const TextStyle(
            color: AppColors.error,
            fontWeight: FontWeight.w600,
          ),
        ),
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: AppColors.error, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // HELPERS
  // ─────────────────────────────────────────────────────────────────────────

  Widget _sectionLabel(String label, bool isDark) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.4,
        color: isDark
            ? AppColors.darkTextSecondary
            : AppColors.lightTextSecondary,
      ),
    );
  }

  Widget _card({required bool isDark, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _divider(bool isDark) => Divider(
    color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
    height: 1,
  );

  Icon _rowIcon(IconData icon, bool isDark) => Icon(
    icon,
    size: 20,
    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
  );

  TextStyle _rowLabelStyle(bool isDark) => TextStyle(
    fontSize: 15,
    color: isDark ? AppColors.darkText : AppColors.lightText,
  );

  Widget _switchRow({
    required IconData icon,
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
    required bool isDark,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          _rowIcon(icon, isDark),
          const SizedBox(width: 14),
          Expanded(child: Text(label, style: _rowLabelStyle(isDark))),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: AppColors.primary,
          ),
        ],
      ),
    );
  }
}
