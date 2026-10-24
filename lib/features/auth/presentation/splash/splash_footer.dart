import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import 'splash_strings.dart';

/// Dòng nhỏ cuối màn hình.
///
/// Lưu ý nội dung: hai dòng chữ này là lời cam kết với người dùng. Chỉ giữ khi
/// app thật sự làm được (phiên đăng nhập an toàn, đồng bộ dữ liệu). Sửa ở `SplashStrings`.
class SplashFooter extends StatelessWidget {
  const SplashFooter({super.key});

  static const _style = TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.8,
    color: AppColors.textSecondary,
  );

  @override
  Widget build(BuildContext context) => const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Flexible(
            child: Text(
              SplashStrings.footerLeft,
              style: _style,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          SizedBox(width: 10),
          DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.brandAccent,
            ),
            child: SizedBox.square(dimension: 4),
          ),
          SizedBox(width: 10),
          Flexible(
            child: Text(
              SplashStrings.footerRight,
              style: _style,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      );
}
