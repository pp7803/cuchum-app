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
import '../utils/trip_datetime_format.dart';
import '../widgets/operations_style.dart';
import 'driver_trip_detail_screen.dart';

/// Driver: danh sách chuyến, phản hồi lịch, bắt đầu/kết thúc.
class DriverTripsScreen extends StatefulWidget {
  const DriverTripsScreen({super.key});

  @override
  State<DriverTripsScreen> createState() => _DriverTripsScreenState();
}

class _DriverTripsScreenState extends State<DriverTripsScreen> {
  bool _loading = true;
  List<TripData> _trips = [];
  List<VehicleData> _vehicles = [];
  bool _todayOnly = true;
  PaginationState _pagination = const PaginationState(itemsPerPage: 20);

  @override
  void initState() {
    super.initState();
    _load();
  }

  String _fmt(DateTime d) {
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _loading = true);
    final svc = Provider.of<UserService>(context, listen: false);
    final now = DateTime.now();
    final start = _todayOnly ? _fmt(now) : _fmt(now.subtract(const Duration(days: 7)));
    final end = _fmt(now);

    final vRes = await svc.getVehicles(status: 'ACTIVE');
    final tRes = await svc.getTrips(startDate: start, endDate: end);

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
    if (t.licensePlate != null && t.licensePlate!.isNotEmpty) return t.licensePlate!;
    for (final v in _vehicles) {
      if (v.id == t.vehicleId) return v.licensePlate;
    }
    return t.vehicleId ?? '—';
  }

  @override
  Widget build(BuildContext context) {
    final lang = Provider.of<LanguageProvider>(context).language;
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;
    final fg = OperationsStyle.fg(isDark);

    final bottomPad = MediaQuery.paddingOf(context).bottom + 24.0;

    return Scaffold(
      backgroundColor: OperationsStyle.bg(isDark),
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
            OperationsScreenHeader(
              title: OperationsLanguage.get('ops_trips_title', lang),
              isDark: isDark,
              onRefresh: _load,
              refreshBusy: _loading,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Row(
                children: [
                  ChoiceChip(
                    label: Text(lang == AppLanguage.vi ? 'Hôm nay' : 'Today'),
                    selected: _todayOnly,
                    selectedColor: AppColors.primary.withValues(alpha: 0.18),
                    checkmarkColor: AppColors.primary,
                    labelStyle: TextStyle(
                      color: _todayOnly ? AppColors.primary : fg,
                      fontWeight:
                          _todayOnly ? FontWeight.w600 : FontWeight.w500,
                      fontSize: 13,
                    ),
                    side: BorderSide(
                      color: AppColors.primary.withValues(alpha: 0.35),
                    ),
                    onSelected: (v) {
                      if (!v) return;
                      setState(() => _todayOnly = true);
                      _load();
                    },
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: Text(lang == AppLanguage.vi ? '7 ngày' : '7 days'),
                    selected: !_todayOnly,
                    selectedColor: AppColors.primary.withValues(alpha: 0.18),
                    checkmarkColor: AppColors.primary,
                    labelStyle: TextStyle(
                      color: !_todayOnly ? AppColors.primary : fg,
                      fontWeight:
                          !_todayOnly ? FontWeight.w600 : FontWeight.w500,
                      fontSize: 13,
                    ),
                    side: BorderSide(
                      color: AppColors.primary.withValues(alpha: 0.35),
                    ),
                    onSelected: (v) {
                      if (!v) return;
                      setState(() => _todayOnly = false);
                      _load();
                    },
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(
                OperationsLanguage.get('trip_detail_hint', lang),
                style: TextStyle(
                  fontSize: 12,
                  color: OperationsStyle.fgMuted(isDark),
                ),
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(color: AppColors.primary),
                    )
                  : _trips.isEmpty
                      ? Center(
                          child: Text(
                            OperationsLanguage.get('no_trips', lang),
                            style: TextStyle(
                              color: OperationsStyle.fgMuted(isDark),
                            ),
                          ),
                        )
                      : RefreshIndicator(
                          color: AppColors.primary,
                          onRefresh: _load,
                          child: ListView.separated(
                            padding: EdgeInsets.fromLTRB(20, 0, 20, bottomPad),
                            itemCount: _pageTrips.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 10),
                            itemBuilder: (ctx, i) {
                              final t = _pageTrips[i];
                              final sub = t.scheduledStartAt ??
                                  t.startedAt ??
                                  '';
                              return Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(14),
                                  onTap: () async {
                                    await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => DriverTripDetailScreen(
                                          tripId: t.id,
                                        ),
                                      ),
                                    );
                                    if (context.mounted) _load();
                                  },
                                  child: _TripCard(
                                    trip: t,
                                    plate: _plate(t),
                                    lang: lang,
                                    isDark: isDark,
                                    subtitleFormatted: sub.isEmpty
                                        ? null
                                        : formatTripLocalDateTime(sub),
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

class _TripCard extends StatelessWidget {
  const _TripCard({
    required this.trip,
    required this.plate,
    required this.lang,
    required this.isDark,
    this.subtitleFormatted,
  });

  final TripData trip;
  final String plate;
  final AppLanguage lang;
  final bool isDark;
  final String? subtitleFormatted;

  @override
  Widget build(BuildContext context) {
    final fg = OperationsStyle.fg(isDark);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: OperationsStyle.card(isDark),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.route_rounded, color: AppColors.primary, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  plate,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: fg,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: TripStatusStyle.badgeBackground(
                    trip.status,
                    isDark: isDark,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  TripStatusLanguage.label(trip.status, lang),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: TripStatusStyle.accent(trip.status),
                  ),
                ),
              ),
            ],
          ),
          if (subtitleFormatted != null) ...[
            const SizedBox(height: 6),
            Text(
              subtitleFormatted!,
              style: TextStyle(
                fontSize: 12,
                color: OperationsStyle.fgMuted(isDark),
              ),
            ),
          ],
          if (trip.driverNote != null && trip.driverNote!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              trip.driverNote!,
              style: TextStyle(
                fontSize: 12,
                color: OperationsStyle.fgMuted(isDark),
              ),
            ),
          ],
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                OperationsLanguage.get('trip_list_cta', lang),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: AppColors.primary.withValues(alpha: 0.8),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
