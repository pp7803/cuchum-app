import '../constants/api_constants.dart';
import 'api_models.dart';
import 'api_service.dart';

class AuthService {
  final ApiService _apiService;

  AuthService(this._apiService);

  bool get isLoggedIn => _apiService.isLoggedIn;
  UserData? get currentUser => _apiService.currentUser;
  bool get hasBiometricToken => _apiService.hasBiometricToken;
  String? get accessToken => _apiService.accessToken;

  Future<ApiResponse<LoginResponse>> login(
    String identifier,
    String password,
  ) async {
    final response = await _apiService.post<LoginResponse>(
      ApiConstants.login,
      {'identifier': identifier, 'password': password},
      fromJson: LoginResponse.fromJson,
    );

    if (response.success && response.data != null) {
      await _apiService.saveTokens(
        response.data!.accessToken,
        response.data!.refreshToken,
      );
      await _apiService.saveUserData(response.data!.user);
    }

    return response;
  }

  Future<ApiResponse<void>> logout() async {
    final refreshToken = _apiService.refreshToken;
    if (refreshToken != null) {
      await _apiService.post(
        ApiConstants.logout,
        {'refresh_token': refreshToken},
        requireAuth: true,
      );
    }
    await _apiService.clearSession();
    return ApiResponse(success: true, message: 'Đăng xuất thành công');
  }

  Future<ApiResponse<RefreshTokenResponse>> refreshToken() async {
    final token = _apiService.refreshToken;
    if (token == null) {
      return ApiResponse(success: false, error: 'Không tìm thấy refresh token');
    }

    final response = await _apiService.post<RefreshTokenResponse>(
      ApiConstants.refresh,
      {'refresh_token': token},
      fromJson: RefreshTokenResponse.fromJson,
    );

    if (response.success && response.data != null) {
      await _apiService.saveTokens(
        response.data!.accessToken,
        response.data!.refreshToken,
      );
    }

    return response;
  }

  Future<ApiResponse<void>> forgotPassword(String email) async {
    return await _apiService.post(
      ApiConstants.forgotPassword,
      {'email': email},
    );
  }

  Future<ApiResponse<void>> resetPassword({
    required String email,
    required String otp,
    required String newPassword,
    required String confirmPassword,
  }) async {
    return await _apiService.post(ApiConstants.resetPassword, {
      'email': email,
      'otp': otp,
      'new_password': newPassword,
      'confirm_password': confirmPassword,
    });
  }

  Future<ApiResponse<void>> changePassword({
    required String currentPassword,
    required String newPassword,
    required String confirmPassword,
  }) async {
    return await _apiService.post(
      ApiConstants.changePassword,
      {
        'current_password': currentPassword,
        'new_password': newPassword,
        'confirm_password': confirmPassword,
      },
      requireAuth: true,
    );
  }

  // ─── Biometric Auth ────────────────────────────────────────────────────────

  /// True when API rejected the stored biometric token (invalid / expired / revoked).
  static bool isBiometricTokenRejectedResponse(ApiResponse<dynamic> response) {
    if (response.success) return false;
    final msg = (response.error ?? response.message ?? '').toLowerCase();
    if (msg.isEmpty) return false;
    if (msg.contains('biometric') &&
        (msg.contains('invalid') || msg.contains('expired'))) {
      return true;
    }
    return false;
  }

  /// Login using biometric token stored on device (PUBLIC - no access_token needed)
  Future<ApiResponse<LoginResponse>> biometricLogin() async {
    final token = _apiService.biometricToken;
    if (token == null || token.isEmpty) {
      return ApiResponse(success: false, error: 'Không tìm thấy biometric token');
    }

    final response = await _apiService.post<LoginResponse>(
      ApiConstants.biometricLogin,
      {'biometric_token': token},
      fromJson: LoginResponse.fromJson,
      requireAuth: false,
    );

    if (!response.success && isBiometricTokenRejectedResponse(response)) {
      // Token không còn hợp lệ trên server → xóa toàn bộ phiên cục bộ (JWT + user + biometric)
      await _apiService.clearSession();
    }

    if (response.success && response.data != null) {
      await _apiService.saveTokens(
        response.data!.accessToken,
        response.data!.refreshToken,
      );
      await _apiService.saveUserData(response.data!.user);
    }

    return response;
  }

  /// Enable biometric auth: call server, get back biometric_token, save to prefs
  Future<ApiResponse<EnableBiometricResponse>> enableBiometric() async {
    final response = await _apiService.post<EnableBiometricResponse>(
      ApiConstants.biometricEnable,
      {},
      fromJson: EnableBiometricResponse.fromJson,
      requireAuth: true,
    );

    if (response.success && response.data != null) {
      await _apiService.saveBiometricToken(response.data!.biometricToken);
    }

    return response;
  }

  /// Disable biometric auth: revoke server-side token + clear local token
  Future<ApiResponse<void>> disableBiometric() async {
    final response = await _apiService.delete(
      ApiConstants.biometricDisable,
      requireAuth: true,
    );

    if (response.success) {
      await _apiService.clearBiometricToken();
    }

    return response;
  }
}
