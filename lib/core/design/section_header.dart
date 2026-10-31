import 'package:flutter/material.dart';

import 'typography.dart';

class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.trailing,
    this.onTap,
  });

  final String title;
  final String? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Expanded(child: Text(title, style: AppTextStyles.sectionTitle)),
          if (trailing != null)
            TextButton(
              onPressed: onTap,
              child: Text(trailing!, style: AppTextStyles.captionStrong),
            ),
        ],
      );
}
