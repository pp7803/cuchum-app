import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/theme_provider.dart';
import '../widgets/admin_ui.dart';
import '../../../core/trans/language_provider.dart';
import '../../../core/trans/admin_language.dart';
import '../../../core/trans/profile_language.dart';
import '../../../core/services/user_service.dart';
import '../../../core/services/address_service.dart';
import '../../../core/services/api_models.dart';
import '../../../core/utils/alert_utils.dart';
import '../../../core/utils/keyboard_utils.dart';
import '../../../core/utils/pagination_utils.dart';
import '../../../core/widgets/address_picker_widget.dart';
import 'member_detail_screen.dart';

class MemberManagementScreen extends StatefulWidget {
  const MemberManagementScreen({super.key});

  @override
  State<MemberManagementScreen> createState() => _MemberManagementScreenState();
}

// Callback type used to lift pagination state to the parent Scaffold
typedef _PaginationCallback = void Function(
  PaginationState state,
  void Function(int page) onPageChanged,
  void Function(int size)? onSizeChanged,
);

class _MemberManagementScreenState extends State<MemberManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // ── Lifted pagination state ───────────────────────────────────────────────
  PaginationState _memberPagination = const PaginationState(itemsPerPage: 20);
  void Function(int)? _memberPageHandler;
  void Function(int)? _memberSizeHandler;

  PaginationState _requestPagination = const PaginationState(itemsPerPage: 10);
  void Function(int)? _requestPageHandler;
  void Function(int)? _requestSizeHandler;

  void _onMemberPagination(
    PaginationState state,
    void Function(int) onPage,
    void Function(int)? onSize,
  ) {
    if (mounted) setState(() {
      _memberPagination = state;
      _memberPageHandler = onPage;
      _memberSizeHandler = onSize;
    });
  }

  void _onRequestPagination(
    PaginationState state,
    void Function(int) onPage,
    void Function(int)? onSize,
  ) {
    if (mounted) setState(() {
      _requestPagination = state;
      _requestPageHandler = onPage;
      _requestSizeHandler = onSize;
    });
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final languageProvider = Provider.of<LanguageProvider>(context);
    final lang = languageProvider.language;
    final isDark = themeProvider.isDarkMode;

    final isMembers = _tabController.index == 0;
    final activePagination = isMembers ? _memberPagination : _requestPagination;
    final activePageHandler = isMembers ? _memberPageHandler : _requestPageHandler;
    final activeSizeHandler = isMembers ? _memberSizeHandler : _requestSizeHandler;

    return Scaffold(
      backgroundColor: AdminTheme.canvas(isDark),
      // ── Pagination fixed at screen bottom (FAB auto-floats above it) ──────
      bottomNavigationBar: activePagination.totalItems > 0
          ? PaginationWidget(
              state: activePagination,
              isDark: isDark,
              onPageChanged: activePageHandler ?? (_) {},
              onPageSizeChanged: activeSizeHandler,
            )
          : null,
      floatingActionButton: isMembers
          ? FloatingActionButton.extended(
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (_) => _CreateMemberSheet(
                    isDark: isDark,
                    lang: lang,
                    onCreated: () {},
                  ),
                );
              },
              backgroundColor: AppColors.primary,
              icon: const Icon(Icons.person_add_rounded, color: Colors.white),
              label: Text(AdminLanguage.get('add_member', lang),
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w600)),
            )
          : null,
      body: SafeArea(
        child: Column(
          children: [
            AdminScreenHeader(
              title: AdminLanguage.get('member_management', lang),
              isDark: isDark,
            ),

            // ── TabBar ──────────────────────────────────────────────────
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                height: 44,
                decoration: AdminTheme.segmentedShell(isDark),
                child: TabBar(
                  controller: _tabController,
                  indicator: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  indicatorSize: TabBarIndicatorSize.tab,
                  labelColor: Colors.white,
                  unselectedLabelColor:
                      isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  labelStyle:
                      const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  unselectedLabelStyle: const TextStyle(fontSize: 13),
                  dividerColor: Colors.transparent,
                  padding: const EdgeInsets.all(4),
                  tabs: [
                    Tab(text: AdminLanguage.get('tab_members', lang)),
                    Tab(text: AdminLanguage.get('tab_requests', lang)),
                  ],
                ),
              ),
            ),

            // ── Tab Views ───────────────────────────────────────────────
            const SizedBox(height: 8),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _MembersTab(
                    isDark: isDark,
                    lang: lang,
                    onPaginationUpdate: _onMemberPagination,
                  ),
                  _ProfileRequestsTab(
                    isDark: isDark,
                    lang: lang,
                    onPaginationUpdate: _onRequestPagination,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tab 1: Members list
// ─────────────────────────────────────────────────────────────────────────────

class _MembersTab extends StatefulWidget {
  final bool isDark;
  final AppLanguage lang;
  final _PaginationCallback? onPaginationUpdate;

  const _MembersTab({
    required this.isDark,
    required this.lang,
    this.onPaginationUpdate,
  });

  @override
  State<_MembersTab> createState() => _MembersTabState();
}

class _MembersTabState extends State<_MembersTab> {
  List<UserData> _members = [];
  bool _isLoading = true;
  String _statusFilter = '';
  final _searchCtrl = TextEditingController();
  PaginationState _pagination = const PaginationState(itemsPerPage: 20);

  bool get isDark => widget.isDark;
  AppLanguage get lang => widget.lang;

  @override
  void initState() {
    super.initState();
    _loadMembers();
    _searchCtrl.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    // Reset to page 1 on search
    _pagination = _pagination.copyWith(currentPage: 1);
    _loadMembers();
  }

  Future<void> _loadMembers({int? page, int? limit}) async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    final userService = Provider.of<UserService>(context, listen: false);
    final currentPage = page ?? _pagination.currentPage;
    final pageSize = limit ?? _pagination.itemsPerPage;

    final result = await userService.getUsers(
      status: _statusFilter.isEmpty ? null : _statusFilter,
      page: currentPage,
      limit: pageSize,
    );

    if (!mounted) return;
    final newPagination = _pagination.copyWith(
      currentPage: currentPage,
      totalItems: result.data?.total ?? 0,
      itemsPerPage: pageSize,
    );
    setState(() {
      _members = result.data?.users ?? [];
      _pagination = newPagination;
      _isLoading = false;
    });
    // Notify parent Scaffold to update bottomNavigationBar
    widget.onPaginationUpdate?.call(
      newPagination,
      (p) => _loadMembers(page: p),
      (s) => _loadMembers(page: 1, limit: s),
    );
  }

  Future<void> _toggleStatus(UserData user) async {
    final newStatus = user.isActive ? 'INACTIVE' : 'ACTIVE';
    final confirmKey = user.isActive ? 'confirm_lock' : 'confirm_unlock';

    final confirmed = await _confirm(AdminLanguage.get(confirmKey, lang));
    if (!confirmed || !mounted) return;

    final userService = Provider.of<UserService>(context, listen: false);
    final result = await userService.updateUserStatus(user.id, newStatus);
    if (!mounted) return;
    if (result.success) {
      AlertUtils.success(context, AdminLanguage.get('status_updated', lang));
      await _loadMembers();
    } else {
      AlertUtils.error(context, result.displayMessage);
    }
  }

  Future<void> _resetPassword(UserData user) async {
    final pwCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(AdminLanguage.get('reset_password', lang),
            style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isDark ? AppColors.darkText : AppColors.lightText)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${user.fullName} — ${user.phoneNumber}',
                style: TextStyle(
                    fontSize: 13,
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.lightTextSecondary)),
            const SizedBox(height: 12),
            TextField(
              controller: pwCtrl,
              obscureText: true,
              decoration: InputDecoration(
                labelText: AdminLanguage.get('new_password', lang),
                hintText: AdminLanguage.get('password_hint', lang),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Hủy')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(minimumSize: Size.zero),
            child: const Text('Xác nhận'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    if (pwCtrl.text.trim().length < 6) {
      AlertUtils.error(context, AdminLanguage.get('password_too_short', lang));
      return;
    }

    final userService = Provider.of<UserService>(context, listen: false);
    final result = await userService.resetUserPassword(user.id, pwCtrl.text.trim());
    if (!mounted) return;
    if (result.success) {
      AlertUtils.success(context, AdminLanguage.get('password_reset', lang));
    } else {
      AlertUtils.error(context, result.displayMessage);
    }
  }

  void _openDetail(UserData user) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => MemberDetailScreen(member: user)),
    ).then((_) => _loadMembers()); // reload after returning (status may have changed)
  }

  Future<bool> _confirm(String message) async {
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            content: Text(message,
                style: TextStyle(
                    color: isDark ? AppColors.darkText : AppColors.lightText)),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Hủy')),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(minimumSize: Size.zero),
                child: const Text('Xác nhận'),
              ),
            ],
          ),
        ) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ── Search + Filter ────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Column(
            children: [
              TextField(
                controller: _searchCtrl,
                decoration: InputDecoration(
                  hintText: AdminLanguage.get('search_hint', lang),
                  prefixIcon: const Icon(Icons.search_rounded, size: 20),
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _filterChip('', AdminLanguage.get('filter_all', lang)),
                    const SizedBox(width: 8),
                    _filterChip('ACTIVE', AdminLanguage.get('filter_active', lang)),
                    const SizedBox(width: 8),
                    _filterChip('INACTIVE', AdminLanguage.get('filter_inactive', lang)),
                  ],
                ),
              ),
            ],
          ),
        ),

        // ── List ──────────────────────────────────────────────────────
        Expanded(
          child: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.primary))
              : _members.isEmpty
                  ? Center(
                      child: Text(AdminLanguage.get('no_members', lang),
                          style: TextStyle(
                              color: isDark
                                  ? AppColors.darkTextSecondary
                                  : AppColors.lightTextSecondary)))
                  : RefreshIndicator(
                      onRefresh: _loadMembers,
                      color: AppColors.primary,
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                        itemCount: _members.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (_, i) => _buildMemberCard(_members[i]),
                    ),
                  ),
        ),
      ],
    );
  }

  Widget _filterChip(String value, String label) {
    final selected = _statusFilter == value;
    return GestureDetector(
      onTap: () {
        _statusFilter = value;
        _pagination = _pagination.copyWith(currentPage: 1);
        _loadMembers(page: 1);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary
              : (isDark ? AppColors.darkSurface : Colors.white),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            if (!selected)
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.06),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
          ],
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: selected
                ? Colors.white
                : (isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.lightTextSecondary),
          ),
        ),
      ),
    );
  }

  Widget _buildMemberCard(UserData user) {
    final isActive = user.isActive;
    final name = user.fullName;
    final initials = name
        .trim()
        .split(' ')
        .map((w) => w.isNotEmpty ? w[0] : '')
        .take(2)
        .join()
        .toUpperCase();
    final avatarColor = isActive ? const Color(0xFF059669) : AppColors.lightTextSecondary;

    return InkWell(
      onTap: () => _openDetail(user),
      borderRadius: BorderRadius.circular(14),
      child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.05),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: avatarColor.withValues(alpha: 0.12),
              border: Border.all(color: avatarColor.withValues(alpha: 0.3), width: 1.5),
            ),
            child: Center(
              child: Text(
                initials.isEmpty ? '?' : initials,
                style: TextStyle(
                  color: avatarColor,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.fullName,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                    color: isDark ? AppColors.darkText : AppColors.lightText,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  user.phoneNumber,
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.lightTextSecondary,
                  ),
                ),
              ],
            ),
          ),
          // Status + actions
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: isActive
                      ? AppColors.success.withValues(alpha: 0.12)
                      : AppColors.error.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  isActive
                      ? AdminLanguage.get('filter_active', lang)
                      : AdminLanguage.get('filter_inactive', lang),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isActive ? AppColors.success : AppColors.error,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _iconBtn(
                    icon: isActive
                        ? Icons.lock_outline_rounded
                        : Icons.lock_open_rounded,
                    color: isActive ? AppColors.warning : AppColors.success,
                    onTap: () => _toggleStatus(user),
                  ),
                  const SizedBox(width: 6),
                  _iconBtn(
                    icon: Icons.key_rounded,
                    color: AppColors.primary,
                    onTap: () => _resetPassword(user),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
      ), // Container
    ); // InkWell
  }

  Widget _iconBtn({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 18, color: color),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tab 2: Profile Update Requests
// ─────────────────────────────────────────────────────────────────────────────

class _ProfileRequestsTab extends StatefulWidget {
  final bool isDark;
  final AppLanguage lang;
  final _PaginationCallback? onPaginationUpdate;

  const _ProfileRequestsTab({
    required this.isDark,
    required this.lang,
    this.onPaginationUpdate,
  });

  @override
  State<_ProfileRequestsTab> createState() => _ProfileRequestsTabState();
}

class _ProfileRequestsTabState extends State<_ProfileRequestsTab> {
  List<ProfileUpdateRequestData> _requests = [];
  bool _isLoading = true;
  String _statusFilter = 'PENDING';
  PaginationState _pagination = const PaginationState(itemsPerPage: 10);

  bool get isDark => widget.isDark;
  AppLanguage get lang => widget.lang;

  @override
  void initState() {
    super.initState();
    _loadRequests();
  }

  Future<void> _loadRequests({int? page, int? limit}) async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    final userService = Provider.of<UserService>(context, listen: false);
    final currentPage = page ?? _pagination.currentPage;
    final pageSize = limit ?? _pagination.itemsPerPage;

    final result = await userService.getProfileRequests(
      status: _statusFilter,
      page: currentPage,
      limit: pageSize,
    );
    if (!mounted) return;
    final newPagination = _pagination.copyWith(
      currentPage: currentPage,
      totalItems: result.data?.total ?? 0,
      itemsPerPage: pageSize,
    );
    setState(() {
      _requests = result.data?.requests ?? [];
      _pagination = newPagination;
      _isLoading = false;
    });
    widget.onPaginationUpdate?.call(
      newPagination,
      (p) => _loadRequests(page: p),
      (s) => _loadRequests(page: 1, limit: s),
    );
  }

  Future<void> _approve(String id) async {
    final userService = Provider.of<UserService>(context, listen: false);
    final result =
        await userService.reviewProfileRequest(id, status: 'APPROVED');
    if (!mounted) return;
    if (result.success) {
      AlertUtils.success(context, AdminLanguage.get('request_approved', lang));
      await _loadRequests();
    } else {
      AlertUtils.error(context, result.displayMessage);
    }
  }

  Future<void> _reject(String id) async {
    final noteCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(AdminLanguage.get('reject', lang),
            style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isDark ? AppColors.darkText : AppColors.lightText)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(AdminLanguage.get('reject_reason', lang),
                style: TextStyle(
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.lightTextSecondary)),
            const SizedBox(height: 10),
            TextField(
              controller: noteCtrl,
              maxLines: 2,
              decoration: InputDecoration(
                  hintText: AdminLanguage.get('reject_reason_hint', lang)),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Hủy')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error, minimumSize: Size.zero),
            child: Text(AdminLanguage.get('reject', lang)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final userService = Provider.of<UserService>(context, listen: false);
    final result = await userService.reviewProfileRequest(
      id,
      status: 'REJECTED',
      adminNote: noteCtrl.text.trim().isNotEmpty ? noteCtrl.text.trim() : null,
    );
    if (!mounted) return;
    if (result.success) {
      AlertUtils.success(context, AdminLanguage.get('request_rejected', lang));
      await _loadRequests();
    } else {
      AlertUtils.error(context, result.displayMessage);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ── Filter chips ───────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _filterChip('PENDING', AdminLanguage.get('filter_pending', lang),
                    AppColors.warning),
                const SizedBox(width: 8),
                _filterChip('APPROVED', AdminLanguage.get('filter_approved', lang),
                    AppColors.success),
                const SizedBox(width: 8),
                _filterChip('REJECTED', AdminLanguage.get('filter_rejected', lang),
                    AppColors.error),
              ],
            ),
          ),
        ),

        // ── List ──────────────────────────────────────────────────────
        Expanded(
          child: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.primary))
              : _requests.isEmpty
                  ? Center(
                      child: Text(AdminLanguage.get('no_requests', lang),
                          style: TextStyle(
                              color: isDark
                                  ? AppColors.darkTextSecondary
                                  : AppColors.lightTextSecondary)))
                  : RefreshIndicator(
                      onRefresh: _loadRequests,
                      color: AppColors.primary,
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                        itemCount: _requests.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 10),
                        itemBuilder: (_, i) =>
                            _buildRequestCard(_requests[i]),
                      ),
                    ),
        ),
      ],
    );
  }

  Widget _filterChip(String value, String label, Color color) {
    final selected = _statusFilter == value;
    return GestureDetector(
      onTap: () {
        _statusFilter = value;
        _pagination = _pagination.copyWith(currentPage: 1);
        _loadRequests(page: 1);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected
              ? color
              : (isDark ? AppColors.darkSurface : Colors.white),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            if (!selected)
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.06),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
          ],
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: selected
                ? Colors.white
                : (isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.lightTextSecondary),
          ),
        ),
      ),
    );
  }

  Widget _buildRequestCard(ProfileUpdateRequestData req) {
    final isPending = req.isPending;
    final statusColor = req.isPending
        ? AppColors.warning
        : req.isApproved
            ? AppColors.success
            : AppColors.error;
    final statusLabel = req.isPending
        ? AdminLanguage.get('pending', lang)
        : req.isApproved
            ? AdminLanguage.get('approved', lang)
            : AdminLanguage.get('rejected', lang);

    final changes = <String>[];
    if (req.citizenId != null)
      changes.add(
          '${AdminLanguage.get('new_citizen_id', lang)}: ${req.citizenId}');
    if (req.licenseClass != null)
      changes.add(
          '${AdminLanguage.get('new_license_class', lang)}: ${req.licenseClass}');
    if (req.licenseNumber != null)
      changes.add(
          '${AdminLanguage.get('new_license_number', lang)}: ${req.licenseNumber}');
    if (req.address != null)
      changes
          .add('${AdminLanguage.get('new_address', lang)}: ${req.address}');

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: isPending
            ? Border.all(
                color: AppColors.warning.withValues(alpha: 0.3), width: 1)
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.05),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Driver name + status badge
          Row(
            children: [
              Expanded(
                child: Text(
                  req.driverName ?? '–',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.darkText : AppColors.lightText,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          // Submitted date
          const SizedBox(height: 4),
          Text(
            '${AdminLanguage.get('submitted_at', lang)}: ${_formatDate(req.createdAt)}',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            ),
          ),
          // Changes list
          if (changes.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              AdminLanguage.get('requested_changes', lang),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.lightTextSecondary,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 4),
            ...changes.map((c) => Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Text(
                    '• $c',
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? AppColors.darkText : AppColors.lightText,
                    ),
                  ),
                )),
          ],
          // Admin note if rejected
          if (!isPending && req.adminNote != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                req.adminNote!,
                style: TextStyle(
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                  color: statusColor,
                ),
              ),
            ),
          ],
          // Approve/Reject buttons (PENDING only)
          if (isPending) ...[
            const SizedBox(height: 12),
            IntrinsicHeight(
              child: Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 44,
                      child: OutlinedButton(
                        onPressed: () => _reject(req.id),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppColors.error, width: 1.5),
                          foregroundColor: AppColors.error,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                        child: Text(AdminLanguage.get('reject', lang),
                            style: const TextStyle(fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: SizedBox(
                      height: 44,
                      child: ElevatedButton(
                        onPressed: () => _approve(req.id),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.success,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                        child: Text(AdminLanguage.get('approve', lang),
                            style: const TextStyle(fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatDate(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return iso;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Create Member Bottom Sheet
// ─────────────────────────────────────────────────────────────────────────────

class _CreateMemberSheet extends StatefulWidget {
  final bool isDark;
  final AppLanguage lang;
  final VoidCallback onCreated;

  const _CreateMemberSheet({
    required this.isDark,
    required this.lang,
    required this.onCreated,
  });

  @override
  State<_CreateMemberSheet> createState() => _CreateMemberSheetState();
}

class _CreateMemberSheetState extends State<_CreateMemberSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _pwCtrl = TextEditingController();
  final _citizenIdCtrl = TextEditingController();
  final _licenseCtrl = TextEditingController();
  final _licenseNumberCtrl = TextEditingController();
  bool _obscurePw = true;
  bool _isLoading = false;
  AddressResult _address = const AddressResult();

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _pwCtrl.dispose();
    _citizenIdCtrl.dispose();
    _licenseCtrl.dispose();
    _licenseNumberCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final userService = Provider.of<UserService>(context, listen: false);
    // Build the combined address string: "Phần1, Phần2, Phần3"
    final combinedAddress = _address.combined; // e.g. "41 Đường A, Phường B, Tỉnh C"

    final result = await userService.createUser(
      phoneNumber:  _phoneCtrl.text.trim(),
      fullName:     _nameCtrl.text.trim(),
      password:     _pwCtrl.text,
      email:        _emailCtrl.text.trim().isEmpty       ? null : _emailCtrl.text.trim(),
      citizenId:    _citizenIdCtrl.text.trim().isEmpty   ? null : _citizenIdCtrl.text.trim(),
      licenseClass: _licenseCtrl.text.trim().isEmpty ? null : _licenseCtrl.text.trim(),
      licenseNumber: _licenseNumberCtrl.text.trim().isEmpty
          ? null
          : _licenseNumberCtrl.text.trim(),
      address: combinedAddress.isEmpty ? null : combinedAddress,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result.success) {
      Navigator.pop(context);
      AlertUtils.success(context, AdminLanguage.get('member_created', widget.lang));
      widget.onCreated();
    } else {
      AlertUtils.error(context, result.displayMessage);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final lang = widget.lang;

    return DismissKeyboard(
      child: Container(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 24,
          bottom: MediaQuery.of(context).viewInsets.bottom + 32,
        ),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      AdminLanguage.get('create_member', lang),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isDark ? AppColors.darkText : AppColors.lightText,
                      ),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        'Huỷ',
                        style: TextStyle(
                          fontSize: 14,
                          color: isDark
                              ? AppColors.darkTextSecondary
                              : AppColors.lightTextSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _field(
                  controller: _nameCtrl,
                  label: AdminLanguage.get('full_name', lang),
                  hint: AdminLanguage.get('name_hint', lang),
                  icon: Icons.person_outline_rounded,
                  isDark: isDark,
                  lang: lang,
                ),
                const SizedBox(height: 14),
                _field(
                  controller: _phoneCtrl,
                  label: AdminLanguage.get('phone_number', lang),
                  hint: AdminLanguage.get('phone_hint', lang),
                  icon: Icons.phone_outlined,
                  isDark: isDark,
                  lang: lang,
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 14),
                _field(
                  controller: _emailCtrl,
                  label: AdminLanguage.get('email_optional', lang),
                  hint: AdminLanguage.get('email_hint', lang),
                  icon: Icons.email_outlined,
                  isDark: isDark,
                  lang: lang,
                  required: false,
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 14),
                // Password field
                _labelText(AdminLanguage.get('password', lang), isDark),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _pwCtrl,
                  obscureText: _obscurePw,
                  decoration: InputDecoration(
                    hintText: AdminLanguage.get('password_hint', lang),
                    prefixIcon: const Icon(Icons.lock_outline_rounded, size: 18),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePw
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        size: 20,
                        color: AppColors.primary,
                      ),
                      onPressed: () =>
                          setState(() => _obscurePw = !_obscurePw),
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) {
                      return AdminLanguage.get('field_required', lang);
                    }
                    if (v.length < 6) {
                      return AdminLanguage.get('password_too_short', lang);
                    }
                    return null;
                  },
                ),
                // ── Optional: CMND/CCCD ───────────────────────────────────
                const SizedBox(height: 14),
                _labelText('CMND/CCCD (tùy chọn)', isDark),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _citizenIdCtrl,
                  keyboardType: TextInputType.number,
                  maxLength: 12,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    hintText: 'Nhập 12 chữ số',
                    prefixIcon: Icon(Icons.badge_outlined, size: 18),
                    counterText: '',
                  ),
                  validator: (v) {
                    if (v != null && v.isNotEmpty && v.length != 12) {
                      return AdminLanguage.get('citizen_id_invalid', lang);
                    }
                    return null;
                  },
                ),
                // ── Optional: Hạng bằng ──────────────────────────────────
                const SizedBox(height: 14),
                _field(
                  controller: _licenseCtrl,
                  label: ProfileLanguage.get('license_class', lang),
                  hint: ProfileLanguage.get('enter_license_class', lang),
                  icon: Icons.card_membership_outlined,
                  isDark: isDark,
                  lang: lang,
                  required: false,
                ),
                const SizedBox(height: 14),
                _field(
                  controller: _licenseNumberCtrl,
                  label: AdminLanguage.get('license_number_field', lang),
                  hint: AdminLanguage.get('license_number_hint', lang),
                  icon: Icons.badge_rounded,
                  isDark: isDark,
                  lang: lang,
                  required: false,
                ),
                // ── Optional: Địa chỉ ────────────────────────────────────
                const SizedBox(height: 14),
                _labelText('Địa chỉ (tùy chọn)', isDark),
                const SizedBox(height: 10),
                AddressPickerWidget(
                  isDark: isDark,
                  onChanged: (result) => setState(() => _address = result),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _submit,
                    child: _isLoading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : Text(AdminLanguage.get('create_member', lang)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required bool isDark,
    required AppLanguage lang,
    bool required = true,
    TextInputType? keyboardType,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _labelText(label, isDark),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon, size: 18),
          ),
          validator: required
              ? (v) {
                  if (v == null || v.trim().isEmpty) {
                    return AdminLanguage.get('field_required', lang);
                  }
                  return null;
                }
              : null,
        ),
      ],
    );
  }

  Widget _labelText(String text, bool isDark) => Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
          letterSpacing: 0.8,
        ),
      );
}

