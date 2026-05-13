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

  // ─── Search & Filter ──────────────────────────────────────────────────
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';
  String? _statusFilter; // null = all
  bool _sortNewestFirst = true;
  int? _dateRangeDays = 30; // null = tất cả

  // All known trip statuses for filter chips
  static const _filterStatuses = [
    'SCHEDULED_PENDING',
    'DRIVER_ACCEPTED',
    'DRIVER_DECLINED',
    'IN_PROGRESS',
    'COMPLETED',
    'CANCELLED',
  ];

  String _fmt(DateTime d) {
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _loading = true);
    final svc = Provider.of<UserService>(context, listen: false);
    final vRes = await svc.getVehicles();
    final ApiResponse<TripListResponse> tRes;
    if (_dateRangeDays == null) {
      tRes = await svc.getTrips();
    } else {
      final end = DateTime.now();
      final start = end.subtract(Duration(days: _dateRangeDays!));
      tRes = await svc.getTrips(
        startDate: _fmt(start),
        endDate: _fmt(end),
      );
    }
    if (!mounted) return;
    setState(() {
      _vehicles = vRes.data?.vehicles ?? [];
      _trips = tRes.data?.trips ?? [];
      _recalcPagination();
      _loading = false;
    });
  }

  // ─── Computed filtered + sorted list ──────────────────────────────────

  List<TripData> get _filteredTrips {
    var list = _trips.toList();

    // Status filter
    if (_statusFilter != null) {
      list = list
          .where((t) => t.status.trim().toUpperCase() == _statusFilter)
          .toList();
    }

    // Text search
    final q = _searchQuery.trim().toLowerCase();
    if (q.isNotEmpty) {
      list = list.where((t) {
        if ((t.driverName ?? '').toLowerCase().contains(q)) return true;
        if ((t.licensePlate ?? '').toLowerCase().contains(q)) return true;
        if ((t.vehicleId ?? '').toLowerCase().contains(q)) return true;
        if ((t.driverNote ?? '').toLowerCase().contains(q)) return true;
        return false;
      }).toList();
    }

    // Sort
    list.sort((a, b) {
      final aDate = _sortDate(a);
      final bDate = _sortDate(b);
      final cmp = aDate.compareTo(bDate);
      return _sortNewestFirst ? -cmp : cmp;
    });

    return list;
  }

  DateTime _sortDate(TripData t) {
    // Use start_time, then scheduled_start_at, then created_at
    final iso = t.startedAt ?? t.scheduledStartAt ?? t.createdAt;
    if (iso != null && iso.isNotEmpty) {
      try {
        return DateTime.parse(iso);
      } catch (_) {}
    }
    return DateTime(2000);
  }

  void _recalcPagination() {
    _pagination = paginationStateForTotal(_pagination, _filteredTrips.length);
  }

  List<TripData> get _pageTrips => paginatedSlice(_filteredTrips, _pagination);

  String _plate(TripData t) {
    if (t.licensePlate != null && t.licensePlate!.isNotEmpty) {
      return t.licensePlate!;
    }
    for (final v in _vehicles) {
      if (v.id == t.vehicleId) return v.licensePlate;
    }
    return t.vehicleId ?? '—';
  }

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

  void _onFilterChanged() {
    setState(() {
      _recalcPagination();
    });
  }

  @override
  Widget build(BuildContext context) {
    final lang = Provider.of<LanguageProvider>(context).language;
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;
    final fg = AdminTheme.fg(isDark);
    final muted = AdminTheme.fgMuted(isDark);

    final bottomPad = MediaQuery.paddingOf(context).bottom + 100.0;
    final filtered = _filteredTrips;

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
                  filtered.length,
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
              subtitle: '${filtered.length} ${_trips.length != filtered.length ? '/ ${_trips.length}' : ''} chuyến',
              onRefresh: _load,
              refreshBusy: _loading,
            ),
            // ── Search bar ─────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TextField(
                controller: _searchCtrl,
                onChanged: (v) {
                  _searchQuery = v;
                  _onFilterChanged();
                },
                style: TextStyle(fontSize: 14, color: fg),
                decoration: OperationsStyle.inputDeco(
                  isDark,
                  hintText: 'Tìm theo tài xế, biển số, ghi chú...',
                ).copyWith(
                  prefixIcon: const Icon(Icons.search_rounded, size: 20),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 18),
                          onPressed: () {
                            _searchCtrl.clear();
                            _searchQuery = '';
                            _onFilterChanged();
                          },
                        )
                      : null,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                ),
              ),
            ),
            const SizedBox(height: 10),
            // ── Status filter chips ────────────────────────────────────
            SizedBox(
              height: 36,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: _filterStatuses.length + 1, // +1 for "All"
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final selected = i == 0
                      ? _statusFilter == null
                      : _statusFilter == _filterStatuses[i - 1];
                  final label = i == 0
                      ? 'Tất cả'
                      : TripStatusLanguage.label(
                          _filterStatuses[i - 1], lang);
                  return FilterChip(
                    label: Text(label, style: const TextStyle(fontSize: 12)),
                    selected: selected,
                    selectedColor: AppColors.primary.withValues(alpha: 0.2),
                    checkmarkColor: AppColors.primary,
                    side: BorderSide(
                      color: selected
                          ? AppColors.primary
                          : (isDark ? Colors.white24 : Colors.grey.shade300),
                    ),
                    onSelected: (_) {
                      setState(() {
                        _statusFilter =
                            i == 0 ? null : _filterStatuses[i - 1];
                        _recalcPagination();
                      });
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 10),
            // ── Sort + date range row ──────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  // Sort toggle
                  InkWell(
                    onTap: () {
                      setState(() {
                        _sortNewestFirst = !_sortNewestFirst;
                        _recalcPagination();
                      });
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: isDark ? Colors.white24 : Colors.grey.shade300,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _sortNewestFirst
                                ? Icons.arrow_downward_rounded
                                : Icons.arrow_upward_rounded,
                            size: 16,
                            color: muted,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _sortNewestFirst ? 'Mới nhất' : 'Cũ nhất',
                            style: TextStyle(fontSize: 12, color: muted),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Spacer(),
                  // Date range quick select
                  ..._dateChips(isDark, muted),
                ],
              ),
            ),
            const SizedBox(height: 10),
            // ── Trip list ──────────────────────────────────────────────
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(
                          color: AppColors.primary),
                    )
                  : RefreshIndicator(
                      color: AppColors.primary,
                      onRefresh: _load,
                      child: filtered.isEmpty
                          ? ListView(children: [
                              SizedBox(
                                height: MediaQuery.sizeOf(context).height *
                                    0.25,
                              ),
                              Center(
                                child: Text(
                                  _trips.isEmpty
                                      ? OperationsLanguage.get(
                                          'no_trips', lang)
                                      : 'Không có chuyến nào khớp với bộ lọc',
                                  style: TextStyle(color: muted),
                                ),
                              ),
                            ])
                          : ListView.separated(
                              padding:
                                  EdgeInsets.fromLTRB(20, 0, 20, bottomPad),
                              itemCount: _pageTrips.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: 10),
                              itemBuilder: (ctx, i) {
                                final t = _pageTrips[i];
                                final subRaw =
                                    t.scheduledStartAt ?? t.startedAt ?? '';
                                final sub =
                                    _formatTripDateTime(subRaw);
                                final noteLine = _tripNoteLine(t);
                                return Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(14),
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              AdminTripDetailScreen(
                                            tripId: t.id,
                                          ),
                                        ),
                                      );
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.all(14),
                                      decoration:
                                          OperationsStyle.card(isDark),
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
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      _plate(t),
                                                      style: TextStyle(
                                                        fontSize: 16,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                        color: fg,
                                                      ),
                                                    ),
                                                    if ((t.driverName ?? '')
                                                        .isNotEmpty)
                                                      Text(
                                                        t.driverName!,
                                                        style: TextStyle(
                                                          fontSize: 12,
                                                          color: muted,
                                                        ),
                                                      ),
                                                  ],
                                                ),
                                              ),
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                  horizontal: 8,
                                                  vertical: 4,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: TripStatusStyle
                                                      .badgeBackground(
                                                    t.status,
                                                    isDark: isDark,
                                                  ),
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          8),
                                                ),
                                                child: Text(
                                                  TripStatusLanguage.label(
                                                    t.status,
                                                    lang,
                                                  ),
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w600,
                                                    color: TripStatusStyle
                                                        .accent(t.status),
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
                                                color: muted,
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
                                                color: muted,
                                              ),
                                              maxLines: 4,
                                              overflow:
                                                  TextOverflow.ellipsis,
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

  List<Widget> _dateChips(bool isDark, Color muted) {
    final options = <int?>[7, 30, 90, null]; // null = tất cả
    return options.map((days) {
      final active = _dateRangeDays == days;
      final label = days == null ? 'Tất cả' : '$days ngày';
      return Padding(
        padding: const EdgeInsets.only(left: 8),
        child: InkWell(
          onTap: () {
            if (_dateRangeDays != days) {
              setState(() {
                _dateRangeDays = days;
                _loading = true;
              });
              _load();
            }
          },
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: active
                  ? AppColors.primary.withValues(alpha: isDark ? 0.3 : 0.15)
                  : null,
              border: Border.all(
                color: active
                    ? AppColors.primary
                    : (isDark ? Colors.white24 : Colors.grey.shade300),
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: active ? AppColors.primary : muted,
                fontWeight: active ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ),
        ),
      );
    }).toList();
  }
}
