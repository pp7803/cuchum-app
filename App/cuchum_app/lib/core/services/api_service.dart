import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/api_constants.dart';
import 'api_models.dart';

class ApiService {
  static const String _accessTokenKey = 'access_token';
  static const String _refreshTokenKey = 'refresh_token';
  static const String _userDataKey = 'user_data';
  static const String _biometricTokenKey = 'biometric_token';

  final HttpClient _client = HttpClient();
  SharedPreferences? _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // ─── Token & Session ──────────────────────────────────────────────────────

  String? get accessToken => _prefs?.getString(_accessTokenKey);
  String? get refreshToken => _prefs?.getString(_refreshTokenKey);

  Future<void> saveTokens(String accessToken, String refreshToken) async {
    await _prefs?.setString(_accessTokenKey, accessToken);
    await _prefs?.setString(_refreshTokenKey, refreshToken);
  }

  Future<void> saveUserData(UserData user) async {
    await _prefs?.setString(_userDataKey, jsonEncode(user.toJson()));
  }

  UserData? get currentUser {
    final userData = _prefs?.getString(_userDataKey);
    if (userData != null) {
      return UserData.fromJson(jsonDecode(userData));
    }
    return null;
  }

  bool get isLoggedIn => accessToken != null && accessToken!.isNotEmpty;

  // ─── Biometric Token ──────────────────────────────────────────────────────

  String? get biometricToken => _prefs?.getString(_biometricTokenKey);
  bool get hasBiometricToken =>
      biometricToken != null && biometricToken!.isNotEmpty;

  Future<void> saveBiometricToken(String token) async {
    await _prefs?.setString(_biometricTokenKey, token);
  }

  Future<void> clearBiometricToken() async {
    await _prefs?.remove(_biometricTokenKey);
  }

  Future<void> clearSession() async {
    await _prefs?.remove(_accessTokenKey);
    await _prefs?.remove(_refreshTokenKey);
    await _prefs?.remove(_userDataKey);
    await _prefs?.remove(_biometricTokenKey);
  }

  // ─── HTTP Helpers ─────────────────────────────────────────────────────────

  Map<String, String> _buildHeaders({bool requireAuth = false}) {
    final headers = <String, String>{...ApiConstants.defaultHeaders};
    if (requireAuth && accessToken != null) {
      headers['Authorization'] = 'Bearer $accessToken';
    }
    return headers;
  }

  ApiResponse<T> _handleError<T>(Object e) {
    if (e is SocketException) {
      return ApiResponse(
        success: false,
        error: 'Không thể kết nối đến máy chủ',
      );
    } else if (e is HttpException) {
      return ApiResponse(success: false, error: 'Lỗi HTTP');
    } else if (e is FormatException) {
      return ApiResponse(success: false, error: 'Dữ liệu không hợp lệ');
    }
    return ApiResponse(success: false, error: e.toString());
  }

  // ─── GET ──────────────────────────────────────────────────────────────────

  Future<ApiResponse<T>> get<T>(
    String endpoint, {
    T Function(Map<String, dynamic>)? fromJson,
    T Function(List<dynamic>)? fromJsonList,
    bool requireAuth = true,
    Map<String, String>? queryParams,
  }) async {
    try {
      var uriString = '${ApiConstants.baseUrl}$endpoint';
      if (queryParams != null && queryParams.isNotEmpty) {
        final query = queryParams.entries
            .map(
              (e) =>
                  '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}',
            )
            .join('&');
        uriString = '$uriString?$query';
      }

      final uri = Uri.parse(uriString);
      final request = await _client.getUrl(uri);
      final headers = _buildHeaders(requireAuth: requireAuth);
      headers.forEach((k, v) => request.headers.set(k, v));

      final response = await request.close();
      final responseBody = await response.transform(utf8.decoder).join();
      final json = jsonDecode(responseBody) as Map<String, dynamic>;

      return ApiResponse.fromJson(json, fromJson, fromJsonList: fromJsonList);
    } catch (e) {
      return _handleError(e);
    }
  }

  // ─── POST ─────────────────────────────────────────────────────────────────

  Future<ApiResponse<T>> post<T>(
    String endpoint,
    Map<String, dynamic> body, {
    T Function(Map<String, dynamic>)? fromJson,
    T Function(List<dynamic>)? fromJsonList,
    bool requireAuth = false,
  }) async {
    try {
      final uri = Uri.parse('${ApiConstants.baseUrl}$endpoint');
      final request = await _client.postUrl(uri);
      final headers = _buildHeaders(requireAuth: requireAuth);
      headers.forEach((k, v) => request.headers.set(k, v));
      final bodyBytes = utf8.encode(jsonEncode(body));
      request.headers.contentLength = bodyBytes.length;
      request.add(bodyBytes);

      final response = await request.close();
      final responseBody = await response.transform(utf8.decoder).join();
      final json = jsonDecode(responseBody) as Map<String, dynamic>;

      return ApiResponse.fromJson(json, fromJson, fromJsonList: fromJsonList);
    } catch (e) {
      return _handleError(e);
    }
  }

  // ─── PUT ──────────────────────────────────────────────────────────────────

  Future<ApiResponse<T>> put<T>(
    String endpoint,
    Map<String, dynamic> body, {
    T Function(Map<String, dynamic>)? fromJson,
    T Function(List<dynamic>)? fromJsonList,
    bool requireAuth = true,
  }) async {
    try {
      final uri = Uri.parse('${ApiConstants.baseUrl}$endpoint');
      final request = await _client.putUrl(uri);
      final headers = _buildHeaders(requireAuth: requireAuth);
      headers.forEach((k, v) => request.headers.set(k, v));
      final bodyBytes = utf8.encode(jsonEncode(body));
      request.headers.contentLength = bodyBytes.length;
      request.add(bodyBytes);

      final response = await request.close();
      final responseBody = await response.transform(utf8.decoder).join();
      final json = jsonDecode(responseBody) as Map<String, dynamic>;

      return ApiResponse.fromJson(json, fromJson, fromJsonList: fromJsonList);
    } catch (e) {
      return _handleError(e);
    }
  }

  // ─── MULTIPART UPLOAD ────────────────────────────────────────────────────

  Future<ApiResponse<UploadResponse>> uploadFile(
    String filePath, {
    String? folder,
    String? vehicleId,
  }) async {
    try {
      final base = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.upload}');
      final qp = <String, String>{};
      if (folder != null && folder.isNotEmpty) qp['folder'] = folder;
      if (vehicleId != null && vehicleId.isNotEmpty) {
        qp['vehicle_id'] = vehicleId;
      }
      final url = qp.isEmpty
          ? base.toString()
          : base.replace(queryParameters: qp).toString();

      final request = http.MultipartRequest('POST', Uri.parse(url));
      request.headers['User-Agent'] = ApiConstants.userAgent;
      request.headers['Accept'] = 'application/json';
      if (accessToken != null) {
        request.headers['Authorization'] = 'Bearer $accessToken';
      }
      request.files.add(await http.MultipartFile.fromPath('file', filePath));

      final streamed = await request.send();
      final body = await streamed.stream.bytesToString();
      final json = jsonDecode(body) as Map<String, dynamic>;

      return ApiResponse.fromJson(json, UploadResponse.fromJson);
    } catch (e) {
      return _handleError(e);
    }
  }

  // ─── DELETE ───────────────────────────────────────────────────────────────

  Future<ApiResponse<T>> delete<T>(
    String endpoint, {
    T Function(Map<String, dynamic>)? fromJson,
    bool requireAuth = true,
  }) async {
    try {
      final uri = Uri.parse('${ApiConstants.baseUrl}$endpoint');
      final request = await _client.deleteUrl(uri);
      final headers = _buildHeaders(requireAuth: requireAuth);
      headers.forEach((k, v) => request.headers.set(k, v));

      final response = await request.close();
      final responseBody = await response.transform(utf8.decoder).join();
      final json = jsonDecode(responseBody) as Map<String, dynamic>;

      return ApiResponse.fromJson(json, fromJson);
    } catch (e) {
      return _handleError(e);
    }
  }

  // ─── PATCH ────────────────────────────────────────────────────────────────

  Future<ApiResponse<T>> patch<T>(
    String endpoint,
    Map<String, dynamic> body, {
    T Function(Map<String, dynamic>)? fromJson,
    T Function(List<dynamic>)? fromJsonList,
    bool requireAuth = true,
  }) async {
    try {
      final uri = Uri.parse('${ApiConstants.baseUrl}$endpoint');
      final request = await _client.patchUrl(uri);
      final headers = _buildHeaders(requireAuth: requireAuth);
      headers.forEach((k, v) => request.headers.set(k, v));
      final bodyBytes = utf8.encode(jsonEncode(body));
      request.headers.contentLength = bodyBytes.length;
      request.add(bodyBytes);

      final response = await request.close();
      final responseBody = await response.transform(utf8.decoder).join();
      final json = jsonDecode(responseBody) as Map<String, dynamic>;

      return ApiResponse.fromJson(json, fromJson, fromJsonList: fromJsonList);
    } catch (e) {
      return _handleError(e);
    }
  }
}
