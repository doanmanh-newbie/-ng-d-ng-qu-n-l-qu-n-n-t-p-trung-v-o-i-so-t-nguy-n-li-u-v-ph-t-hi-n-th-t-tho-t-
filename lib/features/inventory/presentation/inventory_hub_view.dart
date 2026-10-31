import 'package:flutter/material.dart';

import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/fore_card.dart';
import '../../../core/widgets/ops_icon.dart';
import '../../../core/widgets/page_scaffold.dart';
import '../../ops/shift/application/shift_controller.dart';
import '../../stocktake/domain/stocktake_models.dart';

/// Tab "Kho": nhập hàng và kiểm kê. Không hiện số tồn hay lịch sử nhập (chỉ chủ xem).
class InventoryHubView extends StatelessWidget {
  const InventoryHubView({
    super.key,
    required this.shift,
    required this.onPurchase,
    required this.onCount,
  });

  final OpsShiftController shift;
  final VoidCallback onPurchase;
  final void Function(CountKind kind) onCount;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: shift,
        builder: (context, _) {
          final missing = shift.closeStatus?.missingCounts ?? 0;
          return PageScaffold(
            children: [
              const Text('Kho', style: AppTextStyles.display),
              const SizedBox(height: 6),
              const Text(
                'Ghi nguyên liệu nhập về và đếm kho đầu ca, cuối ca.',
                style: TextStyle(
                    fontSize: 15, color: AppColors.textPrimary, height: 1.4),
              ),
              const SizedBox(height: 20),
              ActionTile(
                icon: const ForeIcon(ForeIcons.package, color: AppColors.ink),
                title: 'Nhập hàng',
                subtitle: 'Ghi nguyên liệu vừa nhập về trong ca',
                onTap: onPurchase,
              ),
              const SizedBox(height: 12),
              ActionTile(
                icon: const ForeIcon(ForeIcons.calendar, color: AppColors.ink),
                title: 'Kiểm kê đầu ca',
                subtitle: 'Đếm nguyên liệu trước khi bán',
                onTap: () => onCount(CountKind.open),
              ),
              const SizedBox(height: 12),
              ActionTile(
                icon: const ForeIcon(ForeIcons.lock, color: AppColors.ink),
                title: 'Kiểm kê cuối ca',
                subtitle: 'Đếm đủ rồi mới đóng ca được',
                badge: missing > 0 ? 'Còn $missing' : null,
                onTap: () => onCount(CountKind.close),
              ),
            ],
          );
        },
      );
}
