import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // ── Palet Warna ──────────────────────────────────────────────────
  static const Color primary     = Color(0xFFFF9900);
  static const Color primaryDark = Color(0xFFE55A26);
  static const Color onPrimary   = Colors.white;

  // Light
  static const Color bgLight      = Color(0xFFFAFAFA);
  static const Color surfaceLight = Color(0xFFF5F5F5);
  static const Color cardLight    = Colors.white;
  static const Color textLight    = Color(0xFF1A1A1A);
  static const Color mutedLight   = Color(0xFF888888);
  static const Color divLight     = Color(0xFFEEEEEE);

  // Dark
  static const Color bgDark      = Color(0xFF111111);
  static const Color surfaceDark = Color(0xFF1E1E1E);
  static const Color cardDark    = Color(0xFF242424);
  static const Color textDark    = Color(0xFFF5F5F5);
  static const Color mutedDark   = Color(0xFF9E9E9E);
  static const Color divDark     = Color(0xFF2A2A2A);

  // ── Light Theme ──────────────────────────────────────────────────
  static ThemeData light() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.light(
        primary: primary,
        onPrimary: onPrimary,
        surface: surfaceLight,
      ),
      scaffoldBackgroundColor: bgLight,
      cardColor: cardLight,
      dividerColor: divLight,
      textTheme: GoogleFonts.poppinsTextTheme(),
      appBarTheme: AppBarTheme(
        backgroundColor: cardLight,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: GoogleFonts.poppins(
          color: textLight, fontSize: 16, fontWeight: FontWeight.w600),
        iconTheme: const IconThemeData(color: textLight),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: onPrimary,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: cardLight,
        selectedItemColor: primary,
        unselectedItemColor: mutedLight,
      ),
    );
  }

  // ── Dark Theme ───────────────────────────────────────────────────
  static ThemeData dark() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.dark(
        primary: primary,
        onPrimary: onPrimary,
        surface: surfaceDark,
      ),
      scaffoldBackgroundColor: bgDark,
      cardColor: cardDark,
      dividerColor: divDark,
      textTheme: GoogleFonts.poppinsTextTheme(ThemeData.dark().textTheme),
      appBarTheme: AppBarTheme(
        backgroundColor: surfaceDark,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: GoogleFonts.poppins(
          color: textDark, fontSize: 16, fontWeight: FontWeight.w600),
        iconTheme: const IconThemeData(color: textDark),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: onPrimary,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: surfaceDark,
        selectedItemColor: primary,
        unselectedItemColor: mutedDark,
      ),
    );
  }
}