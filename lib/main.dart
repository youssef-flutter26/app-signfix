import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/app_theme.dart';
import 'services/api_client.dart' as cust;
import 'technician/services/api_client.dart' as tech;

import 'screens/portal/portal_selection_screen.dart';

// Customer screens
import 'screens/auth/login_screen.dart' as cust_auth;
import 'screens/home/customer_home.dart';
import 'screens/activity/quotation_detail_screen.dart';

// Technician screens
import 'technician/screens/auth/login_screen.dart' as tech_auth;
import 'technician/screens/shell/app_shell.dart';

// Global navigator key — allows logout to pop all routes from anywhere
final _navigatorKey = GlobalKey<NavigatorState>();

// Background message handler — must be top-level function
@pragma('vm:entry-point')
Future<void> _firebaseBackgroundHandler(RemoteMessage message) async {
  // Background messages handled silently
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Firebase init — gracefully skip if google-services.json not configured
  try {
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(_firebaseBackgroundHandler);
  } catch (_) {
    // Firebase not configured — push notifications disabled, app works normally
  }
  runApp(const SignFixApp());
}

class SignFixApp extends StatefulWidget {
  const SignFixApp({super.key});
  @override
  State<SignFixApp> createState() => _SignFixAppState();
}

class _SignFixAppState extends State<SignFixApp> {
  final _customerApi = cust.ApiClient();
  final _technicianApi = tech.TechnicianApi();
  bool _ready = false;
  PortalType? _selectedPortal;
  RemoteMessage? _pendingPushMessage;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await Future.wait([
      _customerApi.restoreSession(),
      _technicianApi.restoreSession(),
    ]);
    // Register FCM token if logged in
    await _setupFcm();
    if (mounted) setState(() => _ready = true);
    final pendingMessage = _pendingPushMessage;
    _pendingPushMessage = null;
    if (pendingMessage != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _openQuotationFromPush(pendingMessage);
      });
    }
  }

  Future<void> _setupFcm() async {
    try {
      final messaging = FirebaseMessaging.instance;
      // Request permission (Android 13+ and iOS)
      await messaging.requestPermission(alert: true, badge: true, sound: true);
      final fcmToken = await messaging.getToken();
      if (fcmToken != null) {
        // Register token with backend for whichever portal is logged in
        if (_customerApi.token != null) {
          await _customerApi.registerDeviceToken(fcmToken);
        }
        if (_technicianApi.token != null) {
          await _technicianApi.registerDeviceToken(fcmToken);
        }
      }
      _pendingPushMessage = await messaging.getInitialMessage();
      FirebaseMessaging.onMessageOpenedApp.listen(_openQuotationFromPush);
      // Listen for token refresh
      messaging.onTokenRefresh.listen((newToken) async {
        if (_customerApi.token != null) {
          await _customerApi.registerDeviceToken(newToken);
        }
        if (_technicianApi.token != null) {
          await _technicianApi.registerDeviceToken(newToken);
        }
      });
      // Foreground notifications
      FirebaseMessaging.onMessage.listen((message) {
        final notification = message.notification;
        if (notification != null && _navigatorKey.currentContext != null) {
          final quotationNo = _quotationNoFromPush(message);
          ScaffoldMessenger.of(_navigatorKey.currentContext!).showSnackBar(
            SnackBar(
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(notification.title ?? 'SignFix',
                      style: const TextStyle(
                          fontWeight: FontWeight.w800, color: AppColors.white)),
                  if (notification.body != null)
                    Text(notification.body!,
                        style: const TextStyle(color: AppColors.white70)),
                ],
              ),
              backgroundColor: AppColors.navyDark,
              duration: const Duration(seconds: 4),
              behavior: SnackBarBehavior.floating,
              action: quotationNo == null
                  ? null
                  : SnackBarAction(
                      label: 'View',
                      textColor: AppColors.gold,
                      onPressed: () => _openQuotationFromPush(message),
                    ),
            ),
          );
        }
      });
    } catch (_) {
      // Firebase not configured — skip silently
    }
  }

  String? _quotationNoFromPush(RemoteMessage message) {
    final eventKey = message.data['eventKey']?.toString();
    if (eventKey != 'quotation.sent' && eventKey != 'quotation.expiring') {
      return null;
    }
    final quotationNo = message.data['quotationNo']?.toString();
    return quotationNo == null || quotationNo.isEmpty ? null : quotationNo;
  }

  void _openQuotationFromPush(RemoteMessage message) {
    final quotationNo = _quotationNoFromPush(message);
    if (quotationNo == null) return;
    if (_customerApi.token == null) {
      _pendingPushMessage = message;
      return;
    }
    final context = _navigatorKey.currentContext;
    if (context == null) {
      _pendingPushMessage = message;
      return;
    }
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => QuotationDetailScreen(
        api: _customerApi,
        quotationNo: quotationNo,
      ),
    ));
  }

  void _refresh() {
    setState(() => _selectedPortal = null);
    final pendingMessage = _pendingPushMessage;
    if (_customerApi.token != null && pendingMessage != null) {
      _pendingPushMessage = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _openQuotationFromPush(pendingMessage);
      });
    }
  }

  void _onPortalSelect(PortalType portal) =>
      setState(() => _selectedPortal = portal);

  Future<void> _logout() async {
    // Unregister FCM token before logout
    try {
      final fcmToken = await FirebaseMessaging.instance.getToken();
      if (fcmToken != null) {
        if (_customerApi.token != null) {
          await _customerApi.unregisterDeviceToken(fcmToken);
        }
        if (_technicianApi.token != null) {
          await _technicianApi.unregisterDeviceToken(fcmToken);
        }
      }
    } catch (_) {}

    // 1. Clear tokens
    await _customerApi.logout();
    await _technicianApi.logout();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('last_portal');

    // 2. Pop ALL pushed routes
    _navigatorKey.currentState?.popUntil((route) => route.isFirst);

    // 3. Rebuild root → now shows portal selection
    if (mounted) {
      setState(() {
        _selectedPortal = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
        navigatorKey: _navigatorKey, // ✅ global key
        debugShowCheckedModeBanner: false,
        title: 'SignFix',
        theme: buildAppTheme(),
        home: !_ready ? const _SplashScreen() : _buildHome(),
      );

  Widget _buildHome() {
    // Already logged in
    if (_customerApi.token != null) {
      return CustomerHome(api: _customerApi, onLogout: _logout);
    }
    if (_technicianApi.token != null) {
      return AppShell(api: _technicianApi, onLogout: _logout);
    }

    // Portal selected → login screen
    if (_selectedPortal == PortalType.customer) {
      return cust_auth.LoginScreen(
        api: _customerApi,
        onAuthenticated: _refresh,
        onBack: () => setState(() => _selectedPortal = null),
      );
    }
    if (_selectedPortal == PortalType.technician) {
      return tech_auth.LoginScreen(
        api: _technicianApi,
        onAuthenticated: _refresh,
        onBack: () => setState(() => _selectedPortal = null),
      );
    }

    // No session → portal selection
    return PortalSelectionScreen(onSelect: _onPortalSelect);
  }
}

// ── Splash ─────────────────────────────────────────────────────────────────────
class _SplashScreen extends StatelessWidget {
  const _SplashScreen();
  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.splashBg,
        body: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                      color: AppColors.gold.withValues(alpha: .3),
                      blurRadius: 24)
                ],
              ),
              child: ClipOval(
                child:
                    Image.asset('assets/images/logo.jpeg', fit: BoxFit.cover),
              ),
            ),
            const SizedBox(height: 24),
            const CircularProgressIndicator(color: AppColors.gold),
          ]),
        ),
      );
}
