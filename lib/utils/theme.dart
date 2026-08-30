// lib/utils/theme.dart
import 'package:flutter/material.dart';

class AppColors {
  static const bg0     = Color(0xFF0A0C0F);
  static const bg1     = Color(0xFF111418);
  static const bg2     = Color(0xFF1A1F26);
  static const bg3     = Color(0xFF242B35);
  static const text0   = Color(0xFFF0F4F8);
  static const text1   = Color(0xFF9AA5B4);
  static const text2   = Color(0xFF627082);
  static const accent  = Color(0xFF00B4D8);

  static const aqi1 = Color(0xFF00E676);
  static const aqi2 = Color(0xFF76FF03);
  static const aqi3 = Color(0xFFFFD740);
  static const aqi4 = Color(0xFFFF6D00);
  static const aqi5 = Color(0xFFD50000);

  static const temp     = Color(0xFFFF8A65);
  static const humidity = Color(0xFF4FC3F7);
  static const pm       = Color(0xFFCE93D8);
  static const pressure = Color(0xFF80CBC4);
  static const co2      = Color(0xFFFFF176);
  static const tvoc     = Color(0xFFFF6EC7);

  static const connected    = Color(0xFF00E676);
  static const disconnected = Color(0xFF627082);
  static const error        = Color(0xFFD50000);

  static Color aqiColor(int aqi) {
    switch (aqi) {
      case 1: return aqi1;
      case 2: return aqi2;
      case 3: return aqi3;
      case 4: return aqi4;
      case 5: return aqi5;
      default: return text2;
    }
  }

  static Color co2Color(int eco2) {
    if (eco2 < 600)  return aqi1;
    if (eco2 < 1000) return aqi3;
    if (eco2 < 1500) return aqi4;
    return aqi5;
  }

  static Color pmColor(int pm25) {
    if (pm25 < 12) return aqi1;
    if (pm25 < 35) return aqi3;
    if (pm25 < 55) return aqi4;
    return aqi5;
  }
}

final appTheme = ThemeData(
  brightness: Brightness.dark,
  scaffoldBackgroundColor: AppColors.bg0,
  colorScheme: const ColorScheme.dark(
    primary: AppColors.accent,
    surface: AppColors.bg1,
    onSurface: AppColors.text0,
  ),
  fontFamily: 'SpaceMono',
  appBarTheme: const AppBarTheme(
    backgroundColor: AppColors.bg1,
    foregroundColor: AppColors.text0,
    elevation: 0,
    centerTitle: false,
    titleTextStyle: TextStyle(
      fontFamily: 'SpaceMono',
      fontSize: 16,
      fontWeight: FontWeight.bold,
      color: AppColors.text0,
      letterSpacing: 1,
    ),
  ),
  bottomNavigationBarTheme: const BottomNavigationBarThemeData(
    backgroundColor: AppColors.bg1,
    selectedItemColor: AppColors.accent,
    unselectedItemColor: AppColors.text2,
    type: BottomNavigationBarType.fixed,
  ),
  cardTheme: CardThemeData(
    color: AppColors.bg1,
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
      side: const BorderSide(color: AppColors.bg3),
    ),
  ),
  dividerColor: AppColors.bg3,
  textTheme: const TextTheme(
    bodyLarge:  TextStyle(color: AppColors.text0, fontFamily: 'SpaceMono'),
    bodyMedium: TextStyle(color: AppColors.text1, fontFamily: 'SpaceMono'),
    bodySmall:  TextStyle(color: AppColors.text2, fontFamily: 'SpaceMono'),
  ),
);
