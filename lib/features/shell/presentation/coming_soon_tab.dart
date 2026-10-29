import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/fore_icon.dart';

/// Tab chưa có chức năng. Nói thẳng là đang làm, không giả vờ có.
class ComingSoonTab extends StatelessWidget {
  const ComingSoonTab({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
  });

  final ForeIcon icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DecoratedBox(
                decoration: const BoxDecoration(
                  color: AppColors.tint,
                  shape: BoxShape.circle,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(22),
                  child: ForeIconView(
                    icon,
                    size: 30,
                    color: AppColors.brand,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(title, style: AppTextStyles.heading),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: AppTextStyles.body,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
