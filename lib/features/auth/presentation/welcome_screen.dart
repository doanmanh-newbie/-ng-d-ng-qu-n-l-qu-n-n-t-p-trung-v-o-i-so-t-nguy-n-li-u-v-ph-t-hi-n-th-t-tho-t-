import 'package:flutter/material.dart';

import '../../../app/app_routes.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/brand_logo.dart';
import 'forgot_password_dialog.dart';

/// Màn gốc khi chưa đăng nhập. Không có nút quay lại.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final navigator = Navigator.of(context);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.pagePadding),
          child: Column(
            children: [
              const SizedBox(height: 64),
              const BrandLogo(markSize: 64),
              const SizedBox(height: 16),
              const Text(
                'Bắt đầu ca làm việc tại quán.',
                textAlign: TextAlign.center,
                style: AppTextStyles.body,
              ),
              const Spacer(),
              FilledButton(
                onPressed: () => navigator.pushNamed(AppRoutes.login),
                child: const Text('Đăng nhập'),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => navigator.pushNamed(AppRoutes.register),
                child: const Text('Đăng ký'),
              ),
              const SizedBox(height: 4),
              TextButton(
                onPressed: () => showForgotPasswordDialog(context),
                child: const Text('Quên mật khẩu?'),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
