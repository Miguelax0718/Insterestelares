import 'package:flutter/material.dart';

/// Paleta de colores para la interfaz de cabina espacial (Space Cockpit Dark Mode)
class SpaceTheme {
  static const Color background = Color(0xFF070A0F);
  static const Color surface = Color(0xFF0D141F);
  static const Color card = Color(0xFF141D2B);
  
  // Acentos de telemetría médica
  static const Color cyan = Color(0xFF00E5FF);
  static const Color green = Color(0xFF00E676);
  static const Color warningYellow = Color(0xFFFFD600);
  static const Color dangerRed = Color(0xFFFF1744);
  static const Color neonPurple = Color(0xFFD500F9);

  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      colorScheme: const ColorScheme.dark(
        primary: cyan,
        secondary: green,
        surface: surface,
        error: dangerRed,
      ),
      cardTheme: const CardThemeData(
        color: card,
        elevation: 2,
        margin: EdgeInsets.all(8),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: surface,
        elevation: 0,
        centerTitle: false,
      ),
    );
  }
}
