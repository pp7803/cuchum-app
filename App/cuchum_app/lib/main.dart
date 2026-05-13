import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'core/constants/api_constants.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_provider.dart';
import 'core/trans/language_provider.dart';
import 'core/services/api_service.dart';
import 'core/services/api_models.dart';
import 'core/services/auth_service.dart';
import 'core/services/user_service.dart';
import 'core/services/fcm_service.dart';
import 'core/utils/notification_navigation.dart';
import 'features/auth/screens/login_screen.dart';

/// Global navigator key for FCM to push screens from background/terminated state.
final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  final themeProvider = ThemeProvider();
  final languageProvider = LanguageProvider();
  final apiService = ApiService();

  await Future.wait([
    themeProvider.init(),
    languageProvider.init(),
    apiService.init(),
  ]);

  final authService = AuthService(apiService);
  final userService = UserService(apiService);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: themeProvider),
        ChangeNotifierProvider.value(value: languageProvider),
        Provider.value(value: apiService),
        Provider.value(value: authService),
        Provider.value(value: userService),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final FCMService _fcmService = FCMService();

  @override
  void initState() {
    super.initState();
    _initializeFCM();
  }

  Future<void> _initializeFCM() async {
    final apiService = Provider.of<ApiService>(context, listen: false);

    await _fcmService.initialize(
      onTokenReceived: (token) async {
        debugPrint('FCM Token received: $token');
        if (apiService.isLoggedIn) {
          await _registerDeviceToken(apiService, token);
        }
      },
      onMessageReceived: (message) {
        debugPrint('Message received: ${message.notification?.title}');
      },
      onMessageOpenedApp: (message) {
        debugPrint(
          'App opened from notification: ${message.notification?.title}',
        );
        _handleExternalNotification(message);
      },
    );

    _fcmService.onNotificationTapNavigation = _handleNotificationData;
  }

  void _handleExternalNotification(RemoteMessage message) {
    _handleNotificationData(message.data);
  }

  void _handleNotificationData(Map<String, dynamic> data) {
    final isAdmin = Provider.of<AuthService>(context, listen: false)
            .currentUser
            ?.isAdmin ??
        false;
    Future.delayed(const Duration(milliseconds: 500), () {
      final n = _notificationFromPayload(data);
      NotificationNavigation.navigateWithKey(appNavigatorKey, n, isAdmin: isAdmin);
    });
  }

  NotificationData _notificationFromPayload(Map<String, dynamic> data) {
    final rt = data['resource_type'] as String?;
    String? rid;
    if (data['resource_id'] != null) {
      rid = data['resource_id'].toString();
    }
    return NotificationData(
      id: (data['notification_id'] ?? '').toString(),
      title: '',
      body: '',
      isRead: false,
      resourceType: rt,
      resourceId: rid,
    );
  }

  Future<void> _registerDeviceToken(ApiService apiService, String token) async {
    try {
      final response = await apiService.post<void>(
        ApiConstants.devicesRegister,
        {'token': token, 'platform': _getPlatform()},
        requireAuth: true,
      );

      if (response.success) {
        debugPrint('Device token registered successfully');
      } else {
        debugPrint(
          'Device token registration failed: ${response.displayMessage}',
        );
      }
    } catch (e) {
      debugPrint('Failed to register device token: $e');
    }
  }

  String _getPlatform() {
    if (Theme.of(context).platform == TargetPlatform.iOS) {
      return 'ios';
    } else if (Theme.of(context).platform == TargetPlatform.macOS) {
      return 'macos';
    } else {
      return 'android';
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final languageProvider = Provider.of<LanguageProvider>(context);

    return MaterialApp(
      navigatorKey: appNavigatorKey,
      title: 'CucHum',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeProvider.themeMode,
      locale: Locale(languageProvider.languageCode),
      supportedLocales: const [Locale('en'), Locale('vi')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const LoginScreen(),
    );
  }
}
