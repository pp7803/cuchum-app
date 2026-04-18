import '../constants/api_constants.dart';
import 'api_models.dart';
import 'api_service.dart';

class UserService {
  final ApiService _api;

  UserService(this._api);

  // ─── Profile ──────────────────────────────────────────────────────────────

  Future<ApiResponse<ProfileData>> getProfile() async {
    return await _api.get<ProfileData>(
      ApiConstants.profile,
      fromJson: ProfileData.fromJson,
    );
  }

  /// Upload an image file to the server and return the public URL.
  Future<ApiResponse<UploadResponse>> uploadFile(
    String filePath, {
    String? folder,
    String? vehicleId,
  }) async {
    return await _api.uploadFile(
      filePath,
      folder: folder,
      vehicleId: vehicleId,
    );
  }

  /// Submit a profile update. For DRIVER: creates a pending request (202).
  /// For ADMIN: applies directly (200). Always returns the updated ProfileData
  /// by doing a fresh GET after the PUT.
  Future<ApiResponse<void>> updateProfile({
    String? citizenId,
    String? licenseClass,
    String? licenseNumber,
    String? address,
    String? avatarUrl,
    String? proofImageUrl,
  }) async {
    final body = <String, dynamic>{};
    if (citizenId != null) body['citizen_id'] = citizenId;
    if (licenseClass != null) body['license_class'] = licenseClass;
    if (licenseNumber != null) body['license_number'] = licenseNumber;
    if (address != null) body['address'] = address;
    if (avatarUrl != null) body['avatar_url'] = avatarUrl;
    if (proofImageUrl != null && proofImageUrl.isNotEmpty) {
      body['proof_image_url'] = proofImageUrl;
    }

    return await _api.put<void>(ApiConstants.profile, body);
  }

  // ─── Profile Update Requests (Admin) ─────────────────────────────────────

  Future<ApiResponse<ProfileUpdateRequestListResponse>> getProfileRequests({
    String? status,
    int page = 1,
    int limit = 20,
  }) async {
    final params = <String, String>{'page': '$page', 'limit': '$limit'};
    if (status != null) params['status'] = status;

    return await _api.get<ProfileUpdateRequestListResponse>(
      ApiConstants.profileRequests,
      fromJson: ProfileUpdateRequestListResponse.fromJson,
      queryParams: params,
    );
  }

  Future<ApiResponse<void>> reviewProfileRequest(
    String requestId, {
    required String status, // APPROVED | REJECTED
    String? adminNote,
  }) async {
    final body = <String, dynamic>{'status': status};
    if (adminNote != null) body['admin_note'] = adminNote;

    return await _api.patch<void>(
      '${ApiConstants.profileRequests}/$requestId/review',
      body,
    );
  }

  Future<ApiResponse<UserData>> getMe() async {
    return await _api.get<UserData>(
      ApiConstants.usersMe,
      fromJson: UserData.fromJson,
    );
  }

  // ─── Users (Admin only) ───────────────────────────────────────────────────

  Future<ApiResponse<UserListResponse>> getUsers({
    String? status,
    int page = 1,
    int limit = 50,
  }) async {
    final params = <String, String>{
      'page': page.toString(),
      'limit': limit.toString(),
    };
    if (status != null) params['status'] = status;

    return await _api.get<UserListResponse>(
      ApiConstants.users,
      fromJson: UserListResponse.fromJson,
      queryParams: params,
    );
  }

  Future<ApiResponse<void>> updateUserStatus(
    String userId,
    String status,
  ) async {
    return await _api.patch('${ApiConstants.users}/$userId/status', {
      'status': status,
    });
  }

  Future<ApiResponse<UserData>> createUser({
    required String phoneNumber,
    required String fullName,
    required String password,
    String? email,
    String role = 'DRIVER',
    String? citizenId,
    String? licenseClass,
    String? licenseNumber,
    String? address,
  }) async {
    final body = <String, dynamic>{
      'phone_number': phoneNumber,
      'full_name': fullName,
      'password': password,
      'role': role,
    };
    if (email != null && email.isNotEmpty) body['email'] = email;
    if (citizenId != null && citizenId.isNotEmpty)
      body['citizen_id'] = citizenId;
    if (licenseClass != null && licenseClass.isNotEmpty)
      body['license_class'] = licenseClass;
    if (licenseNumber != null && licenseNumber.isNotEmpty) {
      body['license_number'] = licenseNumber;
    }
    if (address != null && address.isNotEmpty) body['address'] = address;

    return await _api.post<UserData>(
      ApiConstants.users,
      body,
      fromJson: UserData.fromJson,
      requireAuth: true,
    );
  }

  Future<ApiResponse<void>> resetUserPassword(
    String userId,
    String newPassword,
  ) async {
    return await _api.patch('${ApiConstants.users}/$userId/password', {
      'new_password': newPassword,
    });
  }

  Future<ApiResponse<ProfileData>> getUserProfile(String userId) async {
    return await _api.get<ProfileData>(
      '${ApiConstants.users}/$userId/profile',
      fromJson: ProfileData.fromJson,
    );
  }

  // ─── Contracts ────────────────────────────────────────────────────────────

  /// [driverId] omit for DRIVER (own contracts). ADMIN must pass target driver id.
  /// ADMIN optional [acknowledgmentStatus]: PENDING | ACKNOWLEDGED | DECLINED
  Future<ApiResponse<ContractListResponse>> getContracts({
    String? driverId,
    String? acknowledgmentStatus,
  }) async {
    final params = <String, String>{};
    if (driverId != null && driverId.isNotEmpty) params['driver_id'] = driverId;
    if (acknowledgmentStatus != null && acknowledgmentStatus.isNotEmpty) {
      params['acknowledgment_status'] = acknowledgmentStatus;
    }
    return await _api.get<ContractListResponse>(
      ApiConstants.contracts,
      fromJsonList: ContractListResponse.fromJsonList,
      queryParams: params.isEmpty ? null : params,
    );
  }

  Future<ApiResponse<void>> markContractViewed(String contractId) async {
    return await _api.patch<void>(
      '${ApiConstants.contracts}/$contractId/view',
      {},
    );
  }

  Future<ApiResponse<void>> respondContract(
    String contractId, {
    required String status,
    String? note,
  }) async {
    final body = <String, dynamic>{'status': status};
    if (note != null && note.isNotEmpty) body['note'] = note;
    return await _api.patch<void>(
      '${ApiConstants.contracts}/$contractId/respond',
      body,
    );
  }

  Future<ApiResponse<ContractData>> createContract({
    required String driverId,
    required String contractNumber,
    required String fileUrl,
    required String startDate,
    String? endDate,
  }) async {
    final body = <String, dynamic>{
      'driver_id': driverId,
      'contract_number': contractNumber,
      'file_url': fileUrl,
      'start_date': startDate,
    };
    if (endDate != null && endDate.isNotEmpty) body['end_date'] = endDate;
    return await _api.post<ContractData>(
      ApiConstants.contracts,
      body,
      fromJson: ContractData.fromJson,
      requireAuth: true,
    );
  }

  // ─── Payslips ─────────────────────────────────────────────────────────────

  /// ADMIN: [driverId] lọc theo tài xế (BE `?driver_id=`). DRIVER: bỏ qua [driverId].
  Future<ApiResponse<List<PayslipData>>> getPayslips({
    String? month,
    String? driverId,
  }) async {
    final params = <String, String>{};
    if (month != null && month.isNotEmpty) params['month'] = month;
    if (driverId != null && driverId.isNotEmpty) params['driver_id'] = driverId;
    return await _api.get<List<PayslipData>>(
      ApiConstants.payslips,
      fromJsonList: (list) => list
          .map((e) => PayslipData.fromJson(e as Map<String, dynamic>))
          .toList(),
      queryParams: params.isEmpty ? null : params,
    );
  }

  Future<ApiResponse<void>> markPayslipViewed(String payslipId) async {
    return await _api.patch<void>(
      '${ApiConstants.payslips}/$payslipId/view',
      {},
    );
  }

  Future<ApiResponse<void>> confirmPayslip(
    String payslipId, {
    required String status,
    String? note,
  }) async {
    final body = <String, dynamic>{'status': status};
    if (note != null && note.isNotEmpty) body['note'] = note;
    return await _api.patch<void>(
      '${ApiConstants.payslips}/$payslipId/confirm',
      body,
    );
  }

  Future<ApiResponse<PayslipData>> createPayslip({
    required String driverId,
    required String salaryMonth,
    required String fileUrl,
  }) async {
    return await _api.post<PayslipData>(
      ApiConstants.payslips,
      {'driver_id': driverId, 'salary_month': salaryMonth, 'file_url': fileUrl},
      fromJson: PayslipData.fromJson,
      requireAuth: true,
    );
  }

  // ─── Vehicles ─────────────────────────────────────────────────────────────

  Future<ApiResponse<VehicleListResponse>> getVehicles({String? status}) async {
    final params = <String, String>{};
    if (status != null) params['status'] = status;

    return await _api.get<VehicleListResponse>(
      ApiConstants.vehicles,
      fromJsonList: VehicleListResponse.fromJsonList,
      queryParams: params.isEmpty ? null : params,
    );
  }

  /// ADMIN — tạo xe; ảnh upload sau khi có `id`: `uploadFile(..., folder: 'vehicles', vehicleId: id)`.
  Future<ApiResponse<VehicleData>> createVehicle(
    Map<String, dynamic> body,
  ) async {
    return await _api.post<VehicleData>(
      ApiConstants.vehicles,
      body,
      fromJson: VehicleData.fromJson,
      requireAuth: true,
    );
  }

  /// ADMIN — cập nhật xe (PATCH: chỉ gửi trường cần đổi; có thể gửi đủ snapshot từ form).
  Future<ApiResponse<void>> updateVehicle(
    String id,
    Map<String, dynamic> body,
  ) async {
    return await _api.patch<void>(
      '${ApiConstants.vehicles}/$id',
      body,
      requireAuth: true,
    );
  }

  /// ADMIN — xóa xe (lỗi nếu còn chuyến IN_PROGRESS hoặc lịch SCHEDULED_PENDING/DRIVER_ACCEPTED chưa quá scheduled_end_at).
  Future<ApiResponse<void>> deleteVehicle(String id) async {
    return await _api.delete<void>(
      '${ApiConstants.vehicles}/$id',
      requireAuth: true,
    );
  }

  // ─── Trips ────────────────────────────────────────────────────────────────

  /// Query matches BE: `start_date`, `end_date` (YYYY-MM-DD), optional `status`, `vehicle_id`, `driver_id` (admin).
  /// If [date] is set, both `start_date` and `end_date` are set to that day (driver “today” view).
  Future<ApiResponse<TripListResponse>> getTrips({
    String? driverId,
    String? date,
    String? startDate,
    String? endDate,
    String? status,
    String? vehicleId,
  }) async {
    final params = <String, String>{};
    if (driverId != null && driverId.isNotEmpty) params['driver_id'] = driverId;
    if (date != null && date.isNotEmpty) {
      params['start_date'] = date;
      params['end_date'] = date;
    } else {
      if (startDate != null && startDate.isNotEmpty)
        params['start_date'] = startDate;
      if (endDate != null && endDate.isNotEmpty) params['end_date'] = endDate;
    }
    if (status != null && status.isNotEmpty) params['status'] = status;
    if (vehicleId != null && vehicleId.isNotEmpty)
      params['vehicle_id'] = vehicleId;

    return await _api.get<TripListResponse>(
      ApiConstants.trips,
      fromJsonList: TripListResponse.fromJsonList,
      queryParams: params.isEmpty ? null : params,
    );
  }

  /// Chi tiết một chuyến (DRIVER: chỉ chuyến của mình; có `license_plate`, `driver_name`).
  Future<ApiResponse<TripData>> getTrip(String tripId) async {
    return await _api.get<TripData>(
      '${ApiConstants.trips}/$tripId',
      fromJson: TripData.fromJson,
      requireAuth: true,
    );
  }

  Future<ApiResponse<TripData>> scheduleTrip({
    required String driverId,
    required String vehicleId,
    required String scheduledStartAt,
    String? scheduledEndAt,
    String? driverNote,
  }) async {
    final body = <String, dynamic>{
      'driver_id': driverId,
      'vehicle_id': vehicleId,
      'scheduled_start_at': scheduledStartAt,
    };
    if (scheduledEndAt != null && scheduledEndAt.isNotEmpty) {
      body['scheduled_end_at'] = scheduledEndAt;
    }
    if (driverNote != null && driverNote.isNotEmpty)
      body['driver_note'] = driverNote;
    return await _api.post<TripData>(
      ApiConstants.tripsSchedule,
      body,
      fromJson: TripData.fromJson,
      requireAuth: true,
    );
  }

  Future<ApiResponse<TripData>> respondTrip(
    String tripId, {
    required String status,
    String? declineNote,
  }) async {
    final body = <String, dynamic>{'status': status};
    if (declineNote != null && declineNote.isNotEmpty) {
      body['decline_note'] = declineNote;
    }
    return await _api.patch<TripData>(
      '${ApiConstants.trips}/$tripId/respond',
      body,
      fromJson: TripData.fromJson,
      requireAuth: true,
    );
  }

  Future<ApiResponse<TripData>> startScheduledTrip(
    String tripId, {
    int? startOdo,
    double? startLat,
    double? startLng,
  }) async {
    final body = <String, dynamic>{};
    if (startOdo != null) body['start_odo'] = startOdo;
    if (startLat != null) body['start_lat'] = startLat;
    if (startLng != null) body['start_lng'] = startLng;
    return await _api.post<TripData>(
      '${ApiConstants.trips}/$tripId/start',
      body,
      fromJson: TripData.fromJson,
      requireAuth: true,
    );
  }

  Future<ApiResponse<TripData>> endTrip(
    String tripId, {
    int? endOdo,
    double? endLat,
    double? endLng,
  }) async {
    final body = <String, dynamic>{};
    if (endOdo != null) body['end_odo'] = endOdo;
    if (endLat != null) body['end_lat'] = endLat;
    if (endLng != null) body['end_lng'] = endLng;
    return await _api.patch<TripData>(
      '${ApiConstants.trips}/$tripId/end',
      body,
      fromJson: TripData.fromJson,
      requireAuth: true,
    );
  }

  /// ADMIN: hủy chuyến (có lý do; tài xế nhận thông báo).
  Future<ApiResponse<TripData>> cancelTripAsAdmin(
    String tripId, {
    required String reason,
  }) async {
    return await _api.patch<TripData>(
      '${ApiConstants.trips}/$tripId/cancel',
      {'reason': reason},
      fromJson: TripData.fromJson,
      requireAuth: true,
    );
  }

  // ─── Fuel Reports ─────────────────────────────────────────────────────────

  Future<ApiResponse<FuelReportListResponse>> getFuelReports({
    String? driverId,
    String? vehicleId,
    String? date,
    String? tripId,
  }) async {
    final params = <String, String>{};
    if (driverId != null) params['driver_id'] = driverId;
    if (vehicleId != null) params['vehicle_id'] = vehicleId;
    if (date != null) params['date'] = date;
    if (tripId != null && tripId.isNotEmpty) params['trip_id'] = tripId;

    return await _api.get<FuelReportListResponse>(
      ApiConstants.fuelReports,
      fromJsonList: FuelReportListResponse.fromJsonList,
      queryParams: params.isEmpty ? null : params,
    );
  }

  Future<ApiResponse<FuelReportData>> createFuelReport({
    required String vehicleId,
    String? tripId,
    String? reportDate,
    int? odoCurrent,
    double? liters,
    required double totalCost,
    required String receiptImageUrl,
    String? odoImageUrl,
    double? gpsLatitude,
    double? gpsLongitude,
  }) async {
    final body = <String, dynamic>{
      'vehicle_id': vehicleId,
      'total_cost': totalCost,
      'receipt_image_url': receiptImageUrl,
    };
    if (tripId != null && tripId.isNotEmpty) body['trip_id'] = tripId;
    if (reportDate != null && reportDate.isNotEmpty)
      body['report_date'] = reportDate;
    if (odoCurrent != null) body['odo_current'] = odoCurrent;
    if (liters != null) body['liters'] = liters;
    if (odoImageUrl != null && odoImageUrl.isNotEmpty)
      body['odo_image_url'] = odoImageUrl;
    if (gpsLatitude != null) body['gps_latitude'] = gpsLatitude;
    if (gpsLongitude != null) body['gps_longitude'] = gpsLongitude;
    return await _api.post<FuelReportData>(
      ApiConstants.fuelReports,
      body,
      fromJson: FuelReportData.fromJson,
      requireAuth: true,
    );
  }

  Future<ApiResponse<void>> updateFuelReportAdminNote(
    String reportId,
    String adminNote,
  ) async {
    return await _api.patch<void>('${ApiConstants.fuelReports}/$reportId', {
      'admin_note': adminNote,
    }, requireAuth: true);
  }

  // ─── Checklists ───────────────────────────────────────────────────────────

  Future<ApiResponse<ChecklistListResponse>> getChecklists({
    String? vehicleId,
    String? date,
    String? tripId,
  }) async {
    final params = <String, String>{};
    if (vehicleId != null && vehicleId.isNotEmpty)
      params['vehicle_id'] = vehicleId;
    if (date != null && date.isNotEmpty) params['date'] = date;
    if (tripId != null && tripId.isNotEmpty) params['trip_id'] = tripId;
    return await _api.get<ChecklistListResponse>(
      ApiConstants.checklists,
      fromJsonList: ChecklistListResponse.fromJsonList,
      queryParams: params.isEmpty ? null : params,
    );
  }

  Future<ApiResponse<ChecklistData>> createChecklist({
    required String vehicleId,
    required String tripId,
    required bool tireCheck,
    required bool lightCheck,
    required bool cleanCheck,
    required bool brakeCheck,
    required bool oilCheck,
    String? note,
  }) async {
    final body = <String, dynamic>{
      'vehicle_id': vehicleId,
      'trip_id': tripId,
      'tire_check': tireCheck,
      'light_check': lightCheck,
      'clean_check': cleanCheck,
      'brake_check': brakeCheck,
      'oil_check': oilCheck,
    };
    if (note != null && note.isNotEmpty) body['note'] = note;
    return await _api.post<ChecklistData>(
      ApiConstants.checklists,
      body,
      fromJson: ChecklistData.fromJson,
      requireAuth: true,
    );
  }

  // ─── Incidents ───────────────────────────────────────────────────────────

  Future<ApiResponse<IncidentListResponse>> getIncidents({
    String? type,
    String? tripId,
  }) async {
    final params = <String, String>{};
    if (type != null && type.isNotEmpty) params['type'] = type;
    if (tripId != null && tripId.isNotEmpty) params['trip_id'] = tripId;
    return await _api.get<IncidentListResponse>(
      ApiConstants.incidents,
      fromJsonList: IncidentListResponse.fromJsonList,
      queryParams: params.isEmpty ? null : params,
    );
  }

  Future<ApiResponse<void>> createIncident({
    required String vehicleId,
    required String type, // ACCIDENT | BREAKDOWN | TRAFFIC_TICKET
    String? tripId,
    String? description,
    String? imageUrl,
  }) async {
    final body = <String, dynamic>{'vehicle_id': vehicleId, 'type': type};
    if (tripId != null && tripId.isNotEmpty) body['trip_id'] = tripId;
    if (description != null && description.isNotEmpty) {
      body['description'] = description;
    }
    if (imageUrl != null && imageUrl.isNotEmpty) {
      body['image_url'] = imageUrl;
    }
    return await _api.post<void>(
      ApiConstants.incidents,
      body,
      requireAuth: true,
    );
  }

  // ─── Notifications ────────────────────────────────────────────────────────

  // ─── Fuel Prices (PUBLIC) ─────────────────────────────────────────────────

  Future<ApiResponse<FuelPricesData>> getFuelPrices() async {
    return await _api.get<FuelPricesData>(
      ApiConstants.prices,
      fromJson: FuelPricesData.fromJson,
      requireAuth: false,
    );
  }

  Future<ApiResponse<NotificationListResponse>> getNotifications() async {
    return await _api.get<NotificationListResponse>(
      ApiConstants.notifications,
      fromJsonList: NotificationListResponse.fromJsonList,
    );
  }

  Future<ApiResponse<NotificationListResponse>> getAdminNotifications() async {
    return await _api.get<NotificationListResponse>(
      ApiConstants.adminNotifications,
      fromJsonList: NotificationListResponse.fromJsonList,
    );
  }

  Future<ApiResponse<void>> markNotificationRead(String notificationId) async {
    return await _api.patch(
      '${ApiConstants.notifications}/$notificationId/read',
      {},
    );
  }

  Future<int> getUnreadCount() async {
    final result = await _api.get<Map<String, dynamic>>(
      ApiConstants.notificationsUnreadCount,
      fromJson: (json) => json,
    );
    return result.data?['unread_count'] as int? ?? 0;
  }
}
