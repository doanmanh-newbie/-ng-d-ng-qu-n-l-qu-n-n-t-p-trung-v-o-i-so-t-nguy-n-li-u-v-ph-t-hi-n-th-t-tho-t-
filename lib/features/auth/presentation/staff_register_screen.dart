import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/app_routes.dart';
import '../../../core/errors/failure_messages.dart';
import '../../../core/format.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/loading_button.dart';
import '../application/session_controller.dart';
import '../application/staff_register_controller.dart';
import '../domain/staff_contact.dart';
import 'contact_kind_toggle.dart';

/// Tạo tài khoản nhân viên: số điện thoại hoặc email, tên hiển thị, ngày sinh.
/// Tạo xong là đăng nhập luôn và vào thẳng giao diện nhân viên (chưa có quán thì vào không gian
/// nhân viên, lời mời của chủ quán hiện trong hộp thư).
class StaffRegisterScreen extends StatefulWidget {
  const StaffRegisterScreen({super.key});

  @override
  State<StaffRegisterScreen> createState() => _StaffRegisterScreenState();
}

class _StaffRegisterScreenState extends State<StaffRegisterScreen> {
  final _contact = TextEditingController();
  final _name = TextEditingController();
  DateTime? _birthDate;

  /// Tài khoản đã tạo nhưng chưa tải được hồ sơ (mất mạng...): nút chính đổi thành "Thử lại".
  bool _needsRetry = false;
  String? _sessionError;

  @override
  void dispose() {
    _contact.dispose();
    _name.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_needsRetry) return _enterApp();
    final ok = await context.read<StaffRegisterController>().submit(
          contactText: _contact.text,
          fullName: _name.text,
          birthDate: _birthDate,
        );
    if (ok && mounted) await _enterApp();
  }

  /// Đã có phiên: tải hồ sơ rồi đi tới màn của nhân viên.
  Future<void> _enterApp() async {
    final navigator = Navigator.of(context);
    final session = context.read<SessionController>();
    session.ownerIntent = false;
    final failure = await session.refreshAfterSignIn();
    if (!mounted) return;
    if (failure != null) {
      setState(() {
        _needsRetry = true;
        _sessionError = 'Đã tạo tài khoản nhưng chưa vào được: '
            '${failure.userMessage}';
      });
      return;
    }
    final next = AppRoutes.routeFor(session.state);
    if (next != null) navigator.pushNamedAndRemoveUntil(next, (_) => false);
  }

  Future<void> _pickBirthDate() async {
    final today = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate:
          _birthDate ?? DateTime(today.year - 18, today.month, today.day),
      firstDate: DateTime(1900),
      lastDate: today,
      helpText: 'Chọn ngày sinh',
    );
    if (picked == null || !mounted) return;
    setState(() => _birthDate = picked);
    context.read<StaffRegisterController>().clearBirthDateError();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<StaffRegisterController>();
    final phone = c.kind == ContactKind.phone;
    final busy = c.loading;
    return Scaffold(
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSizes.pagePadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Tạo tài khoản nhân viên',
                  style: AppTextStyles.screenTitle),
              const SizedBox(height: 6),
              const Text(
                'Chỉ cần số điện thoại hoặc email. Chủ quán mời bạn bằng đúng số/email này, '
                'lời mời sẽ hiện trong hộp thư của bạn.',
                style: AppTextStyles.body,
              ),
              const SizedBox(height: 24),
              ContactKindToggle(
                kind: c.kind,
                onChanged: c.setKind,
                enabled: !busy,
              ),
              const SizedBox(height: 16),
              AppTextField(
                label: phone ? 'Số điện thoại' : 'Email',
                controller: _contact,
                hint: phone ? '0901 234 567' : 'Địa chỉ email của bạn',
                errorText: c.contactError,
                enabled: !busy,
                onChanged: (_) => c.clearContactError(),
                keyboardType:
                    phone ? TextInputType.phone : TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: [
                  phone ? AutofillHints.telephoneNumber : AutofillHints.email,
                ],
              ),
              const SizedBox(height: 16),
              AppTextField(
                label: 'Tên hiển thị',
                controller: _name,
                hint: 'Ví dụ: Lan',
                errorText: c.nameError,
                enabled: !busy,
                onChanged: (_) => c.clearNameError(),
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.name],
              ),
              const SizedBox(height: 16),
              const Text('Ngày sinh', style: AppTextStyles.label),
              const SizedBox(height: 6),
              OutlinedButton.icon(
                onPressed: busy ? null : _pickBirthDate,
                icon: const Icon(Icons.calendar_month_outlined),
                label: Text(_birthDate == null
                    ? 'Chọn ngày sinh'
                    : formatDmy(_birthDate!)),
              ),
              if (c.birthDateError != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    c.birthDateError!,
                    style: const TextStyle(
                        color: AppColors.statusOff, fontSize: 12),
                  ),
                ),
              if (c.formError != null || _sessionError != null) ...[
                const SizedBox(height: 12),
                Text(
                  c.formError ?? _sessionError!,
                  style: const TextStyle(
                      color: AppColors.statusOff, fontSize: 13),
                ),
              ],
              const SizedBox(height: 24),
              LoadingButton(
                label: _needsRetry ? 'Thử lại' : 'Tạo tài khoản',
                loadingLabel: 'Đang tạo tài khoản',
                loading: busy,
                onPressed: _submit,
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: busy ? null : () => Navigator.of(context).pop(),
                child: const Text('Đã có tài khoản? Đăng nhập'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
