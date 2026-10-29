import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/fore_icon.dart';
import '../../shift/application/shift_controller.dart';
import 'coming_soon_tab.dart';

/// Đóng ca: màn đếm kho và nhập tiền cuối ca làm ở bước sau.
/// Trước mắt cho nhân viên biết điều kiện: hết bill đang mở mới đóng được ca.
class CloseShiftTab extends StatelessWidget {
  const CloseShiftTab({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<ShiftController>().state;
    final bills = state is ShiftOpen ? state.shift.openBills : 0;
    return Stack(
      children: [
        const ComingSoonTab(
          icon: ForeIcon.lock,
          title: 'Đóng ca',
          message: 'Đếm kho và nhập tiền cuối ca đang được làm ở bước sau.',
        ),
        if (bills > 0)
          SafeArea(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: Text(
                  'Còn $bills bill đang mở. Thanh toán hoặc hủy hết '
                  'rồi mới đóng ca được.',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.caption,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
