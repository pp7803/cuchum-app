import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/trans/language_provider.dart';
import '../../../core/trans/dashboard_language.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/user_service.dart';
import '../../admin/screens/member_management_screen.dart';
import '../../admin/widgets/admin_ui.dart';
import '../../notifications/screens/notifications_screen.dart';
import '../../fuel_prices/screens/fuel_prices_screen.dart';
import '../../payslips/screens/payslips_screen.dart';
import '../../contracts/screens/admin_contracts_board_screen.dart';
import '../../admin/screens/vehicles_admin_screen.dart';
import '../../operations/screens/admin_trips_list_screen.dart';
import '../../../core/trans/contracts_language.dart';
import '../../../core/trans/operations_language.dart';
import '../../../core/widgets/unread_notifications_prompt.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  bool _isLoading = true;
  bool _unreadPromptShown = false;
  int _activeDriverCount = 0;
  int _vehicleCount = 0;
  int _tripCount = 0;
  int _totalFuelCost = 0;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    final userService = Provider.of<UserService>(context, listen: false);

    final usersFuture = userService.getUsers(status: 'ACTIVE');
    final vehiclesFuture = userService.getVehicles(status: 'ACTIVE');
    final tripsFuture = userService.getTrips();
    final fuelFuture = userService.getFuelReports();

    final usersResult = await usersFuture;
    final vehiclesResult = await vehiclesFuture;
    final tripsResult = await tripsFuture;
    final fuelResult = await fuelFuture;

    if (!mounted) return;

    setState(() {
      _activeDriverCount =
          usersResult.data?.users.where((u) => u.isDriver).length ?? 0;
      _vehicleCount = vehiclesResult.data?.vehicles.length ?? 0;
      _tripCount = tripsResult.data?.trips.length ?? 0;

      final reports = fuelResult.data?.reports ?? [];
      _totalFuelCost = reports.fold(0.0, (sum, r) => sum + r.totalCost).round();

      _isLoading = false;
    });

    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showUnreadNotificationsPromptIfNeeded(
        context,
        alreadyShown: _unreadPromptShown,
        markShown: () => _unreadPromptShown = true,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final languageProvider = Provider.of<LanguageProvider>(context);
    final lang = languageProvider.language;
    final isDark = themeProvider.isDarkMode;
    final user = Provider.of<AuthService>(context, listen: false).currentUser;
    final canvas = AdminTheme.canvas(isDark);
    final fg = AdminTheme.fg(isDark);
    final muted = AdminTheme.fgMuted(isDark);

    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? DashboardLanguage.get('greeting_morning', lang)
        : hour < 18
            ? DashboardLanguage.get('greeting_afternoon', lang)
            : DashboardLanguage.get('greeting_evening', lang);

    return Scaffold(
      backgroundColor: canvas,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadDashboardData,
          color: AppColors.primary,
          edgeOffset: 8,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                  child: _WelcomeCard(
                    isDark: isDark,
                    lang: lang,
                    greeting: greeting,
                    name: user?.fullName ?? '',
                    onMenu: () => _showAdminMenu(context, lang, isDark),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 22, 20, 0),
                  child: Text(
                    DashboardLanguage.get('admin_metrics', lang),
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                      color: fg,
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                  child: _isLoading
                      ? _LoadingMetricsGrid(isDark: isDark)
                      : _MetricsGrid(
                          isDark: isDark,
                          lang: lang,
                          drivers: _activeDriverCount,
                          vehicles: _vehicleCount,
                          trips: _tripCount,
                          fuelLabel: _formatCurrency(_totalFuelCost),
                          onVehicles: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const VehiclesAdminScreen()),
                          ),
                          onTrips: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const AdminTripsListScreen()),
                          ),
                        ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 26, 20, 0),
                  child: Text(
                    DashboardLanguage.get('admin_center', lang),
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                      color: fg,
                    ),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    AdminDashboardToolTile(
                      icon: Icons.group_rounded,
                      iconColor: AppColors.primary,
                      title: DashboardLanguage.get('manage_drivers', lang),
                      subtitle:
                          DashboardLanguage.get('admin_desc_members', lang),
                      isDark: isDark,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const MemberManagementScreen()),
                      ),
                    ),
                    const SizedBox(height: 10),
                    AdminDashboardToolTile(
                      icon: Icons.airport_shuttle_rounded,
                      iconColor: const Color(0xFF7C3AED),
                      title: DashboardLanguage.get('manage_vehicles', lang),
                      subtitle:
                          DashboardLanguage.get('admin_desc_vehicles', lang),
                      isDark: isDark,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const VehiclesAdminScreen()),
                      ),
                    ),
                    const SizedBox(height: 10),
                    AdminDashboardToolTile(
                      icon: Icons.route_rounded,
                      iconColor: const Color(0xFF059669),
                      title: DashboardLanguage.get('total_trips', lang),
                      subtitle:
                          DashboardLanguage.get('admin_desc_trips', lang),
                      isDark: isDark,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const AdminTripsListScreen()),
                      ),
                    ),
                    const SizedBox(height: 10),
                    AdminDashboardToolTile(
                      icon: Icons.description_rounded,
                      iconColor: const Color(0xFF2563EB),
                      title: ContractsLanguage.get(
                          'admin_menu_contracts', lang),
                      subtitle:
                          DashboardLanguage.get('admin_desc_contracts', lang),
                      isDark: isDark,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const AdminContractsBoardScreen()),
                      ),
                    ),
                    const SizedBox(height: 10),
                    AdminDashboardToolTile(
                      icon: Icons.notifications_active_rounded,
                      iconColor: AppColors.warning,
                      title: DashboardLanguage.get(
                          'menu_admin_notifications', lang),
                      subtitle:
                          DashboardLanguage.get('admin_desc_notifs', lang),
                      isDark: isDark,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const AdminNotificationsScreen()),
                      ),
                    ),
                    const SizedBox(height: 10),
                    AdminDashboardToolTile(
                      icon: Icons.local_gas_station_rounded,
                      iconColor: const Color(0xFFF59E0B),
                      title: DashboardLanguage.get('menu_fuel_prices', lang),
                      subtitle: DashboardLanguage.get(
                          'admin_desc_fuel_prices', lang),
                      isDark: isDark,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const FuelPricesScreen()),
                      ),
                    ),
                    const SizedBox(height: 10),
                    AdminDashboardToolTile(
                      icon: Icons.payments_outlined,
                      iconColor: const Color(0xFF0D9488),
                      title: DashboardLanguage.get('menu_payslips', lang),
                      subtitle:
                          DashboardLanguage.get('admin_desc_payslips', lang),
                      isDark: isDark,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const PayslipsScreen()),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Center(
                      child: Text(
                        DashboardLanguage.get('admin_menu_more', lang),
                        style: TextStyle(
                          fontSize: 12,
                          color: muted,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAdminMenu(BuildContext context, AppLanguage lang, bool isDark) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: AdminTheme.cardShadow(isDark),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AdminTheme.fgMuted(isDark).withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            _sheetTile(
              ctx,
              Icons.group_rounded,
              AppColors.primary,
              DashboardLanguage.get('manage_drivers', lang),
              isDark,
              () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const MemberManagementScreen()),
                );
              },
            ),
            _sheetTile(
              ctx,
              Icons.airport_shuttle_rounded,
              const Color(0xFF7C3AED),
              DashboardLanguage.get('manage_vehicles', lang),
              isDark,
              () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const VehiclesAdminScreen()),
                );
              },
            ),
            _sheetTile(
              ctx,
              Icons.notifications_active_outlined,
              AppColors.warning,
              DashboardLanguage.get('menu_admin_notifications', lang),
              isDark,
              () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const AdminNotificationsScreen()),
                );
              },
            ),
            _sheetTile(
              ctx,
              Icons.local_gas_station_rounded,
              const Color(0xFFF59E0B),
              DashboardLanguage.get('menu_fuel_prices', lang),
              isDark,
              () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const FuelPricesScreen()),
                );
              },
            ),
            _sheetTile(
              ctx,
              Icons.payments_outlined,
              const Color(0xFF0D9488),
              DashboardLanguage.get('menu_payslips', lang),
              isDark,
              () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const PayslipsScreen()),
                );
              },
            ),
            _sheetTile(
              ctx,
              Icons.description_rounded,
              const Color(0xFF2563EB),
              ContractsLanguage.get('admin_menu_contracts', lang),
              isDark,
              () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const AdminContractsBoardScreen()),
                );
              },
            ),
            _sheetTile(
              ctx,
              Icons.route_rounded,
              const Color(0xFF059669),
              OperationsLanguage.get('ops_admin_trips', lang),
              isDark,
              () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const AdminTripsListScreen()),
                );
              },
            ),
            SizedBox(height: MediaQuery.paddingOf(ctx).bottom + 8),
          ],
        ),
      ),
    );
  }

  Widget _sheetTile(
    BuildContext ctx,
    IconData icon,
    Color color,
    String label,
    bool isDark,
    VoidCallback onTap,
  ) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(
        label,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: AdminTheme.fg(isDark),
        ),
      ),
      trailing: Icon(Icons.chevron_right_rounded,
          color: AdminTheme.fgMuted(isDark)),
      onTap: onTap,
    );
  }

  String _formatCurrency(int amount) {
    if (amount == 0) return '0đ';
    if (amount >= 1000000) {
      return '${(amount / 1000000).toStringAsFixed(1)}M';
    }
    if (amount >= 1000) {
      return '${(amount / 1000).toStringAsFixed(0)}K';
    }
    return '$amountđ';
  }
}

class _WelcomeCard extends StatelessWidget {
  const _WelcomeCard({
    required this.isDark,
    required this.lang,
    required this.greeting,
    required this.name,
    required this.onMenu,
  });

  final bool isDark;
  final AppLanguage lang;
  final String greeting;
  final String name;
  final VoidCallback onMenu;

  @override
  Widget build(BuildContext context) {
    final fg = AdminTheme.fg(isDark);
    final muted = AdminTheme.fgMuted(isDark);
    return Container(
      decoration: AdminTheme.welcomeCard(isDark),
      child: Stack(
        children: [
          Positioned(
            right: -20,
            top: -20,
            child: Icon(
              Icons.dashboard_customize_rounded,
              size: 120,
              color: AppColors.primary.withValues(alpha: isDark ? 0.06 : 0.05),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Material(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                      child: InkWell(
                        onTap: onMenu,
                        borderRadius: BorderRadius.circular(14),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Icon(
                            Icons.menu_rounded,
                            color: AppColors.primary,
                            size: 22,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            greeting,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: muted,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            name.isEmpty ? '—' : name,
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.5,
                              height: 1.15,
                              color: fg,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            DashboardLanguage.get('admin_tagline', lang),
                            style: TextStyle(
                              fontSize: 13,
                              color: muted,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppColors.primary, AppColors.primaryLight],
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.35),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.admin_panel_settings_rounded,
                              color: Colors.white, size: 14),
                          const SizedBox(width: 6),
                          Text(
                            DashboardLanguage.get('role_admin', lang),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricsGrid extends StatelessWidget {
  const _MetricsGrid({
    required this.isDark,
    required this.lang,
    required this.drivers,
    required this.vehicles,
    required this.trips,
    required this.fuelLabel,
    this.onVehicles,
    this.onTrips,
  });

  final bool isDark;
  final AppLanguage lang;
  final int drivers;
  final int vehicles;
  final int trips;
  final String fuelLabel;
  final VoidCallback? onVehicles;
  final VoidCallback? onTrips;

  @override
  Widget build(BuildContext context) {
    final stats = [
      _MetricSpec(
        icon: Icons.people_alt_rounded,
        value: drivers.toString(),
        label: DashboardLanguage.get('active_drivers', lang),
        accent: AppColors.primary,
        onTap: null,
      ),
      _MetricSpec(
        icon: Icons.airport_shuttle_rounded,
        value: vehicles.toString(),
        label: DashboardLanguage.get('total_vehicles', lang),
        accent: const Color(0xFF7C3AED),
        onTap: onVehicles,
      ),
      _MetricSpec(
        icon: Icons.route_rounded,
        value: trips.toString(),
        label: DashboardLanguage.get('total_trips', lang),
        accent: const Color(0xFF059669),
        onTap: onTrips,
      ),
      _MetricSpec(
        icon: Icons.local_gas_station_rounded,
        value: fuelLabel,
        label: DashboardLanguage.get('fuel_cost', lang),
        accent: AppColors.warning,
        onTap: null,
      ),
    ];

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.22,
      children: stats
          .map((s) => _MetricTile(spec: s, isDark: isDark))
          .toList(),
    );
  }
}

class _MetricSpec {
  final IconData icon;
  final String value;
  final String label;
  final Color accent;
  final VoidCallback? onTap;

  _MetricSpec({
    required this.icon,
    required this.value,
    required this.label,
    required this.accent,
    this.onTap,
  });
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({required this.spec, required this.isDark});

  final _MetricSpec spec;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final fg = AdminTheme.fg(isDark);
    final muted = AdminTheme.fgMuted(isDark);
    final card = Container(
      decoration: AdminTheme.statCard(isDark, spec.accent),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            child: Container(
              width: 4,
              decoration: BoxDecoration(
                gradient: AdminTheme.accentBar(spec.accent),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: spec.accent.withValues(alpha: isDark ? 0.2 : 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(spec.icon, color: spec.accent, size: 20),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      spec.value,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                        color: fg,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      spec.label,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: muted,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );

    if (spec.onTap != null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: spec.onTap,
          borderRadius: BorderRadius.circular(20),
          child: card,
        ),
      );
    }
    return card;
  }
}

class _LoadingMetricsGrid extends StatelessWidget {
  const _LoadingMetricsGrid({required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.22,
      children: List.generate(
        4,
        (_) => Container(
          decoration: AdminTheme.statCard(isDark, AppColors.primary),
          child: Center(
            child: SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: AppColors.primary.withValues(alpha: 0.5),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
