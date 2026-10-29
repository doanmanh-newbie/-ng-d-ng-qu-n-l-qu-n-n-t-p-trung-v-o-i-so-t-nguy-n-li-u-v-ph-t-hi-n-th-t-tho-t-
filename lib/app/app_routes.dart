import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../features/auth/application/login_controller.dart';
import '../features/auth/application/session_controller.dart';
import '../features/auth/application/staff_login_controller.dart';
import '../features/auth/application/staff_register_controller.dart';
import '../features/auth/application/register_controller.dart';
import '../features/auth/domain/auth_repository.dart';
import '../features/auth/presentation/register_screen.dart';
import '../features/auth/presentation/splash_screen.dart';
import '../features/auth/presentation/staff_register_screen.dart';
import '../features/auth/presentation/welcome_screen.dart';
import '../features/home/role_home_screen.dart';
import '../features/shift/presentation/open_shift_screen.dart';
import '../features/shop/application/inbox_controller.dart';
import '../features/shop/application/team_controller.dart';
import '../features/shop/domain/shop_repository.dart';
import '../features/shop/presentation/create_shop_screen.dart';
import '../features/shop/presentation/empty_space_screen.dart';
import '../features/shop/presentation/inbox_screen.dart';
import '../features/shop/presentation/team_screen.dart';

/// Tên các màn hình. Đi tới màn nào thì dùng hằng ở đây, không gõ chuỗi rời.
abstract final class AppRoutes {
  static const splash = '/';
  static const welcome = '/welcome';
  static const register = '/register';
  static const registerStaff = '/register-staff';
  static const home = '/home';
  static const openShift = '/open-shift';
  static const emptySpace = '/empty-space';
  static const createShop = '/create-shop';
  static const inbox = '/inbox';
  static const team = '/team';

  /// Đăng nhập xong thì đi đâu. `null` = chưa quyết được (đang kiểm tra / mất mạng).
  static String? routeFor(SessionState state, {bool ownerIntent = false}) =>
      switch (state) {
        SessionChecking() || SessionOffline() => null,
        SessionSignedOut() => welcome,
        SessionSignedIn() => home,
        SessionNoShop() => ownerIntent ? createShop : emptySpace,
      };

  static Route<dynamic> generate(RouteSettings settings) {
    final Widget page = switch (settings.name) {
      splash => const SplashScreen(),
      welcome => MultiProvider(
          providers: [
            ChangeNotifierProvider(
              create: (ctx) => LoginController(ctx.read<AuthRepository>()),
            ),
            ChangeNotifierProvider(
              create: (ctx) => StaffLoginController(ctx.read<AuthRepository>()),
            ),
          ],
          child: const WelcomeScreen(),
        ),
      register => ChangeNotifierProvider(
          create: (ctx) => RegisterController(ctx.read<AuthRepository>()),
          child: const RegisterScreen(),
        ),
      registerStaff => ChangeNotifierProvider(
          create: (ctx) => StaffRegisterController(ctx.read<AuthRepository>()),
          child: const StaffRegisterScreen(),
        ),
      home => const RoleHomeScreen(),
      openShift => const OpenShiftScreen(),
      emptySpace => ChangeNotifierProvider(
          create: (ctx) => InboxController(ctx.read<ShopRepository>())
            ..load()
            ..startPolling(),
          child: const EmptySpaceScreen(),
        ),
      createShop => const CreateShopScreen(),
      inbox => ChangeNotifierProvider(
          create: (ctx) => InboxController(ctx.read<ShopRepository>())..load(),
          child: const InboxScreen(),
        ),
      team => ChangeNotifierProvider(
          create: (ctx) => TeamController(ctx.read<ShopRepository>())..load(),
          child: const TeamScreen(),
        ),
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
