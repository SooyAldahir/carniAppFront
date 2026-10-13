import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Construye los temas claro/oscuro de la app en Material 3,
/// a partir de la paleta de marca (AppColors).
class AppTheme {
  AppTheme._();

  static ThemeData light() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.vino,
      brightness: Brightness.light,
      primary: AppColors.vino,
      tertiary: AppColors.bronce,
      surface: AppColors.hueso,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.hueso,
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.hueso,
        foregroundColor: AppColors.carbon,
        elevation: 0,
      ),
    );
  }

  static ThemeData dark() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.vino,
      brightness: Brightness.dark,
      primary: AppColors.bronce,
      tertiary: AppColors.vino,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
    );
  }
}
