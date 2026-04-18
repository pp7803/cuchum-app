import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/trans/language_provider.dart';
import '../../../core/trans/admin_language.dart';
import '../../../core/trans/profile_language.dart';
import '../../../core/services/user_service.dart';
import '../../contracts/screens/contracts_screen.dart';
import '../../../core/services/api_models.dart';
import '../../../core/utils/alert_utils.dart';
import '../widgets/admin_ui.dart';

class MemberDetailScreen extends StatefulWidget {
  final UserData member;

  const MemberDetailScreen({super.key, required this.member});

  @override
  State<MemberDetailScreen> createState() => _MemberDetailScreenState();
}

class _MemberDetailScreenState extends State<MemberDetailScreen> {
  ProfileData? _profile;
  bool _isLoading = true;
  late UserData _member;

  @override
  void initState() {
    super.initState();
    _member = widget.member;
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    final userService = Provider.of<UserService>(context, listen: false);
    final result = await userService.getUserProfile(_member.id);

    if (!mounted) return;
    setState(() {
      _profile = result.data;
      _isLoading = false;
    });
  }

  Future<void> _toggleStatus() async {
    final isDark = Provider.of<ThemeProvider>(context, listen: false).isDarkMode;
    final lang = Provider.of<LanguageProvider>(context, listen: false).language;
    final newStatus = _member.isActive ? 'INACTIVE' : 'ACTIVE';
    final confirmKey = _member.isActive ? 'confirm_lock' : 'confirm_unlock';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Text(
          AdminLanguage.get(confirmKey, lang),
          style: TextStyle(
              color: isDark ? AppColors.darkText : AppColors.lightText),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Hủy')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(minimumSize: Size.zero),
            child: const Text('Xác nhận'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final userService = Provider.of<UserService>(context, listen: false);
    final result = await userService.updateUserStatus(_member.id, newStatus);
    if (!mounted) return;

    if (result.success) {
      setState(() {
        _member = UserData(
          id: _member.id,
          phoneNumber: _member.phoneNumber,
          email: _member.email,
          fullName: _member.fullName,
          role: _member.role,
          status: newStatus,
          createdAt: _member.createdAt,
          updatedAt: _member.updatedAt,
        );
      });
      AlertUtils.success(context, AdminLanguage.get('status_updated', lang));
    } else {
      AlertUtils.error(context, result.displayMessage);
    }
  }

  Future<void> _resetPassword() async {
    final isDark = Provider.of<ThemeProvider>(context, listen: false).isDarkMode;
    final lang = Provider.of<LanguageProvider>(context, listen: false).language;
    final pwCtrl = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(AdminLanguage.get('reset_password', lang),
            style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isDark ? AppColors.darkText : AppColors.lightText)),
        content: TextField(
          controller: pwCtrl,
          obscureText: true,
          decoration: InputDecoration(
            labelText: AdminLanguage.get('new_password', lang),
            hintText: AdminLanguage.get('password_hint', lang),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Hủy')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(minimumSize: Size.zero),
            child: const Text('Xác nhận'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    if (pwCtrl.text.trim().length < 6) {
      AlertUtils.error(context, AdminLanguage.get('password_too_short', lang));
      return;
    }

    final userService = Provider.of<UserService>(context, listen: false);
    final result = await userService.resetUserPassword(_member.id, pwCtrl.text.trim());
    if (!mounted) return;

    if (result.success) {
      AlertUtils.success(context, AdminLanguage.get('password_reset', lang));
    } else {
      AlertUtils.error(context, result.displayMessage);
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
      backgroundColor: AdminTheme.canvas(isDark),
      body: SafeArea(
        child: Column(
          children: [
            AdminScreenHeader(
              title: _member.fullName,
              isDark: isDark,
            ),
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: AppColors.primary))
                  : RefreshIndicator(
                      onRefresh: _loadProfile,
                      color: AppColors.primary,
                      child: CustomScrollView(
                        slivers: [
                          SliverToBoxAdapter(child: _buildHeroCard(lang, isDark)),
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _sectionLabel(
                                      ProfileLanguage.get('account_info', lang), isDark),
                                  const SizedBox(height: 8),
                                  _buildAccountCard(lang, isDark),
                                  const SizedBox(height: 16),
                                  _sectionLabel(
                                      ProfileLanguage.get('driver_info', lang), isDark),
                                  const SizedBox(height: 8),
                                  _buildDriverProfileCard(lang, isDark),
                                  const SizedBox(height: 16),
                                  // ── Contracts shortcut ─────────────────
                                  _buildContractsCard(lang, isDark),
                                  const SizedBox(height: 24),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroCard(AppLanguage lang, bool isDark) {
    final isActive = _member.isActive;
    final name = _member.fullName;
    final initials = name
        .trim()
        .split(' ')
        .map((w) => w.isNotEmpty ? w[0] : '')
        .take(2)
        .join()
        .toUpperCase();
    final avatarColor =
        isActive ? const Color(0xFF059669) : AppColors.lightTextSecondary;

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.07),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          // Avatar
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: avatarColor.withValues(alpha: 0.12),
              border: Border.all(
                  color: avatarColor.withValues(alpha: 0.35), width: 2.5),
            ),
            child: Center(
              child: Text(
                initials.isEmpty ? '?' : initials,
                style: TextStyle(
                  color: avatarColor,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _member.fullName,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDark ? AppColors.darkText : AppColors.lightText,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _statusChip(
                isActive
                    ? ProfileLanguage.get('status_active', lang)
                    : ProfileLanguage.get('status_inactive', lang),
                isActive ? AppColors.success : AppColors.error,
              ),
              const SizedBox(width: 8),
              _statusChip('DRIVER', AppColors.primary),
            ],
          ),
          const SizedBox(height: 16),
          // Action buttons
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 42,
                  child: OutlinedButton.icon(
                    onPressed: _toggleStatus,
                    icon: Icon(
                      isActive
                          ? Icons.lock_outline_rounded
                          : Icons.lock_open_rounded,
                      size: 16,
                    ),
                    label: Text(
                      AdminLanguage.get(
                          isActive ? 'lock_account' : 'unlock_account', lang),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor:
                          isActive ? AppColors.error : AppColors.success,
                      side: BorderSide(
                        color: isActive ? AppColors.error : AppColors.success,
                        width: 1.5,
                      ),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SizedBox(
                  height: 42,
                  child: OutlinedButton.icon(
                    onPressed: _resetPassword,
                    icon: const Icon(Icons.key_rounded, size: 16),
                    label: Text(
                      AdminLanguage.get('reset_password', lang),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.primary, width: 1.5),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAccountCard(AppLanguage lang, bool isDark) {
    return _card(
      isDark: isDark,
      child: Column(
        children: [
          _infoRow(Icons.phone_outlined, ProfileLanguage.get('phone_number', lang),
              _member.phoneNumber, isDark),
          if (_member.email != null) ...[
            _divider(isDark),
            _infoRow(Icons.email_outlined, ProfileLanguage.get('email', lang),
                _member.email!, isDark),
          ],
          _divider(isDark),
          _infoRow(Icons.calendar_today_outlined,
              ProfileLanguage.get('member_since', lang),
              _formatDate(_member.createdAt), isDark),
        ],
      ),
    );
  }

  Widget _buildDriverProfileCard(AppLanguage lang, bool isDark) {
    final p = _profile;
    final notUpdated = ProfileLanguage.get('not_updated', lang);

    return _card(
      isDark: isDark,
      child: Column(
        children: [
          _infoRow(Icons.badge_outlined, ProfileLanguage.get('citizen_id', lang),
              p?.citizenId ?? notUpdated, isDark,
              isPlaceholder: p?.citizenId == null),
          _divider(isDark),
          _infoRow(Icons.card_membership_outlined,
              ProfileLanguage.get('license_class', lang),
              p?.licenseClass ?? notUpdated, isDark,
              isPlaceholder: p?.licenseClass == null),
          _divider(isDark),
          _infoRow(
              Icons.badge_rounded,
              ProfileLanguage.get('license_number', lang),
              p?.licenseNumber ?? notUpdated,
              isDark,
              isPlaceholder: p?.licenseNumber == null),
          _divider(isDark),
          _infoRow(Icons.home_outlined, ProfileLanguage.get('address', lang),
              p?.address ?? notUpdated, isDark,
              isPlaceholder: p?.address == null),
        ],
      ),
    );
  }

  // ─── Helpers ─────────────────────────────────────────────────────────────

  Widget _sectionLabel(String label, bool isDark) => Padding(
        padding: const EdgeInsets.only(bottom: 2),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
          ),
        ),
      );

  Widget _buildContractsCard(AppLanguage lang, bool isDark) {
    return _card(
      isDark: isDark,
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ContractsScreen(
              driverId: _member.id,
              driverName: _member.fullName,
            ),
          ),
        ),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Icon(Icons.description_rounded,
                    color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  lang == AppLanguage.vi ? 'Hợp đồng lao động' : 'Employment Contracts',
                  style: TextStyle(
                    fontSize: 15,
                    color: isDark ? AppColors.darkText : AppColors.lightText,
                  ),
                ),
              ),
              Icon(Icons.chevron_right_rounded,
                  color: isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.lightTextSecondary),
            ],
          ),
        ),
      ),
    );
  }

  Widget _card({required bool isDark, required Widget child}) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.06),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: child,
      );

  Widget _divider(bool isDark) => Divider(
        color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        height: 1,
      );

  Widget _infoRow(
    IconData icon,
    String label,
    String value,
    bool isDark, {
    bool isPlaceholder = false,
  }) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Icon(icon,
                size: 18,
                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
            const SizedBox(width: 12),
            Text(label,
                style: TextStyle(
                    fontSize: 13,
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.lightTextSecondary)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                value,
                textAlign: TextAlign.end,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight:
                      isPlaceholder ? FontWeight.w400 : FontWeight.w500,
                  fontStyle:
                      isPlaceholder ? FontStyle.italic : FontStyle.normal,
                  color: isPlaceholder
                      ? (isDark ? AppColors.darkBorder : const Color(0xFFD1D5DB))
                      : (isDark ? AppColors.darkText : AppColors.lightText),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      );

  Widget _statusChip(String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
              fontSize: 12, fontWeight: FontWeight.w600, color: color),
        ),
      );

  String _formatDate(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
    } catch (_) {
      return iso;
    }
  }
}
