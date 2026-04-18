import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/services/api_models.dart';
import '../../../core/services/user_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/trans/language_provider.dart';
import '../../../core/trans/operations_language.dart';
import '../../../core/utils/alert_utils.dart';
import '../widgets/operations_style.dart';
import '../../admin/widgets/admin_ui.dart';

/// Mở form lên lịch chuyến dạng modal (bottom sheet).
Future<void> showAdminScheduleTripModal(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    isDismissible: true,
    enableDrag: true,
    builder: (ctx) {
      return Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
        child: const _AdminScheduleTripSheet(),
      );
    },
  );
}

class _AdminScheduleTripSheet extends StatefulWidget {
  const _AdminScheduleTripSheet();

  @override
  State<_AdminScheduleTripSheet> createState() =>
      _AdminScheduleTripSheetState();
}

class _AdminScheduleTripSheetState extends State<_AdminScheduleTripSheet> {
  bool _loading = true;
  bool _saving = false;
  List<UserData> _drivers = [];
  List<VehicleData> _vehicles = [];

  UserData? _driver;
  VehicleData? _vehicle;
  DateTime _start = DateTime.now().add(const Duration(hours: 1));
  DateTime? _end;
  final _noteCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  /// BE: `limit` tối đa 100 — gọi 200 sẽ fail binding và không có user.
  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _loading = true);
    final svc = Provider.of<UserService>(context, listen: false);

    const pageLimit = 100;
    final allUsers = <UserData>[];
    var page = 1;
    late ApiResponse<UserListResponse> lastUsers;
    while (true) {
      lastUsers = await svc.getUsers(
        status: 'ACTIVE',
        page: page,
        limit: pageLimit,
      );
      if (!lastUsers.success || lastUsers.data == null) break;
      allUsers.addAll(lastUsers.data!.users);
      final total = lastUsers.data!.total;
      if (allUsers.length >= total || lastUsers.data!.users.length < pageLimit) {
        break;
      }
      page++;
    }

    final vRes = await svc.getVehicles(status: 'ACTIVE');
    if (!mounted) return;

    if (!lastUsers.success && allUsers.isEmpty) {
      setState(() => _loading = false);
      if (mounted) {
        AlertUtils.error(context, lastUsers.displayMessage);
      }
      return;
    }

    final drivers = allUsers
        .where((u) => u.isDriver && u.isActive)
        .toList()
      ..sort((a, b) => a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase()));
    final vehicles = vRes.data?.vehicles ?? [];

    setState(() {
      _drivers = drivers;
      _vehicles = vehicles;
      if (_driver == null || !drivers.any((d) => d.id == _driver!.id)) {
        _driver = drivers.isNotEmpty ? drivers.first : null;
      }
      if (_vehicle == null || !vehicles.any((v) => v.id == _vehicle!.id)) {
        _vehicle = vehicles.isNotEmpty ? vehicles.first : null;
      }
      _loading = false;
    });
  }

  DateTime get _todayStart {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  /// RFC3339 với offset cố định +07:00 (Việt Nam, không DST).
  String _scheduleRfc3339Vietnam(DateTime picked) {
    final two = (int n) => n.toString().padLeft(2, '0');
    final y = picked.year.toString().padLeft(4, '0');
    return '$y-${two(picked.month)}-${two(picked.day)}T'
        '${two(picked.hour)}:${two(picked.minute)}:00+07:00';
  }

  /// Hiển thị local wall-clock: `YYYY-MM-DD HH:MM`
  String _formatDateTime(DateTime dt) {
    final l = dt.toLocal();
    final y = l.year.toString().padLeft(4, '0');
    final mo = l.month.toString().padLeft(2, '0');
    final d = l.day.toString().padLeft(2, '0');
    final h = l.hour.toString().padLeft(2, '0');
    final mi = l.minute.toString().padLeft(2, '0');
    return '$y-$mo-$d $h:$mi';
  }

  Future<void> _pickStart() async {
    final lastDate = DateTime.now().add(const Duration(days: 365));
    var initial = _start;
    if (initial.isBefore(_todayStart)) initial = _todayStart;
    if (initial.isAfter(lastDate)) initial = lastDate;
    final d = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: _todayStart,
      lastDate: lastDate,
    );
    if (d == null || !mounted) return;
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_start),
    );
    if (t == null || !mounted) return;
    setState(() {
      _start = DateTime(d.year, d.month, d.day, t.hour, t.minute);
    });
  }

  Future<void> _pickEnd() async {
    final lastDate = DateTime.now().add(const Duration(days: 365));
    final startDay = DateTime(_start.year, _start.month, _start.day);
    final firstDate =
        startDay.isBefore(_todayStart) ? _todayStart : startDay;
    var initial = _end ?? _start;
    if (initial.isBefore(firstDate)) initial = firstDate;
    if (initial.isAfter(lastDate)) initial = lastDate;
    final d = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: firstDate,
      lastDate: lastDate,
    );
    if (d == null || !mounted) return;
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_end ?? _start),
    );
    if (t == null || !mounted) return;
    setState(() {
      _end = DateTime(d.year, d.month, d.day, t.hour, t.minute);
    });
  }

  Future<void> _save() async {
    final lang = Provider.of<LanguageProvider>(context, listen: false).language;
    if (_driver == null || _vehicle == null) {
      AlertUtils.error(context, OperationsLanguage.get('select_driver', lang));
      return;
    }
    final now = DateTime.now();
    if (!_start.isAfter(now)) {
      AlertUtils.error(
        context,
        OperationsLanguage.get('schedule_start_future', lang),
      );
      return;
    }
    if (_end != null && !_end!.isAfter(_start)) {
      AlertUtils.error(
        context,
        OperationsLanguage.get('schedule_end_after_start', lang),
      );
      return;
    }
    setState(() => _saving = true);
    final svc = Provider.of<UserService>(context, listen: false);
    final startIso = _scheduleRfc3339Vietnam(_start);
    String? endIso;
    if (_end != null) {
      endIso = _scheduleRfc3339Vietnam(_end!);
    }

    final res = await svc.scheduleTrip(
      driverId: _driver!.id,
      vehicleId: _vehicle!.id,
      scheduledStartAt: startIso,
      scheduledEndAt: endIso,
      driverNote: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (res.success) {
      AlertUtils.success(context, OperationsLanguage.get('success', lang));
      Navigator.pop(context);
    } else {
      AlertUtils.error(context, res.displayMessage);
    }
  }

  Widget _dateCard({
    required bool isDark,
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: OperationsStyle.card(isDark),
        child: Row(
          children: [
            Icon(Icons.event_rounded, color: AppColors.primary, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      color: OperationsStyle.fgMuted(isDark),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: OperationsStyle.fg(isDark),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = Provider.of<LanguageProvider>(context).language;
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;
    final fg = AdminTheme.fg(isDark);
    final muted = AdminTheme.fgMuted(isDark);
    final maxH = MediaQuery.sizeOf(context).height * 0.92;

    return Align(
      alignment: Alignment.bottomCenter,
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        child: Material(
          color: AdminTheme.canvas(isDark),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxH),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 10),
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: muted.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: Icon(Icons.close_rounded, color: fg),
                        ),
                        Expanded(
                          child: Text(
                            OperationsLanguage.get('ops_schedule_trip', lang),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.3,
                              color: fg,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: _loading ? null : _load,
                          icon: Icon(Icons.refresh_rounded, color: fg),
                        ),
                      ],
                    ),
                  ),
                  Flexible(
                    child: _loading
                        ? const Padding(
                            padding: EdgeInsets.all(48),
                            child: Center(
                              child: CircularProgressIndicator(
                                color: AppColors.primary,
                              ),
                            ),
                          )
                        : SingleChildScrollView(
                            padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                DropdownButtonFormField<UserData>(
                                  isExpanded: true,
                                  value: _driver,
                                  style: TextStyle(
                                    color: OperationsStyle.fg(isDark),
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  dropdownColor: isDark
                                      ? AppColors.darkSurface
                                      : Colors.white,
                                  items: _drivers
                                      .map(
                                        (u) => DropdownMenuItem(
                                          value: u,
                                          child: Text(u.fullName),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (v) => setState(() => _driver = v),
                                  decoration: OperationsStyle.inputDeco(
                                    isDark,
                                    labelText:
                                        OperationsLanguage.get('driver', lang),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                DropdownButtonFormField<VehicleData>(
                                  isExpanded: true,
                                  value: _vehicle,
                                  style: TextStyle(
                                    color: OperationsStyle.fg(isDark),
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  dropdownColor: isDark
                                      ? AppColors.darkSurface
                                      : Colors.white,
                                  items: _vehicles
                                      .map(
                                        (v) => DropdownMenuItem(
                                          value: v,
                                          child: Text(v.licensePlate),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (v) =>
                                      setState(() => _vehicle = v),
                                  decoration: OperationsStyle.inputDeco(
                                    isDark,
                                    labelText: OperationsLanguage.get(
                                        'vehicle', lang),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                _dateCard(
                                  isDark: isDark,
                                  label: OperationsLanguage.get(
                                      'scheduled_start', lang),
                                  value: _formatDateTime(_start),
                                  onTap: _pickStart,
                                ),
                                const SizedBox(height: 10),
                                _dateCard(
                                  isDark: isDark,
                                  label: OperationsLanguage.get(
                                      'scheduled_end', lang),
                                  value: _end == null
                                      ? '—'
                                      : _formatDateTime(_end!),
                                  onTap: _pickEnd,
                                ),
                                const SizedBox(height: 16),
                                TextField(
                                  controller: _noteCtrl,
                                  maxLines: 3,
                                  style: TextStyle(
                                      color: OperationsStyle.fg(isDark)),
                                  decoration: OperationsStyle.inputDeco(
                                    isDark,
                                    labelText:
                                        OperationsLanguage.get('note', lang),
                                  ),
                                ),
                                const SizedBox(height: 24),
                                FilledButton(
                                  style: OperationsStyle.primaryFilled(isDark),
                                  onPressed: _saving ? null : _save,
                                  child: _saving
                                      ? const SizedBox(
                                          height: 22,
                                          width: 22,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : Text(
                                          OperationsLanguage.get('save', lang),
                                        ),
                                ),
                              ],
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
