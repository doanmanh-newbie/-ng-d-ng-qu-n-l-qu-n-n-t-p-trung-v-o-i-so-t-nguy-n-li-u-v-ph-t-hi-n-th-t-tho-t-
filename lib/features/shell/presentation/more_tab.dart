import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/app_routes.dart';
import '../../../core/errors/failure_messages.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/fore_button.dart';
import '../../auth/application/session_controller.dart';
import '../../shift/application/shift_controller.dart';
import '../../shop/application/inbox_controller.dart';
import '../../shop/presentation/shop_switcher.dart';

/// Tab Thêm: quán đang làm (đổi quán), hộp thư, nhân viên (chủ quán), đăng xuất.
class MoreTab extends StatelessWidget {
  const MoreTab({super.key});

  Future<void> _signOut(BuildContext context) async {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final shift = context.read<ShiftController>();
    final failure = await context.read<SessionController>().signOut();
    if (failure != null) {
      messenger.showSnackBar(SnackBar(content: Text(failure.userMessage)));
      return;
    }
    shift.reset();
    navigator.pushNamedAndRemoveUntil(AppRoutes.welcome, (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<SessionController>().state;
    final signedIn = state is SessionSignedIn ? state : null;
    final name = signedIn?.profile.fullName ?? '';
    final shopName = signedIn?.profile.shopName ?? '';
    final isOwner = signedIn?.profile.role.isOwner ?? false;
    final invites = context.watch<InboxController>().invites.length;

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(AppSizes.pagePadding),
        children: [
          const SizedBox(height: 24),
          const Text('Thêm', style: AppTextStyles.display),
          const SizedBox(height: 20),
          ForeCard(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                DecoratedBox(
                  decoration: const BoxDecoration(
                    color: AppColors.tint,
                    shape: BoxShape.circle,
                  ),
                  child: SizedBox.square(
                    dimension: 48,
                    child: Center(
                      child: Text(
                        name.isEmpty ? '?' : String.fromCharCode(name.runes.first),
                        style: AppTextStyles.heading,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: AppTextStyles.label.copyWith(fontSize: 16)),
                      const SizedBox(height: 2),
                      Text(isOwner ? 'Chủ quán' : 'Nhân viên',
                          style: AppTextStyles.caption),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _Row(
            icon: Icons.storefront_outlined,
            title: shopName.isEmpty ? 'Quán' : shopName,
            subtitle: 'Đổi quán hoặc tạo quán mới',
            onTap: () => showShopSwitcher(context),
          ),
          _Row(
            icon: Icons.mail_outline_rounded,
            title: 'Hộp thư',
            subtitle: invites > 0
                ? '$invites lời mời đang chờ bạn'
                : 'Lời mời vào quán',
            badge: invites,
            onTap: () async {
              final inbox = context.read<InboxController>();
              await Navigator.of(context).pushNamed(AppRoutes.inbox);
              inbox.load(quiet: true);
            },
          ),
          if (isOwner)
            _Row(
              icon: Icons.groups_outlined,
              title: 'Nhân viên',
              subtitle: 'Thêm nhân viên bằng số điện thoại',
              onTap: () => Navigator.of(context).pushNamed(AppRoutes.team),
            ),
          const SizedBox(height: 24),
          OutlinedButton(
            onPressed: () => _signOut(context),
            child: const Text('Đăng xuất'),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.badge = 0,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final int badge;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSizes.radius),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppSizes.radius),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Icon(icon, color: AppColors.brand),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.label.copyWith(fontSize: 15)),
                      Text(subtitle, style: AppTextStyles.caption),
                    ],
                  ),
                ),
                if (badge > 0)
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: AppColors.statusOff,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      child: Text('$badge',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w700)),
                    ),
                  )
                else
                  const Icon(Icons.chevron_right, color: AppColors.inkMuted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
