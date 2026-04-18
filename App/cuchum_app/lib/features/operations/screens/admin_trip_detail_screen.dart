import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/services/api_models.dart';
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
import 'trip_map_screen.dart';
import '../../admin/widgets/admin_ui.dart';

/// Admin: chi tiết một chuyến + checklist & báo cáo xăng gắn chuyến (chỉ xem / ghi chú xăng).
class AdminTripDetailScreen extends StatefulWidget {
  const AdminTripDetailScreen({super.key, required this.tripId});

  final String tripId;

  @override
  State<AdminTripDetailScreen> createState() => _AdminTripDetailScreenState();
}

class _AdminTripDetailScreenState extends State<AdminTripDetailScreen> {
  bool _loadingTrip = true;
  bool _loadingExtras = false;
  TripData? _trip;
  List<ChecklistData> _checklists = [];
  List<FuelReportData> _fuel = [];
  List<IncidentData> _violations = [];
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    if (!mounted) return;
    setState(() {
      _loadingTrip = true;
      _errorMessage = null;
    });
    final svc = Provider.of<UserService>(context, listen: false);
    final tRes = await svc.getTrip(widget.tripId);
    if (!mounted) return;
    if (!tRes.success || tRes.data == null) {
      setState(() {
        _trip = null;
        _errorMessage = tRes.displayMessage;
        _loadingTrip = false;
      });
      return;
    }
    setState(() {
      _trip = tRes.data;
      _loadingTrip = false;
      _loadingExtras = true;
    });
    final cRes = await svc.getChecklists(tripId: widget.tripId);
    final fRes = await svc.getFuelReports(tripId: widget.tripId);
    final iRes = await svc.getIncidents(tripId: widget.tripId);
    if (!mounted) return;
    setState(() {
      _checklists = cRes.data?.checklists ?? [];
      _fuel = fRes.data?.reports ?? [];
      _violations = iRes.data?.incidents ?? [];
      _loadingExtras = false;
    });
  }

  Future<void> _editFuelNote(FuelReportData r) async {
    final lang = Provider.of<LanguageProvider>(context, listen: false).language;
    final isDark = Provider.of<ThemeProvider>(
      context,
      listen: false,
    ).isDarkMode;
    final ctrl = TextEditingController(text: r.adminNote ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
        title: Text(
          OperationsLanguage.get('edit_admin_note', lang),
          style: TextStyle(color: OperationsStyle.fg(isDark)),
        ),
        content: TextField(
          controller: ctrl,
          maxLines: 4,
          style: TextStyle(color: OperationsStyle.fg(isDark)),
          decoration: OperationsStyle.inputDeco(
            isDark,
            labelText: OperationsLanguage.get('admin_note', lang),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(OperationsLanguage.get('cancel', lang)),
          ),
          FilledButton(
            style: OperationsStyle.primaryFilled(isDark),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(OperationsLanguage.get('save', lang)),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final svc = Provider.of<UserService>(context, listen: false);
    final res = await svc.updateFuelReportAdminNote(r.id, ctrl.text.trim());
    if (!mounted) return;
    if (res.success) {
      AlertUtils.success(context, OperationsLanguage.get('success', lang));
      await _loadAll();
    } else {
      AlertUtils.error(context, res.displayMessage);
    }
  }

  bool _canAdminCancel(String status) =>
      status == 'SCHEDULED_PENDING' || status == 'DRIVER_ACCEPTED';

  Future<void> _confirmCancelTrip() async {
    final trip = _trip;
    if (trip == null || !_canAdminCancel(trip.status) || !mounted) return;
    final lang = Provider.of<LanguageProvider>(context, listen: false).language;
    final isDark = Provider.of<ThemeProvider>(
      context,
      listen: false,
    ).isDarkMode;
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
        title: Text(
          OperationsLanguage.get('trip_cancel_admin', lang),
          style: TextStyle(color: OperationsStyle.fg(isDark)),
        ),
        content: TextField(
          controller: ctrl,
          maxLines: 4,
          style: TextStyle(color: OperationsStyle.fg(isDark)),
          decoration: OperationsStyle.inputDeco(
            isDark,
            labelText: OperationsLanguage.get('trip_cancel_reason', lang),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(OperationsLanguage.get('cancel', lang)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(OperationsLanguage.get('submit', lang)),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final reason = ctrl.text.trim();
    if (reason.length < 2) {
      AlertUtils.error(
        context,
        OperationsLanguage.get('trip_cancel_reason', lang),
      );
      return;
    }
    final svc = Provider.of<UserService>(context, listen: false);
    final res = await svc.cancelTripAsAdmin(widget.tripId, reason: reason);
    if (!mounted) return;
    if (res.success) {
      AlertUtils.success(context, OperationsLanguage.get('success', lang));
      await _loadAll();
    } else {
      AlertUtils.error(context, res.displayMessage);
    }
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

  void _openTripMap() {
    final trip = _trip;
    if (trip == null) return;
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => TripMapScreen(trip: trip)));
  }

  @override
  Widget build(BuildContext context) {
    final lang = Provider.of<LanguageProvider>(context).language;
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;
    final fg = AdminTheme.fg(isDark);
    final muted = AdminTheme.fgMuted(isDark);

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
      backgroundColor: AdminTheme.canvas(isDark),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AdminScreenHeader(
              title: OperationsLanguage.get('trip_detail_title', lang),
              isDark: isDark,
              onRefresh: _loadAll,
              refreshBusy: _loadingTrip || _loadingExtras,
            ),
            Expanded(
              child: _loadingTrip
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
                          if (_trip!.driverName != null &&
                              _trip!.driverName!.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              '${OperationsLanguage.get('driver', lang)}: ${_trip!.driverName}',
                              style: TextStyle(fontSize: 14, color: muted),
                            ),
                          ],
                          const SizedBox(height: 8),
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
                          if (_trip!.isCancelled &&
                              _trip!.adminCancelReason != null &&
                              _trip!.adminCancelReason!.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            _infoRow(
                              OperationsLanguage.get(
                                'trip_cancel_reason_label',
                                lang,
                              ),
                              _trip!.adminCancelReason!,
                              fg,
                              muted,
                            ),
                          ],
                          if (_canAdminCancel(_trip!.status)) ...[
                            const SizedBox(height: 16),
                            OutlinedButton.icon(
                              onPressed: _confirmCancelTrip,
                              icon: const Icon(Icons.cancel_outlined),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.error,
                              ),
                              label: Text(
                                OperationsLanguage.get(
                                  'trip_cancel_admin',
                                  lang,
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: 24),
                          Text(
                            OperationsLanguage.get(
                              'trip_admin_checklists_heading',
                              lang,
                            ),
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: fg,
                            ),
                          ),
                          const SizedBox(height: 10),
                          if (_loadingExtras)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 20),
                              child: Center(
                                child: CircularProgressIndicator(
                                  color: AppColors.primary,
                                ),
                              ),
                            )
                          else if (_checklists.isEmpty)
                            Text(
                              OperationsLanguage.get('checklist_empty', lang),
                              style: TextStyle(fontSize: 13, color: muted),
                            )
                          else
                            ..._checklists.map((c) {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: OperationsStyle.card(isDark),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.checklist_rounded,
                                            color: AppColors.primary,
                                            size: 22,
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Text(
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
                                                fontSize: 15,
                                                fontWeight: FontWeight.w700,
                                                color: fg,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      ...ChecklistFormat.itemLines(c, lang).map(
                                        (line) => Padding(
                                          padding: const EdgeInsets.only(
                                            bottom: 4,
                                          ),
                                          child: Text(
                                            line,
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: fg,
                                              height: 1.35,
                                            ),
                                          ),
                                        ),
                                      ),
                                      if (c.note != null &&
                                          c.note!.isNotEmpty) ...[
                                        const SizedBox(height: 6),
                                        Text(
                                          c.note!,
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: muted,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              );
                            }),
                          if (!_loadingExtras) ...[
                            const SizedBox(height: 24),
                            Text(
                              OperationsLanguage.get(
                                'trip_admin_fuel_heading',
                                lang,
                              ),
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: fg,
                              ),
                            ),
                            const SizedBox(height: 10),
                            if (_fuel.isEmpty)
                              Text(
                                OperationsLanguage.get('fuel_empty', lang),
                                style: TextStyle(fontSize: 13, color: muted),
                              )
                            else
                              ..._fuel.map((r) {
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: Container(
                                    padding: const EdgeInsets.all(14),
                                    decoration: OperationsStyle.card(isDark),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Icon(
                                          Icons.local_gas_station_rounded,
                                          color: AppColors.warning,
                                          size: 22,
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
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w700,
                                                  color: fg,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                [
                                                      r.reportDate,
                                                      if (r.fuelPurchasedAt !=
                                                              null &&
                                                          r
                                                              .fuelPurchasedAt!
                                                              .isNotEmpty)
                                                        formatTripLocalDateTime(
                                                          r.fuelPurchasedAt,
                                                        ),
                                                    ]
                                                    .where((e) => e.isNotEmpty)
                                                    .join(' • '),
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: muted,
                                                ),
                                              ),
                                              if (r.adminNote != null &&
                                                  r.adminNote!.isNotEmpty) ...[
                                                const SizedBox(height: 4),
                                                Text(
                                                  r.adminNote!,
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: muted,
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                        IconButton(
                                          icon: const Icon(
                                            Icons.edit_note_rounded,
                                          ),
                                          color: AppColors.primary,
                                          onPressed: () => _editFuelNote(r),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }),

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
                            const SizedBox(height: 10),
                            if (_violations.isEmpty)
                              Text(
                                OperationsLanguage.get(
                                  'trip_no_violation_history',
                                  lang,
                                ),
                                style: TextStyle(fontSize: 13, color: muted),
                              )
                            else
                              ..._violations.map((v) {
                                final incidentTime =
                                    (v.incidentDate != null &&
                                        v.incidentDate!.isNotEmpty)
                                    ? v.incidentDate
                                    : v.createdAt;
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: Container(
                                    padding: const EdgeInsets.all(14),
                                    decoration: OperationsStyle.card(isDark),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Icon(
                                          Icons.warning_amber_rounded,
                                          color: AppColors.error,
                                          size: 22,
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
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.w700,
                                                  color: fg,
                                                ),
                                              ),
                                              if (v.description != null &&
                                                  v
                                                      .description!
                                                      .isNotEmpty) ...[
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
