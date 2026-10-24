import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme/app_theme.dart';
import '../features/auth/application/session_controller.dart';
import '../features/auth/domain/auth_repository.dart';
import '../features/auth/presentation/splash_screen.dart';
import 'app_routes.dart';

/// Gốc của app. Nhận [AuthRepository] từ ngoài vào (dependency injection):
/// `main.dart` truyền bản Supabase, test truyền bản giả.
class ForeApp extends StatelessWidget {
  const ForeApp({super.key, required this.authRepository});

  final AuthRepository authRepository;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<AuthRepository>.value(value: authRepository),
        ChangeNotifierProvider<SessionController>(
          create: (_) => SessionController(
            authRepository,
            minVisible: const Duration(seconds: 5),
          ),
        ),
      ],
      child: MaterialApp(
        title: 'Fore',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        initialRoute: AppRoutes.splash,
        onGenerateRoute: AppRoutes.generate,
      ),
    );
  }
}
