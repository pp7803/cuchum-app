import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/trans/language_provider.dart';
import '../../../core/trans/dashboard_language.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/user_service.dart';
import '../../../core/services/api_models.dart';
import '../../notifications/screens/notifications_screen.dart';
import '../../fuel_prices/screens/fuel_prices_screen.dart';
import '../../operations/screens/driver_trips_screen.dart';
import '../../../core/widgets/unread_notifications_prompt.dart';
import '../../payslips/screens/payslips_screen.dart';
import '../../../core/trans/operations_language.dart';
import '../../../core/utils/alert_utils.dart';

class DriverDashboardScreen extends StatefulWidget {
  const DriverDashboardScreen({super.key});

  @override
  State<DriverDashboardScreen> createState() => _DriverDashboardScreenState();
}

class _DriverDashboardScreenState extends State<DriverDashboardScreen> {
  bool _isLoading = true;
  bool _unreadPromptShown = false;
  List<TripData> _todayTrips = [];
  List<VehicleData> _vehicles = [];
  List<NotificationData> _notifications = [];
  TripData? _ongoingTrip;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    final userService = Provider.of<UserService>(context, listen: false);
    final today = _formatDate(DateTime.now());

    final tripsFuture = userService.getTrips(date: today);
    final ongoingFuture = userService.getTrips(status: 'IN_PROGRESS');
    final vehiclesFuture = userService.getVehicles(status: 'ACTIVE');
    final notifFuture = userService.getNotifications();

    final tripsResult = await tripsFuture;
    final ongoingResult = await ongoingFuture;
    final vehiclesResult = await vehiclesFuture;
    final notifResult = await notifFuture;

    if (!mounted) return;

    TripData? ongoing;
    for (final t in ongoingResult.data?.trips ?? []) {
      if (t.isOngoing) {
        ongoing = t;
        break;
      }
    }

    setState(() {
      _todayTrips = tripsResult.data?.trips ?? [];
      _vehicles = vehiclesResult.data?.vehicles ?? [];
      _ongoingTrip = ongoing;
      _notifications = (notifResult.data?.notifications ?? []).take(4).toList();
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

  String _plateForTrip(TripData t) {
    if (t.licensePlate != null && t.licensePlate!.isNotEmpty) {
      return t.licensePlate!;
    }
    for (final v in _vehicles) {
      if (v.id == t.vehicleId) return v.licensePlate;
    }
    return t.vehicleId ?? '';
  }

  Future<void> _endOngoingTrip() async {
    final trip = _ongoingTrip;
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
    final userService = Provider.of<UserService>(context, listen: false);
    final res = await userService.endTrip(trip.id);
    if (!mounted) return;
    if (res.success) {
      AlertUtils.success(context, OperationsLanguage.get('success', lang));
      await _loadData();
    } else {
      AlertUtils.error(context, res.displayMessage);
    }
  }

  String _formatDate(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }

  Future<void> _markNotificationReadFromHome(NotificationData notif) async {
    if (notif.isRead) return;

    final userService = Provider.of<UserService>(context, listen: false);
    final result = await userService.markNotificationRead(notif.id);
    if (!mounted) return;

    if (!result.success) {
      AlertUtils.error(context, result.displayMessage);
      return;
    }

    setState(() {
      final idx = _notifications.indexWhere((n) => n.id == notif.id);
      if (idx != -1) {
        _notifications[idx] = NotificationData(
          id: notif.id,
          title: notif.title,
          body: notif.body,
          isRead: true,
          isAdminNotification: notif.isAdminNotification,
          createdAt: notif.createdAt,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final languageProvider = Provider.of<LanguageProvider>(context);
    final lang = languageProvider.language;
    final isDark = themeProvider.isDarkMode;
    final user = Provider.of<AuthService>(context, listen: false).currentUser;

    return Scaffold(
      backgroundColor: isDark
          ? AppColors.darkBackground
          : const Color(0xFFF0F4FF),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadData,
          color: AppColors.primary,
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                  child: _buildHeader(user?.fullName ?? '', lang, isDark),
                ),
              ),
              if (_ongoingTrip != null)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                    child: _buildOngoingTripBanner(lang, isDark),
                  ),
                ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                  child: _buildTodaySummary(lang, isDark),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                  child: _buildQuickActions(lang, isDark),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
                  child: _buildNotifications(lang, isDark),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(String name, AppLanguage lang, bool isDark) {
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? DashboardLanguage.get('greeting_morning', lang)
        : hour < 18
        ? DashboardLanguage.get('greeting_afternoon', lang)
        : DashboardLanguage.get('greeting_evening', lang);

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                greeting,
                style: TextStyle(
                  fontSize: 14,
                  color: isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.lightTextSecondary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                name,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppColors.darkText : AppColors.lightText,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        // Bell icon → Notifications (with SSE unread badge from parent)
        InkWell(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const NotificationsScreen()),
          ),
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : Colors.white,
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.06),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(
              Icons.notifications_outlined,
              size: 22,
              color: isDark ? AppColors.darkText : AppColors.lightText,
            ),
          ),
        ),
        const SizedBox(width: 8),
        _buildDriverBadge(lang, isDark),
      ],
    );
  }

  Widget _buildDriverBadge(AppLanguage lang, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF059669), Color(0xFF10B981)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF059669).withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.local_shipping_rounded,
            color: Colors.white,
            size: 14,
          ),
          const SizedBox(width: 6),
          Text(
            DashboardLanguage.get('role_driver', lang),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOngoingTripBanner(AppLanguage lang, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.primaryLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.navigation_rounded, color: Colors.white, size: 32),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  DashboardLanguage.get('trip_started', lang),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                Text(
                  _plateForTrip(_ongoingTrip!),
                  style: const TextStyle(
                    color: Color(0xCCFFFFFF),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: _endOngoingTrip,
            style: TextButton.styleFrom(
              backgroundColor: Colors.white.withValues(alpha: 0.2),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text(
              DashboardLanguage.get('tap_to_end', lang),
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTodaySummary(AppLanguage lang, bool isDark) {
    final completedTrips = _todayTrips.where((t) => t.isCompleted).length;
    final totalKm = _todayTrips.fold(0, (sum, t) => sum + t.distanceKm);

    final cards = [
      _StatCard(
        icon: Icons.route_rounded,
        value: _isLoading ? '–' : completedTrips.toString(),
        label: DashboardLanguage.get('completed_trips', lang),
        color: AppColors.primary,
      ),
      _StatCard(
        icon: Icons.speed_rounded,
        value: _isLoading ? '–' : '${totalKm}km',
        label: DashboardLanguage.get('km_today', lang),
        color: const Color(0xFF059669),
      ),
    ];

    return Row(
      children: cards.asMap().entries.map((entry) {
        final i = entry.key;
        final card = entry.value;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(left: i == 0 ? 0 : 8),
            child: _buildSummaryCard(card, isDark),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSummaryCard(_StatCard card, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: card.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(card.icon, color: card.color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  card.value,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppColors.darkText : AppColors.lightText,
                  ),
                ),
                Text(
                  card.label,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.lightTextSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions(AppLanguage lang, bool isDark) {
    final actions = [
      _QuickAction(
        icon: Icons.route_rounded,
        label: DashboardLanguage.get('my_trips', lang),
        gradient: const [Color(0xFF2563EB), Color(0xFF3B82F6)],
        shadow: AppColors.primary,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const DriverTripsScreen()),
        ),
      ),
      _QuickAction(
        icon: Icons.warning_amber_rounded,
        label: DashboardLanguage.get('report_incident', lang),
        gradient: const [Color(0xFFDC2626), Color(0xFFEF4444)],
        shadow: AppColors.error,
        onTap: () {},
      ),
      _QuickAction(
        icon: Icons.local_gas_station_rounded,
        label: DashboardLanguage.get('fuel_cost', lang),
        gradient: const [Color(0xFF7C3AED), Color(0xFF9F67FF)],
        shadow: const Color(0xFF7C3AED),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const FuelPricesScreen()),
        ),
      ),
      _QuickAction(
        icon: Icons.payments_outlined,
        label: DashboardLanguage.get('payslips', lang),
        gradient: const [Color(0xFF0D9488), Color(0xFF14B8A6)],
        shadow: const Color(0xFF0D9488),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const PayslipsScreen()),
        ),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          DashboardLanguage.get('quick_actions', lang),
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: isDark ? AppColors.darkText : AppColors.lightText,
          ),
        ),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.5,
          children: actions.map((a) => _buildQuickActionCard(a)).toList(),
        ),
      ],
    );
  }

  Widget _buildQuickActionCard(_QuickAction action) {
    return InkWell(
      onTap: action.onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: action.gradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: action.shadow.withValues(alpha: 0.35),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(action.icon, color: Colors.white, size: 32),
            const SizedBox(height: 8),
            Text(
              action.label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                height: 1.3,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotifications(AppLanguage lang, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              DashboardLanguage.get('notifications', lang),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isDark ? AppColors.darkText : AppColors.lightText,
              ),
            ),
            TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const NotificationsScreen()),
              ),
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
              ),
              child: Text(
                DashboardLanguage.get('view_all', lang),
                style: const TextStyle(fontSize: 13, color: AppColors.primary),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_isLoading)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: CircularProgressIndicator(
                color: AppColors.primary.withValues(alpha: 0.6),
              ),
            ),
          )
        else if (_notifications.isEmpty)
          _buildEmptyCard(
            DashboardLanguage.get('no_notifications', lang),
            isDark,
          )
        else
          ...(_notifications.map((n) => _buildNotificationItem(n, isDark))),
      ],
    );
  }

  Widget _buildNotificationItem(NotificationData notif, bool isDark) {
    return InkWell(
      onTap: () => _markNotificationReadFromHome(notif),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: notif.isRead
              ? null
              : Border.all(
                  color: AppColors.primary.withValues(alpha: 0.3),
                  width: 1,
                ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.05),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: notif.isRead
                    ? (isDark ? AppColors.darkBorder : AppColors.lightSurface)
                    : AppColors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.notifications_outlined,
                color: notif.isRead
                    ? (isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.lightTextSecondary)
                    : AppColors.primary,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          notif.title,
                          style: TextStyle(
                            fontWeight: notif.isRead
                                ? FontWeight.w500
                                : FontWeight.bold,
                            fontSize: 14,
                            color: isDark
                                ? AppColors.darkText
                                : AppColors.lightText,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (!notif.isRead)
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    notif.body,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.lightTextSecondary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyCard(String message, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Center(
        child: Text(
          message,
          style: TextStyle(
            color: isDark
                ? AppColors.darkTextSecondary
                : AppColors.lightTextSecondary,
          ),
        ),
      ),
    );
  }
}

class _StatCard {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  _StatCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });
}

class _QuickAction {
  final IconData icon;
  final String label;
  final List<Color> gradient;
  final Color shadow;
  final VoidCallback onTap;

  _QuickAction({
    required this.icon,
    required this.label,
    required this.gradient,
    required this.shadow,
    required this.onTap,
  });
}
