import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'loading_button.dart';

/// Nút chính của các màn nhân viên: cao 56, có bóng mực nhạt bên dưới
/// như bản thiết kế. Bên trong là [LoadingButton] nên cũng chặn bấm hai lần.
class ForeButton extends StatelessWidget {
  const ForeButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.loadingLabel,
  });

  final String label;
  final String? loadingLabel;
  final bool loading;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppSizes.radius),
        boxShadow: const [
          BoxShadow(
            color: Color(0x400C2D32),
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: SizedBox(
        height: 56,
        child: LoadingButton(
          label: label,
          loadingLabel: loadingLabel,
          loading: loading,
          onPressed: onPressed,
        ),
      ),
    );
  }
}

/// Màu nền dùng chung cho thẻ trắng bo tròn của các màn nhân viên.
class ForeCard extends StatelessWidget {
  const ForeCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(24),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [
          BoxShadow(
            color: Color(0x140C2D32),
            blurRadius: 24,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}
