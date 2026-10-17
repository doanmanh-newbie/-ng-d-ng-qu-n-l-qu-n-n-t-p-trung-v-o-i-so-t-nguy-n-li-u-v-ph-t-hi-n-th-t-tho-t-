import 'package:flutter/material.dart';

/// TODO (tuần 1): nhập PIN, gọi Supabase kiểm tra phía server.
/// Không lưu PIN thô; không đặt service_role key trong app.
class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: Text('Fore - Đăng nhập (đang làm)')),
    );
  }
}
