import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/auth_service.dart';
import '../services/user_service.dart';
import '../theme/app_colors.dart';
import '../trans/language_provider.dart';
import '../trans/notifications_language.dart';
import '../../features/notifications/screens/notifications_screen.dart';

/// After login / first home load: one bottom sheet if there are unread items.
Future<void> showUnreadNotificationsPromptIfNeeded(
  BuildContext context, {
  required bool alreadyShown,
  required void Function() markShown,
}) async {
  if (alreadyShown || !context.mounted) return;

  final user = Provider.of<AuthService>(context, listen: false).currentUser;
  if (user == null) return;

  final svc = Provider.of<UserService>(context, listen: false);
  final lang = Provider.of<LanguageProvider>(context, listen: false).language;

  final unread = await svc.getUnreadCount();

  if (!context.mounted || unread <= 0) return;
  markShown();

  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (ctx) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(
              Icons.notifications_active_rounded,
              size: 40,
              color: AppColors.primary.withValues(alpha: 0.9),
            ),
            const SizedBox(height: 12),
            Text(
              NotificationsLanguage.get('unread_prompt_title', lang),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '$unread ${NotificationsLanguage.get('unread_prompt_subtitle', lang)}',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => user.isAdmin
                        ? const AdminNotificationsScreen()
                        : const NotificationsScreen(),
                  ),
                );
              },
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: Text(
                NotificationsLanguage.get('unread_prompt_view', lang),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                NotificationsLanguage.get('unread_prompt_later', lang),
              ),
            ),
          ],
        ),
      );
    },
  );
}
