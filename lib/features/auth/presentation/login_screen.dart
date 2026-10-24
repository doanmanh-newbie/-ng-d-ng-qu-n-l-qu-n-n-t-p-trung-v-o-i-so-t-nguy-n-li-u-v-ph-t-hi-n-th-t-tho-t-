import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/loading_button.dart';
import '../application/login_controller.dart';
import '../application/session_controller.dart';
import 'forgot_password_dialog.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final navigator = Navigator.of(context);
    final session = context.read<SessionController>();
    final ok = await context
        .read<LoginController>()
        .submit(email: _email.text, password: _password.text);
    if (!ok) return;

    await session.refreshAfterSignIn();
    final next = switch (session.state) {
      SessionSignedIn() => AppRoutes.home,
      SessionNotLinked() => AppRoutes.notLinked,
      _ => null, // mất mạng giữa chừng: ở lại để người dùng thử lại
    };
    if (next != null) {
      navigator.pushNamedAndRemoveUntil(next, (_) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<LoginController>();
    return Scaffold(
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSizes.pagePadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Đăng nhập', style: AppTextStyles.screenTitle),
              const SizedBox(height: 6),
              const Text(
                'Dùng email bạn đã gửi cho chủ quán.',
                style: AppTextStyles.body,
              ),
              const SizedBox(height: 24),
              AppTextField(
                label: 'Email',
                controller: _email,
                hint: 'Địa chỉ email cá nhân',
                errorText: c.emailError,
                enabled: !c.loading,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.email],
              ),
              const SizedBox(height: 16),
              AppTextField(
                label: 'Mật khẩu',
                controller: _password,
                hint: 'Mật khẩu của bạn',
                errorText: c.passwordError,
                enabled: !c.loading,
                obscure: true,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.password],
                onSubmitted: _submit,
              ),
              if (c.formError != null) ...[
                const SizedBox(height: 12),
                Text(
                  c.formError!,
                  style: const TextStyle(
                    color: AppColors.statusOff,
                    fontSize: 13,
                  ),
                ),
              ],
              const SizedBox(height: 24),
              LoadingButton(
                label: 'Đăng nhập',
                loadingLabel: 'Đang đăng nhập',
                loading: c.loading,
                onPressed: _submit,
              ),
              Center(
                child: TextButton(
                  onPressed: () => showForgotPasswordDialog(context),
                  child: const Text('Quên mật khẩu?'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
