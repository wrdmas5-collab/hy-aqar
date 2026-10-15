import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:ui';

import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    if (Firebase.apps.isEmpty) {
      if (kIsWeb) {
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
      } else {
        await Firebase.initializeApp();
      }
    }
  } catch (e) {
    debugPrint("Firebase initialization error: $e");
  }

  final prefs = await SharedPreferences.getInstance();
  bool isLoggedIn = prefs.getBool('is_logged_in') ?? false;
  String savedName = prefs.getString('user_name') ?? '';
  String savedPhone = prefs.getString('user_phone') ?? '';
  bool savedIsAdmin = prefs.getBool('is_admin') ?? false;

  runApp(HyAcademyApp(
    isLoggedIn: isLoggedIn,
    initialName: savedName,
    initialPhone: savedPhone,
    initialIsAdmin: savedIsAdmin,
  ));
}

class HyAcademyApp extends StatelessWidget {
  final bool isLoggedIn;
  final String initialName;
  final String initialPhone;
  final bool initialIsAdmin;

  const HyAcademyApp({
    super.key,
    required this.isLoggedIn,
    required this.initialName,
    required this.initialPhone,
    required this.initialIsAdmin,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HY-Academy Store',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF09090D),
        primaryColor: const Color(0xFFE5C158),
        fontFamily: 'Roboto',
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFE5C158),
          secondary: Color(0xFFC5A059),
          surface: Color(0xFF13131A),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF0D0D12),
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(
            color: Color(0xFFE5C158),
            fontSize: 20,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFE5C158),
            foregroundColor: Colors.black,
            textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            elevation: 6,
            shadowColor: const Color(0x66E5C158),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
      ),
      home: isLoggedIn
          ? HomeScreen(userName: initialName, userPhone: initialPhone, isAdmin: initialIsAdmin)
          : const LoginScreen(),
    );
  }
}

// ----------------- شاشة تسجيل الدخول -----------------
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.6),
            radius: 1.2,
            colors: [Color(0xFF231C08), Color(0xFF09090B)],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 40.0),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 440),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                  child: Container(
                    padding: const EdgeInsets.all(32.0),
                    decoration: BoxDecoration(
                      color: const Color(0xFF141418).withOpacity(0.85),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: const Color(0xFFE5C158).withOpacity(0.3), width: 1.5),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black54,
                          blurRadius: 30,
                          offset: Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFFE5C158).withOpacity(0.1),
                            border: Border.all(color: const Color(0xFFE5C158), width: 2),
                          ),
                          child: const Icon(Icons.school, size: 55, color: Color(0xFFE5C158)),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'HY-ACADEMY STORE',
                          style: TextStyle(
                            color: Color(0xFFE5C158),
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'متجر المستلزمات الطلابية الهندسية والطبية',
                          style: TextStyle(color: Colors.white70, fontSize: 13),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 35),
                        _buildInputField(
                          controller: _nameController,
                          label: 'الاسم الثلاثي',
                          icon: Icons.person_outline,
                        ),
                        const SizedBox(height: 16),
                        _buildInputField(
                          controller: _phoneController,
                          label: 'رقم الهاتف',
                          icon: Icons.phone_android_outlined,
                          keyboardType: TextInputType.phone,
                        ),
                        const SizedBox(height: 16),
                        _buildInputField(
                          controller: _passwordController,
                          label: 'كلمة السر',
                          icon: Icons.lock_outline,
                          obscureText: true,
                          helperText: 'أنشئ كلمة سر من 8 أحرف أو أرقام',
                        ),
                        const SizedBox(height: 30),
                        Container(
                          height: 52,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            gradient: const LinearGradient(
                              colors: [Color(0xFFF3D26B), Color(0xFFC5A059)],
                            ),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x40E5C158),
                                blurRadius: 15,
                                offset: Offset(0, 5),
                              ),
                            ],
                          ),
                          child: ElevatedButton(
                            onPressed: _login,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                            child: const Text(
                              'دخول إلى المتجر',
                              style: TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.bold),
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
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscureText = false,
    String? helperText,
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white60),
        helperText: helperText,
        helperStyle: const TextStyle(color: Colors.white38, fontSize: 11),
        prefixIcon: Icon(icon, color: const Color(0xFFE5C158)),
        filled: true,
        fillColor: const Color(0xFF1C1C22),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF2C2C35)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE5C158), width: 1.5),
        ),
      ),
    );
  }
}

// نماذج البيانات
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

class ChatMessage {
  final String id;
  String senderName;
  String text;
  bool isAdmin;

  ChatMessage({
    required this.id,
    required this.senderName,
    required this.text,
    required this.isAdmin,
  });
}

Map<String, List<ChatMessage>> globalChats = {};
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
        "https://wa.me/+963967834966?text=${Uri.encodeComponent('مرحباً إدارة HY-Academy Store، لدي استفسار أو شكوى بخصوص:')}");
    if (await canLaunchUrl(whatsappUri)) {
      await launchUrl(whatsappUri, mode: LaunchMode.externalApplication);
    }
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
        content: Text('تمت إضافة (${product['title']}) إلى سلة المشتريات للشراء لاحقاً 🛒'),
        duration: const Duration(seconds: 2),
        action: SnackBarAction(
          label: 'عرض السلة',
          textColor: const Color(0xFFE5C158),
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
                color: Color(0xFF121218),
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                boxShadow: [
                  BoxShadow(color: Colors.black87, blurRadius: 25, offset: Offset(0, -5)),
                ],
              ),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: const [
                          Icon(Icons.shopping_cart, color: Color(0xFFE5C158), size: 26),
                          SizedBox(width: 10),
                          Text(
                            'سلة المشتريات (للشراء لاحقاً)',
                            style: TextStyle(color: Color(0xFFE5C158), fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white70),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const Divider(color: Colors.white12, height: 25),
                  Expanded(
                    child: cart.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: const [
                                Icon(Icons.remove_shopping_cart_outlined, size: 60, color: Colors.white24),
                                SizedBox(height: 12),
                                Text('السلة فارغة حالياً', style: TextStyle(color: Colors.white38, fontSize: 14)),
                              ],
                            ),
                          )
                        : ListView.builder(
                            itemCount: cart.length,
                            itemBuilder: (context, index) {
                              final item = cart[index];
                              return Container(
                                margin: const EdgeInsets.symmetric(vertical: 6),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1A1A22),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: const Color(0xFF2A2A36)),
                                ),
                                child: Row(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(10),
                                      child: CachedNetworkImage(
                                        imageUrl: item.product['image'] ?? '',
                                        width: 50,
                                        height: 50,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            item.product['title'] ?? '',
                                            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            item.product['price'] ?? '',
                                            style: const TextStyle(color: Color(0xFFE5C158), fontSize: 12, fontWeight: FontWeight.bold),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Row(
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.remove_circle_outline, color: Colors.white70, size: 20),
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
                                        Text('${item.quantity}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                        IconButton(
                                          icon: const Icon(Icons.add_circle_outline, color: Color(0xFFE5C158), size: 20),
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
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('المجموع التقديري:', style: TextStyle(fontSize: 15, color: Colors.white70)),
                          Text(
                            '$totalSum ل.س',
                            style: const TextStyle(fontSize: 18, color: Color(0xFFE5C158), fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.check_circle),
                        label: const Text('طلب جميع منتجات السلة الآن'),
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

  void _checkoutCart(List<CartItem> cart, int totalSum) {
    final deliveryPhoneController = TextEditingController(text: widget.userPhone);
    final universityController = TextEditingController();
    String paymentMethod = 'نقدي عند الاستلام';

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF141418),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Text('طلب سلة المشتريات 🛒', style: TextStyle(color: Color(0xFFE5C158), fontWeight: FontWeight.bold)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('عدد المنتجات: ${cart.length}', style: const TextStyle(color: Colors.white70)),
                    const SizedBox(height: 15),
                    const Text('طريقة الدفع:', style: TextStyle(fontWeight: FontWeight.bold)),
                    DropdownButton<String>(
                      value: paymentMethod,
                      isExpanded: true,
                      dropdownColor: const Color(0xFF1E1E24),
                      items: ['نقدي عند الاستلام', 'شام كاش (الدفع الفوري)']
                          .map((method) => DropdownMenuItem(value: method, child: Text(method)))
                          .toList(),
                      onChanged: (val) => setDialogState(() => paymentMethod = val!),
                    ),
                    const SizedBox(height: 15),
                    const Text('رقم التواصل للتسليم *', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFE5C158))),
                    const SizedBox(height: 8),
                    TextField(
                      controller: deliveryPhoneController,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        hintText: '+963...',
                      ),
                      onChanged: (_) => setDialogState(() {}),
                    ),
                    const SizedBox(height: 15),
                    const Text('الجامعة المراد الاستلام منها *', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFE5C158))),
                    const SizedBox(height: 8),
                    TextField(
                      controller: universityController,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        hintText: 'اسم الجامعة...',
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
                      : () {
                          Navigator.pop(context);

                          String itemsSummary = cart
                              .map((item) => "• ${item.product['title']} (العدد: ${item.quantity})")
                              .join("\n");

                          String orderMsg = "📦 طلب منتجات من سلة المشتريات:\n"
                              "👤 الزبون: ${widget.userName}\n"
                              "📱 رقم الهاتف: ${widget.userPhone}\n"
                              "📋 العناصر:\n$itemsSummary\n"
                              "💰 المجموع الكلي: $totalSum ل.س\n"
                              "- طريقة الدفع: $paymentMethod\n"
                              "- رقم التواصل للتسليم: ${deliveryPhoneController.text.trim()}\n"
                              "- الجامعة: ${universityController.text.trim()}";

                          globalChats.putIfAbsent(widget.userName, () => []);
                          globalChats[widget.userName]!.add(
                            ChatMessage(
                              id: DateTime.now().millisecondsSinceEpoch.toString(),
                              senderName: widget.userName,
                              text: orderMsg,
                              isAdmin: false,
                            ),
                          );

                          globalChats[widget.userName]!.add(
                            ChatMessage(
                              id: (DateTime.now().millisecondsSinceEpoch + 1).toString(),
                              senderName: 'الإدارة',
                              text: 'مرحباً بك، تم تلقي طلب السلة بنجاح. يرجى الانتظار لحين تأكيده.',
                              isAdmin: true,
                            ),
                          );

                          addAppNotification(
                            targetUserName: widget.userName,
                            title: 'تم إرسال طلب السلة بنجاح 🛒',
                            message: 'تم إرسال طلب السلة المتضمن (${cart.length}) منتجات إلى الإدارة بنجاح.',
                            icon: Icons.shopping_cart_outlined,
                            iconColor: const Color(0xFFE5C158),
                          );

                          setState(() {
                            userCarts[widget.userName]?.clear();
                          });

                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ChatScreen(userName: widget.userName, isAdmin: false),
                            ),
                          ).then((_) => setState(() {}));
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
                color: Color(0xFF121218),
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                boxShadow: [
                  BoxShadow(color: Colors.black87, blurRadius: 25, offset: Offset(0, -5)),
                ],
              ),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: const [
                          Icon(Icons.notifications_active, color: Color(0xFFE5C158), size: 26),
                          SizedBox(width: 10),
                          Text(
                            'الإشعارات والتحديثات',
                            style: TextStyle(color: Color(0xFFE5C158), fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white70),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const Divider(color: Colors.white12, height: 25),
                  Expanded(
                    child: notifs.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: const [
                                Icon(Icons.notifications_off_outlined, size: 60, color: Colors.white24),
                                SizedBox(height: 12),
                                Text('لا توجد إشعارات جديدة حالياً', style: TextStyle(color: Colors.white38, fontSize: 14)),
                              ],
                            ),
                          )
                        : ListView.builder(
                            itemCount: notifs.length,
                            itemBuilder: (context, index) {
                              final item = notifs[index];
                              return Container(
                                margin: const EdgeInsets.symmetric(vertical: 6),
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1A1A22),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: const Color(0xFF2A2A36)),
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
                                      child: Icon(item.icon, color: item.iconColor, size: 22),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(
                                                item.title,
                                                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 14),
                                              ),
                                              Text(
                                                item.time,
                                                style: const TextStyle(color: Colors.white38, fontSize: 11),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            item.message,
                                            style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.3),
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
    final deliveryPhoneController = TextEditingController(text: widget.userPhone);
    final universityController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF141418),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Text('طلب: ${product['title']}', style: const TextStyle(color: Color(0xFFE5C158), fontWeight: FontWeight.bold)),
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
                          icon: const Icon(Icons.remove_circle, color: Color(0xFFE5C158)),
                          onPressed: () {
                            if (quantity > 1) {
                              setDialogState(() => quantity--);
                            }
                          },
                        ),
                        Text('$quantity', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        IconButton(
                          icon: const Icon(Icons.add_circle, color: Color(0xFFE5C158)),
                          onPressed: () {
                            setDialogState(() => quantity++);
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 15),
                    const Text('طريقة الدفع:', style: TextStyle(fontWeight: FontWeight.bold)),
                    DropdownButton<String>(
                      value: paymentMethod,
                      isExpanded: true,
                      dropdownColor: const Color(0xFF1E1E24),
                      items: ['نقدي عند الاستلام', 'شام كاش (الدفع الفوري)']
                          .map((method) => DropdownMenuItem(value: method, child: Text(method)))
                          .toList(),
                      onChanged: (val) {
                        setDialogState(() => paymentMethod = val!);
                      },
                    ),
                    const SizedBox(height: 15),
                    const Text('رقم التواصل (حتى نتواصل معك من أجل التسليم) *', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFE5C158))),
                    const SizedBox(height: 8),
                    TextField(
                      controller: deliveryPhoneController,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        hintText: '+963...',
                      ),
                      onChanged: (_) => setDialogState(() {}),
                    ),
                    const SizedBox(height: 15),
                    const Text('اسم الجامعة التي تريد استلام المنتج منها *', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFE5C158))),
                    const SizedBox(height: 8),
                    TextField(
                      controller: universityController,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        hintText: 'اكتب اسم الجامعة هنا...',
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
                      : () {
                          Navigator.pop(context);

                          String orderMsg = "📦 طلب منتج جديد:\n"
                              "👤 الزبون: ${widget.userName}\n"
                              "📱 رقم الهاتف المسجل: ${widget.userPhone}\n"
                              "- المنتج: ${product['title']}\n"
                              "- السعر الفردي: ${product['price']}\n"
                              "- عدد القطع: $quantity\n"
                              "- طريقة الدفع: $paymentMethod\n"
                              "- رقم التواصل للتسليم: ${deliveryPhoneController.text.trim()}\n"
                              "- الجامعة المراد استلام المنتج منها: ${universityController.text.trim()}";

                          globalChats.putIfAbsent(widget.userName, () => []);
                          globalChats[widget.userName]!.add(
                            ChatMessage(
                              id: DateTime.now().millisecondsSinceEpoch.toString(),
                              senderName: widget.userName,
                              text: orderMsg,
                              isAdmin: false,
                            ),
                          );

                          globalChats[widget.userName]!.add(
                            ChatMessage(
                              id: (DateTime.now().millisecondsSinceEpoch + 1).toString(),
                              senderName: 'الإدارة',
                              text: 'مرحباً بك، تم تلقي طلبك بنجاح. يرجى الانتظار حتى تأكيد الطلب من قبل الإدارة.',
                              isAdmin: true,
                            ),
                          );

                          addAppNotification(
                            targetUserName: widget.userName,
                            title: 'تم إرسال طلبك بنجاح 📦',
                            message: 'تم إرسال طلبك (${product['title']}) إلى الإدارة بنجاح وجاري المراجعة.',
                            icon: Icons.shopping_bag_outlined,
                            iconColor: const Color(0xFFE5C158),
                          );

                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ChatScreen(userName: widget.userName, isAdmin: false),
                            ),
                          ).then((_) => setState(() {}));
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
    List<NotificationItem> notifs = userNotifications[widget.userName] ?? [];
    int unreadCount = notifs.where((n) => !n.isRead).length;
    List<CartItem> cart = userCarts[widget.userName] ?? [];
    int cartCount = cart.fold(0, (sum, item) => sum + item.quantity);

    return Scaffold(
      appBar: AppBar(
        title: const Text('HY-ACADEMY STORE'),
        actions: [
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.shopping_cart_outlined, color: Color(0xFFE5C158), size: 26),
                onPressed: _openCartSheet,
                tooltip: 'سلة المشتريات (للشراء لاحقاً)',
              ),
              if (cartCount > 0)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Color(0xFFE5C158),
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                    child: Text(
                      '$cartCount',
                      style: const TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.bold),
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
                icon: const Icon(Icons.notifications_none_rounded, color: Color(0xFFE5C158), size: 26),
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
                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
          if (widget.isAdmin)
            TextButton.icon(
              style: TextButton.styleFrom(foregroundColor: const Color(0xFFE5C158)),
              icon: const Icon(Icons.admin_panel_settings, color: Color(0xFFE5C158)),
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
            icon: const Icon(Icons.chat_bubble_outline, color: Color(0xFFE5C158)),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ChatScreen(userName: widget.userName, isAdmin: false),
                ),
              ).then((_) => setState(() {}));
            },
            tooltip: 'محادثة الإدارة',
          ),
          IconButton(
            icon: const Icon(Icons.support_agent, color: Color(0xFFE5C158)),
            onPressed: _openSupportWhatsApp,
            tooltip: 'الدعم الفني',
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.redAccent),
            onPressed: () => _logout(context),
            tooltip: 'تسجيل خروج',
          ),
        ],
      ),
      drawer: Drawer(
        backgroundColor: const Color(0xFF0F0F12),
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            UserAccountsDrawerHeader(
              decoration: const BoxDecoration(
                gradient: LinearGradient(colors: [Color(0xFF231C08), Color(0xFF141418)]),
              ),
              currentAccountPicture: const CircleAvatar(
                backgroundColor: Color(0xFFE5C158),
                child: Icon(Icons.person, size: 40, color: Colors.black),
              ),
              accountName: Text(
                widget.userName,
                style: const TextStyle(color: Color(0xFFE5C158), fontWeight: FontWeight.bold, fontSize: 16),
              ),
              accountEmail: Text(
                widget.userPhone,
                style: const TextStyle(color: Colors.white70),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.store, color: Color(0xFFE5C158)),
              title: const Text('المتجر الرئيسي'),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: const Icon(Icons.shopping_cart, color: Color(0xFFE5C158)),
              title: Text('سلة المشتريات للشراء لاحقاً ($cartCount)'),
              onTap: () {
                Navigator.pop(context);
                _openCartSheet();
              },
            ),
            ListTile(
              leading: const Icon(Icons.favorite, color: Colors.redAccent),
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
              leading: const Icon(Icons.notifications_none, color: Color(0xFFE5C158)),
              title: const Text('الإشعارات والتحديثات'),
              onTap: () {
                Navigator.pop(context);
                _openNotificationsSheet();
              },
            ),
            ListTile(
              leading: const Icon(Icons.chat_bubble_outline, color: Color(0xFFE5C158)),
              title: const Text('محادثتي مع الإدارة'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ChatScreen(userName: widget.userName, isAdmin: false),
                  ),
                ).then((_) => setState(() {}));
              },
            ),
            const Divider(color: Colors.white12),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.redAccent),
              title: const Text('تسجيل خروج', style: TextStyle(color: Colors.redAccent)),
              onTap: () => _logout(context),
            ),
          ],
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            child: Container(
              height: 110,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF33290D), Color(0xFF121218)],
                ),
                border: Border.all(color: const Color(0xFFE5C158).withOpacity(0.4), width: 1.2),
                boxShadow: const [
                  BoxShadow(color: Color(0x33E5C158), blurRadius: 15, offset: Offset(0, 4)),
                ],
              ),
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFFE5C158).withOpacity(0.15),
                    ),
                    child: const Icon(Icons.workspace_premium, size: 36, color: Color(0xFFE5C158)),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Text(
                          'أهلاً بك في منصة HY-ACADEMY',
                          style: TextStyle(color: Color(0xFFE5C158), fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'تصفح المستلزمات الطبية والهندسية واطلبها أو ضعها في سلة المشتريات للشراء لاحقاً',
                          style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.2),
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
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: selectedCategory == 'الكل'
                    ? 'ابحث عن أي منتج في المتجر...'
                    : 'ابحث في قسم $selectedCategory...',
                hintStyle: const TextStyle(color: Colors.white38),
                prefixIcon: const Icon(Icons.search, color: Color(0xFFE5C158)),
                suffixIcon: searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: Colors.grey),
                        onPressed: () {
                          setState(() {
                            _searchController.clear();
                            searchQuery = '';
                          });
                        },
                      )
                    : null,
                filled: true,
                fillColor: const Color(0xFF14141A),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: Color(0xFF22222E)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: Color(0xFFE5C158), width: 1.5),
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
            height: 58,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              itemCount: globalCategories.length,
              itemBuilder: (context, index) {
                String cat = globalCategories[index];
                bool isSelected = selectedCategory == cat;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 8),
                  child: ChoiceChip(
                    label: Text(cat),
                    selected: isSelected,
                    selectedColor: const Color(0xFFE5C158),
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.black : Colors.white70,
                      fontWeight: FontWeight.bold,
                    ),
                    backgroundColor: const Color(0xFF14141A),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
          const Divider(height: 1, color: Color(0xFF1A1A22)),
          
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('products').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Color(0xFFE5C158)));
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Text(
                      'لا توجد منتجات مضافة بعد. استخدم لوحة الأدمن لإضافة أول منتج!',
                      style: TextStyle(color: Colors.white38, fontSize: 14),
                      textAlign: TextAlign.center,
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
                      'لا توجد منتجات تطابق البحث',
                      style: TextStyle(color: Colors.white38, fontSize: 15),
                    ),
                  );
                }

                return GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 280,
                    childAspectRatio: 0.58,
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
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF14141A),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFF22222E)),
                          boxShadow: const [
                            BoxShadow(color: Colors.black45, blurRadius: 12, offset: Offset(0, 5)),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Stack(
                                children: [
                                  ClipRRect(
                                    borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                                    child: CachedNetworkImage(
                                      imageUrl: product['image'] ?? '',
                                      fit: BoxFit.cover,
                                      width: double.infinity,
                                      placeholder: (context, url) => const Center(
                                        child: CircularProgressIndicator(color: Color(0xFFE5C158)),
                                      ),
                                      errorWidget: (context, url, error) => const Icon(Icons.error),
                                    ),
                                  ),
                                  Positioned(
                                    top: 8,
                                    right: 8,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withOpacity(0.65),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(color: const Color(0xFFE5C158).withOpacity(0.5)),
                                      ),
                                      child: Text(
                                        product['category'] ?? '',
                                        style: const TextStyle(color: Color(0xFFE5C158), fontSize: 10, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    top: 8,
                                    left: 8,
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
                                        radius: 16,
                                        backgroundColor: Colors.black.withOpacity(0.65),
                                        child: Icon(
                                          isFav ? Icons.favorite : Icons.favorite_border,
                                          color: isFav ? Colors.redAccent : Colors.white,
                                          size: 18,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(10.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    product['title'] ?? '',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    product['price'] ?? '',
                                    style: const TextStyle(color: Color(0xFFE5C158), fontWeight: FontWeight.bold, fontSize: 14),
                                  ),
                                  const SizedBox(height: 8),
                                  SizedBox(
                                    width: double.infinity,
                                    height: 32,
                                    child: ElevatedButton(
                                      onPressed: () => _showOrderDialog(product),
                                      child: const Text('طلب سريع', style: TextStyle(fontSize: 11)),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  SizedBox(
                                    width: double.infinity,
                                    height: 32,
                                    child: OutlinedButton.icon(
                                      onPressed: () => _addToCart(product),
                                      style: OutlinedButton.styleFrom(
                                        side: const BorderSide(color: Color(0xFFE5C158)),
                                        padding: EdgeInsets.zero,
                                      ),
                                      icon: const Icon(Icons.bookmark_add_outlined, size: 14, color: Color(0xFFE5C158)),
                                      label: const Text('الوضع في سلة المشتريات للشراء لاحقا', style: TextStyle(fontSize: 9, color: Color(0xFFE5C158))),
                                    ),
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
            ),
          ),
        ],
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
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('products').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFFE5C158)));
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
                  Icon(Icons.favorite_border, size: 70, color: Colors.white24),
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
              return Card(
                color: const Color(0xFF14141A),
                margin: const EdgeInsets.symmetric(vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(10),
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: CachedNetworkImage(imageUrl: product['image'] ?? '', width: 60, height: 60, fit: BoxFit.cover),
                  ),
                  title: Text(product['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                  subtitle: Text('${product['category']} | ${product['price']}', style: const TextStyle(color: Color(0xFFE5C158))),
                  trailing: IconButton(
                    icon: const Icon(Icons.favorite, color: Colors.redAccent),
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
                placeholder: (context, url) => const Center(child: CircularProgressIndicator(color: Color(0xFFE5C158))),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 30),
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
    final deliveryPhoneController = TextEditingController(text: widget.userPhone);
    final universityController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF141418),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Text('طلب: ${widget.product['title']}', style: const TextStyle(color: Color(0xFFE5C158), fontWeight: FontWeight.bold)),
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
                          icon: const Icon(Icons.remove_circle, color: Color(0xFFE5C158)),
                          onPressed: () {
                            if (quantity > 1) setDialogState(() => quantity--);
                          },
                        ),
                        Text('$quantity', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        IconButton(
                          icon: const Icon(Icons.add_circle, color: Color(0xFFE5C158)),
                          onPressed: () => setDialogState(() => quantity++),
                        ),
                      ],
                    ),
                    const SizedBox(height: 15),
                    const Text('طريقة الدفع:', style: TextStyle(fontWeight: FontWeight.bold)),
                    DropdownButton<String>(
                      value: paymentMethod,
                      isExpanded: true,
                      dropdownColor: const Color(0xFF1E1E24),
                      items: ['نقدي عند الاستلام', 'شام كاش (الدفع الفوري)']
                          .map((method) => DropdownMenuItem(value: method, child: Text(method)))
                          .toList(),
                      onChanged: (val) => setDialogState(() => paymentMethod = val!),
                    ),
                    const SizedBox(height: 15),
                    const Text('رقم التواصل للتسليم *', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFE5C158))),
                    const SizedBox(height: 8),
                    TextField(
                      controller: deliveryPhoneController,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        hintText: '+963...',
                      ),
                      onChanged: (_) => setDialogState(() {}),
                    ),
                    const SizedBox(height: 15),
                    const Text('اسم الجامعة للاستلام *', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFE5C158))),
                    const SizedBox(height: 8),
                    TextField(
                      controller: universityController,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        hintText: 'اسم الجامعة...',
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
                      : () {
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

                          globalChats.putIfAbsent(widget.userName, () => []);
                          globalChats[widget.userName]!.add(
                            ChatMessage(
                              id: DateTime.now().millisecondsSinceEpoch.toString(),
                              senderName: widget.userName,
                              text: orderMsg,
                              isAdmin: false,
                            ),
                          );

                          globalChats[widget.userName]!.add(
                            ChatMessage(
                              id: (DateTime.now().millisecondsSinceEpoch + 1).toString(),
                              senderName: 'الإدارة',
                              text: 'مرحباً بك، تم تلقي طلبك بنجاح وجاري المراجعة.',
                              isAdmin: true,
                            ),
                          );

                          addAppNotification(
                            targetUserName: widget.userName,
                            title: 'تم إرسال طلبك بنجاح 📦',
                            message: 'تم إرسال طلبك (${widget.product['title']}) إلى الإدارة بنجاح.',
                            icon: Icons.shopping_bag_outlined,
                            iconColor: const Color(0xFFE5C158),
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            GestureDetector(
              onTap: () => _openImageFullScreen(widget.product['image'] ?? ''),
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: CachedNetworkImage(
                      imageUrl: widget.product['image'] ?? '',
                      height: 300,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      placeholder: (context, url) => const Center(child: CircularProgressIndicator(color: Color(0xFFE5C158))),
                      errorWidget: (context, url, error) => const Icon(Icons.error),
                    ),
                  ),
                  Positioned(
                    bottom: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE5C158)),
                      ),
                      child: Row(
                        children: const [
                          Icon(Icons.zoom_in, color: Color(0xFFE5C158), size: 18),
                          SizedBox(width: 4),
                          Text('معاينة مكبرة', style: TextStyle(color: Colors.white, fontSize: 12)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text(
              widget.product['title'] ?? '',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 8),
            Text(
              widget.product['price'] ?? '',
              style: const TextStyle(fontSize: 22, color: Color(0xFFE5C158), fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: Chip(
                label: Text('القسم: ${widget.product['category']}'),
                backgroundColor: const Color(0xFF1C1C22),
                labelStyle: const TextStyle(color: Color(0xFFE5C158), fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 20),
            const Text('تفاصيل ومواصفات المنتج:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFFE5C158))),
            const SizedBox(height: 8),
            Text(
              widget.product['description'] ?? 'لا توجد تفاصيل إضافية.',
              style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.5),
            ),
            const Divider(height: 40, color: Colors.white12),
            const Text('تقييمات الطلاب للمنتج', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFFE5C158))),
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.star, color: Colors.amber, size: 28),
                const SizedBox(width: 8),
                Text(
                  avgRating.toStringAsFixed(1),
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                Text(' (${ratings.length} تقييمات)', style: const TextStyle(color: Colors.white38)),
              ],
            ),
            const SizedBox(height: 15),
            const Text('قيّم هذا المنتج:', style: TextStyle(fontSize: 14)),
            const SizedBox(height: 6),
            Row(
              children: List.generate(5, (index) {
                int starVal = index + 1;
                return IconButton(
                  icon: Icon(
                    starVal <= myRating ? Icons.star : Icons.star_border,
                    color: Colors.amber,
                    size: 32,
                  ),
                  onPressed: () => _rateProduct(starVal),
                );
              }),
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: _showOrderDialog,
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
              child: const Text('طلب هذا المنتج الآن', style: TextStyle(fontSize: 16)),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: widget.onAddToCart,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                side: const BorderSide(color: Color(0xFFE5C158), width: 1.5),
              ),
              icon: const Icon(Icons.bookmark_add_outlined, color: Color(0xFFE5C158)),
              label: const Text('الوضع في سلة المشتريات للشراء لاحقا', style: TextStyle(color: Color(0xFFE5C158), fontSize: 15)),
            ),
          ],
        ),
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

  void _editProduct(Map<String, dynamic> product) {
    setState(() {
      _titleController.text = product['title'] ?? '';
      _priceController.text = product['price'] ?? '';
      _descController.text = product['description'] ?? '';
      _imageController.text = product['image'] ?? '';
      selectedProductCategory = globalCategories.contains(product['category']) ? product['category'] : 'عمارة';
      editingProductId = product['id'];
      _selectedTab = 0;
    });
  }

  void _deleteProduct(String id) async {
    try {
      await FirebaseFirestore.instance.collection('products').doc(id).delete();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حذف المنتج بنجاح')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ في الحذف: $e')));
      }
    }
  }

  void _addCategory() {
    String cat = _categoryController.text.trim();
    if (cat.isNotEmpty && !globalCategories.contains(cat)) {
      setState(() {
        globalCategories.add(cat);
        _categoryController.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تمت إضافة القسم ($cat) بنجاح')));
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

  void _deleteSingleChat(String studentName) {
    setState(() {
      globalChats.remove(studentName);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('تم حذف محادثة ($studentName) بنجاح')),
    );
  }

  void _deleteAllChats() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF141418),
        title: const Text('حذف جميع المحادثات', style: TextStyle(color: Colors.redAccent)),
        content: const Text('هل أنت متأكد من مسح كل محادثات الطلاب نهائياً؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () {
              setState(() {
                globalChats.clear();
              });
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('تم مسح جميع المحادثات بنجاح')),
              );
            },
            child: const Text('نعم، مسح الكل'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    List<String> studentNames = globalChats.keys.toList();

    return Scaffold(
      appBar: AppBar(
        title: Text('لوحة الأدمن - ${widget.adminName}'),
        backgroundColor: const Color(0xFF141418),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(50),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton.icon(
                onPressed: () => setState(() => _selectedTab = 0),
                icon: const Icon(Icons.add_box, color: Color(0xFFE5C158)),
                label: Text('إدارة المنتجات', style: TextStyle(color: _selectedTab == 0 ? Colors.white : const Color(0xFFE5C158))),
              ),
              TextButton.icon(
                onPressed: () {
                  setState(() => _selectedTab = 1);
                  _fetchTelegramGallery();
                },
                icon: const Icon(Icons.photo_library, color: Color(0xFFE5C158)),
                label: Text('جاليري تيليجرام', style: TextStyle(color: _selectedTab == 1 ? Colors.white : const Color(0xFFE5C158))),
              ),
              TextButton.icon(
                onPressed: () => setState(() => _selectedTab = 2),
                icon: const Icon(Icons.category, color: Color(0xFFE5C158)),
                label: Text('إدارة الأقسام', style: TextStyle(color: _selectedTab == 2 ? Colors.white : const Color(0xFFE5C158))),
              ),
              TextButton.icon(
                onPressed: () => setState(() => _selectedTab = 3),
                icon: const Icon(Icons.chat, color: Color(0xFFE5C158)),
                label: Text('محادثات الطلاب', style: TextStyle(color: _selectedTab == 3 ? Colors.white : const Color(0xFFE5C158))),
              ),
            ],
          ),
        ),
      ),
      body: _selectedTab == 3
          ? Row(
              children: [
                Container(
                  width: 320,
                  color: const Color(0xFF0F0F12),
                  child: Column(
                    children: [
                      if (studentNames.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade900),
                            icon: const Icon(Icons.delete_sweep, color: Colors.white),
                            label: const Text('حذف جميع المحادثات', style: TextStyle(color: Colors.white)),
                            onPressed: _deleteAllChats,
                          ),
                        ),
                      Expanded(
                        child: studentNames.isEmpty
                            ? const Center(child: Text('لا توجد محادثات حالياً', style: TextStyle(color: Colors.white38)))
                            : ListView.builder(
                                itemCount: studentNames.length,
                                itemBuilder: (context, index) {
                                  String student = studentNames[index];
                                  return ListTile(
                                    leading: const Icon(Icons.person, color: Color(0xFFE5C158)),
                                    title: Text(student, style: const TextStyle(fontWeight: FontWeight.bold)),
                                    trailing: IconButton(
                                      icon: const Icon(Icons.delete, color: Colors.redAccent, size: 20),
                                      onPressed: () => _deleteSingleChat(student),
                                      tooltip: 'حذف محادثة هذا الزبون',
                                    ),
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => ChatScreen(userName: student, isAdmin: true),
                                        ),
                                      ).then((_) => setState(() {}));
                                    },
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
                const Expanded(
                  child: Center(
                    child: Text('اختر طالباً من القائمة لمتابعة المحادثة', style: TextStyle(color: Colors.white38)),
                  ),
                ),
              ],
            )
          : _selectedTab == 2
              ? Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text('إضافة قسم دراسي جديد', style: TextStyle(color: Color(0xFFE5C158), fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _categoryController,
                              decoration: const InputDecoration(labelText: 'اسم القسم الجديد', border: OutlineInputBorder()),
                            ),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton(
                            onPressed: _addCategory,
                            child: const Text('إضافة القسم'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 30),
                      const Text('الأقسام الحالية (حذف)', style: TextStyle(color: Color(0xFFE5C158), fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 10),
                      Expanded(
                        child: ListView.builder(
                          itemCount: globalCategories.length,
                          itemBuilder: (context, index) {
                            String cat = globalCategories[index];
                            if (cat == 'الكل') return const SizedBox.shrink();
                            return Card(
                              color: const Color(0xFF141418),
                              child: ListTile(
                                title: Text(cat, style: const TextStyle(fontWeight: FontWeight.bold)),
                                trailing: IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.redAccent),
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
                                'صور مجموعة تيليجرام (انقر لاختيارها لنشرها كمنتج)',
                                style: TextStyle(color: Color(0xFFE5C158), fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                              ElevatedButton.icon(
                                onPressed: _fetchTelegramGallery,
                                icon: const Icon(Icons.refresh),
                                label: const Text('تحديث الصور'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 15),
                          Expanded(
                            child: isLoadingTelegramImages
                                ? const Center(child: CircularProgressIndicator(color: Color(0xFFE5C158)))
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
                                                borderRadius: BorderRadius.circular(12),
                                                border: Border.all(color: const Color(0xFFE5C158), width: 2),
                                              ),
                                              child: ClipRRect(
                                                borderRadius: BorderRadius.circular(10),
                                                child: CachedNetworkImage(
                                                  imageUrl: imgUrl,
                                                  fit: BoxFit.cover,
                                                  placeholder: (context, url) => const Center(
                                                    child: CircularProgressIndicator(color: Color(0xFFE5C158)),
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
                  : Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 1,
                            child: SingleChildScrollView(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Text(
                                    editingProductId == null ? 'إضافة منتج جديد' : 'تعديل بيانات المنتج',
                                    style: const TextStyle(color: Color(0xFFE5C158), fontSize: 18, fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 15),
                                  TextField(
                                    controller: _titleController,
                                    decoration: const InputDecoration(labelText: 'اسم المنتج', border: OutlineInputBorder()),
                                  ),
                                  const SizedBox(height: 12),
                                  TextField(
                                    controller: _priceController,
                                    decoration: const InputDecoration(labelText: 'السعر (ل.س)', border: OutlineInputBorder()),
                                  ),
                                  const SizedBox(height: 12),
                                  DropdownButtonFormField<String>(
                                    value: globalCategories.where((c) => c != 'الكل').contains(selectedProductCategory)
                                        ? selectedProductCategory
                                        : (globalCategories.where((c) => c != 'الكل').isNotEmpty
                                            ? globalCategories.where((c) => c != 'الكل').first
                                            : null),
                                    decoration: const InputDecoration(labelText: 'القسم', border: OutlineInputBorder()),
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
                                  const SizedBox(height: 12),
                                  TextField(
                                    controller: _imageController,
                                    decoration: const InputDecoration(
                                      labelText: 'رابط صورة تيليجرام',
                                      border: OutlineInputBorder(),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  OutlinedButton.icon(
                                    onPressed: () {
                                      setState(() => _selectedTab = 1);
                                      _fetchTelegramGallery();
                                    },
                                    icon: const Icon(Icons.photo_library, color: Color(0xFFE5C158)),
                                    label: const Text('اختيار من جاليري تيليجرام', style: TextStyle(color: Color(0xFFE5C158))),
                                  ),
                                  const SizedBox(height: 12),
                                  TextField(
                                    controller: _descController,
                                    maxLines: 3,
                                    decoration: const InputDecoration(labelText: 'تفاصيل المنتج ومواصفاته', border: OutlineInputBorder()),
                                  ),
                                  const SizedBox(height: 20),
                                  ElevatedButton(
                                    onPressed: _saveProduct,
                                    style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                                    child: Text(editingProductId == null ? 'نشر المنتج' : 'حفظ التعديلات'),
                                  ),
                                  if (editingProductId != null) ...[
                                    const SizedBox(height: 10),
                                    OutlinedButton(
                                      onPressed: () {
                                        setState(() {
                                          editingProductId = null;
                                          _titleController.clear();
                                          _priceController.clear();
                                          _descController.clear();
                                          _imageController.clear();
                                        });
                                      },
                                      child: const Text('إلغاء التعديل'),
                                    ),
                                  ]
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 24),
                          Expanded(
                            flex: 1,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('قائمة المنتجات الحالية', style: TextStyle(color: Color(0xFFE5C158), fontSize: 16, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 10),
                                Expanded(
                                  child: StreamBuilder<QuerySnapshot>(
                                    stream: FirebaseFirestore.instance.collection('products').snapshots(),
                                    builder: (context, snapshot) {
                                      if (!snapshot.hasData) {
                                        return const Center(child: CircularProgressIndicator(color: Color(0xFFE5C158)));
                                      }
                                      var prods = snapshot.data!.docs.map((doc) {
                                        var data = doc.data() as Map<String, dynamic>;
                                        data['id'] = doc.id;
                                        return data;
                                      }).toList();

                                      if (prods.isEmpty) {
                                        return const Center(child: Text('لا توجد منتجات', style: TextStyle(color: Colors.white38)));
                                      }

                                      return ListView.builder(
                                        itemCount: prods.length,
                                        itemBuilder: (context, index) {
                                          final p = prods[index];
                                          return Card(
                                            color: const Color(0xFF141418),
                                            margin: const EdgeInsets.symmetric(vertical: 6),
                                            child: ListTile(
                                              leading: CachedNetworkImage(
                                                imageUrl: p['image'] ?? '',
                                                width: 45,
                                                height: 45,
                                                fit: BoxFit.cover,
                                                errorWidget: (context, url, error) => const Icon(Icons.image),
                                              ),
                                              title: Text(p['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                              subtitle: Text('${p['category']} | ${p['price']}', style: const TextStyle(color: Color(0xFFE5C158), fontSize: 12)),
                                              trailing: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  IconButton(
                                                    icon: const Icon(Icons.edit, color: Colors.blueAccent, size: 20),
                                                    onPressed: () => _editProduct(p),
                                                  ),
                                                  IconButton(
                                                    icon: const Icon(Icons.delete, color: Colors.redAccent, size: 20),
                                                    onPressed: () => _deleteProduct(p['id']),
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
                            ),
                          ),
                        ],
                      ),
                    ),
    );
  }
}

// ----------------- شاشة المحادثة الخاصة -----------------
class ChatScreen extends StatefulWidget {
  final String userName;
  final bool isAdmin;
  const ChatScreen({super.key, required this.userName, required this.isAdmin});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _msgController = TextEditingController();
  Set<String> selectedMessageIds = {};
  bool isSelectionMode = false;

  void _sendMessage(String text) {
    if (text.trim().isEmpty) return;

    setState(() {
      globalChats.putIfAbsent(widget.userName, () => []);
      globalChats[widget.userName]!.add(
        ChatMessage(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          senderName: widget.isAdmin ? 'الإدارة (حيان)' : widget.userName,
          text: text.trim(),
          isAdmin: widget.isAdmin,
        ),
      );
    });
    _msgController.clear();
  }

  void _deleteSelectedMessages() {
    setState(() {
      globalChats[widget.userName]?.removeWhere((msg) => selectedMessageIds.contains(msg.id));
      selectedMessageIds.clear();
      isSelectionMode = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حذف الرسائل المحددة')));
  }

  void _editMessage(ChatMessage msg) {
    final editController = TextEditingController(text: msg.text);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF141418),
        title: const Text('تعديل الرسالة', style: TextStyle(color: Color(0xFFE5C158))),
        content: TextField(
          controller: editController,
          maxLines: 3,
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () {
              if (editController.text.trim().isNotEmpty) {
                setState(() {
                  msg.text = editController.text.trim();
                });
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تعديل الرسالة بنجاح')));
              }
            },
            child: const Text('حفظ التعديل'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    List<ChatMessage> messages = globalChats[widget.userName] ?? [];

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isAdmin ? 'محادثة الزبون: ${widget.userName}' : 'محادثتي الخاصة مع الإدارة'),
        backgroundColor: const Color(0xFF141418),
        actions: [
          if (widget.isAdmin && messages.isNotEmpty) ...[
            if (isSelectionMode) ...[
              IconButton(
                icon: const Icon(Icons.delete, color: Colors.redAccent),
                onPressed: _deleteSelectedMessages,
                tooltip: 'حذف الرسائل المحددة',
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () {
                  setState(() {
                    isSelectionMode = false;
                    selectedMessageIds.clear();
                  });
                },
              ),
            ] else ...[
              IconButton(
                icon: const Icon(Icons.select_all, color: Color(0xFFE5C158)),
                onPressed: () {
                  setState(() {
                    isSelectionMode = true;
                    selectedMessageIds = messages.map((m) => m.id).toSet();
                  });
                },
                tooltip: 'تحديد الكل لحذفهن',
              ),
              IconButton(
                icon: const Icon(Icons.delete_sweep, color: Colors.redAccent),
                onPressed: () {
                  setState(() {
                    globalChats[widget.userName]?.clear();
                  });
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم مسح كل رسائل المحادثة')));
                },
                tooltip: 'مسح محادثة الزبون',
              ),
            ]
          ]
        ],
      ),
      body: Column(
        children: [
          if (widget.isAdmin)
            Container(
              padding: const EdgeInsets.all(8),
              color: const Color(0xFF141418),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade800, foregroundColor: Colors.white),
                      icon: const Icon(Icons.cancel, size: 18),
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
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700, foregroundColor: Colors.white),
                      icon: const Icon(Icons.check_circle, size: 18),
                      label: const Text('تم الطلب - انتظر الدليفري'),
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
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: messages.length,
              itemBuilder: (context, index) {
                ChatMessage msg = messages[index];
                bool isMe = widget.isAdmin ? msg.isAdmin : !msg.isAdmin;
                bool isSelected = selectedMessageIds.contains(msg.id);

                return GestureDetector(
                  onLongPress: widget.isAdmin
                      ? () {
                          setState(() {
                            isSelectionMode = true;
                            if (isSelected) {
                              selectedMessageIds.remove(msg.id);
                            } else {
                              selectedMessageIds.add(msg.id);
                            }
                          });
                        }
                      : null,
                  child: Align(
                    alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Colors.red.shade900
                            : isMe
                                ? const Color(0xFFE5C158)
                                : const Color(0xFF1E1E24),
                        borderRadius: BorderRadius.circular(14),
                        border: isSelected ? Border.all(color: Colors.red, width: 2) : null,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isSelectionMode)
                            Checkbox(
                              value: isSelected,
                              onChanged: (val) {
                                setState(() {
                                  if (val == true) {
                                    selectedMessageIds.add(msg.id);
                                  } else {
                                    selectedMessageIds.remove(msg.id);
                                  }
                                });
                              },
                            ),
                          Flexible(
                            child: Text(
                              msg.text,
                              style: TextStyle(color: isMe ? Colors.black : Colors.white),
                            ),
                          ),
                          if (widget.isAdmin && msg.isAdmin) ...[
                            const SizedBox(width: 8),
                            InkWell(
                              onTap: () => _editMessage(msg),
                              child: const Icon(Icons.edit, size: 16, color: Colors.black54),
                            ),
                          ]
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(10),
            color: const Color(0xFF0F0F12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _msgController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'اكتب رسالتك هنا...',
                      hintStyle: const TextStyle(color: Colors.white38),
                      filled: true,
                      fillColor: const Color(0xFF141418),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.send, color: Color(0xFFE5C158)),
                  onPressed: () => _sendMessage(_msgController.text),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}