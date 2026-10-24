import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/app_routes.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_theme.dart';
import '../auth/application/session_controller.dart';

/// Tạm thời: chỉ chào và cho đăng xuất. Làm theo thiết kế Home ở bước sau.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<SessionController>().state;
    final name = state is SessionSignedIn ? state.profile.fullName : '';
    final role = state is SessionSignedIn
        ? (state.profile.role.isOwner ? 'Chủ quán' : 'Nhân viên')
        : '';
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.pagePadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 48),
              Text('Xin chào, $name', style: AppTextStyles.screenTitle),
              const SizedBox(height: 6),
              Text(role, style: AppTextStyles.body),
              const Spacer(),
              OutlinedButton(
                onPressed: () async {
                  final navigator = Navigator.of(context);
                  await context.read<SessionController>().signOut();
                  navigator.pushNamedAndRemoveUntil(
                    AppRoutes.welcome,
                    (_) => false,
                  );
                },
                child: const Text('Đăng xuất'),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
