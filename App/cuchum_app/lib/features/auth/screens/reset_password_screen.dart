import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/trans/language_provider.dart';
import '../../../core/trans/forgot_password_language.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/utils/alert_utils.dart';
import '../../../core/utils/keyboard_utils.dart';

class ResetPasswordScreen extends StatefulWidget {
  final String email;

  const ResetPasswordScreen({super.key, required this.email});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _otpController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _otpController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _handleResetPassword() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      final authService = Provider.of<AuthService>(context, listen: false);
      final response = await authService.resetPassword(
        email: widget.email,
        otp: _otpController.text.trim(),
        newPassword: _newPasswordController.text,
        confirmPassword: _confirmPasswordController.text,
      );

      setState(() => _isLoading = false);

      if (!mounted) return;

      if (response.success) {
        AlertUtils.success(context, response.displayMessage);
        // Go back to login
        Navigator.popUntil(context, (route) => route.isFirst);
      } else {
        AlertUtils.error(context, response.displayMessage);
      }
    }
  }

  void _handleResendOTP() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final response = await authService.forgotPassword(widget.email);

    if (!mounted) return;

    if (response.success) {
      AlertUtils.success(context, response.displayMessage);
    } else {
      AlertUtils.error(context, response.displayMessage);
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final languageProvider = Provider.of<LanguageProvider>(context);
    final lang = languageProvider.language;
    final isDark = themeProvider.isDarkMode;

    return DismissKeyboard(
      child: Scaffold(
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),
                  // Header with back button
                  _buildHeader(themeProvider, languageProvider, isDark),
                  const SizedBox(height: 48),
                  // Logo
                  _buildLogo(),
                  const SizedBox(height: 32),
                  // Title
                  _buildTitle(lang, isDark),
                  const SizedBox(height: 40),
                  // Form fields
                  _buildOTPField(lang, isDark),
                  const SizedBox(height: 24),
                  _buildNewPasswordField(lang, isDark),
                  const SizedBox(height: 24),
                  _buildConfirmPasswordField(lang, isDark),
                  const SizedBox(height: 16),
                  // Resend OTP
                  _buildResendOTP(lang),
                  const SizedBox(height: 32),
                  // Reset button
                  _buildResetButton(lang),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(
    ThemeProvider themeProvider,
    LanguageProvider languageProvider,
    bool isDark,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Left side with back button
        IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: isDark ? AppColors.darkText : AppColors.lightText,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        // Right side controls
        Row(
          children: [
            _buildLanguageSwitcher(languageProvider, isDark),
            const SizedBox(width: 12),
            _buildThemeToggle(themeProvider, isDark),
          ],
        ),
      ],
    );
  }

  Widget _buildLanguageSwitcher(
    LanguageProvider languageProvider,
    bool isDark,
  ) {
    return InkWell(
      onTap: () => languageProvider.toggleLanguage(),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.language,
              size: 18,
              color: isDark ? AppColors.darkText : AppColors.lightText,
            ),
            const SizedBox(width: 6),
            Text(
              languageProvider.languageDisplay,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: isDark ? AppColors.darkText : AppColors.lightText,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThemeToggle(ThemeProvider themeProvider, bool isDark) {
    return InkWell(
      onTap: () => themeProvider.toggleTheme(),
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Icon(
          isDark ? Icons.wb_sunny_outlined : Icons.dark_mode_outlined,
          size: 24,
          color: isDark ? AppColors.darkText : AppColors.lightText,
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return Center(
      child: Container(
        width: 100,
        height: 100,
        decoration: const BoxDecoration(
          color: AppColors.primary,
          shape: BoxShape.circle,
        ),
        child: const Center(
          child: Icon(Icons.lock_reset, size: 48, color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildTitle(AppLanguage lang, bool isDark) {
    return Column(
      children: [
        Center(
          child: Text(
            ForgotPasswordLanguage.get('reset_password_title', lang),
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: isDark ? AppColors.darkText : AppColors.lightText,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: Text(
            ForgotPasswordLanguage.get('reset_password_subtitle', lang),
            style: TextStyle(
              fontSize: 16,
              color: isDark
                  ? AppColors.darkTextSecondary
                  : AppColors.lightTextSecondary,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: Text(
            'Email: ${widget.email}',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppColors.primary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOTPField(AppLanguage lang, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          ForgotPasswordLanguage.get('otp_label', lang),
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isDark
                ? AppColors.darkTextSecondary
                : AppColors.lightTextSecondary,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _otpController,
          keyboardType: TextInputType.number,
          maxLength: 6,
          decoration: InputDecoration(
            hintText: ForgotPasswordLanguage.get('otp_hint', lang),
            counterText: '',
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return ForgotPasswordLanguage.get('field_required', lang);
            }
            if (value.length != 6 || !RegExp(r'^\d{6}$').hasMatch(value)) {
              return ForgotPasswordLanguage.get('invalid_otp', lang);
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildNewPasswordField(AppLanguage lang, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          ForgotPasswordLanguage.get('new_password_label', lang),
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isDark
                ? AppColors.darkTextSecondary
                : AppColors.lightTextSecondary,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _newPasswordController,
          obscureText: _obscureNewPassword,
          decoration: InputDecoration(
            hintText: ForgotPasswordLanguage.get('new_password_hint', lang),
            suffixIcon: IconButton(
              icon: Icon(
                _obscureNewPassword
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                color: AppColors.primary,
              ),
              onPressed: () {
                setState(() => _obscureNewPassword = !_obscureNewPassword);
              },
            ),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return ForgotPasswordLanguage.get('field_required', lang);
            }
            if (value.length < 6) {
              return ForgotPasswordLanguage.get('password_min_length', lang);
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildConfirmPasswordField(AppLanguage lang, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          ForgotPasswordLanguage.get('confirm_password_label', lang),
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isDark
                ? AppColors.darkTextSecondary
                : AppColors.lightTextSecondary,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _confirmPasswordController,
          obscureText: _obscureConfirmPassword,
          decoration: InputDecoration(
            hintText: ForgotPasswordLanguage.get('confirm_password_hint', lang),
            suffixIcon: IconButton(
              icon: Icon(
                _obscureConfirmPassword
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                color: AppColors.primary,
              ),
              onPressed: () {
                setState(
                  () => _obscureConfirmPassword = !_obscureConfirmPassword,
                );
              },
            ),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return ForgotPasswordLanguage.get('field_required', lang);
            }
            if (value != _newPasswordController.text) {
              return ForgotPasswordLanguage.get('password_mismatch', lang);
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildResendOTP(AppLanguage lang) {
    return Align(
      alignment: Alignment.centerRight,
      child: TextButton(
        onPressed: _handleResendOTP,
        child: Text(ForgotPasswordLanguage.get('resend_otp', lang)),
      ),
    );
  }

  Widget _buildResetButton(AppLanguage lang) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _handleResetPassword,
        child: _isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : Text(ForgotPasswordLanguage.get('reset_button', lang)),
      ),
    );
  }
}
