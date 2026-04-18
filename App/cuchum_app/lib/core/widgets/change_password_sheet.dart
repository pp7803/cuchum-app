import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_colors.dart';
import '../trans/language_provider.dart';
import '../trans/profile_language.dart';
import '../services/auth_service.dart';
import '../utils/alert_utils.dart';
import '../utils/keyboard_utils.dart';

class ChangePasswordSheet extends StatefulWidget {
  const ChangePasswordSheet({super.key});

  /// Helper to open the bottom sheet
  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const ChangePasswordSheet(),
    );
  }

  @override
  State<ChangePasswordSheet> createState() => _ChangePasswordSheetState();
}

class _ChangePasswordSheetState extends State<ChangePasswordSheet> {
  final _formKey = GlobalKey<FormState>();
  final _currentPwCtrl = TextEditingController();
  final _newPwCtrl = TextEditingController();
  final _confirmPwCtrl = TextEditingController();
  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _currentPwCtrl.dispose();
    _newPwCtrl.dispose();
    _confirmPwCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final authService = Provider.of<AuthService>(context, listen: false);
    final lang = Provider.of<LanguageProvider>(context, listen: false).language;
    final result = await authService.changePassword(
      currentPassword: _currentPwCtrl.text,
      newPassword: _newPwCtrl.text,
      confirmPassword: _confirmPwCtrl.text,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result.success) {
      Navigator.pop(context);
      AlertUtils.success(context, ProfileLanguage.get('password_changed', lang));
    } else {
      AlertUtils.error(context, result.displayMessage);
    }
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);
    final lang = languageProvider.language;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppColors.darkSurface : Colors.white;

    return DismissKeyboard(
      child: Container(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 24,
          bottom: MediaQuery.of(context).viewInsets.bottom + 32,
        ),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                ProfileLanguage.get('change_password', lang),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppColors.darkText : AppColors.lightText,
                ),
              ),
              const SizedBox(height: 20),
              _pwField(
                controller: _currentPwCtrl,
                label: ProfileLanguage.get('current_password', lang),
                hint: ProfileLanguage.get('password_hint', lang),
                obscure: _obscureCurrent,
                onToggle: () => setState(() => _obscureCurrent = !_obscureCurrent),
                isDark: isDark,
                lang: lang,
              ),
              const SizedBox(height: 14),
              _pwField(
                controller: _newPwCtrl,
                label: ProfileLanguage.get('new_password', lang),
                hint: ProfileLanguage.get('password_hint', lang),
                obscure: _obscureNew,
                onToggle: () => setState(() => _obscureNew = !_obscureNew),
                isDark: isDark,
                lang: lang,
              ),
              const SizedBox(height: 14),
              _pwField(
                controller: _confirmPwCtrl,
                label: ProfileLanguage.get('confirm_password', lang),
                hint: ProfileLanguage.get('password_hint', lang),
                obscure: _obscureConfirm,
                onToggle: () => setState(() => _obscureConfirm = !_obscureConfirm),
                isDark: isDark,
                lang: lang,
                validator: (v) {
                  if (v == null || v.isEmpty) {
                    return ProfileLanguage.get('field_required', lang);
                  }
                  if (v != _newPwCtrl.text) {
                    return ProfileLanguage.get('passwords_not_match', lang);
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submit,
                  child: _isLoading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(ProfileLanguage.get('save_changes', lang)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _pwField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required bool obscure,
    required VoidCallback onToggle,
    required bool isDark,
    required AppLanguage lang,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          obscureText: obscure,
          decoration: InputDecoration(
            hintText: hint,
            suffixIcon: IconButton(
              icon: Icon(
                obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                color: AppColors.primary,
                size: 20,
              ),
              onPressed: onToggle,
            ),
          ),
          validator: validator ??
              (v) {
                if (v == null || v.isEmpty) {
                  return ProfileLanguage.get('field_required', lang);
                }
                if (v.length < 6) return ProfileLanguage.get('password_hint', lang);
                return null;
              },
        ),
      ],
    );
  }
}
