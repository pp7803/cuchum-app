import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/trans/language_provider.dart';
import '../../../core/trans/notifications_language.dart';
import '../../../core/services/user_service.dart';
import '../../../core/services/api_models.dart';
import '../../../core/services/sse_service.dart';

/// Giữ thứ tự; bỏ bản trùng `id` (id đã chuẩn hóa trong [NotificationData.fromJson]).
List<NotificationData> _uniqueNotificationsById(List<NotificationData> list) {
  final seen = <String>{};
  final out = <NotificationData>[];
  for (final n in list) {
    if (n.id.isEmpty) {
      out.add(n);
      continue;
    }
    if (seen.add(n.id)) out.add(n);
  }
  return out;
}

// ─────────────────────────────────────────────────────────────────────────────
// Driver Notifications Screen
// ─────────────────────────────────────────────────────────────────────────────

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<NotificationData> _notifications = [];
  bool _isLoading = true;
  StreamSubscription<NotificationData>? _sseSub;

  @override
  void initState() {
    super.initState();
    _load();
    // Prepend new driver notifications arriving via SSE
    _sseSub = SSEService.stream.listen((notif) {
      if (!notif.isAdminNotification && mounted) {
        setState(() {
          if (notif.id.isEmpty) return;
          _notifications.removeWhere((x) => x.id == notif.id);
          _notifications.insert(0, notif);
          _notifications = _uniqueNotificationsById(_notifications);
        });
      }
    });
  }

  @override
  void dispose() {
    _sseSub?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    final svc = Provider.of<UserService>(context, listen: false);
    final result = await svc.getNotifications();
    if (!mounted) return;
    setState(() {
      _notifications = _uniqueNotificationsById(result.data?.notifications ?? []);
      _isLoading = false;
    });
  }

  Future<void> _markRead(NotificationData n) async {
    if (n.isRead) return;
    final svc = Provider.of<UserService>(context, listen: false);
    await svc.markNotificationRead(n.id);
    if (!mounted) return;
    setState(() {
      final i = _notifications.indexWhere((x) => x.id == n.id);
      if (i != -1) _notifications[i] = _copyRead(n);
    });
  }

  Future<void> _markAllRead(AppLanguage lang) async {
    final svc = Provider.of<UserService>(context, listen: false);
    for (final n in _notifications.where((x) => !x.isRead)) {
      await svc.markNotificationRead(n.id);
    }
    if (!mounted) return;
    setState(() => _notifications = _notifications.map(_copyRead).toList());
  }

  NotificationData _copyRead(NotificationData n) => NotificationData(
        id: n.id, title: n.title, body: n.body,
        isRead: true, isAdminNotification: n.isAdminNotification,
        createdAt: n.createdAt);

  @override
  Widget build(BuildContext context) {
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;
    final lang = Provider.of<LanguageProvider>(context).language;
    final unread = _notifications.where((n) => !n.isRead).length;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : const Color(0xFFF0F4FF),
      body: SafeArea(
        child: Column(
          children: [
            _NotifHeader(
              title: NotificationsLanguage.get('title', lang),
              unread: unread,
              markAllLabel: NotificationsLanguage.get('mark_all', lang),
              isDark: isDark,
              onBack: () => Navigator.pop(context),
              onMarkAll: () => _markAllRead(lang),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                  : _notifications.isEmpty
                      ? _EmptyPlaceholder(
                          icon: Icons.notifications_none_rounded,
                          message: NotificationsLanguage.get('empty', lang),
                          isDark: isDark,
                        )
                      : RefreshIndicator(
                          onRefresh: _load,
                          color: AppColors.primary,
                          child: ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                            itemCount: _notifications.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 8),
                            itemBuilder: (_, i) => _NotifCard(
                              notif: _notifications[i], isDark: isDark, lang: lang,
                              onTap: () => _markRead(_notifications[i]),
                            ),
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Admin Notifications Screen
// ─────────────────────────────────────────────────────────────────────────────

class AdminNotificationsScreen extends StatefulWidget {
  const AdminNotificationsScreen({super.key});

  @override
  State<AdminNotificationsScreen> createState() => _AdminNotificationsScreenState();
}

class _AdminNotificationsScreenState extends State<AdminNotificationsScreen> {
  List<NotificationData> _notifications = [];
  bool _isLoading = true;
  StreamSubscription<NotificationData>? _sseSub;

  @override
  void initState() {
    super.initState();
    _load();
    // Prepend new admin notifications arriving via SSE
    _sseSub = SSEService.stream.listen((notif) {
      if (notif.isAdminNotification && mounted) {
        setState(() {
          if (notif.id.isEmpty) return;
          _notifications.removeWhere((x) => x.id == notif.id);
          _notifications.insert(0, notif);
          _notifications = _uniqueNotificationsById(_notifications);
        });
      }
    });
  }

  @override
  void dispose() {
    _sseSub?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    final svc = Provider.of<UserService>(context, listen: false);
    final result = await svc.getAdminNotifications();
    if (!mounted) return;
    setState(() {
      _notifications = _uniqueNotificationsById(result.data?.notifications ?? []);
      _isLoading = false;
    });
  }

  Future<void> _markRead(NotificationData n) async {
    if (n.isRead) return;
    final svc = Provider.of<UserService>(context, listen: false);
    await svc.markNotificationRead(n.id);
    if (!mounted) return;
    setState(() {
      final i = _notifications.indexWhere((x) => x.id == n.id);
      if (i != -1) {
        _notifications[i] = NotificationData(
          id: n.id, title: n.title, body: n.body,
          isRead: true, isAdminNotification: true, createdAt: n.createdAt,
        );
      }
    });
  }

  Future<void> _markAllRead(AppLanguage lang) async {
    final svc = Provider.of<UserService>(context, listen: false);
    for (final n in _notifications.where((x) => !x.isRead)) {
      await svc.markNotificationRead(n.id);
    }
    if (!mounted) return;
    setState(() {
      _notifications = _notifications
          .map((n) => NotificationData(
                id: n.id, title: n.title, body: n.body,
                isRead: true, isAdminNotification: true, createdAt: n.createdAt))
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;
    final lang = Provider.of<LanguageProvider>(context).language;
    final unread = _notifications.where((n) => !n.isRead).length;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : const Color(0xFFF0F4FF),
      body: SafeArea(
        child: Column(
          children: [
            _NotifHeader(
              title: NotificationsLanguage.get('admin_title', lang),
              unread: unread,
              markAllLabel: NotificationsLanguage.get('mark_all', lang),
              isDark: isDark,
              onBack: () => Navigator.pop(context),
              onMarkAll: () => _markAllRead(lang),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                  : _notifications.isEmpty
                      ? _EmptyPlaceholder(
                          icon: Icons.inbox_outlined,
                          message: NotificationsLanguage.get('empty_admin', lang),
                          isDark: isDark,
                        )
                      : RefreshIndicator(
                          onRefresh: _load,
                          color: AppColors.primary,
                          child: ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                            itemCount: _notifications.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 8),
                            itemBuilder: (_, i) => _NotifCard(
                              notif: _notifications[i], isDark: isDark, lang: lang,
                              isAdminStyle: true,
                              onTap: () => _markRead(_notifications[i]),
                            ),
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared sub-widgets
// ─────────────────────────────────────────────────────────────────────────────

class _NotifHeader extends StatelessWidget {
  final String title;
  final int unread;
  final String markAllLabel;
  final bool isDark;
  final VoidCallback onBack;
  final VoidCallback onMarkAll;

  const _NotifHeader({
    required this.title, required this.unread,
    required this.markAllLabel, required this.isDark,
    required this.onBack, required this.onMarkAll,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 12, 16, 0),
      child: Row(
        children: [
          IconButton(
            onPressed: onBack,
            icon: Icon(Icons.arrow_back_ios_new_rounded,
                color: isDark ? AppColors.darkText : AppColors.lightText),
          ),
          Expanded(
            child: Text(title,
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold,
                    color: isDark ? AppColors.darkText : AppColors.lightText)),
          ),
          if (unread > 0)
            TextButton(
              onPressed: onMarkAll,
              child: Text('$markAllLabel ($unread)',
                  style: const TextStyle(fontSize: 12, color: AppColors.primary)),
            ),
        ],
      ),
    );
  }
}

class _EmptyPlaceholder extends StatelessWidget {
  final IconData icon;
  final String message;
  final bool isDark;

  const _EmptyPlaceholder({required this.icon, required this.message, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64,
              color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
          const SizedBox(height: 12),
          Text(message,
              style: TextStyle(
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary)),
        ],
      ),
    );
  }
}

class _NotifCard extends StatelessWidget {
  final NotificationData notif;
  final bool isDark;
  final AppLanguage lang;
  final bool isAdminStyle;
  final VoidCallback? onTap;

  const _NotifCard({
    required this.notif, required this.isDark, required this.lang,
    this.isAdminStyle = false, this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isUnread = !notif.isRead;
    final accentColor = isAdminStyle ? AppColors.primary : AppColors.info;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: isUnread
              ? Border.all(color: accentColor.withValues(alpha: 0.3), width: 1)
              : null,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.05),
              blurRadius: 8, offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: isUnread
                    ? accentColor.withValues(alpha: 0.12)
                    : (isDark ? AppColors.darkBorder : AppColors.lightSurface),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                isAdminStyle
                    ? Icons.admin_panel_settings_outlined
                    : Icons.notifications_outlined,
                color: isUnread ? accentColor
                    : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                size: 20,
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
                        child: Text(notif.title,
                            style: TextStyle(
                              fontWeight: isUnread ? FontWeight.bold : FontWeight.w500,
                              fontSize: 14,
                              color: isDark ? AppColors.darkText : AppColors.lightText,
                            ),
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                      if (isUnread)
                        Container(width: 8, height: 8,
                            decoration: BoxDecoration(color: accentColor, shape: BoxShape.circle)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(notif.body,
                      style: TextStyle(fontSize: 13,
                          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                      maxLines: 3, overflow: TextOverflow.ellipsis),
                  if (notif.createdAt != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      NotificationsLanguage.relativeTime(notif.createdAt!, lang),
                      style: TextStyle(fontSize: 11,
                          color: isDark ? AppColors.darkBorder : const Color(0xFFADB5BD)),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
