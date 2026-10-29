import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/app_routes.dart';
import '../../../core/errors/failure_messages.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_theme.dart';
import '../application/session_controller.dart';

/// Đăng nhập được nhưng chủ quán chưa thêm email này vào quán.
class NotLinkedScreen extends StatelessWidget {
  const NotLinkedScreen({super.key});

  Future<void> _recheck(BuildContext context) async {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final session = context.read<SessionController>();
    final failure = await session.refreshAfterSignIn();
    if (failure != null) {
      messenger.showSnackBar(SnackBar(content: Text(failure.userMessage)));
      return;
    }
    if (session.state is SessionSignedIn) {
      navigator.pushNamedAndRemoveUntil(AppRoutes.home, (_) => false);
    }
  }

  Future<void> _signOut(BuildContext context) async {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final failure = await context.read<SessionController>().signOut();
    if (failure != null) {
      messenger.showSnackBar(SnackBar(content: Text(failure.userMessage)));
      return;
    }
    navigator.pushNamedAndRemoveUntil(AppRoutes.welcome, (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<SessionController>().state;
    final contact = state is SessionNoShop ? state.contact : '';
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.pagePadding),
          child: Column(
            children: [
              const Spacer(),
              const Text(
                'Chưa được thêm vào quán',
                textAlign: TextAlign.center,
                style: AppTextStyles.screenTitle,
              ),
              const SizedBox(height: 8),
              Text(
                'Tài khoản $contact chưa thuộc quán nào. Gửi thông tin này cho '
                'chủ quán để được thêm vào, rồi bấm Kiểm tra lại.',
                textAlign: TextAlign.center,
                style: AppTextStyles.body,
              ),
              const Spacer(),
              FilledButton(
                onPressed: () => _recheck(context),
                child: const Text('Kiểm tra lại'),
              ),
              const SizedBox(height: 4),
              TextButton(
                onPressed: () => _signOut(context),
                child: const Text('Đăng xuất'),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
