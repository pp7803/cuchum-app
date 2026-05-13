import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/trans/language_provider.dart';
import '../../../core/trans/payslips_language.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/services/api_models.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/user_service.dart';
import '../../../core/utils/alert_utils.dart';
import '../../../core/utils/pagination_utils.dart';
import '../../admin/widgets/admin_ui.dart';
import '../../../core/utils/keyboard_utils.dart';
import '../../../core/utils/local_file_picker.dart';
import '../../../core/trans/profile_language.dart';
import '../../contracts/screens/contract_pdf_viewer_screen.dart';

class PayslipsScreen extends StatefulWidget {
  const PayslipsScreen({super.key});

  @override
  State<PayslipsScreen> createState() => _PayslipsScreenState();
}

class _PayslipsScreenState extends State<PayslipsScreen> {
  List<PayslipData> _items = [];
  bool _loading = true;
  String? _monthKey;
  PaginationState _payslipPagination =
      const PaginationState(currentPage: 1, itemsPerPage: 10);

  /// Admin: bước 1 — danh sách tài xế (phân trang client).
  List<UserData> _drivers = [];
  bool _loadingDrivers = true;
  UserData? _selectedDriver;
  PaginationState _driverPagination =
      const PaginationState(currentPage: 1, itemsPerPage: 12);

  bool get _isAdmin =>
      Provider.of<AuthService>(context, listen: false).currentUser?.isAdmin ??
      false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_isAdmin) {
        _loadDrivers();
      } else {
        _loadPayslips();
      }
    });
  }

  Future<void> _loadDrivers() async {
    if (!mounted) return;
    setState(() => _loadingDrivers = true);
    final svc = Provider.of<UserService>(context, listen: false);
    const pageLimit = 100;
    final allUsers = <UserData>[];
    var page = 1;
    late ApiResponse<UserListResponse> last;
    while (true) {
      last = await svc.getUsers(status: 'ACTIVE', page: page, limit: pageLimit);
      if (!last.success || last.data == null) break;
      allUsers.addAll(last.data!.users);
      final total = last.data!.total;
      if (allUsers.length >= total || last.data!.users.length < pageLimit) {
        break;
      }
      page++;
    }
    if (!mounted) return;
    final list = allUsers.where((u) => u.isDriver).toList()
      ..sort((a, b) => a.fullName.compareTo(b.fullName));
    setState(() {
      _drivers = list;
      _driverPagination = paginationStateForTotal(_driverPagination, list.length);
      _loadingDrivers = false;
    });
    if (!last.success && mounted && list.isEmpty) {
      AlertUtils.error(context, last.displayMessage);
    }
  }

  Future<void> _loadPayslips() async {
    if (!mounted) return;
    setState(() => _loading = true);
    final svc = Provider.of<UserService>(context, listen: false);
    final r = await svc.getPayslips(
      month: _monthKey,
      driverId: (_isAdmin && _selectedDriver != null) ? _selectedDriver!.id : null,
    );
    if (!mounted) return;
    final list = r.data ?? [];
    setState(() {
      _items = list;
      _payslipPagination = paginationStateForTotal(_payslipPagination, list.length);
      _loading = false;
    });
    if (!r.success && mounted) {
      AlertUtils.error(context, r.displayMessage);
    }
  }

  List<UserData> get _pageDrivers => paginatedSlice(_drivers, _driverPagination);

  List<PayslipData> get _pagePayslips =>
      paginatedSlice(_items, _payslipPagination);

  void _onDriverPageChanged(int page) {
    setState(() {
      _driverPagination = _driverPagination.copyWith(currentPage: page);
    });
  }

  void _onDriverPageSizeChanged(int size) {
    setState(() {
      _driverPagination = paginationStateForTotal(
        _driverPagination.copyWith(currentPage: 1, itemsPerPage: size),
        _drivers.length,
      );
    });
  }

  void _onPayslipPageChanged(int page) {
    setState(() {
      _payslipPagination = _payslipPagination.copyWith(currentPage: page);
    });
  }

  void _onPayslipPageSizeChanged(int size) {
    setState(() {
      _payslipPagination = paginationStateForTotal(
        _payslipPagination.copyWith(currentPage: 1, itemsPerPage: size),
        _items.length,
      );
    });
  }

  String _formatSalaryMonth(String raw) {
    try {
      final dt = DateTime.parse(raw);
      return '${dt.month.toString().padLeft(2, '0')}/${dt.year}';
    } catch (_) {
      return raw.length >= 7 ? raw.substring(0, 7) : raw;
    }
  }

  Future<void> _openPdf(PayslipData p, AppLanguage lang) async {
    final userService = Provider.of<UserService>(context, listen: false);
    if (!_isAdmin) {
      await userService.markPayslipViewed(p.id);
      if (mounted) _loadPayslips();
    }
    if (!mounted) return;
    final fullUrl = p.fileUrl.startsWith('http://') || p.fileUrl.startsWith('https://')
        ? p.fileUrl
        : '${ApiConstants.baseUrl}${p.fileUrl}';
    final api = Provider.of<ApiService>(context, listen: false);
    final headers = <String, String>{};
    final token = api.accessToken;
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => ContractPdfViewerScreen(
          pdfUrl: fullUrl,
          title: PayslipsLanguage.get('view_pdf', lang),
          httpHeaders: headers.isEmpty ? null : headers,
        ),
      ),
    );
  }

  Future<void> _confirmPayslip(PayslipData p, AppLanguage lang) async {
    final svc = Provider.of<UserService>(context, listen: false);
    final r = await svc.confirmPayslip(p.id, status: 'CONFIRMED');
    if (!mounted) return;
    if (r.success) {
      AlertUtils.success(context, PayslipsLanguage.get('status_confirmed', lang));
      _loadPayslips();
    } else {
      AlertUtils.error(context, r.displayMessage);
    }
  }

  Future<void> _complainPayslip(PayslipData p, AppLanguage lang, bool isDark) async {
    final note = await showDialog<String?>(
      context: context,
      builder: (ctx) => _ComplainPayslipDialog(lang: lang, isDark: isDark),
    );
    if (note == null || note.isEmpty || !mounted) return;
    final svc = Provider.of<UserService>(context, listen: false);
    final r = await svc.confirmPayslip(p.id, status: 'COMPLAINED', note: note);
    if (!mounted) return;
    if (r.success) {
      AlertUtils.success(context, PayslipsLanguage.get('status_complained', lang));
      _loadPayslips();
    } else {
      AlertUtils.error(context, r.displayMessage);
    }
  }

  void _showCreateSheet(AppLanguage lang, bool isDark,
      {UserData? preselectedDriver}) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AdminCreatePayslipSheet(
        lang: lang,
        isDark: isDark,
        preselectedDriver: preselectedDriver,
        onCreated: () {
          Navigator.pop(ctx);
          _loadPayslips();
          if (_isAdmin && _selectedDriver == null) _loadDrivers();
        },
      ),
    );
  }

  List<DropdownMenuItem<String?>> _monthItems(AppLanguage lang) {
    final now = DateTime.now();
    final items = <DropdownMenuItem<String?>>[
      DropdownMenuItem<String?>(
        value: null,
        child: Text(PayslipsLanguage.get('all_months', lang)),
      ),
    ];
    for (var i = 0; i < 24; i++) {
      final d = DateTime(now.year, now.month - i, 1);
      final key = '${d.year}-${d.month.toString().padLeft(2, '0')}';
      items.add(DropdownMenuItem<String?>(value: key, child: Text(key)));
    }
    return items;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;
    final lang = Provider.of<LanguageProvider>(context).language;
    final bg = AdminTheme.canvas(isDark);
    final fg = isDark ? AppColors.darkText : AppColors.lightText;

    if (_isAdmin) {
      return DismissKeyboard(
        child: Scaffold(
          backgroundColor: bg,
          bottomNavigationBar: _bottomBar(isDark),
          floatingActionButton: _selectedDriver != null
              ? FloatingActionButton.extended(
                  onPressed: () => _showCreateSheet(lang, isDark,
                      preselectedDriver: _selectedDriver),
                  backgroundColor: AppColors.primary,
                  icon: const Icon(Icons.add_rounded, color: Colors.white),
                  label: Text(
                    PayslipsLanguage.get('create', lang),
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w600),
                  ),
                )
              : null,
          body: SafeArea(
            child: _selectedDriver == null
                ? _buildAdminDriverList(lang, isDark, fg)
                : _buildAdminDriverPayslips(lang, isDark, fg),
          ),
        ),
      );
    }

    return DismissKeyboard(
      child: Scaffold(
        backgroundColor: bg,
        bottomNavigationBar: (!_loading && _payslipPagination.totalItems > 0)
            ? PaginationWidget(
                state: _payslipPagination,
                isDark: isDark,
                onPageChanged: _onPayslipPageChanged,
                onPageSizeChanged: _onPayslipPageSizeChanged,
                pageSizeOptions: const [5, 10, 20],
              )
            : null,
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AdminScreenHeader(
                title: PayslipsLanguage.get('title', lang),
                onBack: () => Navigator.pop(context),
                onRefresh: _loading ? null : _loadPayslips,
                refreshBusy: _loading,
                isDark: isDark,
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 14),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurface : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark ? Colors.white12 : Colors.grey.shade200,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.calendar_month_rounded,
                          size: 18, color: AppColors.primary),
                      const SizedBox(width: 10),
                      Text(
                        PayslipsLanguage.get('month_filter', lang),
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: fg),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: DropdownButtonFormField<String?>(
                          value: _monthKey,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            contentPadding:
                                EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                          ),
                          style: TextStyle(fontSize: 14, color: fg),
                          dropdownColor:
                              isDark ? AppColors.darkSurface : Colors.white,
                          items: _monthItems(lang),
                          onChanged: (v) {
                            setState(() => _monthKey = v);
                            _loadPayslips();
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(child: _buildDriverPayslipBody(lang, isDark, fg)),
            ],
          ),
        ),
      ),
    );
  }

  Widget? _bottomBar(bool isDark) {
    // Admin: driver list
    if (_selectedDriver == null) {
      if (_loadingDrivers || _driverPagination.totalItems <= 0) return null;
      return PaginationWidget(
        state: _driverPagination,
        isDark: isDark,
        onPageChanged: _onDriverPageChanged,
        onPageSizeChanged: _onDriverPageSizeChanged,
        pageSizeOptions: const [8, 12, 24],
      );
    }
    // Admin: per-driver payslips
    if (_loading || _payslipPagination.totalItems <= 0) return null;
    return PaginationWidget(
      state: _payslipPagination,
      isDark: isDark,
      onPageChanged: _onPayslipPageChanged,
      onPageSizeChanged: _onPayslipPageSizeChanged,
      pageSizeOptions: const [5, 10, 20],
    );
  }

  Widget _buildAdminDriverList(
      AppLanguage lang, bool isDark, Color fg) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AdminScreenHeader(
          title: PayslipsLanguage.get('title', lang),
          onBack: () => Navigator.pop(context),
          onRefresh: _loadingDrivers ? null : _loadDrivers,
          refreshBusy: _loadingDrivers,
          isDark: isDark,
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: Text(
            PayslipsLanguage.get('admin_pick_driver_sub', lang),
            style: TextStyle(
              fontSize: 13,
              color: fg.withValues(alpha: 0.72),
              height: 1.35,
            ),
          ),
        ),
        Expanded(
          child: _loadingDrivers
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.primary))
              : _drivers.isEmpty
                  ? Center(
                      child: Text(
                        PayslipsLanguage.get('empty', lang),
                        style: TextStyle(color: fg.withValues(alpha: 0.7)),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                      itemCount: _pageDrivers.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (_, i) {
                        final d = _pageDrivers[i];
                        return Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: () {
                              setState(() {
                                _selectedDriver = d;
                                _payslipPagination = const PaginationState(
                                    currentPage: 1, itemsPerPage: 10);
                              });
                              _loadPayslips();
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 14),
                              decoration: AdminTheme.cardDecoration(isDark),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 22,
                                    backgroundColor: AppColors.primary
                                        .withValues(alpha: 0.12),
                                    child: Text(
                                      d.fullName.isNotEmpty
                                          ? d.fullName[0].toUpperCase()
                                          : '?',
                                      style: const TextStyle(
                                        color: AppColors.primary,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          d.fullName,
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w700,
                                            color: fg,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          d.email ?? d.phoneNumber,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: fg.withValues(alpha: 0.55),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Icon(Icons.chevron_right_rounded,
                                      color: fg.withValues(alpha: 0.35)),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  Widget _buildAdminDriverPayslips(
      AppLanguage lang, bool isDark, Color fg) {
    final d = _selectedDriver!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AdminScreenHeader(
          title: PayslipsLanguage.get('admin_driver_payslips', lang),
          subtitle: d.fullName,
          onBack: () {
            setState(() {
              _selectedDriver = null;
              _items = [];
            });
          },
          onRefresh: _loading ? null : _loadPayslips,
          refreshBusy: _loading,
          isDark: isDark,
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 14),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? Colors.white12 : Colors.grey.shade200,
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.calendar_month_rounded,
                    size: 18, color: AppColors.primary),
                const SizedBox(width: 10),
                Text(
                  PayslipsLanguage.get('month_filter', lang),
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: fg),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<String?>(
                    value: _monthKey,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                    ),
                    style: TextStyle(fontSize: 14, color: fg),
                    dropdownColor: isDark ? AppColors.darkSurface : Colors.white,
                    items: _monthItems(lang),
                    onChanged: (v) {
                      setState(() => _monthKey = v);
                      _loadPayslips();
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
        Expanded(child: _buildDriverPayslipBody(lang, isDark, fg)),
      ],
    );
  }

  Widget _buildDriverPayslipBody(
      AppLanguage lang, bool isDark, Color fg) {
    if (_loading) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.primary));
    }
    if (_pagePayslips.isEmpty) {
      return Center(
        child: Text(
          PayslipsLanguage.get('empty', lang),
          style: TextStyle(color: fg.withValues(alpha: 0.7)),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      itemCount: _pagePayslips.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) {
        final p = _pagePayslips[i];
        final hideDriverLine =
            _isAdmin && _selectedDriver != null;
        return _PayslipCard(
          payslip: p,
          isDark: isDark,
          lang: lang,
          isAdmin: _isAdmin,
          showDriverLine: !hideDriverLine,
          monthLabel: _formatSalaryMonth(p.salaryMonth),
          statusLabel: PayslipsLanguage.statusLabel(p.status, lang),
          onPdf: () => _openPdf(p, lang),
          onConfirm:
              !_isAdmin && p.canRespond ? () => _confirmPayslip(p, lang) : null,
          onComplain: !_isAdmin && p.canRespond
              ? () => _complainPayslip(p, lang, isDark)
              : null,
        );
      },
    );
  }
}

Color _payslipStatusColor(String status) {
  switch (status.toUpperCase()) {
    case 'CONFIRMED':
      return AppColors.success;
    case 'COMPLAINED':
      return AppColors.error;
    case 'VIEWED':
      return AppColors.info;
    default:
      return AppColors.warning; // PENDING
  }
}

class _PayslipCard extends StatelessWidget {
  const _PayslipCard({
    required this.payslip,
    required this.isDark,
    required this.lang,
    required this.isAdmin,
    this.showDriverLine = true,
    required this.monthLabel,
    required this.statusLabel,
    required this.onPdf,
    this.onConfirm,
    this.onComplain,
  });

  final PayslipData payslip;
  final bool isDark;
  final AppLanguage lang;
  final bool isAdmin;
  final bool showDriverLine;
  final String monthLabel;
  final String statusLabel;
  final VoidCallback onPdf;
  final VoidCallback? onConfirm;
  final VoidCallback? onComplain;

  @override
  Widget build(BuildContext context) {
    final cardBg = isDark ? AppColors.darkSurface : Colors.white;
    final fg = isDark ? AppColors.darkText : AppColors.lightText;
    final muted = fg.withValues(alpha: 0.65);
    final accent = _payslipStatusColor(payslip.status);

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.grey.shade100,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header row: icon, month, status badge ──────────────
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.receipt_long_rounded,
                      color: accent, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Kỳ lương $monthLabel',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: fg,
                        ),
                      ),
                      if (isAdmin && showDriverLine) ...[
                        const SizedBox(height: 2),
                        Text(
                          payslip.driverDisplayLabel,
                          style: TextStyle(fontSize: 12, color: muted),
                        ),
                      ],
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    statusLabel,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: accent,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // ── Divider ─────────────────────────────────────────
            Divider(
                height: 1,
                color: isDark ? Colors.white10 : Colors.grey.shade100),
            const SizedBox(height: 12),
            // ── Info row ────────────────────────────────────────
            Row(
              children: [
                _infoChip(
                    payslip.isViewed
                        ? Icons.visibility_rounded
                        : Icons.visibility_off_outlined,
                    payslip.isViewed
                        ? PayslipsLanguage.get('status_viewed', lang)
                        : (lang == AppLanguage.vi ? 'Chưa xem' : 'Unviewed'),
                    payslip.isViewed ? AppColors.success : muted,
                    isDark),
                if (payslip.note != null && payslip.note!.isNotEmpty) ...[
                  const SizedBox(width: 16),
                  Flexible(
                    child: _infoChip(Icons.chat_bubble_outline, payslip.note!,
                        AppColors.warning, isDark),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 14),
            // ── Action buttons ──────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onPdf,
                    icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    label: Text(PayslipsLanguage.get('view_pdf', lang)),
                  ),
                ),
              ],
            ),
            if (onConfirm != null || onComplain != null) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  if (onConfirm != null)
                    Expanded(
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.success,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: onConfirm,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.check_rounded, size: 17),
                            const SizedBox(width: 6),
                            Text(PayslipsLanguage.get('confirm', lang)),
                          ],
                        ),
                      ),
                    ),
                  if (onConfirm != null && onComplain != null)
                    const SizedBox(width: 10),
                  if (onComplain != null)
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.error,
                          side: const BorderSide(color: AppColors.error),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: onComplain,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.report_outlined, size: 17),
                            const SizedBox(width: 6),
                            Text(PayslipsLanguage.get('complain', lang)),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _infoChip(
      IconData icon, String text, Color color, bool isDark) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(fontSize: 11, color: color),
        ),
      ],
    );
  }
}

class _AdminCreatePayslipSheet extends StatefulWidget {
  const _AdminCreatePayslipSheet({
    required this.lang,
    required this.isDark,
    required this.onCreated,
    this.preselectedDriver,
  });

  final AppLanguage lang;
  final bool isDark;
  final VoidCallback onCreated;
  final UserData? preselectedDriver;

  @override
  State<_AdminCreatePayslipSheet> createState() => _AdminCreatePayslipSheetState();
}

class _AdminCreatePayslipSheetState extends State<_AdminCreatePayslipSheet> {
  UserData? _selectedDriver;
  List<UserData> _drivers = [];
  bool _loadingDrivers = true;
  late String _monthKey;
  String? _fileUrl;
  String? _fileName;
  bool _uploading = false;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    final n = DateTime.now();
    _monthKey = '${n.year}-${n.month.toString().padLeft(2, '0')}';
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadDrivers());
  }

  Future<void> _loadDrivers() async {
    final svc = Provider.of<UserService>(context, listen: false);
    // BE: PaginationParams.Limit binding is lte=100
    const pageLimit = 100;
    final allUsers = <UserData>[];
    var page = 1;
    late ApiResponse<UserListResponse> last;
    while (true) {
      last = await svc.getUsers(status: 'ACTIVE', page: page, limit: pageLimit);
      if (!last.success || last.data == null) break;
      allUsers.addAll(last.data!.users);
      final total = last.data!.total;
      if (allUsers.length >= total || last.data!.users.length < pageLimit) {
        break;
      }
      page++;
    }
    if (!mounted) return;
    setState(() {
      _loadingDrivers = false;
      final list = allUsers.where((u) => u.isDriver).toList();
      list.sort((a, b) => a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase()));
      _drivers = list;
      final pref = widget.preselectedDriver;
      if (pref != null) {
        UserData? match;
        for (final u in list) {
          if (u.id == pref.id) {
            match = u;
            break;
          }
        }
        _selectedDriver = match ?? pref;
      }
    });
    if (!last.success && mounted) {
      AlertUtils.error(context, last.displayMessage);
    }
  }

  Future<void> _showDriverPicker() async {
    if (_drivers.isEmpty) return;
    final searchCtrl = TextEditingController();
    try {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) {
          return StatefulBuilder(
            builder: (ctx, setModal) {
              final q = searchCtrl.text.trim().toLowerCase();
              final filtered = q.isEmpty
                  ? _drivers
                  : _drivers.where((u) {
                      final name = u.fullName.toLowerCase();
                      final phone = u.phoneNumber;
                      return name.contains(q) || phone.contains(q);
                    }).toList();
              final bg = widget.isDark ? AppColors.darkSurface : Colors.white;
              final fg = widget.isDark ? AppColors.darkText : AppColors.lightText;
              return Padding(
                padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
                child: Container(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(ctx).size.height * 0.72,
                  ),
                  decoration: BoxDecoration(
                    color: bg,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                PayslipsLanguage.get('select_driver', widget.lang),
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                  color: fg,
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed: () => Navigator.pop(ctx),
                              icon: Icon(Icons.close_rounded, color: fg),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: TextField(
                          controller: searchCtrl,
                          onChanged: (_) => setModal(() {}),
                          decoration: InputDecoration(
                            hintText: PayslipsLanguage.get('search_driver', widget.lang),
                            prefixIcon: const Icon(Icons.search_rounded),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Flexible(
                        child: filtered.isEmpty
                            ? Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(24),
                                  child: Text(
                                    PayslipsLanguage.get('no_drivers', widget.lang),
                                    style: TextStyle(color: fg.withValues(alpha: 0.7)),
                                  ),
                                ),
                              )
                            : ListView.builder(
                                itemCount: filtered.length,
                                itemBuilder: (_, i) {
                                  final u = filtered[i];
                                  return ListTile(
                                    title: Text(
                                      u.fullName,
                                      style: TextStyle(
                                        color: fg,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    subtitle: Text(
                                      u.phoneNumber,
                                      style: TextStyle(
                                        color: fg.withValues(alpha: 0.65),
                                      ),
                                    ),
                                    onTap: () {
                                      Navigator.pop(ctx);
                                      setState(() => _selectedDriver = u);
                                    },
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      );
    } finally {
      searchCtrl.dispose();
    }
  }

  Widget _buildDriverField(Color fg) {
    if (_loadingDrivers) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }
    return InkWell(
      onTap: _drivers.isEmpty ? null : _showDriverPicker,
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: PayslipsLanguage.get('select_driver', widget.lang),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                _selectedDriver?.fullName ??
                    (_drivers.isEmpty
                        ? PayslipsLanguage.get('no_drivers', widget.lang)
                        : PayslipsLanguage.get('tap_to_select_driver', widget.lang)),
                style: TextStyle(
                  fontSize: 16,
                  color: _selectedDriver != null
                      ? fg
                      : fg.withValues(alpha: 0.55),
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(Icons.keyboard_arrow_down_rounded, color: fg.withValues(alpha: 0.55)),
          ],
        ),
      ),
    );
  }

  Future<void> _pickPdf() async {
    final svc = Provider.of<UserService>(context, listen: false);
    final path = await pickFilesWithExtensions(['pdf']);
    if (path == null) return;
    if (!mounted) return;
    setState(() {
      _uploading = true;
      _fileUrl = null;
    });
    final up = await svc.uploadFile(path, folder: 'payslips');
    if (!mounted) return;
    setState(() {
      _uploading = false;
      if (up.success && up.data != null) {
        _fileUrl = up.data!.fileUrl;
        _fileName = path.split(RegExp(r'[/\\]')).last;
      }
    });
    if (!up.success && mounted) {
      AlertUtils.error(context, up.displayMessage);
    }
  }

  Future<void> _submit() async {
    final id = _selectedDriver?.id;
    if (id == null || id.isEmpty || _fileUrl == null) {
      AlertUtils.error(context, PayslipsLanguage.get('fill_driver_pdf', widget.lang));
      return;
    }
    setState(() => _submitting = true);
    final svc = Provider.of<UserService>(context, listen: false);
    final res = await svc.createPayslip(
      driverId: id,
      salaryMonth: _monthKey,
      fileUrl: _fileUrl!,
    );
    if (!mounted) return;
    setState(() => _submitting = false);
    if (res.success) {
      AlertUtils.success(context, PayslipsLanguage.get('created', widget.lang));
      widget.onCreated();
    } else {
      AlertUtils.error(context, res.displayMessage);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bg = widget.isDark ? AppColors.darkSurface : Colors.white;
    final fg = widget.isDark ? AppColors.darkText : AppColors.lightText;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              PayslipsLanguage.get('create', widget.lang),
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: fg),
            ),
            const SizedBox(height: 16),
            _buildDriverField(fg),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _monthKey,
              decoration: InputDecoration(
                labelText: PayslipsLanguage.get('salary_month', widget.lang),
                border: const OutlineInputBorder(),
              ),
              items: () {
                final now = DateTime.now();
                final list = <DropdownMenuItem<String>>[];
                for (var i = 0; i < 36; i++) {
                  final d = DateTime(now.year, now.month - i, 1);
                  final k = '${d.year}-${d.month.toString().padLeft(2, '0')}';
                  list.add(DropdownMenuItem(value: k, child: Text(k)));
                }
                return list;
              }(),
              onChanged: (v) => setState(() => _monthKey = v ?? _monthKey),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _uploading ? null : _pickPdf,
              icon: _uploading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.attach_file_rounded),
              label: Text(_fileName ?? PayslipsLanguage.get('pick_pdf', widget.lang)),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text(PayslipsLanguage.get('create', widget.lang)),
            ),
          ],
        ),
      ),
    );
  }
}

/// Dialog owns [TextEditingController] so it is disposed only after the route is popped.
class _ComplainPayslipDialog extends StatefulWidget {
  const _ComplainPayslipDialog({required this.lang, required this.isDark});

  final AppLanguage lang;
  final bool isDark;

  @override
  State<_ComplainPayslipDialog> createState() => _ComplainPayslipDialogState();
}

class _ComplainPayslipDialogState extends State<_ComplainPayslipDialog> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    return AlertDialog(
      backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
      title: Text(
        PayslipsLanguage.get('complain', widget.lang),
        style: TextStyle(color: isDark ? AppColors.darkText : AppColors.lightText),
      ),
      content: TextField(
        controller: _ctrl,
        maxLines: 4,
        decoration: InputDecoration(
          hintText: PayslipsLanguage.get('complain_hint', widget.lang),
          border: const OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(ProfileLanguage.get('cancel', widget.lang)),
        ),
        ElevatedButton(
          onPressed: () {
            final t = _ctrl.text.trim();
            if (t.isEmpty) return;
            Navigator.pop(context, t);
          },
          child: Text(PayslipsLanguage.get('complain_send', widget.lang)),
        ),
      ],
    );
  }
}
