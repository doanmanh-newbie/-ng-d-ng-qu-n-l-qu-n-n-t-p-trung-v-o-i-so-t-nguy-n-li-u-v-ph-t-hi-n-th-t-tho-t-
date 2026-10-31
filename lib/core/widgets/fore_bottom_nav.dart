import 'package:flutter/material.dart';

import '../motion.dart';
import '../theme/app_colors.dart';
import 'ops_icon.dart';
import 'package:fore/core/design/typography.dart';

class NavItem {
  const NavItem({required this.label, required this.icon, this.enabled = true});

  final String label;
  final String icon;

  /// Tab bị vô hiệu (vd cần có ca đang mở): hiện mờ và không chạm được.
  final bool enabled;
}

/// Thanh điều hướng dưới: tab đang chọn là một "viên thuốc" tối nổi lên khỏi thanh,
/// trượt mượt khi đổi tab. Khớp bản thiết kế "Home / No-shift".
class ForeBottomNav extends StatelessWidget {
  const ForeBottomNav({
    super.key,
    required this.items,
    required this.selected,
    required this.onSelect,
  });

  final List<NavItem> items;
  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          boxShadow: [
            BoxShadow(
              color: AppColors.shadowSoft,
              blurRadius: 20,
              offset: Offset(0, -6),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 72,
            child: Row(
              children: [
                for (var i = 0; i < items.length; i++)
                  Expanded(
                    child: _NavButton(
                      item: items[i],
                      selected: i == selected,
                      onTap: items[i].enabled ? () => onSelect(i) : null,
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final NavItem item;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final Color color = selected
        ? Colors.white
        : item.enabled
            ? AppColors.ink
            : AppColors.textMuted;
    return Semantics(
      button: true,
      selected: selected,
      enabled: item.enabled,
      label: item.label,
      child: ExcludeSemantics(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Center(
            child: AnimatedContainer(
              duration: Motion.of(context, const Duration(milliseconds: 280)),
              curve: Curves.easeOutCubic,
              width: selected ? 82 : 64,
              height: selected ? 64 : 52,
              transform: Matrix4.translationValues(0, selected ? -12 : 0, 0),
              decoration: BoxDecoration(
                color: selected ? AppColors.ink : Colors.transparent,
                borderRadius: BorderRadius.circular(selected ? 20 : 14),
                boxShadow: selected
                    ? const [
                        BoxShadow(
                          color: AppColors.shadow,
                          blurRadius: 14,
                          offset: Offset(0, 6),
                        ),
                      ]
                    : const [],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ForeIcon(item.icon, size: 22, color: color),
                  const SizedBox(height: 3),
                  Text(
                    item.label,
                    maxLines: 1,
                    overflow: TextOverflow.clip,
                    style: TextStyle(
                      fontSize: AppFontSizes.s12,
                      fontWeight: selected || item.enabled
                          ? FontWeight.w700
                          : FontWeight.w500,
                      color: color,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
