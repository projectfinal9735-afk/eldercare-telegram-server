import 'package:flutter/material.dart';

class AppColors {
  // Modern blue palette (change colors only)
  static const Color bg = Color.fromARGB(255, 255, 255, 255);        // deep navy background
  static const Color accent = Color(0xFF1E88E5);    // modern blue accent
  static const Color field = Colors.white;
}


ThemeData buildAppTheme() {
  return ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: AppColors.bg,
    fontFamilyFallback: const ['Kanit', 'Prompt', 'sans-serif'],
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color.fromARGB(255, 255, 255, 255),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.accent,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
  );
}
