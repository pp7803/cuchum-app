import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/services/api_models.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/user_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/trans/contracts_language.dart';
import '../../../core/trans/language_provider.dart';
import '../../../core/utils/pagination_utils.dart';
import '../../admin/widgets/admin_ui.dart';
import 'contract_pdf_viewer_screen.dart';
import 'contracts_screen.dart';

/// ADMIN: danh sách tài xế; mỗi tài xế có khối hợp đồng + **phân trang nội bộ**.
class AdminContractsBoardScreen extends StatefulWidget {
  const AdminContractsBoardScreen({super.key});

  @override
  State<AdminContractsBoardScreen> createState() =>
      _AdminContractsBoardScreenState();
}

class _AdminContractsBoardScreenState extends State<AdminContractsBoardScreen> {
  bool _loading = true;
  List<UserData> _drivers = [];

  @override
  void initState() {
    super.initState();
    _loadDrivers();
  }

  Future<void> _loadDrivers() async {
    if (!mounted) return;
    setState(() => _loading = true);
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
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;
    final lang = Provider.of<LanguageProvider>(context).language;
    final sub = AdminTheme.fgMuted(isDark);
    final bg = AdminTheme.canvas(isDark);
    final bottomPad = MediaQuery.paddingOf(context).bottom + 24.0;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AdminScreenHeader(
              title: ContractsLanguage.get('admin_board_title', lang),
              subtitle: ContractsLanguage.get('admin_board_subtitle', lang),
              isDark: isDark,
              onRefresh: _loadDrivers,
              refreshBusy: _loading,
            ),
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
                      ),
                    )
                  : RefreshIndicator(
                      color: AppColors.primary,
                      onRefresh: _loadDrivers,
                      child: _drivers.isEmpty
                          ? ListView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              children: [
                                SizedBox(
                                  height:
                                      MediaQuery.sizeOf(context).height * 0.25,
                                ),
                                Center(
                                  child: Text(
                                    ContractsLanguage.get(
                                      'admin_board_empty',
                                      lang,
                                    ),
                                    style: TextStyle(color: sub),
                                  ),
                                ),
                              ],
                            )
                          : ListView.separated(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: EdgeInsets.fromLTRB(
                                16,
                                0,
                                16,
                                bottomPad,
                              ),
                              itemCount: _drivers.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: 12),
                              itemBuilder: (context, i) {
                                return _DriverContractsPanel(
                                  driver: _drivers[i],
                                  lang: lang,
                                  isDark: isDark,
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

class _DriverContractsPanel extends StatefulWidget {
  const _DriverContractsPanel({
    required this.driver,
    required this.lang,
    required this.isDark,
  });

  final UserData driver;
  final AppLanguage lang;
  final bool isDark;

  @override
  State<_DriverContractsPanel> createState() => _DriverContractsPanelState();
}

class _DriverContractsPanelState extends State<_DriverContractsPanel> {
  static const int _perPage = 5;

  bool _loadRequested = false;
  bool _loading = false;
  List<ContractData> _contracts = [];
  String? _ackFilter;
  PaginationState _pagination = const PaginationState(
    currentPage: 1,
    itemsPerPage: _perPage,
  );

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _loading = true);
    final svc = Provider.of<UserService>(context, listen: false);
    final r = await svc.getContracts(
      driverId: widget.driver.id,
      acknowledgmentStatus: _ackFilter,
    );
    if (!mounted) return;
    final list = r.data?.contracts ?? [];
    setState(() {
      _contracts = list;
      _pagination = paginationStateForTotal(_pagination, list.length);
      _loading = false;
    });
  }

  void _onExpansionChanged(bool open) {
    if (open && !_loadRequested) {
      setState(() {
        _loadRequested = true;
        _loading = true;
      });
      _load();
    } else {}
  }

  Future<void> _openPdf(ContractData c) async {
    final userService = Provider.of<UserService>(context, listen: false);
    await userService.markContractViewed(c.id);
    if (mounted) await _load();
    if (!mounted) return;
    final fileUrl = c.fileUrl;
    final fullUrl =
        fileUrl.startsWith('http://') || fileUrl.startsWith('https://')
        ? fileUrl
        : '${ApiConstants.baseUrl}$fileUrl';
    final api = Provider.of<ApiService>(context, listen: false);
    final headers = <String, String>{};
    final token = api.accessToken;
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    if (!mounted) return;
    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => ContractPdfViewerScreen(
          pdfUrl: fullUrl,
          title: ContractsLanguage.get('open_pdf', widget.lang),
          httpHeaders: headers.isEmpty ? null : headers,
        ),
      ),
    );
  }

  Widget _filterChips(Color textColor) {
    final secondary = widget.isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;
    Widget chip(String? value, String labelKey) {
      final selected = _ackFilter == value;
      return Padding(
        padding: const EdgeInsets.only(right: 8, bottom: 8),
        child: FilterChip(
          label: Text(
            ContractsLanguage.get(labelKey, widget.lang),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: selected ? Colors.white : textColor,
            ),
          ),
          selected: selected,
          onSelected: (_) {
            setState(() {
              _ackFilter = value;
              _pagination = _pagination.copyWith(currentPage: 1);
            });
            _load();
          },
          selectedColor: AppColors.primary,
          checkmarkColor: Colors.white,
          backgroundColor: widget.isDark ? AppColors.darkSurface : Colors.white,
          side: BorderSide(color: secondary.withValues(alpha: 0.35)),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            ContractsLanguage.get('admin_tools', widget.lang),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: secondary,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            children: [
              chip(null, 'filter_all'),
              chip('PENDING', 'filter_pending'),
              chip('ACKNOWLEDGED', 'filter_ack'),
              chip('DECLINED', 'filter_declined'),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final lang = widget.lang;
    final fg = AdminTheme.fg(isDark);
    final sub = AdminTheme.fgMuted(isDark);
    final d = widget.driver;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AdminTheme.outline(isDark)),
        boxShadow: AdminTheme.cardShadow(isDark),
      ),
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          key: PageStorageKey<String>('contracts_${d.id}'),
          onExpansionChanged: _onExpansionChanged,
          initiallyExpanded: false,
          tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          childrenPadding: const EdgeInsets.only(bottom: 12),
          leading: CircleAvatar(
            backgroundColor: AppColors.primary.withValues(alpha: 0.12),
            child: Text(
              d.fullName.isNotEmpty ? d.fullName[0].toUpperCase() : '?',
              style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          title: Text(
            d.fullName,
            style: TextStyle(fontWeight: FontWeight.w700, color: fg),
          ),
          subtitle: Text(
            d.phoneNumber,
            style: TextStyle(color: sub, fontSize: 13),
          ),
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () {
                  Navigator.push<void>(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => ContractsScreen(
                        driverId: d.id,
                        driverName: d.fullName,
                        embeddedInShell: false,
                      ),
                    ),
                  ).then((_) {
                    if (_loadRequested && mounted) _load();
                  });
                },
                icon: const Icon(Icons.open_in_new_rounded, size: 16),
                label: Text(ContractsLanguage.get('admin_full_manager', lang)),
              ),
            ),
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(20),
                child: Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),
              )
            else ...[
              _filterChips(fg),
              if (_contracts.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Text(
                    ContractsLanguage.get('admin_contracts_none', lang),
                    style: TextStyle(color: sub, fontSize: 13),
                  ),
                )
              else ...[
                ...paginatedSlice(_contracts, _pagination).map(
                  (c) => Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                    child: ContractCard(
                      contract: c,
                      isDark: isDark,
                      lang: lang,
                      isAdmin: true,
                      onOpenPdf: () => _openPdf(c),
                      onAcknowledge: null,
                      onDecline: null,
                    ),
                  ),
                ),
                if (_pagination.totalItems > 0)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: PaginationWidget(
                      state: _pagination,
                      isDark: isDark,
                      pageSizeOptions: const [5, 10, 20],
                      onPageChanged: (p) => setState(
                        () =>
                            _pagination = _pagination.copyWith(currentPage: p),
                      ),
                      onPageSizeChanged: (s) => setState(() {
                        _pagination = paginationStateForTotal(
                          _pagination.copyWith(currentPage: 1, itemsPerPage: s),
                          _contracts.length,
                        );
                      }),
                    ),
                  ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
