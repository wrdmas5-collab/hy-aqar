import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import 'package:video_player/video_player.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:convert';
import 'dart:ui';
import 'dart:math';
import 'dart:async';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'dart:io';
import 'dart:typed_data';

import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;
import 'package:image_picker/image_picker.dart';


String? pendingResetOobCode;
bool bannerAutoPlay = true;

/// تحديد ما إذا كان اشتراك الطالب في مقرر/دورة ما زال ساري المفعول.
/// يعتمد على سجل الحساب السحابي (unlockedUsers) + مدة الاشتراك durationDays،
/// مع التحقق من عدم قيام الأدمن بتعطيل الاشتراك (disabled == true).
bool isSubscriptionActive(Map? unlockInfo, {int defaultDays = 120}) {
  if (unlockInfo == null) return false;
  // إذا أوقف الأدمن الاشتراك يدوياً → يغلق المحتوى فوراً
  if (unlockInfo['disabled'] == true) return false;

  final activatedRaw = unlockInfo['activatedAt'];
  DateTime? activatedDate;
  if (activatedRaw is Timestamp) {
    activatedDate = activatedRaw.toDate();
  } else if (activatedRaw is String) {
    activatedDate = DateTime.tryParse(activatedRaw);
  }
  // سجل قديم بلا تاريخ تفعيل → نعتبره مفعّلاً ما لم يُعطّل
  if (activatedDate == null) return true;

  int days = defaultDays;
  final d = unlockInfo['durationDays'];
  if (d is int) {
    days = d;
  } else if (d is num) {
    days = d.toInt();
  } else if (d is String) {
    days = int.tryParse(d) ?? defaultDays;
  }
  if (days <= 0) days = defaultDays;

  return DateTime.now().isBefore(activatedDate.add(Duration(days: days)));
}

String normalizePdfUrl(String input) {
  final uri = Uri.tryParse(input.trim());
  if (uri == null) return input;
  if (uri.host.contains('drive.google.com')) {
    final id = uri.queryParameters['id'] ??
        RegExp(r'/file/d/([^/]+)').firstMatch(uri.path)?.group(1);
    if (id != null && id.isNotEmpty) {
      return 'https://drive.google.com/uc?export=download&id=${Uri.encodeComponent(id)}';
    }
  }
  if (uri.host.contains('docs.google.com') && uri.pathSegments.contains('document')) {
    final index = uri.pathSegments.indexOf('d');
    if (index >= 0 && index + 1 < uri.pathSegments.length) {
      final id = uri.pathSegments[index + 1];
      return 'https://docs.google.com/document/d/$id/export?format=pdf';
    }
  }
  return input;
}

Future<String?> downloadPdfToLocal(String url, String fileName) async {
  try {
    final resolvedUrl = normalizePdfUrl(url);
    if (kIsWeb) {
      final uri = Uri.parse(resolvedUrl);
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened) return null;
      final prefs = await SharedPreferences.getInstance();
      final localPdfs = prefs.getStringList('local_pdfs') ?? <String>[];
      final entry = '$resolvedUrl|web_download|$fileName';
      if (!localPdfs.contains(entry)) {
        localPdfs.add(entry);
        await prefs.setStringList('local_pdfs', localPdfs);
      }
      return 'web_download:$fileName';
    }

    final response = await http.get(Uri.parse(resolvedUrl));
    if (response.statusCode != 200) return null;
    final bytes = response.bodyBytes;
    // Reject Google Drive login/permission HTML pages saved with a .pdf extension.
    if (bytes.length < 5 || String.fromCharCodes(bytes.take(5)) != '%PDF-') return null;

    final dir = await getApplicationDocumentsDirectory();
    final safeName = fileName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    final finalName = safeName.toLowerCase().endsWith('.pdf') ? safeName : '$safeName.pdf';
    final file = File('${dir.path}/$finalName');
    await file.writeAsBytes(bytes, flush: true);

    final prefs = await SharedPreferences.getInstance();
    final localPdfs = prefs.getStringList('local_pdfs') ?? <String>[];
    final entry = '$resolvedUrl|${file.path}|$finalName';
    if (!localPdfs.contains(entry)) {
      localPdfs.add(entry);
      await prefs.setStringList('local_pdfs', localPdfs);
    }
    return file.path;
  } catch (e) {
    debugPrint('PDF Download error: $e');
    return null;
  }
}

const FirebaseOptions _hyFirebaseOptions = FirebaseOptions(
  apiKey: 'AIzaSyCxMtCMtFHlbDMBWZpHRzqwF0YDz_P9Yzo',
  authDomain: 'hy-aqar.firebaseapp.com',
  projectId: 'hy-aqar',
  storageBucket: 'hy-aqar.firebasestorage.app',
  messagingSenderId: '960269964659',
  appId: '1:960269964659:web:10c758de7d84066f8fe106',
  measurementId: 'G-PC5B02LC48',
);

// Register the Android package in Firebase Console and pass its Android App ID
// at build time. The archive did not contain google-services.json or an Android
// Firebase app ID, so the web ID is retained only as a fallback for old builds.
const String _androidFirebaseAppId = String.fromEnvironment(
  'FIREBASE_ANDROID_APP_ID',
);

FirebaseOptions get _hyFirebaseOptionsForCurrentPlatform {
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    final androidAppId = _androidFirebaseAppId.trim();
    if (androidAppId.isNotEmpty) {
      return FirebaseOptions(
        apiKey: _hyFirebaseOptions.apiKey,
        appId: androidAppId,
        messagingSenderId: _hyFirebaseOptions.messagingSenderId,
        projectId: _hyFirebaseOptions.projectId,
        storageBucket: _hyFirebaseOptions.storageBucket,
      );
    }
    if (_hyFirebaseOptions.appId.contains(':web:')) {
      debugPrint(
        'FIREBASE-ANDROID-CONFIG-WARN: Android App ID is not configured. '
        'Build with --dart-define=FIREBASE_ANDROID_APP_ID=<Android App ID>.',
      );
    }
  }
  return _hyFirebaseOptions;
}

Future<FirebaseApp>? _firebaseInitializationFuture;

Future<FirebaseApp> _ensureFirebaseInitialized() {
  if (Firebase.apps.isNotEmpty) {
    return Future<FirebaseApp>.value(Firebase.app());
  }

  final pending = _firebaseInitializationFuture;
  if (pending != null) return pending;

  final initialization = Firebase.initializeApp(
    options: _hyFirebaseOptionsForCurrentPlatform,
  );
  _firebaseInitializationFuture = initialization;
  return initialization.catchError((Object error, StackTrace stackTrace) {
    if (identical(_firebaseInitializationFuture, initialization)) {
      _firebaseInitializationFuture = null;
    }
    Error.throwWithStackTrace(error, stackTrace);
  });
}

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await _ensureFirebaseInitialized().timeout(const Duration(seconds: 15));
    debugPrint('FCM-BACKGROUND: message=${message.messageId ?? 'unknown'}');
  } catch (error, stackTrace) {
    debugPrint('FCM-BACKGROUND-ERROR: $error');
    debugPrint('FCM-BACKGROUND-STACK: $stackTrace');
  }
}

void _showResetPasswordDialog(BuildContext context, String oobCode) {
  final newPassCtrl = TextEditingController();
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: const Color(0xFF14141C),
      title: const Text('إعادة تعيين كلمة المرور', style: TextStyle(color: Colors.white)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('أدخل كلمة السر الجديدة', style: TextStyle(color: Colors.white70)),
          const SizedBox(height: 10),
          TextField(
            controller: newPassCtrl,
            obscureText: true,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              labelText: 'كلمة السر الجديدة',
              labelStyle: TextStyle(color: Colors.white70),
              enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFFE52521))),
              focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.redAccent)),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('إلغاء', style: TextStyle(color: Colors.grey)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE52521)),
          onPressed: () async {
            try {
              if (newPassCtrl.text.trim().length < 6) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('كلمة السر يجب أن تكون 6 خانات على الأقل')),
                );
                return;
              }
              await FirebaseAuth.instance.confirmPasswordReset(
                code: oobCode,
                newPassword: newPassCtrl.text.trim(),
              );
              if (!context.mounted) return;
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('تم إعادة تعيين كلمة المرور بنجاح ✅')),
              );
} on FirebaseAuthException catch (e) {
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('فشل: ${e.message}')),
              );
            }
          },
          child: const Text('تأكيد', style: TextStyle(color: Colors.white)),
        ),
],
      ),
    );
  }

void main() {
  runZonedGuarded(() {
    WidgetsFlutterBinding.ensureInitialized();

    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.presentError(details);
      debugPrint('FLUTTER-ERROR: ${details.exceptionAsString()}');
      if (details.stack != null) {
        debugPrint('FLUTTER-ERROR-STACK: ${details.stack}');
      }
    };

    PlatformDispatcher.instance.onError = (Object error, StackTrace stackTrace) {
      debugPrint('PLATFORM-UNCAUGHT-ERROR: $error');
      debugPrint('PLATFORM-UNCAUGHT-STACK: $stackTrace');
      return true;
    };

    // Release builds should show a readable recovery surface instead of a blank
    // render area if a widget throws while building.
    ErrorWidget.builder = (FlutterErrorDetails details) {
      final message = details.exceptionAsString();
      return Directionality(
        textDirection: TextDirection.rtl,
        child: Material(
          color: const Color(0xFF101116),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline_rounded,
                      color: Color(0xFFFF6B6B), size: 42),
                  const SizedBox(height: 12),
                  const Text(
                    'حدث خطأ أثناء عرض هذه الشاشة',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    message.length > 180 ? '${message.substring(0, 180)}…' : message,
                    style: const TextStyle(color: Colors.white70, fontSize: 11),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    };

    runApp(const HyAcademyBootstrap());
  }, (Object error, StackTrace stackTrace) {
    debugPrint('ZONE-UNCAUGHT-ERROR: $error');
    debugPrint('ZONE-UNCAUGHT-STACK: $stackTrace');
  });
}

class HyAcademyBootstrap extends StatefulWidget {
  const HyAcademyBootstrap({super.key});

  @override
  State<HyAcademyBootstrap> createState() => _HyAcademyBootstrapState();
}

class _HyAcademyBootstrapState extends State<HyAcademyBootstrap> {
  HyAcademyApp? _application;
  Object? _startupError;
  bool _isInitializing = false;
  int _initializationAttempt = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeApplication();
    });
  }

  Future<void> _initializeApplication() async {
    if (_isInitializing) return;
    _isInitializing = true;
    if (mounted) {
      setState(() {
        _startupError = null;
        _application = null;
      });
    }

    final attempt = ++_initializationAttempt;
    debugPrint('APP-START: initialization attempt=$attempt');

    try {
      // Firebase is required by authentication, Firestore and the store.
      await _ensureFirebaseInitialized()
          .timeout(const Duration(seconds: 18));
      debugPrint('APP-START-FIREBASE-OK');

      // Supabase is used for uploads. A temporary storage service outage must
      // not prevent the application UI from opening.
      try {
        await Supabase.initialize(
          url: 'https://myyblhbcrfjrvxqseshx.supabase.co',
          publishableKey: 'sb_publishable_O8CJ24wTPhEN0UC3X0reWw_9JVoAXCB',
        ).timeout(const Duration(seconds: 12));
        debugPrint('APP-START-SUPABASE-OK');
      } catch (error, stackTrace) {
        debugPrint('APP-START-SUPABASE-WARN: $error');
        debugPrint('APP-START-SUPABASE-STACK: $stackTrace');
      }

      // Push notifications are optional during first-frame startup.
      unawaited(_initializeFirebaseMessaging());

      SharedPreferences? preferences;
      try {
        preferences = await SharedPreferences.getInstance()
            .timeout(const Duration(seconds: 8));
      } catch (error, stackTrace) {
        debugPrint('APP-START-PREFERENCES-WARN: $error');
        debugPrint('APP-START-PREFERENCES-STACK: $stackTrace');
      }

      final prefs = preferences;
      final resetCode = _readPendingResetCode();
      final app = HyAcademyApp(
        isLoggedIn: prefs?.getBool('is_logged_in') ?? false,
        initialName: prefs?.getString('user_name') ?? '',
        initialPhone: prefs?.getString('user_phone') ?? '',
        initialUid: prefs?.getString('user_uid') ?? '',
        initialIsAdmin: prefs?.getBool('is_admin') ?? false,
        initialAdminPerms: prefs?.getStringList('admin_perms') ?? <String>[],
        pendingResetOobCode: resetCode,
      );

      if (!mounted) return;
      setState(() {
        _application = app;
        _startupError = null;
      });
      debugPrint('APP-START-DONE');
    } catch (error, stackTrace) {
      debugPrint('APP-START-FAILED: $error');
      debugPrint('APP-START-STACK: $stackTrace');
      if (mounted) {
        setState(() {
          _startupError = error;
        });
      }
    } finally {
      _isInitializing = false;
      if (mounted) setState(() {});
    }
  }

  String? _readPendingResetCode() {
    if (!kIsWeb) return null;
    final parameters = Uri.base.queryParameters;
    if (parameters['mode'] == 'resetPassword' &&
        parameters['oobCode'] != null &&
        parameters['oobCode']!.isNotEmpty) {
      pendingResetOobCode = parameters['oobCode'];
      return pendingResetOobCode;
    }
    pendingResetOobCode = null;
    return null;
  }

  Future<void> _initializeFirebaseMessaging() async {
    try {
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
      final messaging = FirebaseMessaging.instance;
      final settings = await messaging
          .requestPermission(alert: true, badge: true, sound: true)
          .timeout(const Duration(seconds: 8));
      debugPrint('FCM-PERMISSION: ${settings.authorizationStatus}');

      if (!kIsWeb) {
        try {
          await messaging.subscribeToTopic('all_users')
              .timeout(const Duration(seconds: 6));
        } catch (error) {
          debugPrint('FCM-SUBSCRIBE-WARN: $error');
        }
      }

      final token = await messaging.getToken()
          .timeout(const Duration(seconds: 8));
      // Never write the full registration token to logs.
      debugPrint('FCM-TOKEN: ${token == null ? 'unavailable' : 'available'}');

      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint('FCM-FOREGROUND: received notification');
        if (message.notification != null) {
          addAppNotification(
            targetUserName: '',
            title: message.notification?.title ?? 'إشعار جديد',
            message: message.notification?.body ?? '',
            icon: Icons.notifications_active_rounded,
            iconColor: const Color(0xFFE52521),
          );
        }
      });
    } catch (error, stackTrace) {
      debugPrint('FCM-INITIALIZATION-WARN: $error');
      debugPrint('FCM-INITIALIZATION-STACK: $stackTrace');
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = _application;
    if (app != null) return app;

    return MaterialApp(
      title: 'hy Academy',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true),
      home: _StartupRecoveryScreen(
        isLoading: _isInitializing,
        error: _startupError,
        attempt: _initializationAttempt,
        onRetry: _initializeApplication,
      ),
    );
  }
}

class _StartupRecoveryScreen extends StatelessWidget {
  final bool isLoading;
  final Object? error;
  final int attempt;
  final Future<void> Function() onRetry;

  const _StartupRecoveryScreen({
    required this.isLoading,
    required this.error,
    required this.attempt,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final hasError = error != null;
    return Scaffold(
      backgroundColor: const Color(0xFF0F1016),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      gradient: const LinearGradient(
                        colors: [Color(0xFFE52521), Color(0xFFFF6D65)],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Color(0x44E52521),
                          blurRadius: 24,
                          offset: Offset(0, 8),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.school_rounded,
                        color: Colors.white, size: 34),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'hy Academy',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    hasError
                        ? 'تعذّر تجهيز بعض خدمات التطبيق.'
                        : 'جارٍ تجهيز التطبيق بأمان...',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  const SizedBox(height: 22),
                  if (isLoading)
                    const SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Color(0xFFE52521),
                      ),
                    ),
                  if (hasError) ...[
                    Text(
                      'رمز المحاولة: APP-START-$attempt',
                      style: const TextStyle(color: Colors.white38, fontSize: 11),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: isLoading ? null : onRetry,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFE52521),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('إعادة المحاولة'),
                      ),
                    ),
                  ],
                  if (hasError)
                    Padding(
                      padding: const EdgeInsets.only(top: 14),
                      child: Text(
                        error.toString().length > 160
                            ? '${error.toString().substring(0, 160)}…'
                            : error.toString(),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white38,
                          fontSize: 10,
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

class HyAcademyApp extends StatefulWidget {
  final bool isLoggedIn;
  final String initialName;
  final String initialPhone;
  final String initialUid;
  final bool initialIsAdmin;
  final List<String> initialAdminPerms;
  final String? pendingResetOobCode;

  const HyAcademyApp({
    super.key,
    required this.isLoggedIn,
    required this.initialName,
    required this.initialPhone,
    required this.initialUid,
    required this.initialIsAdmin,
    required this.initialAdminPerms,
    this.pendingResetOobCode,
  });

  @override
  State<HyAcademyApp> createState() => _HyAcademyAppState();

  static _HyAcademyAppState of(BuildContext context) =>
      context.findAncestorStateOfType<_HyAcademyAppState>()!;
}

class _HyAcademyAppState extends State<HyAcademyApp> {
  bool isDarkMode = true;

  @override
  void initState() {
    super.initState();
    if (widget.pendingResetOobCode != null) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _showResetPasswordDialog(context, widget.pendingResetOobCode!),
      );
    }
  }

  void toggleTheme() {
    setState(() {
      isDarkMode = !isDarkMode;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'hy Academy',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: isDarkMode ? Brightness.dark : Brightness.light,
        scaffoldBackgroundColor: isDarkMode ? const Color(0xFF0F0F12) : const Color(0xFFF9F9FB),
        primaryColor: const Color(0xFFE52521),
        fontFamily: 'Roboto',
        colorScheme: isDarkMode
            ? const ColorScheme.dark(
                primary: Color(0xFFE52521),
                secondary: Color(0xFFFF4D4D),
                surface: Color(0xFF181820),
              )
            : const ColorScheme.light(
                primary: Color(0xFFD32F2F),
                secondary: Color(0xFFFF5252),
                surface: Color(0xFFFFFFFF),
              ),
        appBarTheme: AppBarTheme(
          backgroundColor: isDarkMode ? const Color(0xFF14141C) : const Color(0xFFFFFFFF),
          elevation: 0,
          centerTitle: true,
          titleTextStyle: const TextStyle(
            color: Color(0xFFE52521),
            fontSize: 22,
            fontWeight: FontWeight.w900,
            letterSpacing: 2.0,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFE52521),
            foregroundColor: Colors.white,
            textStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
            elevation: 8,
            shadowColor: const Color(0x55E52521),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
          ),
        ),
      ),
      home: SplashScreen(
        isLoggedIn: widget.isLoggedIn,
        initialName: widget.initialName,
        initialPhone: widget.initialPhone,
        initialUid: widget.initialUid,
        initialIsAdmin: widget.initialIsAdmin,
        initialAdminPerms: widget.initialAdminPerms,
      ),
    );
  }
}

/// مشغل يوتيوب محمي بالكامل: يمنع ظهور اسم القناة أو عنوان الفيديو أو زر المشاركة أو نسخ الرابط
class SecureYouTubePlayer extends StatelessWidget {
  final YoutubePlayerController controller;
  final bool showControls;

  const SecureYouTubePlayer({
    super.key,
    required this.controller,
    this.showControls = true,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Stack(
        children: [
          YoutubePlayer(
            controller: controller,
            aspectRatio: 16 / 9,
          ),
          // حجب الشريط العلوي بالكامل لمنع الضغط على اسم القناة أو العنوان أو زر المشاركة/نسخ الرابط
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 62,
            child: AbsorbPointer(
              absorbing: true,
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xFF0F0F12),
                      Color(0xCC0F0F12),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),
          // حجب شعار YouTube في الزاوية السفلية اليمنى لمنع فتح الفيديو في تطبيق يوتيوب أو المتصفح
          Positioned(
            bottom: 0,
            right: 0,
            width: 115,
            height: 48,
            child: AbsorbPointer(
              absorbing: true,
              child: Container(color: Colors.transparent),
            ),
          ),
          // حجب الزاوية السفلية اليسرى (شعار المشاهدة على يوتيوب إن ظهر)
          Positioned(
            bottom: 0,
            left: 0,
            width: 90,
            height: 36,
            child: AbsorbPointer(
              absorbing: true,
              child: Container(color: Colors.transparent),
            ),
          ),
        ],
      ),
    );
  }
}

class FloatingSticker3D extends StatefulWidget {
  final String imageUrl;
  final IconData fallbackIcon;
  final double? top;
  final double? bottom;
  final double? left;
  final double? right;
  final Duration duration;
  final double size;

  const FloatingSticker3D({
    super.key,
    required this.imageUrl,
    required this.fallbackIcon,
    this.top,
    this.bottom,
    this.left,
    this.right,
    required this.duration,
    this.size = 65,
  });

  @override
  State<FloatingSticker3D> createState() => _FloatingSticker3DState();
}

class _FloatingSticker3DState extends State<FloatingSticker3D>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration)
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        double dy = sin(_controller.value * 2 * pi) * 16;
        double dx = cos(_controller.value * 2 * pi) * 12;
        double angle = sin(_controller.value * 2 * pi) * 0.12;

        return Positioned(
          top: widget.top != null ? widget.top! + dy : null,
          bottom: widget.bottom != null ? widget.bottom! - dy : null,
          left: widget.left != null ? widget.left! + dx : null,
          right: widget.right != null ? widget.right! - dx : null,
          child: IgnorePointer(
            child: Transform(
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.001)
                ..rotateX(angle)
                ..rotateY(angle)
                ..rotateZ(angle * 0.5),
              alignment: Alignment.center,
              child: Container(
                width: widget.size,
                height: widget.size,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.35),
                      blurRadius: 15,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: CachedNetworkImage(
                    imageUrl: widget.imageUrl,
                    fit: BoxFit.cover,
                    memCacheWidth: 150,
                    memCacheHeight: 150,
                    placeholder: (context, url) => Center(
                      child: Icon(widget.fallbackIcon, color: const Color(0xFFE52521), size: 26),
                    ),
                    errorWidget: (context, url, error) => Center(
                      child: Icon(widget.fallbackIcon, color: const Color(0xFFE52521), size: 26),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class BackgroundStickersLayer extends StatelessWidget {
  const BackgroundStickersLayer({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: const [
        FloatingSticker3D(
          imageUrl: 'https://images.unsplash.com/photo-1588776814546-1ffcf47267a5?w=200',
          fallbackIcon: Icons.medical_services_rounded,
          top: 20,
          left: 15,
          duration: Duration(seconds: 4),
          size: 65,
        ),
        FloatingSticker3D(
          imageUrl: 'https://images.unsplash.com/photo-1581291518633-83b4ebd1d83e?w=200',
          fallbackIcon: Icons.architecture_rounded,
          top: 25,
          right: 20,
          duration: Duration(seconds: 5),
          size: 65,
        ),
        FloatingSticker3D(
          imageUrl: 'https://images.unsplash.com/photo-1513364776144-60967b0f800f?w=200',
          fallbackIcon: Icons.palette_rounded,
          bottom: 30,
          left: 25,
          duration: Duration(seconds: 6),
          size: 65,
        ),
        FloatingSticker3D(
          imageUrl: 'https://images.unsplash.com/photo-1532187863486-abf9dbad1b69?w=200',
          fallbackIcon: Icons.science_rounded,
          bottom: 25,
          right: 30,
          duration: Duration(seconds: 4),
          size: 65,
        ),
        FloatingSticker3D(
          imageUrl: 'https://images.unsplash.com/photo-1607604276583-eef5d076aa5f?w=200',
          fallbackIcon: Icons.school_rounded,
          top: 150,
          left: 10,
          duration: Duration(seconds: 5),
          size: 60,
        ),
        FloatingSticker3D(
          imageUrl: 'https://images.unsplash.com/photo-1523240795612-9a054b0db644?w=200',
          fallbackIcon: Icons.menu_book_rounded,
          top: 160,
          right: 10,
          duration: Duration(seconds: 6),
          size: 60,
        ),
      ],
    );
  }
}

class SplashScreen extends StatefulWidget {
  final bool isLoggedIn;
  final String initialName;
  final String initialPhone;
  final String initialUid;
  final bool initialIsAdmin;
  final List<String> initialAdminPerms;

  const SplashScreen({
    super.key,
    required this.isLoggedIn,
    required this.initialName,
    required this.initialPhone,
    required this.initialUid,
    required this.initialIsAdmin,
    required this.initialAdminPerms,
  });

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    _controller.forward();

    Future.delayed(const Duration(seconds: 3), () {
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => widget.isLoggedIn
              ? HomeScreen(
                  userName: widget.initialName,
                  userPhone: widget.initialPhone,
                  userUid: widget.initialUid,
                  isAdmin: widget.initialIsAdmin,
                  adminPerms: widget.initialAdminPerms,
                )
              : const LoginScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
          transitionDuration: const Duration(milliseconds: 800),
        ),
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFE52521), width: 2),
                boxShadow: const [
                  BoxShadow(color: Color(0x33E52521), blurRadius: 25, spreadRadius: 6),
                ],
              ),
              child: ClipOval(
                child: Image.asset(
                  'assets/icon/icon.jpg',
                  width: 55,
                  height: 55,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) =>
                      const Icon(Icons.school_rounded, size: 55, color: Color(0xFFE52521)),
                ),
              ),
            ),
            const SizedBox(height: 24),
            ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
                colors: [Color(0xFFE52521), Color(0xFFFF7674)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ).createShader(bounds),
              child: const Text(
                'hy Academy',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2.5,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 8),
            const CircularProgressIndicator(color: Color(0xFFE52521)),
          ],
        ),
      ),
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with TickerProviderStateMixin {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController(text: '+963');
  final _passwordController = TextEditingController();
  final _uniController = TextEditingController();
  final _collegeController = TextEditingController();

  bool _isSignUp = false;
  bool _obscurePassword = true;
  bool _isSubmitting = false;

  final String adminPhone = '+963967834966';
  final String adminPass = '81644936';
  final String supportWhatsApp = '963967834966';

  double _rotateX = 0.0;
  double _rotateY = 0.0;

  late AnimationController _entryController;
  late Animation<double> _fadeAnim;
  late Animation<double> _scaleAnim;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();

    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _fadeAnim = CurvedAnimation(
      parent: _entryController,
      curve: Curves.easeOutCubic,
    );
    _scaleAnim = Tween<double>(begin: 0.88, end: 1.0).animate(
      CurvedAnimation(parent: _entryController, curve: Curves.easeOutBack),
    );
    _entryController.forward();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: -0.025, end: 0.025).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOutSine),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _uniController.dispose();
    _collegeController.dispose();
    _entryController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  void _onPointerHover(PointerHoverEvent event, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final pos = event.localPosition;
    setState(() {
      _rotateY = ((pos.dx - center.dx) / center.dx).clamp(-1.0, 1.0) * 0.16;
      _rotateX = -((pos.dy - center.dy) / center.dy).clamp(-1.0, 1.0) * 0.16;
    });
  }

  void _onPointerExit(PointerExitEvent event) {
    setState(() {
      _rotateX = 0.0;
      _rotateY = 0.0;
    });
  }

  void _toggleAuthMode(bool signUp) {
    if (_isSignUp == signUp) return;
    setState(() {
      _isSignUp = signUp;
    });
    _entryController
      ..reset()
      ..forward();
  }

  bool _isValidPassword8(String pass) {
    return pass.length >= 8;
  }

  bool _isValidTripleName(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    return parts.length >= 3;
  }

  Future<void> _openWhatsAppSupport() async {
    const msg =
        'مرحباً إدارة hy Academy، لدي مشكلة في الحساب أو تسجيل الدخول، يرجى الرد من قبل الإدارة وتوضيح ما يلي:\n- ';
    final waUrl = 'https://wa.me/$supportWhatsApp?text=${Uri.encodeComponent(msg)}';
    final uri = Uri.parse(waUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر فتح واتساب تلقائياً، الرقم: +963967834966')),
      );
    }
  }

  Future<void> _handleAuthAction() async {
    if (_isSubmitting) return;

    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();
    final pass = _passwordController.text.trim();

    if (phone.isEmpty || !phone.startsWith('+') || phone.length < 8) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى إدخال رقم الهاتف بشكل صحيح مع الرمز الدولي')),
      );
      return;
    }

    if (!_isValidPassword8(pass)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('كلمة السر يجب أن تكون 8 خانات على الأقل')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      // تحقق داخلي صامت من حساب المدير الأساسي أو المشرفين الفرعيين دون إظهار أي تمييز في الواجهة
      if (!_isSignUp) {
        if (phone == adminPhone && pass == adminPass) {
          final adminDisplayName = name.isNotEmpty ? name : 'م. حيان المصري';
          final uid = 'ADMIN-UID-$phone';
          const perms = ['all'];

          try {
            await FirebaseFirestore.instance.collection('users').doc(uid).set({
              'name': adminDisplayName,
              'phone': phone,
              'isAdmin': true,
              'lastLogin': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));
          } catch (_) {}

          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('is_logged_in', true);
          await prefs.setString('user_name', adminDisplayName);
          await prefs.setString('user_phone', phone);
          await prefs.setString('user_uid', uid);
          await prefs.setBool('is_admin', true);
          await prefs.setStringList('admin_perms', perms);

          if (!mounted) return;
          Navigator.pushReplacement(
            context,
            PageRouteBuilder(
              pageBuilder: (_, __, ___) => HomeScreen(
                userName: adminDisplayName,
                userPhone: phone,
                userUid: uid,
                isAdmin: true,
                adminPerms: perms,
              ),
              transitionsBuilder: (_, anim, __, child) =>
                  FadeTransition(opacity: anim, child: child),
              transitionDuration: const Duration(milliseconds: 500),
            ),
          );
          return;
        }

        final subQuery = await FirebaseFirestore.instance
            .collection('sub_admins')
            .where('phone', isEqualTo: phone)
            .where('pass', isEqualTo: pass)
            .where('isActive', isEqualTo: true)
            .limit(1)
            .get();

        if (subQuery.docs.isNotEmpty) {
          final subDoc = subQuery.docs.first;
          final subData = subDoc.data();
          final subName =
              (name.isNotEmpty ? name : (subData['name'] ?? 'مشرف')).toString();
          final uid = 'SUB-ADMIN-${subDoc.id}';
          final perms = <String>[];
          final permsMap = subData['permissions'] as Map<String, dynamic>?;
          if (permsMap != null) {
            permsMap.forEach((k, v) {
              if (v == true) perms.add(k);
            });
          }

          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('is_logged_in', true);
          await prefs.setString('user_name', subName);
          await prefs.setString('user_phone', phone);
          await prefs.setString('user_uid', uid);
          await prefs.setBool('is_admin', true);
          await prefs.setStringList('admin_perms', perms);

          if (!mounted) return;
          Navigator.pushReplacement(
            context,
            PageRouteBuilder(
              pageBuilder: (_, __, ___) => HomeScreen(
                userName: subName,
                userPhone: phone,
                userUid: uid,
                isAdmin: true,
                adminPerms: perms,
              ),
              transitionsBuilder: (_, anim, __, child) =>
                  FadeTransition(opacity: anim, child: child),
              transitionDuration: const Duration(milliseconds: 500),
            ),
          );
          return;
        }
      }

      // عند إنشاء حساب جديد فقط: نطلب الاسم الثلاثي والجامعة والكلية
      final uniText = _uniController.text.trim();
      final collegeText = _collegeController.text.trim();
      if (_isSignUp) {
        if (!_isValidTripleName(name)) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('يرجى إدخال الاسم الثلاثي كاملاً')),
          );
          return;
        }

        if (uniText.isEmpty || collegeText.isEmpty) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('يرجى إدخال الجامعة والكلية')),
          );
          return;
        }
      }

      final cleanPhoneDigits = phone.replaceAll(RegExp(r'[^0-9]'), '');
      final authEmail = 'u$cleanPhoneDigits@hyacademy.local';
      final userDocRef = FirebaseFirestore.instance
          .collection('student_accounts')
          .doc(cleanPhoneDigits);

      if (_isSignUp) {
        final existing = await userDocRef.get();
        if (existing.exists) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('هذا الرقم مسجل مسبقاً، يمكنك تسجيل الدخول مباشرة')),
          );
          return;
        }

        String uid = 'USER-$cleanPhoneDigits';
        try {
          final cred =
              await FirebaseAuth.instance.createUserWithEmailAndPassword(
            email: authEmail,
            password: pass,
          );
          if (cred.user != null) {
            uid = cred.user!.uid;
            await cred.user!.updateDisplayName(name);
          }
        } on FirebaseAuthException catch (e) {
          if (e.code != 'email-already-in-use' &&
              e.code != 'operation-not-allowed') {
            debugPrint('Auth signup note: ${e.code}');
          }
        }

        await userDocRef.set({
          'uid': uid,
          'fullName': name,
          'phone': phone,
          'password': pass,
          'university': uniText,
          'college': collegeText,
          'isAdmin': false,
          'createdAt': FieldValue.serverTimestamp(),
          'lastLogin': FieldValue.serverTimestamp(),
        });

        await FirebaseFirestore.instance.collection('users').doc(uid).set({
          'name': name,
          'phone': phone,
          'university': uniText,
          'college': collegeText,
          'isAdmin': false,
          'lastLogin': FieldValue.serverTimestamp(),
          'enrolledCourses': FieldValue.arrayUnion([]),
          'orders': FieldValue.arrayUnion([]),
          'createdAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('is_logged_in', true);
        await prefs.setString('user_name', name);
        await prefs.setString('user_phone', phone);
        await prefs.setString('user_uid', uid);
        await prefs.setString('user_university', uniText);
        await prefs.setString('user_college', collegeText);
        await prefs.setBool('is_admin', false);
        await prefs.setStringList('admin_perms', []);

        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            pageBuilder: (_, __, ___) => HomeScreen(
              userName: name,
              userPhone: phone,
              userUid: uid,
              isAdmin: false,
              adminPerms: const [],
            ),
            transitionsBuilder: (_, anim, __, child) =>
                FadeTransition(opacity: anim, child: child),
            transitionDuration: const Duration(milliseconds: 550),
          ),
        );
      } else {
        final snap = await userDocRef.get();
        if (!snap.exists) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('الحساب غير موجود، يرجى إنشاء حساب أولاً')),
          );
          return;
        }

        final data = snap.data() as Map<String, dynamic>;
        final savedName = (data['fullName'] ?? '').toString().trim();
        final savedPass = (data['password'] ?? '').toString();
        final savedUni = (data['university'] ?? '').toString();
        final savedCollege = (data['college'] ?? '').toString();

        // تسجيل الدخول: الرقم وكلمة السر فقط
        if (savedPass != pass) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('كلمة السر غير صحيحة')),
          );
          return;
        }

        final uid = (data['uid'] ?? 'USER-$cleanPhoneDigits').toString();
        await userDocRef.update({'lastLogin': FieldValue.serverTimestamp()});

        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('is_logged_in', true);
        await prefs.setString('user_name', savedName);
        await prefs.setString('user_phone', phone);
        await prefs.setString('user_uid', uid);
        await prefs.setString('user_university', savedUni);
        await prefs.setString('user_college', savedCollege);
        await prefs.setBool('is_admin', false);
        await prefs.setStringList('admin_perms', []);

        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            pageBuilder: (_, __, ___) => HomeScreen(
              userName: savedName,
              userPhone: phone,
              userUid: uid,
              isAdmin: false,
              adminPerms: const [],
            ),
            transitionsBuilder: (_, anim, __, child) =>
                FadeTransition(opacity: anim, child: child),
            transitionDuration: const Duration(milliseconds: 550),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('حدث خطأ أثناء العملية: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = HyAcademyApp.of(context).isDarkMode;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: Stack(
          children: [
            Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0, -0.55),
                  radius: 1.5,
                  colors: isDark
                      ? const [
                          Color(0xFF23161D),
                          Color(0xFF121218),
                          Color(0xFF0C0C0F)
                        ]
                      : const [
                          Color(0xFFFFFFFF),
                          Color(0xFFF3F3F8),
                          Color(0xFFE7E7F0)
                        ],
                ),
              ),
            ),
            const BackgroundStickersLayer(),
            Positioned(
              top: 22,
              left: 22,
              child: IconButton(
                icon: Icon(
                  isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                  color: const Color(0xFFE52521),
                  size: 28,
                ),
                onPressed: () => HyAcademyApp.of(context).toggleTheme(),
                tooltip: 'تبديل المظهر',
              ),
            ),
            Center(
              child: SingleChildScrollView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 36),
                child: MouseRegion(
                  onHover: (event) =>
                      _onPointerHover(event, const Size(460, 740)),
                  onExit: _onPointerExit,
                  child: AnimatedBuilder(
                    animation:
                        Listenable.merge([_fadeAnim, _scaleAnim, _pulseAnim]),
                    builder: (context, child) {
                      return FadeTransition(
                        opacity: _fadeAnim,
                        child: Transform(
                          transform: Matrix4.identity()
                            ..setEntry(3, 2, 0.0012)
                            ..scaleByDouble(_scaleAnim.value, _scaleAnim.value, _scaleAnim.value, 1.0)
                            ..rotateX(_rotateX + _pulseAnim.value)
                            ..rotateY(_rotateY - _pulseAnim.value),
                          alignment: Alignment.center,
                          child: child,
                        ),
                      );
                    },
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 460),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(32),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                          child: Container(
                            padding: const EdgeInsets.all(28),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0xFF14141C).withValues(alpha: 0.94)
                                  : Colors.white.withValues(alpha: 0.94),
                              borderRadius: BorderRadius.circular(32),
                              border: Border.all(
                                color: const Color(0xFFE52521).withValues(alpha: 0.75),
                                width: 2,
                              ),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x38E52521),
                                  blurRadius: 45,
                                  offset: Offset(0, 18),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Center(
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                          color: const Color(0xFFE52521),
                                          width: 2.2),
                                      boxShadow: const [
                                        BoxShadow(
                                          color: Color(0x44E52521),
                                          blurRadius: 24,
                                          spreadRadius: 4,
                                        ),
                                      ],
                                    ),
                                    child: ClipOval(
                                      child: Image.asset(
                                        'assets/icon/icon.jpg',
                                        width: 60,
                                        height: 60,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) =>
                                            const Icon(
                                          Icons.school_rounded,
                                          size: 56,
                                          color: Color(0xFFE52521),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                ShaderMask(
                                  shaderCallback: (bounds) =>
                                      const LinearGradient(
                                    colors: [
                                      Color(0xFFE52521),
                                      Color(0xFFFF7A78)
                                    ],
                                  ).createShader(bounds),
                                  child: const Text(
                                    'hy Academy',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 26,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 1.5,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 350),
                                  transitionBuilder: (child, anim) =>
                                      FadeTransition(
                                    opacity: anim,
                                    child:
                                        ScaleTransition(scale: anim, child: child),
                                  ),
                                  child: Text(
                                    _isSignUp
                                        ? 'أنشئ حسابك وحدد الجامعة والكلية وكلمة سر من 8 خانات على الأقل'
                                        : 'سجل دخولك بالرقم وكلمة السر فقط',
                                    key: ValueKey(_isSignUp),
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: isDark
                                          ? Colors.white70
                                          : Colors.black54,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 20),

                                Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? const Color(0xFF1D1D27)
                                        : const Color(0xFFECECF4),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: GestureDetector(
                                          onTap: () => _toggleAuthMode(false),
                                          child: AnimatedContainer(
                                            duration:
                                                const Duration(milliseconds: 280),
                                            padding: const EdgeInsets.symmetric(
                                                vertical: 11),
                                            decoration: BoxDecoration(
                                              color: !_isSignUp
                                                  ? const Color(0xFFE52521)
                                                  : Colors.transparent,
                                              borderRadius:
                                                  BorderRadius.circular(13),
                                            ),
                                            child: Text(
                                              'تسجيل دخول',
                                              textAlign: TextAlign.center,
                                              style: TextStyle(
                                                color: !_isSignUp
                                                    ? Colors.white
                                                    : (isDark
                                                        ? Colors.white70
                                                        : Colors.black87),
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        child: GestureDetector(
                                          onTap: () => _toggleAuthMode(true),
                                          child: AnimatedContainer(
                                            duration:
                                                const Duration(milliseconds: 280),
                                            padding: const EdgeInsets.symmetric(
                                                vertical: 11),
                                            decoration: BoxDecoration(
                                              color: _isSignUp
                                                  ? const Color(0xFFE52521)
                                                  : Colors.transparent,
                                              borderRadius:
                                                  BorderRadius.circular(13),
                                            ),
                                            child: Text(
                                              'إنشاء حساب',
                                              textAlign: TextAlign.center,
                                              style: TextStyle(
                                                color: _isSignUp
                                                    ? Colors.white
                                                    : (isDark
                                                        ? Colors.white70
                                                        : Colors.black87),
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 18),

                                if (_isSignUp) ...[
                                  _buildInputField(
                                    controller: _nameController,
                                    label: 'الاسم الثلاثي',
                                    icon: Icons.person_rounded,
                                    isDark: isDark,
                                  ),
                                  const SizedBox(height: 14),
                                ],

                                _buildInputField(
                                  controller: _phoneController,
                                  label: 'رقم الهاتف (+963...)',
                                  icon: Icons.phone_iphone_rounded,
                                  keyboardType: TextInputType.phone,
                                  isDark: isDark,
                                ),
                                const SizedBox(height: 14),

                                _buildInputField(
                                  controller: _passwordController,
                                  label: 'كلمة السر (8 خانات على الأقل)',
                                  icon: Icons.lock_rounded,
                                  obscureText: _obscurePassword,
                                  isDark: isDark,
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscurePassword
                                          ? Icons.visibility_off_rounded
                                          : Icons.visibility_rounded,
                                      color: Colors.grey,
                                    ),
                                    onPressed: () => setState(() =>
                                        _obscurePassword = !_obscurePassword),
                                  ),
                                ),
                                const SizedBox(height: 14),

                                if (_isSignUp) ...[
                                  _buildInputField(
                                    controller: _uniController,
                                    label: 'الجامعة (إجباري)',
                                    icon: Icons.account_balance_rounded,
                                    isDark: isDark,
                                  ),
                                  const SizedBox(height: 14),
                                  _buildInputField(
                                    controller: _collegeController,
                                    label: 'الكلية (إجباري)',
                                    icon: Icons.school_outlined,
                                    isDark: isDark,
                                  ),
                                ],
                                const SizedBox(height: 22),

                                SizedBox(
                                  height: 54,
                                  child: ElevatedButton(
                                    onPressed:
                                        _isSubmitting ? null : _handleAuthAction,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFFE52521),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(18),
                                      ),
                                    ),
                                    child: _isSubmitting
                                        ? const SizedBox(
                                            width: 22,
                                            height: 22,
                                            child: CircularProgressIndicator(
                                              color: Colors.white,
                                              strokeWidth: 2.5,
                                            ),
                                          )
                                        : Text(
                                            _isSignUp
                                                ? 'إنشاء الحساب'
                                                : 'تسجيل الدخول',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 17,
                                              fontWeight: FontWeight.w900,
                                            ),
                                          ),
                                  ),
                                ),
                                const SizedBox(height: 14),

                                SizedBox(
                                  height: 48,
                                  child: OutlinedButton.icon(
                                    style: OutlinedButton.styleFrom(
                                      side: const BorderSide(
                                          color: Color(0xFF25D366),
                                          width: 1.5),
                                      foregroundColor: const Color(0xFF25D366),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                    ),
                                    onPressed: _openWhatsAppSupport,
                                    icon: const Icon(Icons.support_agent_rounded,
                                        size: 22),
                                    label: const Text(
                                      'التواصل مع الدعم لحل المشاكل (واتساب)',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscureText = false,
    TextInputType? keyboardType,
    Widget? suffixIcon,
    required bool isDark,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      style: TextStyle(
          color: isDark ? Colors.white : Colors.black87, fontSize: 15),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
            color: isDark ? Colors.white60 : Colors.black54, fontSize: 13),
        prefixIcon: Icon(icon, color: const Color(0xFFE52521)),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: isDark ? const Color(0xFF1E1E28) : const Color(0xFFF0F0F5),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: isDark ? const Color(0xFF2E2E3E) : const Color(0xFFD4D4E0),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFE52521), width: 2),
        ),
      ),
    );
  }
}
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  bool _isSending = false;

  Future<void> _sendResetEmail() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الرجاء إدخال بريد إلكتروني صحيح')),
      );
      return;
    }
    setState(() => _isSending = true);
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم إرسال رابط إعادة تعيين كلمة المرور إلى بريدك الإلكتروني ✅'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context);
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      String arabicMsg = 'فشل الإرسال';
      if (e.code == 'user-not-found') arabicMsg = 'هذا البريد الإلكتروني غير مسجل في النظام';
      if (e.code == 'invalid-email') arabicMsg = 'تنسيق البريد الإلكتروني غير صحيح';
      if (e.code == 'too-many-requests') arabicMsg = 'كثير من الطلبات، حاول مرة أخرى لاحقاً';
      if (e.code == 'network-request-failed') arabicMsg = 'تأكد من اتصالك بالإنترنت';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$arabicMsg (${e.message})')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('فشل الإرسال: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isDark = HyAcademyApp.of(context).isDarkMode;
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F0F12) : const Color(0xFFF9F9FB),
      appBar: AppBar(
        title: const Text('استعادة كلمة المرور'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.email_outlined, size: 80, color: Color(0xFFE52521)),
              const SizedBox(height: 20),
              const Text(
                'نسيت كلمة المرور؟',
                style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              const Text(
                'أدخل بريدك الإلكتروني لإرسال رابط إعادة تعيين كلمة المرور',
                style: TextStyle(color: Colors.white70, fontSize: 14),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 30),
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: 'البريد الإلكتروني',
                  labelStyle: const TextStyle(color: Colors.white70),
                  prefixIcon: const Icon(Icons.email_rounded, color: Color(0xFFE52521)),
                  filled: true,
                  fillColor: isDark ? const Color(0xFF1E1E28) : const Color(0xFFF0F0F5),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(
                        color: isDark ? const Color(0xFF2E2E3E) : const Color(0xFFD4D4E0)),
                  ),
                  focusedBorder: const OutlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFFE52521), width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: 54,
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSending ? null : _sendResetEmail,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE52521),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                    elevation: 8,
                    shadowColor: const Color(0x55E52521),
                  ),
                  child: _isSending
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Text(
                          'إرسال رابط الاستعادة',
                          style: TextStyle(
                              color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900),
                        ),
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('العودة لتسجيل الدخول', style: TextStyle(color: Colors.white70)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class NotificationItem {
  final String id;
  final String title;
  final String message;
  final String time;
  final IconData icon;
  final Color iconColor;
  bool isRead;

  NotificationItem({
    required this.id,
    required this.title,
    required this.message,
    required this.time,
    required this.icon,
    required this.iconColor,
    this.isRead = false,
  });
}

Map<String, List<NotificationItem>> userNotifications = {};
Set<String> globalFavorites = {};
List<Map<String, dynamic>> globalCart = [];

void addAppNotification({
  required String targetUserName,
  required String title,
  required String message,
  required IconData icon,
  required Color iconColor,
}) {
  userNotifications.putIfAbsent(targetUserName, () => []);
  String timeStr = '${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')}';
  userNotifications[targetUserName]!.insert(
    0,
    NotificationItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      message: message,
      time: timeStr,
      icon: icon,
      iconColor: iconColor,
    ),
  );
}

List<String> globalCategories = [
  'الكل',
  'عمارة',
  'أسنان',
  'مدنية',
  'معلوماتية',
  'بشرية',
  'ديكور',
  'العروض'
];

Map<String, IconData> categoryIcons = {
  'الكل': Icons.grid_view_rounded,
  'عمارة': Icons.architecture_rounded,
  'أسنان': Icons.medical_services_rounded,
  'مدنية': Icons.foundation_rounded,
  'معلوماتية': Icons.computer_rounded,
  'بشرية': Icons.health_and_safety_rounded,
  'ديكور': Icons.weekend_rounded,
  'العروض': Icons.local_offer_rounded,
};

List<String> globalUniversities = [
  'جامعة دمشق',
  'جامعة حلب',
  'جامعة تشرين',
  'جامعة الفرات',
  'جامعة حمص',
  'جامعة اليرموك الخاصة',
  'الجامعة العربية الدولية (AIU)',
  'الجامعة الدولية الخاصة للعلوم والتكنولوجيا (IUST)',
  'جامعة الاتحاد الخاصة (IPU)',
  'جامعة الجزيرة الخاصة (JPU)',
  'الجامعة البريطانية في دمشق (BUD)',
  'جامعة قاسيون الخاصة (QPU)',
  'جامعة القلمون الخاصة',
  'الجامعة السورية الخاصة (ASPU)',
  'جامعة الحواش الخاصة (HPU)',
];

Map<String, List<String>> universityColleges = {
  'جامعة دمشق': [
    'هندسة مدنية',
    'هندسة معلوماتية',
    'هندسة ديكور',
    'هندسة عمارة',
    'طب بشري',
    'طب أسنان'
  ],
  'جامعة حلب': ['هندسة ميكانيكية', 'هندسة كهربائية', 'هندسة مدنية', 'طب بشري', 'هندسة عمارة'],
  'جامعة تشرين': ['هندسة تقانة المعلومات', 'هندسة مدنية', 'صيدلة', 'طب أسنان'],
  'جامعة الفرات': ['هندسة مدنية', 'آداب', 'علوم', 'طب بشري'],
  'جامعة حمص': ['هندسة بتروكيمياوية', 'هندسة معمارية', 'علوم أساسية', 'طب بشري'],
  'جامعة اليرموك الخاصة': ['هندسة معلوماتية', 'هندسة اتصالات', 'إدارة أعمال'],
  'الجامعة العربية الدولية (AIU)': ['هندسة معمارية', 'هندسة معلوماتية', 'صيدلة', 'إدارة أعمال'],
  'الجامعة الدولية الخاصة للعلوم والتكنولوجيا (IUST)': [
    'هندسة إلكترونيات',
    'هندسة ميكاترونيكس',
    'طب أسنان',
    'هندسة معلوماتية'
  ],
  'جامعة الاتحاد الخاصة (IPU)': ['هندسة معلوماتية', 'هندسة مدنية', 'إدارة أعمال', 'صيدلة'],
  'جامعة الجزيرة الخاصة (JPU)': ['هندسة مدنية', 'هندسة معمارية', 'إدارة أعمال'],
  'الجامعة البريطانية في دمشق (BUD)': ['إدارة أعمال دولية', 'هندسة برمجيات', 'ذكاء اصطناعي'],
  'جامعة قاسيون الخاصة (QPU)': [
    'هندسة إلكترونيات',
    'هندسة ميكاترونيكس',
    'طب أسنان',
    'هندسة معلوماتية'
  ],
  'جامعة القلمون الخاصة': ['طب بشري', 'هندسة طبية', 'إدارة أعمال', 'صيدلة'],
  'الجامعة السورية الخاصة (ASPU)': ['طب بشري', 'هندسة معلوماتية', 'إدارة أعمال', 'صيدلة'],
  'جامعة الحواش الخاصة (HPU)': ['صيدلة', 'طب أسنان', 'هندسة معلوماتية', 'هندسة مدنية'],
};

class HomeScreen extends StatefulWidget {
  final String userName;
  final String userPhone;
  final String userUid;
  final bool isAdmin;
  final List<String> adminPerms;

  const HomeScreen({
    super.key,
    required this.userName,
    required this.userPhone,
    required this.userUid,
    required this.isAdmin,
    required this.adminPerms,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentNavIndex = 0;
  String selectedCategory = 'الكل';
  final TextEditingController _searchController = TextEditingController();
  String searchQuery = '';

  Widget _buildScrollableNavItem({
    required int index,
    required IconData icon,
    required String label,
    required bool isDark,
  }) {
    final bool isActive = _currentNavIndex == index;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: InkWell(
        onTap: () => setState(() => _currentNavIndex = index),
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: isActive
                ? const Color(0xFFE52521).withValues(alpha: 0.18)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: isActive
                ? Border.all(color: const Color(0xFFE52521), width: 1.5)
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 22,
                color: isActive ? const Color(0xFFE52521) : (isDark ? Colors.white70 : Colors.grey),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                    color: isActive
                        ? const Color(0xFFE52521)
                        : (isDark ? Colors.white70 : Colors.grey.shade700),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _logout(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    try {
      await GoogleSignIn().signOut();
    } catch (_) {}
    await FirebaseAuth.instance.signOut();

    if (!context.mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
    );
  }

  void _openNotificationsSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return FutureBuilder<QuerySnapshot>(
          future: FirebaseFirestore.instance
              .collection('broadcast_notifications')
              .orderBy('timestamp', descending: true)
              .limit(20)
              .get(),
          builder: (context, snapshot) {
            List<QueryDocumentSnapshot> broadcastNotifs =
                snapshot.hasData ? snapshot.data!.docs : [];
            List<NotificationItem> localNotifs = [
              ...(userNotifications[widget.userName] ?? []),
              ...(userNotifications[''] ?? []),
            ];

            return Container(
              height: MediaQuery.of(context).size.height * 0.65,
              decoration: const BoxDecoration(
                color: Color(0xFF14141C),
                borderRadius: BorderRadius.vertical(top: Radius.circular(35)),
              ),
              padding: const EdgeInsets.all(26),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'الإشعارات والتحديثات 🔔',
                    style: TextStyle(
                        color: Color(0xFFE52521), fontSize: 20, fontWeight: FontWeight.w900),
                  ),
                  const Divider(color: Colors.white12, height: 30),
                  Expanded(
                    child: (broadcastNotifs.isEmpty && localNotifs.isEmpty)
                        ? const Center(
                            child: Text('لا توجد إشعارات حالياً',
                                style: TextStyle(color: Colors.white38)))
                        : ListView(
                            children: [
                              ...broadcastNotifs.map((doc) {
                                var data = doc.data() as Map<String, dynamic>;
                                Timestamp? ts = data['timestamp'] as Timestamp?;
                                String timeStr = ts != null
                                    ? '${ts.toDate().hour}:${ts.toDate().minute.toString().padLeft(2, '0')}'
                                    : '';
                                return ListTile(
                                  leading: const Icon(Icons.campaign_rounded,
                                      color: Color(0xFFE52521)),
                                  title: Text(data['title'] ?? '',
                                      style: const TextStyle(
                                          color: Colors.white, fontWeight: FontWeight.bold)),
                                  subtitle: Text(data['message'] ?? '',
                                      style: const TextStyle(color: Colors.white70)),
                                  trailing: Text(timeStr,
                                      style: const TextStyle(color: Colors.grey, fontSize: 11)),
                                );
                              }),
                              ...localNotifs.map((item) {
                                return ListTile(
                                  leading: Icon(item.icon, color: item.iconColor),
                                  title: Text(item.title,
                                      style: const TextStyle(
                                          color: Colors.white, fontWeight: FontWeight.bold)),
                                  subtitle: Text(item.message,
                                      style: const TextStyle(color: Colors.white70)),
                                  trailing: Text(item.time,
                                      style: const TextStyle(color: Colors.grey, fontSize: 11)),
                                );
                              }),
                            ],
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _openCartSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            double totalNum = globalCart.fold(0.0, (sum, item) {
              double price = (item['priceNum'] is num) ? (item['priceNum'] as num).toDouble() : 0.0;
              int qty = (item['qty'] is int) ? item['qty'] as int : 1;
              return sum + (price * qty);
            });
            String currency = globalCart.isNotEmpty ? (globalCart.first['currency'] ?? 'ل.س') : 'ل.س';
            String totalCartPriceStr = '${totalNum.toStringAsFixed(0)} $currency';

            return Container(
              height: MediaQuery.of(context).size.height * 0.7,
              decoration: const BoxDecoration(
                color: Color(0xFF14141C),
                borderRadius: BorderRadius.vertical(top: Radius.circular(35)),
              ),
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'سلة المشتريات 🛒',
                        style: TextStyle(
                            color: Color(0xFFE52521), fontSize: 20, fontWeight: FontWeight.w900),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_sweep, color: Colors.redAccent),
                        onPressed: () {
                          setModalState(() {
                            globalCart.clear();
                          });
                          setState(() {});
                        },
                        tooltip: 'إفراغ السلة',
                      ),
                    ],
                  ),
                  const Divider(color: Colors.white12, height: 20),
                  Expanded(
                    child: globalCart.isEmpty
                        ? const Center(
                            child: Text('سلة المشتريات فارغة حالياً',
                                style: TextStyle(color: Colors.white38)))
                        : ListView.builder(
                            itemCount: globalCart.length,
                            itemBuilder: (context, index) {
                              var cartItem = globalCart[index];
                              return ListTile(
                                leading: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: CachedNetworkImage(
                                    imageUrl: cartItem['image'] ?? '',
                                    width: 50,
                                    height: 50,
                                    fit: BoxFit.cover,
                                    memCacheWidth: 150,
                                    memCacheHeight: 150,
                                  ),
                                ),
                                title: Text(cartItem['title'] ?? '',
                                    style: const TextStyle(
                                        color: Colors.white, fontWeight: FontWeight.bold)),
                                subtitle: Text(
                                    'العدد: ${cartItem['qty']} | السعر: ${cartItem['price']}',
                                    style: const TextStyle(color: Colors.white70, fontSize: 12)),
                                trailing: IconButton(
                                  icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                                  onPressed: () {
                                    setModalState(() {
                                      globalCart.removeAt(index);
                                    });
                                    setState(() {});
                                  },
                                ),
                              );
                            },
                          ),
                  ),
                  const Divider(color: Colors.white12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('الإجمالي: $totalCartPriceStr',
                          style: const TextStyle(
                              color: Color(0xFFE52521),
                              fontSize: 16,
                              fontWeight: FontWeight.w900)),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                        onPressed: globalCart.isEmpty
                            ? null
                            : () async {
                                DocumentSnapshot settingsDoc = await FirebaseFirestore.instance
                                    .collection('settings')
                                    .doc('app_config')
                                    .get();
                                String activeWhatsApp = '963967834966';
                                if (settingsDoc.exists && settingsDoc.data() != null) {
                                  var data = settingsDoc.data() as Map<String, dynamic>;
                                  if (data['whatsapp'] != null &&
                                      data['whatsapp'].toString().isNotEmpty) {
                                    activeWhatsApp = data['whatsapp'];
                                  }
                                }

                                String itemsStr = globalCart
                                    .map((i) =>
                                        '• ${i['title']} (العدد: ${i['qty']} - السعر: ${i['price']})')
                                    .join('\n');
                                String orderMsg =
                                    '📦 طلب سلة مشتريات من hy Academy\n$itemsStr\n• السعر الإجمالي: $totalCartPriceStr\n• اسم الزبون: ${widget.userName}';

                                String waUrl =
                                    'https://wa.me/$activeWhatsApp?text=${Uri.encodeComponent(orderMsg)}';
                                final uri = Uri.parse(waUrl);
                                if (await canLaunchUrl(uri)) {
                                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                                } else {
                                  debugPrint('Could not launch WhatsApp URL: $waUrl');
                                }

                                if (!context.mounted) return;
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                                    content: Text('تم توجيهك إلى واتساب لإتمام طلب السلة بنجاح!')));
                              },
                        icon: const Icon(Icons.chat, color: Colors.white),
                        label: const Text('طلب السلة عبر واتساب',
                            style: TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isDark = HyAcademyApp.of(context).isDarkMode;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        bool? shouldExit = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: const Color(0xFF14141C),
            title: const Text('تأكيد الخروج',
                style: TextStyle(color: Color(0xFFE52521), fontWeight: FontWeight.bold)),
            content: const Text('هل تريد الخروج من التطبيق؟', style: TextStyle(color: Colors.white)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('لا', style: TextStyle(color: Colors.grey)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE52521)),
                onPressed: () => Navigator.pop(context, true),
                child: const Text('نعم', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        );
        if (shouldExit == true) {
          exit(0);
        }
      },
      child: Stack(
        children: [
          Scaffold(
            drawer: Drawer(
          backgroundColor: const Color(0xFF14141C),
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              const DrawerHeader(
                decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [Color(0xFFE52521), Color(0xFF14141C)])),
                child: SizedBox.shrink(),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text('المواد الجامعية المفعلة لدي',
                    style: TextStyle(
                        color: Color(0xFFE52521),
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8)),
              ),
              FutureBuilder<List<String>>(
                future: SharedPreferences.getInstance()
                    .then((p) => p.getStringList('activated_courses_${widget.userUid}') ?? []),
                builder: (context, snap) {
                  List<String> activeIds = snap.data ?? [];
                  if (activeIds.isEmpty) {
                    return const ListTile(
                        title: Text('لا توجد مواد جامعية مفعلة حالياً',
                            style: TextStyle(color: Colors.grey)));
                  }
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: activeIds
                        .map((cid) => FutureBuilder<DocumentSnapshot>(
                              future:
                                  FirebaseFirestore.instance.collection('courses').doc(cid).get(),
                              builder: (context, csnap) {
                                if (!csnap.hasData || !csnap.data!.exists) {
                                  return const SizedBox.shrink();
                                }
                                var c = csnap.data!.data() as Map<String, dynamic>?;
                                if (c == null) return const SizedBox.shrink();
                                c['id'] = csnap.data!.id;
                                return ListTile(
                                  leading: const Icon(Icons.school_rounded,
                                      color: Colors.greenAccent, size: 22),
                                  title: Text(c['title'] ?? 'مقرر',
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600)),
                                  subtitle: Text(c['university'] ?? '',
                                      style: const TextStyle(color: Colors.white70, fontSize: 11)),
                                  trailing: const Icon(Icons.chevron_right,
                                      color: Colors.white54, size: 18),
                                  onTap: () {
                                    Navigator.pop(context);
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            CoursePlayerScreen(course: c, isAdmin: widget.isAdmin, userUid: widget.userUid, adminPerms: widget.adminPerms),
                                      ),
                                    );
                                  },
                                );
                              },
                            ))
                        .toList(),
                  );
                },
              ),
              const Divider(color: Colors.white12, height: 24),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text('الدورات التدريبية المفعلة لدي',
                    style: TextStyle(
                        color: Color(0xFFE52521),
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8)),
              ),
              FutureBuilder<List<String>>(
                future: SharedPreferences.getInstance().then(
                    (p) => p.getStringList('activated_training_courses_${widget.userUid}') ?? []),
                builder: (context, snap) {
                  List<String> activeIds = snap.data ?? [];
                  if (activeIds.isEmpty) {
                    return const ListTile(
                        title: Text('لا توجد دورات تدريبية مفعلة حالياً',
                            style: TextStyle(color: Colors.grey)));
                  }
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: activeIds
                        .map((cid) => FutureBuilder<DocumentSnapshot>(
                              future: FirebaseFirestore.instance
                                  .collection('training_courses')
                                  .doc(cid)
                                  .get(),
                              builder: (context, csnap) {
                                if (!csnap.hasData || !csnap.data!.exists) {
                                  return const SizedBox.shrink();
                                }
                                var c = csnap.data!.data() as Map<String, dynamic>?;
                                if (c == null) return const SizedBox.shrink();
                                c['id'] = csnap.data!.id;
                                return ListTile(
                                  leading: const Icon(Icons.work_rounded,
                                      color: Colors.amberAccent, size: 22),
                                  title: Text(c['title'] ?? 'دورة تدريبية',
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600)),
                                  subtitle: Text(
                                      '${c['category'] ?? ''} - ${c['subCategory'] ?? ''}',
                                      style: const TextStyle(color: Colors.white70, fontSize: 11)),
                                  trailing: const Icon(Icons.chevron_right,
                                      color: Colors.white54, size: 18),
                                  onTap: () {
                                    Navigator.pop(context);
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            CoursePlayerScreen(course: c, isAdmin: widget.isAdmin, userUid: widget.userUid, adminPerms: widget.adminPerms, collection: 'training_courses'),
                                      ),
                                    );
                                  },
                                );
                              },
                            ))
                        .toList(),
                  );
                },
              ),
              const Divider(color: Colors.white12, height: 30),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text('المحملات (PDF)',
                    style: TextStyle(
                        color: Color(0xFFE52521),
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8)),
              ),
              FutureBuilder<List<String>>(
                future: SharedPreferences.getInstance()
                    .then((p) => p.getStringList('downloaded_pdfs') ?? []),
                builder: (context, snapshot) {
                  List<String> list = snapshot.data ?? [];
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (list.isEmpty)
                        const ListTile(
                            title: Text('لا توجد ملفات محملة عبر الرابط',
                                style: TextStyle(color: Colors.grey))),
                      ...list.map((u) => ListTile(
                            leading: const Icon(Icons.picture_as_pdf, color: Colors.redAccent),
                            title: Text(u.split('/').last,
                                style: const TextStyle(color: Colors.white, fontSize: 12)),
                            onTap: () async {
                              Uri uri = Uri.parse(u);
                              if (await canLaunchUrl(uri)) {
                                await launchUrl(uri, mode: LaunchMode.externalApplication);
                              }
                            },
                          )),
                    ],
                  );
                },
              ),
              const Divider(color: Colors.white12, height: 30),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text('الملفات المحملة (أوفلاين)',
                    style: TextStyle(
                        color: Color(0xFFE52521),
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8)),
              ),
              FutureBuilder<List<String>>(
                future: SharedPreferences.getInstance()
                    .then((p) => p.getStringList('local_pdfs') ?? []),
                builder: (context, snapshot) {
                  List<String> localList = snapshot.data ?? [];
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (localList.isEmpty)
                        const ListTile(
                            title: Text('لا توجد ملفات محملة محلياً',
                                style: TextStyle(color: Colors.grey))),
                      ...localList.map((entry) {
                        var parts = entry.split('|');
                        String filePath = parts.length > 1 ? parts[1] : '';
                        String fileName = parts.length > 2 ? parts[2] : 'ملف PDF';
                        return ListTile(
                          leading: const Icon(Icons.picture_as_pdf, color: Colors.greenAccent),
                          title: Text(fileName,
                              style: const TextStyle(color: Colors.white, fontSize: 12),
                              overflow: TextOverflow.ellipsis),
                          subtitle: const Text('ملف محلي - يعمل بدون إنترنت',
                              style: TextStyle(color: Colors.white70, fontSize: 11)),
                          onTap: () async {
                            if (filePath.isNotEmpty) {
                              if (kIsWeb) {
                                // على الويب: فتح الرابط الأصلي للملف
                                final pdfUrl = parts.length > 0 ? parts[0] : '';
                                if (pdfUrl.isNotEmpty && pdfUrl.startsWith('http')) {
                                  final uri = Uri.parse(normalizePdfUrl(pdfUrl));
                                  if (await canLaunchUrl(uri)) {
                                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                                  }
                                }
                              } else {
                                // على الجوال: فتح الملف المحفوظ محلياً
                                final result = await OpenFilex.open(filePath);
                                if (!mounted) return;
                                if (result.type != ResultType.done) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                        content: Text('تعذر فتح الملف: ${result.message}'),
                                        backgroundColor: Colors.redAccent),
                                  );
                                }
                              }
                            }
                          },
                        );
                      }),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
        appBar: AppBar(
          automaticallyImplyLeading: false,
          leading: Builder(
            builder: (ctx) => IconButton(
              icon: const Icon(Icons.menu_rounded, color: Color(0xFFE52521)),
              onPressed: () => Scaffold.of(ctx).openDrawer(),
            ),
          ),
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipOval(
                child: Image.asset(
                  'assets/icon/icon.jpg',
                  width: 32,
                  height: 32,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) =>
                      const Icon(Icons.storefront, color: Color(0xFFE52521)),
                ),
              ),
              const SizedBox(width: 8),
              const Text('hy Academy'),
            ],
          ),
          actions: [
            Stack(
              alignment: Alignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.shopping_cart_rounded, color: Color(0xFFE52521)),
                  onPressed: _openCartSheet,
                  tooltip: 'سلة المشتريات',
                ),
                if (globalCart.isNotEmpty)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration:
                          const BoxDecoration(color: Color(0xFFE52521), shape: BoxShape.circle),
                      child: Text('${globalCart.length}',
                          style: const TextStyle(
                              color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                    ),
                  ),
              ],
            ),
            IconButton(
              icon: Icon(
                  isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                  color: const Color(0xFFE52521)),
              onPressed: () => HyAcademyApp.of(context).toggleTheme(),
            ),
            IconButton(
              icon: const Icon(Icons.notifications_none_rounded, color: Color(0xFFE52521)),
              onPressed: _openNotificationsSheet,
            ),
            if (widget.isAdmin)
              TextButton.icon(
                icon: const Icon(Icons.admin_panel_settings_rounded, color: Color(0xFFE52521)),
                label: const Text('لوحة الأدمن',
                    style: TextStyle(color: Color(0xFFE52521), fontWeight: FontWeight.bold)),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => AdminDashboard(
                        adminName: widget.userName,
                        adminPerms: widget.adminPerms,
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
        body: _currentNavIndex == 0
            ? _buildStoreTab(isDark)
            : _currentNavIndex == 1
                ? CoursesAcademyTab(
                    userName: widget.userName,
                    userPhone: widget.userPhone,
                    userUid: widget.userUid,
                    isAdmin: widget.isAdmin,
                    adminPerms: widget.adminPerms,
                  )
                : _currentNavIndex == 2
                    ? LaborMarketTrainingTab(
                        userName: widget.userName,
                        userPhone: widget.userPhone,
                        userUid: widget.userUid,
                        isAdmin: widget.isAdmin,
                        adminPerms: widget.adminPerms,
                      )
                    : _buildProfileTab(),
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF14141C) : Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 8,
                offset: const Offset(0, -2),
              ),
            ],
            border: Border(
              top: BorderSide(
                color: isDark ? Colors.white12 : Colors.grey.shade300,
                width: 0.5,
              ),
            ),
          ),
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildScrollableNavItem(
                      index: 0,
                      icon: Icons.storefront_rounded,
                      label: 'المتجر',
                      isDark: isDark,
                    ),
                    _buildScrollableNavItem(
                      index: 1,
                      icon: Icons.school_rounded,
                      label: 'الكورسات والمواد الجامعية',
                      isDark: isDark,
                    ),
                    _buildScrollableNavItem(
                      index: 2,
                      icon: Icons.work_rounded,
                      label: 'الدورات التدريبية لسوق العمل',
                      isDark: isDark,
                    ),
                    _buildScrollableNavItem(
                      index: 3,
                      icon: Icons.person_rounded,
                      label: 'حسابي',
                      isDark: isDark,
                    ),
                  ],
                ),
              ),
            ),
          ),
          ),
          ),
        ],
      ),
    );
  }

  Widget _buildStoreTab(bool isDark) {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0.95, end: 1.0),
            duration: const Duration(seconds: 2),
            builder: (context, scale, child) {
              return Transform.scale(
                scale: scale,
                child: Container(
                  width: double.infinity,
                  margin: const EdgeInsets.all(8),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF2E1A22), Color(0xFF14141C), Color(0xFF1F1218)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border:
                        Border.all(color: const Color(0xFFE52521).withValues(alpha: 0.6), width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFE52521).withValues(alpha: 0.25),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Welcome to hy Academy',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.8),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'كل ما يحتاجه الطالب الجامعي تجده هنا',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'أهلاً بك، ${widget.userName}',
                        style: const TextStyle(
                          color: Colors.amberAccent,
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SliverToBoxAdapter(
          child: SizedBox(height: 8),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'ابحث عن منتج أو عرض في المتجر...',
                prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFFE52521), size: 20),
                filled: true,
                fillColor: const Color(0xFF1E1E28),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
              ),
              onChanged: (val) => setState(() => searchQuery = val.trim()),
            ),
          ),
        ),
        const SliverToBoxAdapter(
          child: SizedBox(height: 8),
        ),
        SliverToBoxAdapter(
          child: SizedBox(
            height: 32,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              itemCount: globalCategories.length,
              itemBuilder: (context, index) {
                String cat = globalCategories[index];
                bool isSelected = selectedCategory == cat;
                IconData icon = categoryIcons[cat] ?? Icons.category_rounded;

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: ChoiceChip(
                    avatar: Icon(icon,
                        color: isSelected ? Colors.white : const Color(0xFFE52521), size: 16),
                    label: Text(cat, style: const TextStyle(fontSize: 12)),
                    selected: isSelected,
                    selectedColor: const Color(0xFFE52521),
                    labelStyle: TextStyle(
                        color: isSelected
                            ? Colors.white
                            : (isDark ? Colors.white70 : Colors.black87),
                        fontWeight: FontWeight.bold),
                    onSelected: (_) => setState(() => selectedCategory = cat),
                  ),
                );
              },
            ),
          ),
        ),
        const SliverToBoxAdapter(
          child: SizedBox(height: 8),
        ),
        SliverToBoxAdapter(
          child: StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance.collection('ads').doc('main_banner').snapshots(),
            builder: (context, adSnapshot) {
              if (!adSnapshot.hasData || !adSnapshot.data!.exists) {
                return const SizedBox.shrink();
              }
              var adData = adSnapshot.data!.data() as Map<String, dynamic>?;
              if (adData == null || (adData['isActive'] ?? false) != true) {
                return const SizedBox.shrink();
              }
              String adUrl = adData['url'] ?? '';
              if (adUrl.isEmpty) return const SizedBox.shrink();
              return SizedBox(
                height: 180,
                child: InlineVideoAdCard(adData: adData, autoPlay: bannerAutoPlay),
              );
            },
          ),
        ),
        const SliverToBoxAdapter(
          child: SizedBox(height: 10),
        ),
        _PaginatedStoreGrid(
          selectedCategory: selectedCategory,
          searchQuery: searchQuery,
          isDark: isDark,
          userName: widget.userName,
          userPhone: widget.userPhone,
          userUid: widget.userUid,
          isAdmin: widget.isAdmin,
        ),
      ],
    );
  }

  Widget _buildProfileTab() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFFE52521)),
            child: ClipOval(
              child: Image.asset(
                'assets/icon/icon.jpg',
                width: 80,
                height: 80,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    const Icon(Icons.person, size: 80, color: Colors.white),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(widget.userName,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          Text(widget.userPhone, style: const TextStyle(color: Colors.grey)),
          const SizedBox(height: 12),
          Chip(
              label: Text(
                  'UID: ${widget.userUid.substring(0, min(15, widget.userUid.length))}...',
                  style: const TextStyle(
                      color: Color(0xFFE52521), fontWeight: FontWeight.bold))),
          const SizedBox(height: 30),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.red)),
            icon: const Icon(Icons.logout, color: Colors.red),
            label: const Text('تسجيل خروج', style: TextStyle(color: Colors.red)),
            onPressed: () => _logout(context),
          ),
        ],
      ),
    );
  }
}

class InlineVideoAdCard extends StatefulWidget {
  final Map<String, dynamic> adData;
  final bool autoPlay;
  const InlineVideoAdCard({super.key, required this.adData, this.autoPlay = true});

  @override
  State<InlineVideoAdCard> createState() => _InlineVideoAdCardState();
}

class _InlineVideoAdCardState extends State<InlineVideoAdCard> {
  VideoPlayerController? _videoController;
  bool _isInitialized = false;
  bool _isPausedByUser = false;
  bool _closed = false;
  bool _completionHandled = false;

  @override
  void initState() {
    super.initState();
    String url = widget.adData['url'] ?? '';
    bool isVideo = widget.adData['isVideo'] ?? false;
    if (isVideo && url.isNotEmpty && widget.autoPlay) {
      _videoController = VideoPlayerController.networkUrl(Uri.parse(url))
        ..initialize().then((_) {
          if (!mounted) return;
          setState(() {
            _isInitialized = true;
          });
          // تشغيل مرة واحدة فقط ثم إطفاء تلقائي
          _videoController!.setLooping(false);
          _videoController!.addListener(_handlePlayback);
          _videoController!.play();
        });
    }
  }

  void _handlePlayback() {
    final v = _videoController?.value;
    if (v == null || _completionHandled || _closed) return;
    if (v.duration > Duration.zero && v.position >= v.duration) {
      _completionHandled = true;
      _closeAd();
    }
  }

  void _closeAd() {
    if (_closed) return;
    _videoController?.pause();
    // لا يُعاد تشغيل الإعلان تلقائياً مرة أخرى في نفس الجلسة
    bannerAutoPlay = false;
    if (mounted) setState(() => _closed = true);
  }

  @override
  void didUpdateWidget(covariant InlineVideoAdCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.adData != widget.adData) {
      _closed = false;
      _completionHandled = false;
    }
    if (oldWidget.autoPlay != widget.autoPlay && _videoController != null) {
      if (!widget.autoPlay) {
        _videoController!.pause();
        _isPausedByUser = true;
      } else if (_isPausedByUser) {
        _videoController!.play();
        _isPausedByUser = false;
      }
    }
  }

  @override
  void dispose() {
    _videoController?.removeListener(_handlePlayback);
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    String url = widget.adData['url'] ?? '';
    bool isVideo = widget.adData['isVideo'] ?? false;
    bool isInstagram = url.contains('instagram.com');

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF181820),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE52521), width: 1.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (isVideo && _isInitialized && _videoController != null)
                  GestureDetector(
                    onTap: _closeAd,
                    child: FittedBox(
                      fit: BoxFit.cover,
                      child: SizedBox(
                        width: _videoController!.value.size.width,
                        height: _videoController!.value.size.height,
                        child: VideoPlayer(_videoController!),
                      ),
                    ),
                  )
                else if (isInstagram)
                  GestureDetector(
                    onTap: _closeAd,
                    child: Container(
                      color: Colors.purple.shade900,
                      child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.video_library_rounded, color: Colors.white, size: 36),
                          SizedBox(height: 4),
                          Text('إعلان إنستغرام',
                              style: TextStyle(
                                  color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
                        ],
                      ),
                    ),
                  )
                else
                  GestureDetector(
                    onTap: _closeAd,
                    child: CachedNetworkImage(
                      imageUrl: url,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                      errorWidget: (context, url, error) => Container(
                        color: Colors.black87,
                        child: const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.broken_image, color: Color(0xFFE52521), size: 45),
                            SizedBox(height: 4),
                            Text('صورة إعلانية',
                                style: TextStyle(
                                    color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
                          ],
                        ),
                      ),
                    ),
                  ),
                Positioned(
                  top: 6,
                  left: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE52521),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'إعلان مميز 📢',
                      style: TextStyle(
                          color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('إعلان برعاية المتجر',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.white)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 32,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isInstagram ? Colors.purple : const Color(0xFFE52521),
                            padding: EdgeInsets.zero,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: () async {
                            final uri = Uri.parse(url);
                            if (await canLaunchUrl(uri)) {
                              await launchUrl(uri, mode: LaunchMode.externalApplication);
                            }
                          },
                          child: Text(isInstagram ? 'زيارة انستغرام' : 'مشاهدة الإعلان',
                              style: const TextStyle(fontSize: 11, color: Colors.white)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      height: 32,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          side: const BorderSide(color: Colors.white38),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        icon: const Icon(Icons.stop_rounded, size: 16, color: Colors.white),
                        label: const Text('إيقاف',
                            style: TextStyle(fontSize: 11, color: Colors.white)),
                        onPressed: _closeAd,
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

class ProductDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> product;
  final String userName;
  final String userPhone;
  final String userUid;
  final bool isAdmin;

  const ProductDetailsScreen({
    super.key,
    required this.product,
    required this.userName,
    required this.userPhone,
    required this.userUid,
    required this.isAdmin,
  });

  @override
  State<ProductDetailsScreen> createState() => _ProductDetailsScreenState();
}

class _ProductDetailsScreenState extends State<ProductDetailsScreen> {
  int quantity = 1;
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _recipientPhoneController = TextEditingController();

  void _orderViaWhatsApp() async {
    String recipientPhone = _recipientPhoneController.text.trim();
    String location = _locationController.text.trim();

    if (recipientPhone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الرجاء إدخال رقم هاتف المستلم لإتمام الطلب')),
      );
      return;
    }
    if (location.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الرجاء إدخال مكان التوصيل أو الجامعة بالتفصيل')),
      );
      return;
    }

    int priceNum = widget.product['priceNum'] ?? 0;
    int totalPrice = priceNum * quantity;
    String currency = widget.product['currency'] ?? 'ل.س';

    DocumentSnapshot settingsDoc =
        await FirebaseFirestore.instance.collection('settings').doc('app_config').get();
    String activeWhatsApp = '963967834966';
    if (settingsDoc.exists && settingsDoc.data() != null) {
      var data = settingsDoc.data() as Map<String, dynamic>;
      if (data['whatsapp'] != null && data['whatsapp'].toString().isNotEmpty) {
        activeWhatsApp = data['whatsapp'];
      }
    }

    String orderMsg =
        '📦 طلب منتج من hy Academy\n• المنتج: ${widget.product['title']}\n• العدد: $quantity قطع\n• السعر الإجمالي: $totalPrice $currency\n• اسم الزبون: ${widget.userName}\n• هاتف المستلم: $recipientPhone\n• مكان التوصيل/الجامعة: $location';

    String waUrl = 'https://wa.me/$activeWhatsApp?text=${Uri.encodeComponent(orderMsg)}';
    final uri = Uri.parse(waUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      debugPrint('Could not launch WhatsApp URL: $waUrl');
    }

    addAppNotification(
      targetUserName: widget.userName,
      title: 'تم إرسال طلب المتجر بنجاح 🛒',
      message: 'تم إرسال طلب (${widget.product['title']}) عبر واتساب للإدارة.',
      icon: Icons.shopping_bag_rounded,
      iconColor: const Color(0xFFE52521),
    );

    if (!mounted) return;
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم توجيهك إلى واتساب لإتمام الطلب بنجاح!')),
    );
  }

  void _editProduct() async {
    final titleCtrl = TextEditingController(text: widget.product['title'] ?? '');
    final priceCtrl = TextEditingController(text: (widget.product['priceNum'] ?? 0).toString());
    final descCtrl = TextEditingController(text: widget.product['description'] ?? '');
    final categoryCtrl = TextEditingController(text: widget.product['category'] ?? '');
    String colName = widget.product['isBundle'] == true ? 'bundles' : 'products';
    String imageUrl = widget.product['image'] ?? '';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E28),
        title: const Text('تعديل المنتج', style: TextStyle(color: Colors.white)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(
                      labelText: 'اسم المنتج',
                      labelStyle: TextStyle(color: Colors.white70),
                      enabledBorder:
                          UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFFE52521))),
                      focusedBorder:
                          UnderlineInputBorder(borderSide: BorderSide(color: Colors.redAccent)))),
              const SizedBox(height: 10),
              TextField(
                  controller: priceCtrl,
                  decoration: const InputDecoration(
                      labelText: 'السعر',
                      labelStyle: TextStyle(color: Colors.white70),
                      enabledBorder:
                          UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFFE52521))),
                      focusedBorder:
                          UnderlineInputBorder(borderSide: BorderSide(color: Colors.redAccent))),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true)),
              const SizedBox(height: 10),
              TextField(
                  controller: categoryCtrl,
                  decoration: const InputDecoration(
                      labelText: 'القسم',
                      labelStyle: TextStyle(color: Colors.white70),
                      enabledBorder:
                          UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFFE52521))),
                      focusedBorder:
                          UnderlineInputBorder(borderSide: BorderSide(color: Colors.redAccent)))),
              const SizedBox(height: 10),
              TextField(
                  controller: descCtrl,
                  decoration: const InputDecoration(
                      labelText: 'الوصف',
                      labelStyle: TextStyle(color: Colors.white70),
                      enabledBorder:
                          UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFFE52521))),
                      focusedBorder:
                          UnderlineInputBorder(borderSide: BorderSide(color: Colors.redAccent))),
                  maxLines: 2),
              const SizedBox(height: 10),
              Text(imageUrl.isNotEmpty ? 'الصورة الحالية: $imageUrl' : 'لا توجد صورة',
                  style: const TextStyle(color: Colors.white70, fontSize: 12)),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE52521)),
            onPressed: () async {
              int priceNum = int.tryParse(priceCtrl.text.trim()) ?? 0;
              String currency = widget.product['currency'] ?? 'ل.س';
              String priceStr = '$priceNum $currency';
              await FirebaseFirestore.instance
                  .collection(colName)
                  .doc(widget.product['id'])
                  .update({
                'title': titleCtrl.text.trim(),
                'price': priceStr,
                'priceNum': priceNum,
                'category': categoryCtrl.text.trim(),
                'description': descCtrl.text.trim(),
              });
              if (!mounted) return;
              Navigator.pop(ctx);
              Navigator.pop(context);
              ScaffoldMessenger.of(context)
                  .showSnackBar(const SnackBar(content: Text('تم تحديث المنتج بنجاح ✅')));
            },
            child: const Text('حفظ', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _deleteProduct() async {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E28),
        title: const Text('حذف المنتج'),
        content: const Text('هل أنت متأكد من حذف هذا المنتج نهائياً؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('تراجع')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              String colName = widget.product['isBundle'] == true ? 'bundles' : 'products';
              await FirebaseFirestore.instance
                  .collection(colName)
                  .doc(widget.product['id'])
                  .delete();
              if (!mounted) return;
              Navigator.pop(ctx);
              Navigator.pop(context);
              ScaffoldMessenger.of(context)
                  .showSnackBar(const SnackBar(content: Text('تم حذف المنتج/العرض بنجاح')));
            },
            child: const Text('حذف نهائي'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isFav = globalFavorites.contains(widget.product['id']);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.product['title'] ?? 'تفاصيل المنتج'),
        actions: [
          if (widget.isAdmin)
            IconButton(
              icon: const Icon(Icons.edit_rounded, color: Color(0xFFE52521)),
              onPressed: _editProduct,
              tooltip: 'تعديل المنتج',
            ),
          if (widget.isAdmin)
            IconButton(
              icon: const Icon(Icons.delete_forever_rounded, color: Colors.redAccent),
              onPressed: _deleteProduct,
              tooltip: 'حذف المنتج',
            ),
          IconButton(
            icon: Icon(isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                color: Colors.redAccent),
            onPressed: () {
              setState(() {
                if (isFav) {
                  globalFavorites.remove(widget.product['id']);
                } else {
                  globalFavorites.add(widget.product['id']);
                }
              });
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(25),
                child: CachedNetworkImage(
                  imageUrl: widget.product['image'] ?? '',
                  height: 250,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  memCacheWidth: 600,
                  memCacheHeight: 600,
                  errorWidget: (context, url, error) => Container(
                    height: 250,
                    color: Colors.grey.shade900,
                    child: const Center(
                        child: Icon(Icons.broken_image, size: 50, color: Colors.grey)),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    widget.product['title'] ?? '',
                    style: const TextStyle(
                        fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white),
                  ),
                ),
                Text(
                  widget.product['price'] ?? '',
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFFE52521)),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Chip(
              label: Text('القسم: ${widget.product['category'] ?? 'عام'}',
                  style: const TextStyle(color: Color(0xFFE52521), fontWeight: FontWeight.bold)),
              backgroundColor: const Color(0xFFE52521).withValues(alpha: 0.15),
            ),
            const SizedBox(height: 16),
            const Text('تفاصيل المنتج:',
                style:
                    TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white70)),
            const SizedBox(height: 6),
            Text(
              (widget.product['description'] ?? '').toString().isNotEmpty
                  ? widget.product['description']
                  : 'لا توجد تفاصيل إضافية متاحة لهذا المنتج حالياً.',
              style: const TextStyle(fontSize: 14, color: Colors.white60, height: 1.5),
            ),
            const Divider(color: Colors.white24, height: 35),
            const Text('تحديد عدد القطع:',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              children: [
                IconButton(
                  onPressed: () {
                    if (quantity > 1) setState(() => quantity--);
                  },
                  icon: const Icon(Icons.remove_circle, color: Color(0xFFE52521), size: 32),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  decoration: BoxDecoration(
                      color: const Color(0xFF1E1E28), borderRadius: BorderRadius.circular(12)),
                  child: Text('$quantity',
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                ),
                IconButton(
                  onPressed: () => setState(() => quantity++),
                  icon: const Icon(Icons.add_circle, color: Color(0xFFE52521), size: 32),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _recipientPhoneController,
              decoration: const InputDecoration(
                labelText: 'رقم هاتف المستلم (إجباري)',
                prefixIcon: Icon(Icons.phone_rounded, color: Color(0xFFE52521)),
                filled: true,
              ),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _locationController,
              decoration: const InputDecoration(
                labelText: 'مكان التوصيل أو الجامعة بالتفصيل',
                prefixIcon: Icon(Icons.location_on, color: Color(0xFFE52521)),
                filled: true,
              ),
            ),
            const SizedBox(height: 25),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 54,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                      onPressed: _orderViaWhatsApp,
                      icon: const Icon(Icons.chat, color: Colors.white),
                      label: const Text('طلب عبر واتساب 🛒',
                          style: TextStyle(
                              color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  height: 54,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E1E28)),
                    onPressed: () {
                      globalCart.add({
                        'title': widget.product['title'],
                        'price': widget.product['price'],
                        'priceNum': widget.product['priceNum'] ?? 0,
                        'currency': widget.product['currency'] ?? 'ل.س',
                        'image': widget.product['image'],
                        'qty': quantity,
                      });
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text('تمت إضافة المنتج إلى سلة المشتريات بنجاح 🛒')));
                    },
                    icon: const Icon(Icons.add_shopping_cart, color: Color(0xFFE52521)),
                    label: const Text('إضافة للسلة', style: TextStyle(color: Colors.white)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// قسم الكورسات والمواد الجامعية
class CoursesAcademyTab extends StatefulWidget {
  final String userName;
  final String userPhone;
  final String userUid;
  final bool isAdmin;
  final List<String> adminPerms;
  const CoursesAcademyTab({
    super.key,
    required this.userName,
    required this.userPhone,
    required this.userUid,
    required this.isAdmin,
    required this.adminPerms,
  });

  @override
  State<CoursesAcademyTab> createState() => _CoursesAcademyTabState();
}

class _CoursesAcademyTabState extends State<CoursesAcademyTab> {
  String? selectedUni;
  String? selectedCollege;

  void _deleteCourse(String courseId, String courseTitle) async {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E28),
        title: const Text('حذف المقرر'),
        content: Text('هل أنت متأكد من حذف مقرر ($courseTitle) نهائياً؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('تراجع')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              await FirebaseFirestore.instance.collection('courses').doc(courseId).delete();
              if (!mounted) return;
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context)
                  .showSnackBar(const SnackBar(content: Text('تم حذف المقرر بنجاح')));
            },
            child: const Text('حذف نهائي'),
          ),
        ],
      ),
    );
  }

  void _showActivationDialog(Map<String, dynamic> course) {
    final codeController = TextEditingController();
    String coursePriceStr = course['price'] ?? '${course['priceNum'] ?? 25000} ل.س';
    String courseTitle = course['title'] ?? 'المقرر';

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF14141C),
          title: Text('تفعيل مادة: $courseTitle',
              style: const TextStyle(color: Color(0xFFE52521), fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('السعر المطلوب: $coursePriceStr',
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 12),
                const Text('لشراء كود التفعيل الفوري، تواصل مع الإدارة عبر واتساب:',
                    style: TextStyle(color: Colors.white70, fontSize: 12)),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                    icon: const Icon(Icons.chat, color: Colors.white),
                    label: const Text('شراء كود عبر الواتساب',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    onPressed: () async {
                      const activeWhatsApp = '963967834966';
                      final university = (course['university'] ?? 'غير محددة').toString();
                      final college = (course['college'] ?? 'غير محددة').toString();
                      final message =
                          'أرغب بشراء الكورس/المادة: $courseTitle\nالجامعة: $university\nالكلية: $college\nالسعر: $coursePriceStr\nأرجو تزويدي بكود التحقق والتفعيل.';
                      final uri = Uri.parse(
                        'https://wa.me/$activeWhatsApp?text=${Uri.encodeComponent(message)}',
                      );
                      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
                      if (!opened && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('تعذر فتح واتساب. تأكد من تثبيته أو افتح الرقم +963967834966 يدوياً.')),
                        );
                      }
                    },
                  ),
                ),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () async {
                    await Clipboard.setData(const ClipboardData(text: '+963967834966'));
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('تم نسخ رقم الواتساب بنجاح')));
                  },
                  child: RichText(
                    text: const TextSpan(
                      style: TextStyle(
                          color: Color(0xFFE52521),
                          fontSize: 13,
                          decoration: TextDecoration.underline),
                      children: [
                        TextSpan(
                            text: 'لحل المشاكل في الشراء او طلب الكود يدويا تواصل مع الادارة عبر واتس اب '),
                        TextSpan(
                            text: '+963967834966', style: TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
                const Divider(color: Colors.white24, height: 25),
                const Text('أدخل كود التفعيل الذي استلمته من الإدارة:',
                    style: TextStyle(color: Colors.white70, fontSize: 12)),
                const SizedBox(height: 6),
                TextField(
                  controller: codeController,
                  decoration: const InputDecoration(hintText: 'أدخل كود التفعيل...', filled: true),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
            ElevatedButton(
              onPressed: () async {
                String enteredCode = codeController.text.trim();
                if (enteredCode.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('الرجاء إدخال كود التفعيل')));
                  return;
                }

                // 1. البحث أولاً في المجموعة المستقلة course_codes
                DocumentSnapshot? codeDoc;
                bool foundInExternal = false;

                try {
                  final doc = await FirebaseFirestore.instance
                      .collection('course_codes')
                      .doc(enteredCode)
                      .get();
                  if (doc.exists) {
                    final cData = doc.data() ?? <String, dynamic>{};
                    if ((cData['code'] ?? doc.id).toString().trim() == enteredCode &&
                        (cData['courseId'] ?? '').toString() == course['id'].toString()) {
                      codeDoc = doc;
                      if (cData['isUsed'] != true && cData['isDisabled'] != true) {
                        foundInExternal = true;
                      }
                    }
                  }
                } catch (e) {
                  debugPrint('Error querying course_codes: $e');
                }

                // 2. الاحتياط: البحث في مصفوفة codes المدمجة
                var rawCodes = course['codes'] as List? ?? [];
                var codesList = rawCodes.map((c) => Map<String, dynamic>.from(c as Map)).toList();
                int matchedIndex = -1;

                if (!foundInExternal) {
                  for (int i = 0; i < codesList.length; i++) {
                    String dbCode = (codesList[i]['code'] ?? '').toString().trim();
                    bool isUsed = codesList[i]['isUsed'] == true;
                    bool isDisabled = codesList[i]['isDisabled'] == true;
                    if (dbCode == enteredCode && !isUsed && !isDisabled) {
                      matchedIndex = i;
                      break;
                    }
                  }
                }

                bool isValid = foundInExternal || matchedIndex != -1;

                if (isValid) {
                  try {
                    final firestore = FirebaseFirestore.instance;
                    final courseRef = firestore.collection('courses').doc(course['id'].toString());
                    final saleRef = firestore.collection('sales_log').doc();
                    final externalCodeRef = foundInExternal ? codeDoc?.reference : null;
                    if (foundInExternal && externalCodeRef == null) {
                      throw StateError('تعذر تحديد مستند كود التفعيل الخارجي.');
                    }
                    await firestore.runTransaction((transaction) async {
                      final courseSnapshot = await transaction.get(courseRef);
                      if (!courseSnapshot.exists) throw StateError('الكورس غير موجود.');
                      final freshCourse = Map<String, dynamic>.from(courseSnapshot.data()!);
                      var durationDays = 120;
                      final courseUpdates = <String, dynamic>{};
                      if (externalCodeRef != null) {
                        final codeSnapshot = await transaction.get(externalCodeRef);
                        if (!codeSnapshot.exists) throw StateError('كود التفعيل غير موجود.');
                        final codeData = codeSnapshot.data() as Map<String, dynamic>;
                        if ((codeData['code'] ?? '').toString().trim() != enteredCode ||
                            (codeData['courseId'] ?? '').toString() != course['id'].toString() ||
                            codeData['isUsed'] == true || codeData['isDisabled'] == true) {
                          throw StateError('الكود مستخدم أو معطل أو غير صالح لهذا الكورس.');
                        }
                        final rawDuration = codeData['durationDays'];
                        durationDays = rawDuration is num ? rawDuration.toInt() : 120;
                        transaction.update(externalCodeRef, {
                          'isUsed': true, 'usedBy': widget.userName,
                          'userUid': widget.userUid, 'usedAt': FieldValue.serverTimestamp(),
                        });
                      } else {
                        final rawCodes = freshCourse['codes'] as List? ?? [];
                        final codes = rawCodes.map((item) => Map<String, dynamic>.from(item as Map)).toList();
                        final codeIndex = codes.indexWhere((item) =>
                            (item['code'] ?? '').toString().trim() == enteredCode &&
                            item['isUsed'] != true && item['isDisabled'] != true);
                        if (codeIndex < 0) throw StateError('الكود مستخدم أو معطل أو غير صالح.');
                        final rawDuration = codes[codeIndex]['durationDays'];
                        durationDays = rawDuration is num ? rawDuration.toInt() : 120;
                        codes[codeIndex]['isUsed'] = true;
                        codes[codeIndex]['usedBy'] = widget.userName;
                        codes[codeIndex]['userUid'] = widget.userUid;
                        codes[codeIndex]['usedAt'] = DateTime.now().toIso8601String();
                        courseUpdates['codes'] = codes;
                      }
                      courseUpdates['unlockedUsers.${widget.userUid}'] = {
                          'name': widget.userName,
                          'activatedAt': FieldValue.serverTimestamp(),
                          'durationDays': durationDays,
                          'code': enteredCode,
                        };
                      transaction.update(courseRef, courseUpdates);
                      transaction.set(saleRef, {
                        'courseTitle': courseTitle, 'university': (freshCourse['university'] ?? 'عام'), 'college': (freshCourse['college'] ?? 'عام'),
                        'price': coursePriceStr, 'userName': widget.userName,
                        'userUid': widget.userUid, 'codeUsed': enteredCode,
                        'purchasedAt': FieldValue.serverTimestamp(),
                      });
                    });
                    try {
                      final prefs = await SharedPreferences.getInstance();
                      final key = 'activated_courses_${widget.userUid}';
                      final active = prefs.getStringList(key) ?? <String>[];
                      if (!active.contains(course['id'].toString())) {
                        active.add(course['id'].toString());
                        await prefs.setStringList(key, active);
                      }
                    } catch (e) { debugPrint('Activation cache error: $e'); }
                    if (!context.mounted) return;
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('تم تفعيل المقرر بنجاح! 🎉')),
                    );
                    if (mounted) setState(() {});
                  } catch (e, st) {
                    debugPrint('Activation transaction failed: $e\n$st');
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('تعذر تفعيل الاشتراك: $e')),
                    );
                  }
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('كود التفعيل غير صحيح أو مستخدم مسبقاً أو معطل'),
                  ));
                }
              },
              child: const Text('تفعيل المقرر'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (selectedUni == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text('اختر الجامعة السورية:',
                style: TextStyle(
                    color: Color(0xFFE52521), fontSize: 20, fontWeight: FontWeight.w900)),
          ),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.8,
              ),
              itemCount: globalUniversities.length,
              itemBuilder: (context, index) {
                String uni = globalUniversities[index];

                return GestureDetector(
                  onTap: () => setState(() => selectedUni = uni),
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF14141C),
                      borderRadius: BorderRadius.circular(20),
                      border:
                          Border.all(color: const Color(0xFFE52521).withValues(alpha: 0.6), width: 1.5),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius:
                                const BorderRadius.vertical(top: Radius.circular(18)),
                            child: Image.asset(
                              'assets/images/university.jpg',
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  Image.asset('assets/icon/icon.jpg', fit: BoxFit.cover),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Text(
                            uni,
                            style: const TextStyle(
                                color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      );
    }

    if (selectedCollege == null) {
      List<String> colleges = universityColleges[selectedUni] ?? <String>[];
      if (colleges.isEmpty) {
        return Column(children: [
          ListTile(
            leading: const Icon(Icons.arrow_back_rounded, color: Color(0xFFE52521)),
            title: Text('كليات $selectedUni'),
            onTap: () => setState(() => selectedUni = null),
          ),
          const Expanded(child: Center(child: Text(
            'لا توجد كليات مسجلة لهذه الجامعة حالياً. يمكن للأدمن إضافتها من إدارة الجامعات.',
            textAlign: TextAlign.center, style: TextStyle(color: Colors.grey),
          ))),
        ]);
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFFE52521)),
                  onPressed: () => setState(() => selectedUni = null),
                ),
                Expanded(
                  child: Text('كليات $selectedUni:',
                      style: const TextStyle(
                          color: Color(0xFFE52521), fontSize: 18, fontWeight: FontWeight.w900)),
                ),
              ],
            ),
          ),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.8,
              ),
              itemCount: colleges.length,
              itemBuilder: (context, index) {
                String college = colleges[index];

                return GestureDetector(
                  onTap: () => setState(() => selectedCollege = college),
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF14141C),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFE52521), width: 1.5),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius:
                                const BorderRadius.vertical(top: Radius.circular(18)),
                            child: Image.asset(
                              'assets/images/university.jpg',
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  Image.asset('assets/icon/icon.jpg', fit: BoxFit.cover),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Text(
                            college,
                            style: const TextStyle(
                                color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFFE52521)),
                onPressed: () => setState(() => selectedCollege = null),
              ),
              Expanded(
                child: Text('مقررات $selectedCollege ($selectedUni):',
                    style: const TextStyle(
                        color: Color(0xFFE52521), fontSize: 16, fontWeight: FontWeight.w900)),
              ),
            ],
          ),
        ),
        Expanded(
          child: _PaginatedCoursesGrid(
            selectedUni: selectedUni!,
            selectedCollege: selectedCollege,
            userName: widget.userName,
            userUid: widget.userUid,
            isAdmin: widget.isAdmin,
            adminPerms: widget.adminPerms,
            onActivationTap: _showActivationDialog,
          ),
        ),
      ],
    );
  }
}

/// قسم الدورات التدريبية لسوق العمل (يعمل بنفس نظام قسم الكورسات والمواد الجامعية تماماً)
class LaborMarketTrainingTab extends StatefulWidget {
  final String userName;
  final String userPhone;
  final String userUid;
  final bool isAdmin;
  final List<String> adminPerms;

  const LaborMarketTrainingTab({
    super.key,
    required this.userName,
    required this.userPhone,
    required this.userUid,
    required this.isAdmin,
    required this.adminPerms,
  });

  @override
  State<LaborMarketTrainingTab> createState() => _LaborMarketTrainingTabState();
}

class _LaborMarketTrainingTabState extends State<LaborMarketTrainingTab> {
  String? selectedCategory;
  String? selectedSubCategory;

  void _deleteTrainingCourse(String courseId, String courseTitle) async {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E28),
        title: const Text('حذف الدورة التدريبية'),
        content: Text('هل أنت متأكد من حذف دورة ($courseTitle) نهائياً؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('تراجع')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              await FirebaseFirestore.instance
                  .collection('training_courses')
                  .doc(courseId)
                  .delete();
              if (!mounted) return;
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context)
                  .showSnackBar(const SnackBar(content: Text('تم حذف الدورة التدريبية بنجاح')));
            },
            child: const Text('حذف نهائي'),
          ),
        ],
      ),
    );
  }

  void _showTrainingActivationDialog(Map<String, dynamic> course) {
    final codeController = TextEditingController();
    String coursePriceStr = course['price'] ?? '${course['priceNum'] ?? 25000} ل.س';
    String courseTitle = course['title'] ?? 'الدورة التدريبية';

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF14141C),
          title: Text('تفعيل دورة: $courseTitle',
              style: const TextStyle(color: Color(0xFFE52521), fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('السعر المطلوب: $coursePriceStr',
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 12),
                const Text('لشراء كود التفعيل الفوري، تواصل مع الإدارة عبر واتساب:',
                    style: TextStyle(color: Colors.white70, fontSize: 12)),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                    icon: const Icon(Icons.chat, color: Colors.white),
                    label: const Text('شراء كود عبر الواتساب',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    onPressed: () async {
                      const activeWhatsApp = '963967834966';
                      final category = (course['category'] ?? 'دورات تدريبية').toString();
                      final subCategory = (course['subCategory'] ?? 'عام').toString();
                      final message =
                          'أرغب بشراء الدورة: $courseTitle\nالتصنيف: $category\nالتخصص: $subCategory\nالسعر: $coursePriceStr\nأرجو تزويدي بكود التحقق والتفعيل.';
                      final uri = Uri.parse(
                        'https://wa.me/$activeWhatsApp?text=${Uri.encodeComponent(message)}',
                      );
                      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
                      if (!opened && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('تعذر فتح واتساب. تأكد من تثبيته أو افتح الرقم +963967834966 يدوياً.')),
                        );
                      }
                    },
                  ),
                ),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () async {
                    await Clipboard.setData(const ClipboardData(text: '+963967834966'));
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('تم نسخ رقم الواتساب بنجاح')));
                  },
                  child: RichText(
                    text: const TextSpan(
                      style: TextStyle(
                          color: Color(0xFFE52521),
                          fontSize: 13,
                          decoration: TextDecoration.underline),
                      children: [
                        TextSpan(
                            text:
                                'لحل المشاكل في الشراء او طلب الكود يدويا تواصل مع الادارة عبر واتس اب '),
                        TextSpan(
                            text: '+963967834966', style: TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
                const Divider(color: Colors.white24, height: 25),
                const Text('أدخل كود التفعيل الذي استلمته من الإدارة:',
                    style: TextStyle(color: Colors.white70, fontSize: 12)),
                const SizedBox(height: 6),
                TextField(
                  controller: codeController,
                  decoration: const InputDecoration(hintText: 'أدخل كود التفعيل...', filled: true),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
            ElevatedButton(
              onPressed: () async {
                String enteredCode = codeController.text.trim();
                if (enteredCode.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('الرجاء إدخال كود التفعيل')));
                  return;
                }

                // 1. البحث أولاً في المجموعة المستقلة training_codes
                DocumentSnapshot? codeDoc;
                bool foundInExternal = false;

                try {
                  final doc = await FirebaseFirestore.instance
                      .collection('training_codes')
                      .doc(enteredCode)
                      .get();
                  if (doc.exists) {
                    final cData = doc.data() ?? <String, dynamic>{};
                    if ((cData['code'] ?? doc.id).toString().trim() == enteredCode &&
                        (cData['courseId'] ?? '').toString() == course['id'].toString()) {
                      codeDoc = doc;
                      if (cData['isUsed'] != true && cData['isDisabled'] != true) {
                        foundInExternal = true;
                      }
                    }
                  }
                } catch (e) {
                  debugPrint('Error querying training_codes: $e');
                }

                // 2. الاحتياط: البحث في مصفوفة codes المدمجة
                var rawCodes = course['codes'] as List? ?? [];
                var codesList = rawCodes.map((c) => Map<String, dynamic>.from(c as Map)).toList();
                int matchedIndex = -1;

                if (!foundInExternal) {
                  for (int i = 0; i < codesList.length; i++) {
                    String dbCode = (codesList[i]['code'] ?? '').toString().trim();
                    bool isUsed = codesList[i]['isUsed'] == true;
                    bool isDisabled = codesList[i]['isDisabled'] == true;
                    if (dbCode == enteredCode && !isUsed && !isDisabled) {
                      matchedIndex = i;
                      break;
                    }
                  }
                }

                bool isValid = foundInExternal || matchedIndex != -1;

                if (isValid) {
                  try {
                    final firestore = FirebaseFirestore.instance;
                    final courseRef = firestore.collection('training_courses').doc(course['id'].toString());
                    final saleRef = firestore.collection('sales_log').doc();
                    final externalCodeRef = foundInExternal ? codeDoc?.reference : null;
                    if (foundInExternal && externalCodeRef == null) {
                      throw StateError('تعذر تحديد مستند كود التفعيل الخارجي.');
                    }
                    await firestore.runTransaction((transaction) async {
                      final courseSnapshot = await transaction.get(courseRef);
                      if (!courseSnapshot.exists) throw StateError('الكورس غير موجود.');
                      final freshCourse = Map<String, dynamic>.from(courseSnapshot.data()!);
                      var durationDays = 120;
                      final courseUpdates = <String, dynamic>{};
                      if (externalCodeRef != null) {
                        final codeSnapshot = await transaction.get(externalCodeRef);
                        if (!codeSnapshot.exists) throw StateError('كود التفعيل غير موجود.');
                        final codeData = codeSnapshot.data() as Map<String, dynamic>;
                        if ((codeData['code'] ?? '').toString().trim() != enteredCode ||
                            (codeData['courseId'] ?? '').toString() != course['id'].toString() ||
                            codeData['isUsed'] == true || codeData['isDisabled'] == true) {
                          throw StateError('الكود مستخدم أو معطل أو غير صالح لهذا الكورس.');
                        }
                        final rawDuration = codeData['durationDays'];
                        durationDays = rawDuration is num ? rawDuration.toInt() : 120;
                        transaction.update(externalCodeRef, {
                          'isUsed': true, 'usedBy': widget.userName,
                          'userUid': widget.userUid, 'usedAt': FieldValue.serverTimestamp(),
                        });
                      } else {
                        final rawCodes = freshCourse['codes'] as List? ?? [];
                        final codes = rawCodes.map((item) => Map<String, dynamic>.from(item as Map)).toList();
                        final codeIndex = codes.indexWhere((item) =>
                            (item['code'] ?? '').toString().trim() == enteredCode &&
                            item['isUsed'] != true && item['isDisabled'] != true);
                        if (codeIndex < 0) throw StateError('الكود مستخدم أو معطل أو غير صالح.');
                        final rawDuration = codes[codeIndex]['durationDays'];
                        durationDays = rawDuration is num ? rawDuration.toInt() : 120;
                        codes[codeIndex]['isUsed'] = true;
                        codes[codeIndex]['usedBy'] = widget.userName;
                        codes[codeIndex]['userUid'] = widget.userUid;
                        codes[codeIndex]['usedAt'] = DateTime.now().toIso8601String();
                        courseUpdates['codes'] = codes;
                      }
                      courseUpdates['unlockedUsers.${widget.userUid}'] = {
                          'name': widget.userName,
                          'activatedAt': FieldValue.serverTimestamp(),
                          'durationDays': durationDays,
                          'code': enteredCode,
                        };
                      transaction.update(courseRef, courseUpdates);
                      transaction.set(saleRef, {
                        'courseTitle': courseTitle, 'university': (freshCourse['category'] ?? 'دورات تدريبية'), 'college': (freshCourse['subCategory'] ?? 'سوق العمل'),
                        'price': coursePriceStr, 'userName': widget.userName,
                        'userUid': widget.userUid, 'codeUsed': enteredCode,
                        'purchasedAt': FieldValue.serverTimestamp(),
                      });
                    });
                    try {
                      final prefs = await SharedPreferences.getInstance();
                      final key = 'activated_training_courses_${widget.userUid}';
                      final active = prefs.getStringList(key) ?? <String>[];
                      if (!active.contains(course['id'].toString())) {
                        active.add(course['id'].toString());
                        await prefs.setStringList(key, active);
                      }
                    } catch (e) { debugPrint('Activation cache error: $e'); }
                    if (!context.mounted) return;
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('تم تفعيل الدورة التدريبية بنجاح! 🎉')),
                    );
                    if (mounted) setState(() {});
                  } catch (e, st) {
                    debugPrint('Activation transaction failed: $e\n$st');
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('تعذر تفعيل الاشتراك: $e')),
                    );
                  }
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('كود التفعيل غير صحيح أو مستخدم مسبقاً أو معطل'),
                  ));
                }
              },
              child: const Text('تفعيل الدورة'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // المستوى 1: اختيار المجال الرئيسي للدورات التدريبية
    if (selectedCategory == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text('اختر مجال الدورات التدريبية لسوق العمل:',
                style: TextStyle(
                    color: Color(0xFFE52521), fontSize: 19, fontWeight: FontWeight.w900)),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('training_categories')
                  .orderBy('name')
                  .limit(100)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('تعذر جلب المجالات التدريبية: ${snapshot.error}',
                      textAlign: TextAlign.center, style: const TextStyle(color: Colors.orangeAccent)));
                }
                if (!snapshot.hasData) {
                  return const Center(
                      child: CircularProgressIndicator(color: Color(0xFFE52521)));
                }
                final catDocs = snapshot.data!.docs;
                if (catDocs.isEmpty) {
                  return const Center(
                    child: Text('لا توجد مجالات تدريبية مضافة بعد',
                        style: TextStyle(color: Colors.grey)),
                  );
                }
                return GridView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 0.8,
                  ),
                  itemCount: catDocs.length,
                  itemBuilder: (context, index) {
                    var data = catDocs[index].data() as Map<String, dynamic>;
                    String catName = data['name'] ?? '';
                    return GestureDetector(
                      onTap: () => setState(() => selectedCategory = catName),
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF14141C),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: const Color(0xFFE52521).withValues(alpha: 0.6), width: 1.5),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              child: ClipRRect(
                                borderRadius:
                                    const BorderRadius.vertical(top: Radius.circular(18)),
                                child: Image.asset(
                                  'assets/images/university.jpg',
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) =>
                                      Image.asset('assets/icon/icon.jpg', fit: BoxFit.cover),
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Text(
                                catName,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold),
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      );
    }

    // المستوى 2: اختيار التخصص الفرعي داخل المجال
    if (selectedSubCategory == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFFE52521)),
                  onPressed: () => setState(() => selectedCategory = null),
                ),
                Expanded(
                  child: Text('تخصصات $selectedCategory:',
                      style: const TextStyle(
                          color: Color(0xFFE52521), fontSize: 18, fontWeight: FontWeight.w900)),
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('training_categories')
                  .where('name', isEqualTo: selectedCategory)
                  .limit(1)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('تعذر جلب التخصصات: ${snapshot.error}',
                      textAlign: TextAlign.center, style: const TextStyle(color: Colors.orangeAccent)));
                }
                if (!snapshot.hasData) {
                  return const Center(
                      child: CircularProgressIndicator(color: Color(0xFFE52521)));
                }
                List<String> subCats = [];
                if (snapshot.data!.docs.isNotEmpty) {
                  var data = snapshot.data!.docs.first.data() as Map<String, dynamic>;
                  subCats = List<String>.from(data['subCategories'] ?? []);
                }
                if (subCats.isEmpty) {
                  subCats = ['عام'];
                }
                return GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 0.8,
                  ),
                  itemCount: subCats.length,
                  itemBuilder: (context, index) {
                    String sub = subCats[index];
                    return GestureDetector(
                      onTap: () => setState(() => selectedSubCategory = sub),
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF14141C),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFFE52521), width: 1.5),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              child: ClipRRect(
                                borderRadius:
                                    const BorderRadius.vertical(top: Radius.circular(18)),
                                child: Image.asset(
                                  'assets/images/university.jpg',
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) =>
                                      Image.asset('assets/icon/icon.jpg', fit: BoxFit.cover),
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Text(
                                sub,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12),
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      );
    }

    // المستوى 3: عرض الدورات التدريبية المقفلة/المفعلة بنفس آلية المواد الجامعية
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFFE52521)),
                onPressed: () => setState(() => selectedSubCategory = null),
              ),
              Expanded(
                child: Text('دورات $selectedSubCategory ($selectedCategory):',
                    style: const TextStyle(
                        color: Color(0xFFE52521), fontSize: 16, fontWeight: FontWeight.w900)),
              ),
            ],
          ),
        ),
        Expanded(
          child: _PaginatedTrainingCoursesGrid(
            selectedCategory: selectedCategory!,
            selectedSubCategory: selectedSubCategory!,
            userName: widget.userName,
            userUid: widget.userUid,
            isAdmin: widget.isAdmin,
            adminPerms: widget.adminPerms,
            onActivationTap: _showTrainingActivationDialog,
          ),
        ),
      ],
    );
  }
}

class CoursePlayerScreen extends StatefulWidget {
  final Map<String, dynamic> course;
  final bool isAdmin;
  final String userUid;
  final String collection;
  final List<String> adminPerms;
  const CoursePlayerScreen({
    super.key,
    required this.course,
    required this.isAdmin,
    required this.userUid,
    required this.adminPerms,
    this.collection = 'courses',
  });

  @override
  State<CoursePlayerScreen> createState() => _CoursePlayerScreenState();
}

class _CoursePlayerScreenState extends State<CoursePlayerScreen> {
  /// شاشة تظهر عندما يُوقف الأدمن الاشتراك أو تنتهي مدته (إغلاق فوري).
  Widget _buildLockedView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock_rounded, color: Color(0xFFE52521), size: 64),
            const SizedBox(height: 16),
            const Text(
              'تم إيقاف أو انتهاء صلاحية هذا الاشتراك',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'لم يعد بإمكانك الوصول إلى محتوى هذا المقرر. يرجى التواصل مع الإدارة لإعادة التفعيل.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white60, fontSize: 13),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE52521)),
              icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
              label: const Text('العودة', style: TextStyle(color: Colors.white)),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // الاستماع الحي لمستند المقرر من Firestore للتحقق الفوري من الاشتراك.
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection(widget.collection)
          .doc(widget.course['id'])
          .snapshots(),
      builder: (context, snapshot) {
        Map<String, dynamic> liveCourse = widget.course;
        bool docMissing = false;
        if (snapshot.hasData) {
          if (snapshot.data!.exists) {
            liveCourse = snapshot.data!.data() as Map<String, dynamic>;
            liveCourse['id'] = snapshot.data!.id;
          } else {
            docMissing = true;
          }
        }

        bool isActive = widget.isAdmin;
        if (!widget.isAdmin) {
          var unlockedMap = liveCourse['unlockedUsers'] as Map?;
          var info = unlockedMap != null ? unlockedMap[widget.userUid] : null;
          isActive = !docMissing && isSubscriptionActive(info);
        }

        var lectures = liveCourse['lectures'] as List<dynamic>? ?? [];
        var coursePdfs = liveCourse['pdfs'] as List<dynamic>? ?? [];

        return Stack(
          children: [
            Scaffold(
              appBar: AppBar(title: Text(liveCourse['title'] ?? 'المقرر التعليمي')),
              body: !isActive
                  ? _buildLockedView()
                  : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text('قائمة المحاضرات والدروس الآمنة 📚',
                          style: TextStyle(
                              color: Color(0xFFE52521),
                              fontSize: 18,
                              fontWeight: FontWeight.w900)),
                    ),
                    if (liveCourse['pdfUrl'] != null &&
                        liveCourse['pdfUrl'].toString().isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 4),
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1E1E28)),
                          icon: const Icon(Icons.picture_as_pdf,
                              color: Colors.redAccent),
                          label: const Text('فتح ملف PDF الرئيسي للمقرر',
                              style: TextStyle(color: Colors.white)),
                          onPressed: () async {
                            Uri pdfUri = Uri.parse(normalizePdfUrl(liveCourse['pdfUrl'].toString()));
                            if (await canLaunchUrl(pdfUri)) {
                              await launchUrl(pdfUri,
                                  mode: LaunchMode.externalApplication);
                            }
                          },
                        ),
                      ),
                    const Divider(color: Colors.white24, height: 20),
                    Expanded(
                      child: lectures.isEmpty
                          ? const Center(
                              child: Text('لا توجد محاضرات مضافة لهذا المقرر بعد',
                                  style: TextStyle(color: Colors.grey)))
                          : ListView.builder(
                              padding: const EdgeInsets.all(12),
                              itemCount: lectures.length,
                              itemBuilder: (context, i) {
                                var lec = lectures[i];
                                return Container(
                                  margin: const EdgeInsets.symmetric(
                                      vertical: 6, horizontal: 4),
                                  decoration: BoxDecoration(
                                      color: const Color(0xFF14141C),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                          color: const Color(0xFF2E2E3A))),
                                  child: ListTile(
                                    leading: CircleAvatar(
                                        backgroundColor:
                                            const Color(0xFFE52521),
                                        child: Text('${i + 1}',
                                            style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold))),
                                    title: Text(lec['title'] ?? 'المحاضرة ${i + 1}',
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15)),
                                    subtitle: const Text(
                                        'اضغط للدخول إلى صفحة المحاضرة والفيديو وبنك الأسئلة 🎬',
                                        style: TextStyle(
                                            color: Colors.grey, fontSize: 11)),
                                    trailing: const Icon(
                                        Icons.arrow_forward_ios_rounded,
                                        color: Color(0xFFE52521),
                                        size: 16),
onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                LectureDetailScreen(
                                              course: liveCourse,
                                              initialLectureIndex: i,
                                              isAdmin: widget.isAdmin,
                                              userUid: widget.userUid,
                                              adminPerms: widget.adminPerms,
                                              collection: widget.collection,
                                            ),
                                          ),
                                        );
                                      },
                                  ),
                                );
                              },
                            ),
                    ),
                    if (coursePdfs.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.all(12),
                        color: const Color(0xFF181820),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('قائمة الملفات الإضافية وبنك الأسئلة العام:',
                                style: TextStyle(
                                    color: Colors.amberAccent,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14)),
                            const SizedBox(height: 6),
                            ...coursePdfs.map((pdf) => ListTile(
                                  leading: const Icon(Icons.picture_as_pdf,
                                      color: Colors.redAccent),
                                  title: Text(pdf['name'] ?? 'ملف PDF',
                                      style: const TextStyle(
                                          color: Colors.white, fontSize: 13)),
                                  onTap: () async {
                                    Uri uri = Uri.parse(normalizePdfUrl((pdf['url'] ?? '').toString()));
                                    if (await canLaunchUrl(uri)) {
                                      await launchUrl(uri,
                                          mode:
                                              LaunchMode.externalApplication);
                                    }
                                  },
                                )),
                          ],
                        ),
                      ),
                  ],
                ),
            ),
          ],
        );
      },
    );
  }
}

class LectureDetailScreen extends StatefulWidget {
  final Map<String, dynamic> course;
  final int initialLectureIndex;
  final bool isAdmin;
  final String userUid;
  final String collection;
  final List<String> adminPerms;

  const LectureDetailScreen({
    super.key,
    required this.course,
    required this.initialLectureIndex,
    required this.isAdmin,
    required this.userUid,
    required this.adminPerms,
    this.collection = 'courses',
  });

  @override
  State<LectureDetailScreen> createState() => _LectureDetailScreenState();
}

class _LectureDetailScreenState extends State<LectureDetailScreen> {
  late int currentIndex;
  late List<dynamic> lectures;

  @override
  void initState() {
    super.initState();
    currentIndex = widget.initialLectureIndex;
    lectures = widget.course['lectures'] ?? [];
  }

  bool _isActive(Map<String, dynamic>? course) {
    if (widget.isAdmin) return true;
    var unlockedMap = course?['unlockedUsers'] as Map?;
    var info = unlockedMap != null ? unlockedMap[widget.userUid] : null;
    return isSubscriptionActive(info);
  }

  Widget _buildLockedScaffold() {
    return Scaffold(
      appBar: AppBar(title: const Text('الاشتراك غير مفعّل')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock_rounded, color: Color(0xFFE52521), size: 56),
              const SizedBox(height: 16),
              const Text(
                'تم إيقاف أو انتهاء صلاحية هذا الاشتراك',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'لم يعد بإمكانك الوصول إلى محتوى هذه المحاضرة. يرجى التواصل مع الإدارة لإعادة التفعيل.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white60, fontSize: 13),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE52521)),
                icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                label: const Text('العودة', style: TextStyle(color: Colors.white)),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // الاستماع الحي لمستند المقرر لإغلاق المحتوى فوراً عند تعطيل الأدمن أو انتهاء المدة.
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection(widget.collection)
          .doc(widget.course['id'])
          .snapshots(),
      builder: (context, snapshot) {
        Map<String, dynamic>? liveCourse;
        if (snapshot.hasData && snapshot.data!.exists) {
          liveCourse = snapshot.data!.data() as Map<String, dynamic>;
          liveCourse['id'] = snapshot.data!.id;
        }

        bool active = widget.isAdmin;
        if (!widget.isAdmin) {
          active = liveCourse != null && _isActive(liveCourse);
        }
        if (!active) return _buildLockedScaffold();

        return _buildLectureBody(liveCourse ?? widget.course);
      },
    );
  }

  Widget _buildLectureBody(Map<String, dynamic> course) {
    lectures = course['lectures'] ?? [];
    if (currentIndex < 0 || currentIndex >= lectures.length) currentIndex = 0;
    var lec = lectures[currentIndex] ?? {};
    String title = lec['title'] ?? 'المحاضرة ${currentIndex + 1}';
    String url = lec['url'] ?? '';
    String videoId = lec['videoId'] ?? '';
    String pdfUrl = lec['pdfUrl'] ?? lec['pdf'] ?? '';
    String questionBankUrl = lec['questionBankUrl'] ?? lec['questionBank'] ?? '';

    return Stack(
      children: [
        Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          if (currentIndex > 0)
            IconButton(
              icon: const Icon(Icons.arrow_forward_ios_rounded, size: 18),
              tooltip: 'المحاضرة السابقة',
              onPressed: () => setState(() => currentIndex--),
            ),
          if (currentIndex < lectures.length - 1)
            IconButton(
              icon: const Icon(Icons.arrow_back_ios_rounded, size: 18),
              tooltip: 'المحاضرة التالية',
              onPressed: () => setState(() => currentIndex++),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 240,
              child: (url.isEmpty && videoId.isEmpty)
                  ? const Center(
                      child: Text('لا يوجد فيديو لهذه المحاضرة',
                          style: TextStyle(color: Colors.grey)))
                  : CourseYouTubePlayerWidget(
                      videoUrlOrId: videoId.isNotEmpty ? videoId : url,
                    ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        currentIndex > 0 ? const Color(0xFF1E1E28) : Colors.grey.shade800,
                  ),
                  onPressed: currentIndex > 0 ? () => setState(() => currentIndex--) : null,
                  icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                  label: const Text('المحاضرة السابقة', style: TextStyle(fontSize: 12)),
                ),
                Text('محاضرة ${currentIndex + 1} من ${lectures.length}',
                    style: const TextStyle(
                        color: Colors.amberAccent, fontWeight: FontWeight.bold)),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: currentIndex < lectures.length - 1
                        ? const Color(0xFF1E1E28)
                        : Colors.grey.shade800,
                  ),
                  onPressed: currentIndex < lectures.length - 1
                      ? () => setState(() => currentIndex++)
                      : null,
                  label: const Text('التالية', style: TextStyle(fontSize: 12)),
                  icon: const Icon(Icons.arrow_back_rounded, size: 16),
                ),
              ],
            ),
            const Divider(color: Colors.white24, height: 35),
            const Text('مستلزمات المحاضرة والامتحانات 📚',
                style: TextStyle(
                    color: Color(0xFFE52521), fontSize: 18, fontWeight: FontWeight.w900)),
            const SizedBox(height: 12),
            Card(
              color: const Color(0xFF14141C),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: ListTile(
                leading:
                    const Icon(Icons.picture_as_pdf_rounded, color: Colors.redAccent, size: 32),
                title: const Text('ملف PDF للمحاضرة',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                subtitle: Text(
                    pdfUrl.isNotEmpty ? 'متاح للتحميل والدراسة' : 'غير متوفر حالياً',
                    style: const TextStyle(color: Colors.grey, fontSize: 11)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                          backgroundColor:
                              pdfUrl.isNotEmpty ? const Color(0xFFE52521) : Colors.grey),
                      onPressed: pdfUrl.isNotEmpty
                          ? () async {
                              Uri uri = Uri.parse(normalizePdfUrl(pdfUrl));
                              if (await canLaunchUrl(uri)) {
                                await launchUrl(uri, mode: LaunchMode.externalApplication);
                              }
                            }
                          : null,
                      child: const Text('فتح PDF', style: TextStyle(fontSize: 12)),
                    ),
                    const SizedBox(width: 6),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: pdfUrl.isNotEmpty ? Colors.green : Colors.grey),
                      onPressed: pdfUrl.isNotEmpty
                          ? () async {
                              String fileName = pdfUrl.split('/').last;
                              if (fileName.isEmpty) fileName = 'lecture_${currentIndex + 1}.pdf';
                              String? localPath = await downloadPdfToLocal(pdfUrl, fileName);
                              if (!mounted) return;
                              if (localPath != null) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('تم تنزيل وحفظ ملف PDF بنجاح ✅')),
                                );
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('فشل تنزيل ملف PDF')),
                                );
                              }
                            }
                          : null,
                      child: const Text('تنزيل PDF', style: TextStyle(fontSize: 12)),
                    ),
                    const SizedBox(width: 6),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: pdfUrl.isNotEmpty ? Colors.blue : Colors.grey,
                      ),
                      onPressed: pdfUrl.isNotEmpty
                          ? () async {
                              String fileName = pdfUrl.split('/').last;
                              if (fileName.isEmpty) fileName = 'lecture_${currentIndex + 1}.pdf';
                              String? localPath = await downloadPdfToLocal(pdfUrl, fileName);
                              if (!mounted) return;
                              if (localPath != null) {
                                if (kIsWeb) {
                                  // على الويب: الملف تم تحميله عبر المتصفح، افتح الرابط مباشرة
                                  Uri uri = Uri.parse(normalizePdfUrl(pdfUrl));
                                  if (await canLaunchUrl(uri)) {
                                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                                  }
                                } else {
                                  // على الجوال: افتح الملف المحفوظ محلياً
                                  final result = await OpenFilex.open(localPath);
                                  if (!mounted) return;
                                  if (result.type != ResultType.done) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                          content: Text('تعذر فتح الملف: ${result.message}'),
                                    ));
                                  }
                                }
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('فشل فتح ملف PDF')),
                                );
                              }
                            }
                          : null,
                      child: const Text('تحميل محلي', style: TextStyle(fontSize: 11)),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              color: const Color(0xFF14141C),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: ListTile(
                leading: const Icon(Icons.quiz_rounded, color: Colors.amberAccent, size: 32),
                title: const Text('بنك الأسئلة ونماذج الامتحانات 📝',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                subtitle: Text(
                    questionBankUrl.isNotEmpty
                        ? 'متاح للتدريب ونماذج الامتحانات'
                        : 'غير متوفر حالياً',
                    style: const TextStyle(color: Colors.grey, fontSize: 11)),
                trailing: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: questionBankUrl.isNotEmpty ? Colors.green : Colors.grey),
                  onPressed: questionBankUrl.isNotEmpty
                      ? () async {
                          Uri uri = Uri.parse(questionBankUrl);
                          if (await canLaunchUrl(uri)) {
                            await launchUrl(uri, mode: LaunchMode.externalApplication);
                          }
                        }
                      : null,
                  child: const Text('بنك الأسئلة', style: TextStyle(fontSize: 12)),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  ],
);
}
}

class CourseYouTubePlayerWidget extends StatefulWidget {
  final String videoUrlOrId;
  const CourseYouTubePlayerWidget({super.key, required this.videoUrlOrId});

  @override
  State<CourseYouTubePlayerWidget> createState() => _CourseYouTubePlayerWidgetState();
}

String extractYoutubeVideoId(String url) {
  final trimmed = url.trim();
  if (RegExp(r'^[a-zA-Z0-9_-]{11}$').hasMatch(trimmed)) {
    return trimmed;
  }
  final regExp = RegExp(
    r'(?:youtube\.com\/(?:[^\/]+\/.+\/|(?:v|e(?:mbed)?)\/|.*[?&]v=)|youtu\.be\/)([^"&?\/\s]{11})',
    caseSensitive: false,
  );
  final match = regExp.firstMatch(trimmed);
  return match?.group(1) ?? trimmed;
}

class _CourseYouTubePlayerWidgetState extends State<CourseYouTubePlayerWidget> {
  late YoutubePlayerController _playerController;
  OverlayEntry? _fullscreenOverlay;
  bool _isFullscreen = false;
  bool _hasValidVideoId = false;

  bool _isPlaying = false;
  String? _quality;
  Duration _position = Duration.zero;
  double _durationSec = 0;

  StreamSubscription<YoutubePlayerValue>? _stateSub;
  StreamSubscription<Duration>? _posSub;

  String extractVideoId(String url) => extractYoutubeVideoId(url);

  YoutubePlayerController _createSecureController(String videoId) {
    return YoutubePlayerController.fromVideoId(
      videoId: videoId.isNotEmpty ? videoId : '___________',
      params: const YoutubePlayerParams(
        // إخفاء أدوات يوتيوب الأصلية (زر المشاركة، الجودة، اسم القناة، الشعار)
        showControls: false,
        showFullscreenButton: false,
        strictRelatedVideos: true,
        showVideoAnnotations: false,
        enableJavaScript: true,
        origin: 'https://www.youtube-nocookie.com',
      ),
    );
  }

  void _bindListeners() {
    _stateSub = _playerController.stream.listen((value) {
      if (!mounted) return;
      final playing = value.playerState == PlayerState.playing;
      if (playing != _isPlaying || value.playbackQuality != _quality) {
        setState(() {
          _isPlaying = playing;
          _quality = value.playbackQuality;
        });
      }
      _refreshDuration();
    });
    _posSub = _playerController.getCurrentPositionStream().listen((pos) {
      if (!mounted) return;
      if (pos != _position) setState(() => _position = pos);
    });
  }

  Future<void> _refreshDuration() async {
    if (_durationSec > 0 || !mounted) return;
    try {
      final d = await _playerController.duration;
      if (mounted && d > 0) setState(() => _durationSec = d);
    } catch (_) {}
  }

  @override
  void initState() {
    super.initState();
    String vidId = extractVideoId(widget.videoUrlOrId);
    _hasValidVideoId = RegExp(r'^[a-zA-Z0-9_-]{11}$').hasMatch(vidId);
    _playerController = _createSecureController(_hasValidVideoId ? vidId : '');
    _bindListeners();
  }

  @override
  void didUpdateWidget(covariant CourseYouTubePlayerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoUrlOrId != widget.videoUrlOrId) {
      _stateSub?.cancel();
      _posSub?.cancel();
      _playerController.close();
      _isPlaying = false;
      _quality = null;
      _position = Duration.zero;
      _durationSec = 0;
      String vidId = extractVideoId(widget.videoUrlOrId);
      _hasValidVideoId = RegExp(r'^[a-zA-Z0-9_-]{11}$').hasMatch(vidId);
      _playerController = _createSecureController(_hasValidVideoId ? vidId : '');
      _bindListeners();
    }
  }

  @override
  void dispose() {
    _removeFullscreenOverlay();
    _stateSub?.cancel();
    _posSub?.cancel();
    _playerController.close();
    super.dispose();
  }

  String _fmtDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    if (h > 0) return '${twoDigits(h)}:${twoDigits(m)}:${twoDigits(s)}';
    return '${twoDigits(m)}:${twoDigits(s)}';
  }

  void _togglePlay() {
    if (_isPlaying) {
      _playerController.pauseVideo();
    } else {
      _playerController.playVideo();
    }
  }

  void _seekBy(int seconds) {
    final target =
        (_position.inSeconds + seconds).clamp(0, _durationSec.round());
    _playerController.seekTo(
        seconds: target.toDouble(), allowSeekAhead: seconds > 0);
  }

  void _enterFullscreen() {
    SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _isFullscreen = true;
    _fullscreenOverlay = OverlayEntry(builder: (ctx) => _buildFullscreenView());
    Overlay.of(context).insert(_fullscreenOverlay!);
    setState(() {});
  }

  void _removeFullscreenOverlay() {
    _fullscreenOverlay?.remove();
    _fullscreenOverlay = null;
  }

  void _exitFullscreen() {
    _removeFullscreenOverlay();
    SystemChrome.setPreferredOrientations(const [DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _isFullscreen = false;
    if (mounted) setState(() {});
  }

  void _toggleFullscreen() {
    if (_isFullscreen) {
      _exitFullscreen();
    } else {
      _enterFullscreen();
    }
  }

  Widget _circleIconButton(IconData icon, VoidCallback onTap,
      {String? tooltip}) {
    return Material(
      color: Colors.black54,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: IconButton(
        tooltip: tooltip,
        icon: Icon(icon, color: Colors.white),
        onPressed: onTap,
      ),
    );
  }

  Widget _buildFullscreenView() {
    return Material(
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Center(
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: SecureYouTubePlayer(controller: _playerController),
            ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: _circleIconButton(Icons.fullscreen_exit_rounded, _exitFullscreen,
                tooltip: 'إنهاء ملء الشاشة'),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _buildControlBar(isFullscreen: true),
          ),
        ],
      ),
    );
  }

  Widget _buildControlBar({bool isFullscreen = false}) {
    final isPlaying = _isPlaying;
    final pos = _position;
    final durMs = (_durationSec * 1000).round();
    return Container(
      color: Colors.black54,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (durMs > 0)
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 2,
                overlayShape: SliderComponentShape.noOverlay,
              ),
              child: Slider(
                value: pos.inMilliseconds.clamp(0, durMs).toDouble(),
                max: durMs.toDouble(),
                onChanged: (v) {
                  _playerController.seekTo(
                      seconds: v / 1000, allowSeekAhead: true);
                },
              ),
            ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                  '${_fmtDuration(pos)} / ${_fmtDuration(Duration(milliseconds: durMs))}',
                  style: const TextStyle(color: Colors.white, fontSize: 11)),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'إرجاع 10 ثوان',
                    icon: const Icon(Icons.replay_10_rounded, color: Colors.white),
                    onPressed: () => _seekBy(-10),
                  ),
                  IconButton(
                    tooltip: isPlaying ? 'إيقاف' : 'تشغيل',
                    icon: Icon(
                        isPlaying
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                        color: Colors.white),
                    onPressed: _togglePlay,
                  ),
                  IconButton(
                    tooltip: 'تقديم 10 ثوان',
                    icon: const Icon(Icons.forward_10_rounded, color: Colors.white),
                    onPressed: () => _seekBy(10),
                  ),
                  IconButton(
                    tooltip: 'الجودة',
                    icon: const Icon(Icons.hd_rounded, color: Colors.white),
                    onPressed: _showQualityMenu,
                  ),
                  IconButton(
                    tooltip: isFullscreen ? 'إنهاء ملء الشاشة' : 'ملء الشاشة',
                    icon: Icon(
                        isFullscreen
                            ? Icons.fullscreen_exit_rounded
                            : Icons.fullscreen_rounded,
                        color: Colors.white),
                    onPressed: _toggleFullscreen,
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showQualityMenu() {
    final currentQuality = _quality ?? 'تلقائي';
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E28),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(12),
                child: Text('جودة الفيديو',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold)),
              ),
              ...['تلقائي', '1080p', '720p', '480p', '360p'].map((q) {
                final bool isCurrent =
                    (q == 'تلقائي' && (currentQuality == 'تلقائي')) ||
                        q.toLowerCase() == currentQuality.toLowerCase();
                return ListTile(
                  leading: Icon(
                    isCurrent ? Icons.radio_button_checked : Icons.hd_rounded,
                    color: isCurrent ? const Color(0xFFE52521) : Colors.white70,
                  ),
                  title: Text(q, style: const TextStyle(color: Colors.white)),
                  trailing: q == currentQuality
                      ? const Text('الحالية',
                          style: TextStyle(color: Colors.white54, fontSize: 11))
                      : null,
                  onTap: () {
                    Navigator.pop(ctx);
                    // واجهة YouTube المضمّنة لا تدعم ضبط الجودة يدوياً؛ نعيد التحميل
                    final vidId = extractVideoId(widget.videoUrlOrId);
                    _playerController.loadVideoById(videoId: vidId);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('تمت إعادة التحميل ($q)')),
                    );
                  },
                );
              }).toList(),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_hasValidVideoId) {
      return Container(
        color: Colors.black,
        height: 220,
        alignment: Alignment.center,
        child: const Text('رابط فيديو يوتيوب غير صالح. يرجى إبلاغ الإدارة.',
            textAlign: TextAlign.center, style: TextStyle(color: Colors.white70)),
      );
    }
    return Container(
      color: Colors.black,
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: Stack(
          children: [
            Positioned.fill(
              child: SecureYouTubePlayer(controller: _playerController),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _buildControlBar(),
            ),
          ],
        ),
      ),
    );
  }
}

class _PaginatedStoreGrid extends StatefulWidget {
  final String selectedCategory;
  final String searchQuery;
  final bool isDark;
  final String userName;
  final String userPhone;
  final String userUid;
  final bool isAdmin;

  const _PaginatedStoreGrid({
    required this.selectedCategory,
    required this.searchQuery,
    required this.isDark,
    required this.userName,
    required this.userPhone,
    required this.userUid,
    required this.isAdmin,
  });

  @override
  State<_PaginatedStoreGrid> createState() => _PaginatedStoreGridState();
}

class _PaginatedStoreGridState extends State<_PaginatedStoreGrid> {
  final List<Map<String, dynamic>> _items = [];
  DocumentSnapshot? _lastDoc;
  bool _isLoading = false;
  bool _hasMore = true;
  final int _pageSize = 10;

  @override
  void initState() {
    super.initState();
    _loadMore();
  }

  @override
  void didUpdateWidget(covariant _PaginatedStoreGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedCategory != widget.selectedCategory ||
        oldWidget.searchQuery != widget.searchQuery) {
      _items.clear();
      _lastDoc = null;
      _hasMore = true;
      _loadMore();
    }
  }

  Future<void> _loadMore() async {
    if (_isLoading || !_hasMore) return;
    setState(() => _isLoading = true);

    try {
      final collection = widget.selectedCategory == 'العروض'
          ? FirebaseFirestore.instance.collection('bundles')
          : FirebaseFirestore.instance.collection('products');

      Query query = collection.orderBy('title').limit(_pageSize);
      if (_lastDoc != null) {
        query = query.startAfterDocument(_lastDoc!);
      }

      final snap = await query.get();
      final docs = snap.docs;

      if (docs.isEmpty) {
        setState(() => _hasMore = false);
      } else {
        final newItems = docs.map((d) {
          var data = d.data() as Map<String, dynamic>;
          data['id'] = d.id;
          return data;
        }).where((p) {
          bool matchCat = (widget.selectedCategory == 'الكل' ||
              widget.selectedCategory == 'العروض' ||
              p['category'] == widget.selectedCategory);
          bool matchQuery = (widget.searchQuery.isEmpty ||
              p['title'].toString().toLowerCase().contains(widget.searchQuery.toLowerCase()));
          return matchCat && matchQuery;
        }).toList();

        setState(() {
          _items.addAll(newItems);
          _lastDoc = docs.last;
          _hasMore = docs.length == _pageSize;
        });
      }
    } catch (e) {
      debugPrint('Load more error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_items.isEmpty && !_isLoading) {
      return SliverFillRemaining(
        child: FutureBuilder(
          future: _loadMore(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: Color(0xFFE52521)));
            }
            if (_items.isEmpty) {
              return const Center(
                  child: Text('لا توجد منتجات أو عروض مضافة بعد',
                      style: TextStyle(color: Colors.grey)));
            }
            return const SizedBox.shrink();
          },
        ),
      );
    }

    return SliverGrid(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.72,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          if (index == _items.length) {
            // Load more button
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Color(0xFFE52521))
                    : _hasMore
                        ? ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFE52521)),
                            icon: const Icon(Icons.download_rounded, color: Colors.white),
                            label: const Text('تحميل المزيد',
                                style: TextStyle(color: Colors.white)),
                            onPressed: _loadMore,
                          )
                        : const Text('لا توجد عناصر إضافية',
                            style: TextStyle(color: Colors.grey)),
              ),
            );
          }

          var p = _items[index];
          bool isFav = globalFavorites.contains(p['id']);
          String? discountBadge = p['discountBadge'];

          return GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ProductDetailsScreen(
                    product: p,
                    userName: widget.userName,
                    userPhone: widget.userPhone,
                    userUid: widget.userUid,
                    isAdmin: widget.isAdmin,
                  ),
                ),
              );
            },
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: widget.isDark
                      ? const [Color(0xFF242735), Color(0xFF171A23)]
                      : const [Color(0xFFFFFFFF), Color(0xFFF2F4F9)],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: widget.isDark ? const Color(0xFF3A4050) : const Color(0xFFDDE1EA),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: widget.isDark ? 0.16 : 0.05),
                    blurRadius: 12,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Stack(
                      children: [
                        ClipRRect(
                          borderRadius:
                              const BorderRadius.vertical(top: Radius.circular(16)),
                          child: CachedNetworkImage(
                            imageUrl: p['image'] ?? '',
                            fit: BoxFit.cover,
                            width: double.infinity,
                            memCacheWidth: 300,
                            memCacheHeight: 300,
                            errorWidget: (context, url, error) => Container(
                              color: Colors.grey.shade900,
                              child: const Center(
                                  child: Icon(Icons.broken_image, color: Colors.grey)),
                            ),
                          ),
                        ),
                        if (discountBadge != null && discountBadge.isNotEmpty)
                          Positioned(
                            top: 6,
                            left: 6,
                            child: Container(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.red,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                discountBadge,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        Positioned(
                          top: 6,
                          right: 6,
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                if (isFav) {
                                  globalFavorites.remove(p['id']);
                                } else {
                                  globalFavorites.add(p['id']);
                                }
                              });
                            },
                            child: CircleAvatar(
                              backgroundColor: Colors.black54,
                              radius: 14,
                              child: Icon(
                                isFav
                                    ? Icons.favorite_rounded
                                    : Icons.favorite_border_rounded,
                                color: Colors.redAccent,
                                size: 16,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(p['title'] ?? '',
                            style:
                                const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            maxLines: 1),
                        const SizedBox(height: 2),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0x22E52521),
                            borderRadius: BorderRadius.circular(9),
                            border: Border.all(color: const Color(0x44E52521)),
                          ),
                          child: Text(
                            p['price'] ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFFFF655E),
                              fontWeight: FontWeight.w900,
                              fontSize: 12,
                              height: 1.2,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Expanded(
                              child: SizedBox(
                                height: 32,
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
                                    shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8)),
                                  ),
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => ProductDetailsScreen(
                                          product: p,
                                          userName: widget.userName,
                                          userPhone: widget.userPhone,
                                          userUid: widget.userUid,
                                          isAdmin: widget.isAdmin,
                                        ),
                                      ),
                                    );
                                  },
                                  child: const Text('طلب',
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold)),
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            IconButton(
                              constraints: const BoxConstraints(),
                              padding: EdgeInsets.zero,
                              icon: const Icon(Icons.add_shopping_cart_rounded,
                                  color: Color(0xFFE52521), size: 20),
                              onPressed: () {
                                globalCart.add({
                                  'title': p['title'],
                                  'price': p['price'],
                                  'priceNum': p['priceNum'] ?? 0,
                                  'currency': p['currency'] ?? 'ل.س',
                                  'image': p['image'],
                                  'qty': 1,
                                });
                                setState(() {});
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                                    content:
                                        Text('تمت إضافة المنتج إلى سلة المشتريات 🛒')));
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
        childCount: _items.length + (_hasMore ? 1 : 0),
      ),
    );
  }
}

class _PaginatedCoursesGrid extends StatefulWidget {
  final String selectedUni;
  final String? selectedCollege;
  final String userName;
  final String userUid;
  final bool isAdmin;
  final List<String> adminPerms;
  final Function(Map<String, dynamic>) onActivationTap;

  const _PaginatedCoursesGrid({
    required this.selectedUni,
    required this.selectedCollege,
    required this.userName,
    required this.userUid,
    required this.isAdmin,
    required this.adminPerms,
    required this.onActivationTap,
  });

  @override
  State<_PaginatedCoursesGrid> createState() => _PaginatedCoursesGridState();
}

class _PaginatedCoursesGridState extends State<_PaginatedCoursesGrid> {
  final List<Map<String, dynamic>> _items = [];
  DocumentSnapshot? _lastDoc;
  bool _isLoading = false;
  bool _hasMore = true;
  String? _loadError;
  final int _pageSize = 20;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _loadMore();
  }

  @override
  void didUpdateWidget(covariant _PaginatedCoursesGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedUni != widget.selectedUni || oldWidget.selectedCollege != widget.selectedCollege) {
      _generation++;
      _items.clear();
      _lastDoc = null;
      _hasMore = true;
      _loadError = null;
      _isLoading = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _loadMore();
      });
    }
  }

  Future<void> _loadMore() async {
    if (_isLoading || !_hasMore || !mounted) return;
    final generation = _generation;
    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    try {
      // Filter by university in Firestore and by college locally for compatibility
      // with older course documents that do not contain a college field.
      bool reachedEnd = false;
      final initialItemCount = _items.length;
      while (mounted && _hasMore && _items.length == initialItemCount) {
        Query query = FirebaseFirestore.instance
            .collection('courses')
            .where('university', isEqualTo: widget.selectedUni)
            .limit(_pageSize);
        if (_lastDoc != null) query = query.startAfterDocument(_lastDoc!);

        final snap = await query.get();
        if (!mounted || generation != _generation) return;
        final docs = snap.docs;
        if (docs.isEmpty) {
          reachedEnd = true;
          break;
        }

        final pageItems = docs.map((doc) {
          final data = Map<String, dynamic>.from(doc.data() as Map<String, dynamic>);
          data['id'] = doc.id;
          return data;
        }).where((course) {
          if (widget.selectedCollege == null) return true;
          return (course['college'] ?? '').toString().trim() ==
              widget.selectedCollege!.trim();
        }).toList();

        final existingIds = _items.map((item) => item['id']).toSet();
        final uniqueItems = pageItems
            .where((item) => !existingIds.contains(item['id']))
            .toList();
        _items.addAll(uniqueItems);
        _lastDoc = docs.last;
        _hasMore = docs.length == _pageSize;
        if (!_hasMore) reachedEnd = true;
        // If this page had no matching college, continue scanning instead of
        // presenting a false empty state while later pages still contain matches.
        if (_items.isNotEmpty || !_hasMore) break;
      }
      if (reachedEnd) _hasMore = false;
    } catch (e, st) {
      debugPrint('Load university courses error: $e\n$st');
      if (mounted && generation == _generation) _loadError = e.toString();
    } finally {
      if (mounted && generation == _generation) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_items.isEmpty) {
      if (_isLoading) {
        return const Center(child: CircularProgressIndicator(color: Color(0xFFE52521)));
      }
      if (_loadError != null) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.cloud_off, color: Colors.orangeAccent, size: 38),
              const SizedBox(height: 10),
              const Text('تعذر جلب المقررات. تحقق من الاتصال والصلاحيات ثم أعد المحاولة.',
                  textAlign: TextAlign.center, style: TextStyle(color: Colors.white70)),
              const SizedBox(height: 10),
              ElevatedButton.icon(onPressed: _loadMore,
                  icon: const Icon(Icons.refresh), label: const Text('إعادة المحاولة')),
            ]),
          ),
        );
      }
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('لا توجد مقررات منشورة لهذه الكلية حالياً.',
              style: TextStyle(color: Colors.grey)),
          if (_hasMore) TextButton(onPressed: _loadMore, child: const Text('تحديث')),
        ]),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 0.8,
      ),
      itemCount: _items.length + (_hasMore || _loadError != null ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _items.length) {
          return Center(child: Padding(
            padding: const EdgeInsets.all(16),
            child: _isLoading
                ? const CircularProgressIndicator(color: Color(0xFFE52521))
                : _loadError != null
                    ? TextButton.icon(onPressed: _loadMore,
                        icon: const Icon(Icons.refresh), label: const Text('فشل التحميل — أعد المحاولة'))
                    : _hasMore
                        ? ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE52521)),
                            icon: const Icon(Icons.download_rounded, color: Colors.white),
                            label: const Text('تحميل المزيد', style: TextStyle(color: Colors.white)),
                            onPressed: _loadMore,
                          )
                        : const Text('لا توجد عناصر إضافية', style: TextStyle(color: Colors.grey)),
          ));
        }

        final course = _items[index];
        final unlockedMap = course['unlockedUsers'] as Map?;
        final userUnlockInfo = unlockedMap?[widget.userUid] ?? unlockedMap?[widget.userName];
        final isUnlocked = isSubscriptionActive(userUnlockInfo);
        return GestureDetector(
          onTap: () {
            if (isUnlocked) {
              Navigator.push(context, MaterialPageRoute(builder: (_) => CoursePlayerScreen(
                course: course, isAdmin: widget.isAdmin, userUid: widget.userUid,
                adminPerms: widget.adminPerms,
              )));
            } else {
              widget.onActivationTap(course);
            }
          },
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF14141C), borderRadius: BorderRadius.circular(20),
              border: Border.all(color: isUnlocked ? Colors.green : const Color(0xFFE52521), width: 1.5),
            ),
            padding: const EdgeInsets.all(10),
            child: Stack(children: [
              Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(isUnlocked ? Icons.lock_open_rounded : Icons.lock_rounded,
                    color: isUnlocked ? Colors.green : const Color(0xFFE52521), size: 48),
                const SizedBox(height: 8),
                Text(course['title']?.toString() ?? 'مقرر',
                    style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Text(course['price']?.toString() ?? '',
                    style: const TextStyle(color: Color(0xFFE52521), fontWeight: FontWeight.w900, fontSize: 12)),
              ]),
              if (!isUnlocked) Positioned.fill(child: Container(
                decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(20)),
                child: const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.lock_rounded, color: Colors.white54, size: 32),
                  SizedBox(height: 4), Text('مقرر مقفل', style: TextStyle(color: Colors.white54, fontSize: 11)),
                ])),
              )),
            ]),
          ),
        );
      },
    );
  }
}

class _PaginatedTrainingCoursesGrid extends StatefulWidget {
  final String selectedCategory;
  final String selectedSubCategory;
  final String userName;
  final String userUid;
  final bool isAdmin;
  final List<String> adminPerms;
  final Function(Map<String, dynamic>) onActivationTap;

  const _PaginatedTrainingCoursesGrid({
    required this.selectedCategory,
    required this.selectedSubCategory,
    required this.userName,
    required this.userUid,
    required this.isAdmin,
    required this.adminPerms,
    required this.onActivationTap,
  });

  @override
  State<_PaginatedTrainingCoursesGrid> createState() => _PaginatedTrainingCoursesGridState();
}

class _PaginatedTrainingCoursesGridState extends State<_PaginatedTrainingCoursesGrid> {
  final List<Map<String, dynamic>> _items = [];
  DocumentSnapshot? _lastDoc;
  bool _isLoading = false;
  bool _hasMore = true;
  String? _loadError;
  final int _pageSize = 20;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _loadMore();
  }

  @override
  void didUpdateWidget(covariant _PaginatedTrainingCoursesGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedCategory != widget.selectedCategory || oldWidget.selectedSubCategory != widget.selectedSubCategory) {
      _generation++;
      _items.clear();
      _lastDoc = null;
      _hasMore = true;
      _loadError = null;
      _isLoading = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _loadMore();
      });
    }
  }

  Future<void> _loadMore() async {
    if (_isLoading || !_hasMore || !mounted) return;
    final generation = _generation;
    setState(() { _isLoading = true; _loadError = null; });
    try {
      final initialItemCount = _items.length;
      while (mounted && _hasMore && _items.length == initialItemCount) {
        Query query = FirebaseFirestore.instance
            .collection('training_courses')
            .where('category', isEqualTo: widget.selectedCategory)
            .limit(_pageSize);
        if (_lastDoc != null) query = query.startAfterDocument(_lastDoc!);
        final snap = await query.get();
        if (!mounted || generation != _generation) return;
        final docs = snap.docs;
        if (docs.isEmpty) { _hasMore = false; break; }

        final pageItems = docs.map((doc) {
          final data = Map<String, dynamic>.from(doc.data() as Map<String, dynamic>);
          data['id'] = doc.id;
          return data;
        }).where((course) {
          if (widget.selectedSubCategory == 'عام') return true;
          return (course['subCategory'] ?? '').toString().trim() ==
              widget.selectedSubCategory.trim();
        }).toList();
        final existingIds = _items.map((item) => item['id']).toSet();
        _items.addAll(pageItems.where((item) => !existingIds.contains(item['id'])));
        _lastDoc = docs.last;
        _hasMore = docs.length == _pageSize;
        if (_items.isNotEmpty || !_hasMore) break;
      }
    } catch (e, st) {
      debugPrint('Load training courses error: $e\n$st');
      if (mounted && generation == _generation) _loadError = e.toString();
    } finally {
      if (mounted && generation == _generation) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_items.isEmpty) {
      if (_isLoading) return const Center(child: CircularProgressIndicator(color: Color(0xFFE52521)));
      if (_loadError != null) {
        return Center(child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.cloud_off, color: Colors.orangeAccent, size: 38),
            const SizedBox(height: 10),
            const Text('تعذر جلب الدورات التدريبية. تحقق من الاتصال والصلاحيات ثم أعد المحاولة.',
                textAlign: TextAlign.center, style: TextStyle(color: Colors.white70)),
            const SizedBox(height: 10),
            ElevatedButton.icon(onPressed: _loadMore, icon: const Icon(Icons.refresh), label: const Text('إعادة المحاولة')),
          ]),
        ));
      }
      return const Center(child: Text('لا توجد دورات تدريبية منشورة لهذا التخصص حالياً.',
          style: TextStyle(color: Colors.grey)));
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 0.78,
      ),
      itemCount: _items.length + (_hasMore || _loadError != null ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _items.length) {
          return Center(child: _isLoading
              ? const CircularProgressIndicator(color: Color(0xFFE52521))
              : _loadError != null
                  ? TextButton.icon(onPressed: _loadMore, icon: const Icon(Icons.refresh), label: const Text('فشل التحميل — أعد المحاولة'))
                  : _hasMore
                      ? ElevatedButton.icon(onPressed: _loadMore,
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE52521)),
                          icon: const Icon(Icons.download_rounded, color: Colors.white),
                          label: const Text('تحميل المزيد', style: TextStyle(color: Colors.white)))
                      : const Text('لا توجد عناصر إضافية', style: TextStyle(color: Colors.grey)));
        }

        final course = _items[index];
        final unlockedMap = course['unlockedUsers'] as Map?;
        final userUnlockInfo = unlockedMap?[widget.userUid] ?? unlockedMap?[widget.userName];
        final isUnlocked = isSubscriptionActive(userUnlockInfo);
        final imageUrl = (course['imageUrl'] ?? '').toString();
        return GestureDetector(
          onTap: () {
            if (isUnlocked) {
              Navigator.push(context, MaterialPageRoute(builder: (_) => CoursePlayerScreen(
                course: course, isAdmin: widget.isAdmin, userUid: widget.userUid,
                adminPerms: widget.adminPerms, collection: 'training_courses',
              )));
            } else {
              widget.onActivationTap(course);
            }
          },
          child: Container(
            decoration: BoxDecoration(color: const Color(0xFF14141C), borderRadius: BorderRadius.circular(20),
                border: Border.all(color: isUnlocked ? Colors.green : const Color(0xFFE52521), width: 1.5)),
            padding: const EdgeInsets.all(10),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              if (imageUrl.isNotEmpty)
                ClipRRect(borderRadius: BorderRadius.circular(12), child: CachedNetworkImage(
                  imageUrl: imageUrl, height: 65, width: double.infinity, fit: BoxFit.cover,
                  errorWidget: (_, __, ___) => Icon(isUnlocked ? Icons.lock_open_rounded : Icons.lock_rounded,
                      color: isUnlocked ? Colors.green : const Color(0xFFE52521), size: 30),
                ))
              else Icon(isUnlocked ? Icons.lock_open_rounded : Icons.lock_rounded,
                  color: isUnlocked ? Colors.green : const Color(0xFFE52521), size: 30),
              const SizedBox(height: 8),
              Text(course['title']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.white),
                  textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 4),
              Text(isUnlocked ? 'مفعلة (صالح 4 أشهر) ✅' : (course['price'] ?? '${course['priceNum'] ?? 25000} ل.س').toString(),
                  style: TextStyle(color: isUnlocked ? Colors.green : Colors.grey, fontSize: 10, fontWeight: FontWeight.bold)),
            ]),
          ),
        );
      },
    );
  }
}

class AdminDashboard extends StatefulWidget {
  final String adminName;
  final List<String> adminPerms;

  const AdminDashboard({super.key, required this.adminName, required this.adminPerms});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  int _selectedTab = 0;

  final _titleController = TextEditingController();
  final _priceController = TextEditingController();
  String _productCurrency = 'ل.س';
  final _descController = TextEditingController();
  String _productImageUrl = '';
  bool _isUploadingProductImage = false;
  final _discountController = TextEditingController();
  String selectedCat = 'عمارة';

  final _bundleTitleController = TextEditingController();
  final _bundlePriceController = TextEditingController();
  String _bundleCurrency = 'ل.س';
  final _bundleDescController = TextEditingController();
  String _bundleImageUrl = '';
  bool _isUploadingBundleImage = false;
  final _bundleDiscountController = TextEditingController();
  String selectedBundleCat = 'عمارة';

  final _adUrlController = TextEditingController();
  bool _isAdVideo = false;
  bool _isAdActive = true;
  bool _isUploadingAdVideo = false;

final _courseTitleController = TextEditingController();
  final _coursePriceController = TextEditingController();
  final _courseCodesCountController = TextEditingController(text: '50');
  String _courseCurrency = 'ل.س';
  String _courseImageUrl = '';
  String _coursePdfUrl = '';
  String selectedUniForCourse = globalUniversities.first;
  String selectedCollegeForCourse = 'هندسة معلوماتية';

  List<Map<String, dynamic>> lectureControllers = [
    {
      'title': TextEditingController(text: 'المحاضرة الأولى'),
      'url': TextEditingController(),
      'pdf': '',
      'questionBank': '',
      'isUploadingPdf': false,
      'isUploadingQB': false,
    }
  ];

  // متحكمات قسم الدورات التدريبية لسوق العمل (بنفس نظام المواد الجامعية تماماً)
  final _trainingCourseTitleController = TextEditingController();
  final _trainingCoursePriceController = TextEditingController();
  final _trainingCourseCodesCountController = TextEditingController(text: '50');
  String _trainingCourseCurrency = 'ل.س';
  String _trainingCourseImageUrl = '';
  String _trainingCoursePdfUrl = '';
  bool _isUploadingTrainingCourseImage = false;
  String _selectedTrainingCategory = '';
  String _selectedTrainingSubCategory = '';
  List<Map<String, dynamic>> _trainingLectureControllers = [
    {
      'title': TextEditingController(text: 'المحاضرة الأولى'),
      'url': TextEditingController(),
      'pdf': '',
      'questionBank': '',
      'isUploadingPdf': false,
      'isUploadingQB': false,
    }
  ];


  List<String> trainingCategories = [];
  Map<String, List<String>> trainingSubCategories = {};

  final TextEditingController _customCodeController = TextEditingController();
  final TextEditingController _customTrainingCodeController = TextEditingController();
  final TextEditingController _salesSearchController = TextEditingController();
  String salesSearchQuery = '';
  String salesDateFilter = 'الكل';
  final Set<String> _selectedSalesIds = {};

  final TextEditingController _whatsappController = TextEditingController(text: '963967834966');
  final TextEditingController _notifTitleController = TextEditingController();
  final TextEditingController _notifBodyController = TextEditingController();
  String _notifTargetSection = 'الجميع (كل الطلاب)';

  String statsFilterUni = 'الكل';
  String statsFilterCollege = 'الكل';

  bool permStore = true;
  bool permBundles = true;
  bool permCourses = true;
  bool permCodes = true;
  bool permSales = true;
  bool permStats = true;
  bool permSubAdmins = true;
  bool permAds = true;
  bool permWhatsapp = true;
  bool permNotif = true;
  bool permTrainingCourses = true;
  bool permTrainingCodes = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _loadActiveAdBanner();
    _loadTrainingCategories();
    if (!widget.adminPerms.contains('all') && widget.adminPerms.isNotEmpty) {
      for (int i = 0; i < 12; i++) {
        if (_hasPermissionForTab(i)) {
          _selectedTab = i;
          break;
        }
      }
    }
  }

  Future<void> _loadTrainingCategories() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('training_categories')
          .orderBy('name')
          .limit(100)
          .get();
      final cats = <String>[];
      final subsMap = <String, List<String>>{};
      for (var doc in snap.docs) {
        final data = doc.data();
        final name = (data['name'] ?? '').toString();
        if (name.isNotEmpty) {
          cats.add(name);
          subsMap[name] = List<String>.from(data['subCategories'] ?? []);
        }
      }
      setState(() {
        trainingCategories = cats;
        trainingSubCategories = subsMap;
        if (trainingCategories.isNotEmpty &&
            (_selectedTrainingCategory.isEmpty ||
                !trainingCategories.contains(_selectedTrainingCategory))) {
          _selectedTrainingCategory = trainingCategories.first;
          final subs = trainingSubCategories[_selectedTrainingCategory] ?? [];
          _selectedTrainingSubCategory = subs.isNotEmpty ? subs.first : '';
        }
      });
    } catch (e) {
      debugPrint('Error loading training categories: $e');
    }
  }

  static const int _supabaseFreeMaxFileBytes = 50 * 1000 * 1000;

  void _showSupabaseFileLimitMessage() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('حجم الملف يتجاوز حد الرفع المجاني في Supabase (50 MB).'),
      ),
    );
  }

  bool _hasPermissionForTab(int tabIndex) {
    if (widget.adminPerms.contains('all')) return true;
    switch (tabIndex) {
      case 0:
        return widget.adminPerms.contains('store');
      case 1:
        return widget.adminPerms.contains('bundles');
      case 2:
        return widget.adminPerms.contains('courses');
      case 3:
        return widget.adminPerms.contains('codes');
      case 4:
        return widget.adminPerms.contains('sales');
      case 5:
        return widget.adminPerms.contains('stats');
      case 6:
        return widget.adminPerms.contains('subAdmins');
      case 7:
        return widget.adminPerms.contains('ads');
      case 8:
        return widget.adminPerms.contains('whatsapp');
      case 9:
        return widget.adminPerms.contains('notif');
      case 10:
        return widget.adminPerms.contains('trainingCourses');
      case 11:
        return widget.adminPerms.contains('trainingCodes');
      default:
        return false;
    }
  }

  void _loadSettings() async {
    DocumentSnapshot doc =
        await FirebaseFirestore.instance.collection('settings').doc('app_config').get();
    if (doc.exists && doc.data() != null) {
      var data = doc.data() as Map<String, dynamic>;
      if (data['whatsapp'] != null) {
        setState(() {
          _whatsappController.text = data['whatsapp'];
        });
      }
    }
  }

  void _loadActiveAdBanner() async {
    DocumentSnapshot doc =
        await FirebaseFirestore.instance.collection('ads').doc('main_banner').get();
    if (doc.exists && doc.data() != null) {
      var data = doc.data() as Map<String, dynamic>;
      if (data['url'] != null) {
        setState(() {
          _adUrlController.text = data['url'];
          _isAdVideo = data['isVideo'] ?? false;
          _isAdActive = data['isActive'] ?? true;
        });
      }
    }
  }

  /// رفع صورة موحد إلى بكيت "images" في Supabase Storage
  /// يدعم المنتجات، الباكيجات، والدورات التدريبية عبر معامل folder
  Future<String?> _uploadImageToSupabase({
    required String folder,
    required void Function(bool) setLoading,
  }) async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 50,
      );
      if (image == null) return null;

      final imageSize = await image.length();
      if (imageSize > _supabaseFreeMaxFileBytes) {
        _showSupabaseFileLimitMessage();
        return null;
      }

      setLoading(true);

      // رفع إلى بكيت "images" في Supabase Storage.
      String fileName = '$folder/${DateTime.now().millisecondsSinceEpoch}.jpg';
      final bytes = await image.readAsBytes();
      if (bytes.lengthInBytes > _supabaseFreeMaxFileBytes) {
        setLoading(false);
        _showSupabaseFileLimitMessage();
        return null;
      }

      await Supabase.instance.client.storage.from('images').uploadBinary(fileName, bytes);
      String downloadUrl = Supabase.instance.client.storage.from('images').getPublicUrl(fileName);

      if (!mounted) return null;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم رفع الصورة بنجاح وتخزينها! ✅')),
      );

      return downloadUrl;
    } catch (e) {
      setLoading(false);
      if (!mounted) return null;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'فشل رفع الصورة: تأكد من اتصال الإنترنت أو حجم الملف أو صيغته ($e)',
          ),
        ),
      );
      return null;
    }
  }

  Future<void> _pickAndUploadAdVideo() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? video = await picker.pickVideo(source: ImageSource.gallery);
      if (video == null) return;

      final videoSize = await video.length();
      if (videoSize > _supabaseFreeMaxFileBytes) {
        _showSupabaseFileLimitMessage();
        return;
      }

      setState(() {
        _isUploadingAdVideo = true;
      });

      String fileName = 'ads/${DateTime.now().millisecondsSinceEpoch}.mp4';
      final bytes = await video.readAsBytes();
      if (bytes.lengthInBytes > _supabaseFreeMaxFileBytes) {
        if (mounted) {
          setState(() => _isUploadingAdVideo = false);
          _showSupabaseFileLimitMessage();
        }
        return;
      }
      // رفع فيديو الإعلان إلى بكيت "images" في Supabase Storage.
      await Supabase.instance.client.storage.from('images').uploadBinary(fileName, bytes);
      String downloadUrl = Supabase.instance.client.storage.from('images').getPublicUrl(fileName);

      if (!mounted) return;
      setState(() {
        _adUrlController.text = downloadUrl;
        _isAdVideo = true;
        _isUploadingAdVideo = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم رفع فيديو الإعلان بنجاح وتخزينه! 🎬')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isUploadingAdVideo = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('فشل رفع الفيديو: $e')),
      );
    }
  }

  Future<String?> _pickAndUploadPdf(String folder) async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );
      if (result == null ||
          (result.files.single.path == null && result.files.single.bytes == null)) {
        return null;
      }
      if (result.files.single.size > _supabaseFreeMaxFileBytes) {
        _showSupabaseFileLimitMessage();
        return null;
      }

      String fileName = '$folder/${DateTime.now().millisecondsSinceEpoch}.pdf';
      Uint8List bytes;
      if (result.files.single.bytes != null) {
        bytes = result.files.single.bytes!;
      } else {
        bytes = await File(result.files.single.path!).readAsBytes();
      }

      if (bytes.lengthInBytes > _supabaseFreeMaxFileBytes) {
        _showSupabaseFileLimitMessage();
        return null;
      }

      // رفع إلى Supabase Storage (مثل الصور)
      await Supabase.instance.client.storage.from('pdfs').uploadBinary(fileName, bytes);
      String downloadUrl = Supabase.instance.client.storage.from('pdfs').getPublicUrl(fileName);
      return downloadUrl;
    } catch (e) {
      debugPrint('PDF Upload error: $e');
      return null;
    }
  }

  void _saveWhatsAppSettings() async {
    await FirebaseFirestore.instance.collection('settings').doc('app_config').set({
      'whatsapp': _whatsappController.text.trim(),
    }, SetOptions(merge: true));
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('تم تحديث رقم الواتساب بنجاح! 📱')));
  }

  void _saveAdBanner() async {
    String url = _adUrlController.text.trim();
    if (url.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('الرجاء إدخال رابط أو رفع فيديو الإعلان')));
      return;
    }
    await FirebaseFirestore.instance.collection('ads').doc('main_banner').set({
      'url': url,
      'isVideo': _isAdVideo,
      'isActive': _isAdActive,
    });
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('تم نشر وتحديث الإعلان في المتجر بنجاح! 📢')));
  }

  void _deleteAdBanner() async {
    await FirebaseFirestore.instance.collection('ads').doc('main_banner').delete();
    _adUrlController.clear();
    setState(() {
      _isAdActive = false;
      _isAdVideo = false;
    });
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('تم حذف الإعلان نهائياً')));
  }

  void _sendFcmBroadcast() async {
    String title = _notifTitleController.text.trim();
    String body = _notifBodyController.text.trim();

    if (title.isEmpty || body.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('الرجاء إدخال عنوان ونص الإشعار')));
      return;
    }

    try {
      await FirebaseFirestore.instance.collection('broadcast_notifications').add({
        'title': title,
        'message': body,
        'targetSection': _notifTargetSection,
        'sentBy': widget.adminName,
        'timestamp': FieldValue.serverTimestamp(),
      });

      addAppNotification(
        targetUserName: '',
        title: title,
        message: '[$_notifTargetSection] $body',
        icon: Icons.campaign_rounded,
        iconColor: const Color(0xFFE52521),
      );

      _notifTitleController.clear();
      _notifBodyController.clear();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تم إرسال الإشعار بنجاح إلى ($_notifTargetSection)! 🚀'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('حدث خطأ أثناء إرسال الإشعار: $e')),
      );
    }
  }

  void _saveProduct() async {
    if (_titleController.text.isEmpty || _priceController.text.isEmpty) return;
    int priceNum = int.tryParse(_priceController.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
    String formattedPrice = '$priceNum $_productCurrency';

    await FirebaseFirestore.instance.collection('products').add({
      'title': _titleController.text.trim(),
      'price': formattedPrice,
      'priceNum': priceNum,
      'currency': _productCurrency,
      'category': selectedCat,
      'discountBadge': _discountController.text.trim(),
      'image': _productImageUrl.isNotEmpty
          ? _productImageUrl
          : 'https://images.unsplash.com/photo-1581291518633-83b4ebd1d83e?w=400',
      'description': _descController.text.trim(),
    });

    await FirebaseFirestore.instance.collection('broadcast_notifications').add({
      'title': 'تم نشر منتج جديد في المتجر 🛒',
      'message': 'تمت إضافة (${_titleController.text.trim()}) إلى قسم ($selectedCat). تصفحه الآن!',
      'targetSection': 'المتجر',
      'timestamp': FieldValue.serverTimestamp(),
    });

    addAppNotification(
      targetUserName: '',
      title: 'تم نشر منتج جديد في المتجر 🛒',
      message: 'تمت إضافة (${_titleController.text.trim()}) إلى قسم ($selectedCat). تصفحه الآن!',
      icon: Icons.shopping_bag_rounded,
      iconColor: const Color(0xFFE52521),
    );

    _titleController.clear();
    _priceController.clear();
    _discountController.clear();
    _descController.clear();
    _productImageUrl = '';
    setState(() {});
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('تمت إضافة المنتج ونشر الإشعار بنجاح')));
  }

  void _saveBundle() async {
    if (_bundleTitleController.text.isEmpty || _bundlePriceController.text.isEmpty) return;
    int priceNum =
        int.tryParse(_bundlePriceController.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
    String formattedPrice = '$priceNum $_bundleCurrency';

    await FirebaseFirestore.instance.collection('bundles').add({
      'title': _bundleTitleController.text.trim(),
      'price': formattedPrice,
      'priceNum': priceNum,
      'currency': _bundleCurrency,
      'category': selectedBundleCat,
      'discountBadge': _bundleDiscountController.text.trim(),
      'image': _bundleImageUrl.isNotEmpty
          ? _bundleImageUrl
          : 'https://images.unsplash.com/photo-1513364776144-60967b0f800f?w=400',
      'description': _bundleDescController.text.trim(),
      'isBundle': true,
    });

    await FirebaseFirestore.instance.collection('broadcast_notifications').add({
      'title': 'عرض أو باكدج جديد في المتجر 🎁',
      'message': 'تم إطلاق عرض مميز (${_bundleTitleController.text.trim()}). تفقده في قسم العروض!',
      'targetSection': 'المتجر - العروض',
      'timestamp': FieldValue.serverTimestamp(),
    });

    addAppNotification(
      targetUserName: '',
      title: 'عرض أو باكدج جديد في المتجر 🎁',
      message: 'تم إطلاق عرض مميز (${_bundleTitleController.text.trim()}). تفقده في قسم العروض!',
      icon: Icons.local_offer_rounded,
      iconColor: const Color(0xFFE52521),
    );

    _bundleTitleController.clear();
    _bundlePriceController.clear();
    _bundleDiscountController.clear();
    _bundleDescController.clear();
    _bundleImageUrl = '';
    setState(() {});
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('تم نشر العرض/الباكدج بنجاح!')));
  }

  void _saveCourse() async {
    if (_courseTitleController.text.isEmpty) return;

    var lecturesList = <Map<String, dynamic>>[];
    for (var lec in lectureControllers) {
      String title = (lec['title'] as TextEditingController).text.trim();
      String url = (lec['url'] as TextEditingController).text.trim();
      String pdf = lec['pdf'] as String;
      String qb = lec['questionBank'] as String;
      if (url.isNotEmpty) {
        String extractedVideoId = extractYoutubeVideoId(url);
        lecturesList.add({
          'title': title.isNotEmpty ? title : 'محاضرة',
          'videoId': extractedVideoId,
          'url': url,
          'pdfUrl': pdf,
          'questionBankUrl': qb,
        });
      }
    }

    if (lecturesList.isEmpty) {
      lecturesList.add({
        'title': 'المحاضرة الأولى',
        'videoId': '',
        'url': '',
        'pdfUrl': '',
        'questionBankUrl': ''
      });
    }

    int priceNum = int.tryParse(_coursePriceController.text) ?? 25000;
    String formattedPrice = '$priceNum $_courseCurrency';

    // قراءة عدد الأكواد من حقل الإدخال (افتراضي 50)
    int codesCount = int.tryParse(_courseCodesCountController.text) ?? 50;
    codesCount = codesCount.clamp(1, 1000); // حد أدنى 1، حد أقصى 1000 لتخفيف استهلاك حصة الكتابة المجانية

    // 1. إنشاء مستند الكورس أولاً للحصول على الـ ID
    final courseRef = FirebaseFirestore.instance.collection('courses').doc();
    final courseId = courseRef.id;

    // 2. توليد الأكواد وحفظهم في مجموعة course_codes باستخدام WriteBatch مقسم
    // Firestore يحد الدفعة الواحدة بـ 500 عملية، لذا نقسمها إلى دفعات
    const int batchSize = 500;
    final generatedCodes = <String>{};
    for (int batchStart = 0; batchStart < codesCount; batchStart += batchSize) {
      int batchEnd = (batchStart + batchSize).clamp(0, codesCount);
      WriteBatch batch = FirebaseFirestore.instance.batch();
      for (int i = batchStart; i < batchEnd; i++) {
        String code;
        do {
          code = (100000 + Random().nextInt(900000)).toString();
        } while (!generatedCodes.add(code));
        final codeData = {
          'code': code,
          'courseId': courseId,
          'isUsed': false,
          'isDisabled': false,
          'usedBy': null,
          'userUid': null,
          'usedAt': null,
          'durationDays': 120,
        };
        batch.set(FirebaseFirestore.instance.collection('course_codes').doc(code), codeData);
      }
      await batch.commit();
    }

    // 3. حفظ الكورس مع عدد الأكواد فقط (لا نخزن المصفوفة الضخمة في المستند)
    await courseRef.set({
      'title': _courseTitleController.text.trim(),
      'university': selectedUniForCourse,
      'college': selectedCollegeForCourse,
      'priceNum': priceNum,
      'currency': _courseCurrency,
      'price': formattedPrice,
      'pdfUrl': _coursePdfUrl,
      'lectures': lecturesList,
      'codesCount': codesCount,
      'codes': [], // مصفوفة فارغة لتقليل حجم المستند
    });

    await FirebaseFirestore.instance.collection('broadcast_notifications').add({
      'title': 'تم نشر كورس جامعي جديد 🎓',
      'message':
          'تم إضافة كورس (${_courseTitleController.text.trim()}) في تخصص ($selectedCollegeForCourse) لجامعة ($selectedUniForCourse).',
      'targetSection': 'الكورسات والمواد الجامعية',
      'timestamp': FieldValue.serverTimestamp(),
    });

    addAppNotification(
      targetUserName: '',
      title: 'تم نشر كورس جامعي جديد 🎓',
      message:
          'تم إضافة كورس (${_courseTitleController.text.trim()}) في تخصص ($selectedCollegeForCourse) لجامعة ($selectedUniForCourse).',
      icon: Icons.school_rounded,
      iconColor: const Color(0xFFE52521),
    );

    _courseTitleController.clear();
    _coursePriceController.clear();
    _coursePdfUrl = '';
    setState(() {
      lectureControllers = [
        {
          'title': TextEditingController(text: 'المحاضرة الأولى'),
          'url': TextEditingController(),
          'pdf': '',
          'questionBank': '',
          'isUploadingPdf': false,
          'isUploadingQB': false,
        }
      ];
    });
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تم نشر المقرر، توليد $codesCount كود تفعيل في course_codes، وإرسال الإشعار بنجاح!')));
  }

  void _showManageUniversitiesDialog() {
    final newUniController = TextEditingController();
    final newCatController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF14141C),
              title: const Text('إدارة الجامعات والكليات وأقسام المتجر',
                  style: TextStyle(color: Color(0xFFE52521), fontWeight: FontWeight.bold)),
              content: SizedBox(
                width: 450,
                height: 450,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('إدارة الجامعات والتخصصات:',
                          style:
                              TextStyle(color: Color(0xFFE52521), fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: newUniController,
                              decoration:
                                  const InputDecoration(hintText: 'اسم جامعة جديدة...', filled: true),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: () {
                              if (newUniController.text.trim().isNotEmpty) {
                                setState(() {
                                  globalUniversities.add(newUniController.text.trim());
                                  universityColleges[newUniController.text.trim()] = [
                                    'هندسة معلوماتية',
                                    'هندسة مدنية'
                                  ];
                                });
                                newUniController.clear();
                                setDialogState(() {});
                              }
                            },
                            child: const Text('إضافة'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      ...globalUniversities.map((uni) => ExpansionTile(
                            title: Text(uni,
                                style: const TextStyle(
                                    color: Colors.white, fontWeight: FontWeight.bold)),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete, color: Colors.redAccent),
                              onPressed: () {
                                setState(() {
                                  globalUniversities.remove(uni);
                                  universityColleges.remove(uni);
                                });
                                setDialogState(() {});
                              },
                            ),
                            children: [
                              ...(universityColleges[uni] ?? []).map((college) => ListTile(
                                    title: Text(college,
                                        style: const TextStyle(color: Colors.white70)),
                                  )),
                            ],
                          )),
                      const Divider(color: Colors.white24, height: 30),
                      const Text('إدارة أقسام المتجر:',
                          style:
                              TextStyle(color: Color(0xFFE52521), fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: newCatController,
                              decoration: const InputDecoration(
                                  hintText: 'اسم قسم جديد للمتجر...', filled: true),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: () {
                              if (newCatController.text.trim().isNotEmpty) {
                                setState(() {
                                  globalCategories.add(newCatController.text.trim());
                                  categoryIcons[newCatController.text.trim()] =
                                      Icons.folder_rounded;
                                });
                                newCatController.clear();
                                setDialogState(() {});
                              }
                            },
                            child: const Text('إضافة'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8.0,
                        children: globalCategories
                            .where((c) => c != 'الكل' && c != 'العروض')
                            .map((cat) => Chip(
                                  label: Text(cat),
                                  deleteIcon: const Icon(Icons.close, size: 16),
                                  onDeleted: () {
                                    setState(() {
                                      globalCategories.remove(cat);
                                    });
                                    setDialogState(() {});
                                  },
                                ))
                            .toList(),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('إغلاق')),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('لوحة تحكم الأدمن'),
      ),
      drawer: Drawer(
        backgroundColor: const Color(0xFF14141C),
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(
                gradient: LinearGradient(colors: [Color(0xFFE52521), Color(0xFF14141C)]),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  ClipOval(
                    child: Image.asset(
                      'assets/icon/icon.jpg',
                      width: 50,
                      height: 50,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          const Icon(Icons.admin_panel_settings, size: 50, color: Colors.white),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(widget.adminName,
                      style: const TextStyle(
                          color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  const Text('أقسام لوحة الأدمن',
                      style: TextStyle(color: Colors.white70, fontSize: 12)),
                ],
              ),
            ),
            if (_hasPermissionForTab(0))
              ListTile(
                leading: const Icon(Icons.storefront, color: Color(0xFFE52521)),
                title: const Text('إدارة المتجر', style: TextStyle(color: Colors.white)),
                selected: _selectedTab == 0,
                onTap: () {
                  setState(() => _selectedTab = 0);
                  Navigator.pop(context);
                },
              ),
            if (_hasPermissionForTab(1))
              ListTile(
                leading: const Icon(Icons.local_offer, color: Color(0xFFE52521)),
                title: const Text('العروض والباكدجات 🎁', style: TextStyle(color: Colors.white)),
                selected: _selectedTab == 1,
                onTap: () {
                  setState(() => _selectedTab = 1);
                  Navigator.pop(context);
                },
              ),
            if (_hasPermissionForTab(2))
              ListTile(
                leading: const Icon(Icons.school, color: Color(0xFFE52521)),
                title: const Text('الكورسات والمواد الجامعية',
                    style: TextStyle(color: Colors.white)),
                selected: _selectedTab == 2,
                onTap: () {
                  setState(() => _selectedTab = 2);
                  Navigator.pop(context);
                },
              ),
            if (_hasPermissionForTab(3))
              ListTile(
                leading: const Icon(Icons.vpn_key, color: Color(0xFFE52521)),
                title: const Text('أكواد المواد الجامعية وإدارتها',
                    style: TextStyle(color: Colors.white)),
                selected: _selectedTab == 3,
                onTap: () {
                  setState(() => _selectedTab = 3);
                  Navigator.pop(context);
                },
              ),
            if (_hasPermissionForTab(10))
              ListTile(
                leading: const Icon(Icons.work_outline, color: Color(0xFFE52521)),
                title: const Text('الدورات التدريبية لسوق العمل 🎓',
                    style: TextStyle(color: Colors.white)),
                selected: _selectedTab == 10,
                onTap: () {
                  setState(() => _selectedTab = 10);
                  Navigator.pop(context);
                },
              ),
            if (_hasPermissionForTab(11))
              ListTile(
                leading: const Icon(Icons.vpn_key_outlined, color: Color(0xFFE52521)),
                title: const Text('أكواد الدورات التدريبية وإدارتها',
                    style: TextStyle(color: Colors.white)),
                selected: _selectedTab == 11,
                onTap: () {
                  setState(() => _selectedTab = 11);
                  Navigator.pop(context);
                },
              ),
            if (_hasPermissionForTab(4))
              ListTile(
                leading: const Icon(Icons.analytics, color: Color(0xFFE52521)),
                title: const Text('سجل المبيعات والتاريخ', style: TextStyle(color: Colors.white)),
                selected: _selectedTab == 4,
                onTap: () {
                  setState(() => _selectedTab = 4);
                  Navigator.pop(context);
                },
              ),
            if (_hasPermissionForTab(5))
              ListTile(
                leading: const Icon(Icons.bar_chart_rounded, color: Color(0xFFE52521)),
                title: const Text('إحصاءات المواد والجامعات 📊',
                    style: TextStyle(color: Colors.white)),
                selected: _selectedTab == 5,
                onTap: () {
                  setState(() => _selectedTab = 5);
                  Navigator.pop(context);
                },
              ),
            if (_hasPermissionForTab(6))
              ListTile(
                leading: const Icon(Icons.admin_panel_settings, color: Color(0xFFE52521)),
                title: const Text('إدارة المشرفين 👥', style: TextStyle(color: Colors.white)),
                selected: _selectedTab == 6,
                onTap: () {
                  setState(() => _selectedTab = 6);
                  Navigator.pop(context);
                },
              ),
            if (_hasPermissionForTab(7))
              ListTile(
                leading: const Icon(Icons.video_collection_rounded, color: Color(0xFFE52521)),
                title: const Text('إدارة الإعلانات 🎬', style: TextStyle(color: Colors.white)),
                selected: _selectedTab == 7,
                onTap: () {
                  setState(() => _selectedTab = 7);
                  Navigator.pop(context);
                },
              ),
            if (_hasPermissionForTab(8))
              ListTile(
                leading: const Icon(Icons.settings_phone, color: Color(0xFFE52521)),
                title: const Text('إعدادات الواتساب', style: TextStyle(color: Colors.white)),
                selected: _selectedTab == 8,
                onTap: () {
                  setState(() => _selectedTab = 8);
                  Navigator.pop(context);
                },
              ),
            if (_hasPermissionForTab(9))
              ListTile(
                leading: const Icon(Icons.campaign, color: Color(0xFFE52521)),
                title: const Text('إرسال إشعار عام 🔔', style: TextStyle(color: Colors.white)),
                selected: _selectedTab == 9,
                onTap: () {
                  setState(() => _selectedTab = 9);
                  Navigator.pop(context);
                },
              ),
          ],
        ),
      ),
      body: _getSelectedBodyTab(),
    );
  }

  Future<void> _editManagedCourse(String collection, DocumentSnapshot<Map<String, dynamic>> doc) async {
    final data = doc.data() ?? <String, dynamic>{};
    final titleController = TextEditingController(text: (data['title'] ?? '').toString());
    final priceController = TextEditingController(text: (data['price'] ?? '').toString());
    final pdfController = TextEditingController(text: (data['pdfUrl'] ?? '').toString());
    final lecturesController = TextEditingController(
      text: JsonEncoder.withIndent('  ').convert(data['lectures'] ?? <dynamic>[]),
    );
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF14141C),
        title: const Text('تعديل بيانات الكورس والمحاضرات', style: TextStyle(color: Color(0xFFE52521))),
        content: SizedBox(
          width: 650,
          child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: titleController, decoration: const InputDecoration(labelText: 'اسم الكورس', filled: true)),
            const SizedBox(height: 8),
            TextField(controller: priceController, decoration: const InputDecoration(labelText: 'السعر المعروض', filled: true)),
            const SizedBox(height: 8),
            TextField(controller: pdfController, decoration: const InputDecoration(labelText: 'رابط PDF الرئيسي / Google Drive', filled: true)),
            const SizedBox(height: 8),
            TextField(
              controller: lecturesController,
              minLines: 8,
              maxLines: 16,
              decoration: const InputDecoration(
                labelText: 'بيانات المحاضرات بصيغة JSON',
                helperText: 'يمكن تعديل title وurl أو videoId وpdfUrl وquestionBankUrl. يجب أن تبقى البيانات قائمة JSON صحيحة.',
                alignLabelWithHint: true,
                filled: true,
              ),
            ),
          ])),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () async {
              try {
                final decoded = jsonDecode(lecturesController.text);
                if (decoded is! List || decoded.any((item) => item is! Map)) {
                  throw const FormatException('يجب أن تكون بيانات المحاضرات قائمة من العناصر.');
                }
                final priceText = priceController.text.trim();
                final priceNum = int.tryParse(priceText.replaceAll(RegExp(r'[^0-9]'), ''));
                final normalizedLectures = decoded
                    .map((item) => Map<String, dynamic>.from(item as Map))
                    .toList();
                for (final lecture in normalizedLectures) {
                  final enteredUrl = (lecture['url'] ?? '').toString().trim();
                  if (enteredUrl.isNotEmpty) {
                    final extractedId = extractYoutubeVideoId(enteredUrl);
                    if (RegExp(r'^[a-zA-Z0-9_-]{11}$').hasMatch(extractedId)) {
                      lecture['videoId'] = extractedId;
                    }
                  }
                }
                await FirebaseFirestore.instance.collection(collection).doc(doc.id).update({
                  'title': titleController.text.trim(),
                  'price': priceText,
                  if (priceNum != null) 'priceNum': priceNum,
                  'pdfUrl': pdfController.text.trim(),
                  'lectures': normalizedLectures,
                  'updatedAt': FieldValue.serverTimestamp(),
                });
                if (!dialogContext.mounted) return;
                Navigator.pop(dialogContext);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حفظ تعديلات الكورس بنجاح.')));
              } catch (e) {
                if (!dialogContext.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر حفظ التعديلات: $e')));
              }
            },
            child: const Text('حفظ التعديلات'),
          ),
        ],
      ),
    );
    titleController.dispose();
    priceController.dispose();
    pdfController.dispose();
    lecturesController.dispose();
  }

  Future<void> _deleteManagedCourse(String collection, String codesCollection, DocumentSnapshot<Map<String, dynamic>> doc) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF14141C),
        title: const Text('حذف الكورس نهائياً'),
        content: Text('هل تريد حذف "${doc.data()?['title'] ?? 'الكورس'}" وجميع أكواد التفعيل المرتبطة به؟ سجلات المبيعات ستبقى محفوظة.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), style: ElevatedButton.styleFrom(backgroundColor: Colors.red), child: const Text('حذف نهائي')),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      final firestore = FirebaseFirestore.instance;
      final codeDocs = await firestore.collection(codesCollection).where('courseId', isEqualTo: doc.id).get();
      for (var start = 0; start < codeDocs.docs.length; start += 400) {
        final batch = firestore.batch();
        for (final codeDoc in codeDocs.docs.skip(start).take(400)) {
          batch.delete(codeDoc.reference);
        }
        await batch.commit();
      }
      await firestore.collection(collection).doc(doc.id).delete();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حذف الكورس وأكواد التفعيل مع الإبقاء على سجل المبيعات.')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر حذف الكورس: $e')));
    }
  }

  void _showManagedCoursesDialog({required bool training}) {
    final collection = training ? 'training_courses' : 'courses';
    final codesCollection = training ? 'training_codes' : 'course_codes';
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF14141C),
        title: Text(training ? 'إدارة الدورات التدريبية' : 'إدارة المواد الجامعية',
            style: const TextStyle(color: Color(0xFFE52521))),
        content: SizedBox(
          width: 620,
          height: 520,
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance.collection(collection).limit(100).snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) return Center(child: Text('تعذر جلب الكورسات: ${snapshot.error}', style: const TextStyle(color: Colors.white70)));
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: Color(0xFFE52521)));
              final docs = snapshot.data!.docs;
              if (docs.isEmpty) return const Center(child: Text('لا توجد كورسات منشورة حالياً.', style: TextStyle(color: Colors.grey)));
              return ListView.separated(
                itemCount: docs.length,
                separatorBuilder: (_, __) => const Divider(color: Colors.white12),
                itemBuilder: (context, index) {
                  final doc = docs[index];
                  final data = doc.data();
                  return ListTile(
                    title: Text((data['title'] ?? 'بدون عنوان').toString(), style: const TextStyle(color: Colors.white)),
                    subtitle: Text('${data['price'] ?? ''} • ${data['lectures'] is List ? (data['lectures'] as List).length : 0} محاضرة', style: const TextStyle(color: Colors.white60)),
                    trailing: Wrap(spacing: 4, children: [
                      IconButton(tooltip: 'تعديل الكورس والفيديوهات وملفات PDF', icon: const Icon(Icons.edit, color: Colors.amber),
                        onPressed: () => _editManagedCourse(collection, doc)),
                      IconButton(tooltip: 'حذف الكورس وأكواد التفعيل', icon: const Icon(Icons.delete_forever, color: Colors.redAccent),
                        onPressed: () => _deleteManagedCourse(collection, codesCollection, doc)),
                    ]),
                  );
                },
              );
            },
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('إغلاق'))],
      ),
    );
  }

  Future<void> _addExternalActivationCode({required String collection, required String courseId}) async {
    final controller = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF14141C),
        title: const Text('إضافة كود تفعيل'),
        content: TextField(controller: controller, autofocus: true, decoration: const InputDecoration(labelText: 'الكود', filled: true)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, controller.text.trim()), child: const Text('إضافة')),
        ],
      ),
    );
    controller.dispose();
    if (code == null || code.isEmpty) return;
    if (code.contains('/') || code.length > 128) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الكود غير صالح: لا تستخدم / ويجب ألا يتجاوز 128 حرفاً.')),
      );
      return;
    }
    try {
      final ref = FirebaseFirestore.instance.collection(collection).doc(code);
      final existing = await ref.get();
      if (existing.exists) throw StateError('هذا الكود موجود مسبقاً.');
      await ref.set({
        'code': code, 'courseId': courseId, 'isUsed': false, 'isDisabled': false,
        'usedBy': null, 'userUid': null, 'usedAt': null, 'durationDays': 120,
        'createdAt': FieldValue.serverTimestamp(),
      });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تمت إضافة كود التفعيل.')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر إضافة الكود: $e')));
    }
  }

  Widget _buildExternalCodeManagement({required bool training}) {
    final coursesCollection = training ? 'training_courses' : 'courses';
    final codesCollection = training ? 'training_codes' : 'course_codes';
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection(coursesCollection).limit(100).snapshots(),
      builder: (context, coursesSnapshot) {
        if (coursesSnapshot.hasError) return Center(child: Text('تعذر جلب الكورسات: ${coursesSnapshot.error}', style: const TextStyle(color: Colors.white70)));
        if (!coursesSnapshot.hasData) return const Center(child: CircularProgressIndicator(color: Color(0xFFE52521)));
        final courses = coursesSnapshot.data!.docs;
        if (courses.isEmpty) return const Center(child: Text('لا توجد كورسات منشورة حالياً.', style: TextStyle(color: Colors.grey)));
        return ListView.builder(
          padding: const EdgeInsets.all(14),
          itemCount: courses.length,
          itemBuilder: (context, index) {
            final courseDoc = courses[index];
            final course = courseDoc.data();
            return Card(
              color: const Color(0xFF14141C),
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance.collection(codesCollection)
                    .where('courseId', isEqualTo: courseDoc.id).limit(1000).snapshots(),
                builder: (context, codesSnapshot) {
                  if (codesSnapshot.hasError) {
                    return ListTile(title: Text((course['title'] ?? '').toString(), style: const TextStyle(color: Colors.white)),
                      subtitle: Text('تعذر جلب الأكواد: ${codesSnapshot.error}', style: const TextStyle(color: Colors.orangeAccent)));
                  }
                  if (!codesSnapshot.hasData) {
                    return const ListTile(title: Text('جاري تحميل الأكواد...', style: TextStyle(color: Colors.white70)), trailing: CircularProgressIndicator());
                  }
                  final codeDocs = codesSnapshot.data!.docs;
                  final available = codeDocs.where((d) => d.data()['isUsed'] != true && d.data()['isDisabled'] != true).length;
                  final usedOrDisabled = codeDocs.length - available;
                  return ExpansionTile(
                    title: Text((course['title'] ?? 'بدون عنوان').toString(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    subtitle: Text('متاحة: $available • مستعملة/معطلة: $usedOrDisabled • الإجمالي: ${codeDocs.length}', style: const TextStyle(color: Colors.white60, fontSize: 12)),
                    children: [
                      Align(alignment: Alignment.centerRight, child: TextButton.icon(
                        onPressed: () => _addExternalActivationCode(collection: codesCollection, courseId: courseDoc.id),
                        icon: const Icon(Icons.add), label: const Text('إضافة كود لهذا الكورس'),
                      )),
                      if (codeDocs.isEmpty) const Padding(padding: EdgeInsets.all(12), child: Text('لا توجد أكواد مسجلة لهذا الكورس.', style: TextStyle(color: Colors.grey))),
                      ...codeDocs.map((codeDoc) {
                        final data = codeDoc.data();
                        final isUsed = data['isUsed'] == true;
                        final isDisabled = data['isDisabled'] == true;
                        final isAvailable = !isUsed && !isDisabled;
                        final label = isAvailable ? 'متاح' : (isDisabled ? 'معطل' : 'مستعمل بواسطة ${data['usedBy'] ?? 'طالب'}');
                        return ListTile(
                          dense: true,
                          title: Text((data['code'] ?? codeDoc.id).toString(), style: TextStyle(color: isAvailable ? Colors.greenAccent : Colors.orangeAccent, fontWeight: FontWeight.bold)),
                          subtitle: Text(label, style: const TextStyle(color: Colors.white60, fontSize: 11)),
                          trailing: Wrap(spacing: 2, children: [
                            IconButton(tooltip: 'نسخ الكود', icon: const Icon(Icons.copy, color: Colors.white70),
                              onPressed: () { Clipboard.setData(ClipboardData(text: (data['code'] ?? codeDoc.id).toString())); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم نسخ الكود'))); }),
                            TextButton(
                              onPressed: () async {
                                try {
                                  if (isAvailable) {
                                    await codeDoc.reference.update({'isDisabled': true, 'disabledAt': FieldValue.serverTimestamp()});
                                  } else {
                                    await codeDoc.reference.update({'isUsed': false, 'isDisabled': false, 'usedBy': null, 'userUid': null, 'usedAt': null});
                                  }
                                } catch (e) {
                                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر تحديث الكود: $e')));
                                }
                              },
                              child: Text(isAvailable ? 'تعطيل' : 'إعادة إتاحة', style: TextStyle(color: isAvailable ? Colors.redAccent : Colors.amberAccent)),
                            ),
                          ]),
                        );
                      }),
                    ],
                  );
                },
              ),
            );
          },
        );
      },
    );
  }

  Widget _getSelectedBodyTab() {
    switch (_selectedTab) {
      case 0:
        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('إضافة منتج جديد للمتجر',
                      style: TextStyle(
                          color: Color(0xFFE52521), fontSize: 18, fontWeight: FontWeight.w900)),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E1E28)),
                    onPressed: _showManageUniversitiesDialog,
                    icon: const Icon(Icons.settings, color: Color(0xFFE52521)),
                    label: const Text('إدارة الأقسام',
                        style: TextStyle(color: Colors.white, fontSize: 11)),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              TextField(
                  controller: _titleController,
                  decoration: const InputDecoration(labelText: 'اسم المنتج', filled: true)),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                      child: TextField(
                          controller: _priceController,
                          keyboardType: TextInputType.number,
                          decoration:
                              const InputDecoration(labelText: 'السعر الرقمي', filled: true))),
                  const SizedBox(width: 8),
                  DropdownButton<String>(
                    value: _productCurrency,
                    dropdownColor: const Color(0xFF14141C),
                    items: const [
                      DropdownMenuItem(
                          value: 'ل.س',
                          child: Text('ل.س', style: TextStyle(color: Colors.white))),
                      DropdownMenuItem(
                          value: '\$', child: Text('\$', style: TextStyle(color: Colors.white))),
                    ],
                    onChanged: (val) => setState(() => _productCurrency = val ?? 'ل.س'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                  controller: _discountController,
                  decoration: const InputDecoration(
                      labelText: 'نسبة الحسم (مثال: خصم 20% أو عرض محدود)', filled: true)),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: selectedCat,
                dropdownColor: const Color(0xFF14141C),
                items: globalCategories
                    .where((c) => c != 'الكل' && c != 'العروض')
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (v) => setState(() => selectedCat = v!),
                decoration: const InputDecoration(labelText: 'القسم', filled: true),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF14141C),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE52521), width: 1.5),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('صورة المنتج (من الاستوديو)',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE52521)),
                          onPressed: _isUploadingProductImage
                              ? null
                              : () async {
                                  final url = await _uploadImageToSupabase(
                                    folder: 'products',
                                    setLoading: (v) => setState(() => _isUploadingProductImage = v),
                                  );
                                  if (!mounted) return;
                                  if (url != null) {
                                    setState(() => _productImageUrl = url);
                                  }
                                },
                          icon: _isUploadingProductImage
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                      color: Colors.white, strokeWidth: 2))
                              : const Icon(Icons.photo_library_rounded, color: Colors.white),
                          label: Text(
                              _isUploadingProductImage
                                  ? 'جاري الرفع...'
                                  : 'اختر صورة من الاستوديو 🖼️',
                              style: const TextStyle(color: Colors.white)),
                        ),
                      ],
                    ),
                    if (_productImageUrl.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: CachedNetworkImage(
                            imageUrl: _productImageUrl,
                            height: 100,
                            width: 100,
                            fit: BoxFit.cover),
                      ),
                      const SizedBox(height: 4),
                      const Text('تم حفظ الصورة بنجاح للأبد ✅',
                          style: TextStyle(
                              color: Colors.green, fontSize: 11, fontWeight: FontWeight.bold)),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                  controller: _descController,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'التفاصيل', filled: true)),
              const SizedBox(height: 20),
              ElevatedButton(
                  onPressed: _saveProduct,
                  child: const Text('نشر المنتج وإرسال إشعار للطلاب')),
            ],
          ),
        );
      case 1:
        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('إضافة عرض أو باكدج جديد في المتجر',
                  style: TextStyle(
                      color: Color(0xFFE52521), fontSize: 18, fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              const Text('اختر صورة الباكدج مباشرة من استوديو هاتفك.',
                  style: TextStyle(color: Colors.grey, fontSize: 12)),
              const SizedBox(height: 14),
              TextField(
                  controller: _bundleTitleController,
                  decoration:
                      const InputDecoration(labelText: 'عنوان العرض أو الباكدج', filled: true)),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                      child: TextField(
                          controller: _bundlePriceController,
                          keyboardType: TextInputType.number,
                          decoration:
                              const InputDecoration(labelText: 'السعر الرقمي', filled: true))),
                  const SizedBox(width: 8),
                  DropdownButton<String>(
                    value: _bundleCurrency,
                    dropdownColor: const Color(0xFF14141C),
                    items: const [
                      DropdownMenuItem(
                          value: 'ل.س',
                          child: Text('ل.س', style: TextStyle(color: Colors.white))),
                      DropdownMenuItem(
                          value: '\$', child: Text('\$', style: TextStyle(color: Colors.white))),
                    ],
                    onChanged: (val) => setState(() => _bundleCurrency = val ?? 'ل.س'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                  controller: _bundleDiscountController,
                  decoration: const InputDecoration(
                      labelText: 'نسبة الحسم (مثال: حسم 30%)', filled: true)),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: selectedBundleCat,
                dropdownColor: const Color(0xFF14141C),
                items: globalCategories
                    .where((c) => c != 'الكل' && c != 'العروض')
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (v) => setState(() => selectedBundleCat = v!),
                decoration: const InputDecoration(labelText: 'القسم التابع له', filled: true),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF14141C),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE52521), width: 1.5),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('صورة الباكدج (من الاستوديو)',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE52521)),
                          onPressed: _isUploadingBundleImage
                              ? null
                              : () async {
                                  final url = await _uploadImageToSupabase(
                                    folder: 'bundles',
                                    setLoading: (v) => setState(() => _isUploadingBundleImage = v),
                                  );
                                  if (!mounted) return;
                                  if (url != null) {
                                    setState(() => _bundleImageUrl = url);
                                  }
                                },
                          icon: _isUploadingBundleImage
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                      color: Colors.white, strokeWidth: 2))
                              : const Icon(Icons.photo_library_rounded, color: Colors.white),
                          label: Text(
                              _isUploadingBundleImage
                                  ? 'جاري الرفع...'
                                  : 'اختر صورة العرض 🖼️',
                              style: const TextStyle(color: Colors.white)),
                        ),
                      ],
                    ),
                    if (_bundleImageUrl.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: CachedNetworkImage(
                            imageUrl: _bundleImageUrl,
                            height: 100,
                            width: 100,
                            fit: BoxFit.cover),
                      ),
                      const SizedBox(height: 4),
                      const Text('تم حفظ الصورة بنجاح للأبد ✅',
                          style: TextStyle(
                              color: Colors.green, fontSize: 11, fontWeight: FontWeight.bold)),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                  controller: _bundleDescController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                      labelText: 'تفاصيل العرض ومحتويات الباكدج', filled: true)),
              const SizedBox(height: 20),
              ElevatedButton(
                  onPressed: _saveBundle, child: const Text('نشر العرض/الباكدج بقمة المتجر')),
            ],
          ),
        );
      case 2:
        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Expanded(
                    child: Text('إضافة مادة جامعية وتوليد 2000 كود (فيديوهات يوتيوب غير مدرجة)',
                        style: TextStyle(
                            color: Color(0xFFE52521), fontSize: 16, fontWeight: FontWeight.w900)),
                  ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E1E28)),
                    onPressed: _showManageUniversitiesDialog,
                    icon: const Icon(Icons.settings, color: Color(0xFFE52521)),
                    label: const Text('إدارة الجامعات',
                        style: TextStyle(color: Colors.white, fontSize: 11)),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              OutlinedButton.icon(
                onPressed: () => _showManagedCoursesDialog(training: false),
                icon: const Icon(Icons.manage_search),
                label: const Text('إدارة الكورسات المنشورة: تعديل الفيديوهات وملفات PDF أو الحذف'),
              ),
              const SizedBox(height: 10),
              TextField(
                  controller: _courseTitleController,
                  decoration:
                      const InputDecoration(labelText: 'اسم المادة التعليمية', filled: true)),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: selectedUniForCourse,
                dropdownColor: const Color(0xFF14141C),
                items: globalUniversities
                    .map((u) => DropdownMenuItem(value: u, child: Text(u)))
                    .toList(),
                onChanged: (v) => setState(() {
                  selectedUniForCourse = v!;
                  var cols = universityColleges[selectedUniForCourse] ?? [];
                  if (cols.isNotEmpty) selectedCollegeForCourse = cols.first;
                }),
                decoration: const InputDecoration(labelText: 'الجامعة السورية', filled: true),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: selectedCollegeForCourse,
                dropdownColor: const Color(0xFF14141C),
                items: (universityColleges[selectedUniForCourse] ?? ['هندسة معلوماتية'])
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (v) => setState(() => selectedCollegeForCourse = v!),
                decoration: const InputDecoration(labelText: 'الكلية / التخصص', filled: true),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                      child: TextField(
                          controller: _coursePriceController,
                          keyboardType: TextInputType.number,
                          decoration:
                              const InputDecoration(labelText: 'السعر الرقمي', filled: true))),
                  const SizedBox(width: 8),
                  DropdownButton<String>(
                    value: _courseCurrency,
                    dropdownColor: const Color(0xFF14141C),
                    items: const [
                      DropdownMenuItem(
                          value: 'ل.س',
                          child: Text('ل.س', style: TextStyle(color: Colors.white))),
                      DropdownMenuItem(
                          value: '\$', child: Text('\$', style: TextStyle(color: Colors.white))),
                    ],
                    onChanged: (val) => setState(() => _courseCurrency = val ?? 'ل.س'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                      child: TextField(
                          controller: _courseCodesCountController,
                          keyboardType: TextInputType.number,
                          decoration:
                              const InputDecoration(labelText: 'عدد الأكواد المراد توليدها (افتراضي 50، الحد الأقصى 1000)', filled: true))),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Text(
                        _coursePdfUrl.isEmpty
                            ? 'لم يتم اختيار ملف PDF الرئيسي'
                            : 'تم اختيار ملف PDF الرئيسي ✅',
                        style: const TextStyle(color: Colors.white70)),
                  ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E1E28)),
                    icon: const Icon(Icons.upload_file, color: Color(0xFFE52521)),
                    label: const Text('رفع PDF للمقرر', style: TextStyle(color: Colors.white)),
                    onPressed: () async {
                      String? url = await _pickAndUploadPdf('courses_pdfs');
                      if (url != null) {
                        setState(() => _coursePdfUrl = url);
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('تم رفع ملف PDF بنجاح!')));
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Text(
                  'إدارة المحاضرات (روابط يوتيوب غير مدرجة + ملفات PDF وبنك الأسئلة)',
                  style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              ...lectureControllers.asMap().entries.map((entry) {
                int idx = entry.key;
                var lec = entry.value;
                if (lec['pdfCtrl'] == null) {
                  lec['pdfCtrl'] = TextEditingController(text: (lec['pdf'] as String? ?? ''));
                }
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                        color: const Color(0xFF14141C), borderRadius: BorderRadius.circular(16)),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                                child: TextField(
                                    controller: lec['title'] as TextEditingController,
                                    decoration: InputDecoration(
                                        labelText: 'عنوان المحاضرة ${idx + 1}', filled: true))),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 2,
                              child: TextField(
                                controller: lec['url'] as TextEditingController,
                                decoration: InputDecoration(
                                  labelText: 'رابط يوتيوب غير مدرج ${idx + 1}',
                                  filled: true,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                  (lec['pdf'] as String).isEmpty
                                      ? 'لا يوجد PDF محاضرة'
                                      : 'تم رفع PDF المحاضرة ✅',
                                  style: const TextStyle(color: Colors.grey, fontSize: 11)),
                            ),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF1E1E28)),
                              icon: const Icon(Icons.upload_file,
                                  color: Colors.redAccent, size: 16),
                              label: Text(
                                  (lec['isUploadingPdf'] == true)
                                      ? 'جاري الرفع...'
                                      : 'رفع PDF محاضرة',
                                  style: const TextStyle(fontSize: 11)),
                              onPressed: (lec['isUploadingPdf'] == true)
                                  ? null
                                  : () async {
                                      setState(() => lec['isUploadingPdf'] = true);
                                      String? url = await _pickAndUploadPdf('lectures_pdfs');
                                      setState(() {
                                        lec['isUploadingPdf'] = false;
                                        if (url != null) {
                                          lec['pdf'] = url;
                                          if (lec['pdfCtrl'] != null) {
                                            (lec['pdfCtrl'] as TextEditingController).text = url;
                                          }
                                        }
                                      });
                                      if (url != null && mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                                            content: Text('تم رفع ملف المحاضرة بنجاح!')));
                                      }
                                    },
                            ),
                            IconButton(
                              tooltip: 'حذف المحاضرة',
                              icon: const Icon(Icons.delete_forever_rounded,
                                  color: Colors.redAccent, size: 20),
                              onPressed: () {
                                setState(() => lectureControllers.removeAt(idx));
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: lec['pdfCtrl'] as TextEditingController,
                          style: const TextStyle(fontSize: 12, color: Colors.white70),
                          decoration: const InputDecoration(
                            isDense: true,
                            labelText: 'رابط PDF للمحاضرة (أو رابط Google Drive)',
                            hintText: 'الصق رابط ملف PDF أو Google Drive',
                            filled: true,
                          ),
                          onChanged: (v) => lec['pdf'] = v.trim(),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                  (lec['questionBank'] as String).isEmpty
                                      ? 'لا يوجد بنك أسئلة'
                                      : 'تم رفع بنك الأسئلة ✅',
                                  style: const TextStyle(color: Colors.grey, fontSize: 11)),
                            ),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF1E1E28)),
                              icon: const Icon(Icons.quiz, color: Colors.amberAccent, size: 16),
                              label: Text(
                                  (lec['isUploadingQB'] == true)
                                      ? 'جاري الرفع...'
                                      : 'رفع بنك الأسئلة PDF',
                                  style: const TextStyle(fontSize: 11)),
                              onPressed: (lec['isUploadingQB'] == true)
                                  ? null
                                  : () async {
                                      setState(() => lec['isUploadingQB'] = true);
                                      String? url = await _pickAndUploadPdf('question_banks');
                                      setState(() {
                                        lec['isUploadingQB'] = false;
                                        if (url != null) lec['questionBank'] = url;
                                      });
                                      if (url != null && mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                                            content: Text('تم رفع بنك الأسئلة بنجاح!')));
                                      }
                                    },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }),
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    lectureControllers.add({
                      'title': TextEditingController(
                          text: 'المحاضرة ${lectureControllers.length + 1}'),
                      'url': TextEditingController(),
                      'pdf': '',
                      'questionBank': '',
                      'isUploadingPdf': false,
                      'isUploadingQB': false,
                    });
                  });
                },
                icon: const Icon(Icons.add_rounded, color: Color(0xFFE52521)),
                label:
                    const Text('إضافة محاضرة أخرى', style: TextStyle(color: Color(0xFFE52521))),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                  onPressed: _saveCourse,
                  child: Text('نشر المقرر وتوليد $_courseCodesCountController.text كود تفعيل')),
            ],
          ),
        );
      case 3:
        return _buildExternalCodeManagement(training: false);
      case 4:
        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('sales_log')
              .orderBy('purchasedAt', descending: true)
              .limit(200)
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator(color: Color(0xFFE52521)));
            }
            var salesDocs = snapshot.data!.docs;

            var filteredSales = salesDocs.where((doc) {
              var data = doc.data() as Map<String, dynamic>;
              String name = (data['userName'] ?? '').toLowerCase();
              String uid = (data['userUid'] ?? '').toLowerCase();
              String course = (data['courseTitle'] ?? '').toLowerCase();

              bool matchQuery = salesSearchQuery.isEmpty ||
                  name.contains(salesSearchQuery) ||
                  uid.contains(salesSearchQuery) ||
                  course.contains(salesSearchQuery);

              bool matchDate = true;
              if (salesDateFilter != 'الكل' && data['purchasedAt'] != null) {
                Timestamp ts = data['purchasedAt'];
                DateTime dt = ts.toDate();
                DateTime now = DateTime.now();
                if (salesDateFilter == 'اليوم') {
                  matchDate = dt.year == now.year && dt.month == now.month && dt.day == now.day;
                } else if (salesDateFilter == 'آخر 7 أيام') {
                  matchDate = now.difference(dt).inDays <= 7;
                } else if (salesDateFilter == 'آخر 30 يوم') {
                  matchDate = now.difference(dt).inDays <= 30;
                }
              }
              return matchQuery && matchDate;
            }).toList();

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _salesSearchController,
                          decoration: InputDecoration(
                            hintText: 'ابحث عن طالب بالاسم، الأيدي أو المقرر...',
                            prefixIcon: const Icon(Icons.search, color: Color(0xFFE52521)),
                            filled: true,
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide.none),
                          ),
                          onChanged: (val) =>
                              setState(() => salesSearchQuery = val.trim().toLowerCase()),
                        ),
                      ),
                      const SizedBox(width: 8),
                      DropdownButton<String>(
                        value: salesDateFilter,
                        dropdownColor: const Color(0xFF14141C),
                        items: const [
                          DropdownMenuItem(
                              value: 'الكل',
                              child: Text('كل الأيام',
                                  style: TextStyle(color: Colors.white, fontSize: 12))),
                          DropdownMenuItem(
                              value: 'اليوم',
                              child: Text('اليوم',
                                  style: TextStyle(color: Colors.white, fontSize: 12))),
                          DropdownMenuItem(
                              value: 'آخر 7 أيام',
                              child: Text('آخر 7 أيام',
                                  style: TextStyle(color: Colors.white, fontSize: 12))),
                          DropdownMenuItem(
                              value: 'آخر 30 يوم',
                              child: Text('آخر 30 يوم',
                                  style: TextStyle(color: Colors.white, fontSize: 12))),
                        ],
                        onChanged: (val) => setState(() => salesDateFilter = val ?? 'الكل'),
                      ),
                    ],
                  ),
                ),
                if (_selectedSalesIds.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('تم تحديد ${_selectedSalesIds.length} عملية بيع',
                            style: const TextStyle(
                                color: Colors.amberAccent, fontWeight: FontWeight.bold)),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                          icon: const Icon(Icons.delete, color: Colors.white),
                          label: const Text('حذف المحدد', style: TextStyle(color: Colors.white)),
                          onPressed: () async {
                            for (String id in _selectedSalesIds) {
                              await FirebaseFirestore.instance
                                  .collection('sales_log')
                                  .doc(id)
                                  .delete();
                            }
                            setState(() {
                              _selectedSalesIds.clear();
                            });
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('تم حذف المبيعات المحددة بنجاح')));
                          },
                        ),
                      ],
                    ),
                  ),
                Expanded(
                  child: filteredSales.isEmpty
                      ? const Center(
                          child: Text('لا توجد عمليات بيع مطابقة للبحث أو الفترة',
                              style: TextStyle(color: Colors.grey)))
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: filteredSales.length,
                          itemBuilder: (context, index) {
                            var doc = filteredSales[index];
                            var sData = doc.data() as Map<String, dynamic>;
                            String docId = doc.id;
                            bool isSelected = _selectedSalesIds.contains(docId);

                            String courseTitle = sData['courseTitle'] ?? 'مقرر';
                            String university = sData['university'] ?? 'غير محدد';
                            String college = sData['college'] ?? 'غير محدد';
                            String price = (sData['price'] ?? '0').toString();
                            String userName = sData['userName'] ?? 'طالب';
                            String userUid = sData['userUid'] ?? '';
                            String codeUsed = sData['codeUsed'] ?? '';
                            Timestamp? time = sData['purchasedAt'] as Timestamp?;
                            String timeStr = time != null
                                ? '${time.toDate().year}/${time.toDate().month}/${time.toDate().day} - ${time.toDate().hour}:${time.toDate().minute.toString().padLeft(2, '0')}'
                                : 'الآن';

                            return Card(
                              color: isSelected
                                  ? const Color(0xFFE52521).withValues(alpha: 0.15)
                                  : const Color(0xFF14141C),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  side: BorderSide(
                                      color: isSelected
                                          ? const Color(0xFFE52521)
                                          : const Color(0xFF2E2E3A))),
                              margin: const EdgeInsets.symmetric(vertical: 6),
                              child: ListTile(
                                leading: Checkbox(
                                  value: isSelected,
                                  activeColor: const Color(0xFFE52521),
                                  onChanged: (val) {
                                    setState(() {
                                      if (val == true) {
                                        _selectedSalesIds.add(docId);
                                      } else {
                                        _selectedSalesIds.remove(docId);
                                      }
                                    });
                                  },
                                ),
                                title: Text('الطالب: $userName (ID: $userUid)',
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13)),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 4),
                                    Text('المادة / الدورة: $courseTitle ($university - $college)',
                                        style: const TextStyle(
                                            color: Color(0xFFE52521),
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12)),
                                    Text('السعر: $price | الكود: $codeUsed',
                                        style: const TextStyle(
                                            color: Colors.white70, fontSize: 11)),
                                    Text('التاريخ: $timeStr',
                                        style:
                                            const TextStyle(color: Colors.grey, fontSize: 11)),
                                  ],
                                ),
                                trailing: IconButton(
                                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                                  onPressed: () async {
                                    await FirebaseFirestore.instance
                                        .collection('sales_log')
                                        .doc(docId)
                                        .delete();
                                    if (!mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('تم حذف سجل البيع بنجاح')));
                                  },
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            );
          },
        );
      case 5:
        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('sales_log')
              .orderBy('purchasedAt', descending: true)
              .limit(500)
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator(color: Color(0xFFE52521)));
            }
            var salesDocs = snapshot.data!.docs;

            var filtered = salesDocs.where((doc) {
              var data = doc.data() as Map<String, dynamic>;
              bool matchUni = statsFilterUni == 'الكل' || data['university'] == statsFilterUni;
              bool matchCol =
                  statsFilterCollege == 'الكل' || data['college'] == statsFilterCollege;
              return matchUni && matchCol;
            }).toList();

            Map<String, int> courseSalesCount = {};
            double totalRevenueSyp = 0;
            double totalRevenueUsd = 0;

            for (var doc in filtered) {
              var data = doc.data() as Map<String, dynamic>;
              String cTitle = data['courseTitle'] ?? 'مقرر غير محدد';
              courseSalesCount[cTitle] = (courseSalesCount[cTitle] ?? 0) + 1;

              String priceStr = (data['price'] ?? '0').toString();
              double val =
                  double.tryParse(priceStr.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0;
              if (priceStr.contains('\$')) {
                totalRevenueUsd += val;
              } else {
                totalRevenueSyp += val;
              }
            }

            return SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('إحصاءات المبيعات والفلترة المتقدمة 📊',
                      style: TextStyle(
                          color: Color(0xFFE52521), fontSize: 18, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 4),
                  const Text('الإحصاءات محسوبة من آخر 500 عملية بيع لتقليل قراءات Firestore.',
                      style: TextStyle(color: Colors.white54, fontSize: 11)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: statsFilterUni,
                          dropdownColor: const Color(0xFF14141C),
                          items: ['الكل', ...globalUniversities]
                              .map((u) => DropdownMenuItem(
                                  value: u, child: Text(u, style: const TextStyle(fontSize: 11))))
                              .toList(),
                          onChanged: (v) => setState(() {
                            statsFilterUni = v!;
                            statsFilterCollege = 'الكل';
                          }),
                          decoration: const InputDecoration(
                              labelText: 'تصفية حسب الجامعة / المجال', filled: true),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: statsFilterCollege,
dropdownColor: const Color(0xFF14141C),
items: <String>[
  'الكل',
  if (statsFilterUni != 'الكل')
    ...(universityColleges[statsFilterUni] ?? const []).map((e) => e.toString()),
]
    .map<DropdownMenuItem<String>>(
      (c) => DropdownMenuItem<String>(
        value: c,
        child: Text(c, style: const TextStyle(fontSize: 11)),
      ),
    )
    .toList(),
onChanged: (v) => setState(() => statsFilterCollege = v!),
decoration: const InputDecoration(
    labelText: 'تصفية حسب الكلية', filled: true),
                  ),
                  ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard('إجمالي الاشتراكات', '${filtered.length} اشتراك',
                            Icons.people_alt, Colors.blue),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildStatCard(
                            'الإيرادات (ل.س)',
                            '${totalRevenueSyp.toStringAsFixed(0)} ل.س',
                            Icons.monetization_on,
                            Colors.green),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _buildStatCard(
                      'الإيرادات بالدولار (\$)',
                      '${totalRevenueUsd.toStringAsFixed(2)} \$',
                      Icons.attach_money,
                      Colors.amber),
                  const Divider(color: Colors.white24, height: 30),
                  const Text('تفصيل المبيعات لكل مادة / دورة تدريبية:',
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 10),
                  if (courseSalesCount.isEmpty)
                    const Center(
                        child: Text('لا توجد بيانات مبيعات مسجلة وفق الفلتر المختار',
                            style: TextStyle(color: Colors.grey)))
                  else
                    ...courseSalesCount.entries.map((entry) {
                      return Container(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFF14141C),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFF2E2E3A)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                                child: Text(entry.key,
                                    style: const TextStyle(
                                        color: Colors.white, fontWeight: FontWeight.bold))),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE52521).withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text('${entry.value} مبيعة 🎓',
                                  style: const TextStyle(
                                      color: Color(0xFFE52521), fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                      );
                    }),
                ],
              ),
            );
          },
        );
      case 6:
        return _buildSubAdminsTab();
      case 7:
        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('إدارة إعلانات المتجر 🎬',
                  style: TextStyle(
                      color: Color(0xFFE52521), fontSize: 18, fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              const Text(
                  'يمكنك رفع فيديو إعلاني مباشرة من استوديو هاتفك أو لصق رابط صورة أو رابط فيديو إنستغرام وسيظهر في أعلى المتجر للجميع.',
                  style: TextStyle(color: Colors.grey, fontSize: 12)),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF14141C),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE52521), width: 1.5),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Expanded(
                        child: Text('رفع فيديو إعلاني مباشر (من الاستوديو)',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE52521)),
                      onPressed: _isUploadingAdVideo ? null : _pickAndUploadAdVideo,
                      icon: _isUploadingAdVideo
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Icon(Icons.video_library_rounded, color: Colors.white),
                      label: Text(_isUploadingAdVideo ? 'جاري الرفع...' : 'رفع فيديو 🎥',
                          style: const TextStyle(color: Colors.white)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _adUrlController,
                decoration: const InputDecoration(
                    labelText: 'أو لصق رابط الإعلان (رابط صورة أو فيديو إنستغرام)', filled: true),
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                title: const Text('نوع الإعلان: فيديو (مباشر أو رابط)',
                    style: TextStyle(color: Colors.white)),
                value: _isAdVideo,
                activeThumbColor: const Color(0xFFE52521),
                onChanged: (v) => setState(() => _isAdVideo = v),
              ),
              SwitchListTile(
                title: const Text('تفعيل وعرض الإعلان في قمة المتجر للطلاب',
                    style: TextStyle(color: Colors.white)),
                value: _isAdActive,
                activeThumbColor: Colors.green,
                onChanged: (v) => setState(() => _isAdActive = v),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _saveAdBanner,
                icon: const Icon(Icons.publish_rounded, color: Colors.white),
                label: const Text('حفظ ونشر الإعلان في المتجر'),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.red)),
                onPressed: _deleteAdBanner,
                icon: const Icon(Icons.delete_forever, color: Colors.red),
                label:
                    const Text('حذف الإعلان نهائياً', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        );
      case 8:
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('إعدادات رقم واتساب استقبال الطلبات وتفعيل الكورسات 📱',
                  style: TextStyle(
                      color: Color(0xFFE52521), fontSize: 18, fontWeight: FontWeight.w900)),
              const SizedBox(height: 12),
              TextField(
                controller: _whatsappController,
                decoration: const InputDecoration(
                    labelText: 'رقم الواتساب النشط (بدون إشارة + مثل: 963967834966)',
                    filled: true),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                  onPressed: _saveWhatsAppSettings, child: const Text('حفظ وتفعيل الرقم الجديد')),
            ],
          ),
        );
      case 9:
        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('إرسال إشعار عام للطلاب والأقسام 🔔',
                  style: TextStyle(
                      color: Color(0xFFE52521), fontSize: 18, fontWeight: FontWeight.w900)),
              const SizedBox(height: 6),
              const Text(
                  'سيصل الإشعار فوراً إلى جميع الطلاب في جرس الإشعارات داخل التطبيق حسب القسم المحدد.',
                  style: TextStyle(color: Colors.grey, fontSize: 12)),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                initialValue: _notifTargetSection,
                dropdownColor: const Color(0xFF14141C),
                items: const [
                  DropdownMenuItem(
                      value: 'الجميع (كل الطلاب)',
                      child: Text('الجميع (كل الطلاب)', style: TextStyle(color: Colors.white))),
                  DropdownMenuItem(
                      value: 'المتجر',
                      child: Text('قسم المتجر', style: TextStyle(color: Colors.white))),
                  DropdownMenuItem(
                      value: 'الكورسات والمواد الجامعية',
                      child: Text('قسم الكورسات والمواد الجامعية',
                          style: TextStyle(color: Colors.white))),
                  DropdownMenuItem(
                      value: 'الدورات التدريبية لسوق العمل',
                      child: Text('قسم الدورات التدريبية لسوق العمل',
                          style: TextStyle(color: Colors.white))),
                ],
                onChanged: (val) {
                  if (val != null) setState(() => _notifTargetSection = val);
                },
                decoration: const InputDecoration(
                  labelText: 'القسم المستهدف بالإشعار',
                  filled: true,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _notifTitleController,
                decoration: const InputDecoration(
                    labelText: 'عنوان الإشعار (مثال: خصم خاص أو محاضرة جديدة)', filled: true),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _notifBodyController,
                maxLines: 3,
                decoration:
                    const InputDecoration(labelText: 'نص الإشعار بالتفصيل', filled: true),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                  onPressed: _sendFcmBroadcast,
                  icon: const Icon(Icons.send_rounded, color: Colors.white),
                  label: const Text('إرسال الإشعار الآن لجميع الطلاب 🚀')),
              const Divider(color: Colors.white24, height: 32),
              const Text('سجل الإشعارات المرسلة سابقاً:',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
              const SizedBox(height: 10),
              FutureBuilder<QuerySnapshot>(
                future: FirebaseFirestore.instance
                    .collection('broadcast_notifications')
                    .orderBy('timestamp', descending: true)
                    .limit(20)
                    .get(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(
                        child: CircularProgressIndicator(color: Color(0xFFE52521)));
                  }
                  final docs = snapshot.data!.docs;
                  if (docs.isEmpty) {
                    return const Text('لا توجد إشعارات مرسلة بعد',
                        style: TextStyle(color: Colors.grey));
                  }
                  return Column(
                    children: docs.map((doc) {
                      var data = doc.data() as Map<String, dynamic>;
                      return Card(
                        color: const Color(0xFF14141C),
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        child: ListTile(
                          leading:
                              const Icon(Icons.notifications_active, color: Color(0xFFE52521)),
                          title: Text(data['title'] ?? '',
                              style: const TextStyle(
                                  color: Colors.white, fontWeight: FontWeight.bold)),
                          subtitle: Text(
                              '${data['message'] ?? ''}\nالقسم: ${data['targetSection'] ?? 'الجميع'}',
                              style: const TextStyle(color: Colors.white70, fontSize: 12)),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                            onPressed: () async {
                              await doc.reference.delete();
                            },
                          ),
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
            ],
          ),
        );
      case 10:
        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Expanded(
                    child: Text(
                        'إضافة دورة تدريبية لسوق العمل وتوليد 2000 كود (بنفس نظام المواد الجامعية)',
                        style: TextStyle(
                            color: Color(0xFFE52521), fontSize: 16, fontWeight: FontWeight.w900)),
                  ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E1E28)),
                    onPressed: _showManageTrainingCategoriesDialog,
                    icon: const Icon(Icons.settings, color: Color(0xFFE52521)),
                    label: const Text('إدارة المجالات',
                        style: TextStyle(color: Colors.white, fontSize: 11)),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              OutlinedButton.icon(
                onPressed: () => _showManagedCoursesDialog(training: true),
                icon: const Icon(Icons.manage_search),
                label: const Text('إدارة الدورات المنشورة: تعديل الفيديوهات وملفات PDF أو الحذف'),
              ),
              const SizedBox(height: 10),
              TextField(
                  controller: _trainingCourseTitleController,
                  decoration: const InputDecoration(
                      labelText: 'عنوان الدورة التدريبية (مثال: برمجة Flutter متقدم)',
                      filled: true)),
              const SizedBox(height: 12),
              if (trainingCategories.isEmpty)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF14141C),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.amberAccent),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Expanded(
                        child: Text('يرجى إضافة مجال تدريبي أولاً من زر إدارة المجالات',
                            style: TextStyle(color: Colors.amberAccent, fontSize: 12)),
                      ),
                      TextButton(
                        onPressed: _showManageTrainingCategoriesDialog,
                        child: const Text('إضافة مجال الآن'),
                      ),
                    ],
                  ),
                )
              else ...[
                DropdownButtonFormField<String>(
                  initialValue: trainingCategories.contains(_selectedTrainingCategory)
                      ? _selectedTrainingCategory
                      : trainingCategories.first,
                  dropdownColor: const Color(0xFF14141C),
                  items: trainingCategories
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() {
                      _selectedTrainingCategory = v;
                      final subs = trainingSubCategories[v] ?? [];
                      _selectedTrainingSubCategory = subs.isNotEmpty ? subs.first : 'عام';
                    });
                  },
                  decoration: const InputDecoration(
                      labelText: 'المجال التدريبي الرئيسي (مثل: برمجة، لغات، تصميم...)',
                      filled: true),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: (trainingSubCategories[_selectedTrainingCategory] ?? ['عام'])
                          .contains(_selectedTrainingSubCategory)
                      ? _selectedTrainingSubCategory
                      : (trainingSubCategories[_selectedTrainingCategory]?.isNotEmpty == true
                          ? trainingSubCategories[_selectedTrainingCategory]!.first
                          : 'عام'),
                  dropdownColor: const Color(0xFF14141C),
                  items: (trainingSubCategories[_selectedTrainingCategory]?.isNotEmpty == true
                          ? trainingSubCategories[_selectedTrainingCategory]!
                          : ['عام'])
                      .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setState(() => _selectedTrainingSubCategory = v);
                  },
                  decoration: const InputDecoration(
                      labelText: 'التخصص الفرعي داخل المجال', filled: true),
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                      child: TextField(
                          controller: _trainingCoursePriceController,
                          keyboardType: TextInputType.number,
                          decoration:
                              const InputDecoration(labelText: 'السعر الرقمي', filled: true))),
                  const SizedBox(width: 8),
                  DropdownButton<String>(
                    value: _trainingCourseCurrency,
                    dropdownColor: const Color(0xFF14141C),
                    items: const [
                      DropdownMenuItem(
                          value: 'ل.س',
                          child: Text('ل.س', style: TextStyle(color: Colors.white))),
                      DropdownMenuItem(
                          value: '\$', child: Text('\$', style: TextStyle(color: Colors.white))),
                    ],
                    onChanged: (val) => setState(() => _trainingCourseCurrency = val ?? 'ل.س'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                      child: TextField(
                          controller: _trainingCourseCodesCountController,
                          keyboardType: TextInputType.number,
                          decoration:
                              const InputDecoration(labelText: 'عدد الأكواد المراد توليدها (افتراضي 50، الحد الأقصى 1000)', filled: true))),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF14141C),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE52521), width: 1.5),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('صورة الدورة التدريبية (اختياري)',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE52521)),
                          onPressed: _isUploadingTrainingCourseImage
                              ? null
                              : () async {
                                  final url = await _uploadImageToSupabase(
                                    folder: 'training_courses',
                                    setLoading: (v) => setState(() => _isUploadingTrainingCourseImage = v),
                                  );
                                  if (!mounted) return;
                                  if (url != null) {
                                    setState(() => _trainingCourseImageUrl = url);
                                  }
                                },
                          icon: _isUploadingTrainingCourseImage
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                      color: Colors.white, strokeWidth: 2))
                              : const Icon(Icons.photo_library_rounded, color: Colors.white),
                          label: Text(
                              _isUploadingTrainingCourseImage ? 'جاري الرفع...' : 'رفع صورة 🖼️',
                              style: const TextStyle(color: Colors.white)),
                        ),
                      ],
                    ),
                    if (_trainingCourseImageUrl.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: CachedNetworkImage(
                            imageUrl: _trainingCourseImageUrl,
                            height: 100,
                            width: 100,
                            fit: BoxFit.cover),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Text(
                        _trainingCoursePdfUrl.isEmpty
                            ? 'لم يتم اختيار ملف PDF الرئيسي للدورة'
                            : 'تم اختيار ملف PDF الرئيسي للدورة ✅',
                        style: const TextStyle(color: Colors.white70)),
                  ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E1E28)),
                    icon: const Icon(Icons.upload_file, color: Color(0xFFE52521)),
                    label: const Text('رفع PDF للدورة', style: TextStyle(color: Colors.white)),
                    onPressed: () async {
                      String? url = await _pickAndUploadPdf('training_courses_pdfs');
                      if (url != null) {
                        setState(() => _trainingCoursePdfUrl = url);
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('تم رفع ملف PDF بنجاح!')));
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Text(
                  'إدارة محاضرات الدورة التدريبية (روابط يوتيوب غير مدرجة محمية + ملفات PDF وبنك الأسئلة)',
                  style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              ..._trainingLectureControllers.asMap().entries.map((entry) {
                int idx = entry.key;
                var lec = entry.value;
                if (lec['pdfCtrl'] == null) {
                  lec['pdfCtrl'] = TextEditingController(text: (lec['pdf'] as String? ?? ''));
                }
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                        color: const Color(0xFF14141C), borderRadius: BorderRadius.circular(16)),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                                child: TextField(
                                    controller: lec['title'] as TextEditingController,
                                    decoration: InputDecoration(
                                        labelText: 'عنوان المحاضرة ${idx + 1}', filled: true))),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 2,
                              child: TextField(
                                controller: lec['url'] as TextEditingController,
                                decoration: InputDecoration(
                                  labelText: 'رابط يوتيوب غير مدرج ${idx + 1}',
                                  filled: true,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                  (lec['pdf'] as String).isEmpty
                                      ? 'لا يوجد PDF محاضرة'
                                      : 'تم رفع PDF المحاضرة ✅',
                                  style: const TextStyle(color: Colors.grey, fontSize: 11)),
                            ),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF1E1E28)),
                              icon: const Icon(Icons.upload_file,
                                  color: Colors.redAccent, size: 16),
                              label: Text(
                                  (lec['isUploadingPdf'] == true)
                                      ? 'جاري الرفع...'
                                      : 'رفع PDF محاضرة',
                                  style: const TextStyle(fontSize: 11)),
                              onPressed: (lec['isUploadingPdf'] == true)
                                  ? null
                                  : () async {
                                      setState(() => lec['isUploadingPdf'] = true);
                                      String? url =
                                          await _pickAndUploadPdf('training_lectures_pdfs');
                                      setState(() {
                                        lec['isUploadingPdf'] = false;
                                        if (url != null) {
                                          lec['pdf'] = url;
                                          if (lec['pdfCtrl'] != null) {
                                            (lec['pdfCtrl'] as TextEditingController).text = url;
                                          }
                                        }
                                      });
                                      if (url != null && mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                                            content: Text('تم رفع ملف المحاضرة بنجاح!')));
                                      }
                                    },
                            ),
                            IconButton(
                              tooltip: 'حذف المحاضرة',
                              icon: const Icon(Icons.delete_forever_rounded,
                                  color: Colors.redAccent, size: 20),
                              onPressed: () {
                                setState(() => _trainingLectureControllers.removeAt(idx));
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: lec['pdfCtrl'] as TextEditingController,
                          style: const TextStyle(fontSize: 12, color: Colors.white70),
                          decoration: const InputDecoration(
                            isDense: true,
                            labelText: 'رابط PDF للمحاضرة (أو رابط Google Drive)',
                            hintText: 'الصق رابط ملف PDF أو Google Drive',
                            filled: true,
                          ),
                          onChanged: (v) => lec['pdf'] = v.trim(),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                  (lec['questionBank'] as String).isEmpty
                                      ? 'لا يوجد ملف تمارين / بنك أسئلة'
                                      : 'تم رفع ملف التمارين ✅',
                                  style: const TextStyle(color: Colors.grey, fontSize: 11)),
                            ),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF1E1E28)),
                              icon: const Icon(Icons.quiz, color: Colors.amberAccent, size: 16),
                              label: Text(
                                  (lec['isUploadingQB'] == true)
                                      ? 'جاري الرفع...'
                                      : 'رفع ملف تمارين PDF',
                                  style: const TextStyle(fontSize: 11)),
                              onPressed: (lec['isUploadingQB'] == true)
                                  ? null
                                  : () async {
                                      setState(() => lec['isUploadingQB'] = true);
                                      String? url =
                                          await _pickAndUploadPdf('training_question_banks');
                                      setState(() {
                                        lec['isUploadingQB'] = false;
                                        if (url != null) lec['questionBank'] = url;
                                      });
                                      if (url != null && mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                                            content: Text('تم رفع ملف التمارين بنجاح!')));
                                      }
                                    },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }),
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    _trainingLectureControllers.add({
                      'title': TextEditingController(
                          text: 'المحاضرة ${_trainingLectureControllers.length + 1}'),
                      'url': TextEditingController(),
                      'pdf': '',
                      'questionBank': '',
                      'isUploadingPdf': false,
                      'isUploadingQB': false,
                    });
                  });
                },
                icon: const Icon(Icons.add_rounded, color: Color(0xFFE52521)),
                label:
                    const Text('إضافة محاضرة أخرى', style: TextStyle(color: Color(0xFFE52521))),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                  onPressed: _saveTrainingCourse,
                  child: Text('نشر الدورة التدريبية وتوليد $_trainingCourseCodesCountController.text كود تفعيل')),
            ],
          ),
        );
      case 11:
        return _buildExternalCodeManagement(training: true);
      default:
        return const Center(
            child: Text('يرجى اختيار قسم من القائمة الجانبية',
                style: TextStyle(color: Colors.grey)));
    }
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF14141C),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(title, style: const TextStyle(color: Colors.grey, fontSize: 11)),
          const SizedBox(height: 4),
          Text(value,
              style: const TextStyle(
                  color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }

  Widget _buildSubAdminsTab() {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController(text: '+963');
    final passCtrl = TextEditingController();

    return StatefulBuilder(
      builder: (context, setSubState) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('إضافة مشرف فرعي وتعيين صلاحياته 👥',
                  style: TextStyle(
                      color: Color(0xFFE52521), fontSize: 18, fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              const Text(
                  'يمكنك تعيين مشرفين لمساعدتك في إدارة الأقسام (سيسجلون الدخول برقم الهاتف وكلمة السر المحددة هنا).',
                  style: TextStyle(color: Colors.grey, fontSize: 12)),
              const SizedBox(height: 14),
              TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'اسم المشرف', filled: true)),
              const SizedBox(height: 10),
              TextField(
                  controller: phoneCtrl,
                  decoration:
                      const InputDecoration(labelText: 'رقم هاتف المشرف (+963...)', filled: true),
                  keyboardType: TextInputType.phone),
              const SizedBox(height: 10),
              TextField(
                  controller: passCtrl,
                  decoration: const InputDecoration(labelText: 'كلمة سر المشرف', filled: true)),
              const SizedBox(height: 16),
              const Text('اختر الصلاحيات المسموحة لهذا المشرف:',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              CheckboxListTile(
                  title: const Text('إدارة المتجر', style: TextStyle(color: Colors.white70)),
                  value: permStore,
                  activeColor: const Color(0xFFE52521),
                  onChanged: (v) => setSubState(() => permStore = v!)),
              CheckboxListTile(
                  title:
                      const Text('العروض والباكدجات', style: TextStyle(color: Colors.white70)),
                  value: permBundles,
                  activeColor: const Color(0xFFE52521),
                  onChanged: (v) => setSubState(() => permBundles = v!)),
              CheckboxListTile(
                  title: const Text('الكورسات والمواد الجامعية',
                      style: TextStyle(color: Colors.white70)),
                  value: permCourses,
                  activeColor: const Color(0xFFE52521),
                  onChanged: (v) => setSubState(() => permCourses = v!)),
              CheckboxListTile(
                  title: const Text('أكواد المواد الجامعية',
                      style: TextStyle(color: Colors.white70)),
                  value: permCodes,
                  activeColor: const Color(0xFFE52521),
                  onChanged: (v) => setSubState(() => permCodes = v!)),
              CheckboxListTile(
                  title: const Text('الدورات التدريبية لسوق العمل',
                      style: TextStyle(color: Colors.white70)),
                  value: permTrainingCourses,
                  activeColor: const Color(0xFFE52521),
                  onChanged: (v) => setSubState(() => permTrainingCourses = v!)),
              CheckboxListTile(
                  title: const Text('أكواد الدورات التدريبية',
                      style: TextStyle(color: Colors.white70)),
                  value: permTrainingCodes,
                  activeColor: const Color(0xFFE52521),
                  onChanged: (v) => setSubState(() => permTrainingCodes = v!)),
              CheckboxListTile(
                  title: const Text('سجل المبيعات', style: TextStyle(color: Colors.white70)),
                  value: permSales,
                  activeColor: const Color(0xFFE52521),
                  onChanged: (v) => setSubState(() => permSales = v!)),
              CheckboxListTile(
                  title:
                      const Text('إحصاءات الجامعات', style: TextStyle(color: Colors.white70)),
                  value: permStats,
                  activeColor: const Color(0xFFE52521),
                  onChanged: (v) => setSubState(() => permStats = v!)),
              CheckboxListTile(
                  title: const Text('إدارة الإعلانات', style: TextStyle(color: Colors.white70)),
                  value: permAds,
                  activeColor: const Color(0xFFE52521),
                  onChanged: (v) => setSubState(() => permAds = v!)),
              CheckboxListTile(
                  title:
                      const Text('إعدادات الواتساب', style: TextStyle(color: Colors.white70)),
                  value: permWhatsapp,
                  activeColor: const Color(0xFFE52521),
                  onChanged: (v) => setSubState(() => permWhatsapp = v!)),
              CheckboxListTile(
                  title: const Text('إرسال إشعارات عامة',
                      style: TextStyle(color: Colors.white70)),
                  value: permNotif,
                  activeColor: const Color(0xFFE52521),
                  onChanged: (v) => setSubState(() => permNotif = v!)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () async {
                  if (nameCtrl.text.isEmpty || phoneCtrl.text.isEmpty || passCtrl.text.isEmpty) {
                    return;
                  }
                  await FirebaseFirestore.instance.collection('sub_admins').add({
                    'name': nameCtrl.text.trim(),
                    'phone': phoneCtrl.text.trim(),
                    'pass': passCtrl.text.trim(),
                    'isActive': true,
                    'permissions': {
                      'store': permStore,
                      'bundles': permBundles,
                      'courses': permCourses,
                      'codes': permCodes,
                      'trainingCourses': permTrainingCourses,
                      'trainingCodes': permTrainingCodes,
                      'sales': permSales,
                      'stats': permStats,
                      'ads': permAds,
                      'whatsapp': permWhatsapp,
                      'notif': permNotif,
                    },
                  });
                  nameCtrl.clear();
                  passCtrl.clear();
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('تم إنشاء حساب المشرف الفرعي بنجاح! ✅')));
                },
                child: const Text('إنشاء حساب المشرف'),
              ),
              const Divider(color: Colors.white24, height: 35),
              const Text('المشرفون الحاليون في المنصة:',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 10),
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('sub_admins').limit(100).snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const SizedBox();
                  return Column(
                    children: snapshot.data!.docs.map((doc) {
                      var s = doc.data() as Map<String, dynamic>;
                      bool isActive = s['isActive'] ?? true;
                      return Card(
                        color: const Color(0xFF14141C),
                        child: ListTile(
                          title: Text('${s['name']} (${s['phone']})',
                              style: const TextStyle(color: Colors.white)),
                          subtitle: Text('كلمة السر: ${s['pass']}',
                              style: const TextStyle(color: Colors.grey, fontSize: 12)),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Switch(
                                value: isActive,
                                activeThumbColor: Colors.green,
                                onChanged: (val) async {
                                  await FirebaseFirestore.instance
                                      .collection('sub_admins')
                                      .doc(doc.id)
                                      .update({'isActive': val});
                                },
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                onPressed: () async {
                                  await FirebaseFirestore.instance
                                      .collection('sub_admins')
                                      .doc(doc.id)
                                      .delete();
                                },
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showManageTrainingCategoriesDialog() {
    final newCatCtrl = TextEditingController();
    final newSubCtrl = TextEditingController();
    String selectedCatForSub = trainingCategories.isNotEmpty ? trainingCategories.first : '';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF14141C),
          title: const Text('إدارة مجالات الدورات التدريبية لسوق العمل',
              style: TextStyle(color: Color(0xFFE52521), fontWeight: FontWeight.bold)),
          content: SizedBox(
            width: 450,
            height: 430,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('إضافة مجال تدريبي رئيسي جديد:',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: newCatCtrl,
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(
                              hintText: 'اسم المجال (مثل: برمجة، تصميم، لغات)', filled: true),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE52521)),
                        onPressed: () async {
                          final name = newCatCtrl.text.trim();
                          if (name.isEmpty) return;
                          await FirebaseFirestore.instance.collection('training_categories').add({
                            'name': name,
                            'subCategories': ['عام'],
                          });
                          newCatCtrl.clear();
                          await _loadTrainingCategories();
                          setDialogState(() {
                            if (trainingCategories.isNotEmpty) {
                              selectedCatForSub = trainingCategories.last;
                            }
                          });
                        },
                        child: const Text('إضافة'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text('إضافة تخصص فرعي لمجال:',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  if (trainingCategories.isNotEmpty) ...[
                    DropdownButtonFormField<String>(
                      initialValue: trainingCategories.contains(selectedCatForSub)
                          ? selectedCatForSub
                          : trainingCategories.first,
                      dropdownColor: const Color(0xFF1E1E28),
                      items: trainingCategories
                          .map((c) => DropdownMenuItem(
                              value: c,
                              child: Text(c, style: const TextStyle(color: Colors.white))))
                          .toList(),
                      onChanged: (v) => setDialogState(() => selectedCatForSub = v!),
                      decoration: const InputDecoration(labelText: 'اختر المجال', filled: true),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: newSubCtrl,
                            style: const TextStyle(color: Colors.white),
                            decoration: const InputDecoration(
                                hintText: 'اسم التخصص الفرعي (مثل: تطبيقات موبايل)', filled: true),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          style:
                              ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE52521)),
                          onPressed: () async {
                            final subName = newSubCtrl.text.trim();
                            if (subName.isEmpty) return;
                            final query = await FirebaseFirestore.instance
                                .collection('training_categories')
                                .where('name', isEqualTo: selectedCatForSub)
                                .limit(1)
                                .get();
                            if (query.docs.isNotEmpty) {
                              await query.docs.first.reference.update({
                                'subCategories': FieldValue.arrayUnion([subName]),
                              });
                              newSubCtrl.clear();
                              await _loadTrainingCategories();
                              setDialogState(() {});
                            }
                          },
                          child: const Text('إضافة'),
                        ),
                      ],
                    ),
                  ],
                  const Divider(color: Colors.white24, height: 24),
                  const Text('المجالات والتخصصات الحالية:',
                      style: TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  ...trainingCategories.map((cat) {
                    final subs = trainingSubCategories[cat] ?? [];
                    return Card(
                      color: const Color(0xFF1E1E28),
                      child: ExpansionTile(
                        title: Text(cat,
                            style: const TextStyle(
                                color: Colors.white, fontWeight: FontWeight.bold)),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete, color: Colors.redAccent),
                          onPressed: () async {
                            final query = await FirebaseFirestore.instance
                                .collection('training_categories')
                                .where('name', isEqualTo: cat)
                                .limit(1)
                                .get();
                            for (var doc in query.docs) {
                              await doc.reference.delete();
                            }
                            await _loadTrainingCategories();
                            setDialogState(() {});
                          },
                        ),
                        children: subs
                            .map((s) => ListTile(
                                  title: Text(s, style: const TextStyle(color: Colors.white70)),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.close,
                                        color: Colors.redAccent, size: 16),
                                    onPressed: () async {
                                      final query = await FirebaseFirestore.instance
                                          .collection('training_categories')
                                          .where('name', isEqualTo: cat)
                                          .limit(1)
                                          .get();
                                      if (query.docs.isNotEmpty) {
                                        await query.docs.first.reference.update({
                                          'subCategories': FieldValue.arrayRemove([s]),
                                        });
                                        await _loadTrainingCategories();
                                        setDialogState(() {});
                                      }
                                    },
                                  ),
                                ))
                            .toList(),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إغلاق')),
          ],
        ),
      ),
    );
  }

  Future<void> _saveTrainingCourse() async {
    if (_trainingCourseTitleController.text.isEmpty || _selectedTrainingCategory.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('الرجاء إدخال عنوان الدورة واختيار المجال التدريبي')));
      return;
    }

    var lecturesList = <Map<String, dynamic>>[];
    for (var lec in _trainingLectureControllers) {
      String title = (lec['title'] as TextEditingController).text.trim();
      String url = (lec['url'] as TextEditingController).text.trim();
      String pdf = lec['pdf'] as String;
      String qb = lec['questionBank'] as String;
      if (url.isNotEmpty) {
        String extractedVideoId = extractYoutubeVideoId(url);
        lecturesList.add({
          'title': title.isNotEmpty ? title : 'محاضرة',
          'videoId': extractedVideoId,
          'url': url,
          'pdfUrl': pdf,
          'questionBankUrl': qb,
        });
      }
    }

    if (lecturesList.isEmpty) {
      lecturesList.add({
        'title': 'المحاضرة الأولى',
        'videoId': '',
        'url': '',
        'pdfUrl': '',
        'questionBankUrl': ''
      });
    }

    int priceNum = int.tryParse(_trainingCoursePriceController.text) ?? 25000;
    String formattedPrice = '$priceNum $_trainingCourseCurrency';

    // قراءة عدد الأكواد من حقل الإدخال (افتراضي 50)
    int codesCount = int.tryParse(_trainingCourseCodesCountController.text) ?? 50;
    codesCount = codesCount.clamp(1, 1000); // حد أدنى 1، حد أقصى 1000 لتخفيف استهلاك حصة الكتابة المجانية

    // 1. إنشاء مستند الدورة أولاً للحصول على الـ ID
    final courseRef = FirebaseFirestore.instance.collection('training_courses').doc();
    final courseId = courseRef.id;

    // 2. توليد الأكواد وحفظهم في مجموعة training_codes باستخدام WriteBatch مقسم
    // Firestore يحد الدفعة الواحدة بـ 500 عملية، لذا نقسمها إلى دفعات
    const int batchSize = 500;
    final generatedCodes = <String>{};
    for (int batchStart = 0; batchStart < codesCount; batchStart += batchSize) {
      int batchEnd = (batchStart + batchSize).clamp(0, codesCount);
      WriteBatch batch = FirebaseFirestore.instance.batch();
      for (int i = batchStart; i < batchEnd; i++) {
        String code;
        do {
          code = (100000 + Random().nextInt(900000)).toString();
        } while (!generatedCodes.add(code));
        final codeData = {
          'code': code,
          'courseId': courseId,
          'isUsed': false,
          'isDisabled': false,
          'usedBy': null,
          'userUid': null,
          'usedAt': null,
          'durationDays': 120,
        };
        batch.set(FirebaseFirestore.instance.collection('training_codes').doc(code), codeData);
      }
      await batch.commit();
    }

    // 3. حفظ الدورة مع عدد الأكواد فقط (لا نخزن المصفوفة الضخمة في المستند)
    await courseRef.set({
      'title': _trainingCourseTitleController.text.trim(),
      'category': _selectedTrainingCategory,
      'subCategory':
          _selectedTrainingSubCategory.isEmpty ? 'عام' : _selectedTrainingSubCategory,
      'priceNum': priceNum,
      'currency': _trainingCourseCurrency,
      'price': formattedPrice,
      'imageUrl': _trainingCourseImageUrl,
      'pdfUrl': _trainingCoursePdfUrl,
      'lectures': lecturesList,
      'codesCount': codesCount,
      'codes': [], // مصفوفة فارغة لتقليل حجم المستند
      'createdAt': FieldValue.serverTimestamp(),
    });

    await FirebaseFirestore.instance.collection('broadcast_notifications').add({
      'title': 'تم نشر دورة تدريبية جديدة لسوق العمل 💼',
      'message':
          'تم إضافة دورة (${_trainingCourseTitleController.text.trim()}) في مجال ($_selectedTrainingCategory).',
      'targetSection': 'الدورات التدريبية لسوق العمل',
      'timestamp': FieldValue.serverTimestamp(),
    });

    addAppNotification(
      targetUserName: '',
      title: 'تم نشر دورة تدريبية جديدة لسوق العمل 💼',
      message:
          'تم إضافة دورة (${_trainingCourseTitleController.text.trim()}) في مجال ($_selectedTrainingCategory).',
      icon: Icons.work_rounded,
      iconColor: const Color(0xFFE52521),
    );

    _trainingCourseTitleController.clear();
    _trainingCoursePriceController.clear();
    _trainingCourseImageUrl = '';
    _trainingCoursePdfUrl = '';
    setState(() {
      _trainingLectureControllers = [
        {
          'title': TextEditingController(text: 'المحاضرة الأولى'),
          'url': TextEditingController(),
          'pdf': '',
          'questionBank': '',
          'isUploadingPdf': false,
          'isUploadingQB': false,
        }
      ];
    });
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تم نشر الدورة، توليد $codesCount كود تفعيل في training_codes، وإرسال الإشعار بنجاح!')));
  }
}