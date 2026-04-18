import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/services/api_models.dart';
import '../../../core/services/user_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/trans/language_provider.dart';
import '../../../core/trans/operations_language.dart';
import '../../../core/trans/trip_status_language.dart';
import '../../../core/utils/pagination_utils.dart';
import '../widgets/operations_style.dart';
import '../../admin/widgets/admin_ui.dart';
import 'admin_schedule_trip_screen.dart' show showAdminScheduleTripModal;
import 'admin_trip_detail_screen.dart';

class AdminTripsListScreen extends StatefulWidget {
  const AdminTripsListScreen({super.key});

  @override
  State<AdminTripsListScreen> createState() => _AdminTripsListScreenState();
}

class _AdminTripsListScreenState extends State<AdminTripsListScreen> {
  bool _loading = true;
  List<TripData> _trips = [];
  List<VehicleData> _vehicles = [];
  PaginationState _pagination = const PaginationState(itemsPerPage: 20);

  String _fmt(DateTime d) {
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _loading = true);
    final svc = Provider.of<UserService>(context, listen: false);
    final end = DateTime.now();
    final start = end.subtract(const Duration(days: 30));
    final vRes = await svc.getVehicles();
    final tRes = await svc.getTrips(
      startDate: _fmt(start),
      endDate: _fmt(end),
    );
    if (!mounted) return;
    setState(() {
      _vehicles = vRes.data?.vehicles ?? [];
      _trips = tRes.data?.trips ?? [];
      _pagination = paginationStateForTotal(_pagination, _trips.length);
      _loading = false;
    });
  }

  List<TripData> get _pageTrips => paginatedSlice(_trips, _pagination);

  String _plate(TripData t) {
    if (t.licensePlate != null && t.licensePlate!.isNotEmpty) {
      return t.licensePlate!;
    }
    for (final v in _vehicles) {
      if (v.id == t.vehicleId) return v.licensePlate;
    }
    return t.vehicleId ?? '—';
  }

  /// `YYYY-MM-DD HH:mm` (local), fallback chuỗi gốc nếu parse lỗi.
  String _formatTripDateTime(String? iso) {
    if (iso == null || iso.isEmpty) return '';
    try {
      final dt = DateTime.parse(iso).toLocal();
      final y = dt.year.toString().padLeft(4, '0');
      final mo = dt.month.toString().padLeft(2, '0');
      final d = dt.day.toString().padLeft(2, '0');
      final h = dt.hour.toString().padLeft(2, '0');
      final mi = dt.minute.toString().padLeft(2, '0');
      return '$y-$mo-$d $h:$mi';
    } catch (_) {
      return iso;
    }
  }

  String? _tripNoteLine(TripData t) {
    final n = t.driverNote?.trim();
    if (n != null && n.isNotEmpty) return n;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final lang = Provider.of<LanguageProvider>(context).language;
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;
    final fg = AdminTheme.fg(isDark);

    // FAB + thanh phân trang (khi có) — tránh che dòng cuối.
    final bottomPad = MediaQuery.paddingOf(context).bottom + 100.0;

    return Scaffold(
      backgroundColor: AdminTheme.canvas(isDark),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await showAdminScheduleTripModal(context);
          if (mounted) _load();
        },
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.event_available_rounded, color: Colors.white),
        label: Text(
          OperationsLanguage.get('ops_schedule_trip', lang),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      bottomNavigationBar: _pagination.totalItems > 0
          ? PaginationWidget(
              state: _pagination,
              isDark: isDark,
              onPageChanged: (p) => setState(
                () => _pagination = _pagination.copyWith(currentPage: p),
              ),
              onPageSizeChanged: (s) => setState(() {
                _pagination = paginationStateForTotal(
                  _pagination.copyWith(currentPage: 1, itemsPerPage: s),
                  _trips.length,
                );
              }),
            )
          : null,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AdminScreenHeader(
              title: OperationsLanguage.get('ops_admin_trips', lang),
              isDark: isDark,
              onRefresh: _load,
              refreshBusy: _loading,
            ),
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(color: AppColors.primary),
                    )
                  : RefreshIndicator(
                      color: AppColors.primary,
                      onRefresh: _load,
                      child: _trips.isEmpty
                          ? ListView(
                              children: [
                                SizedBox(
                                  height:
                                      MediaQuery.sizeOf(context).height * 0.25,
                                ),
                                Center(
                                  child: Text(
                                    OperationsLanguage.get('no_trips', lang),
                                    style: TextStyle(
                                      color: OperationsStyle.fgMuted(isDark),
                                    ),
                                  ),
                                ),
                              ],
                            )
                          : ListView.separated(
                              padding: EdgeInsets.fromLTRB(20, 0, 20, bottomPad),
                              itemCount: _pageTrips.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: 10),
                              itemBuilder: (ctx, i) {
                                final t = _pageTrips[i];
                                final subRaw =
                                    t.scheduledStartAt ?? t.startedAt ?? '';
                                final sub = _formatTripDateTime(subRaw);
                                final noteLine = _tripNoteLine(t);
                                return Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(14),
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => AdminTripDetailScreen(
                                            tripId: t.id,
                                          ),
                                        ),
                                      );
                                    },
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
                                            Icons.route_rounded,
                                            color: AppColors.primary,
                                            size: 22,
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Text(
                                              _plate(t),
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w700,
                                                color: fg,
                                              ),
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: TripStatusStyle.badgeBackground(
                                                t.status,
                                                isDark: isDark,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              TripStatusLanguage.label(
                                                t.status,
                                                lang,
                                              ),
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                                color: TripStatusStyle.accent(
                                                    t.status),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      if (sub.isNotEmpty) ...[
                                        const SizedBox(height: 6),
                                        Text(
                                          sub,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: OperationsStyle.fgMuted(
                                                isDark),
                                          ),
                                        ),
                                      ],
                                      if (noteLine != null) ...[
                                        const SizedBox(height: 6),
                                        Text(
                                          '${OperationsLanguage.get('note', lang)}: $noteLine',
                                          style: TextStyle(
                                            fontSize: 12,
                                            height: 1.25,
                                            color: OperationsStyle.fgMuted(
                                                isDark),
                                          ),
                                          maxLines: 4,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ],
                                  ),
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
