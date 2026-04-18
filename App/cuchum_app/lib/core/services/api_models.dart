class ApiResponse<T> {
  final bool success;
  final String? message;
  final String? error;
  final T? data;

  ApiResponse({required this.success, this.message, this.error, this.data});

  factory ApiResponse.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>)? fromJsonT, {
    T Function(List<dynamic>)? fromJsonList,
  }) {
    String? errorMessage = json['error'];
    if (errorMessage == null && json['data'] is String) {
      errorMessage = json['data'];
    }

    T? parsedData;
    if (json['data'] != null) {
      if (json['data'] is Map && fromJsonT != null) {
        parsedData = fromJsonT(json['data'] as Map<String, dynamic>);
      } else if (json['data'] is List && fromJsonList != null) {
        parsedData = fromJsonList(json['data'] as List<dynamic>);
      }
    }

    return ApiResponse(
      success: json['success'] ?? false,
      message: json['message'],
      error: errorMessage,
      data: parsedData,
    );
  }

  String get displayMessage => message ?? error ?? 'Unknown error';
}

// ─── Upload Response ─────────────────────────────────────────────────────────

class UploadResponse {
  final String fileUrl;
  final String fileName;
  final int fileSize;

  UploadResponse({
    required this.fileUrl,
    required this.fileName,
    required this.fileSize,
  });

  factory UploadResponse.fromJson(Map<String, dynamic> json) {
    return UploadResponse(
      fileUrl: json['file_url'] ?? '',
      fileName: json['file_name'] ?? '',
      fileSize: (json['file_size'] as num?)?.toInt() ?? 0,
    );
  }
}

// ─── Auth Models ────────────────────────────────────────────────────────────

class EnableBiometricResponse {
  final String biometricToken;
  final String expiresAt;

  EnableBiometricResponse({
    required this.biometricToken,
    required this.expiresAt,
  });

  factory EnableBiometricResponse.fromJson(Map<String, dynamic> json) {
    return EnableBiometricResponse(
      biometricToken: json['biometric_token'] ?? '',
      expiresAt: json['expires_at'] ?? '',
    );
  }
}

class LoginResponse {
  final String accessToken;
  final String refreshToken;
  final int expiresIn;
  final UserData user;

  LoginResponse({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresIn,
    required this.user,
  });

  factory LoginResponse.fromJson(Map<String, dynamic> json) {
    return LoginResponse(
      accessToken: json['access_token'] ?? '',
      refreshToken: json['refresh_token'] ?? '',
      expiresIn: json['expires_in'] ?? 0,
      user: UserData.fromJson(json['user'] ?? {}),
    );
  }
}

class RefreshTokenResponse {
  final String accessToken;
  final String refreshToken;
  final int expiresIn;

  RefreshTokenResponse({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresIn,
  });

  factory RefreshTokenResponse.fromJson(Map<String, dynamic> json) {
    return RefreshTokenResponse(
      accessToken: json['access_token'] ?? '',
      refreshToken: json['refresh_token'] ?? '',
      expiresIn: json['expires_in'] ?? 0,
    );
  }
}

// ─── User & Profile Models ───────────────────────────────────────────────────

class UserData {
  final String id;
  final String phoneNumber;
  final String? email;
  final String fullName;
  final String role;
  final String status;
  final String createdAt;
  final String updatedAt;

  UserData({
    required this.id,
    required this.phoneNumber,
    this.email,
    required this.fullName,
    required this.role,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isAdmin => role == 'ADMIN';
  bool get isDriver => role == 'DRIVER';
  bool get isActive => status == 'ACTIVE';

  factory UserData.fromJson(Map<String, dynamic> json) {
    return UserData(
      id: json['id'] ?? '',
      phoneNumber: json['phone_number'] ?? '',
      email: json['email'],
      fullName: json['full_name'] ?? '',
      role: json['role'] ?? '',
      status: json['status'] ?? '',
      createdAt: json['created_at'] ?? '',
      updatedAt: json['updated_at'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'phone_number': phoneNumber,
      'email': email,
      'full_name': fullName,
      'role': role,
      'status': status,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }
}

// ─── Profile Update Request ───────────────────────────────────────────────────

class ProfileUpdateRequestData {
  final String id;
  final String? driverName;
  final String? citizenId;
  final String? licenseClass;
  final String? licenseNumber;
  final String? address;
  final String? avatarUrl;
  final String? proofImageUrl;
  final String status; // PENDING | APPROVED | REJECTED
  final String? adminNote;
  final String createdAt;

  ProfileUpdateRequestData({
    required this.id,
    this.driverName,
    this.citizenId,
    this.licenseClass,
    this.licenseNumber,
    this.address,
    this.avatarUrl,
    this.proofImageUrl,
    required this.status,
    this.adminNote,
    required this.createdAt,
  });

  bool get isPending => status == 'PENDING';
  bool get isApproved => status == 'APPROVED';
  bool get isRejected => status == 'REJECTED';

  factory ProfileUpdateRequestData.fromJson(Map<String, dynamic> json) {
    return ProfileUpdateRequestData(
      id: json['id'] ?? '',
      driverName: json['driver_name'],
      citizenId: json['citizen_id'],
      licenseClass: json['license_class'],
      licenseNumber: json['license_number'],
      address: json['address'],
      avatarUrl: json['avatar_url'],
      proofImageUrl: json['proof_image_url'] as String?,
      status: json['status'] ?? 'PENDING',
      adminNote: json['admin_note'],
      createdAt: json['created_at'] ?? '',
    );
  }
}

// ─── Profile ─────────────────────────────────────────────────────────────────

class ProfileData {
  final String id;
  final String phoneNumber;
  final String? email;
  final String fullName;
  final String role;
  final String status;
  final String? citizenId;
  final String? licenseClass;
  final String? licenseNumber;
  final String? address;
  final String? avatarUrl;
  final String? createdAt;
  final String? updatedAt;
  final ProfileUpdateRequestData? pendingRequest;

  ProfileData({
    required this.id,
    required this.phoneNumber,
    this.email,
    required this.fullName,
    required this.role,
    required this.status,
    this.citizenId,
    this.licenseClass,
    this.licenseNumber,
    this.address,
    this.avatarUrl,
    this.createdAt,
    this.updatedAt,
    this.pendingRequest,
  });

  bool get isAdmin => role == 'ADMIN';
  bool get isDriver => role == 'DRIVER';
  bool get isActive => status == 'ACTIVE';
  bool get hasPendingRequest =>
      pendingRequest != null && pendingRequest!.isPending;

  factory ProfileData.fromJson(Map<String, dynamic> json) {
    return ProfileData(
      id: json['user_id'] ?? json['id'] ?? '',
      phoneNumber: json['phone_number'] ?? '',
      email: json['email'],
      fullName: json['full_name'] ?? '',
      role: json['role'] ?? '',
      status: json['status'] ?? '',
      citizenId: json['citizen_id'],
      licenseClass: json['license_class'],
      licenseNumber: json['license_number'],
      address: json['address'],
      avatarUrl: json['avatar_url'],
      createdAt: json['created_at'],
      updatedAt: json['updated_at'],
      pendingRequest: json['pending_request'] != null
          ? ProfileUpdateRequestData.fromJson(
              json['pending_request'] as Map<String, dynamic>,
            )
          : null,
    );
  }
}

// ─── Profile Update Request List ─────────────────────────────────────────────

class ProfileUpdateRequestListResponse {
  final List<ProfileUpdateRequestData> requests;
  final int total;

  ProfileUpdateRequestListResponse({required this.requests, this.total = 0});

  // API returns {"requests": [...], "total": N}
  factory ProfileUpdateRequestListResponse.fromJson(Map<String, dynamic> json) {
    final list = json['requests'] as List<dynamic>? ?? [];
    return ProfileUpdateRequestListResponse(
      requests: list
          .map(
            (e) => ProfileUpdateRequestData.fromJson(e as Map<String, dynamic>),
          )
          .toList(),
      total: json['total'] ?? 0,
    );
  }
}

// ─── User List Model ─────────────────────────────────────────────────────────

class UserListResponse {
  final List<UserData> users;
  final int total;

  UserListResponse({required this.users, this.total = 0});

  // API returns {"users": [...], "total": N, "page": N, "limit": N}
  factory UserListResponse.fromJson(Map<String, dynamic> json) {
    final list = json['users'] as List<dynamic>? ?? [];
    return UserListResponse(
      users: list
          .map((e) => UserData.fromJson(e as Map<String, dynamic>))
          .toList(),
      total: json['total'] ?? 0,
    );
  }
}

// ─── Vehicle Models ──────────────────────────────────────────────────────────

class VehicleData {
  final String id;

  /// Biển số xe (API: `license_plate`)
  final String licensePlate;

  /// Loại xe (API: `vehicle_type`)
  final String? vehicleType;
  final String status;

  /// Ảnh xe — đường dẫn tương đối, nối với base URL (API: `image_url`)
  final String? imageUrl;

  /// Hạn bảo hiểm
  final DateTime? insuranceExpiry;

  /// Hạn đăng kiểm (kiểm định) — API: `registration_expiry`
  final DateTime? registrationExpiry;
  final DateTime? lastMaintenanceDate;
  final DateTime? nextMaintenanceDate;

  VehicleData({
    required this.id,
    required this.licensePlate,
    this.vehicleType,
    required this.status,
    this.imageUrl,
    this.insuranceExpiry,
    this.registrationExpiry,
    this.lastMaintenanceDate,
    this.nextMaintenanceDate,
  });

  /// Alias cho UI cũ dùng `model`
  String? get model => vehicleType;

  static DateTime? _parseDate(dynamic v) {
    if (v == null) return null;
    if (v is! String || v.isEmpty) return null;
    final d = DateTime.tryParse(v);
    return d;
  }

  factory VehicleData.fromJson(Map<String, dynamic> json) {
    return VehicleData(
      id: json['id'] ?? '',
      licensePlate: json['license_plate'] ?? '',
      vehicleType: json['vehicle_type'] as String? ?? json['model'] as String?,
      status: json['status'] ?? '',
      imageUrl: json['image_url'] as String?,
      insuranceExpiry: _parseDate(json['insurance_expiry']),
      registrationExpiry: _parseDate(json['registration_expiry']),
      lastMaintenanceDate: _parseDate(json['last_maintenance_date']),
      nextMaintenanceDate: _parseDate(json['next_maintenance_date']),
    );
  }
}

class VehicleListResponse {
  final List<VehicleData> vehicles;

  VehicleListResponse({required this.vehicles});

  static VehicleListResponse fromJsonList(List<dynamic> list) {
    return VehicleListResponse(
      vehicles: list
          .map((e) => VehicleData.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

// ─── Trip Models ─────────────────────────────────────────────────────────────

class TripData {
  final String id;
  final String? driverId;
  final String? driverName;
  final String? vehicleId;
  final String? licensePlate;
  final int? startOdo;
  final int? endOdo;
  final double? startLat;
  final double? startLng;
  final double? endLat;
  final double? endLng;
  final String status;

  /// API: `start_time` (scheduled/ad-hoc start).
  final String? startedAt;

  /// API: `end_time`.
  final String? endedAt;
  final String? createdAt;
  final String? scheduledStartAt;
  final String? scheduledEndAt;
  final String? driverNote;
  final String? driverDeclineNote;

  /// Khi admin hủy chuyến.
  final String? adminCancelReason;
  final String? cancelledAt;
  final double? distanceKmFromApi;

  TripData({
    required this.id,
    this.driverId,
    this.driverName,
    this.vehicleId,
    this.licensePlate,
    this.startOdo,
    this.endOdo,
    this.startLat,
    this.startLng,
    this.endLat,
    this.endLng,
    required this.status,
    this.startedAt,
    this.endedAt,
    this.createdAt,
    this.scheduledStartAt,
    this.scheduledEndAt,
    this.driverNote,
    this.driverDeclineNote,
    this.adminCancelReason,
    this.cancelledAt,
    this.distanceKmFromApi,
  });

  bool get isOngoing => status == 'IN_PROGRESS' || status == 'ONGOING';

  bool get isCompleted => status == 'COMPLETED';

  bool get isCancelled => status == 'CANCELLED';

  /// Matches BE checklist: only after driver accepted the schedule.
  bool get isEligibleForChecklist =>
      status == 'DRIVER_ACCEPTED' ||
      status == 'IN_PROGRESS' ||
      status == 'ONGOING';

  /// Matches BE fuel `trip_id`: accepted or in progress.
  bool get canLinkFuelReport =>
      status == 'DRIVER_ACCEPTED' ||
      status == 'IN_PROGRESS' ||
      status == 'ONGOING';

  /// Khớp BE: báo xăng gắn chuyến trong [giờ dự kiến − 15p, + 30p] (local).
  bool get canAddTripLinkedFuelReport {
    if (!canLinkFuelReport) return false;
    final iso = scheduledStartAt;
    if (iso == null || iso.isEmpty) return false;
    try {
      final s = DateTime.parse(iso).toLocal();
      final now = DateTime.now();
      final w0 = s.subtract(const Duration(minutes: 15));
      final w1 = s.add(const Duration(minutes: 30));
      return !now.isBefore(w0) && !now.isAfter(w1);
    } catch (_) {
      return false;
    }
  }

  int get distanceKm {
    if (distanceKmFromApi != null) return distanceKmFromApi!.round();
    if (startOdo != null && endOdo != null) return endOdo! - startOdo!;
    return 0;
  }

  static String? _iso(dynamic v) {
    if (v == null) return null;
    if (v is String) return v;
    return v.toString();
  }

  factory TripData.fromJson(Map<String, dynamic> json) {
    return TripData(
      id: json['id'] ?? '',
      driverId: json['driver_id']?.toString(),
      driverName: json['driver_name'] as String?,
      vehicleId: json['vehicle_id']?.toString(),
      licensePlate: json['license_plate'] as String?,
      startOdo: (json['start_odo'] as num?)?.toInt(),
      endOdo: (json['end_odo'] as num?)?.toInt(),
      startLat: (json['start_lat'] as num?)?.toDouble(),
      startLng: (json['start_lng'] as num?)?.toDouble(),
      endLat: (json['end_lat'] as num?)?.toDouble(),
      endLng: (json['end_lng'] as num?)?.toDouble(),
      status: json['status']?.toString() ?? 'UNKNOWN',
      startedAt: _iso(json['start_time'] ?? json['started_at']),
      endedAt: _iso(json['end_time'] ?? json['ended_at']),
      createdAt: _iso(json['created_at']),
      scheduledStartAt: _iso(json['scheduled_start_at']),
      scheduledEndAt: _iso(json['scheduled_end_at']),
      driverNote: json['driver_note'] as String?,
      driverDeclineNote: json['driver_decline_note'] as String?,
      adminCancelReason: json['admin_cancel_reason'] as String?,
      cancelledAt: _iso(json['cancelled_at']),
      distanceKmFromApi: (json['distance_km'] as num?)?.toDouble(),
    );
  }
}

class TripListResponse {
  final List<TripData> trips;

  TripListResponse({required this.trips});

  static TripListResponse fromJsonList(List<dynamic> list) {
    return TripListResponse(
      trips: list
          .map((e) => TripData.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

// ─── Fuel Report Models ───────────────────────────────────────────────────────

class FuelReportData {
  final String id;
  final String? driverId;
  final String? driverName;
  final String? vehicleId;
  final String? tripId;
  final String? licensePlate;
  final String reportDate;
  final int? odoCurrent;
  final double? liters;
  final double totalCost;
  final String? receiptImageUrl;
  final String? odoImageUrl;
  final String? adminNote;
  final String? fuelPurchasedAt;
  final String? createdAt;

  FuelReportData({
    required this.id,
    this.driverId,
    this.driverName,
    this.vehicleId,
    this.tripId,
    this.licensePlate,
    required this.reportDate,
    this.odoCurrent,
    this.liters,
    required this.totalCost,
    this.receiptImageUrl,
    this.odoImageUrl,
    this.adminNote,
    this.fuelPurchasedAt,
    this.createdAt,
  });

  static String _reportDateStr(dynamic v) {
    if (v == null) return '';
    if (v is String) return v;
    return v.toString();
  }

  factory FuelReportData.fromJson(Map<String, dynamic> json) {
    final tc = json['total_cost'];
    return FuelReportData(
      id: json['id'] ?? '',
      driverId: json['driver_id']?.toString(),
      driverName: json['driver_name'] as String?,
      vehicleId: json['vehicle_id']?.toString(),
      tripId: json['trip_id']?.toString(),
      licensePlate: json['license_plate'] as String?,
      reportDate: _reportDateStr(json['report_date']),
      odoCurrent: (json['odo_current'] as num?)?.toInt(),
      liters: (json['liters'] as num?)?.toDouble(),
      totalCost: (tc is num) ? tc.toDouble() : double.tryParse('$tc') ?? 0,
      receiptImageUrl: json['receipt_image_url'] as String?,
      odoImageUrl: json['odo_image_url'] as String?,
      adminNote: json['admin_note'] as String?,
      fuelPurchasedAt: TripData._iso(json['fuel_purchased_at']),
      createdAt: json['created_at']?.toString(),
    );
  }
}

class FuelReportListResponse {
  final List<FuelReportData> reports;

  FuelReportListResponse({required this.reports});

  static FuelReportListResponse fromJsonList(List<dynamic> list) {
    return FuelReportListResponse(
      reports: list
          .map((e) => FuelReportData.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

// ─── Checklist Models ─────────────────────────────────────────────────────────

class ChecklistData {
  final String id;
  final String driverId;
  final String vehicleId;
  final String? tripId;
  final String checkDate;
  final bool tireCheck;
  final bool lightCheck;
  final bool cleanCheck;
  final bool brakeCheck;
  final bool oilCheck;
  final String? note;
  final String? createdAt;

  ChecklistData({
    required this.id,
    required this.driverId,
    required this.vehicleId,
    this.tripId,
    required this.checkDate,
    required this.tireCheck,
    required this.lightCheck,
    required this.cleanCheck,
    required this.brakeCheck,
    required this.oilCheck,
    this.note,
    this.createdAt,
  });

  factory ChecklistData.fromJson(Map<String, dynamic> json) {
    return ChecklistData(
      id: json['id'] ?? '',
      driverId: json['driver_id']?.toString() ?? '',
      vehicleId: json['vehicle_id']?.toString() ?? '',
      tripId: json['trip_id']?.toString(),
      checkDate: json['check_date']?.toString() ?? '',
      tireCheck: json['tire_check'] == true,
      lightCheck: json['light_check'] == true,
      cleanCheck: json['clean_check'] == true,
      brakeCheck: json['brake_check'] == true,
      oilCheck: json['oil_check'] == true,
      note: json['note'] as String?,
      createdAt: json['created_at']?.toString(),
    );
  }
}

class ChecklistListResponse {
  final List<ChecklistData> checklists;

  ChecklistListResponse({required this.checklists});

  static ChecklistListResponse fromJsonList(List<dynamic> list) {
    return ChecklistListResponse(
      checklists: list
          .map((e) => ChecklistData.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

// ─── Incident Models ─────────────────────────────────────────────────────────

class IncidentData {
  final String id;
  final String driverId;
  final String vehicleId;
  final String? tripId;
  final String type; // ACCIDENT | BREAKDOWN | TRAFFIC_TICKET
  final String? description;
  final String? imageUrl;
  final double? gpsLat;
  final double? gpsLng;
  final String? incidentDate;
  final String? createdAt;
  final String? adminNote;

  IncidentData({
    required this.id,
    required this.driverId,
    required this.vehicleId,
    this.tripId,
    required this.type,
    this.description,
    this.imageUrl,
    this.gpsLat,
    this.gpsLng,
    this.incidentDate,
    this.createdAt,
    this.adminNote,
  });

  factory IncidentData.fromJson(Map<String, dynamic> json) {
    return IncidentData(
      id: json['id']?.toString() ?? '',
      driverId: json['driver_id']?.toString() ?? '',
      vehicleId: json['vehicle_id']?.toString() ?? '',
      tripId: json['trip_id']?.toString(),
      type: (json['type'] ?? '').toString(),
      description: json['description'] as String?,
      imageUrl: json['image_url'] as String?,
      gpsLat: (json['gps_lat'] as num?)?.toDouble(),
      gpsLng: (json['gps_lng'] as num?)?.toDouble(),
      incidentDate: TripData._iso(json['incident_date']),
      createdAt: TripData._iso(json['created_at']),
      adminNote: json['admin_note'] as String?,
    );
  }
}

class IncidentListResponse {
  final List<IncidentData> incidents;

  IncidentListResponse({required this.incidents});

  static IncidentListResponse fromJsonList(List<dynamic> list) {
    return IncidentListResponse(
      incidents: list
          .map((e) => IncidentData.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

// ─── Notification Models ──────────────────────────────────────────────────────

/// UUID so sánh không phân biệt hoa/thường (SSE vs REST có thể khác casing → dedupe fail).
String _notificationIdFromJson(dynamic v) {
  if (v == null) return '';
  return v.toString().trim().toLowerCase();
}

class NotificationData {
  final String id;
  final String title;
  final String body;
  final bool isRead;
  final bool isAdminNotification;
  final String? createdAt;

  NotificationData({
    required this.id,
    required this.title,
    required this.body,
    required this.isRead,
    this.isAdminNotification = false,
    this.createdAt,
  });

  factory NotificationData.fromJson(Map<String, dynamic> json) {
    return NotificationData(
      id: _notificationIdFromJson(json['id']),
      title: json['title'] ?? '',
      body: json['body'] ?? '',
      isRead: json['is_read'] ?? false,
      isAdminNotification: json['is_admin_notification'] ?? false,
      createdAt: json['created_at'],
    );
  }
}

// ─── Contract Models ─────────────────────────────────────────────────────────

class ContractData {
  final String id;
  final String driverId;
  final String? driverName;
  final String contractNumber;
  final String fileUrl;
  final String startDate;
  final String? endDate;
  final bool isViewed;

  /// PENDING | ACKNOWLEDGED | DECLINED
  final String acknowledgmentStatus;
  final String? driverNote;
  final String? respondedAt;
  final String createdAt;

  ContractData({
    required this.id,
    required this.driverId,
    this.driverName,
    required this.contractNumber,
    required this.fileUrl,
    required this.startDate,
    this.endDate,
    this.isViewed = false,
    this.acknowledgmentStatus = 'PENDING',
    this.driverNote,
    this.respondedAt,
    required this.createdAt,
  });

  /// true if the contract has no end date OR end date is in the future
  bool get isActive {
    if (endDate == null || endDate!.isEmpty) return true;
    try {
      return DateTime.parse(endDate!).isAfter(DateTime.now());
    } catch (_) {
      return true;
    }
  }

  bool get canRespond => acknowledgmentStatus.toUpperCase() == 'PENDING';

  factory ContractData.fromJson(Map<String, dynamic> json) {
    final dn = json['driver_full_name'] ?? json['driver_name'];
    String? nameStr;
    if (dn is String) {
      nameStr = dn.trim().isEmpty ? null : dn.trim();
    } else if (dn != null) {
      final s = dn.toString().trim();
      nameStr = s.isEmpty ? null : s;
    }
    return ContractData(
      id: json['id']?.toString() ?? '',
      driverId: json['driver_id']?.toString() ?? '',
      driverName: nameStr,
      contractNumber: json['contract_number']?.toString() ?? '',
      fileUrl: json['file_url']?.toString() ?? '',
      startDate: json['start_date']?.toString() ?? '',
      endDate: json['end_date']?.toString(),
      isViewed: json['is_viewed'] == true,
      acknowledgmentStatus: (json['acknowledgment_status'] ?? 'PENDING')
          .toString()
          .toUpperCase(),
      driverNote: json['driver_note'] as String?,
      respondedAt: json['responded_at']?.toString(),
      createdAt: json['created_at']?.toString() ?? '',
    );
  }
}

class ContractListResponse {
  final List<ContractData> contracts;

  ContractListResponse({required this.contracts});

  static ContractListResponse fromJsonList(List<dynamic> list) {
    return ContractListResponse(
      contracts: list
          .map((e) => ContractData.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

// ─── Payslips ───────────────────────────────────────────────────────────────

class PayslipData {
  final String id;
  final String driverId;

  /// From API `driver_full_name`; falls back to [driverId] in [driverDisplayLabel].
  final String? driverFullName;
  final String salaryMonth;
  final String fileUrl;
  final bool isViewed;
  final String status;
  final String? note;
  final String? confirmedAt;
  final String createdAt;

  PayslipData({
    required this.id,
    required this.driverId,
    this.driverFullName,
    required this.salaryMonth,
    required this.fileUrl,
    required this.isViewed,
    required this.status,
    this.note,
    this.confirmedAt,
    required this.createdAt,
  });

  String get driverDisplayLabel {
    final n = driverFullName?.trim();
    if (n != null && n.isNotEmpty) return n;
    return driverId;
  }

  bool get canRespond {
    final s = status.toUpperCase();
    return s != 'CONFIRMED' && s != 'COMPLAINED';
  }

  factory PayslipData.fromJson(Map<String, dynamic> json) {
    final dn = json['driver_full_name'];
    return PayslipData(
      id: json['id']?.toString() ?? '',
      driverId: json['driver_id']?.toString() ?? '',
      driverFullName: dn is String ? (dn.isEmpty ? null : dn) : dn?.toString(),
      salaryMonth: json['salary_month']?.toString() ?? '',
      fileUrl: json['file_url'] ?? '',
      isViewed: json['is_viewed'] == true,
      status: (json['status'] ?? 'PENDING').toString().toUpperCase(),
      note: json['note'] as String?,
      confirmedAt: json['confirmed_at'] as String?,
      createdAt: json['created_at']?.toString() ?? '',
    );
  }
}

// ─── Fuel Prices ─────────────────────────────────────────────────────────────

class FuelPriceEntry {
  final String name;
  final String priceZone1;
  final String? priceZone2;

  FuelPriceEntry({
    required this.name,
    required this.priceZone1,
    this.priceZone2,
  });

  factory FuelPriceEntry.fromJson(Map<String, dynamic> json) => FuelPriceEntry(
    name: json['name'] ?? '',
    priceZone1: json['price_zone1'] ?? '',
    priceZone2: json['price_zone2'],
  );
}

class FuelCompanyPrices {
  final String company;
  final String updatedAt;
  final List<FuelPriceEntry> prices;

  FuelCompanyPrices({
    required this.company,
    required this.updatedAt,
    required this.prices,
  });

  factory FuelCompanyPrices.fromJson(Map<String, dynamic> json) =>
      FuelCompanyPrices(
        company: json['company'] ?? '',
        updatedAt: json['updated_at'] ?? '',
        prices: (json['prices'] as List<dynamic>? ?? [])
            .map((e) => FuelPriceEntry.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class FuelPricesData {
  final FuelCompanyPrices petrolimex;
  final FuelCompanyPrices pvoil;

  FuelPricesData({required this.petrolimex, required this.pvoil});

  factory FuelPricesData.fromJson(Map<String, dynamic> json) => FuelPricesData(
    petrolimex: FuelCompanyPrices.fromJson(
      json['petrolimex'] as Map<String, dynamic>,
    ),
    pvoil: FuelCompanyPrices.fromJson(json['pvoil'] as Map<String, dynamic>),
  );
}

class NotificationListResponse {
  final List<NotificationData> notifications;

  NotificationListResponse({required this.notifications});

  static NotificationListResponse fromJsonList(List<dynamic> list) {
    return NotificationListResponse(
      notifications: list
          .map((e) => NotificationData.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
