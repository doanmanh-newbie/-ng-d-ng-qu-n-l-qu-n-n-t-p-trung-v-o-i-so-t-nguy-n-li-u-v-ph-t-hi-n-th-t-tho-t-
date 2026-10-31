import 'package:flutter/material.dart';

import 'spacing.dart';
import 'typography.dart';

class PageTitleBlock extends StatelessWidget {
  const PageTitleBlock({
    super.key,
    required this.title,
    this.today,
    this.updatedAt,
    this.businessDay,
  });

  final String title;
  final String? today;
  final String? updatedAt;
  final String? businessDay;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: AppSizes.cardGap),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(child: Text(title, style: AppTextStyles.pageTitle)),
                if (today != null)
                  Text(today!, style: AppTextStyles.captionStrong),
              ],
            ),
            if (updatedAt != null || businessDay != null) ...[
              const SizedBox(height: 2),
              Text(
                [
                  if (updatedAt != null) updatedAt!,
                  if (businessDay != null) businessDay!
                ].join(' · '),
                style: AppTextStyles.caption,
              ),
            ],
          ],
        ),
      );
}
