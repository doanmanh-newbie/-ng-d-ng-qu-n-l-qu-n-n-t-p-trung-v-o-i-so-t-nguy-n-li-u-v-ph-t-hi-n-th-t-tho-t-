import 'package:flutter/material.dart';

/// Token màu. Giá trị lấy xấp xỉ từ ảnh Figma; khi có mã hex chính thức
/// của bạn thiết kế thì chỉ cần sửa ở đây, mọi màn hình tự đổi theo.
abstract final class AppColors {
  static const brand = Color(0xFF0F3B3B); // teal đậm: nút chính, chữ tiêu đề
  static const brandAccent = Color(0xFF3F9E92); // teal sáng: logo, điểm nhấn
  static const background = Color(0xFFF1F6F4);
  static const surface = Color(0xFFFFFFFF);
  static const border = Color(0xFFCBD8D4);
  static const textPrimary = Color(0xFF14292A);
  static const textSecondary = Color(0xFF4F6663); // đủ tương phản trên nền nhạt
  static const disabledFill = Color(0xFFE3EAE7);

  // Màu trạng thái: chỉ dùng cho trạng thái, không dùng làm trang trí.
  static const statusOk = Color(0xFF1F9D63);
  static const statusWatch = Color(0xFFE0A100);
  static const statusOff = Color(0xFFD8433A);
}
