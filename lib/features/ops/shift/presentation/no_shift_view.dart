import 'package:flutter/material.dart';

import '../../../../core/errors/app_failure.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/fore_card.dart';
import '../../../../core/widgets/ops_icon.dart';
import '../../../../core/widgets/money_field.dart';
import '../../../../core/widgets/fore_sheet.dart';
import '../../../../core/widgets/notify.dart';
import '../../../../core/format.dart';
import '../application/shift_controller.dart';

/// Màn "Chưa mở ca" (thiết kế "Home / No-shift"): thẻ giữa màn kèm nút Mở ca.
/// Bấm Mở ca thì hỏi số tiền có trong két lúc bắt đầu.
class NoShiftView extends StatelessWidget {
  const NoShiftView({super.key, required this.shift});

  final OpsShiftController shift;

  @override
  Widget build(BuildContext context) => RefreshIndicator(
        onRefresh: shift.load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
          children: [
            ForeCard(
              padding: const EdgeInsets.fromLTRB(24, 36, 24, 24),
              child: Column(
                children: [
                  const ForeIcon(ForeIcons.calendar,
                      size: 34, color: AppColors.ink),
                  const SizedBox(height: 28),
                  const Text(
                    'Chưa có ca đang mở',
                    style: AppTextStyles.headline,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Mở ca để nhận order và dùng các chức năng bán hàng.',
                    style: TextStyle(
                        fontSize: 16,
                        color: AppColors.textPrimary,
                        height: 1.4),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 56),
                  FilledButton(
                    onPressed:
                        shift.busy ? null : () => _askOpeningCash(context),
                    child: const Text('Mở ca'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Bàn, Mang đi và Kho dùng được sau khi mở ca.',
              style: TextStyle(fontSize: 14, color: AppColors.textPrimary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );

  Future<void> _askOpeningCash(BuildContext context) async {
    final cash = await showForeSheet<int>(
      context,
      title: 'Mở ca',
      subtitle: 'Nhập số tiền có trong két lúc bắt đầu ca.',
      builder: (_) => const _OpeningCashForm(),
    );
    if (cash == null || !context.mounted) return;
    try {
      final opened = await shift.openShift(cash);
      if (opened && context.mounted)
        showNotice(context, 'Đã mở ca. Chúc ca làm việc thuận lợi!');
    } on AppFailure catch (f) {
      if (context.mounted) showFailure(context, f);
    }
  }
}

class _OpeningCashForm extends StatefulWidget {
  const _OpeningCashForm();

  @override
  State<_OpeningCashForm> createState() => _OpeningCashFormState();
}

class _OpeningCashFormState extends State<_OpeningCashForm> {
  final _controller = TextEditingController();
  int? _value;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MoneyField(
            controller: _controller,
            label: 'Tiền đầu ca',
            large: true,
            autofocus: true,
            helper:
                _value == null ? 'Nhập 0 nếu két trống.' : formatVnd(_value!),
            onChanged: (v) => setState(() => _value = v),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed:
                _value == null ? null : () => Navigator.of(context).pop(_value),
            child: const Text('Mở ca'),
          ),
        ],
      );
}
