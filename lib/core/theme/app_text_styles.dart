import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Kiểu chữ dùng chung. Tiêu đề và wordmark dùng chữ có chân như bản thiết kế.
/// Khi chốt font chính thức: thêm font vào `assets/fonts` và đổi `fontFamily` ở đây.
abstract final class AppTextStyles {
  static const _serif = 'serif';

  static const wordmark = TextStyle(
    fontFamily: _serif,
    fontSize: 32,
    fontWeight: FontWeight.w700,
    color: AppColors.brand,
    height: 1.1,
  );

  static const screenTitle = TextStyle(
    fontFamily: _serif,
    fontSize: 26,
    fontWeight: FontWeight.w700,
    color: AppColors.brand,
    height: 1.2,
  );

  static const body = TextStyle(
    fontSize: 15,
    color: AppColors.textSecondary,
    height: 1.4,
  );

  static const label = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  static const caption = TextStyle(
    fontSize: 12,
    color: AppColors.textSecondary,
  );
}
