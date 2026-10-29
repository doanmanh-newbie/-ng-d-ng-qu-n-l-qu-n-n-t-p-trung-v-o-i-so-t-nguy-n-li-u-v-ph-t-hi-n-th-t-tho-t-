import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/motion.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/fore_icon.dart';
import '../../../core/widgets/shake.dart';

/// Năm tab của nhân viên, theo thứ tự từ trái sang phải.
enum ShellTab {
  takeaway('Mang đi', ForeIcon.bag, requiresShift: true),
  stock('Kho', ForeIcon.package, requiresShift: true),
  home('Trang chủ', ForeIcon.home, requiresShift: false),
  closeShift('Đóng ca', ForeIcon.lock, requiresShift: true),
  more('Thêm', ForeIcon.plus, requiresShift: false);

  const ShellTab(this.label, this.icon, {required this.requiresShift});

  final String label;
  final ForeIcon icon;

  /// `true`: chỉ dùng được khi quán đang có ca mở.
  final bool requiresShift;
}

/// Thanh tab dưới cùng.
///
/// - Tab đang chọn nổi lên thành một khối mực đậm (như bản thiết kế).
/// - Chưa có ca: Mang đi, Kho, Đóng ca mờ đi. Bấm vào thì tab lắc nhẹ và rung
///   máy một nhịp thay vì im lặng.
/// - Vừa mở ca: ba tab đó "thức dậy" lần lượt, mỗi tab nảy lên một lần.
class ForeBottomNav extends StatelessWidget {
  const ForeBottomNav({
    super.key,
    required this.current,
    required this.shiftOpen,
    required this.onSelect,
    required this.onLockedTap,
    this.shakeTab,
    this.shakeTick = 0,
  });

  final ShellTab current;
  final bool shiftOpen;
  final ValueChanged<ShellTab> onSelect;
  final ValueChanged<ShellTab> onLockedTap;

  /// Tab đang cần lắc, và số lần đã lắc (tăng lên để lắc lại).
  final ShellTab? shakeTab;
  final int shakeTick;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    var wake = 0;
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        boxShadow: [
          BoxShadow(
            color: Color(0x140C2D32),
            blurRadius: 20,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(8, 10, 8, 8 + bottom),
        child: SizedBox(
          height: 56,
          child: Row(
            children: [
              for (final tab in ShellTab.values)
                Expanded(
                  child: _NavItem(
                    key: ValueKey(tab),
                    tab: tab,
                    selected: tab == current,
                    enabled: !tab.requiresShift || shiftOpen,
                    // Chờ màn mở ca đóng xong rồi mới nảy, từng tab một.
                    wakeDelay: tab.requiresShift
                        ? Duration(milliseconds: 280 + 110 * wake++)
                        : Duration.zero,
                    shakeTick: tab == shakeTab ? shakeTick : 0,
                    onTap: () {
                      final enabled = !tab.requiresShift || shiftOpen;
                      if (enabled) {
                        HapticFeedback.selectionClick();
                        onSelect(tab);
                      } else {
                        HapticFeedback.lightImpact();
                        onLockedTap(tab);
                      }
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatefulWidget {
  const _NavItem({
    super.key,
    required this.tab,
    required this.selected,
    required this.enabled,
    required this.wakeDelay,
    required this.shakeTick,
    required this.onTap,
  });

  final ShellTab tab;
  final bool selected;
  final bool enabled;
  final Duration wakeDelay;
  final int shakeTick;
  final VoidCallback onTap;

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem>
    with SingleTickerProviderStateMixin {
  late final AnimationController _bounce = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 520),
  );
  Timer? _wakeTimer;

  @override
  void didUpdateWidget(_NavItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Vừa được mở khóa (mở ca xong): nảy lên một lần, tab sau trễ hơn tab trước.
    if (!oldWidget.enabled && widget.enabled && !Motion.reduced(context)) {
      _wakeTimer?.cancel();
      _wakeTimer = Timer(widget.wakeDelay, () {
        if (mounted) _bounce.forward(from: 0);
      });
    }
  }

  @override
  void dispose() {
    _wakeTimer?.cancel();
    _bounce.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selected = widget.selected;
    final Color color = selected
        ? Colors.white
        : widget.enabled
            ? AppColors.brand
            : AppColors.inkMuted;
    final duration = Motion.of(context, const Duration(milliseconds: 260));

    return Semantics(
      button: true,
      selected: selected,
      enabled: widget.enabled,
      label: widget.enabled
          ? widget.tab.label
          : '${widget.tab.label}, cần mở ca trước',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: Shake(
          trigger: widget.shakeTick,
          child: AnimatedBuilder(
            animation: _bounce,
            builder: (context, child) => Transform.scale(
              scale: 1 + 0.28 * _bump(_bounce.value),
              child: child,
            ),
            child: AnimatedSlide(
              duration: duration,
              curve: Curves.easeOutBack,
              offset: selected ? const Offset(0, -0.14) : Offset.zero,
              child: AnimatedContainer(
                duration: duration,
                curve: Curves.easeOutCubic,
                decoration: BoxDecoration(
                  color: selected ? AppColors.brand : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: selected
                      ? const [
                          BoxShadow(
                            color: Color(0x590C2D32),
                            blurRadius: 14,
                            offset: Offset(0, 6),
                          ),
                        ]
                      : const [],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ForeIconView(widget.tab.icon, size: 22, color: color),
                    const SizedBox(height: 4),
                    Text(
                      widget.tab.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: color,
                        height: 1.1,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Đường cong nảy lên rồi về: 0 -> 1 -> 0.
  static double _bump(double t) => t < 0.35
      ? Curves.easeOut.transform(t / 0.35)
      : 1 - Curves.elasticOut.transform((t - 0.35) / 0.65).clamp(0.0, 1.0);
}
