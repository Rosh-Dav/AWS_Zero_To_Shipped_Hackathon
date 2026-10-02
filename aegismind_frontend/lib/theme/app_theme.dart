import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Common Colors
  static const Color dangerLight = Color(0xFFE11D48); // Rose 600
  static const Color dangerDark = Color(0xFFF43F5E); // Rose 500
  static const Color warningLight = Color(0xFFD97706); // Amber 600
  static const Color warningDark = Color(0xFFF59E0B); // Amber 500
  static const Color successLight = Color(0xFF059669); // Emerald 600
  static const Color successDark = Color(0xFF10B981); // Emerald 500
  static const Color idleLight = Color(0xFF64748B); // Slate 500
  static const Color idleDark = Color(0xFF94A3B8); // Slate 400

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: const ColorScheme.light(
        primary: Color(0xFF4338CA), // Indigo 700
        surface: Color(0xFFFFFFFF), // White cards
        surfaceContainerHighest: Color(0xFFF1F5F9), // Slate 100 (Deep/Borders)
        surfaceContainer: Color(0xFFF8FAFC), // Slate 50 (Main BG)
        onSurface: Color(0xFF0F172A), // Slate 900 (Text Primary)
        onSurfaceVariant: Color(0xFF475569), // Slate 600 (Text Muted)
        error: dangerLight,
      ),
      scaffoldBackgroundColor: Colors.transparent,
      appBarTheme: const AppBarTheme(backgroundColor: Colors.transparent, elevation: 0, surfaceTintColor: Colors.transparent),
      textTheme: GoogleFonts.outfitTextTheme(ThemeData.light().textTheme),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF4338CA),
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: const ColorScheme.dark(
        primary: Color(0xFF6366F1), // Indigo 500
        surface: Color(0xFF1E293B), // Slate 800 (Cards)
        surfaceContainerHighest: Color(0xFF020617), // Slate 950 (Deep/Borders)
        surfaceContainer: Color(0xFF0F172A), // Slate 900 (Main BG)
        onSurface: Color(0xFFF8FAFC), // Slate 50 (Text Primary)
        onSurfaceVariant: Color(0xFF94A3B8), // Slate 400 (Text Muted)
        error: dangerDark,
      ),
      scaffoldBackgroundColor: Colors.transparent,
      appBarTheme: const AppBarTheme(backgroundColor: Colors.transparent, elevation: 0, surfaceTintColor: Colors.transparent),
      textTheme: GoogleFonts.outfitTextTheme(ThemeData.dark().textTheme),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF6366F1),
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }
}

extension IncidentColors on ThemeData {
  Color get dangerColor => brightness == Brightness.light ? AppTheme.dangerLight : AppTheme.dangerDark;
  Color get warningColor => brightness == Brightness.light ? AppTheme.warningLight : AppTheme.warningDark;
  Color get successColor => brightness == Brightness.light ? AppTheme.successLight : AppTheme.successDark;
  Color get idleColor => brightness == Brightness.light ? AppTheme.idleLight : AppTheme.idleDark;
}
