import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../auth/domain/auth_models.dart';
import '../auth/application/session_controller.dart';
import '../home/home_screen.dart';
import '../owner/owner_home_screen.dart';

/// Chọn giao diện theo vai trò thật trong hồ sơ quán; không dựa vào lựa chọn ở màn đăng nhập.
class RoleHomeScreen extends StatelessWidget {
  const RoleHomeScreen({super.key});

  static bool isOwnerRole(StaffRole role) => role == StaffRole.owner;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<SessionController>().state;
    if (state is SessionNoShop) {
      return const OpsHomeScreen();
    }
    if (state is! SessionSignedIn) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (isOwnerRole(state.profile.role)) {
      return OwnerHomeScreen(profile: state.profile);
    }
    return const OpsHomeScreen();
  }
}
