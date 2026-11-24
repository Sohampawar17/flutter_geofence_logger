import 'package:flutter/material.dart';

import 'app_controller.dart';
import 'app_shell.dart';

class GeoPulseApp extends StatefulWidget {
  const GeoPulseApp({super.key});

  @override
  State<GeoPulseApp> createState() => _GeoPulseAppState();
}

class _GeoPulseAppState extends State<GeoPulseApp> {
  late final AppController controller;

  @override
  void initState() {
    super.initState();
    controller = AppController()..initialize();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'GeoPulse',
    theme: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF5B5CE2),
        primary: const Color(0xFF4141C8),
        secondary: const Color(0xFF006C49),
        surface: const Color(0xFFFBF8FF),
      ),
      scaffoldBackgroundColor: const Color(0xFFFBF8FF),
      cardTheme: const CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: Colors.white,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: Color(0xFFE2E4ED)),
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFF4F2FF),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF5B5CE2), width: 2),
        ),
      ),
      navigationBarTheme: const NavigationBarThemeData(
        backgroundColor: Colors.white,
        indicatorColor: Color(0xFFE1DFFF),
        elevation: 3,
      ),
    ),
    home: AppShell(controller: controller),
  );
}
