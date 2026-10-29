import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../theme/app_theme.dart';
import 'pressable_scale.dart';

/// Thẻ trắng bo góc có bóng nhẹ: khối nội dung chuẩn của app.
class ForeCard extends StatelessWidget {
  const ForeCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.radius = AppSizes.radiusCard,
    this.color = AppColors.surface,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => PressableScale(
        onTap: onTap,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(radius),
            boxShadow: const [
              BoxShadow(
                color: AppColors.shadowSoft,
                blurRadius: 18,
                offset: Offset(0, 5),
              ),
            ],
          ),
          child: Padding(padding: padding, child: child),
        ),
      );
}

/// Một dòng hành động: icon, tiêu đề, mô tả, mũi tên. Dùng ở tab Kho và Thêm.
class ActionTile extends StatelessWidget {
  const ActionTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.badge,
  });

  final Widget icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  /// Nhãn nhỏ bên phải (vd "Còn 3").
  final String? badge;

  @override
  Widget build(BuildContext context) => ForeCard(
        onTap: onTap,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        radius: AppSizes.radiusTile,
        child: Row(
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.surfaceTint,
                borderRadius: BorderRadius.circular(14),
              ),
              child:
                  SizedBox(width: 48, height: 48, child: Center(child: icon)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTextStyles.title),
                  const SizedBox(height: 2),
                  Text(subtitle, style: AppTextStyles.caption),
                ],
              ),
            ),
            if (badge != null) ...[
              DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.statusWatchTint,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  child: Text(
                    badge!,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.statusWatch,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],
            const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
          ],
        ),
      );
}

/// Tiêu đề phần kèm dòng phụ nhỏ bên phải: "Tầng 1" ... "6 bàn · 2 đang dùng".
class SectionHeader extends StatelessWidget {
  const SectionHeader({super.key, required this.title, this.trailing});

  final String title;
  final String? trailing;

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Expanded(child: Text(title, style: AppTextStyles.headline)),
          if (trailing != null) Text(trailing!, style: AppTextStyles.caption),
        ],
      );
}
