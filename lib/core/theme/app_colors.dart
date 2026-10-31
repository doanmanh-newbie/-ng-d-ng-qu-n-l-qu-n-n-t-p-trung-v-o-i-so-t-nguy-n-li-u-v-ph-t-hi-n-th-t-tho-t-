import 'package:flutter/material.dart';

/// Token màu. Mã hex lấy từ file thiết kế Figma (màu mực #0C2D32 trùng với màu
/// đậm của logo). Sửa ở đây, mọi màn hình tự đổi theo.
abstract final class AppColors {
  static const brand = Color(0xFF0C2D32); // mực đậm: nút chính, chữ tiêu đề
  static const brandAccent = Color(0xFF3F9E92); // teal sáng: logo, điểm nhấn
  static const background = Color(0xFFF3F7F5);
  static const surface = Color(0xFFFFFFFF);
  static const border = Color(0xFFCBD8D4);
  static const textPrimary = Color(0xFF14292A);
  static const textSecondary = Color(0xFF4F6663); // đủ tương phản trên nền nhạt
  static const disabledFill = Color(0xFFE3EAE7);

  // Màu trạng thái: chỉ dùng cho trạng thái, không dùng làm trang trí.
  static const statusHealthy = Color(0xFF18794E);
  static const statusAttention = Color(0xFF8A5A00);
  static const statusCritical = Color(0xFFB42318);

  // Tên cũ giữ để các màn hiện có tiếp tục dùng cùng màu ngữ nghĩa.
  static const statusOk = statusHealthy;
  static const statusWatch = statusAttention;
  static const statusOff = statusCritical;

  /// Cảnh báo (cam), dùng cho icon cảnh báo và lỗi nhập liệu. Chữ cam đi kèm
  /// chữ đậm hơn ([warningText]) để đủ tương phản trên nền sáng.
  static const warning = Color(0xFFED6C02);
  static const warningText = Color(0xFFB54708);
  static const warningSoft = Color(0xFFFFF4E5);

  /// Màu mực mờ: tab bị khóa, chữ phụ.
  static const inkMuted = Color(0x8C0C2D32);
  static const tint = Color(0xFFEAF0EE); // nền viên thuốc, nền ô số liệu

  // Tương thích token được dùng bởi các màn nghiệp vụ mới.
  static const ink = brand;
  static const surfaceTint = tint;
  static const hairline = border;
  static const textMuted = textSecondary;
  static const statusWatchBright = statusAttention;
  static const statusHealthyTint = Color(0xFFE2F4EA);
  static const statusAttentionTint = Color(0xFFFFF1CC);
  static const statusCriticalTint = Color(0xFFFBE4E2);
  static const statusOkTint = statusHealthyTint;
  static const statusWatchTint = statusAttentionTint;
  static const statusOffTint = statusCriticalTint;
  static const shadow = Color(0x1F0C2D32);
  static const shadowSoft = Color(0x120C2D32);
  static const onInkMuted = Color(0xB3FFFFFF);
  static const scrim = Color(0x730C2D32);
}
