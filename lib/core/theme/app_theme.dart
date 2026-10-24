import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Kích thước dùng chung, khớp bản thiết kế: lề 16, bo góc 12, nút cao 48.
abstract final class AppSizes {
  static const pagePadding = 16.0;
  static const radius = 12.0;
  static const controlHeight = 48.0;
}

abstract final class AppTheme {
  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.brand,
      primary: AppColors.brand,
      surface: AppColors.surface,
      error: AppColors.statusOff,
    );
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppSizes.radius),
    );
    OutlineInputBorder border(Color color) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSizes.radius),
          borderSide: BorderSide(color: color),
        );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.background,
      textTheme: Typography.blackMountainView.apply(
        bodyColor: AppColors.textPrimary,
        displayColor: AppColors.textPrimary,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        enabledBorder: border(AppColors.border),
        focusedBorder: border(AppColors.brand),
        errorBorder: border(AppColors.statusOff),
        focusedErrorBorder: border(AppColors.statusOff),
        disabledBorder: border(AppColors.border),
        errorStyle: const TextStyle(color: AppColors.statusOff, fontSize: 12),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(AppSizes.controlHeight),
          shape: shape,
          backgroundColor: AppColors.brand,
          foregroundColor: Colors.white,
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(AppSizes.controlHeight),
          shape: shape,
          foregroundColor: AppColors.brand,
          side: const BorderSide(color: AppColors.brand),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(48, AppSizes.controlHeight),
          foregroundColor: AppColors.brand,
        ),
      ),
    );
  }
}
