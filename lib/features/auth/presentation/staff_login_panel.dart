import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/loading_button.dart';
import '../application/staff_login_controller.dart';
import '../domain/staff_contact.dart';
import 'contact_kind_toggle.dart';

/// Đăng nhập của nhân viên: chọn số điện thoại hoặc email, nhập, bấm "Đăng nhập".
/// Không mật khẩu, không mã xác nhận. Chưa có tài khoản thì bấm "Tạo tài khoản".
/// Đăng nhập xong gọi `onSignedIn` để màn cha chuyển trang.
class StaffLoginPanel extends StatefulWidget {
  const StaffLoginPanel({super.key, required this.onSignedIn});

  final Future<void> Function() onSignedIn;

  @override
  State<StaffLoginPanel> createState() => _StaffLoginPanelState();
}

class _StaffLoginPanelState extends State<StaffLoginPanel> {
  final _contact = TextEditingController();

  @override
  void dispose() {
    _contact.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final ok = await context.read<StaffLoginController>().submit(_contact.text);
    if (ok) await widget.onSignedIn();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<StaffLoginController>();
    final phone = c.kind == ContactKind.phone;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ContactKindToggle(
          kind: c.kind,
          onChanged: c.setKind,
          enabled: !c.loading,
        ),
        const SizedBox(height: 16),
        AppTextField(
          label: phone ? 'Số điện thoại' : 'Email',
          controller: _contact,
          hint: phone ? '0901 234 567' : 'Địa chỉ email của bạn',
          errorText: c.contactError,
          enabled: !c.loading,
          keyboardType:
              phone ? TextInputType.phone : TextInputType.emailAddress,
          textInputAction: TextInputAction.done,
          autofillHints: [
            phone ? AutofillHints.telephoneNumber : AutofillHints.email,
          ],
          onSubmitted: _submit,
        ),
        const SizedBox(height: 8),
        const Text(
          'Đây là đăng nhập thử nghiệm, chưa an toàn để dùng thật: không có mật khẩu '
          'hay mã xác nhận; ai biết số/email đều có thể vào tài khoản.',
          style: AppTextStyles.caption,
        ),
        if (c.formError != null) ...[
          const SizedBox(height: 12),
          Text(
            c.formError!,
            style: const TextStyle(
                color: AppColors.statusOff, fontSize: AppFontSizes.s13),
          ),
        ],
        const SizedBox(height: 20),
        LoadingButton(
          label: 'Đăng nhập',
          loadingLabel: 'Đang đăng nhập',
          loading: c.loading,
          onPressed: _submit,
        ),
        const SizedBox(height: 14),
        OutlinedButton(
          onPressed: c.loading
              ? null
              : () => Navigator.of(context).pushNamed(AppRoutes.registerStaff),
          child: const Text('Tạo tài khoản nhân viên'),
        ),
      ],
    );
  }
}
