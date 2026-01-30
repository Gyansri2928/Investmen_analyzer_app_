import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // ✅ REQUIRED for SystemChrome
import 'package:property_analyzer_mobile/controller/property_controller.dart';
import 'package:property_analyzer_mobile/pages/pcm.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

void main() async {
  // ✅ FIX 1: Add parenthesis and setup System UI for Full Screen
  WidgetsFlutterBinding.ensureInitialized();
  await GetStorage.init();
  Get.put(PropertyController());

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

class PropertyAnalyzerApp extends StatefulWidget {
  const PropertyAnalyzerApp({super.key});

  @override
  State<PropertyAnalyzerApp> createState() => _PropertyAnalyzerAppState();
}

class _PropertyAnalyzerAppState extends State<PropertyAnalyzerApp> {
  ThemeMode _themeMode = ThemeMode.light;

  void toggleTheme() {
    setState(() {
      _themeMode = _themeMode == ThemeMode.light
          ? ThemeMode.dark
          : ThemeMode.light;
    });
  }

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'Property Investment Analyzer',
      debugShowCheckedModeBanner: false,
      themeMode: _themeMode,
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
      home: MainLayout(
        toggleTheme: toggleTheme,
        isDarkMode: _themeMode == ThemeMode.dark,
      ),
    );
  }
}

class MainLayout extends StatelessWidget {
  final VoidCallback toggleTheme;
  final bool isDarkMode;

  const MainLayout({
    super.key,
    required this.toggleTheme,
    required this.isDarkMode,
  });

  @override
  Widget build(BuildContext context) {
    final bool isMobile = MediaQuery.of(context).size.width < 768;

    return Scaffold(
      // ✅ FIX 2: Essential for "Behind Notch" layout
      extendBodyBehindAppBar: true,

      appBar: AppBar(
        // Make the standard AppBar invisible so our GlassHeader shows
        backgroundColor: Colors.transparent,
        elevation: 0,
        // ✅ FIX 3: Use flexibleSpace. This automatically stretches to cover the status bar
        flexibleSpace: GlassHeader(
          isMobile: isMobile,
          toggleTheme: toggleTheme,
          isDarkMode: isDarkMode,
        ),
        // We set the height of the toolbar to 0 because flexibleSpace handles it
        toolbarHeight: isMobile ? 56 : 75,
      ),

      body: Container(
        decoration: BoxDecoration(
          gradient: isDarkMode
              ? null
              : const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.bgLightStart, AppColors.bgLightEnd],
                ),
          color: isDarkMode ? AppColors.bgDark : null,
        ),
        // ✅ FIX 4: Add top padding to body so content doesn't hide behind the header
        // We use kToolbarHeight + padding to push the content down correctly
        child: Padding(
          padding: EdgeInsets.only(top: isMobile ? 80 : 100),
          child: const PropertyComparisonPage(),
        ),
      ),
      bottomNavigationBar: isMobile ? null : const DesktopFooter(),
    );
  }
}

class GlassHeader extends StatelessWidget {
  final bool isMobile;
  final VoidCallback toggleTheme;
  final bool isDarkMode;

  const GlassHeader({
    super.key,
    required this.isMobile,
    required this.toggleTheme,
    required this.isDarkMode,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12.0, sigmaY: 12.0),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDarkMode
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
          // ✅ FIX 5: Use SafeArea only for the ROW (Content), not the Container
          // This allows the Container color to go UP behind the notch, but pushes the Logo DOWN into view.
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 32),
              child: Row(
                children: [
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
                  if (!isMobile)
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Property Investment Analyzer",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Row(
                            children: [
                              const Text(
                                "Strategic Investment Insights • By ",
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                              const Text(
                                "Agenthum AI Solutions",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  if (isMobile) const Spacer(), // Push icons to right on mobile
                  Row(
                    children: [
                      IconButton(
                        icon: Icon(
                          isDarkMode ? Icons.light_mode : Icons.dark_mode,
                          color: Colors.white,
                        ),
                        onPressed: toggleTheme,
                      ),
                      const SizedBox(width: 8),
                      Container(
                        height: 36,
                        width: 36,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white54, width: 2),
                          color: Colors.white24,
                        ),
                        child: const Icon(
                          Icons.person,
                          color: Colors.white,
                          size: 20,
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
