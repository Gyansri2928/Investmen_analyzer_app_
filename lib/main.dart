import 'dart:ui';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // ✅ REQUIRED for SystemChrome
import 'package:property_analyzer_mobile/controller/auth_controller.dart';
import 'package:property_analyzer_mobile/controller/property_controller.dart';
import 'package:property_analyzer_mobile/pages/pcm.dart';
import 'package:property_analyzer_mobile/pages/saved_properties.dart';
import 'package:property_analyzer_mobile/pages/login_page.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'firebase_options.dart';

void main() async {
  // ✅ FIX 1: Add parenthesis and setup System UI for Full Screen
  WidgetsFlutterBinding.ensureInitialized();
  await GetStorage.init();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  Get.put(AuthController());
  Get.put(PropertyController());
  Get.put(ThemeController());

  // This forces the app to fill the screen (including behind the status bar)
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  // This makes the top status bar transparent so your gradient shows through
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light, // Icons color (white)
      systemNavigationBarColor:
          Colors.transparent, // Bottom nav bar transparent
    ),
  );

  runApp(const PropertyAnalyzerApp());
}

class AppColors {
  static const Color headerLightStart = Color.fromARGB(255, 24, 42, 59);
  static const Color headerLightEnd = Color.fromARGB(255, 62, 87, 126);
  static const Color headerDarkStart = Color(0xFF0F172A);
  static const Color headerDarkEnd = Color(0xFF1E293B);
  static const Color bgLightStart = Color(0xFFF5F7FA);
  static const Color bgLightEnd = Color(0xFFC3CFE2);
  static const Color bgDark = Color(0xFF121212);
  static const Color accentTeal = Color(0xFF4ECDC4);
  static const Color textDark = Color(0xFF212529);
  static const Color textLight = Color(0xFFF8F9FA);
}

class PropertyAnalyzerApp extends StatelessWidget {
  const PropertyAnalyzerApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Access ThemeController to react to changes
    final ThemeController themeController = Get.find();

    return Obx(
      () => GetMaterialApp(
        title: 'Property Investment Analyzer',
        debugShowCheckedModeBanner: false,

        // ✅ Theme Logic controlled by GetX
        themeMode: themeController.isDarkMode.value
            ? ThemeMode.dark
            : ThemeMode.light,

        theme: ThemeData(
          useMaterial3: true,
          brightness: Brightness.light,
          scaffoldBackgroundColor: AppColors.bgLightStart,
          colorScheme: const ColorScheme.light(
            primary: AppColors.headerLightEnd,
            secondary: AppColors.headerLightStart,
          ),
        ),
        darkTheme: ThemeData(
          useMaterial3: true,
          brightness: Brightness.dark,
          scaffoldBackgroundColor: AppColors.bgDark,
          colorScheme: const ColorScheme.dark(
            primary: AppColors.accentTeal,
            secondary: AppColors.headerDarkEnd,
          ),
        ),

        // ✅ THE IMPORTANT PART: AUTH GATE
        // If user is null -> Show LoginPage
        // If user is logged in -> Show MainLayout
        home: Obx(() {
          return Get.find<AuthController>().firebaseUser.value == null
              // ✅ ADD key: ValueKey('login')
              ? const LoginPage(key: ValueKey('login'))
              // ✅ ADD key: ValueKey('home')
              : const MainLayout(key: ValueKey('home'));
        }),
      ),
    );
  }
}

class MainLayout extends StatelessWidget {
  const MainLayout({super.key}); // No arguments needed now!

  @override
  Widget build(BuildContext context) {
    final bool isMobile = MediaQuery.of(context).size.width < 768;
    final themeController = Get.find<ThemeController>(); // Access controller

    return Obx(
      () => Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          flexibleSpace: GlassHeader(isMobile: isMobile), // Cleaner!
          toolbarHeight: isMobile ? 56 : 75,
        ),
        body: Container(
          decoration: BoxDecoration(
            gradient: themeController.isDarkMode.value
                ? null
                : const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppColors.bgLightStart, AppColors.bgLightEnd],
                  ),
            color: themeController.isDarkMode.value ? AppColors.bgDark : null,
          ),
          child: Padding(
            padding: EdgeInsets.only(top: isMobile ? 80 : 100),
            child:
                const PropertyComparisonMobile(), // Make sure this matches your import
          ),
        ),
        bottomNavigationBar: isMobile ? null : const DesktopFooter(),
      ),
    );
  }
}

class GlassHeader extends StatelessWidget {
  final bool isMobile;

  const GlassHeader({super.key, required this.isMobile});

  @override
  Widget build(BuildContext context) {
    final themeController = Get.find<ThemeController>();
    final authController = Get.find<AuthController>();

    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12.0, sigmaY: 12.0),
        child: Obx(
          () => Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: themeController.isDarkMode.value
                    ? [
                        AppColors.headerDarkStart.withOpacity(0.85),
                        AppColors.headerDarkEnd.withOpacity(0.85),
                      ]
                    : [
                        AppColors.headerLightStart.withOpacity(0.85),
                        AppColors.headerLightEnd.withOpacity(0.85),
                      ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: const Border(bottom: BorderSide(color: Colors.white10)),
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 32),
                child: Row(
                  children: [
                    // --- LOGO (Unchanged) ---
                    Image.asset(
                      'assets/logo.png',
                      height: isMobile ? 40 : 60,
                      errorBuilder: (c, o, s) => const Icon(
                        Icons.apartment,
                        color: Colors.white,
                        size: 40,
                      ),
                    ),
                    const SizedBox(width: 16),

                    // --- TITLE (Unchanged) ---
                    if (!isMobile)
                      const Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Property Investment Analyzer",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),

                    if (isMobile) const Spacer(),

                    // --- RIGHT SIDE ICONS ---
                    Row(
                      children: [
                        // ✅ 1. NEW: SAVED PROPERTIES BUTTON
                        IconButton(
                          icon: const Icon(
                            Icons.folder_open,
                            color: Colors.white,
                          ),
                          tooltip: "My Properties",
                          onPressed: () {
                            // Navigate to the Saved Screen
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => SavedPropertiesScreen(),
                              ),
                            );
                          },
                        ),

                        // 2. Theme Toggle (Existing)
                        IconButton(
                          icon: Icon(
                            themeController.isDarkMode.value
                                ? Icons.light_mode
                                : Icons.dark_mode,
                            color: Colors.white,
                          ),
                          onPressed: themeController.toggleTheme,
                        ),

                        const SizedBox(width: 8),

                        // 3. User Dropdown (Existing)
                        Container(
                          height: 36,
                          width: 36,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white54, width: 2),
                            color: Colors.white24,
                          ),
                          child: PopupMenuButton<String>(
                            offset: const Offset(0, 45),
                            padding: EdgeInsets.zero,
                            icon: const Icon(
                              Icons.person,
                              color: Colors.white,
                              size: 20,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            onSelected: (value) {
                              if (value == 'logout') {
                                authController.logout();
                              }
                            },
                            itemBuilder: (BuildContext context) {
                              final user = authController.firebaseUser.value;
                              final email = user?.email ?? 'No Email';
                              final name =
                                  user?.displayName ?? email.split('@')[0];
                              final isVerified = user?.emailVerified ?? false;

                              return [
                                PopupMenuItem<String>(
                                  enabled: false,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        name,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                          color: Theme.of(
                                            context,
                                          ).textTheme.bodyLarge?.color,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        email,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Theme.of(
                                            context,
                                          ).textTheme.bodySmall?.color,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: isVerified
                                              ? Colors.green.withOpacity(0.1)
                                              : Colors.orange.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                          border: Border.all(
                                            color: isVerified
                                                ? Colors.green
                                                : Colors.orange,
                                            width: 1,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              isVerified
                                                  ? Icons.verified
                                                  : Icons.gpp_bad,
                                              size: 12,
                                              color: isVerified
                                                  ? Colors.green
                                                  : Colors.orange,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              isVerified
                                                  ? "Verified"
                                                  : "Not Verified",
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                color: isVerified
                                                    ? Colors.green
                                                    : Colors.orange,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const PopupMenuDivider(
                                  color: Colors.grey,
                                  thickness: 1,
                                ),
                                const PopupMenuItem<String>(
                                  value: 'logout',
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.logout,
                                        color: Colors.redAccent,
                                        size: 20,
                                      ),
                                      SizedBox(width: 10),
                                      Text(
                                        "Sign Out",
                                        style: TextStyle(
                                          color: Colors.redAccent,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ];
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class DesktopFooter extends StatelessWidget {
  const DesktopFooter({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      color: const Color(0xFF2C3E50),
      child: const Center(
        child: Text(
          "© 2026 Agenthum AI Solutions Pvt. Ltd. • All Rights Reserved",
          style: TextStyle(color: Colors.white70, fontSize: 12),
        ),
      ),
    );
  }
}

class PropertyComparisonPage extends StatelessWidget {
  const PropertyComparisonPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const PropertyComparisonMobile();
  }
}

class ThemeController extends GetxController {
  final _box = GetStorage();
  final _key = 'isDarkMode';

  // Observable state
  RxBool isDarkMode = false.obs;

  @override
  void onInit() {
    super.onInit();
    // Load saved theme or default to Light
    isDarkMode.value = _box.read(_key) ?? false;
    Get.changeThemeMode(isDarkMode.value ? ThemeMode.dark : ThemeMode.light);
  }

  void toggleTheme() {
    isDarkMode.value = !isDarkMode.value;
    Get.changeThemeMode(isDarkMode.value ? ThemeMode.dark : ThemeMode.light);
    _box.write(_key, isDarkMode.value); // Save preference
  }
}
