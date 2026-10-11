import 'package:flutter/material.dart';

/// Paleta Family Funds: verdes (dinheiro, crescimento) e azuis (confiança, estabilidade).
class FFColors {
  static const green = Color(0xFF00A86B);
  static const greenDark = Color(0xFF00794D);
  static const greenLight = Color(0xFF66D4A3);
  static const blue = Color(0xFF1565C0);
  static const blueLight = Color(0xFF42A5F5);
  static const teal = Color(0xFF00897B);
  static const navy = Color(0xFF0D2B4E);

  static const income = green;
  static const expense = Color(0xFF1E88E5);
  static const danger = Color(0xFFD32F2F);
  static const warning = Color(0xFFF9A825);

  static const brandGradient = LinearGradient(
    colors: [green, blue],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Cores para gráficos de categoria, alternando verdes e azuis.
  static const chart = [
    Color(0xFF00A86B),
    Color(0xFF1565C0),
    Color(0xFF26A69A),
    Color(0xFF42A5F5),
    Color(0xFF2E7D32),
    Color(0xFF0288D1),
    Color(0xFF66BB6A),
    Color(0xFF5C6BC0),
    Color(0xFF80CBC4),
    Color(0xFF90CAF9),
  ];
}

ThemeData buildTheme(Brightness brightness) {
  final isDark = brightness == Brightness.dark;
  final scheme = ColorScheme.fromSeed(
    seedColor: FFColors.green,
    brightness: brightness,
  ).copyWith(
    primary: isDark ? FFColors.greenLight : FFColors.green,
    secondary: isDark ? FFColors.blueLight : FFColors.blue,
    tertiary: FFColors.teal,
    surface: isDark ? const Color(0xFF0B1A2A) : const Color(0xFFF5FAF8),
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: scheme.surface,
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      foregroundColor: isDark ? Colors.white : FFColors.navy,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: isDark ? Colors.white : FFColors.navy,
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: isDark ? const Color(0xFF12263B) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      margin: EdgeInsets.zero,
    ),
    navigationBarTheme: NavigationBarThemeData(
      indicatorColor: scheme.primary.withValues(alpha: 0.18),
      backgroundColor: isDark ? const Color(0xFF0F2134) : Colors.white,
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: FFColors.green,
      foregroundColor: Colors.white,
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      filled: true,
      fillColor: isDark ? const Color(0xFF12263B) : Colors.white,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(50),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
  );
}
