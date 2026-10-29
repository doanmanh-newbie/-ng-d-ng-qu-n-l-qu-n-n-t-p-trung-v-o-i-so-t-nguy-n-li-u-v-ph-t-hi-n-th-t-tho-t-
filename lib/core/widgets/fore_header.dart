import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'brand_logo.dart';

/// Đầu trang chung của mọi màn trong ca: tên quán, "Nhân viên · tên", logo và (tùy chọn) nhãn trạng thái ca.
class ForeHeader extends StatelessWidget {
  const ForeHeader({
    super.key,
    required this.shopName,
    required this.subtitle,
    this.pill,
    this.onBack,
  });

  final String shopName;
  final String subtitle;
  final Widget? pill;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          boxShadow: [
            BoxShadow(
              color: AppColors.shadowSoft,
              blurRadius: 18,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            shopName,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: AppColors.brand,
                              height: 1.2,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            subtitle,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (onBack != null) ...[
                      IconButton(
                        tooltip: 'Về màn quản lý',
                        onPressed: onBack,
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Icons.arrow_back_rounded),
                      ),
                      const SizedBox(width: 4),
                    ],
                    const _LogoBadge(),
                  ],
                ),
                if (pill != null) ...[
                  const SizedBox(height: 12),
                  pill!,
                ],
              ],
            ),
          ),
        ),
      );
}

class _LogoBadge extends StatelessWidget {
  const _LogoBadge();

  @override
  Widget build(BuildContext context) => const DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.surface,
          boxShadow: [
            BoxShadow(
              color: AppColors.shadow,
              blurRadius: 16,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: Padding(
          padding: EdgeInsets.all(9),
          child: BrandMark(size: 34),
        ),
      );
}

/// Nhãn nhỏ có chấm màu: "Chưa mở ca" / "Ca của An, mở lúc 8:02".
class ShiftPill extends StatelessWidget {
  const ShiftPill({super.key, required this.label, required this.active});

  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) => Semantics(
        label: label,
        child: ExcludeSemantics(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: active ? AppColors.statusOkTint : AppColors.surfaceTint,
              borderRadius: BorderRadius.circular(999),
              boxShadow: const [
                BoxShadow(
                  color: AppColors.shadowSoft,
                  blurRadius: 10,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: active ? AppColors.statusOk : AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.ink,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}
