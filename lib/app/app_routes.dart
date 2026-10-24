import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../features/auth/application/login_controller.dart';
import '../features/auth/application/register_controller.dart';
import '../features/auth/domain/auth_repository.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/auth/presentation/not_linked_screen.dart';
import '../features/auth/presentation/register_screen.dart';
import '../features/auth/presentation/splash_screen.dart';
import '../features/auth/presentation/welcome_screen.dart';
import '../features/home/home_screen.dart';

/// Tên các màn hình. Đi tới màn nào thì dùng hằng ở đây, không gõ chuỗi rời.
abstract final class AppRoutes {
  static const splash = '/';
  static const welcome = '/welcome';
  static const login = '/login';
  static const register = '/register';
  static const home = '/home';
  static const notLinked = '/not-linked';

  static Route<dynamic> generate(RouteSettings settings) {
    final Widget page = switch (settings.name) {
      splash => const SplashScreen(),
      welcome => const WelcomeScreen(),
      login => ChangeNotifierProvider(
          create: (ctx) => LoginController(ctx.read<AuthRepository>()),
          child: const LoginScreen(),
        ),
      register => ChangeNotifierProvider(
          create: (ctx) => RegisterController(ctx.read<AuthRepository>()),
          child: const RegisterScreen(),
        ),
      home => const HomeScreen(),
      notLinked => const NotLinkedScreen(),
      _ => const SplashScreen(),
    };

    // Welcome mở chậm hơn một chút để logo kịp bay từ Splash sang.
    final duration = settings.name == welcome
        ? const Duration(milliseconds: 500)
        : const Duration(milliseconds: 250);

    return PageRouteBuilder<void>(
      settings: settings,
      transitionDuration: duration,
      reverseTransitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (_, __, ___) => page,
      transitionsBuilder: (_, animation, __, child) => FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
        child: child,
      ),
    );
  }
}
