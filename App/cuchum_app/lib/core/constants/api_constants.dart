class ApiConstants {
  // static const String baseUrl = 'http://127.0.0.1:8080'; // macOS Desktop / localhost
  // static const String baseUrl = 'http://10.0.2.2:8080'; // Android Emulator
  static const String baseUrl =
      'https://api.cuchum.info.vn'; // Production server

  static const String apiVersion = '/api/v1';

  // ─── Client Identity ──────────────────────────────────────────────────────
  static const String userAgent = 'CucHumApp/1.0';

  // ─── Auth ─────────────────────────────────────────────────────────────────
  static const String login = '$apiVersion/auth/login';
  static const String refresh = '$apiVersion/auth/refresh';
  static const String logout = '$apiVersion/auth/logout';
  static const String forgotPassword = '$apiVersion/auth/forgot-password';
  static const String resetPassword = '$apiVersion/auth/reset-password';
  static const String changePassword = '$apiVersion/auth/change-password';
  static const String biometricLogin = '$apiVersion/auth/biometric-login';
  static const String biometricEnable = '$apiVersion/auth/biometric/enable';
  static const String biometricDisable = '$apiVersion/auth/biometric/disable';

  // ─── Users & Profile ──────────────────────────────────────────────────────
  static const String usersMe = '$apiVersion/users/me';
  static const String users = '$apiVersion/users';
  static const String profile = '$apiVersion/profile';

  // ─── Vehicles ─────────────────────────────────────────────────────────────
  static const String vehicles = '$apiVersion/vehicles';

  // ─── Trips ────────────────────────────────────────────────────────────────
  static const String trips = '$apiVersion/trips';
  static const String tripsSchedule = '$apiVersion/trips/schedule';

  // ─── Fuel Reports ─────────────────────────────────────────────────────────
  static const String fuelReports = '$apiVersion/fuel-reports';
  static const String fuelReportsExport = '$apiVersion/fuel-reports/export';

  // ─── Checklists ───────────────────────────────────────────────────────────
  static const String checklists = '$apiVersion/checklists';

  // ─── Incidents ────────────────────────────────────────────────────────────
  static const String incidents = '$apiVersion/incidents';

  // ─── Notifications ────────────────────────────────────────────────────────
  static const String notifications = '$apiVersion/notifications';
  static const String adminNotifications = '$apiVersion/admin/notifications';
  static const String notificationsUnreadCount =
      '$apiVersion/notifications/unread-count';
  static const String notificationsStream = '$apiVersion/notifications/stream';

  // ─── Device Tokens (FCM) ─────────────────────────────────────────────────
  static const String devicesRegister = '$apiVersion/devices/register';
  static const String devicesUnregister = '$apiVersion/devices/unregister';

  // ─── Upload ───────────────────────────────────────────────────────────────
  static const String upload = '$apiVersion/upload';

  // ─── Profile Update Requests (Admin review queue) ─────────────────────────
  static const String profileRequests = '$apiVersion/profile-requests';

  // ─── Contracts ────────────────────────────────────────────────────────────
  static const String contracts = '$apiVersion/contracts';

  // ─── Payslips ─────────────────────────────────────────────────────────────
  static const String payslips = '$apiVersion/payslips';

  // ─── Fuel Prices ──────────────────────────────────────────────────────────
  static const String prices = '$apiVersion/prices';

  // ─── System ───────────────────────────────────────────────────────────────
  static const String health = '/health';

  // ─── Headers ──────────────────────────────────────────────────────────────
  static const Map<String, String> defaultHeaders = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
    'User-Agent': userAgent,
  };
}
