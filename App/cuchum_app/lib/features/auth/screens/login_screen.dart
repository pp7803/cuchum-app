import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/trans/language_provider.dart';
import '../../../core/trans/login_language.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/biometric_service.dart';
import '../../../core/services/api_models.dart';
import '../../../core/services/fcm_service.dart';
import '../../../core/utils/alert_utils.dart';
import '../../../core/utils/keyboard_utils.dart';
import '../../home/screens/main_shell.dart';
import 'forgot_password_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;
  bool _showBiometricButton = false;
  String _biometricLabel = 'Sinh trắc học';
  UserData? _savedUser;

  @override
  void initState() {
    super.initState();
    _checkBiometricAvailability();
  }

  Future<void> _checkBiometricAvailability() async {
    final authService = Provider.of<AuthService>(context, listen: false);

    // Pre-fill saved account info
    final savedUser = authService.currentUser;
    if (savedUser != null) {
      final identifier = savedUser.phoneNumber.isNotEmpty
          ? savedUser.phoneNumber
          : (savedUser.email ?? '');
      if (mounted) {
        setState(() {
          _savedUser = savedUser;
          _identifierController.text = identifier;
        });
      }
    }

    // Show biometric button only when saved user matches saved biometric token
    final hasBiometricToken = authService.hasBiometricToken;
    final deviceSupports = await BiometricService.isAvailable();
    if (hasBiometricToken && deviceSupports) {
      final label = await BiometricService.getBiometricLabel();
      if (mounted) {
        setState(() {
          _showBiometricButton = true;
          _biometricLabel = label;
        });
      }
    }
  }

  Future<void> _registerDeviceTokenAfterLogin() async {
    final token = FCMService().fcmToken;
    if (token == null || token.isEmpty) {
      debugPrint(
        'Skip device token registration after login: FCM token unavailable',
      );
      return;
    }

    final apiService = Provider.of<ApiService>(context, listen: false);
    final platform = Theme.of(context).platform == TargetPlatform.iOS
        ? 'ios'
        : Theme.of(context).platform == TargetPlatform.macOS
        ? 'macos'
        : 'android';

    final response = await apiService.post<void>(ApiConstants.devicesRegister, {
      'token': token,
      'platform': platform,
    }, requireAuth: true);

    if (response.success) {
      debugPrint('Device token registered after login');
    } else {
      debugPrint(
        'Device token registration after login failed: ${response.displayMessage}',
      );
    }
  }

  /// Full sign-out from login screen: clear all local tokens + user data
  Future<void> _signOutFromLoginScreen() async {
    final lang = Provider.of<LanguageProvider>(context, listen: false).language;
    final isDark = Provider.of<ThemeProvider>(
      context,
      listen: false,
    ).isDarkMode;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          LoginLanguage.get('switch_account_confirm', lang),
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isDark ? AppColors.darkText : AppColors.lightText,
          ),
        ),
        content: Text(
          LoginLanguage.get('switch_account_body', lang),
          style: TextStyle(
            color: isDark
                ? AppColors.darkTextSecondary
                : AppColors.lightTextSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              minimumSize: Size.zero,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
            child: Text(LoginLanguage.get('switch_account_yes', lang)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final authService = Provider.of<AuthService>(context, listen: false);
      // Revoke refresh token on server if available
      await authService.logout();
      if (!mounted) return;
      setState(() {
        _savedUser = null;
        _showBiometricButton = false;
        _identifierController.clear();
        _passwordController.clear();
      });
    }
  }

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _handleLogin() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      final authService = Provider.of<AuthService>(context, listen: false);
      final response = await authService.login(
        _identifierController.text.trim(),
        _passwordController.text,
      );

      setState(() => _isLoading = false);

      if (!mounted) return;

      if (response.success) {
        await _registerDeviceTokenAfterLogin();
        AlertUtils.success(context, response.displayMessage);
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const MainShell()),
          (_) => false,
        );
      } else {
        AlertUtils.error(context, response.displayMessage);
      }
    }
  }

  void _handleForgotPassword() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ForgotPasswordScreen()),
    );
  }

  Future<void> _handleBiometricLogin() async {
    setState(() => _isLoading = true);

    final authenticated = await BiometricService.authenticate(
      reason: 'Xác thực để đăng nhập vào CucHum',
    );

    if (!authenticated) {
      setState(() => _isLoading = false);
      if (mounted) {
        AlertUtils.error(context, 'Xác thực sinh trắc học thất bại');
      }
      return;
    }

    final authService = Provider.of<AuthService>(context, listen: false);
    final response = await authService.biometricLogin();

    setState(() => _isLoading = false);

    if (!mounted) return;

    if (response.success) {
      await _registerDeviceTokenAfterLogin();
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const MainShell()),
        (_) => false,
      );
    } else {
      await _checkBiometricAvailability();
      if (!mounted) return;
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
                  // Header
                  _buildHeader(themeProvider, languageProvider, isDark),
                  const SizedBox(height: 48),
                  // Logo
                  _buildLogo(),
                  const SizedBox(height: 32),
                  // Welcome / saved-account greeting
                  _savedUser != null
                      ? _buildSavedAccountCard(lang, isDark)
                      : _buildWelcomeText(lang, isDark),
                  const SizedBox(height: 40),
                  // Form fields
                  _buildIdentifierField(lang, isDark),
                  const SizedBox(height: 24),
                  _buildPasswordField(lang, isDark),
                  const SizedBox(height: 12),
                  // Forgot password
                  _buildForgotPassword(lang),
                  const SizedBox(height: 32),
                  // Login button
                  _buildLoginButton(lang),
                  // Biometric login (shown only if token exists & device supports)
                  if (_showBiometricButton) ...[
                    const SizedBox(height: 16),
                    _buildBiometricButton(isDark),
                  ],
                  const SizedBox(height: 24),
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
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        // Language switcher
        _buildLanguageSwitcher(languageProvider, isDark),
        const SizedBox(width: 12),
        // Theme toggle
        _buildThemeToggle(themeProvider, isDark),
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
      child: ClipOval(
        child: Image.asset(
          'lib/assets/images/icon.png',
          width: 120,
          height: 120,
          fit: BoxFit.cover,
        ),
      ),
    );
  }

  Widget _buildWelcomeText(AppLanguage lang, bool isDark) {
    return Column(
      children: [
        Center(
          child: Text(
            LoginLanguage.get('welcome_title', lang),
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
            LoginLanguage.get('welcome_subtitle', lang),
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

  Widget _buildSavedAccountCard(AppLanguage lang, bool isDark) {
    final user = _savedUser!;
    final name = user.fullName;
    final initials = name
        .trim()
        .split(' ')
        .map((w) => w.isNotEmpty ? w[0] : '')
        .take(2)
        .join()
        .toUpperCase();
    final isAdmin = user.isAdmin;
    final avatarColor = isAdmin ? AppColors.primary : const Color(0xFF059669);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Avatar
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: avatarColor.withValues(alpha: 0.15),
            border: Border.all(
              color: avatarColor.withValues(alpha: 0.4),
              width: 2,
            ),
          ),
          child: Center(
            child: Text(
              initials.isEmpty ? '?' : initials,
              style: TextStyle(
                color: avatarColor,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        // Greeting row
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              LoginLanguage.get('saved_greeting', lang),
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w400,
                color: isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.lightTextSecondary,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              name,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: isDark ? AppColors.darkText : AppColors.lightText,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        // Sign-out underline link
        GestureDetector(
          onTap: _signOutFromLoginScreen,
          child: Text(
            LoginLanguage.get('switch_account', lang),
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppColors.error,
              decoration: TextDecoration.underline,
              decorationColor: AppColors.error,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildIdentifierField(AppLanguage lang, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          LoginLanguage.get('identifier_label', lang),
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
          controller: _identifierController,
          keyboardType: TextInputType.emailAddress,
          enabled: _savedUser == null, // lock field when session is pre-filled
          decoration: InputDecoration(
            hintText: LoginLanguage.get('identifier_hint', lang),
            suffixIcon: _savedUser != null
                ? const Icon(
                    Icons.lock_outline_rounded,
                    size: 18,
                    color: AppColors.primary,
                  )
                : null,
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return LoginLanguage.get('field_required', lang);
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildPasswordField(AppLanguage lang, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          LoginLanguage.get('password_label', lang),
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
          controller: _passwordController,
          obscureText: _obscurePassword,
          decoration: InputDecoration(
            hintText: LoginLanguage.get('password_hint', lang),
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                color: AppColors.primary,
              ),
              onPressed: () {
                setState(() => _obscurePassword = !_obscurePassword);
              },
            ),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return LoginLanguage.get('field_required', lang);
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildForgotPassword(AppLanguage lang) {
    return Align(
      alignment: Alignment.centerRight,
      child: TextButton(
        onPressed: _handleForgotPassword,
        child: Text(LoginLanguage.get('forgot_password', lang)),
      ),
    );
  }

  Widget _buildLoginButton(AppLanguage lang) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _handleLogin,
        child: _isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : Text(LoginLanguage.get('login_button', lang)),
      ),
    );
  }

  Widget _buildBiometricButton(bool isDark) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Divider(
                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                'hoặc',
                style: TextStyle(
                  fontSize: 13,
                  color: isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.lightTextSecondary,
                ),
              ),
            ),
            Expanded(
              child: Divider(
                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          height: 56,
          child: OutlinedButton.icon(
            onPressed: _isLoading ? null : _handleBiometricLogin,
            icon: const Icon(Icons.fingerprint_rounded, size: 24),
            label: Text(
              'Đăng nhập bằng $_biometricLabel',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              side: const BorderSide(color: AppColors.primary, width: 1.5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
