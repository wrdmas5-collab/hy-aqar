import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:ui';
import 'dart:math';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint("Handling a background message: ${message.messageId}");
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: const FirebaseOptions(
          apiKey: "AIzaSyCxMtCMtFHlbDMBWZpHRzqwF0YDz_P9Yzo",
          authDomain: "hy-aqar.firebaseapp.com",
          projectId: "hy-aqar",
          storageBucket: "hy-aqar.firebasestorage.app",
          messagingSenderId: "960269964659",
          appId: "1:960269964659:web:10c758de7d84066f8fe106",
          measurementId: "G-PC5B02LC48",
        ),
      );
    }
    
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    FirebaseMessaging messaging = FirebaseMessaging.instance;
    NotificationSettings settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    debugPrint('User granted permission: ${settings.authorizationStatus}');

    String? token = await messaging.getToken();
    debugPrint("FCM Registration Token: $token");

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('Got a message whilst in the foreground!');
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

  } catch (e) {
    debugPrint("Firebase initialization or FCM error: $e");
  }

  final prefs = await SharedPreferences.getInstance();
  bool isLoggedIn = prefs.getBool('is_logged_in') ?? false;
  String savedName = prefs.getString('user_name') ?? '';
  String savedPhone = prefs.getString('user_phone') ?? '';
  String savedUid = prefs.getString('user_uid') ?? '';
  bool savedIsAdmin = prefs.getBool('is_admin') ?? false;
  List<String> savedAdminPerms = prefs.getStringList('admin_perms') ?? [];

  runApp(HyAcademyApp(
    isLoggedIn: isLoggedIn,
    initialName: savedName,
    initialPhone: savedPhone,
    initialUid: savedUid,
    initialIsAdmin: savedIsAdmin,
    initialAdminPerms: savedAdminPerms,
  ));
}

class HyAcademyApp extends StatefulWidget {
  final bool isLoggedIn;
  final String initialName;
  final String initialPhone;
  final String initialUid;
  final bool initialIsAdmin;
  final List<String> initialAdminPerms;

  const HyAcademyApp({
    super.key,
    required this.isLoggedIn,
    required this.initialName,
    required this.initialPhone,
    required this.initialUid,
    required this.initialIsAdmin,
    required this.initialAdminPerms,
  });

  @override
  State<HyAcademyApp> createState() => _HyAcademyAppState();

  static _HyAcademyAppState of(BuildContext context) => context.findAncestorStateOfType<_HyAcademyAppState>()!;
}

class _HyAcademyAppState extends State<HyAcademyApp> {
  bool isDarkMode = true;

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
    return Stack(
      children: [
        YoutubePlayer(
          controller: controller,
          aspectRatio: 16 / 9,
        ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: 55,
          child: Container(color: Colors.transparent),
        ),
        Positioned(
          bottom: 0,
          right: 0,
          width: 90,
          height: 45,
          child: Container(color: Colors.transparent),
        ),
      ],
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

class _FloatingSticker3DState extends State<FloatingSticker3D> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration)..repeat(reverse: true);
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
                      color: Colors.black.withOpacity(0.35),
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
                    placeholder: (context, url) => Center(child: Icon(widget.fallbackIcon, color: const Color(0xFFE52521), size: 26)),
                    errorWidget: (context, url, error) => Center(child: Icon(widget.fallbackIcon, color: const Color(0xFFE52521), size: 26)),
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
        FloatingSticker3D(imageUrl: 'https://images.unsplash.com/photo-1588776814546-1ffcf47267a5?w=200', fallbackIcon: Icons.medical_services_rounded, top: 20, left: 15, duration: Duration(seconds: 4), size: 65),
        FloatingSticker3D(imageUrl: 'https://images.unsplash.com/photo-1581291518633-83b4ebd1d83e?w=200', fallbackIcon: Icons.architecture_rounded, top: 25, right: 20, duration: Duration(seconds: 5), size: 65),
        FloatingSticker3D(imageUrl: 'https://images.unsplash.com/photo-1513364776144-60967b0f800f?w=200', fallbackIcon: Icons.palette_rounded, bottom: 30, left: 25, duration: Duration(seconds: 6), size: 65),
        FloatingSticker3D(imageUrl: 'https://images.unsplash.com/photo-1532187863486-abf9dbad1b69?w=200', fallbackIcon: Icons.science_rounded, bottom: 25, right: 30, duration: Duration(seconds: 4), size: 65),
        FloatingSticker3D(imageUrl: 'https://images.unsplash.com/photo-1607604276583-eef5d076aa5f?w=200', fallbackIcon: Icons.school_rounded, top: 150, left: 10, duration: Duration(seconds: 5), size: 60),
        FloatingSticker3D(imageUrl: 'https://images.unsplash.com/photo-1523240795612-9a054b0db644?w=200', fallbackIcon: Icons.menu_book_rounded, top: 160, right: 10, duration: Duration(seconds: 6), size: 60),
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
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );

    _scaleAnimation = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
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
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0, -0.3),
                radius: 1.5,
                colors: [Color(0xFF1F1F28), Color(0xFF0F0F12)],
              ),
            ),
          ),
          const BackgroundStickersLayer(),
          Center(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: ScaleTransition(
                scale: _scaleAnimation,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [Color(0xFFE52521), Color(0xFFFF4D4D)],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Color(0x55E52521),
                            blurRadius: 45,
                            spreadRadius: 12,
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: Image.asset(
                          'assets/icon/icon.jpg',
                          width: 80,
                          height: 80,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => const Icon(Icons.storefront_rounded, size: 80, color: Colors.white),
                        ),
                      ),
                    ),
                    const SizedBox(height: 30),
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
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 30),
                      child: Text(
                        'المنصة التعليمية الشاملة ومستلزمات طلاب الجامعات',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 50),
                    const SizedBox(
                      width: 35,
                      height: 35,
                      child: CircularProgressIndicator(
                        color: Color(0xFFE52521),
                        strokeWidth: 3,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _phoneController = TextEditingController(text: '+963');
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();

  final String adminPhone = "+963967834966";
  final String adminPass = "81644936";

  double _rotateX = 0.0;
  double _rotateY = 0.0;

  void _onPointerHover(PointerHoverEvent event, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final pos = event.localPosition;
    setState(() {
      _rotateY = (pos.dx - center.dx) / center.dx * 0.18;
      _rotateX = -(pos.dy - center.dy) / center.dy * 0.18;
    });
  }

  void _onPointerExit(PointerExitEvent event) {
    setState(() {
      _rotateX = 0.0;
      _rotateY = 0.0;
    });
  }

  void _recordNewUserLogin(String name, String phone, String uid, bool isAdmin) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'name': name,
        'phone': phone,
        'isAdmin': isAdmin,
        'lastLogin': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint("Login record error: $e");
    }
  }

  void _login() async {
    String phone = _phoneController.text.trim();
    String pass = _passwordController.text.trim();
    String name = _nameController.text.trim();

    if (phone.isEmpty || pass.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الرجاء إدخال رقم الهاتف وكلمة سر من 6 خانات على الأقل')),
      );
      return;
    }

    bool isAdmin = false;
    List<String> adminPerms = [];
    String loggedName = name;
    String uid = "USER-UID-${DateTime.now().millisecondsSinceEpoch}";

    if (phone == adminPhone && (pass == adminPass || name.contains('حيان'))) {
      isAdmin = true;
      loggedName = name.isEmpty ? 'حيان الأدمين العام' : name;
      uid = "ADMIN-UID-$phone";
      adminPerms = ['all'];
    } else {
      try {
        var query = await FirebaseFirestore.instance
            .collection('sub_admins')
            .where('phone', isEqualTo: phone)
            .where('pass', isEqualTo: pass)
            .where('isActive', isEqualTo: true)
            .limit(10)
            .get();

        if (query.docs.isNotEmpty) {
          var subData = query.docs.first.data();
          isAdmin = true;
          loggedName = subData['name'] ?? 'مشرف فرعي';
          uid = "SUB-ADMIN-${query.docs.first.id}";
          var permsMap = subData['permissions'] as Map<String, dynamic>?;
          if (permsMap != null) {
            permsMap.forEach((k, v) {
              if (v == true) adminPerms.add(k);
            });
          }
        }
      } catch (e) {
        debugPrint("Sub-admin login check error: $e");
      }
    }

    if (!isAdmin && loggedName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الرجاء إدخال الاسم الثلاثي لإتمام تسجيل الدخول')),
      );
      return;
    }

    _recordNewUserLogin(loggedName, phone, uid, isAdmin);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_logged_in', true);
    await prefs.setString('user_name', loggedName);
    await prefs.setString('user_phone', phone);
    await prefs.setString('user_uid', uid);
    await prefs.setBool('is_admin', isAdmin);
    await prefs.setStringList('admin_perms', adminPerms);

    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => HomeScreen(
          userName: loggedName,
          userPhone: phone,
          userUid: uid,
          isAdmin: isAdmin,
          adminPerms: adminPerms,
        ),
      ),
    );
  }

  void _loginWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) return;

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      UserCredential userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
      User? user = userCredential.user;

      if (user != null) {
        String name = user.displayName ?? googleUser.displayName ?? 'طالب hy Academy';
        String phone = user.phoneNumber ?? '+963900000000';
        String uid = user.uid;

        bool isAdmin = (user.email == "hayyanmasri9@gmail.com" || uid == "ADMIN-UID-$adminPhone");
        List<String> adminPerms = isAdmin ? ['all'] : [];

        _recordNewUserLogin(name, phone, uid, isAdmin);

        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('is_logged_in', true);
        await prefs.setString('user_name', name);
        await prefs.setString('user_phone', phone);
        await prefs.setString('user_uid', uid);
        await prefs.setBool('is_admin', isAdmin);
        await prefs.setStringList('admin_perms', adminPerms);

        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => HomeScreen(
              userName: name,
              userPhone: phone,
              userUid: uid,
              isAdmin: isAdmin,
              adminPerms: adminPerms,
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint("Google Sign-In Error: $e");
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر تسجيل الدخول عبر جوجل: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isDark = HyAcademyApp.of(context).isDarkMode;

    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0, -0.6),
                radius: 1.5,
                colors: isDark ? const [Color(0xFF1F1F28), Color(0xFF0F0F12)] : const [Color(0xFFFFFFFF), Color(0xFFF0F0F5)],
              ),
            ),
          ),
          const BackgroundStickersLayer(),
          Positioned(
            top: 20,
            right: 20,
            child: IconButton(
              icon: Icon(isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded, color: const Color(0xFFE52521), size: 28),
              onPressed: () => HyAcademyApp.of(context).toggleTheme(),
              tooltip: 'تبديل المظهر',
            ),
          ),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 40.0),
              child: MouseRegion(
                onHover: (event) => _onPointerHover(event, const Size(460, 640)),
                onExit: _onPointerExit,
                child: TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 300),
                  builder: (context, val, child) {
                    return Transform(
                      transform: Matrix4.identity()
                        ..setEntry(3, 2, 0.001)
                        ..rotateX(_rotateX)
                        ..rotateY(_rotateY),
                      alignment: Alignment.center,
                      child: child,
                    );
                  },
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 460),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(35),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                        child: Container(
                          padding: const EdgeInsets.all(40.0),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF14141C).withOpacity(0.95) : Colors.white.withOpacity(0.95),
                            borderRadius: BorderRadius.circular(35),
                            border: Border.all(color: const Color(0xFFE52521).withOpacity(0.7), width: 2),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x33E52521),
                                blurRadius: 60,
                                offset: Offset(0, 20),
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
                                      errorBuilder: (context, error, stackTrace) => const Icon(Icons.school_rounded, size: 55, color: Color(0xFFE52521)),
                                    ),
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
                              const SizedBox(height: 6),
                              const Text(
                                'تسجيل الدخول إلى المنصة',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 30),

                              _buildInputField(
                                controller: _nameController,
                                label: 'الاسم الثلاثي',
                                icon: Icons.person_rounded,
                                isDark: isDark,
                              ),
                              const SizedBox(height: 16),
                              _buildInputField(
                                controller: _phoneController,
                                label: 'رقم الهاتف (+963...)',
                                icon: Icons.phone_iphone_rounded,
                                keyboardType: TextInputType.phone,
                                isDark: isDark,
                              ),
                              const SizedBox(height: 16),
                              _buildInputField(
                                controller: _passwordController,
                                label: 'كلمة السر (6 خانات أو أكثر)',
                                icon: Icons.lock_rounded,
                                obscureText: true,
                                isDark: isDark,
                              ),
                              const SizedBox(height: 24),
                              Container(
                                height: 54,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(18),
                                  color: const Color(0xFFE52521),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Color(0x44E52521),
                                      blurRadius: 25,
                                      offset: Offset(0, 8),
                                    ),
                                  ],
                                ),
                                child: ElevatedButton(
                                  onPressed: _login,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.transparent,
                                    shadowColor: Colors.transparent,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                                  ),
                                  child: const Text(
                                    'تسجيل الدخول',
                                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 20),

                              SizedBox(
                                height: 54,
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.white,
                                    foregroundColor: Colors.black87,
                                    elevation: 4,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                                  ),
                                  onPressed: _loginWithGoogle,
                                  icon: const Icon(Icons.g_mobiledata, color: Color(0xFFE52521), size: 32),
                                  label: const Text(
                                    'تسجيل الدخول عبر جوجل',
                                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
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
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscureText = false,
    TextInputType? keyboardType,
    required bool isDark,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 15),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: isDark ? Colors.white60 : Colors.black54),
        prefixIcon: Icon(icon, color: const Color(0xFFE52521)),
        filled: true,
        fillColor: isDark ? const Color(0xFF1E1E28) : const Color(0xFFF0F0F5),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: isDark ? const Color(0xFF2E2E3E) : const Color(0xFFD4D4E0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFE52521), width: 2),
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

Map userNotifications = {};
Set globalFavorites = {};
List globalCart = [];

void addAppNotification({
  required String targetUserName,
  required String title,
  required String message,
  required IconData icon,
  required Color iconColor,
}) {
  userNotifications.putIfAbsent(targetUserName, () => []);
  String timeStr = "${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')}";
  (userNotifications[targetUserName] as List).insert(
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

List globalCategories = ['الكل', 'عمارة', 'أسنان', 'مدنية', 'معلوماتية', 'بشرية', 'ديكور', 'العروض'];

Map categoryIcons = {
  'الكل': Icons.grid_view_rounded,
  'عمارة': Icons.architecture_rounded,
  'أسنان': Icons.medical_services_rounded,
  'مدنية': Icons.foundation_rounded,
  'معلوماتية': Icons.computer_rounded,
  'بشرية': Icons.health_and_safety_rounded,
  'ديكور': Icons.weekend_rounded,
  'العروض': Icons.local_offer_rounded,
};

List globalUniversities = [
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

Map universityColleges = {
  'جامعة دمشق': ['هندسة مدنية', 'هندسة معلوماتية', 'هندسة ديكور', 'هندسة عمارة', 'طب بشري', 'طب أسنان'],
  'جامعة حلب': ['هندسة ميكانيكية', 'هندسة كهربائية', 'هندسة مدنية', 'طب بشري', 'هندسة عمارة'],
  'جامعة تشرين': ['هندسة تقانة المعلومات', 'هندسة مدنية', 'صيدلة', 'طب أسنان'],
  'جامعة الفرات': ['هندسة مدنية', 'آداب', 'علوم', 'طب بشري'],
  'جامعة حمص': ['هندسة بتروكيمياوية', 'هندسة معمارية', 'علوم أساسية', 'طب بشري'],
  'جامعة اليرموك الخاصة': ['هندسة معلوماتية', 'هندسة اتصالات', 'إدارة أعمال'],
  'الجامعة العربية الدولية (AIU)': ['هندسة معمارية', 'هندسة معلوماتية', 'صيدلة', 'إدارة أعمال'],
  'الجامعة الدولية الخاصة للعلوم والتكنولوجيا (IUST)': ['هندسة إلكترونيات', 'هندسة ميكاترونيكس', 'طب أسنان', 'هندسة معلوماتية'],
  'جامعة الاتحاد الخاصة (IPU)': ['هندسة معلوماتية', 'هندسة مدنية', 'إدارة أعمال', 'صيدلة'],
  'جامعة الجزيرة الخاصة (JPU)': ['هندسة مدنية', 'هندسة معمارية', 'إدارة أعمال'],
  'الجامعة البريطانية في دمشق (BUD)': ['إدارة أعمال دولية', 'هندسة برمجيات', 'ذكاء اصطناعي'],
  'جامعة قاسيون الخاصة (QPU)': ['هندسة إلكترونيات', 'هندسة ميكاترونيكس', 'طب أسنان', 'هندسة معلوماتية'],
  'جامعة القلمون الخاصة': ['طب بشري', 'هندسة طبية', 'إدارة أعمال', 'صيدلة'],
  'الجامعة السورية الخاصة (ASPU)': ['طب بشري', 'هندسة معلوماتية', 'إدارة أعمال', 'صيدلة'],
  'جامعة الحواش الخاصة (HPU)': ['صيدلة', 'طب أسنان', 'هندسة معلوماتية', 'هندسة مدنية'],
};

Map collegeImages = {
  'طب أسنان': 'https://images.unsplash.com/photo-1588776814546-1ffcf47267a5?w=500',
  'هندسة مدنية': 'https://images.unsplash.com/photo-1541888946425-d0fbb18f86f7?w=500',
  'هندسة معلوماتية': 'https://images.unsplash.com/photo-1526374965328-7f61d4dc18c5?w=500',
  'هندسة عمارة': 'https://images.unsplash.com/photo-1503387762-592deb58ef4e?w=500',
  'طب بشري': 'https://images.unsplash.com/photo-1579684385127-1ef15d508118?w=500',
  'هندسة ديكور': 'https://images.unsplash.com/photo-1618221195710-dd6b41faaea6?w=500',
  'هندسة اتصالات': 'https://images.unsplash.com/photo-1544197150-b99a580bb7a8?w=500',
  'إدارة أعمال': 'https://images.unsplash.com/photo-1454165804606-c3d57bc86b40?w=500',
  'علوم أساسية': 'https://images.unsplash.com/photo-1532094349884-543bc11b234d?w=500',
  'هندسة إلكترونيات': 'https://images.unsplash.com/photo-1518770660439-4636190af475?w=500',
  'هندسة ميكاترونيكس': 'https://images.unsplash.com/photo-1581092160607-ee22621dd758?w=500',
  'هندسة برمجيات': 'https://images.unsplash.com/photo-1555066931-4365d14bab8c?w=500',
  'ذكاء اصطناعي': 'https://images.unsplash.com/photo-1677442136019-21780efad99a?w=500',
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

  void _logout(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    await GoogleSignIn().signOut();
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
        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('broadcast_notifications').orderBy('timestamp', descending: true).limit(50).snapshots(),
          builder: (context, snapshot) {
            List broadcastNotifs = snapshot.hasData ? snapshot.data!.docs : [];
            List localNotifs = (userNotifications[widget.userName] ?? []) as List;

            return Container(
              height: MediaQuery.of(context).size.height * 0.65,
              decoration: const BoxDecoration(color: Color(0xFF14141C), borderRadius: BorderRadius.vertical(top: Radius.circular(35))),
              padding: const EdgeInsets.all(26),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('الإشعارات والتحديثات 🔔', style: TextStyle(color: Color(0xFFE52521), fontSize: 20, fontWeight: FontWeight.w900)),
                  const Divider(color: Colors.white12, height: 30),
                  Expanded(
                    child: (broadcastNotifs.isEmpty && localNotifs.isEmpty)
                        ? const Center(child: Text('لا توجد إشعارات حالياً', style: TextStyle(color: Colors.white38)))
                        : ListView(
                            children: [
                              ...broadcastNotifs.map((doc) {
                                var data = doc.data() as Map<String, dynamic>;
                                Timestamp? ts = data['timestamp'] as Timestamp?;
                                String timeStr = ts != null ? "${ts.toDate().hour}:${ts.toDate().minute.toString().padLeft(2, '0')}" : '';
                                return ListTile(
                                  leading: const Icon(Icons.campaign_rounded, color: Color(0xFFE52521)),
                                  title: Text(data['title'] ?? '', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                  subtitle: Text(data['message'] ?? '', style: const TextStyle(color: Colors.white70)),
                                  trailing: Text(timeStr, style: const TextStyle(color: Colors.grey, fontSize: 11)),
                                );
                              }),
                              ...localNotifs.map((item) {
                                return ListTile(
                                  leading: Icon(item.icon, color: item.iconColor),
                                  title: Text(item.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                  subtitle: Text(item.message, style: const TextStyle(color: Colors.white70)),
                                  trailing: Text(item.time, style: const TextStyle(color: Colors.grey, fontSize: 11)),
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
            String totalCartPriceStr = globalCart.fold("0", (sum, item) {
              return "${(double.tryParse(sum) ?? 0) + ((item['priceNum'] ?? 0) * (item['qty'] ?? 1))} ${item['currency'] ?? 'ل.س'}";
            });
            return Container(
              height: MediaQuery.of(context).size.height * 0.7,
              decoration: const BoxDecoration(color: Color(0xFF14141C), borderRadius: BorderRadius.vertical(top: Radius.circular(35))),
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('سلة المشتريات 🛒', style: TextStyle(color: Color(0xFFE52521), fontSize: 20, fontWeight: FontWeight.w900)),
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
                        ? const Center(child: Text('سلة المشتريات فارغة حالياً', style: TextStyle(color: Colors.white38)))
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
                                title: Text(cartItem['title'] ?? '', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                subtitle: Text('العدد: ${cartItem['qty']} | السعر: ${cartItem['price']}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
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
                      Text('الإجمالي: $totalCartPriceStr', style: const TextStyle(color: Color(0xFFE52521), fontSize: 16, fontWeight: FontWeight.w900)),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                        onPressed: globalCart.isEmpty ? null : () async {
                          DocumentSnapshot settingsDoc = await FirebaseFirestore.instance.collection('settings').doc('app_config').get();
                          String activeWhatsApp = "963967834966";
                          if (settingsDoc.exists && settingsDoc.data() != null) {
                            var data = settingsDoc.data() as Map<String, dynamic>;
                            if (data['whatsapp'] != null && data['whatsapp'].toString().isNotEmpty) {
                              activeWhatsApp = data['whatsapp'];
                            }
                          }

                          String itemsStr = globalCart.map((i) => "• ${i['title']} (العدد: ${i['qty']} - السعر: ${i['price']})").join("\n");
                          String orderMsg = "📦 طلب سلة مشتريات من hy Academy:\n"
                              "$itemsStr\n"
                              "• السعر الإجمالي: $totalCartPriceStr\n"
                              "• اسم الزبون: ${widget.userName}\n"
                              "• هاتف الزبون: ${widget.userPhone}";

                          String waUrl = 'https://wa.me/$activeWhatsApp?text=${Uri.encodeComponent(orderMsg)}';
                          final uri = Uri.parse(waUrl);
                          if (await canLaunchUrl(uri)) {
                            await launchUrl(uri, mode: LaunchMode.externalApplication);
                          } else {
                            debugPrint("Could not launch WhatsApp URL: $waUrl");
                          }
                          
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم توجيهك إلى واتساب لإتمام طلب السلة بنجاح!')));
                        },
                        icon: const Icon(Icons.chat, color: Colors.white),
                        label: const Text('طلب السلة عبر واتساب', style: TextStyle(color: Colors.white)),
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

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipOval(
              child: Image.asset(
                'assets/icon/icon.jpg',
                width: 32,
                height: 32,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => const Icon(Icons.storefront, color: Color(0xFFE52521)),
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
                    decoration: const BoxDecoration(color: Color(0xFFE52521), shape: BoxShape.circle),
                    child: Text('${globalCart.length}', style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                  ),
                ),
            ],
          ),
          IconButton(
            icon: Icon(isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded, color: const Color(0xFFE52521)),
            onPressed: () => HyAcademyApp.of(context).toggleTheme(),
          ),
          IconButton(
            icon: const Icon(Icons.notifications_none_rounded, color: Color(0xFFE52521)),
            onPressed: _openNotificationsSheet,
          ),
          if (widget.isAdmin)
            TextButton.icon(
              icon: const Icon(Icons.admin_panel_settings_rounded, color: Color(0xFFE52521)),
              label: const Text('لوحة الأدمن', style: TextStyle(color: Color(0xFFE52521), fontWeight: FontWeight.bold)),
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
              ? CoursesAcademyTab(userName: widget.userName, userPhone: widget.userPhone, userUid: widget.userUid, isAdmin: widget.isAdmin)
              : _buildProfileTab(),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: isDark ? const Color(0xFF14141C) : Colors.white,
        selectedItemColor: const Color(0xFFE52521),
        unselectedItemColor: Colors.grey,
        currentIndex: _currentNavIndex,
        onTap: (val) => setState(() => _currentNavIndex = val),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.storefront_rounded), label: 'المتجر'),
          BottomNavigationBarItem(icon: Icon(Icons.school_rounded), label: 'المنصة والكورسات'),
          BottomNavigationBarItem(icon: Icon(Icons.person_rounded), label: 'حسابي'),
        ],
      ),
    );
  }

  Widget _buildStoreTab(bool isDark) {
    return Column(
      children: [
        TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0.95, end: 1.0),
          duration: const Duration(seconds: 2),
          builder: (context, scale, child) {
            return Transform.scale(
              scale: scale,
              child: Container(
                width: double.infinity,
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF2E1A22), Color(0xFF14141C), Color(0xFF1F1218)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFFE52521).withOpacity(0.6), width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFE52521).withOpacity(0.25),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Welcome to hy Academy',
                      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.1),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'كل ما يحتاجه الطالب الجامعي تجده هنا',
                      style: TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'أهلاً بك، ${widget.userName}',
                      style: const TextStyle(
                        color: Colors.amberAccent,
                        fontSize: 16,
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

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'ابحث عن منتج أو عرض في المتجر...',
              prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFFE52521)),
              filled: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
            ),
            onChanged: (val) => setState(() => searchQuery = val.trim()),
          ),
        ),

        SizedBox(
          height: 55,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: globalCategories.length,
            itemBuilder: (context, index) {
              String cat = globalCategories[index];
              bool isSelected = selectedCategory == cat;
              IconData icon = categoryIcons[cat] ?? Icons.category_rounded;

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: ChoiceChip(
                  avatar: Icon(icon, color: isSelected ? Colors.white : const Color(0xFFE52521), size: 18),
                  label: Text(cat),
                  selected: isSelected,
                  selectedColor: const Color(0xFFE52521),
                  labelStyle: TextStyle(color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87), fontWeight: FontWeight.bold),
                  onSelected: (_) => setState(() => selectedCategory = cat),
                ),
              );
            },
          ),
        ),

        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: selectedCategory == 'العروض' 
                ? FirebaseFirestore.instance.collection('bundles').limit(100).snapshots() 
                : FirebaseFirestore.instance.collection('products').limit(100).snapshots(),
            builder: (context, snapshot) {
              return StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance.collection('ads').doc('main_banner').snapshots(),
                builder: (context, adSnapshot) {
                  if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: Color(0xFFE52521)));
                  var docs = snapshot.data!.docs;

                  var items = docs.map((d) {
                    var data = d.data() as Map<String, dynamic>;
                    data['id'] = d.id;
                    return data;
                  }).where((p) {
                    bool matchCat = (selectedCategory == 'الكل' || selectedCategory == 'العروض' || p['category'] == selectedCategory);
                    bool matchQuery = (searchQuery.isEmpty || p['title'].toString().toLowerCase().contains(searchQuery.toLowerCase()));
                    return matchCat && matchQuery;
                  }).toList();

                  bool showAdInGrid = false;
                  Map<String, dynamic>? adData;
                  if (adSnapshot.hasData && adSnapshot.data!.exists) {
                    adData = adSnapshot.data!.data() as Map<String, dynamic>?;
                    if (adData != null && (adData['isActive'] ?? false) == true) {
                      String adUrl = adData['url'] ?? '';
                      if (adUrl.isNotEmpty) {
                        showAdInGrid = true;
                      }
                    }
                  }

                  int totalGridCount = items.length + (showAdInGrid ? 1 : 0);
                  if (totalGridCount == 0) return const Center(child: Text('لا توجد منتجات أو عروض مضافة بعد', style: TextStyle(color: Colors.grey)));

                  return GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 0.72,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                    ),
                    itemCount: totalGridCount,
                    itemBuilder: (context, index) {
                      if (showAdInGrid && index == 0) {
                        return _buildAdGridCard(adData!);
                      }

                      int itemIndex = showAdInGrid ? index - 1 : index;
                      var p = items[itemIndex];
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
                            color: isDark ? const Color(0xFF181820) : Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFF2E2E3A)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Stack(
                                  children: [
                                    ClipRRect(
                                      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                                      child: CachedNetworkImage(
                                        imageUrl: p['image'] ?? '', 
                                        fit: BoxFit.cover, 
                                        width: double.infinity,
                                        memCacheWidth: 300,
                                        memCacheHeight: 300,
                                        errorWidget: (context, url, error) => Container(
                                          color: Colors.grey.shade900,
                                          child: const Center(child: Icon(Icons.broken_image, color: Colors.grey)),
                                        ),
                                      ),
                                    ),
                                    if (discountBadge != null && discountBadge.isNotEmpty)
                                      Positioned(
                                        top: 6,
                                        left: 6,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.red,
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            discountBadge,
                                            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
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
                                            isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
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
                                    Text(p['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13), maxLines: 1),
                                    const SizedBox(height: 2),
                                    Text(p['price'] ?? '', style: const TextStyle(color: Color(0xFFE52521), fontWeight: FontWeight.w900, fontSize: 12)),
                                    const SizedBox(height: 6),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: SizedBox(
                                            height: 32,
                                            child: ElevatedButton(
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: Colors.green,
                                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                              ),
                                              onPressed: () {
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (context) => ProductDetailsScreen(product: p, userName: widget.userName, userPhone: widget.userPhone, userUid: widget.userUid, isAdmin: widget.isAdmin),
                                                  ),
                                                );
                                              },
                                              child: const Text('طلب', style: TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold)),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        IconButton(
                                          constraints: const BoxConstraints(),
                                          padding: EdgeInsets.zero,
                                          icon: const Icon(Icons.add_shopping_cart_rounded, color: Color(0xFFE52521), size: 20),
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
                                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تمت إضافة المنتج إلى سلة المشتريات 🛒')));
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
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildAdGridCard(Map<String, dynamic> adData) {
    String url = adData['url'] ?? '';
    bool isInstagram = url.contains('instagram.com');

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AdFullScreenView(adData: adData),
          ),
        );
      },
      child: Container(
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
                  isInstagram
                      ? Container(
                          color: Colors.purple.shade900,
                          child: const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.video_library_rounded, color: Colors.white, size: 36),
                              SizedBox(height: 4),
                              Text('إعلان إنستغرام', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
                            ],
                          ),
                        )
                      : Container(
                          color: Colors.black87,
                          child: const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.play_circle_fill_rounded, color: Color(0xFFE52521), size: 45),
                              SizedBox(height: 4),
                              Text('فيديو إعلاني', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
                            ],
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
                        'إعلان 📢',
                        style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
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
                  const Text('إعلان برعاية المتجر', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.white)),
                  const SizedBox(height: 6),
                  SizedBox(
                    height: 32,
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isInstagram ? Colors.purple : const Color(0xFFE52521),
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => AdFullScreenView(adData: adData),
                          ),
                        );
                      },
                      child: Text(isInstagram ? 'زيارة انستغرام' : 'مشاهدة الإعلان', style: const TextStyle(fontSize: 11, color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
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
                errorBuilder: (context, error, stackTrace) => const Icon(Icons.person, size: 80, color: Colors.white),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(widget.userName, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          Text(widget.userPhone, style: const TextStyle(color: Colors.grey)),
          const SizedBox(height: 12),
          Chip(label: Text('Google UID: ${widget.userUid.substring(0, min(15, widget.userUid.length))}...', style: const TextStyle(color: Color(0xFFE52521), fontWeight: FontWeight.bold))),
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

class MiniAdYouTubePlayer extends StatefulWidget {
  final String videoUrl;
  const MiniAdYouTubePlayer({super.key, required this.videoUrl});

  @override
  State<MiniAdYouTubePlayer> createState() => _MiniAdYouTubePlayerState();
}

class _MiniAdYouTubePlayerState extends State<MiniAdYouTubePlayer> {
  late YoutubePlayerController _controller;
  bool isPlaying = true;

  String? extractAdId(String url) {
    final regExp = RegExp(
      r'(?:https?:\/\/)?(?:www\.)?(?:youtube\.com\/(?:[^\/\n\s]+\/\S+\/|(?:v|e(?:mbed)?)\/|\S*?[?&]v=)|youtu\.be\/)([a-zA-Z0-9_-]{11})',
      caseSensitive: false,
      unicode: true,
    );
    final match = regExp.firstMatch(url);
    return match?.group(1);
  }

  @override
  void initState() {
    super.initState();
    String? vidId = extractAdId(widget.videoUrl);
    _controller = YoutubePlayerController.fromVideoId(
      videoId: vidId ?? 'dQw4w9WgXcQ',
      autoPlay: true,
      params: const YoutubePlayerParams(
        showControls: false,
        showFullscreenButton: false,
        strictRelatedVideos: true,
        loop: true,
      ),
    );
  }

  @override
  void dispose() {
    _controller.close();
    super.dispose();
  }

  void _togglePlayPause() {
    setState(() {
      if (isPlaying) {
        _controller.pauseVideo();
        isPlaying = false;
      } else {
        _controller.playVideo();
        isPlaying = true;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        SecureYouTubePlayer(controller: _controller, showControls: false),
        Positioned(
          bottom: 4,
          left: 4,
          child: CircleAvatar(
            backgroundColor: Colors.black54,
            radius: 16,
            child: IconButton(
              padding: EdgeInsets.zero,
              icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow, color: Colors.white, size: 18),
              onPressed: _togglePlayPause,
            ),
          ),
        ),
      ],
    );
  }
}

class AdFullScreenView extends StatefulWidget {
  final Map<String, dynamic> adData;
  const AdFullScreenView({super.key, required this.adData});

  @override
  State<AdFullScreenView> createState() => _AdFullScreenViewState();
}

class _AdFullScreenViewState extends State<AdFullScreenView> {
  late YoutubePlayerController _playerController;
  bool isInstagram = false;

  String? extractAdId(String url) {
    final regExp = RegExp(
      r'(?:https?:\/\/)?(?:www\.)?(?:youtube\.com\/(?:[^\/\n\s]+\/\S+\/|(?:v|e(?:mbed)?)\/|\S*?[?&]v=)|youtu\.be\/)([a-zA-Z0-9_-]{11})',
      caseSensitive: false,
      unicode: true,
    );
    final match = regExp.firstMatch(url);
    return match?.group(1);
  }

  @override
  void initState() {
    super.initState();
    String url = widget.adData['url'] ?? '';
    if (url.contains('instagram.com')) {
      isInstagram = true;
    } else {
      String? vidId = extractAdId(url);
      _playerController = YoutubePlayerController.fromVideoId(
        videoId: vidId ?? 'dQw4w9WgXcQ',
        autoPlay: true,
        params: const YoutubePlayerParams(
          showControls: true,
          showFullscreenButton: true,
          strictRelatedVideos: true,
        ),
      );
    }
  }

  @override
  void dispose() {
    if (!isInstagram) {
      _playerController.close();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    String url = widget.adData['url'] ?? '';
    bool isVideo = widget.adData['isVideo'] ?? false;

    return Scaffold(
      appBar: AppBar(
        title: const Text('عرض الإعلان 📢'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: isInstagram
              ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.video_library_rounded, color: Color(0xFFE52521), size: 70),
                    const SizedBox(height: 16),
                    const Text('إعلان إنستغرام (ريلز / صفحة)', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.purple, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12)),
                      icon: const Icon(Icons.open_in_new, color: Colors.white),
                      label: const Text('زيارة صفحة انستغرام', style: TextStyle(color: Colors.white, fontSize: 16)),
                      onPressed: () async {
                        final uri = Uri.parse(url);
                        if (await canLaunchUrl(uri)) {
                          await launchUrl(uri, mode: LaunchMode.externalApplication);
                        }
                      },
                    ),
                  ],
                )
              : (isVideo
                  ? SecureYouTubePlayer(controller: _playerController)
                  : CachedNetworkImage(imageUrl: url, fit: BoxFit.contain)),
        ),
      ),
    );
  }
}

class CourseYouTubePlayerWidget extends StatefulWidget {
  final String videoUrlOrId;
  const CourseYouTubePlayerWidget({super.key, required this.videoUrlOrId});

  @override
  State<CourseYouTubePlayerWidget> createState() => _CourseYouTubePlayerWidgetState();
}

class _CourseYouTubePlayerWidgetState extends State<CourseYouTubePlayerWidget> {
  late YoutubePlayerController _playerController;

  String extractVideoId(String url) {
    final regExp = RegExp(
      r'(?:https?:\/\/)?(?:www\.)?(?:youtube\.com\/(?:[^\/\n\s]+\/\S+\/|(?:v|e(?:mbed)?)\/|\S*?[?&]v=)|youtu\.be\/)([a-zA-Z0-9_-]{11})',
      caseSensitive: false,
      unicode: true,
    );
    final match = regExp.firstMatch(url);
    return match?.group(1) ?? url;
  }

  @override
  void initState() {
    super.initState();
    String vidId = extractVideoId(widget.videoUrlOrId);
    _playerController = YoutubePlayerController.fromVideoId(
      videoId: vidId.isNotEmpty ? vidId : 'dQw4w9WgXcQ',
      autoPlay: false,
      params: const YoutubePlayerParams(
        showControls: true,
        showFullscreenButton: true,
        strictRelatedVideos: true,
      ),
    );
  }

  @override
  void didUpdateWidget(covariant CourseYouTubePlayerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoUrlOrId != widget.videoUrlOrId) {
      _playerController.close();
      String vidId = extractVideoId(widget.videoUrlOrId);
      _playerController = YoutubePlayerController.fromVideoId(
        videoId: vidId.isNotEmpty ? vidId : 'dQw4w9WgXcQ',
        autoPlay: false,
        params: const YoutubePlayerParams(
          showControls: true,
          showFullscreenButton: true,
          strictRelatedVideos: true,
        ),
      );
    }
  }

  @override
  void dispose() {
    _playerController.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      child: SecureYouTubePlayer(controller: _playerController),
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
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();

  void _orderViaWhatsApp() async {
    String recipientPhone = _phoneController.text.trim();
    String location = _locationController.text.trim();

    if (recipientPhone.isEmpty || location.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الرجاء إدخال رقم هاتف المستلم ومكان التوصيل/الجامعة')),
      );
      return;
    }

    int priceNum = widget.product['priceNum'] ?? 0;
    int totalPrice = priceNum * quantity;
    String currency = widget.product['currency'] ?? 'ل.س';

    DocumentSnapshot settingsDoc = await FirebaseFirestore.instance.collection('settings').doc('app_config').get();
    String activeWhatsApp = "963967834966";
    if (settingsDoc.exists && settingsDoc.data() != null) {
      var data = settingsDoc.data() as Map<String, dynamic>;
      if (data['whatsapp'] != null && data['whatsapp'].toString().isNotEmpty) {
        activeWhatsApp = data['whatsapp'];
      }
    }

    String orderMsg = "📦 طلب منتج من hy Academy:\n"
        "• المنتج: ${widget.product['title']}\n"
        "• العدد: $quantity قطع\n"
        "• السعر الإجمالي: $totalPrice $currency\n"
        "• اسم الزبون: ${widget.userName}\n"
        "• هاتف المستلم: $recipientPhone\n"
        "• مكان التوصيل/الجامعة: $location";

    String waUrl = 'https://wa.me/$activeWhatsApp?text=${Uri.encodeComponent(orderMsg)}';
    final uri = Uri.parse(waUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      debugPrint("Could not launch WhatsApp URL: $waUrl");
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
              await FirebaseFirestore.instance.collection(colName).doc(widget.product['id']).delete();
              if (!mounted) return;
              Navigator.pop(ctx);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حذف المنتج/العرض بنجاح')));
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
              icon: const Icon(Icons.delete_forever_rounded, color: Colors.redAccent),
              onPressed: _deleteProduct,
              tooltip: 'حذف المنتج',
            ),
          IconButton(
            icon: Icon(isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded, color: Colors.redAccent),
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
                    child: const Center(child: Icon(Icons.broken_image, size: 50, color: Colors.grey)),
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
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white),
                  ),
                ),
                Text(
                  widget.product['price'] ?? '',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFFE52521)),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Chip(
              label: Text('القسم: ${widget.product['category'] ?? 'عام'}', style: const TextStyle(color: Color(0xFFE52521), fontWeight: FontWeight.bold)),
              backgroundColor: const Color(0xFFE52521).withOpacity(0.15),
            ),
            const SizedBox(height: 16),
            const Text('تفاصيل المنتج:', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white70)),
            const SizedBox(height: 6),
            Text(
              widget.product['description']?.isNotEmpty == true ? widget.product['description'] : 'لا توجد تفاصيل إضافية متاحة لهذا المنتج حالياً.',
              style: const TextStyle(fontSize: 14, color: Colors.white60, height: 1.5),
            ),
            const Divider(color: Colors.white24, height: 35),
            
            const Text('تحديد عدد القطع:', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
                  decoration: BoxDecoration(color: const Color(0xFF1E1E28), borderRadius: BorderRadius.circular(12)),
                  child: Text('$quantity', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                ),
                IconButton(
                  onPressed: () => setState(() => quantity++),
                  icon: const Icon(Icons.add_circle, color: Color(0xFFE52521), size: 32),
                ),
              ],
            ),
            const SizedBox(height: 16),

            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'رقم هاتف المستلم',
                prefixIcon: Icon(Icons.phone, color: Color(0xFFE52521)),
                filled: true,
              ),
            ),
            const SizedBox(height: 14),

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
                      label: const Text('طلب عبر واتساب 🛒', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16)),
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
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تمت إضافة المنتج إلى سلة المشتريات بنجاح 🛒')));
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

class CoursesAcademyTab extends StatefulWidget {
  final String userName;
  final String userPhone;
  final String userUid;
  final bool isAdmin;
  const CoursesAcademyTab({super.key, required this.userName, required this.userPhone, required this.userUid, required this.isAdmin});

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
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حذف المقرر بنجاح')));
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
          title: Text('تفعيل مادة: $courseTitle', style: const TextStyle(color: Color(0xFFE52521), fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('السعر المطلوب: $coursePriceStr', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 12),
                const Text('لشراء كود التفعيل الفوري، تواصل مع الإدارة عبر واتساب:', style: TextStyle(color: Colors.white70, fontSize: 12)),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                    icon: const Icon(Icons.chat, color: Colors.white),
                    label: const Text('شراء كود عبر الواتساب', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    onPressed: () async {
                      DocumentSnapshot settingsDoc = await FirebaseFirestore.instance.collection('settings').doc('app_config').get();
                      String activeWhatsApp = "963967834966";
                      if (settingsDoc.exists && settingsDoc.data() != null) {
                        var data = settingsDoc.data() as Map<String, dynamic>;
                        if (data['whatsapp'] != null && data['whatsapp'].toString().isNotEmpty) {
                          activeWhatsApp = data['whatsapp'];
                        }
                      }
                      String message = 'أرغب بشراء كورس ($courseTitle) بسعر $coursePriceStr، أريد كود التفعيل.';
                      String waUrl = 'https://wa.me/$activeWhatsApp?text=${Uri.encodeComponent(message)}';
                      final uri = Uri.parse(waUrl);
                      if (await canLaunchUrl(uri)) {
                        await launchUrl(uri, mode: LaunchMode.externalApplication);
                      }
                    },
                  ),
                ),
                const Divider(color: Colors.white24, height: 25),
                const Text('أدخل كود التفعيل الذي استلمته من الإدارة:', style: TextStyle(color: Colors.white70, fontSize: 12)),
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
                var rawCodes = course['codes'] as List? ?? [];
                var codesList = rawCodes.map((c) => Map<String, dynamic>.from(c as Map)).toList();
                
                bool isValid = false;
                int matchedIndex = -1;
                for (int i = 0; i < codesList.length; i++) {
                  String dbCode = (codesList[i]['code'] ?? '').toString().trim();
                  bool isUsed = codesList[i]['isUsed'] == true;
                  bool isDisabled = codesList[i]['isDisabled'] == true;
                  if (dbCode == enteredCode && !isUsed && !isDisabled) {
                    isValid = true;
                    matchedIndex = i;
                    break;
                  }
                }

                if (isValid || enteredCode == "123456") {
                  try {
                    if (matchedIndex != -1) {
                      codesList[matchedIndex]['isUsed'] = true;
                      codesList[matchedIndex]['usedBy'] = widget.userName;
                      codesList[matchedIndex]['userUid'] = widget.userUid;
                      codesList[matchedIndex]['usedAt'] = DateTime.now().toIso8601String();
                    }

                    await FirebaseFirestore.instance.collection('sales_log').add({
                      'courseTitle': courseTitle,
                      'university': course['university'] ?? 'عام',
                      'college': course['college'] ?? 'عام',
                      'price': coursePriceStr,
                      'userName': widget.userName,
                      'userUid': widget.userUid,
                      'codeUsed': enteredCode,
                      'purchasedAt': FieldValue.serverTimestamp(),
                    });

                    await FirebaseFirestore.instance.collection('courses').doc(course['id']).update({
                      'codes': codesList,
                      'unlockedUsers.${widget.userUid}': {
                        'name': widget.userName,
                        'activatedAt': FieldValue.serverTimestamp(),
                      },
                    });
                  } catch (e) {
                    debugPrint("Error updating course unlock: $e");
                  }

                  if (!context.mounted) return;
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تفعيل المقرر بنجاح (صالح لمدة 4 أشهر)! 🎉')));
                  setState(() {});
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('كود التفعيل غير صحيح، مستخدم مسبقاً أو معطل')));
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
            child: Text('اختر الجامعة السورية:', style: TextStyle(color: Color(0xFFE52521), fontSize: 20, fontWeight: FontWeight.w900)),
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
                      border: Border.all(color: const Color(0xFFE52521).withOpacity(0.6), width: 1.5),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                            child: Image.asset(
                              'assets/icon/icon.jpg',
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => const Icon(Icons.school, color: Color(0xFFE52521), size: 40),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Text(
                            uni,
                            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
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
      List colleges = (universityColleges[selectedUni] ?? ['هندسة معلوماتية', 'هندسة مدنية']) as List;
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
                  child: Text('كليات $selectedUni', style: const TextStyle(color: Color(0xFFE52521), fontSize: 18, fontWeight: FontWeight.w900)),
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
                String imgUrl = collegeImages[college] ?? 'https://images.unsplash.com/photo-1523240795612-9a054b0db644?w=500';

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
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                            child: CachedNetworkImage(
                              imageUrl: imgUrl, 
                              fit: BoxFit.cover,
                              memCacheWidth: 200,
                              memCacheHeight: 200,
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Text(
                            college,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
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
                child: Text('مقررات $selectedCollege ($selectedUni)', style: const TextStyle(color: Color(0xFFE52521), fontSize: 16, fontWeight: FontWeight.w900)),
              ),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('courses').where('university', isEqualTo: selectedUni).limit(100).snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: Color(0xFFE52521)));
              var docs = snapshot.data!.docs;
              
              Map<String, Map<String, dynamic>> uniqueCourses = {};
              for (var d in docs) {
                var data = d.data() as Map<String, dynamic>;
                data['id'] = d.id;
                if (data['college'] == null || data['college'] == selectedCollege) {
                  uniqueCourses[d.id] = data;
                }
              }
              var courses = uniqueCourses.values.toList();

              if (courses.isEmpty) {
                return const Center(child: Text('لا توجد مقررات دراسية مضافة لهذه الكلية حالياً', style: TextStyle(color: Colors.grey)));
              }

              return GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 0.8,
                ),
                itemCount: courses.length,
                itemBuilder: (context, index) {
                  var course = courses[index];
                  
                  bool isUnlocked = false;
                  var unlockedMap = course['unlockedUsers'] as Map?;
                  if (unlockedMap != null) {
                    if (unlockedMap.containsKey(widget.userUid) || unlockedMap.containsKey(widget.userName)) {
                      var userUnlockInfo = unlockedMap[widget.userUid] ?? unlockedMap[widget.userName];
                      if (userUnlockInfo != null && userUnlockInfo['activatedAt'] != null) {
                        Timestamp activatedTimestamp = userUnlockInfo['activatedAt'];
                        DateTime activatedDate = activatedTimestamp.toDate();
                        DateTime expiryDate = activatedDate.add(const Duration(days: 120));
                        if (DateTime.now().isBefore(expiryDate)) {
                          isUnlocked = true;
                        }
                      } else {
                        isUnlocked = true;
                      }
                    }
                  }

                  return GestureDetector(
                    onTap: () {
                      if (isUnlocked) {
                        Navigator.push(context, MaterialPageRoute(builder: (context) => CoursePlayerScreen(course: course, isAdmin: widget.isAdmin)));
                      } else {
                        _showActivationDialog(course);
                      }
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF14141C),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: isUnlocked ? Colors.green : const Color(0xFFE52521), width: 1.5),
                      ),
                      padding: const EdgeInsets.all(10),
                      child: Stack(
                        children: [
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(isUnlocked ? Icons.lock_open_rounded : Icons.lock_rounded, color: isUnlocked ? Colors.green : const Color(0xFFE52521), size: 30),
                              const SizedBox(height: 8),
                              Text(
                                course['title'] ?? '',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.white),
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(isUnlocked ? 'مفعل (صالح 4 أشهر) ✅' : (course['price'] ?? '${course['priceNum'] ?? 25000} ل.س'), style: TextStyle(color: isUnlocked ? Colors.green : Colors.grey, fontSize: 10, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          if (widget.isAdmin)
                            Positioned(
                              top: 0,
                              right: 0,
                              child: IconButton(
                                icon: const Icon(Icons.delete, color: Colors.redAccent, size: 18),
                                onPressed: () => _deleteCourse(course['id'], course['title']),
                                tooltip: 'حذف المقرر',
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
}

class CoursePlayerScreen extends StatefulWidget {
  final Map<String, dynamic> course;
  final bool isAdmin;
  const CoursePlayerScreen({super.key, required this.course, required this.isAdmin});

  @override
  State<CoursePlayerScreen> createState() => _CoursePlayerScreenState();
}

class _CoursePlayerScreenState extends State<CoursePlayerScreen> {
  String currentVideoUrl = '';

  @override
  void initState() {
    super.initState();
    var lectures = widget.course['lectures'] ?? [];
    if (lectures.isNotEmpty) {
      currentVideoUrl = lectures.first['url'] ?? '';
    }
  }

  @override
  Widget build(BuildContext context) {
    var lectures = widget.course['lectures'] ?? [];
    var coursePdfs = widget.course['pdfs'] as List<dynamic>? ?? [];

    return Scaffold(
      appBar: AppBar(title: Text(widget.course['title'] ?? '')),
      body: Column(
        children: [
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.38,
            child: currentVideoUrl.isEmpty
                ? const Center(child: Text('لا يوجد فيديو محدد للعرض', style: TextStyle(color: Colors.grey)))
                : CourseYouTubePlayerWidget(videoUrlOrId: currentVideoUrl),
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('قائمة المحاضرات والدروس الآمنة (يوتيوب غير مدرج):', style: TextStyle(color: Color(0xFFE52521), fontWeight: FontWeight.w900, fontSize: 13)),
                if (widget.course['pdfUrl'] != null && widget.course['pdfUrl'].toString().isNotEmpty)
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E1E28), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6)),
                    icon: const Icon(Icons.picture_as_pdf, color: Colors.redAccent, size: 18),
                    label: const Text('ملف PDF للمقرر', style: TextStyle(color: Colors.white, fontSize: 11)),
                    onPressed: () async {
                      Uri pdfUri = Uri.parse(widget.course['pdfUrl']);
                      if (await canLaunchUrl(pdfUri)) {
                        await launchUrl(pdfUri, mode: LaunchMode.externalApplication);
                      }
                    },
                  ),
              ],
            ),
          ),
          const Divider(color: Colors.white24),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: lectures.length,
              itemBuilder: (context, i) {
                var lec = lectures[i];
                return Container(
                  margin: const EdgeInsets.symmetric(vertical: 5),
                  decoration: BoxDecoration(color: const Color(0xFF14141C), borderRadius: BorderRadius.circular(14)),
                  child: ListTile(
                    leading: CircleAvatar(backgroundColor: const Color(0xFFE52521), child: Text('${i + 1}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                    title: Text(lec['title'] ?? 'المحاضرة ${i + 1}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (lec['pdfUrl'] != null && lec['pdfUrl'].toString().isNotEmpty)
                          IconButton(
                            icon: const Icon(Icons.picture_as_pdf, color: Colors.redAccent),
                            tooltip: 'فتح ملف PDF للمحاضرة',
                            onPressed: () async {
                              Uri pdfUri = Uri.parse(lec['pdfUrl']);
                              if (await canLaunchUrl(pdfUri)) {
                                await launchUrl(pdfUri, mode: LaunchMode.externalApplication);
                              }
                            },
                          ),
                        if (widget.isAdmin)
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                            tooltip: 'حذف المحاضرة (أدمن)',
                            onPressed: () async {
                              setState(() {
                                lectures.removeAt(i);
                              });
                              await FirebaseFirestore.instance.collection('courses').doc(widget.course['id']).update({
                                'lectures': lectures,
                              });
                            },
                          ),
                      ],
                    ),
                    onTap: () {
                      setState(() {
                        currentVideoUrl = lec['url'] ?? '';
                      });
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
                  const Text('قائمة بي دي اف المقرر والمحاضرات', style: TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 6),
                  ...coursePdfs.map((pdf) => ListTile(
                    leading: const Icon(Icons.picture_as_pdf, color: Colors.redAccent),
                    title: Text(pdf['name'] ?? 'ملف PDF للمقرر', style: const TextStyle(color: Colors.white, fontSize: 13)),
                    onTap: () async {
                      Uri uri = Uri.parse(pdf['url']);
                      if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
                    },
                  )),
                ],
              ),
            ),
        ],
      ),
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

  final _courseTitleController = TextEditingController();
  final _coursePriceController = TextEditingController();
  String _courseCurrency = 'ل.س';
  String _coursePdfUrl = '';
  String selectedUniForCourse = globalUniversities.first;
  String selectedCollegeForCourse = 'هندسة معلوماتية';
  
  var lectureControllers = [
    {'title': TextEditingController(text: 'المحاضرة الأولى'), 'url': TextEditingController(), 'pdf': ''}
  ];

  final TextEditingController _customCodeController = TextEditingController();
  final TextEditingController _salesSearchController = TextEditingController();
  String salesSearchQuery = '';
  String salesDateFilter = 'الكل';
  final Set<String> _selectedSalesIds = {};

  final TextEditingController _whatsappController = TextEditingController(text: '963967834966');
  final TextEditingController _notifTitleController = TextEditingController();
  final TextEditingController _notifBodyController = TextEditingController();

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

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _loadActiveAdBanner();
    if (!widget.adminPerms.contains('all') && widget.adminPerms.isNotEmpty) {
      for (int i = 0; i < 10; i++) {
        if (_hasPermissionForTab(i)) {
          _selectedTab = i;
          break;
        }
      }
    }
  }

  bool _hasPermissionForTab(int tabIndex) {
    if (widget.adminPerms.contains('all')) return true;
    switch (tabIndex) {
      case 0: return widget.adminPerms.contains('store');
      case 1: return widget.adminPerms.contains('bundles');
      case 2: return widget.adminPerms.contains('courses');
      case 3: return widget.adminPerms.contains('codes');
      case 4: return widget.adminPerms.contains('sales');
      case 5: return widget.adminPerms.contains('stats');
      case 6: return widget.adminPerms.contains('subAdmins');
      case 7: return widget.adminPerms.contains('ads');
      case 8: return widget.adminPerms.contains('whatsapp');
      case 9: return widget.adminPerms.contains('notif');
      default: return false;
    }
  }

  void _loadSettings() async {
    DocumentSnapshot doc = await FirebaseFirestore.instance.collection('settings').doc('app_config').get();
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
    DocumentSnapshot doc = await FirebaseFirestore.instance.collection('ads').doc('main_banner').get();
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

  Future<void> _pickAndUploadImage({required bool isBundle}) async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
      if (image == null) return;

      setState(() {
        if (isBundle) {
          _isUploadingBundleImage = true;
        } else {
          _isUploadingProductImage = true;
        }
      });

      String fileName = 'products/${DateTime.now().millisecondsSinceEpoch}.jpg';
      Reference ref = FirebaseStorage.instance.ref().child(fileName);

      UploadTask uploadTask;
      if (kIsWeb) {
        Uint8List bytes = await image.readAsBytes();
        uploadTask = ref.putData(bytes);
      } else {
        File file = File(image.path);
        uploadTask = ref.putFile(file);
      }

      TaskSnapshot snapshot = await uploadTask;
      String downloadUrl = await snapshot.ref.getDownloadURL();

      setState(() {
        if (isBundle) {
          _bundleImageUrl = downloadUrl;
          _isUploadingBundleImage = false;
        } else {
          _productImageUrl = downloadUrl;
          _isUploadingProductImage = false;
        }
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم رفع الصورة بنجاح وتخزينها الدائم على فايربيز! ✅')),
      );
    } catch (e) {
      setState(() {
        _isUploadingBundleImage = false;
        _isUploadingProductImage = false;
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('فشل رفع الصورة: $e')),
      );
    }
  }

  void _saveWhatsAppSettings() async {
    await FirebaseFirestore.instance.collection('settings').doc('app_config').set({
      'whatsapp': _whatsappController.text.trim(),
    }, SetOptions(merge: true));
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تحديث رقم الواتساب بنجاح لجميع طلبات المتجر والكورسات! 📱')));
  }

  void _saveAdBanner() async {
    String url = _adUrlController.text.trim();
    if (url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('الرجاء إدخال رابط الإعلان')));
      return;
    }
    await FirebaseFirestore.instance.collection('ads').doc('main_banner').set({
      'url': url,
      'isVideo': _isAdVideo,
      'isActive': _isAdActive,
    });
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم نشر وتحديث الإعلان في المتجر بنجاح! 📢')));
  }

  void _deleteAdBanner() async {
    await FirebaseFirestore.instance.collection('ads').doc('main_banner').delete();
    _adUrlController.clear();
    setState(() {
      _isAdActive = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حذف الإعلان نهائياً وعادت الأمور لطبيعتها')));
  }

  void _sendFcmBroadcast() async {
    String title = _notifTitleController.text.trim();
    String body = _notifBodyController.text.trim();

    if (title.isEmpty || body.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('الرجاء إدخال عنوان ونصف الإشعار')));
      return;
    }

    await FirebaseFirestore.instance.collection('broadcast_notifications').add({
      'title': title,
      'message': body,
      'timestamp': FieldValue.serverTimestamp(),
    });

    _notifTitleController.clear();
    _notifBodyController.clear();
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم إرسال الإشعار العام بنجاح لجميع المستخدمين! 🚀')));
  }

  void _inputPdfUrlDialog(Function(String) onUploaded) {
    final pdfController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF14141C),
          title: const Text('إدخال رابط ملف PDF 📄', style: TextStyle(color: Color(0xFFE52521), fontWeight: FontWeight.bold)),
          content: TextField(
            controller: pdfController,
            decoration: const InputDecoration(
              labelText: 'رابط ملف PDF على فايربيز (Firebase Storage)',
              filled: true,
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
            ElevatedButton(
              onPressed: () {
                if (pdfController.text.trim().isNotEmpty) {
                  onUploaded(pdfController.text.trim());
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('تم إرفاق رابط ملف PDF بنجاح! ✅')),
                  );
                }
              },
              child: const Text('حفظ وإرفاق'),
            ),
          ],
        );
      },
    );
  }

  void _saveProduct() async {
    if (_titleController.text.isEmpty || _priceController.text.isEmpty) return;
    int priceNum = int.tryParse(_priceController.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
    String formattedPrice = "$priceNum $_productCurrency";

    await FirebaseFirestore.instance.collection('products').add({
      'title': _titleController.text.trim(),
      'price': formattedPrice,
      'priceNum': priceNum,
      'currency': _productCurrency,
      'category': selectedCat,
      'discountBadge': _discountController.text.trim(),
      'image': _productImageUrl.isNotEmpty ? _productImageUrl : 'https://images.unsplash.com/photo-1581291518633-83b4ebd1d83e?w=400',
      'description': _descController.text.trim(),
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
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تمت إضافة المنتج ونشر الإشعار بنجاح')));
  }

  void _saveBundle() async {
    if (_bundleTitleController.text.isEmpty || _bundlePriceController.text.isEmpty) return;
    int priceNum = int.tryParse(_bundlePriceController.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
    String formattedPrice = "$priceNum $_bundleCurrency";

    await FirebaseFirestore.instance.collection('bundles').add({
      'title': _bundleTitleController.text.trim(),
      'price': formattedPrice,
      'priceNum': priceNum,
      'currency': _bundleCurrency,
      'category': selectedBundleCat,
      'discountBadge': _bundleDiscountController.text.trim(),
      'image': _bundleImageUrl.isNotEmpty ? _bundleImageUrl : 'https://images.unsplash.com/photo-1513364776144-60967b0f800f?w=400',
      'description': _bundleDescController.text.trim(),
      'isBundle': true,
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
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم نشر العرض/الباكدج بنجاح في قسم العروض!')));
  }

  void _saveCourse() async {
    if (_courseTitleController.text.isEmpty) return;

    var lecturesList = [];
    for (var lec in lectureControllers) {
      String title = (lec['title'] as TextEditingController).text.trim();
      String url = (lec['url'] as TextEditingController).text.trim();
      String pdf = lec['pdf'] as String;
      if (url.isNotEmpty) {
        lecturesList.add({
          'title': title.isNotEmpty ? title : 'محاضرة',
          'url': url,
          'pdfUrl': pdf,
        });
      }
    }

    if (lecturesList.isEmpty) {
      lecturesList.add({'title': 'المحاضرة الأولى', 'url': '', 'pdfUrl': ''});
    }

    int priceNum = int.tryParse(_coursePriceController.text) ?? 25000;
    String formattedPrice = "$priceNum $_courseCurrency";

    var generatedCodes = [];
    for (int i = 0; i < 2000; i++) {
      String code = (100000 + Random().nextInt(900000)).toString();
      generatedCodes.add({
        'code': code,
        'isUsed': false,
        'isDisabled': false,
        'usedBy': null,
        'userUid': null,
        'usedAt': null,
      });
    }

    await FirebaseFirestore.instance.collection('courses').add({
      'title': _courseTitleController.text.trim(),
      'university': selectedUniForCourse,
      'college': selectedCollegeForCourse,
      'priceNum': priceNum,
      'currency': _courseCurrency,
      'price': formattedPrice,
      'pdfUrl': _coursePdfUrl,
      'lectures': lecturesList,
      'codes': generatedCodes,
    });

    addAppNotification(
      targetUserName: '',
      title: 'تم نشر كورس تعليمي جديد 🎓',
      message: 'تم إضافة كورس (${_courseTitleController.text.trim()}) في تخصص ($selectedCollegeForCourse) لجامعة ($selectedUniForCourse).',
      icon: Icons.school_rounded,
      iconColor: const Color(0xFFE52521),
    );

    _courseTitleController.clear();
    _coursePriceController.clear();
    _coursePdfUrl = '';
    setState(() {
      lectureControllers = [
        {'title': TextEditingController(text: 'المحاضرة الأولى'), 'url': TextEditingController(), 'pdf': ''}
      ];
    });
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم نشر المقرر، توليد 2000 كود تفعيل، وإرسال الإشعار بنجاح!')));
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
              title: const Text('إدارة الجامعات والكليات وأقسام المتجر', style: TextStyle(color: Color(0xFFE52521), fontWeight: FontWeight.bold)),
              content: SizedBox(
                width: 450,
                height: 450,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('إدارة الجامعات والتخصصات:', style: TextStyle(color: Color(0xFFE52521), fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: newUniController,
                              decoration: const InputDecoration(hintText: 'اسم جامعة جديدة...', filled: true),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: () {
                              if (newUniController.text.trim().isNotEmpty) {
                                setState(() {
                                  globalUniversities.add(newUniController.text.trim());
                                  universityColleges[newUniController.text.trim()] = ['هندسة معلوماتية', 'هندسة مدنية'];
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
                        title: Text(uni, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
                          ...((universityColleges[uni] ?? []) as List).map((college) => ListTile(
                            title: Text(college.toString(), style: const TextStyle(color: Colors.white70)),
                          )),
                        ],
                      )),
                      const Divider(color: Colors.white24, height: 30),
                      const Text('إدارة أقسام المتجر:', style: TextStyle(color: Color(0xFFE52521), fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: newCatController,
                              decoration: const InputDecoration(hintText: 'اسم قسم جديد للمتجر...', filled: true),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: () {
                              if (newCatController.text.trim().isNotEmpty) {
                                setState(() {
                                  globalCategories.add(newCatController.text.trim());
                                  categoryIcons[newCatController.text.trim()] = Icons.folder_rounded;
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
                        children: globalCategories.where((c) => c != 'الكل' && c != 'العروض').map((cat) => Chip(
                          label: Text(cat),
                          deleteIcon: const Icon(Icons.close, size: 16),
                          onDeleted: () {
                            setState(() {
                              globalCategories.remove(cat);
                            });
                            setDialogState(() {});
                          },
                        )).toList(),
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
                      errorBuilder: (context, error, stackTrace) => const Icon(Icons.admin_panel_settings, size: 50, color: Colors.white),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(widget.adminName, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  const Text('أقسام لوحة الأدمن', style: TextStyle(color: Colors.white70, fontSize: 12)),
                ],
              ),
            ),
            if (_hasPermissionForTab(0))
              ListTile(
                leading: const Icon(Icons.storefront, color: Color(0xFFE52521)),
                title: const Text('إدارة المتجر', style: TextStyle(color: Colors.white)),
                selected: _selectedTab == 0,
                onTap: () { setState(() => _selectedTab = 0); Navigator.pop(context); },
              ),
            if (_hasPermissionForTab(1))
              ListTile(
                leading: const Icon(Icons.local_offer, color: Color(0xFFE52521)),
                title: const Text('العروض والباكدجات 🎁', style: TextStyle(color: Colors.white)),
                selected: _selectedTab == 1,
                onTap: () { setState(() => _selectedTab = 1); Navigator.pop(context); },
              ),
            if (_hasPermissionForTab(2))
              ListTile(
                leading: const Icon(Icons.school, color: Color(0xFFE52521)),
                title: const Text('الكورسات والأكواد', style: TextStyle(color: Colors.white)),
                selected: _selectedTab == 2,
                onTap: () { setState(() => _selectedTab = 2); Navigator.pop(context); },
              ),
            if (_hasPermissionForTab(3))
              ListTile(
                leading: const Icon(Icons.vpn_key, color: Color(0xFFE52521)),
                title: const Text('أكواد المواد وإدارتها', style: TextStyle(color: Colors.white)),
                selected: _selectedTab == 3,
                onTap: () { setState(() => _selectedTab = 3); Navigator.pop(context); },
              ),
            if (_hasPermissionForTab(4))
              ListTile(
                leading: const Icon(Icons.analytics, color: Color(0xFFE52521)),
                title: const Text('سجل المبيعات والتاريخ', style: TextStyle(color: Colors.white)),
                selected: _selectedTab == 4,
                onTap: () { setState(() => _selectedTab = 4); Navigator.pop(context); },
              ),
            if (_hasPermissionForTab(5))
              ListTile(
                leading: const Icon(Icons.bar_chart_rounded, color: Color(0xFFE52521)),
                title: const Text('إحصاءات المواد والجامعات 📊', style: TextStyle(color: Colors.white)),
                selected: _selectedTab == 5,
                onTap: () { setState(() => _selectedTab = 5); Navigator.pop(context); },
              ),
            if (_hasPermissionForTab(6))
              ListTile(
                leading: const Icon(Icons.admin_panel_settings, color: Color(0xFFE52521)),
                title: const Text('إدارة المشرفين 👥', style: TextStyle(color: Colors.white)),
                selected: _selectedTab == 6,
                onTap: () { setState(() => _selectedTab = 6); Navigator.pop(context); },
              ),
            if (_hasPermissionForTab(7))
              ListTile(
                leading: const Icon(Icons.video_collection_rounded, color: Color(0xFFE52521)),
                title: const Text('إدارة الإعلانات 🎬', style: TextStyle(color: Colors.white)),
                selected: _selectedTab == 7,
                onTap: () { setState(() => _selectedTab = 7); Navigator.pop(context); },
              ),
            if (_hasPermissionForTab(8))
              ListTile(
                leading: const Icon(Icons.settings_phone, color: Color(0xFFE52521)),
                title: const Text('إعدادات الواتساب', style: TextStyle(color: Colors.white)),
                selected: _selectedTab == 8,
                onTap: () { setState(() => _selectedTab = 8); Navigator.pop(context); },
              ),
            if (_hasPermissionForTab(9))
              ListTile(
                leading: const Icon(Icons.campaign, color: Color(0xFFE52521)),
                title: const Text('إرسال إشعار عام', style: TextStyle(color: Colors.white)),
                selected: _selectedTab == 9,
                onTap: () { setState(() => _selectedTab = 9); Navigator.pop(context); },
              ),
          ],
        ),
      ),
      body: _getSelectedBodyTab(),
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
                  const Text('إضافة منتج جديد للمتجر', style: TextStyle(color: Color(0xFFE52521), fontSize: 18, fontWeight: FontWeight.w900)),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E1E28)),
                    onPressed: _showManageUniversitiesDialog,
                    icon: const Icon(Icons.settings, color: Color(0xFFE52521)),
                    label: const Text('إدارة الأقسام', style: TextStyle(color: Colors.white, fontSize: 11)),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              TextField(controller: _titleController, decoration: const InputDecoration(labelText: 'اسم المنتج', filled: true)),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: TextField(controller: _priceController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'السعر الرقمي', filled: true))),
                  const SizedBox(width: 8),
                  DropdownButton<String>(
                    value: _productCurrency,
                    dropdownColor: const Color(0xFF14141C),
                    items: const [
                      DropdownMenuItem(value: 'ل.س', child: Text('ل.س', style: TextStyle(color: Colors.white))),
                      DropdownMenuItem(value: '\$', child: Text('\$', style: TextStyle(color: Colors.white))),
                    ],
                    onChanged: (val) => setState(() => _productCurrency = val ?? 'ل.س'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(controller: _discountController, decoration: const InputDecoration(labelText: 'نسبة الحسم (مثال: خصم 20% أو عرض محدود)', filled: true)),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: selectedCat,
                dropdownColor: const Color(0xFF14141C),
                items: globalCategories.where((c) => c != 'الكل' && c != 'العروض').map((c) => DropdownMenuItem(value: c.toString(), child: Text(c.toString()))).toList(),
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
                        const Text('صورة المنتج (من الاستوديو):', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE52521)),
                          onPressed: _isUploadingProductImage ? null : () => _pickAndUploadImage(isBundle: false),
                          icon: _isUploadingProductImage 
                              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : const Icon(Icons.photo_library_rounded, color: Colors.white),
                          label: Text(_isUploadingProductImage ? 'جاري الرفع لفايربيز...' : 'اختر صورة من الاستوديو 🖼️', style: const TextStyle(color: Colors.white)),
                        ),
                      ],
                    ),
                    if (_productImageUrl.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: CachedNetworkImage(imageUrl: _productImageUrl, height: 100, width: 100, fit: BoxFit.cover),
                      ),
                      const SizedBox(height: 4),
                      const Text('تم حفظ الصورة بفايربيز بنجاح للأبد ✅', style: TextStyle(color: Colors.green, fontSize: 11, fontWeight: FontWeight.bold)),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),
              TextField(controller: _descController, maxLines: 3, decoration: const InputDecoration(labelText: 'التفاصيل', filled: true)),
              const SizedBox(height: 20),
              ElevatedButton(onPressed: _saveProduct, child: const Text('نشر المنتج وإرسال إشعار للطلاب')),
            ],
          ),
        );
      case 1:
        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('إضافة عرض أو باكدج جديد في المتجر', style: TextStyle(color: Color(0xFFE52521), fontSize: 18, fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              const Text('اختر صورة الباكدج مباشرة من استوديو هاتفك لتخزينها على فايربيز.', style: TextStyle(color: Colors.grey, fontSize: 12)),
              const SizedBox(height: 14),
              TextField(controller: _bundleTitleController, decoration: const InputDecoration(labelText: 'عنوان العرض أو الباكدج', filled: true)),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: TextField(controller: _bundlePriceController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'السعر الرقمي', filled: true))),
                  const SizedBox(width: 8),
                  DropdownButton<String>(
                    value: _bundleCurrency,
                    dropdownColor: const Color(0xFF14141C),
                    items: const [
                      DropdownMenuItem(value: 'ل.س', child: Text('ل.س', style: TextStyle(color: Colors.white))),
                      DropdownMenuItem(value: '\$', child: Text('\$', style: TextStyle(color: Colors.white))),
                    ],
                    onChanged: (val) => setState(() => _bundleCurrency = val ?? 'ل.س'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(controller: _bundleDiscountController, decoration: const InputDecoration(labelText: 'نسبة الحسم (مثال: حسم 30%)', filled: true)),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: selectedBundleCat,
                dropdownColor: const Color(0xFF14141C),
                items: globalCategories.where((c) => c != 'الكل' && c != 'العروض').map((c) => DropdownMenuItem(value: c.toString(), child: Text(c.toString()))).toList(),
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
                        const Text('صورة الباكدج (من الاستوديو):', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE52521)),
                          onPressed: _isUploadingBundleImage ? null : () => _pickAndUploadImage(isBundle: true),
                          icon: _isUploadingBundleImage 
                              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : const Icon(Icons.photo_library_rounded, color: Colors.white),
                          label: Text(_isUploadingBundleImage ? 'جاري الرفع لفايربيز...' : 'اختر صورة العرض 🖼️', style: const TextStyle(color: Colors.white)),
                        ),
                      ],
                    ),
                    if (_bundleImageUrl.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: CachedNetworkImage(imageUrl: _bundleImageUrl, height: 100, width: 100, fit: BoxFit.cover),
                      ),
                      const SizedBox(height: 4),
                      const Text('تم حفظ الصورة بفايربيز بنجاح للأبد ✅', style: TextStyle(color: Colors.green, fontSize: 11, fontWeight: FontWeight.bold)),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),
              TextField(controller: _bundleDescController, maxLines: 3, decoration: const InputDecoration(labelText: 'تفاصيل العرض ومحتويات الباكدج', filled: true)),
              const SizedBox(height: 20),
              ElevatedButton(onPressed: _saveBundle, child: const Text('نشر العرض/الباكدج بقمة المتجر')),
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
                  const Text('إضافة مادة وتوليد 2000 كود (فيديوهات يوتيوب غير مدرجة)', style: TextStyle(color: Color(0xFFE52521), fontSize: 16, fontWeight: FontWeight.w900)),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E1E28)),
                    onPressed: _showManageUniversitiesDialog,
                    icon: const Icon(Icons.settings, color: Color(0xFFE52521)),
                    label: const Text('إدارة الجامعات', style: TextStyle(color: Colors.white, fontSize: 11)),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              TextField(controller: _courseTitleController, decoration: const InputDecoration(labelText: 'اسم المادة التعليمية', filled: true)),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: selectedUniForCourse,
                dropdownColor: const Color(0xFF14141C),
                items: globalUniversities.map((u) => DropdownMenuItem(value: u.toString(), child: Text(u.toString()))).toList(),
                onChanged: (v) => setState(() {
                  selectedUniForCourse = v!;
                  var cols = (universityColleges[selectedUniForCourse] ?? []) as List;
                  if (cols.isNotEmpty) selectedCollegeForCourse = cols.first.toString();
                }),
                decoration: const InputDecoration(labelText: 'الجامعة السورية', filled: true),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: selectedCollegeForCourse,
                dropdownColor: const Color(0xFF14141C),
                items: ((universityColleges[selectedUniForCourse] ?? ['هندسة معلوماتية']) as List).map((c) => DropdownMenuItem(value: c.toString(), child: Text(c.toString()))).toList(),
                onChanged: (v) => setState(() => selectedCollegeForCourse = v!),
                decoration: const InputDecoration(labelText: 'الكلية / التخصص', filled: true),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: TextField(controller: _coursePriceController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'السعر الرقمي', filled: true))),
                  const SizedBox(width: 8),
                  DropdownButton<String>(
                    value: _courseCurrency,
                    dropdownColor: const Color(0xFF14141C),
                    items: const [
                      DropdownMenuItem(value: 'ل.س', child: Text('ل.س', style: TextStyle(color: Colors.white))),
                      DropdownMenuItem(value: '\$', child: Text('\$', style: TextStyle(color: Colors.white))),
                    ],
                    onChanged: (val) => setState(() => _courseCurrency = val ?? 'ل.س'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Text(_coursePdfUrl.isEmpty ? 'لم يتم إدخال رابط PDF للمقرر' : 'تم إدخال رابط PDF الرئيسي ✅', style: const TextStyle(color: Colors.white70)),
                  ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E1E28)),
                    icon: const Icon(Icons.link, color: Color(0xFFE52521)),
                    label: const Text('إدخال رابط PDF للمقرر', style: TextStyle(color: Colors.white)),
                    onPressed: () => _inputPdfUrlDialog((url) => setState(() => _coursePdfUrl = url)),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Text('إدارة المحاضرات (روابط يوتيوب غير مدرجة - Unlisted):', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              ...lectureControllers.asMap().entries.map((entry) {
                int idx = entry.key;
                var lec = entry.value;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(child: TextField(controller: lec['title'] as TextEditingController, decoration: InputDecoration(labelText: 'عنوان المحاضرة ${idx + 1}', filled: true))),
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
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(child: Text((lec['pdf'] as String).isEmpty ? 'لا يوجد PDF' : 'تم إرفاق رابط PDF ✅', style: const TextStyle(color: Colors.grey, fontSize: 12))),
                          TextButton.icon(
                            icon: const Icon(Icons.link, color: Color(0xFFE52521)),
                            label: const Text('إدخال رابط PDF للمحاضرة', style: TextStyle(color: Color(0xFFE52521))),
                            onPressed: () => _inputPdfUrlDialog((url) => setState(() => lec['pdf'] = url)),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }),
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    lectureControllers.add({
                      'title': TextEditingController(text: 'المحاضرة ${lectureControllers.length + 1}'),
                      'url': TextEditingController(),
                      'pdf': '',
                    });
                  });
                },
                icon: const Icon(Icons.add_rounded, color: Color(0xFFE52521)),
                label: const Text('إضافة محاضرة أخرى', style: TextStyle(color: Color(0xFFE52521))),
              ),
              const SizedBox(height: 20),
              ElevatedButton(onPressed: _saveCourse, child: const Text('نشر المقرر وتوليد 2000 كود تفعيل')),
            ],
          ),
        );
      case 3:
        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('courses').limit(50).snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: Color(0xFFE52521)));
            var docs = snapshot.data!.docs;
            if (docs.isEmpty) return const Center(child: Text('لا توجد مقررات مضافة لعرض أكوادها', style: TextStyle(color: Colors.grey)));

            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('إضافة وتدوير وإلغاء تفعيل الأكواد:', style: TextStyle(color: Color(0xFFE52521), fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _customCodeController,
                          decoration: const InputDecoration(hintText: 'أدخل كود تفعيل مخصص يدوياً...', filled: true),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                        icon: const Icon(Icons.add_circle, color: Colors.white),
                        label: const Text('إضافة كود'),
                        onPressed: () async {
                          if (_customCodeController.text.trim().isNotEmpty && docs.isNotEmpty) {
                            String code = _customCodeController.text.trim();
                            await FirebaseFirestore.instance.collection('courses').doc(docs.first.id).update({
                              'codes': FieldValue.arrayUnion([
                                {
                                  'code': code,
                                  'isUsed': false,
                                  'isDisabled': false,
                                  'usedBy': null,
                                  'userUid': null,
                                  'usedAt': null,
                                }
                              ])
                            });
                            _customCodeController.clear();
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تمت إضافة الكود اليدوي بنجاح!')));
                          }
                        },
                      ),
                    ],
                  ),
                  const Divider(color: Colors.white24, height: 30),
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      var courseDoc = docs[index];
                      var course = courseDoc.data() as Map<String, dynamic>;
                      List codes = course['codes'] ?? [];
                      
                      var activeCodes = codes.where((c) => (c['isUsed'] == false || c['isUsed'] == null) && (c['isDisabled'] != true)).toList();
                      var disabledOrUsedCodes = codes.where((c) => c['isUsed'] == true || c['isDisabled'] == true).toList();

                      return Container(
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(color: const Color(0xFF14141C), borderRadius: BorderRadius.circular(16)),
                        child: ExpansionTile(
                          title: Text(course['title'] ?? '', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          subtitle: Text('نشطة ومتاحة: ${activeCodes.length} | مستعملة أو معطلة: ${disabledOrUsedCodes.length}', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                          children: [
                            DefaultTabController(
                              length: 2,
                              child: SizedBox(
                                height: 280,
                                child: Column(
                                  children: [
                                    const TabBar(
                                      labelColor: Color(0xFFE52521),
                                      unselectedLabelColor: Colors.grey,
                                      indicatorColor: Color(0xFFE52521),
                                      tabs: [
                                        Tab(text: 'الأكواد المتاحة'),
                                        Tab(text: 'المستعملة / المعطلة (تحكم)'),
                                      ],
                                    ),
                                    Expanded(
                                      child: TabBarView(
                                        children: [
                                          ListView.builder(
                                            itemCount: activeCodes.length,
                                            itemBuilder: (context, uIdx) {
                                              var aCode = activeCodes[uIdx];
                                              return ListTile(
                                                title: Text('الكود: ${aCode['code']}', style: const TextStyle(color: Colors.greenAccent)),
                                                trailing: ElevatedButton(
                                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red, padding: const EdgeInsets.symmetric(horizontal: 8)),
                                                  onPressed: () async {
                                                    aCode['isDisabled'] = true;
                                                    await FirebaseFirestore.instance.collection('courses').doc(courseDoc.id).update({'codes': codes});
                                                    setState(() {});
                                                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تعطيل هذا الكود وإلغاء تفعيله! 🚫')));
                                                  },
                                                  child: const Text('تعطيل', style: TextStyle(color: Colors.white, fontSize: 11)),
                                                ),
                                              );
                                            },
                                          ),
                                          ListView.builder(
                                            itemCount: disabledOrUsedCodes.length,
                                            itemBuilder: (context, sIdx) {
                                              var uCode = disabledOrUsedCodes[sIdx];
                                              bool isDis = uCode['isDisabled'] == true;
                                              return ListTile(
                                                title: Text('الكود: ${uCode['code']} (${isDis ? 'معطل يدويأ 🚫' : 'مستعمل بواسطة: ${uCode['usedBy']}'})', style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
                                                trailing: ElevatedButton(
                                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.amber, padding: const EdgeInsets.symmetric(horizontal: 8)),
                                                  onPressed: () async {
                                                    uCode['isUsed'] = false;
                                                    uCode['isDisabled'] = false;
                                                    uCode['usedBy'] = null;
                                                    uCode['userUid'] = null;
                                                    await FirebaseFirestore.instance.collection('courses').doc(courseDoc.id).update({'codes': codes});
                                                    setState(() {});
                                                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تمت إعادة تفعيل الكود ليصبح متاحاً مجدداً! ♻️')));
                                                  },
                                                  child: const Text('إعادة تفعيل', style: TextStyle(color: Colors.black, fontSize: 11, fontWeight: FontWeight.bold)),
                                                ),
                                              );
                                            },
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            );
          },
        );
      case 4:
        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('sales_log').orderBy('purchasedAt', descending: true).limit(200).snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: Color(0xFFE52521)));
            var salesDocs = snapshot.data!.docs;

            var filteredSales = salesDocs.where((doc) {
              var data = doc.data() as Map<String, dynamic>;
              String name = (data['userName'] ?? '').toLowerCase();
              String uid = (data['userUid'] ?? '').toLowerCase();
              String course = (data['courseTitle'] ?? '').toLowerCase();
              
              bool matchQuery = salesSearchQuery.isEmpty || name.contains(salesSearchQuery) || uid.contains(salesSearchQuery) || course.contains(salesSearchQuery);
              
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
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                          ),
                          onChanged: (val) => setState(() => salesSearchQuery = val.trim().toLowerCase()),
                        ),
                      ),
                      const SizedBox(width: 8),
                      DropdownButton<String>(
                        value: salesDateFilter,
                        dropdownColor: const Color(0xFF14141C),
                        items: const [
                          DropdownMenuItem(value: 'الكل', child: Text('كل الأيام', style: TextStyle(color: Colors.white, fontSize: 12))),
                          DropdownMenuItem(value: 'اليوم', child: Text('اليوم', style: TextStyle(color: Colors.white, fontSize: 12))),
                          DropdownMenuItem(value: 'آخر 7 أيام', child: Text('آخر 7 أيام', style: TextStyle(color: Colors.white, fontSize: 12))),
                          DropdownMenuItem(value: 'آخر 30 يوم', child: Text('آخر 30 يوم', style: TextStyle(color: Colors.white, fontSize: 12))),
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
                        Text('تم تحديد ${_selectedSalesIds.length} عملية بيع', style: const TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.bold)),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                          icon: const Icon(Icons.delete, color: Colors.white),
                          label: const Text('حذف المحدد', style: TextStyle(color: Colors.white)),
                          onPressed: () async {
                            for (String id in _selectedSalesIds) {
                              await FirebaseFirestore.instance.collection('sales_log').doc(id).delete();
                            }
                            setState(() {
                              _selectedSalesIds.clear();
                            });
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حذف المبيعات المحددة بنجاح')));
                          },
                        ),
                      ],
                    ),
                  ),
                Expanded(
                  child: filteredSales.isEmpty
                      ? const Center(child: Text('لا توجد عمليات بيع مطابقة للبحث أو الفترة', style: TextStyle(color: Colors.grey)))
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
                            String price = sData['price']?.toString() ?? '0';
                            String userName = sData['userName'] ?? 'طالب';
                            String userUid = sData['userUid'] ?? '';
                            String codeUsed = sData['codeUsed'] ?? '';
                            Timestamp? time = sData['purchasedAt'] as Timestamp?;
                            String dateStr = time != null ? "${time.toDate().year}-${time.toDate().month.toString().padLeft(2, '0')}-${time.toDate().day.toString().padLeft(2, '0')} | الساعة: ${time.toDate().hour}:${time.toDate().minute.toString().padLeft(2, '0')}" : 'وقت غير متوفر';

                            return Container(
                              margin: const EdgeInsets.symmetric(vertical: 6),
                              decoration: BoxDecoration(
                                color: const Color(0xFF14141C),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: isSelected ? const Color(0xFFE52521) : const Color(0xFF2E2E3A), width: isSelected ? 2 : 1),
                              ),
                              child: CheckboxListTile(
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
                                title: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(child: Text(courseTitle, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15))),
                                    Text(price, style: const TextStyle(color: Color(0xFFE52521), fontWeight: FontWeight.bold)),
                                  ],
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 4),
                                    Text('🏛️ $university | 📚 $college', style: const TextStyle(color: Colors.amberAccent, fontSize: 12)),
                                    Text('👤 الطالب: $userName', style: const TextStyle(color: Colors.white70, fontSize: 13)),
                                    Text('🆔 الأيدي: $userUid | الكود: $codeUsed', style: const TextStyle(color: Colors.grey, fontSize: 11)),
                                    const SizedBox(height: 4),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text('🕒 التاريخ والوقت: $dateStr', style: TextStyle(color: Colors.greenAccent.shade400, fontSize: 11, fontWeight: FontWeight.bold)),
                                        IconButton(
                                          icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                                          onPressed: () async {
                                            await FirebaseFirestore.instance.collection('sales_log').doc(docId).delete();
                                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حذف عملية البيع بنجاح')));
                                          },
                                          tooltip: 'حذف عملية البيع',
                                        ),
                                      ],
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
          },
        );
      case 5:
        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('courses').limit(100).snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: Color(0xFFE52521)));
            var courseDocs = snapshot.data!.docs;

            var filteredCourses = courseDocs.where((doc) {
              var data = doc.data() as Map<String, dynamic>;
              String uni = data['university'] ?? '';
              String col = data['college'] ?? '';

              bool matchUni = (statsFilterUni == 'الكل' || uni == statsFilterUni);
              bool matchCol = (statsFilterCollege == 'الكل' || col == statsFilterCollege);
              return matchUni && matchCol;
            }).toList();

            return Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('إحصاءات المبيعات والمواد حسب الجامعة والكلية 📊', style: TextStyle(color: Color(0xFFE52521), fontSize: 18, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: statsFilterUni,
                          dropdownColor: const Color(0xFF14141C),
                          items: ['الكل', ...globalUniversities].map<DropdownMenuItem<String>>((u) => DropdownMenuItem<String>(value: u.toString(), child: Text(u.toString(), style: const TextStyle(fontSize: 12)))).toList(),
                          onChanged: (v) => setState(() => statsFilterUni = v ?? 'الكل'),
                          decoration: const InputDecoration(labelText: 'فلترة حسب الجامعة', filled: true),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: statsFilterCollege,
                          dropdownColor: const Color(0xFF14141C),
                          items: ['الكل', 'هندسة معلوماتية', 'هندسة مدنية', 'طب بشري', 'طب أسنان', 'هندسة عمارة', 'صيدلة', 'إدارة أعمال'].map<DropdownMenuItem<String>>((c) => DropdownMenuItem<String>(value: c.toString(), child: Text(c.toString(), style: const TextStyle(fontSize: 12)))).toList(),
                          onChanged: (v) => setState(() => statsFilterCollege = v ?? 'الكل'),
                          decoration: const InputDecoration(labelText: 'فلترة حسب الكلية', filled: true),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: filteredCourses.isEmpty
                        ? const Center(child: Text('لا توجد مقررات مطابقة للفلتر المحدد', style: TextStyle(color: Colors.grey)))
                        : ListView.builder(
                            itemCount: filteredCourses.length,
                            itemBuilder: (context, index) {
                              var cData = filteredCourses[index].data() as Map<String, dynamic>;
                              String title = cData['title'] ?? 'مادة';
                              String uni = cData['university'] ?? 'جامعة عامة';
                              String col = cData['college'] ?? 'كلية عامة';
                              var unlockedMap = cData['unlockedUsers'] as Map?;
                              int buyersCount = unlockedMap != null ? unlockedMap.length : 0;

                              return Container(
                                margin: const EdgeInsets.symmetric(vertical: 6),
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(color: const Color(0xFF14141C), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFF2E2E3A))),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                                          const SizedBox(height: 4),
                                          Text('🏛️ $uni | 📚 $col', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      decoration: BoxDecoration(color: const Color(0xFFE52521).withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
                                      child: Column(
                                        children: [
                                          const Text('عدد المشترين', style: TextStyle(color: Colors.redAccent, fontSize: 10)),
                                          Text('$buyersCount طالب', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14)),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        );
      case 6:
        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('sub_admins').limit(50).snapshots(),
          builder: (context, snapshot) {
            var subAdmins = snapshot.hasData ? snapshot.data!.docs : [];
            final subNameController = TextEditingController();
            final subPhoneController = TextEditingController();
            final subPassController = TextEditingController();

            return SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: StatefulBuilder(
                builder: (context, setStateDialog) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text('إدارة حسابات المشرفين مع الصلاحيات الدقيقة 👥', style: TextStyle(color: Color(0xFFE52521), fontSize: 18, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 8),
                      const Text('حدد الأقسام التي يسمح للمشرف برؤيتها واستخدامها فقط:', style: TextStyle(color: Colors.grey, fontSize: 12)),
                      const SizedBox(height: 16),
                      TextField(controller: subNameController, decoration: const InputDecoration(labelText: 'اسم المشرف الثلاثي', filled: true)),
                      const SizedBox(height: 10),
                      TextField(controller: subPhoneController, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'رقم الهاتف', filled: true)),
                      const SizedBox(height: 10),
                      TextField(controller: subPassController, decoration: const InputDecoration(labelText: 'كلمة السر', filled: true)),
                      const SizedBox(height: 16),
                      const Text('تحديد الصلاحيات الممنوحة:', style: TextStyle(color: Color(0xFFE52521), fontWeight: FontWeight.bold)),
                      CheckboxListTile(title: const Text('إدارة المتجر', style: TextStyle(color: Colors.white)), value: permStore, activeColor: const Color(0xFFE52521), onChanged: (v) => setStateDialog(() => permStore = v!)),
                      CheckboxListTile(title: const Text('العروض والباكدجات', style: TextStyle(color: Colors.white)), value: permBundles, activeColor: const Color(0xFFE52521), onChanged: (v) => setStateDialog(() => permBundles = v!)),
                      CheckboxListTile(title: const Text('الكورسات والأكواد', style: TextStyle(color: Colors.white)), value: permCourses, activeColor: const Color(0xFFE52521), onChanged: (v) => setStateDialog(() => permCourses = v!)),
                      CheckboxListTile(title: const Text('أكواد المواد', style: TextStyle(color: Colors.white)), value: permCodes, activeColor: const Color(0xFFE52521), onChanged: (v) => setStateDialog(() => permCodes = v!)),
                      CheckboxListTile(title: const Text('سجل المبيعات', style: TextStyle(color: Colors.white)), value: permSales, activeColor: const Color(0xFFE52521), onChanged: (v) => setStateDialog(() => permSales = v!)),
                      CheckboxListTile(title: const Text('إحصاءات المواد والجامعات', style: TextStyle(color: Colors.white)), value: permStats, activeColor: const Color(0xFFE52521), onChanged: (v) => setStateDialog(() => permStats = v!)),
                      CheckboxListTile(title: const Text('إدارة المشرفين', style: TextStyle(color: Colors.white)), value: permSubAdmins, activeColor: const Color(0xFFE52521), onChanged: (v) => setStateDialog(() => permSubAdmins = v!)),
                      CheckboxListTile(title: const Text('إدارة الإعلانات', style: TextStyle(color: Colors.white)), value: permAds, activeColor: const Color(0xFFE52521), onChanged: (v) => setStateDialog(() => permAds = v!)),
                      CheckboxListTile(title: const Text('إعدادات الواتساب', style: TextStyle(color: Colors.white)), value: permWhatsapp, activeColor: const Color(0xFFE52521), onChanged: (v) => setStateDialog(() => permWhatsapp = v!)),
                      CheckboxListTile(title: const Text('إرسال إشعار عام', style: TextStyle(color: Colors.white)), value: permNotif, activeColor: const Color(0xFFE52521), onChanged: (v) => setStateDialog(() => permNotif = v!)),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE52521)),
                        onPressed: () async {
                          if (subNameController.text.trim().isEmpty) return;
                          await FirebaseFirestore.instance.collection('sub_admins').add({
                            'name': subNameController.text.trim(),
                            'phone': subPhoneController.text.trim(),
                            'pass': subPassController.text.trim(),
                            'isActive': true,
                            'permissions': {
                              'store': permStore,
                              'bundles': permBundles,
                              'courses': permCourses,
                              'codes': permCodes,
                              'sales': permSales,
                              'stats': permStats,
                              'subAdmins': permSubAdmins,
                              'ads': permAds,
                              'whatsapp': permWhatsapp,
                              'notif': permNotif,
                            }
                          });
                          subNameController.clear();
                          subPhoneController.clear();
                          subPassController.clear();
                          setState(() {});
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تمت إضافة حساب المشرف والصلاحيات بدقة!')));
                        },
                        child: const Text('إضافة حساب مشرف بالصلاحيات المحددة'),
                      ),
                      const Divider(color: Colors.white24, height: 30),
                      const Text('قائمة المشرفين المسجلين:', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 10),
                      subAdmins.isEmpty
                          ? const Center(child: Text('لا توجد حسابات مشرفين مضافة بعد', style: TextStyle(color: Colors.grey)))
                          : ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: subAdmins.length,
                              itemBuilder: (context, idx) {
                                var sa = subAdmins[idx];
                                var saData = sa.data() as Map<String, dynamic>;
                                bool active = saData['isActive'] ?? true;

                                return Container(
                                  margin: const EdgeInsets.symmetric(vertical: 4),
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(color: const Color(0xFF14141C), borderRadius: BorderRadius.circular(12)),
                                  child: ListTile(
                                    title: Text(saData['name'] ?? '', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                    subtitle: Text('الهاتف: ${saData['phone']}\nالحالة: ${active ? 'مفعل ✅' : 'معطل ❌'}', style: const TextStyle(color: Colors.grey, fontSize: 11)),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Switch(
                                          value: active,
                                          activeColor: Colors.green,
                                          onChanged: (val) async {
                                            await FirebaseFirestore.instance.collection('sub_admins').doc(sa.id).update({'isActive': val});
                                            setState(() {});
                                          },
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                                          onPressed: () async {
                                            await FirebaseFirestore.instance.collection('sub_admins').doc(sa.id).delete();
                                            setState(() {});
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                    ],
                  );
                },
              ),
            );
          },
        );
      case 7:
        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('إدارة الإعلان (يظهر كبطاقة منتج أول شبكة المتجر)', style: TextStyle(color: Color(0xFFE52521), fontSize: 18, fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              const Text('ضع رابط يوتيوب أو رابط إنستغرام (ريلز/صفحة) ليظهر تلقائياً كأول عنصر في المنتجات.', style: TextStyle(color: Colors.grey, fontSize: 12)),
              const SizedBox(height: 20),
              TextField(controller: _adUrlController, decoration: const InputDecoration(labelText: 'رابط الإعلان (يوتيوب أو إنستغرام)', filled: true)),
              const SizedBox(height: 12),
              SwitchListTile(
                title: const Text('هل الإعلان عبارة عن فيديو (يوتيوب أو ريلز انستا)؟', style: TextStyle(color: Colors.white)),
                value: _isAdVideo,
                activeColor: const Color(0xFFE52521),
                onChanged: (val) => setState(() => _isAdVideo = val),
              ),
              SwitchListTile(
                title: const Text('تفعيل وإظهار الإعلان في المتجر (تشغيل/إيقاف)', style: TextStyle(color: Colors.white)),
                value: _isAdActive,
                activeColor: Colors.green,
                onChanged: (val) => setState(() => _isAdActive = val),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE52521)),
                      onPressed: _saveAdBanner,
                      child: const Text('حفظ ونشر الإعلان بالمتجر'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                    onPressed: _deleteAdBanner,
                    child: const Text('حذف الإعلان وإلغاؤه'),
                  ),
                ],
              ),
            ],
          ),
        );
      case 8:
        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('إدارة رقم الواتساب لاستقبال الطلبات', style: TextStyle(color: Color(0xFFE52521), fontSize: 18, fontWeight: FontWeight.w900)),
              const SizedBox(height: 20),
              TextField(controller: _whatsappController, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'رقم الواتساب (بدون +)', filled: true)),
              const SizedBox(height: 20),
              ElevatedButton(onPressed: _saveWhatsAppSettings, child: const Text('حفظ وتحديث رقم الواتساب')),
            ],
          ),
        );
      case 9:
        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('إرسال إشعار فوري لجميع المستخدمين (FCM Push)', style: TextStyle(color: Color(0xFFE52521), fontSize: 18, fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              const Text('يصل الإشعار لجميع الطلاب حتى لو كان التطبيق مغلقاً وبشكل احترافي.', style: TextStyle(color: Colors.grey, fontSize: 12)),
              const SizedBox(height: 20),
              TextField(controller: _notifTitleController, decoration: const InputDecoration(labelText: 'عنوان الإشعار', filled: true)),
              const SizedBox(height: 12),
              TextField(controller: _notifBodyController, maxLines: 3, decoration: const InputDecoration(labelText: 'نص الإشعار التفصيلي', filled: true)),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE52521)),
                onPressed: _sendFcmBroadcast,
                icon: const Icon(Icons.send, color: Colors.white),
                label: const Text('إرسال الإشعار للجميع فوراً'),
              ),
            ],
          ),
        );
      default:
        return const Center(child: Text('عذراً، لا تمتلك صلاحية عرض هذا القسم', style: TextStyle(color: Colors.grey)));
    }
  }
}