import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/services/api_models.dart';
import '../../../core/services/location_permission_service.dart';
import '../../../core/services/user_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/trans/language_provider.dart';
import '../../../core/trans/operations_language.dart';
import '../../../core/trans/trip_status_language.dart';
import '../../../core/utils/alert_utils.dart';
import '../utils/checklist_format.dart';
import '../utils/trip_datetime_format.dart';
import '../widgets/operations_style.dart';
import '../widgets/trip_map_card.dart';
import 'driver_trip_checklist_screen.dart';
import 'driver_trip_incident_screen.dart';
import 'driver_trip_fuel_screen.dart';
import 'trip_map_screen.dart';

/// Chi tiết chuyến: giờ dự kiến/thực tế, thao tác lịch, checklist & xăng.
class DriverTripDetailScreen extends StatefulWidget {
  const DriverTripDetailScreen({super.key, required this.tripId});

  final String tripId;

  @override
  State<DriverTripDetailScreen> createState() => _DriverTripDetailScreenState();
}

class _DriverTripDetailScreenState extends State<DriverTripDetailScreen> {
  bool _loading = true;
  TripData? _trip;
  String? _errorMessage;
  bool _hasChecklistForTrip = false;
  List<ChecklistData> _tripChecklists = [];
  List<FuelReportData> _tripFuels = [];
  List<IncidentData> _tripViolations = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    final svc = Provider.of<UserService>(context, listen: false);
    final res = await svc.getTrip(widget.tripId);
    if (!mounted) return;
    if (res.success && res.data != null) {
      final cRes = await svc.getChecklists(tripId: widget.tripId);
      final fRes = await svc.getFuelReports(tripId: widget.tripId);
      final iRes = await svc.getIncidents(tripId: widget.tripId);
      if (!mounted) return;
      final cl = cRes.data?.checklists ?? [];
      final fl = fRes.data?.reports ?? [];
      final iv = iRes.data?.incidents ?? [];
      setState(() {
        _trip = res.data;
        _tripChecklists = cl;
        _tripFuels = fl;
        _tripViolations = iv;
        _hasChecklistForTrip = cl.isNotEmpty;
        _loading = false;
      });
    } else {
      setState(() {
        _trip = null;
        _tripChecklists = [];
        _tripFuels = [];
        _tripViolations = [];
        _hasChecklistForTrip = false;
        _errorMessage = res.displayMessage;
        _loading = false;
      });
    }
  }

  /// Khớp BE: "Bắt đầu chạy" trong [giờ dự kiến − 15p, + 30p] (local).
  bool _isWithinStartScheduleWindow(TripData t) {
    final iso = t.scheduledStartAt;
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

  bool _canTapStartScheduled(TripData t) =>
      _isWithinStartScheduleWindow(t) && _hasChecklistForTrip;

  Future<void> _respond({required bool accept}) async {
    final trip = _trip;
    if (trip == null || !mounted) return;
    final lang = Provider.of<LanguageProvider>(context, listen: false).language;
    String? declineNote;
    if (!accept) {
      final noteCtrl = TextEditingController();
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(OperationsLanguage.get('decline', lang)),
          content: TextField(
            controller: noteCtrl,
            decoration: InputDecoration(
              labelText: OperationsLanguage.get('decline_note', lang),
            ),
            maxLines: 2,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(OperationsLanguage.get('cancel', lang)),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(OperationsLanguage.get('submit', lang)),
            ),
          ],
        ),
      );
      if (ok != true || !mounted) return;
      declineNote = noteCtrl.text.trim();
    }

    final svc = Provider.of<UserService>(context, listen: false);
    final res = await svc.respondTrip(
      trip.id,
      status: accept ? 'DRIVER_ACCEPTED' : 'DRIVER_DECLINED',
      declineNote: declineNote,
    );
    if (!mounted) return;
    if (res.success) {
      AlertUtils.success(context, OperationsLanguage.get('success', lang));
      await _load();
    } else {
      AlertUtils.error(context, res.displayMessage);
    }
  }

  Future<void> _startScheduled() async {
    final trip = _trip;
    if (trip == null || !mounted) return;
    final lang = Provider.of<LanguageProvider>(context, listen: false).language;
    if (!_hasChecklistForTrip) {
      AlertUtils.error(
        context,
        OperationsLanguage.get('checklist_required_before_start', lang),
      );
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(OperationsLanguage.get('start_trip', lang)),
        content: Text(OperationsLanguage.get('start_trip_confirm', lang)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(OperationsLanguage.get('cancel', lang)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(OperationsLanguage.get('start_trip', lang)),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    TripLocationPoint? location;
    if (LocationPermissionService.isAppleDesktopOrMobile) {
      location = await LocationPermissionService.getCurrentTripLocation();
      if (location == null) {
        if (!mounted) return;
        AlertUtils.error(
          context,
          OperationsLanguage.get('location_required_for_trip_start', lang),
        );
        return;
      }
    }

    final svc = Provider.of<UserService>(context, listen: false);
    final res = await svc.startScheduledTrip(
      trip.id,
      startLat: location?.latitude,
      startLng: location?.longitude,
    );
    if (!mounted) return;
    if (res.success) {
      AlertUtils.success(context, OperationsLanguage.get('success', lang));
      await _load();
    } else {
      AlertUtils.error(context, res.displayMessage);
    }
  }

  Future<void> _endTrip() async {
    final trip = _trip;
    if (trip == null || !mounted) return;
    final lang = Provider.of<LanguageProvider>(context, listen: false).language;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(OperationsLanguage.get('end_trip', lang)),
        content: Text(OperationsLanguage.get('end_trip_confirm', lang)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(OperationsLanguage.get('cancel', lang)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(OperationsLanguage.get('end_trip', lang)),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    TripLocationPoint? location;
    if (LocationPermissionService.isAppleDesktopOrMobile) {
      location = await LocationPermissionService.getCurrentTripLocation();
    }

    final svc = Provider.of<UserService>(context, listen: false);
    final res = await svc.endTrip(
      trip.id,
      endLat: location?.latitude,
      endLng: location?.longitude,
    );
    if (!mounted) return;
    if (res.success) {
      AlertUtils.success(context, OperationsLanguage.get('success', lang));
      await _load();
    } else {
      AlertUtils.error(context, res.displayMessage);
    }
  }

  void _openTripMap() {
    final trip = _trip;
    if (trip == null) return;
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => TripMapScreen(trip: trip)));
  }

  Widget _infoRow(String label, String value, Color fg, Color muted) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text(
              label,
              style: TextStyle(fontSize: 13, color: muted, height: 1.3),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: fg,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = Provider.of<LanguageProvider>(context).language;
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;
    final fg = OperationsStyle.fg(isDark);
    final muted = OperationsStyle.fgMuted(isDark);

    String incidentTypeLabel(String type) {
      switch (type.toUpperCase()) {
        case 'TRAFFIC_TICKET':
          return OperationsLanguage.get('incident_type_traffic_ticket', lang);
        case 'BREAKDOWN':
          return OperationsLanguage.get('incident_type_breakdown', lang);
        default:
          return OperationsLanguage.get('incident_type_accident', lang);
      }
    }

    return Scaffold(
      backgroundColor: OperationsStyle.bg(isDark),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            OperationsScreenHeader(
              title: OperationsLanguage.get('trip_detail_title', lang),
              isDark: isDark,
              onRefresh: _load,
              refreshBusy: _loading,
            ),
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
                      ),
                    )
                  : _errorMessage != null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          _errorMessage!,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: muted),
                        ),
                      ),
                    )
                  : _trip == null
                  ? const SizedBox.shrink()
                  : SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            _trip!.licensePlate ?? (_trip!.vehicleId ?? '—'),
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: fg,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: TripStatusStyle.badgeBackground(
                                _trip!.status,
                                isDark: isDark,
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              TripStatusLanguage.label(_trip!.status, lang),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: TripStatusStyle.accent(_trip!.status),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            OperationsLanguage.get(
                              'trip_scheduled_start',
                              lang,
                            ),
                            style: TextStyle(
                              fontSize: 12,
                              color: muted,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            formatTripLocalDateTime(_trip!.scheduledStartAt),
                            style: TextStyle(
                              fontSize: 15,
                              color: fg,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            OperationsLanguage.get('trip_scheduled_end', lang),
                            style: TextStyle(
                              fontSize: 12,
                              color: muted,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            formatTripLocalDateTime(_trip!.scheduledEndAt),
                            style: TextStyle(
                              fontSize: 15,
                              color: fg,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Divider(color: muted.withValues(alpha: 0.3)),
                          const SizedBox(height: 16),
                          _infoRow(
                            OperationsLanguage.get('trip_actual_start', lang),
                            formatTripLocalDateTime(_trip!.startedAt),
                            fg,
                            muted,
                          ),
                          _infoRow(
                            OperationsLanguage.get('trip_actual_end', lang),
                            formatTripLocalDateTime(_trip!.endedAt),
                            fg,
                            muted,
                          ),
                          if (_trip!.isCancelled)
                            _infoRow(
                              OperationsLanguage.get(
                                'trip_cancel_time_label',
                                lang,
                              ),
                              formatTripLocalDateTime(_trip!.cancelledAt),
                              fg,
                              muted,
                            ),
                          const SizedBox(height: 8),
                          TripMapCard(
                            trip: _trip!,
                            lang: lang,
                            isDark: isDark,
                            onOpenFullMap: _openTripMap,
                          ),
                          if (_trip!.driverNote != null &&
                              _trip!.driverNote!.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(
                              OperationsLanguage.get('note', lang),
                              style: TextStyle(
                                fontSize: 12,
                                color: muted,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _trip!.driverNote!,
                              style: TextStyle(fontSize: 14, color: fg),
                            ),
                          ],
                          if (_trip!.isCancelled &&
                              _trip!.adminCancelReason != null &&
                              _trip!.adminCancelReason!.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.error.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: AppColors.error.withValues(
                                    alpha: 0.35,
                                  ),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    OperationsLanguage.get(
                                      'trip_cancelled_by_admin',
                                      lang,
                                    ),
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.error,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    _trip!.adminCancelReason!,
                                    style: TextStyle(fontSize: 14, color: fg),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: 24),
                          Text(
                            OperationsLanguage.get(
                              'trip_violation_history_heading',
                              lang,
                            ),
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: fg,
                            ),
                          ),
                          const SizedBox(height: 8),
                          if (_tripViolations.isEmpty)
                            Text(
                              OperationsLanguage.get(
                                'trip_no_violation_history',
                                lang,
                              ),
                              style: TextStyle(fontSize: 13, color: muted),
                            )
                          else
                            ..._tripViolations.map((v) {
                              final incidentTime =
                                  (v.incidentDate != null &&
                                      v.incidentDate!.isNotEmpty)
                                  ? v.incidentDate
                                  : v.createdAt;
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: OperationsStyle.card(isDark),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Icon(
                                        Icons.warning_amber_rounded,
                                        color: AppColors.error,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              incidentTypeLabel(v.type),
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                                color: AppColors.error,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              formatTripLocalDateTime(
                                                incidentTime,
                                              ),
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w700,
                                                color: fg,
                                              ),
                                            ),
                                            if (v.description != null &&
                                                v.description!.isNotEmpty) ...[
                                              const SizedBox(height: 4),
                                              Text(
                                                v.description!,
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  color: muted,
                                                ),
                                              ),
                                            ],
                                            if (v.adminNote != null &&
                                                v.adminNote!.isNotEmpty) ...[
                                              const SizedBox(height: 4),
                                              Text(
                                                v.adminNote!,
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: muted,
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }),
                          if (_trip!.isCompleted || _trip!.isCancelled) ...[
                            const SizedBox(height: 24),
                            Divider(color: muted.withValues(alpha: 0.3)),
                            const SizedBox(height: 16),
                            Text(
                              OperationsLanguage.get(
                                'trip_history_title',
                                lang,
                              ),
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: fg,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              OperationsLanguage.get(
                                'trip_admin_checklists_heading',
                                lang,
                              ),
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: muted,
                              ),
                            ),
                            const SizedBox(height: 8),
                            if (_tripChecklists.isEmpty)
                              Text(
                                OperationsLanguage.get(
                                  'trip_no_checklist_history',
                                  lang,
                                ),
                                style: TextStyle(fontSize: 13, color: muted),
                              )
                            else
                              ..._tripChecklists.map((c) {
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: OperationsStyle.card(isDark),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          (c.createdAt != null &&
                                                  c.createdAt!.isNotEmpty)
                                              ? formatTripLocalDateTime(
                                                  c.createdAt,
                                                )
                                              : formatTripLocalDateTime(
                                                  c.checkDate.isNotEmpty
                                                      ? c.checkDate
                                                      : null,
                                                ),
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w700,
                                            color: fg,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        ...ChecklistFormat.itemLines(
                                          c,
                                          lang,
                                        ).map(
                                          (line) => Padding(
                                            padding: const EdgeInsets.only(
                                              bottom: 3,
                                            ),
                                            child: Text(
                                              line,
                                              style: TextStyle(
                                                fontSize: 13,
                                                color: fg,
                                              ),
                                            ),
                                          ),
                                        ),
                                        if (c.note != null &&
                                            c.note!.isNotEmpty) ...[
                                          const SizedBox(height: 4),
                                          Text(
                                            c.note!,
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: muted,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                );
                              }),
                            const SizedBox(height: 16),
                            Text(
                              OperationsLanguage.get(
                                'trip_fuel_history_heading',
                                lang,
                              ),
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: muted,
                              ),
                            ),
                            const SizedBox(height: 8),
                            if (_tripFuels.isEmpty)
                              Text(
                                OperationsLanguage.get(
                                  'trip_no_fuel_history',
                                  lang,
                                ),
                                style: TextStyle(fontSize: 13, color: muted),
                              )
                            else
                              ..._tripFuels.map((r) {
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: OperationsStyle.card(isDark),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.local_gas_station,
                                          color: AppColors.warning,
                                          size: 20,
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                '${r.totalCost.round()}đ',
                                                style: TextStyle(
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.w700,
                                                  color: fg,
                                                ),
                                              ),
                                              Text(
                                                (r.fuelPurchasedAt != null &&
                                                        r
                                                            .fuelPurchasedAt!
                                                            .isNotEmpty)
                                                    ? formatTripLocalDateTime(
                                                        r.fuelPurchasedAt,
                                                      )
                                                    : r.reportDate,
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: muted,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }),
                          ],
                          const SizedBox(height: 24),
                          if (_trip!.status == 'SCHEDULED_PENDING') ...[
                            Row(
                              children: [
                                Expanded(
                                  child: FilledButton.tonal(
                                    onPressed: () => _respond(accept: true),
                                    child: Text(
                                      OperationsLanguage.get('accept', lang),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: () => _respond(accept: false),
                                    child: Text(
                                      OperationsLanguage.get('decline', lang),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                          ],
                          if (_trip!.status == 'DRIVER_ACCEPTED') ...[
                            if (_trip!.isEligibleForChecklist &&
                                !_hasChecklistForTrip)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: Text(
                                  OperationsLanguage.get(
                                    'checklist_required_before_start',
                                    lang,
                                  ),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: muted,
                                    height: 1.35,
                                  ),
                                ),
                              ),
                            if (!_isWithinStartScheduleWindow(_trip!))
                              Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: Text(
                                  OperationsLanguage.get(
                                    'start_trip_window_hint',
                                    lang,
                                  ),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: muted,
                                    height: 1.35,
                                  ),
                                ),
                              ),
                            FilledButton(
                              style: OperationsStyle.primaryFilled(isDark),
                              onPressed: _canTapStartScheduled(_trip!)
                                  ? _startScheduled
                                  : null,
                              child: Text(
                                OperationsLanguage.get('start_trip', lang),
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],
                          if (_trip!.isOngoing) ...[
                            FilledButton(
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.error,
                                foregroundColor: Colors.white,
                              ),
                              onPressed: _endTrip,
                              child: Text(
                                OperationsLanguage.get('end_trip', lang),
                              ),
                            ),
                            const SizedBox(height: 10),
                            OutlinedButton.icon(
                              onPressed: () async {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        DriverTripIncidentScreen(trip: _trip!),
                                  ),
                                );
                                if (mounted) await _load();
                              },
                              icon: const Icon(Icons.warning_amber_rounded),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.error,
                              ),
                              label: Text(
                                OperationsLanguage.get(
                                  'trip_action_incident',
                                  lang,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],
                          if (_trip!.isEligibleForChecklist &&
                              _hasChecklistForTrip) ...[
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.success.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: AppColors.success.withValues(
                                    alpha: 0.35,
                                  ),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.check_circle_outline,
                                    color: AppColors.success,
                                    size: 22,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      OperationsLanguage.get(
                                        'checklist_done_for_trip',
                                        lang,
                                      ),
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: fg,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 10),
                          ],
                          if (_trip!.isEligibleForChecklist &&
                              !_hasChecklistForTrip) ...[
                            OutlinedButton.icon(
                              onPressed: () async {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        DriverTripChecklistScreen(trip: _trip!),
                                  ),
                                );
                                if (mounted) await _load();
                              },
                              icon: const Icon(Icons.fact_check),
                              label: Text(
                                OperationsLanguage.get(
                                  'trip_action_checklist',
                                  lang,
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                          ],
                          if (_trip!.canLinkFuelReport &&
                              !_trip!.canAddTripLinkedFuelReport) ...[
                            Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Text(
                                OperationsLanguage.get(
                                  'fuel_report_window_hint',
                                  lang,
                                ),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: muted,
                                  height: 1.35,
                                ),
                              ),
                            ),
                          ],
                          if (_trip!.canAddTripLinkedFuelReport) ...[
                            OutlinedButton.icon(
                              onPressed: () async {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        DriverTripFuelScreen(trip: _trip!),
                                  ),
                                );
                                if (mounted) await _load();
                              },
                              icon: const Icon(
                                Icons.local_gas_station_outlined,
                              ),
                              label: Text(
                                OperationsLanguage.get(
                                  'trip_action_fuel',
                                  lang,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
