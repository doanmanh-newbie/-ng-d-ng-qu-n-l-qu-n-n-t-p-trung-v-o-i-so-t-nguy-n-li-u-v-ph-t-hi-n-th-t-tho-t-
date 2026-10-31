import 'package:flutter/material.dart';

/// Palette và bộ màu ngữ nghĩa duy nhất của Fore.
abstract final class AppColors {
  static const brand = Color(0xFF0C2D32);
  static const brandAccent = Color(0xFF51A19B);
  static const background = Color(0xFFF3F7F5);
  static const surface = Color(0xFFFFFFFF);
  static const border = Color(0xFFCBD8D4);
  static const textPrimary = Color(0xFF14292A);
  static const textSecondary = Color(0xFF4F6663);
  static const disabledFill = Color(0xFFE3EAE7);

  static const statusHealthy = Color(0xFF18794E);
  static const statusAttention = Color(0xFF8A5A00);
  static const statusCritical = Color(0xFFB42318);
  static const statusHealthyTint = Color(0xFFE2F4EA);
  static const statusAttentionTint = Color(0xFFFFF1CC);
  static const statusCriticalTint = Color(0xFFFBE4E2);

  static const warning = Color(0xFFED6C02);
  static const warningText = Color(0xFFB54708);
  static const warningSoft = Color(0xFFFFF4E5);
  static const inkMuted = Color(0x8C0C2D32);
  static const tint = Color(0xFFEAF0EE);
  static const shadow = Color(0x1F0C2D32);
  static const shadowSoft = Color(0x120C2D32);
  static const onInkMuted = Color(0xB3FFFFFF);
  static const scrim = Color(0x730C2D32);
  static const surfaceDark = Color(0xFF123C3A);
  static const actionLime = Color(0xFFD8F27A);
  static const navIndicator = Color(0xFFDDF1EF);
  static const cardBorder = Color(0xFFE7EFEC);
  static const legacyTeal = Color(0xFF3F9E92);
  static const legacyDanger = Color(0xFFD8433A);
  static const backgroundTint = Color(0xFFDDEFE7);
  static const healthyBackground = Color(0xFFE6F4EC);
  static const warningOverlay = Color(0x66ED6C02);
  static const shadowSubtle = Color(0x140C2D32);
  static const shadowMedium = Color(0x330C2D32);
  static const shadowRaised = Color(0x400C2D32);
  static const shadowStrong = Color(0xDB0C2D32);
  static const onSurfaceStrong = Color(0xCCFFFFFF);
  static const onDarkBorder = Color(0x66FFFFFF);
  static const white = Color(0xFFFFFFFF);

  // Tên tương thích với các màn đang được chuyển dần sang bộ component mới.
  static const statusOk = statusHealthy;
  static const statusWatch = statusAttention;
  static const statusOff = statusCritical;
  static const ink = brand;
  static const surfaceTint = tint;
  static const hairline = border;
  static const textMuted = textSecondary;
  static const statusWatchBright = statusAttention;
  static const statusOkTint = statusHealthyTint;
  static const statusWatchTint = statusAttentionTint;
  static const statusOffTint = statusCriticalTint;
}
