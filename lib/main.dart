import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:ui';
import 'dart:math';

import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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
  } catch (e) {
    debugPrint("Firebase initialization error: $e");
  }

  final prefs = await SharedPreferences.getInstance();
  bool isLoggedIn = prefs.getBool('is_logged_in') ?? false;
  String savedName = prefs.getString('user_name') ?? '';
  String savedPhone = prefs.getString('user_phone') ?? '';
  bool savedIsAdmin = prefs.getBool('is_admin') ?? false;

  runApp(HyStoreApp(
    isLoggedIn: isLoggedIn,
    initialName: savedName,
    initialPhone: savedPhone,
    initialIsAdmin: savedIsAdmin,
  ));
}

class HyStoreApp extends StatefulWidget {
  final bool isLoggedIn;
  final String initialName;
  final String initialPhone;
  final bool initialIsAdmin;

  const HyStoreApp({
    super.key,
    required this.isLoggedIn,
    required this.initialName,
    required this.initialPhone,
    required this.initialIsAdmin,
  });

  @override
  State<HyStoreApp> createState() => _HyStoreAppState();

  static _HyStoreAppState of(BuildContext context) => context.findAncestorStateOfType<_HyStoreAppState>()!;
}

class _HyStoreAppState extends State<HyStoreApp> {
  bool isDarkMode = true;

  void toggleTheme() {
    setState(() {
      isDarkMode = !isDarkMode;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HY Store',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: isDarkMode ? Brightness.dark : Brightness.light,
        scaffoldBackgroundColor: isDarkMode ? const Color(0xFF121218) : const Color(0xFFF0F2F5),
        primaryColor: const Color(0xFFFFB703),
        fontFamily: 'Roboto',
        colorScheme: isDarkMode
            ? const ColorScheme.dark(
                primary: Color(0xFFFFB703),
                secondary: Color(0xFFFB8500),
                surface: Color(0xFF1A1A24),
              )
            : const ColorScheme.light(
                primary: Color(0xFFD49A00),
                secondary: Color(0xFFFB8500),
                surface: Colors.white,
              ),
        appBarTheme: AppBarTheme(
          backgroundColor: isDarkMode ? const Color(0xFF161622) : Colors.white,
          elevation: 0,
          centerTitle: true,
          titleTextStyle: const TextStyle(
            color: Color(0xFFFFB703),
            fontSize: 22,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.5,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFFFB703),
            foregroundColor: Colors.black,
            textStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
            elevation: 12,
            shadowColor: const Color(0x7FFFB703),
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
        initialIsAdmin: widget.initialIsAdmin,
      ),
    );
  }
}

// ----------------- ستيكرات وأنيميشن ثلاثي الأبعاد كثيفة تملأ الشاشة -----------------
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
    this.size = 60,
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
        double dy = sin(_controller.value * 2 * pi) * 18;
        double dx = cos(_controller.value * 2 * pi) * 14;
        double angle = sin(_controller.value * 2 * pi) * 0.15;

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
                ..rotateZ(angle * 0.7),
              alignment: Alignment.center,
              child: Container(
                width: widget.size,
                height: widget.size,
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E2C).withOpacity(0.85),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFFFB703).withOpacity(0.7), width: 2),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x44FFB703),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: CachedNetworkImage(
                    imageUrl: widget.imageUrl,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Center(child: Icon(widget.fallbackIcon, color: const Color(0xFFFFB703), size: 26)),
                    errorWidget: (context, url, error) => Center(child: Icon(widget.fallbackIcon, color: const Color(0xFFFFB703), size: 26)),
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

// مجموعة ضخمة من الستيكرات لتعبئة الشاشة بالكامل بدون إزعاج
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
        FloatingSticker3D(imageUrl: 'https://images.unsplash.com/photo-1576091160399-112ba8d25d1d?w=200', fallbackIcon: Icons.coronavirus_rounded, bottom: 180, left: 15, duration: Duration(seconds: 5), size: 60),
        FloatingSticker3D(imageUrl: 'https://images.unsplash.com/photo-1509228468518-180dd4864904?w=200', fallbackIcon: Icons.format_paint_rounded, bottom: 170, right: 15, duration: Duration(seconds: 4), size: 60),
        FloatingSticker3D(imageUrl: 'https://images.unsplash.com/photo-1516321318423-f06f85e504b3?w=200', fallbackIcon: Icons.computer_rounded, top: 320, left: 8, duration: Duration(seconds: 5), size: 55),
        FloatingSticker3D(imageUrl: 'https://images.unsplash.com/photo-1454165804606-c3d57bc86b40?w=200', fallbackIcon: Icons.business_center_rounded, top: 300, right: 8, duration: Duration(seconds: 6), size: 55),
      ],
    );
  }
}

// ----------------- شاشة الترحيب الفخمة -----------------
class SplashScreen extends StatefulWidget {
  final bool isLoggedIn;
  final String initialName;
  final String initialPhone;
  final bool initialIsAdmin;

  const SplashScreen({
    super.key,
    required this.isLoggedIn,
    required this.initialName,
    required this.initialPhone,
    required this.initialIsAdmin,
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
              ? HomeScreen(userName: widget.initialName, userPhone: widget.initialPhone, isAdmin: widget.initialIsAdmin)
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
                colors: [Color(0xFF2A2A38), Color(0xFF121218)],
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
                      padding: const EdgeInsets.all(30),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFFB703), Color(0xFFFB8500)],
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x7FFFB703),
                            blurRadius: 45,
                            spreadRadius: 12,
                          ),
                        ],
                      ),
                      child: const Icon(Icons.storefront_rounded, size: 80, color: Colors.black),
                    ),
                    const SizedBox(height: 30),
                    const Text(
                      'HY STORE',
                      style: TextStyle(
                        color: Color(0xFFFFB703),
                        fontSize: 34,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 4,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 30),
                      child: Text(
                        'أفضل الأسعار وأفضل المستلزمات جودة وأفضل خدمة يقدمها لكم متجرنا',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 50),
                    const SizedBox(
                      width: 35,
                      height: 35,
                      child: CircularProgressIndicator(
                        color: Color(0xFFFFB703),
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

// ----------------- شاشة تسجيل الدخول ببطاقة 3D تفاعلية -----------------
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _phoneController = TextEditingController();
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

  void _login() async {
    String phone = _phoneController.text.trim();
    String pass = _passwordController.text.trim();
    String name = _nameController.text.trim();

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الرجاء إدخال الاسم الثلاثي')),
      );
      return;
    }

    bool isAdmin = (phone == adminPhone && pass == adminPass);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_logged_in', true);
    await prefs.setString('user_name', name);
    await prefs.setString('user_phone', phone);
    await prefs.setBool('is_admin', isAdmin);

    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => HomeScreen(
          userName: name,
          userPhone: phone,
          isAdmin: isAdmin,
        ),
      ),
    );
  }

  void _openSupportWhatsApp() async {
    final Uri whatsappUri = Uri.parse(
        "https://wa.me/+963967834966?text=${Uri.encodeComponent('لدي مشكلة ارغب من الادارة الاطلاع عليها ومساعدتي')}");
    if (await canLaunchUrl(whatsappUri)) {
      await launchUrl(whatsappUri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isDark = HyStoreApp.of(context).isDarkMode;

    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0, -0.6),
                radius: 1.5,
                colors: isDark ? const [Color(0xFF2A2A38), Color(0xFF121218)] : const [Color(0xFFE2E8F0), Color(0xFFCBD5E1)],
              ),
            ),
          ),
          const BackgroundStickersLayer(),
          Positioned(
            top: 20,
            right: 20,
            child: IconButton(
              icon: Icon(isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded, color: const Color(0xFFFFB703), size: 28),
              onPressed: () => HyStoreApp.of(context).toggleTheme(),
              tooltip: 'تبديل المظهر (ليلي / صباحي)',
            ),
          ),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 40.0),
              child: MouseRegion(
                onHover: (event) => _onPointerHover(event, const Size(460, 620)),
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
                            color: isDark ? const Color(0xFF1B1B26).withOpacity(0.95) : Colors.white.withOpacity(0.95),
                            borderRadius: BorderRadius.circular(35),
                            border: Border.all(color: const Color(0xFFFFB703).withOpacity(0.7), width: 2),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x55FFB703),
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
                                  padding: const EdgeInsets.all(22),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: LinearGradient(
                                      colors: [const Color(0xFFFFB703).withOpacity(0.3), const Color(0xFFFB8500).withOpacity(0.05)],
                                    ),
                                    border: Border.all(color: const Color(0xFFFFB703), width: 2),
                                    boxShadow: const [
                                      BoxShadow(color: Color(0x44FFB703), blurRadius: 25, spreadRadius: 6),
                                    ],
                                  ),
                                  child: const Icon(Icons.storefront_rounded, size: 60, color: Color(0xFFFFB703)),
                                ),
                              ),
                              const SizedBox(height: 24),
                              const Text(
                                'HY STORE',
                                style: TextStyle(
                                  color: Color(0xFFFFB703),
                                  fontSize: 30,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 4,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'أفضل الأسعار وأفضل المستلزمات جودة وأفضل خدمة',
                                style: TextStyle(color: isDark ? Colors.white60 : Colors.black54, fontSize: 12),
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
                                label: 'رقم الهاتف',
                                icon: Icons.phone_iphone_rounded,
                                keyboardType: TextInputType.phone,
                                isDark: isDark,
                              ),
                              const SizedBox(height: 16),
                              _buildInputField(
                                controller: _passwordController,
                                label: 'كلمة السر',
                                icon: Icons.lock_rounded,
                                obscureText: true,
                                helperText: 'أنشئ كلمة سر من 8 أحرف أو أرقام',
                                isDark: isDark,
                              ),
                              const SizedBox(height: 10),
                              // زر التواصل مع الدعم الفني بمربع أخضر وكتابة خضراء احترافية
                              SizedBox(
                                width: double.infinity,
                                height: 50,
                                child: ElevatedButton.icon(
                                  onPressed: _openSupportWhatsApp,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green.withOpacity(0.18),
                                    foregroundColor: Colors.greenAccent,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      side: const BorderSide(color: Colors.green, width: 1.8),
                                    ),
                                    elevation: 4,
                                  ),
                                  icon: const Icon(Icons.support_agent_rounded, color: Colors.greenAccent, size: 24),
                                  label: const Text(
                                    'التواصل مع الدعم الفني (واتساب)',
                                    style: TextStyle(color: Colors.greenAccent, fontSize: 15, fontWeight: FontWeight.w900),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 24),
                              Container(
                                height: 58,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(18),
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFFFFB703), Color(0xFFFB8500)],
                                  ),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Color(0x66FFB703),
                                      blurRadius: 30,
                                      offset: Offset(0, 10),
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
                                    'دخول إلى المتجر',
                                    style: TextStyle(color: Colors.black, fontSize: 18, fontWeight: FontWeight.w900),
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
    String? helperText,
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
        helperText: helperText,
        helperStyle: TextStyle(color: isDark ? Colors.white38 : Colors.black45, fontSize: 11),
        prefixIcon: Icon(icon, color: const Color(0xFFFFB703)),
        filled: true,
        fillColor: isDark ? const Color(0xFF262636) : const Color(0xFFE8ECEF),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: isDark ? const Color(0xFF36364D) : const Color(0xFFCBD5E1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFFFB703), width: 2),
        ),
      ),
    );
  }
}

// النماذج والإشعارات المحلية
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

class CartItem {
  final Map<String, dynamic> product;
  int quantity;
  CartItem({required this.product, this.quantity = 1});
}

Map<String, List<CartItem>> userCarts = {};
Map<String, List<NotificationItem>> userNotifications = {};

void addAppNotification({
  required String targetUserName,
  required String title,
  required String message,
  required IconData icon,
  required Color iconColor,
}) {
  userNotifications.putIfAbsent(targetUserName, () => []);
  String timeStr = "${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')}";
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

List<String> globalCategories = ['الكل', 'عمارة', 'أسنان', 'مدنية', 'معلوماتية', 'بشرية', 'ديكور'];

// ----------------- واجهة المتجر الرئيسية -----------------
class HomeScreen extends StatefulWidget {
  final String userName;
  final String userPhone;
  final bool isAdmin;
  const HomeScreen({super.key, required this.userName, required this.userPhone, required this.isAdmin});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String selectedCategory = 'الكل';
  final TextEditingController _searchController = TextEditingController();
  String searchQuery = '';
  Set<String> favoriteProductIds = {};

  void _logout(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    if (!context.mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
    );
  }

  void _openSupportWhatsApp() async {
    final Uri whatsappUri = Uri.parse(
        "https://wa.me/+963967834966?text=${Uri.encodeComponent('لدي مشكلة ارغب من الادارة الاطلاع عليها ومساعدتي')}");
    if (await canLaunchUrl(whatsappUri)) {
      await launchUrl(whatsappUri, mode: LaunchMode.externalApplication);
    }
  }

  void _addSampleProductForTest() async {
    try {
      await FirebaseFirestore.instance.collection('products').add({
        'title': 'طقم أدوات هندسية معماري',
        'price': '45000 ل.س',
        'priceNum': 45000,
        'category': 'عمارة',
        'image': 'https://images.unsplash.com/photo-1581291518633-83b4ebd1d83e?w=400',
        'description': 'طقم هندسي متكامل لطلاب الهندسة المعمارية بجودة عالية جداً.',
        'ratings': {},
        'createdAt': FieldValue.serverTimestamp(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تمت إضافة منتج تجريبي بنجاح!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: $e')),
        );
      }
    }
  }

  void _deleteProduct(String productId) async {
    try {
      await FirebaseFirestore.instance.collection('products').doc(productId).delete();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم حذف المنتج بنجاح')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في الحذف: $e')),
        );
      }
    }
  }

  void _showEditProductDialog(Map<String, dynamic> product) {
    final titleController = TextEditingController(text: product['title']);
    final priceController = TextEditingController(text: product['price']);
    final descController = TextEditingController(text: product['description']);
    final imageController = TextEditingController(text: product['image']);
    String cat = globalCategories.contains(product['category']) ? product['category'] : 'عمارة';

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1B1B26),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              title: const Text('تعديل المنتج (صلاحية الأدمن)', style: TextStyle(color: Color(0xFFFFB703), fontWeight: FontWeight.w900)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: titleController,
                      decoration: const InputDecoration(labelText: 'اسم المنتج', filled: true, fillColor: Color(0xFF262636)),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: priceController,
                      decoration: const InputDecoration(labelText: 'السعر (ل.س)', filled: true, fillColor: Color(0xFF262636)),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      value: cat,
                      dropdownColor: const Color(0xFF262636),
                      decoration: const InputDecoration(labelText: 'القسم', filled: true, fillColor: Color(0xFF262636)),
                      items: globalCategories.where((c) => c != 'الكل').map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                      onChanged: (val) => setDialogState(() => cat = val!),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: imageController,
                      decoration: const InputDecoration(labelText: 'رابط الصورة', filled: true, fillColor: Color(0xFF262636)),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: descController,
                      maxLines: 3,
                      decoration: const InputDecoration(labelText: 'التفاصيل', filled: true, fillColor: Color(0xFF262636)),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء', style: TextStyle(color: Colors.grey))),
                ElevatedButton(
                  onPressed: () async {
                    String cleanPrice = priceController.text.replaceAll(RegExp(r'[^0-9]'), '');
                    int priceNum = int.tryParse(cleanPrice) ?? 0;

                    await FirebaseFirestore.instance.collection('products').doc(product['id']).update({
                      'title': titleController.text.trim(),
                      'price': priceController.text.trim(),
                      'priceNum': priceNum,
                      'category': cat,
                      'image': imageController.text.trim(),
                      'description': descController.text.trim(),
                    });

                    if (!context.mounted) return;
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('تم تعديل المنتج بنجاح!')),
                    );
                  },
                  child: const Text('حفظ التعديلات'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _addToCart(Map<String, dynamic> product) {
    userCarts.putIfAbsent(widget.userName, () => []);
    List<CartItem> cart = userCarts[widget.userName]!;
    int index = cart.indexWhere((item) => item.product['id'] == product['id']);
    setState(() {
      if (index != -1) {
        cart[index].quantity++;
      } else {
        cart.add(CartItem(product: product, quantity: 1));
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('تمت إضافة (${product['title']}) إلى سلة المشتريات 🛒'),
        duration: const Duration(seconds: 2),
        action: SnackBarAction(
          label: 'عرض السلة',
          textColor: const Color(0xFFFFB703),
          onPressed: _openCartSheet,
        ),
      ),
    );
  }

  void _openCartSheet() {
    List<CartItem> cart = userCarts[widget.userName] ?? [];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setCartState) {
            int totalSum = cart.fold(0, (sum, item) {
              int price = item.product['priceNum'] ?? 0;
              return sum + (price * item.quantity);
            });

            return Container(
              height: MediaQuery.of(context).size.height * 0.75,
              decoration: const BoxDecoration(
                color: Color(0xFF1B1B26),
                borderRadius: BorderRadius.vertical(top: Radius.circular(35)),
                boxShadow: [
                  BoxShadow(color: Colors.black87, blurRadius: 35, offset: Offset(0, -10)),
                ],
              ),
              padding: const EdgeInsets.all(26),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: const [
                          Icon(Icons.shopping_bag_rounded, color: Color(0xFFFFB703), size: 30),
                          SizedBox(width: 12),
                          Text(
                            'سلة المشتريات الذكية',
                            style: TextStyle(color: Color(0xFFFFB703), fontSize: 20, fontWeight: FontWeight.w900),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: Colors.white70),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const Divider(color: Colors.white12, height: 30),
                  Expanded(
                    child: cart.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: const [
                                Icon(Icons.remove_shopping_cart_rounded, size: 70, color: Colors.white24),
                                SizedBox(height: 14),
                                Text('السلة فارغة حالياً', style: TextStyle(color: Colors.white38, fontSize: 15)),
                              ],
                            ),
                          )
                        : ListView.builder(
                            itemCount: cart.length,
                            itemBuilder: (context, index) {
                              final item = cart[index];
                              return Container(
                                margin: const EdgeInsets.symmetric(vertical: 8),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF262636),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: const Color(0xFF36364D)),
                                ),
                                child: Row(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(14),
                                      child: CachedNetworkImage(
                                        imageUrl: item.product['image'] ?? '',
                                        width: 65,
                                        height: 65,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            item.product['title'] ?? '',
                                            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 14),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            item.product['price'] ?? '',
                                            style: const TextStyle(color: Color(0xFFFFB703), fontSize: 13, fontWeight: FontWeight.w900),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Row(
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.remove_circle_outline, color: Colors.white70, size: 22),
                                          onPressed: () {
                                            setCartState(() {
                                              if (item.quantity > 1) {
                                                item.quantity--;
                                              } else {
                                                cart.removeAt(index);
                                              }
                                              setState(() {});
                                            });
                                          },
                                        ),
                                        Text('${item.quantity}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                                        IconButton(
                                          icon: const Icon(Icons.add_circle_outline, color: Color(0xFFFFB703), size: 22),
                                          onPressed: () {
                                            setCartState(() {
                                              item.quantity++;
                                              setState(() {});
                                            });
                                          },
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
                  if (cart.isNotEmpty) ...[
                    const Divider(color: Colors.white12),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('المجموع الكلي:', style: TextStyle(fontSize: 16, color: Colors.white70)),
                          Text(
                            '$totalSum ل.س',
                            style: const TextStyle(fontSize: 21, color: Color(0xFFFFB703), fontWeight: FontWeight.w900),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.verified_rounded),
                        label: const Text('إتمام طلب السلة الآن'),
                        onPressed: () {
                          Navigator.pop(context);
                          _checkoutCart(cart, totalSum);
                        },
                      ),
                    ),
                  ]
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _checkoutCart(List<CartItem> cart, int totalSum) async {
    // تم جعل الحقل فارغاً بطلب منك تماماً
    final deliveryPhoneController = TextEditingController();
    final universityController = TextEditingController();
    String paymentMethod = 'نقدي عند الاستلام';

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1B1B26),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
              title: const Text('تأكيد طلب السلة 🛒', style: TextStyle(color: Color(0xFFFFB703), fontWeight: FontWeight.w900)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('عدد المنتجات: ${cart.length}', style: const TextStyle(color: Colors.white70)),
                    const SizedBox(height: 16),
                    const Text('طريقة الدفع:', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    DropdownButton<String>(
                      value: paymentMethod,
                      isExpanded: true,
                      dropdownColor: const Color(0xFF262636),
                      items: ['نقدي عند الاستلام', 'شام كاش (الدفع الفوري)']
                          .map((method) => DropdownMenuItem(value: method, child: Text(method)))
                          .toList(),
                      onChanged: (val) => setDialogState(() => paymentMethod = val!),
                    ),
                    const SizedBox(height: 16),
                    const Text('رقم التواصل للتسليم *', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFFFB703))),
                    const SizedBox(height: 6),
                    TextField(
                      controller: deliveryPhoneController,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                        hintText: '+963...',
                        filled: true,
                        fillColor: const Color(0xFF262636),
                      ),
                      onChanged: (_) => setDialogState(() {}),
                    ),
                    const SizedBox(height: 16),
                    const Text('الجامعة المراد الاستلام منها *', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFFFB703))),
                    const SizedBox(height: 6),
                    TextField(
                      controller: universityController,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                        hintText: 'اسم الجامعة...',
                        filled: true,
                        fillColor: const Color(0xFF262636),
                      ),
                      onChanged: (_) => setDialogState(() {}),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('إلغاء', style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  onPressed: (deliveryPhoneController.text.trim().isEmpty ||
                          universityController.text.trim().isEmpty)
                      ? null
                      : () async {
                          Navigator.pop(context);

                          String itemsSummary = cart
                              .map((item) => "• ${item.product['title']} (العدد: ${item.quantity})")
                              .join("\n");

                          String orderMsg = "📦 طلب منتجات من سلة المشتريات:\n"
                              "👤 الزبون: ${widget.userName}\n"
                              "📱 رقم الهاتف المسجل: ${widget.userPhone}\n"
                              "📋 العناصر:\n$itemsSummary\n"
                              "💰 المجموع الكلي: $totalSum ل.س\n"
                              "- طريقة الدفع: $paymentMethod\n"
                              "- رقم التواصل للتسليم: ${deliveryPhoneController.text.trim()}\n"
                              "- الجامعة: ${universityController.text.trim()}";

                          try {
                            final chatRef = FirebaseFirestore.instance.collection('chats').doc(widget.userName);
                            await chatRef.set({
                              'lastActive': FieldValue.serverTimestamp(),
                              'studentName': widget.userName,
                            }, SetOptions(merge: true));

                            await chatRef.collection('messages').add({
                              'senderName': widget.userName,
                              'text': orderMsg,
                              'isAdmin': false,
                              'timestamp': FieldValue.serverTimestamp(),
                            });

                            await chatRef.collection('messages').add({
                              'senderName': 'الإدارة',
                              'text': 'مرحباً بك، تم تلقي طلب السلة بنجاح. يرجى الانتظار لحين تأكيده.',
                              'isAdmin': true,
                              'timestamp': FieldValue.serverTimestamp(),
                            });
                          } catch (e) {
                            debugPrint("Error sending order: $e");
                          }

                          addAppNotification(
                            targetUserName: widget.userName,
                            title: 'تم إرسال طلب السلة بنجاح 🛒',
                            message: 'تم إرسال طلب السلة المتضمن (${cart.length}) منتجات إلى الإدارة بنجاح.',
                            icon: Icons.shopping_cart_outlined,
                            iconColor: const Color(0xFFFFB703),
                          );

                          setState(() {
                            userCarts[widget.userName]?.clear();
                          });

                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ChatScreen(userName: widget.userName, isAdmin: false),
                            ),
                          );
                        },
                  child: const Text('تأكيد الإرسال للإدارة'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _openNotificationsSheet() {
    List<NotificationItem> notifs = userNotifications[widget.userName] ?? [];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.70,
              decoration: const BoxDecoration(
                color: Color(0xFF1B1B26),
                borderRadius: BorderRadius.vertical(top: Radius.circular(35)),
                boxShadow: [
                  BoxShadow(color: Colors.black87, blurRadius: 35, offset: Offset(0, -10)),
                ],
              ),
              padding: const EdgeInsets.all(26),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: const [
                          Icon(Icons.notifications_active_rounded, color: Color(0xFFFFB703), size: 30),
                          SizedBox(width: 12),
                          Text(
                            'الإشعارات والتحديثات',
                            style: TextStyle(color: Color(0xFFFFB703), fontSize: 20, fontWeight: FontWeight.w900),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: Colors.white70),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const Divider(color: Colors.white12, height: 30),
                  Expanded(
                    child: notifs.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: const [
                                Icon(Icons.notifications_off_rounded, size: 70, color: Colors.white24),
                                SizedBox(height: 14),
                                Text('لا توجد إشعارات جديدة حالياً', style: TextStyle(color: Colors.white38, fontSize: 15)),
                              ],
                            ),
                          )
                        : ListView.builder(
                            itemCount: notifs.length,
                            itemBuilder: (context, index) {
                              final item = notifs[index];
                              return Container(
                                margin: const EdgeInsets.symmetric(vertical: 8),
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF262636),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: const Color(0xFF36364D)),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: item.iconColor.withOpacity(0.15),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(item.icon, color: item.iconColor, size: 24),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(
                                                item.title,
                                                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 15),
                                              ),
                                              Text(
                                                item.time,
                                                style: const TextStyle(color: Colors.white38, fontSize: 11),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            item.message,
                                            style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
                                          ),
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
      },
    ).then((_) {
      setState(() {
        for (var n in notifs) {
          n.isRead = true;
        }
      });
    });
  }

  void _showOrderDialog(Map<String, dynamic> product) {
    int quantity = 1;
    String paymentMethod = 'نقدي عند الاستلام';
    // تم جعل الحقل فارغاً تماماً ليقوم المستخدم بكتابة الرقم من جديد بدون مسح
    final deliveryPhoneController = TextEditingController();
    final universityController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1B1B26),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
              title: Text('طلب: ${product['title']}', style: const TextStyle(color: Color(0xFFFFB703), fontWeight: FontWeight.w900)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('السعر للقطعة: ${product['price']}', style: const TextStyle(color: Colors.white60)),
                    const SizedBox(height: 20),
                    const Text('عدد القطع المطلوبة:', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.remove_circle, color: Color(0xFFFFB703)),
                          onPressed: () {
                            if (quantity > 1) {
                              setDialogState(() => quantity--);
                            }
                          },
                        ),
                        Text('$quantity', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                        IconButton(
                          icon: const Icon(Icons.add_circle, color: Color(0xFFFFB703)),
                          onPressed: () {
                            setDialogState(() => quantity++);
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text('طريقة الدفع:', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    DropdownButton<String>(
                      value: paymentMethod,
                      isExpanded: true,
                      dropdownColor: const Color(0xFF262636),
                      items: ['نقدي عند الاستلام', 'شام كاش (الدفع الفوري)']
                          .map((method) => DropdownMenuItem(value: method, child: Text(method)))
                          .toList(),
                      onChanged: (val) {
                        setDialogState(() => paymentMethod = val!);
                      },
                    ),
                    const SizedBox(height: 16),
                    const Text('رقم التواصل للتسليم *', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFFFB703))),
                    const SizedBox(height: 6),
                    TextField(
                      controller: deliveryPhoneController,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                        hintText: '+963...',
                        filled: true,
                        fillColor: const Color(0xFF262636),
                      ),
                      onChanged: (_) => setDialogState(() {}),
                    ),
                    const SizedBox(height: 16),
                    const Text('اسم الجامعة للاستلام *', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFFFB703))),
                    const SizedBox(height: 6),
                    TextField(
                      controller: universityController,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                        hintText: 'اكتب اسم الجامعة هنا...',
                        filled: true,
                        fillColor: const Color(0xFF262636),
                      ),
                      onChanged: (_) => setDialogState(() {}),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('إلغاء', style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  onPressed: (deliveryPhoneController.text.trim().isEmpty ||
                          universityController.text.trim().isEmpty)
                      ? null
                      : () async {
                          Navigator.pop(context);

                          String orderMsg = "📦 طلب منتج جديد:\n"
                              "👤 الزبون: ${widget.userName}\n"
                              "📱 رقم الهاتف المسجل: ${widget.userPhone}\n"
                              "- المنتج: ${product['title']}\n"
                              "- السعر الفردي: ${product['price']}\n"
                              "- عدد القطع: $quantity\n"
                              "- الدفع: $paymentMethod\n"
                              "- هاتف التسليم: ${deliveryPhoneController.text.trim()}\n"
                              "- الجامعة: ${universityController.text.trim()}";

                          try {
                            final chatRef = FirebaseFirestore.instance.collection('chats').doc(widget.userName);
                            await chatRef.set({
                              'lastActive': FieldValue.serverTimestamp(),
                              'studentName': widget.userName,
                            }, SetOptions(merge: true));

                            await chatRef.collection('messages').add({
                              'senderName': widget.userName,
                              'text': orderMsg,
                              'isAdmin': false,
                              'timestamp': FieldValue.serverTimestamp(),
                            });

                            await chatRef.collection('messages').add({
                              'senderName': 'الإدارة',
                              'text': 'مرحباً بك، تم تلقي طلبك بنجاح وجاري المراجعة.',
                              'isAdmin': true,
                              'timestamp': FieldValue.serverTimestamp(),
                            });
                          } catch (e) {
                            debugPrint("Error sending order: $e");
                          }

                          addAppNotification(
                            targetUserName: widget.userName,
                            title: 'تم إرسال طلبك بنجاح 📦',
                            message: 'تم إرسال طلبك (${product['title']}) إلى الإدارة بنجاح.',
                            icon: Icons.shopping_bag_outlined,
                            iconColor: const Color(0xFFFFB703),
                          );

                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ChatScreen(userName: widget.userName, isAdmin: false),
                            ),
                          );
                        },
                  child: const Text('تأكيد الإرسال للإدارة'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isDark = HyStoreApp.of(context).isDarkMode;
    List<NotificationItem> notifs = userNotifications[widget.userName] ?? [];
    int unreadCount = notifs.where((n) => !n.isRead).length;
    List<CartItem> cart = userCarts[widget.userName] ?? [];
    int cartCount = cart.fold(0, (sum, item) => sum + item.quantity);

    return Scaffold(
      body: Stack(
        children: [
          const BackgroundStickersLayer(),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppBar(
                title: const Text('HY STORE'),
                actions: [
                  IconButton(
                    icon: Icon(isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded, color: const Color(0xFFFFB703), size: 24),
                    onPressed: () => HyStoreApp.of(context).toggleTheme(),
                    tooltip: 'تبديل المظهر',
                  ),
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.shopping_cart_outlined, color: Color(0xFFFFB703), size: 26),
                        onPressed: _openCartSheet,
                        tooltip: 'سلة المشتريات',
                      ),
                      if (cartCount > 0)
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Color(0xFFFFB703),
                              shape: BoxShape.circle,
                            ),
                            constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                            child: Text(
                              '$cartCount',
                              style: const TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.w900),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                    ],
                  ),
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.notifications_none_rounded, color: Color(0xFFFFB703), size: 26),
                        onPressed: _openNotificationsSheet,
                        tooltip: 'الإشعارات',
                      ),
                      if (unreadCount > 0)
                        Positioned(
                          top: 10,
                          right: 10,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Colors.redAccent,
                              shape: BoxShape.circle,
                            ),
                            constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                            child: Text(
                              '$unreadCount',
                              style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                    ],
                  ),
                  if (widget.isAdmin)
                    TextButton.icon(
                      style: TextButton.styleFrom(foregroundColor: const Color(0xFFFFB703)),
                      icon: const Icon(Icons.admin_panel_settings_rounded, color: Color(0xFFFFB703)),
                      label: const Text('الأدمن', style: TextStyle(fontWeight: FontWeight.bold)),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => AdminDashboard(adminName: widget.userName),
                          ),
                        ).then((_) => setState(() {}));
                      },
                    ),
                  IconButton(
                    icon: const Icon(Icons.chat_bubble_outline_rounded, color: Color(0xFFFFB703)),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ChatScreen(userName: widget.userName, isAdmin: false),
                        ),
                      );
                    },
                    tooltip: 'محادثة الإدارة',
                  ),
                  IconButton(
                    icon: const Icon(Icons.support_agent_rounded, color: Color(0xFFFFB703)),
                    onPressed: _openSupportWhatsApp,
                    tooltip: 'الدعم الفني',
                  ),
                  IconButton(
                    icon: const Icon(Icons.logout_rounded, color: Colors.redAccent),
                    onPressed: () => _logout(context),
                    tooltip: 'تسجيل خروج',
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                child: Container(
                  height: 125,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(26),
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF2A2A38), Color(0xFF1B1B26)],
                    ),
                    border: Border.all(color: const Color(0xFFFFB703).withOpacity(0.5), width: 1.8),
                    boxShadow: const [
                      BoxShadow(color: Color(0x33FFB703), blurRadius: 25, offset: Offset(0, 8)),
                    ],
                  ),
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFFFFB703).withOpacity(0.2),
                          boxShadow: const [BoxShadow(color: Color(0x33FFB703), blurRadius: 10)],
                        ),
                        child: const Icon(Icons.storefront_rounded, size: 38, color: Color(0xFFFFB703)),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Text(
                              'أهلاً بك في منصة HY STORE',
                              style: TextStyle(color: Color(0xFFFFB703), fontWeight: FontWeight.w900, fontSize: 17),
                            ),
                            SizedBox(height: 6),
                            Text(
                              'أفضل الأسعار وأفضل المستلزمات جودة وأفضل خدمة يقدمها لكم متجرنا',
                              style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.3),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                child: TextField(
                  controller: _searchController,
                  style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                  decoration: InputDecoration(
                    hintText: selectedCategory == 'الكل'
                        ? 'ابحث عن أي منتج في المتجر الذكي...'
                        : 'ابحث في قسم $selectedCategory...',
                    hintStyle: TextStyle(color: isDark ? Colors.white38 : Colors.black45),
                    prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFFFFB703)),
                    suffixIcon: searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, color: Colors.grey),
                            onPressed: () {
                              setState(() {
                                _searchController.clear();
                                searchQuery = '';
                              });
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: isDark ? const Color(0xFF1B1B26).withOpacity(0.9) : Colors.white.withOpacity(0.9),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide: BorderSide(color: isDark ? const Color(0xFF2E2E40) : const Color(0xFFCBD5E1)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide: const BorderSide(color: Color(0xFFFFB703), width: 2),
                    ),
                  ),
                  onChanged: (val) {
                    setState(() {
                      searchQuery = val.trim();
                    });
                  },
                ),
              ),
              SizedBox(
                height: 68,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  itemCount: globalCategories.length,
                  itemBuilder: (context, index) {
                    String cat = globalCategories[index];
                    bool isSelected = selectedCategory == cat;
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
                      child: ChoiceChip(
                        avatar: Icon(
                          cat == 'عمارة' ? Icons.architecture_rounded :
                          cat == 'أسنان' ? Icons.medical_services_rounded :
                          cat == 'مدنية' ? Icons.apartment_rounded :
                          cat == 'معلوماتية' ? Icons.computer_rounded :
                          cat == 'بشرية' ? Icons.local_hospital_rounded :
                          cat == 'ديكور' ? Icons.chair_rounded : Icons.star_rounded,
                          color: isSelected ? Colors.black : const Color(0xFFFFB703),
                          size: 22,
                        ),
                        label: Text(cat, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),
                        selected: isSelected,
                        selectedColor: const Color(0xFFFFB703),
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.black : (isDark ? Colors.white : Colors.black87),
                          fontWeight: FontWeight.w900,
                        ),
                        backgroundColor: isDark ? const Color(0xFF222232) : const Color(0xFFE2E8F0),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                        onSelected: (bool selected) {
                          setState(() {
                            selectedCategory = cat;
                          });
                        },
                      ),
                    );
                  },
                ),
              ),
              const Divider(height: 1, color: Color(0xFF2A2A3E)),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance.collection('products').snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(color: Color(0xFFFFB703)),
                            SizedBox(height: 14),
                            Text('جاري تحميل المنتجات السحابية...', style: TextStyle(color: Colors.white54, fontSize: 13)),
                          ],
                        ),
                      );
                    }

                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.inventory_2_outlined, size: 75, color: Color(0xFFFFB703)),
                              const SizedBox(height: 16),
                              const Text(
                                'لا توجد منتجات مضافة بعد في السحابة.',
                                style: TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.bold),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'اضغط على الزر أدناه لإضافة منتج تجريبي واختبار العرض:',
                                style: TextStyle(color: Colors.white38, fontSize: 12),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 24),
                              ElevatedButton.icon(
                                onPressed: _addSampleProductForTest,
                                icon: const Icon(Icons.add_circle_outline_rounded),
                                label: const Text('إضافة منتج تجريبي الآن'),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    var firestoreProducts = snapshot.data!.docs.map((doc) {
                      var data = doc.data() as Map<String, dynamic>;
                      data['id'] = doc.id;
                      data['ratings'] = data['ratings'] ?? {};
                      return data;
                    }).toList();

                    List filteredProducts = firestoreProducts.where((p) {
                      bool matchesCategory = (selectedCategory == 'الكل') || (p['category'] == selectedCategory);
                      bool matchesQuery = searchQuery.isEmpty ||
                          p['title'].toString().toLowerCase().contains(searchQuery.toLowerCase()) ||
                          p['description'].toString().toLowerCase().contains(searchQuery.toLowerCase());
                      return matchesCategory && matchesQuery;
                    }).toList();

                    if (filteredProducts.isEmpty) {
                      return const Center(
                        child: Text(
                          'لا توجد منتجات تطابق بحثك',
                          style: TextStyle(color: Colors.white38, fontSize: 15),
                        ),
                      );
                    }

                    return GridView.builder(
                      padding: const EdgeInsets.all(16),
                      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 280,
                        childAspectRatio: 0.53,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                      ),
                      itemCount: filteredProducts.length,
                      itemBuilder: (context, index) {
                        final product = filteredProducts[index];
                        bool isFav = favoriteProductIds.contains(product['id']);

                        return GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ProductDetailScreen(
                                  product: product,
                                  userName: widget.userName,
                                  userPhone: widget.userPhone,
                                  onAddToCart: () => _addToCart(product),
                                ),
                              ),
                            ).then((_) => setState(() {}));
                          },
                          child: Transform(
                            transform: Matrix4.identity()
                              ..setEntry(3, 2, 0.001)
                              ..rotateX(0.015)
                              ..rotateY(0.015),
                            alignment: Alignment.center,
                            child: Container(
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF1B1B26).withOpacity(0.95) : Colors.white.withOpacity(0.95),
                                borderRadius: BorderRadius.circular(26),
                                border: Border.all(color: const Color(0xFF2E2E40)),
                                boxShadow: const [
                                  BoxShadow(color: Color(0x33FFB703), blurRadius: 20, offset: Offset(0, 10)),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Stack(
                                      children: [
                                        ClipRRect(
                                          borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
                                          child: CachedNetworkImage(
                                            imageUrl: product['image'] ?? '',
                                            fit: BoxFit.cover,
                                            width: double.infinity,
                                            placeholder: (context, url) => const Center(
                                              child: CircularProgressIndicator(color: Color(0xFFFFB703)),
                                            ),
                                            errorWidget: (context, url, error) => const Icon(Icons.error),
                                          ),
                                        ),
                                        Positioned(
                                          top: 10,
                                          right: 10,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                            decoration: BoxDecoration(
                                              color: Colors.black.withOpacity(0.85),
                                              borderRadius: BorderRadius.circular(12),
                                              border: Border.all(color: const Color(0xFFFFB703).withOpacity(0.7)),
                                            ),
                                            child: Text(
                                              product['category'] ?? '',
                                              style: const TextStyle(color: Color(0xFFFFB703), fontSize: 10, fontWeight: FontWeight.w900),
                                            ),
                                          ),
                                        ),
                                        Positioned(
                                          top: 10,
                                          left: 10,
                                          child: GestureDetector(
                                            onTap: () {
                                              setState(() {
                                                if (isFav) {
                                                  favoriteProductIds.remove(product['id']);
                                                } else {
                                                  favoriteProductIds.add(product['id']);
                                                }
                                              });
                                            },
                                            child: CircleAvatar(
                                              radius: 17,
                                              backgroundColor: Colors.black.withOpacity(0.85),
                                              child: Icon(
                                                isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                                                color: isFav ? Colors.redAccent : Colors.white,
                                                size: 19,
                                              ),
                                            ),
                                          ),
                                        ),
                                        // زر الثلاث نقاط للأدمن حصراً
                                        if (widget.isAdmin)
                                          Positioned(
                                            top: 45,
                                            left: 10,
                                            child: Container(
                                              decoration: BoxDecoration(
                                                color: Colors.black.withOpacity(0.85),
                                                shape: BoxShape.circle,
                                                border: Border.all(color: const Color(0xFFFFB703)),
                                              ),
                                              child: PopupMenuButton<String>(
                                                icon: const Icon(Icons.more_vert_rounded, color: Color(0xFFFFB703), size: 18),
                                                color: const Color(0xFF1B1B26),
                                                onSelected: (val) {
                                                  if (val == 'edit') {
                                                    _showEditProductDialog(product);
                                                  } else if (val == 'delete') {
                                                    _deleteProduct(product['id']);
                                                  }
                                                },
                                                itemBuilder: (context) => [
                                                  const PopupMenuItem(
                                                    value: 'edit',
                                                    child: Text('تعديل المنتج', style: TextStyle(color: Color(0xFFFFB703), fontWeight: FontWeight.bold)),
                                                  ),
                                                  const PopupMenuItem(
                                                    value: 'delete',
                                                    child: Text('حذف المنتج', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.all(12.0),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          product['title'] ?? '',
                                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isDark ? Colors.white : Colors.black87),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          product['price'] ?? '',
                                          style: const TextStyle(color: Color(0xFFFFB703), fontWeight: FontWeight.w900, fontSize: 15),
                                        ),
                                        const SizedBox(height: 10),
                                        SizedBox(
                                          width: double.infinity,
                                          height: 36,
                                          child: ElevatedButton(
                                            onPressed: () => _showOrderDialog(product),
                                            child: const Text('طلب سريع', style: TextStyle(fontSize: 11)),
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        SizedBox(
                                          width: double.infinity,
                                          height: 36,
                                          child: OutlinedButton.icon(
                                            onPressed: () => _addToCart(product),
                                            style: OutlinedButton.styleFrom(
                                              side: const BorderSide(color: Color(0xFFFFB703)),
                                              padding: EdgeInsets.zero,
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                            ),
                                            icon: const Icon(Icons.bookmark_add_outlined, size: 14, color: Color(0xFFFFB703)),
                                            label: const Text('إضافة للسلة', style: TextStyle(fontSize: 10, color: Color(0xFFFFB703), fontWeight: FontWeight.bold)),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
      drawer: Drawer(
        backgroundColor: isDark ? const Color(0xFF161622) : Colors.white,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            UserAccountsDrawerHeader(
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: isDark ? [const Color(0xFF2A2A38), const Color(0xFF121218)] : [const Color(0xFFFFB703), const Color(0xFFFB8500)]),
              ),
              currentAccountPicture: const CircleAvatar(
                backgroundColor: Color(0xFFFFB703),
                child: Icon(Icons.person_rounded, size: 40, color: Colors.black),
              ),
              accountName: Text(
                widget.userName,
                style: const TextStyle(color: Color(0xFFFFB703), fontWeight: FontWeight.w900, fontSize: 17),
              ),
              accountEmail: Text(
                widget.userPhone,
                style: const TextStyle(color: Colors.white70),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.store_rounded, color: Color(0xFFFFB703)),
              title: const Text('المتجر الرئيسي'),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: const Icon(Icons.shopping_cart_rounded, color: Color(0xFFFFB703)),
              title: Text('سلة المشتريات ($cartCount)'),
              onTap: () {
                Navigator.pop(context);
                _openCartSheet();
              },
            ),
            ListTile(
              leading: const Icon(Icons.favorite_rounded, color: Colors.redAccent),
              title: Text('المنتجات المفضلة (${favoriteProductIds.length})'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => FavoritesScreen(
                      favoriteIds: favoriteProductIds,
                      userName: widget.userName,
                      userPhone: widget.userPhone,
                    ),
                  ),
                ).then((_) => setState(() {}));
              },
            ),
            ListTile(
              leading: const Icon(Icons.notifications_none_rounded, color: Color(0xFFFFB703)),
              title: const Text('الإشعارات والتحديثات'),
              onTap: () {
                Navigator.pop(context);
                _openNotificationsSheet();
              },
            ),
            ListTile(
              leading: const Icon(Icons.chat_bubble_outline_rounded, color: Color(0xFFFFB703)),
              title: const Text('محادثتي مع الإدارة'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ChatScreen(userName: widget.userName, isAdmin: false),
                  ),
                );
              },
            ),
            const Divider(color: Colors.white12),
            ListTile(
              leading: const Icon(Icons.logout_rounded, color: Colors.redAccent),
              title: const Text('تسجيل خروج', style: TextStyle(color: Colors.redAccent)),
              onTap: () => _logout(context),
            ),
          ],
        ),
      ),
    );
  }
}

// ----------------- صفحة المفضلة -----------------
class FavoritesScreen extends StatefulWidget {
  final Set<String> favoriteIds;
  final String userName;
  final String userPhone;
  const FavoritesScreen({super.key, required this.favoriteIds, required this.userName, required this.userPhone});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('المنتجات المفضلة ❤️')),
      body: Stack(
        children: [
          const BackgroundStickersLayer(),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('products').snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator(color: Color(0xFFFFB703)));
              }

              var favProducts = snapshot.data!.docs.map((doc) {
                var data = doc.data() as Map<String, dynamic>;
                data['id'] = doc.id;
                return data;
              }).where((p) => widget.favoriteIds.contains(p['id'])).toList();

              if (favProducts.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.favorite_border_rounded, size: 70, color: Colors.white24),
                      SizedBox(height: 16),
                      Text('لم تقم بإضافة أي منتجات للمفضلة بعد', style: TextStyle(color: Colors.white38, fontSize: 15)),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: favProducts.length,
                itemBuilder: (context, index) {
                  final product = favProducts[index];
                  return Container(
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1B1B26),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFF2E2E40)),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(12),
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: CachedNetworkImage(imageUrl: product['image'] ?? '', width: 65, height: 65, fit: BoxFit.cover),
                      ),
                      title: Text(product['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                      subtitle: Text('${product['category']} | ${product['price']}', style: const TextStyle(color: Color(0xFFFFB703), fontWeight: FontWeight.w900)),
                      trailing: IconButton(
                        icon: const Icon(Icons.favorite_rounded, color: Colors.redAccent),
                        onPressed: () {
                          setState(() {
                            widget.favoriteIds.remove(product['id']);
                          });
                        },
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}

// ----------------- صفحة تفاصيل المنتج -----------------
class ProductDetailScreen extends StatefulWidget {
  final Map<String, dynamic> product;
  final String userName;
  final String userPhone;
  final VoidCallback onAddToCart;
  const ProductDetailScreen({
    super.key,
    required this.product,
    required this.userName,
    required this.userPhone,
    required this.onAddToCart,
  });

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  void _openImageFullScreen(String imageUrl) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            InteractiveViewer(
              child: CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.contain,
                placeholder: (context, url) => const Center(child: CircularProgressIndicator(color: Color(0xFFFFB703))),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close_rounded, color: Colors.white, size: 30),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  void _rateProduct(int stars) async {
    Map<String, dynamic> ratings = Map<String, dynamic>.from(widget.product['ratings'] ?? {});
    ratings[widget.userName] = stars;

    await FirebaseFirestore.instance.collection('products').doc(widget.product['id']).update({
      'ratings': ratings,
    });

    setState(() {
      widget.product['ratings'] = ratings;
    });

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('تم تسجيل تقييمك ($stars نجوم) بنجاح!')),
    );
  }

  double _calculateAverageRating() {
    Map<String, dynamic> ratings = Map<String, dynamic>.from(widget.product['ratings'] ?? {});
    if (ratings.isEmpty) return 0.0;
    int sum = ratings.values.fold(0, (a, b) => a + (b as int));
    return sum / ratings.length;
  }

  void _showOrderDialog() {
    int quantity = 1;
    String paymentMethod = 'نقدي عند الاستلام';
    // حقل الهاتف فارغ تماماً مثل الطلب
    final deliveryPhoneController = TextEditingController();
    final universityController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1B1B26),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
              title: Text('طلب: ${widget.product['title']}', style: const TextStyle(color: Color(0xFFFFB703), fontWeight: FontWeight.w900)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('السعر للقطعة: ${widget.product['price']}', style: const TextStyle(color: Colors.white60)),
                    const SizedBox(height: 20),
                    const Text('عدد القطع المطلوبة:', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.remove_circle, color: Color(0xFFFFB703)),
                          onPressed: () {
                            if (quantity > 1) setDialogState(() => quantity--);
                          },
                        ),
                        Text('$quantity', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                        IconButton(
                          icon: const Icon(Icons.add_circle, color: Color(0xFFFFB703)),
                          onPressed: () => setDialogState(() => quantity++),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text('طريقة الدفع:', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    DropdownButton<String>(
                      value: paymentMethod,
                      isExpanded: true,
                      dropdownColor: const Color(0xFF262636),
                      items: ['نقدي عند الاستلام', 'شام كاش (الدفع الفوري)']
                          .map((method) => DropdownMenuItem(value: method, child: Text(method)))
                          .toList(),
                      onChanged: (val) => setDialogState(() => paymentMethod = val!),
                    ),
                    const SizedBox(height: 16),
                    const Text('رقم التواصل للتسليم *', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFFFB703))),
                    const SizedBox(height: 6),
                    TextField(
                      controller: deliveryPhoneController,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                        hintText: '+963...',
                        filled: true,
                        fillColor: const Color(0xFF262636),
                      ),
                      onChanged: (_) => setDialogState(() {}),
                    ),
                    const SizedBox(height: 16),
                    const Text('اسم الجامعة للاستلام *', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFFFB703))),
                    const SizedBox(height: 6),
                    TextField(
                      controller: universityController,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                        hintText: 'اسم الجامعة...',
                        filled: true,
                        fillColor: const Color(0xFF262636),
                      ),
                      onChanged: (_) => setDialogState(() {}),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('إلغاء', style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  onPressed: (deliveryPhoneController.text.trim().isEmpty ||
                          universityController.text.trim().isEmpty)
                      ? null
                      : () async {
                          Navigator.pop(context);
                          String orderMsg = "📦 طلب منتج جديد:\n"
                              "👤 الزبون: ${widget.userName}\n"
                              "📱 الهاتف: ${widget.userPhone}\n"
                              "- المنتج: ${widget.product['title']}\n"
                              "- السعر الفردي: ${widget.product['price']}\n"
                              "- العدد: $quantity\n"
                              "- الدفع: $paymentMethod\n"
                              "- هاتف التسليم: ${deliveryPhoneController.text.trim()}\n"
                              "- الجامعة: ${universityController.text.trim()}";

                          try {
                            final chatRef = FirebaseFirestore.instance.collection('chats').doc(widget.userName);
                            await chatRef.set({
                              'lastActive': FieldValue.serverTimestamp(),
                              'studentName': widget.userName,
                            }, SetOptions(merge: true));

                            await chatRef.collection('messages').add({
                              'senderName': widget.userName,
                              'text': orderMsg,
                              'isAdmin': false,
                              'timestamp': FieldValue.serverTimestamp(),
                            });

                            await chatRef.collection('messages').add({
                              'senderName': 'الإدارة',
                              'text': 'مرحباً بك، تم تلقي طلبك بنجاح وجاري المراجعة.',
                              'isAdmin': true,
                              'timestamp': FieldValue.serverTimestamp(),
                            });
                          } catch (e) {
                            debugPrint("Error sending order: $e");
                          }

                          addAppNotification(
                            targetUserName: widget.userName,
                            title: 'تم إرسال طلبك بنجاح 📦',
                            message: 'تم إرسال طلبك (${widget.product['title']}) إلى الإدارة بنجاح.',
                            icon: Icons.shopping_bag_outlined,
                            iconColor: const Color(0xFFFFB703),
                          );

                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ChatScreen(userName: widget.userName, isAdmin: false),
                            ),
                          );
                        },
                  child: const Text('تأكيد الإرسال للإدارة'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    double avgRating = _calculateAverageRating();
    Map<String, dynamic> ratings = Map<String, dynamic>.from(widget.product['ratings'] ?? {});
    int myRating = ratings[widget.userName] ?? 0;

    return Scaffold(
      appBar: AppBar(title: Text(widget.product['title'] ?? '')),
      body: Stack(
        children: [
          const BackgroundStickersLayer(),
          SingleChildScrollView(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                GestureDetector(
                  onTap: () => _openImageFullScreen(widget.product['image'] ?? ''),
                  child: Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(26),
                        child: CachedNetworkImage(
                          imageUrl: widget.product['image'] ?? '',
                          height: 320,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          placeholder: (context, url) => const Center(child: CircularProgressIndicator(color: Color(0xFFFFB703))),
                          errorWidget: (context, url, error) => const Icon(Icons.error),
                        ),
                      ),
                      Positioned(
                        bottom: 14,
                        right: 14,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.8),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFFFFB703)),
                          ),
                          child: Row(
                            children: const [
                              Icon(Icons.zoom_in_rounded, color: Color(0xFFFFB703), size: 20),
                              SizedBox(width: 6),
                              Text('معاينة مكبرة', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  widget.product['title'] ?? '',
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.white),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.product['price'] ?? '',
                  style: const TextStyle(fontSize: 24, color: Color(0xFFFFB703), fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 14),
                Align(
                  alignment: Alignment.centerRight,
                  child: Chip(
                    label: Text('القسم: ${widget.product['category']}'),
                    backgroundColor: const Color(0xFF262636),
                    labelStyle: const TextStyle(color: Color(0xFFFFB703), fontWeight: FontWeight.w900),
                  ),
                ),
                const SizedBox(height: 20),
                const Text('تفاصيل ومواصفات المنتج:', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: Color(0xFFFFB703))),
                const SizedBox(height: 8),
                Text(
                  widget.product['description'] ?? 'لا توجد تفاصيل إضافية.',
                  style: const TextStyle(color: Colors.white70, fontSize: 15, height: 1.6),
                ),
                const Divider(height: 40, color: Colors.white12),
                const Text('تقييمات المستخدمين للمنتج', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: Color(0xFFFFB703))),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.star_rounded, color: Colors.amber, size: 30),
                    const SizedBox(width: 8),
                    Text(
                      avgRating.toStringAsFixed(1),
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                    ),
                    Text(' (${ratings.length} تقييمات)', style: const TextStyle(color: Colors.white38)),
                  ],
                ),
                const SizedBox(height: 16),
                const Text('قيّم هذا المنتج:', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Row(
                  children: List.generate(5, (index) {
                    int starVal = index + 1;
                    return IconButton(
                      icon: Icon(
                        starVal <= myRating ? Icons.star_rounded : Icons.star_border_rounded,
                        color: Colors.amber,
                        size: 34,
                      ),
                      onPressed: () => _rateProduct(starVal),
                    );
                  }),
                ),
                const SizedBox(height: 35),
                ElevatedButton(
                  onPressed: _showOrderDialog,
                  style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 18), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18))),
                  child: const Text('طلب هذا المنتج الآن', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
                ),
                const SizedBox(height: 14),
                OutlinedButton.icon(
                  onPressed: widget.onAddToCart,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    side: const BorderSide(color: Color(0xFFFFB703), width: 2),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  ),
                  icon: const Icon(Icons.bookmark_add_outlined, color: Color(0xFFFFB703)),
                  label: const Text('إضافة إلى سلة المشتريات', style: TextStyle(color: Color(0xFFFFB703), fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ----------------- لوحة تحكم الأدمن -----------------
class AdminDashboard extends StatefulWidget {
  final String adminName;
  const AdminDashboard({super.key, required this.adminName});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  int _selectedTab = 0;

  final _titleController = TextEditingController();
  final _priceController = TextEditingController();
  final _descController = TextEditingController();
  final _imageController = TextEditingController();
  String? editingProductId;
  String selectedProductCategory = 'عمارة';
  final _categoryController = TextEditingController();

  bool isLoadingTelegramImages = false;
  List<String> telegramImages = [];
  final String tgToken = "8623101299:AAFK03es2d1eSXnoDbBF3NsPARLQxn7J68M";

  Future<void> _fetchTelegramGallery() async {
    setState(() => isLoadingTelegramImages = true);
    try {
      final url = Uri.parse('https://api.telegram.org/bot$tgToken/getUpdates');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        List<String> fetchedUrls = [];

        if (data['ok'] == true) {
          for (var result in data['result']) {
            var message = result['message'] ?? result['channel_post'];
            if (message != null && message['photo'] != null) {
              List photos = message['photo'];
              var bestPhoto = photos.last;
              String fileId = bestPhoto['file_id'];

              final fileUrl = Uri.parse('https://api.telegram.org/bot$tgToken/getFile?file_id=$fileId');
              final fileRes = await http.get(fileUrl);
              if (fileRes.statusCode == 200) {
                var fileData = json.decode(fileRes.body);
                if (fileData['ok'] == true) {
                  String filePath = fileData['result']['file_path'];
                  String fullImageUrl = 'https://api.telegram.org/file/bot$tgToken/$filePath';
                  fetchedUrls.add(fullImageUrl);
                }
              }
            }
          }
        }

        setState(() {
          telegramImages = fetchedUrls.toSet().toList();
          isLoadingTelegramImages = false;
        });
      } else {
        setState(() => isLoadingTelegramImages = false);
      }
    } catch (e) {
      setState(() => isLoadingTelegramImages = false);
    }
  }

  void _saveProduct() async {
    if (_titleController.text.isEmpty || _priceController.text.isEmpty) return;

    String cleanPriceStr = _priceController.text.replaceAll(RegExp(r'[^0-9]'), '');
    int priceVal = int.tryParse(cleanPriceStr) ?? 0;

    Map<String, dynamic> productData = {
      'title': _titleController.text.trim(),
      'price': _priceController.text.trim(),
      'priceNum': priceVal,
      'category': selectedProductCategory,
      'image': _imageController.text.isNotEmpty ? _imageController.text.trim() : 'https://images.unsplash.com/photo-1513542789411-b6a5d4f31634?w=400',
      'description': _descController.text.trim(),
      'ratings': {},
      'createdAt': FieldValue.serverTimestamp(),
    };

    try {
      if (editingProductId == null) {
        await FirebaseFirestore.instance.collection('products').add(productData);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تمت إضافة المنتج بنجاح')));
        }
      } else {
        await FirebaseFirestore.instance.collection('products').doc(editingProductId).update(productData);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تعديل المنتج بنجاح')));
        }
        editingProductId = null;
      }
      _titleController.clear();
      _priceController.clear();
      _descController.clear();
      _imageController.clear();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ أثناء الحفظ: $e')));
      }
    }
  }

  void _deleteCategory(String cat) {
    if (cat == 'الكل') return;
    setState(() {
      globalCategories.remove(cat);
      if (selectedProductCategory == cat) {
        selectedProductCategory = 'عمارة';
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حذف القسم بنجاح')));
  }

  void _deleteSingleChat(String studentName) async {
    try {
      var batch = FirebaseFirestore.instance.batch();
      var snapshots = await FirebaseFirestore.instance.collection('chats').doc(studentName).collection('messages').get();
      for (var doc in snapshots.docs) {
        batch.delete(doc.reference);
      }
      batch.delete(FirebaseFirestore.instance.collection('chats').doc(studentName));
      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تم حذف محادثة ($studentName) بنجاح')),
        );
      }
    } catch (e) {
      debugPrint("Error deleting chat: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('لوحة الأدمن - ${widget.adminName}'),
        backgroundColor: const Color(0xFF161622),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(55),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              children: [
                TextButton.icon(
                  onPressed: () => setState(() => _selectedTab = 0),
                  icon: const Icon(Icons.add_box_rounded, color: Color(0xFFFFB703)),
                  label: Text('إدارة المنتجات', style: TextStyle(color: _selectedTab == 0 ? Colors.white : const Color(0xFFFFB703), fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 10),
                TextButton.icon(
                  onPressed: () {
                    setState(() => _selectedTab = 1);
                    _fetchTelegramGallery();
                  },
                  icon: const Icon(Icons.photo_library_rounded, color: Color(0xFFFFB703)),
                  label: Text('جاليري تيليجرام', style: TextStyle(color: _selectedTab == 1 ? Colors.white : const Color(0xFFFFB703), fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 10),
                TextButton.icon(
                  onPressed: () => setState(() => _selectedTab = 2),
                  icon: const Icon(Icons.category_rounded, color: Color(0xFFFFB703)),
                  label: Text('إدارة الأقسام', style: TextStyle(color: _selectedTab == 2 ? Colors.white : const Color(0xFFFFB703), fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 10),
                TextButton.icon(
                  onPressed: () => setState(() => _selectedTab = 3),
                  icon: const Icon(Icons.chat_rounded, color: Color(0xFFFFB703)),
                  label: Text('محادثات الطلاب', style: TextStyle(color: _selectedTab == 3 ? Colors.white : const Color(0xFFFFB703), fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          const BackgroundStickersLayer(),
          _selectedTab == 3
              ? StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance.collection('chats').snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator(color: Color(0xFFFFB703)));
                    }
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return const Center(
                        child: Text('لا توجد محادثات طلاب سحابية حالياً', style: TextStyle(color: Colors.white38)),
                      );
                    }
                    var studentDocs = snapshot.data!.docs;

                    return Row(
                      children: [
                        Container(
                          width: 290,
                          color: const Color(0xFF121218),
                          child: ListView.builder(
                            itemCount: studentDocs.length,
                            itemBuilder: (context, index) {
                              String student = studentDocs[index].id;
                              return ListTile(
                                leading: const Icon(Icons.person_rounded, color: Color(0xFFFFB703)),
                                title: Text(student, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                                trailing: IconButton(
                                  icon: const Icon(Icons.delete_rounded, color: Colors.redAccent, size: 20),
                                  onPressed: () => _deleteSingleChat(student),
                                  tooltip: 'حذف محادثة هذا الزبون',
                                ),
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => ChatScreen(userName: student, isAdmin: true),
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                        ),
                        const Expanded(
                          child: Center(
                            child: Text('اختر طالباً من القائمة لمتابعة محادثته السحابية', style: TextStyle(color: Colors.white38)),
                          ),
                        ),
                      ],
                    );
                  },
                )
              : _selectedTab == 2
                  ? Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text('إضافة قسم دراسي جديد', style: TextStyle(color: Color(0xFFFFB703), fontSize: 18, fontWeight: FontWeight.w900)),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _categoryController,
                                  decoration: InputDecoration(labelText: 'اسم القسم الجديد', border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)), filled: true, fillColor: const Color(0xFF1B1B26)),
                                ),
                              ),
                              const SizedBox(width: 12),
                              ElevatedButton(
                                onPressed: () {
                                  String cat = _categoryController.text.trim();
                                  if (cat.isNotEmpty && !globalCategories.contains(cat)) {
                                    setState(() {
                                      globalCategories.add(cat);
                                      _categoryController.clear();
                                    });
                                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تمت إضافة القسم ($cat) بنجاح')));
                                  }
                                },
                                style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16)),
                                child: const Text('إضافة'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 35),
                          const Text('الأقسام الحالية (إدارة الحذف)', style: TextStyle(color: Color(0xFFFFB703), fontSize: 16, fontWeight: FontWeight.w900)),
                          const SizedBox(height: 12),
                          Expanded(
                            child: ListView.builder(
                              itemCount: globalCategories.length,
                              itemBuilder: (context, index) {
                                String cat = globalCategories[index];
                                if (cat == 'الكل') return const SizedBox.shrink();
                                return Container(
                                  margin: const EdgeInsets.symmetric(vertical: 6),
                                  decoration: BoxDecoration(color: const Color(0xFF1B1B26), borderRadius: BorderRadius.circular(16)),
                                  child: ListTile(
                                    title: Text(cat, style: const TextStyle(fontWeight: FontWeight.bold)),
                                    trailing: IconButton(
                                      icon: const Icon(Icons.delete_rounded, color: Colors.redAccent),
                                      onPressed: () => _deleteCategory(cat),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    )
                  : _selectedTab == 1
                      ? Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'صور مجموعة تيليجرام (انقر لاختيارها كمنتج)',
                                    style: TextStyle(color: Color(0xFFFFB703), fontSize: 15, fontWeight: FontWeight.w900),
                                  ),
                                  ElevatedButton.icon(
                                    onPressed: _fetchTelegramGallery,
                                    icon: const Icon(Icons.refresh_rounded),
                                    label: const Text('تحديث'),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Expanded(
                                child: isLoadingTelegramImages
                                    ? const Center(child: CircularProgressIndicator(color: Color(0xFFFFB703)))
                                    : telegramImages.isEmpty
                                        ? const Center(
                                            child: Text(
                                              'لا توجد صور حديثة في مجموعة تيليجرام.',
                                              textAlign: TextAlign.center,
                                              style: TextStyle(color: Colors.white38),
                                            ),
                                          )
                                        : GridView.builder(
                                            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                                              maxCrossAxisExtent: 180,
                                              childAspectRatio: 1.0,
                                              crossAxisSpacing: 12,
                                              mainAxisSpacing: 12,
                                            ),
                                            itemCount: telegramImages.length,
                                            itemBuilder: (context, index) {
                                              String imgUrl = telegramImages[index];
                                              return GestureDetector(
                                                onTap: () {
                                                  setState(() {
                                                    _imageController.text = imgUrl;
                                                    _selectedTab = 0;
                                                  });
                                                  ScaffoldMessenger.of(context).showSnackBar(
                                                    const SnackBar(content: Text('تم اختيار الصورة بنجاح!')),
                                                  );
                                                },
                                                child: Container(
                                                  decoration: BoxDecoration(
                                                    borderRadius: BorderRadius.circular(16),
                                                    border: Border.all(color: const Color(0xFFFFB703), width: 2),
                                                  ),
                                                  child: ClipRRect(
                                                    borderRadius: BorderRadius.circular(14),
                                                    child: CachedNetworkImage(
                                                      imageUrl: imgUrl,
                                                      fit: BoxFit.cover,
                                                      placeholder: (context, url) => const Center(
                                                        child: CircularProgressIndicator(color: Color(0xFFFFB703)),
                                                      ),
                                                      errorWidget: (context, url, error) => const Icon(Icons.error),
                                                    ),
                                                  ),
                                                ),
                                              );
                                            },
                                          ),
                              ),
                            ],
                          ),
                        )
                      : SingleChildScrollView(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                editingProductId == null ? 'إضافة منتج جديد' : 'تعديل بيانات المنتج',
                                style: const TextStyle(color: Color(0xFFFFB703), fontSize: 20, fontWeight: FontWeight.w900),
                              ),
                              const SizedBox(height: 22),
                              TextField(
                                controller: _titleController,
                                decoration: InputDecoration(labelText: 'اسم المنتج', border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)), filled: true, fillColor: const Color(0xFF1B1B26)),
                              ),
                              const SizedBox(height: 16),
                              TextField(
                                controller: _priceController,
                                decoration: InputDecoration(labelText: 'السعر (ل.س)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)), filled: true, fillColor: const Color(0xFF1B1B26)),
                              ),
                              const SizedBox(height: 16),
                              DropdownButtonFormField<String>(
                                value: globalCategories.where((c) => c != 'الكل').contains(selectedProductCategory)
                                    ? selectedProductCategory
                                    : (globalCategories.where((c) => c != 'الكل').isNotEmpty
                                        ? globalCategories.where((c) => c != 'الكل').first
                                        : null),
                                decoration: InputDecoration(labelText: 'القسم', border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)), filled: true, fillColor: const Color(0xFF1B1B26)),
                                items: globalCategories
                                    .where((c) => c != 'الكل')
                                    .map((cat) => DropdownMenuItem(value: cat, child: Text(cat)))
                                    .toList(),
                                onChanged: (val) {
                                  setState(() {
                                    selectedProductCategory = val!;
                                  });
                                },
                              ),
                              const SizedBox(height: 16),
                              TextField(
                                controller: _imageController,
                                decoration: InputDecoration(
                                  labelText: 'رابط صورة تيليجرام أو المنتج',
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                                  filled: true,
                                  fillColor: const Color(0xFF1B1B26),
                                ),
                              ),
                              const SizedBox(height: 12),
                              OutlinedButton.icon(
                                onPressed: () {
                                  setState(() => _selectedTab = 1);
                                  _fetchTelegramGallery();
                                },
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  side: const BorderSide(color: Color(0xFFFFB703)),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                ),
                                icon: const Icon(Icons.photo_library_rounded, color: Color(0xFFFFB703)),
                                label: const Text('اختيار من جاليري تيليجرام', style: TextStyle(color: Color(0xFFFFB703), fontSize: 15, fontWeight: FontWeight.bold)),
                              ),
                              const SizedBox(height: 16),
                              TextField(
                                controller: _descController,
                                maxLines: 4,
                                decoration: InputDecoration(labelText: 'تفاصيل المنتج ومواصفاته', border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)), filled: true, fillColor: const Color(0xFF1B1B26)),
                              ),
                              const SizedBox(height: 28),
                              ElevatedButton(
                                onPressed: _saveProduct,
                                style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 18), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18))),
                                child: Text(editingProductId == null ? 'نشر المنتج للسحابة' : 'حفظ التعديلات', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
                              ),
                            ],
                          ),
                        ),
        ],
      ),
    );
  }
}

// ----------------- شاشة المحادثة الخاصة والسحابية -----------------
class ChatScreen extends StatefulWidget {
  final String userName;
  final bool isAdmin;
  const ChatScreen({super.key, required this.userName, required this.isAdmin});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _msgController = TextEditingController();

  void _sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    try {
      final chatRef = FirebaseFirestore.instance.collection('chats').doc(widget.userName);
      await chatRef.set({
        'lastActive': FieldValue.serverTimestamp(),
        'studentName': widget.userName,
      }, SetOptions(merge: true));

      await chatRef.collection('messages').add({
        'senderName': widget.isAdmin ? 'الإدارة (حيان)' : widget.userName,
        'text': text.trim(),
        'isAdmin': widget.isAdmin,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint("Error sending message: $e");
    }

    _msgController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isAdmin ? 'محادثة الزبون: ${widget.userName}' : 'محادثتي الخاصة مع الإدارة'),
        backgroundColor: const Color(0xFF161622),
      ),
      body: Stack(
        children: [
          const BackgroundStickersLayer(),
          Column(
            children: [
              if (widget.isAdmin)
                Container(
                  padding: const EdgeInsets.all(10),
                  color: const Color(0xFF161622),
                  child: Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade800, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                          icon: const Icon(Icons.cancel_rounded, size: 18),
                          label: const Text('تم رفض الطلب'),
                          onPressed: () {
                            _sendMessage('عذراً، تم رفض الطلب لعدم توفر المنتج حالياً.');
                            addAppNotification(
                              targetUserName: widget.userName,
                              title: 'تحديث حالة الطلب ❌',
                              message: 'عذراً، تعذر قبول طلبك الأخير.',
                              icon: Icons.cancel_outlined,
                              iconColor: Colors.redAccent,
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                          icon: const Icon(Icons.check_circle_rounded, size: 18),
                          label: const Text('تأكيد الطلب (دليفري)'),
                          onPressed: () {
                            _sendMessage('تم تأكيد طلبك بنجاح ✅ وسيتم التواصل معك قريباً.');
                            addAppNotification(
                              targetUserName: widget.userName,
                              title: 'تم تأكيد طلبك بنجاح ✅',
                              message: 'سيقوم مندوب التوصيل بالتواصل معك قريباً للتسليم.',
                              icon: Icons.local_shipping_outlined,
                              iconColor: Colors.greenAccent,
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('chats')
                      .doc(widget.userName)
                      .collection('messages')
                      .orderBy('timestamp', descending: false)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator(color: Color(0xFFFFB703)));
                    }

                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return const Center(
                        child: Text('لا توجد رسائل سحابية في هذه المحادثة بعد', style: TextStyle(color: Colors.white38)),
                      );
                    }

                    var messages = snapshot.data!.docs;

                    return ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        var msgData = messages[index].data() as Map<String, dynamic>;
                        bool isMsgAdmin = msgData['isAdmin'] ?? false;
                        bool isMe = widget.isAdmin ? isMsgAdmin : !isMsgAdmin;

                        return Align(
                          alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                          child: Container(
                            margin: const EdgeInsets.symmetric(vertical: 6),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: isMe ? const Color(0xFFFFB703) : const Color(0xFF262636),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              msgData['text'] ?? '',
                              style: TextStyle(color: isMe ? Colors.black : Colors.white, fontWeight: isMe ? FontWeight.bold : FontWeight.normal),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
              Container(
                padding: const EdgeInsets.all(12),
                color: const Color(0xFF121218),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _msgController,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'اكتب رسالتك السحابية هنا...',
                          hintStyle: const TextStyle(color: Colors.white38),
                          filled: true,
                          fillColor: const Color(0xFF1B1B26),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    IconButton(
                      icon: const Icon(Icons.send_rounded, color: Color(0xFFFFB703), size: 26),
                      onPressed: () => _sendMessage(_msgController.text),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}