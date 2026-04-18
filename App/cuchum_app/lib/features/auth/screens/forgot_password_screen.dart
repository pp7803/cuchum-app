import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/trans/language_provider.dart';
import '../../../core/trans/forgot_password_language.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/utils/alert_utils.dart';
import '../../../core/utils/keyboard_utils.dart';
import 'reset_password_screen.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  void _handleSendOTP() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      final authService = Provider.of<AuthService>(context, listen: false);
      final response = await authService.forgotPassword(
        _emailController.text.trim(),
      );

      setState(() => _isLoading = false);

      if (!mounted) return;

      if (response.success) {
        AlertUtils.success(context, response.displayMessage);
        // Navigate to reset password screen
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                ResetPasswordScreen(email: _emailController.text.trim()),
          ),
        );
      } else {
        AlertUtils.error(context, response.displayMessage);
      }
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
                  // Email field
                  _buildEmailField(lang, isDark),
                  const SizedBox(height: 32),
                  // Send OTP button
                  _buildSendOTPButton(lang),
                  const SizedBox(height: 16),
                  // Back to login
                  _buildBackToLogin(lang),
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
            ForgotPasswordLanguage.get('forgot_password_title', lang),
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
            ForgotPasswordLanguage.get('forgot_password_subtitle', lang),
            style: TextStyle(
              fontSize: 16,
              color: isDark
                  ? AppColors.darkTextSecondary
                  : AppColors.lightTextSecondary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmailField(AppLanguage lang, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          ForgotPasswordLanguage.get('email_label', lang),
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
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          decoration: InputDecoration(
            hintText: ForgotPasswordLanguage.get('email_hint', lang),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return ForgotPasswordLanguage.get('field_required', lang);
            }
            if (!value.contains('@')) {
              return ForgotPasswordLanguage.get('invalid_email', lang);
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildSendOTPButton(AppLanguage lang) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _handleSendOTP,
        child: _isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : Text(ForgotPasswordLanguage.get('send_otp_button', lang)),
      ),
    );
  }

  Widget _buildBackToLogin(AppLanguage lang) {
    return Center(
      child: TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(ForgotPasswordLanguage.get('back_to_login', lang)),
      ),
    );
  }
}
