import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/theme/app_theme.dart';
import '../core/data/rpc_client.dart';
import '../features/auth/application/session_controller.dart';
import '../features/auth/domain/auth_repository.dart';
import '../features/auth/presentation/splash_screen.dart';
import '../features/inventory/data/rpc_inventory_repository.dart';
import '../features/inventory/domain/inventory_repository.dart';
import '../features/owner/data/owner_dashboard_repository.dart';
import '../features/owner/data/supabase_owner_menu_repository.dart';
import '../features/owner/domain/owner_menu_repository.dart';
import '../features/shift/application/shift_controller.dart';
import '../features/shift/domain/shift_repository.dart';
import '../features/shop/domain/shop_repository.dart';
import 'app_routes.dart';

/// Gốc của app. Nhận các repository từ ngoài vào (dependency injection):
/// `main.dart` truyền bản Supabase, test truyền bản giả.
class ForeApp extends StatelessWidget {
  const ForeApp({
    super.key,
    required this.authRepository,
    required this.shiftRepository,
    required this.shopRepository,
  });

  final AuthRepository authRepository;
  final ShiftRepository shiftRepository;
  final ShopRepository shopRepository;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<AuthRepository>.value(value: authRepository),
        ChangeNotifierProvider<SessionController>(
          create: (_) => SessionController(
            authRepository,
            minVisible: SplashScreen.introDuration,
          ),
        ),
        Provider<ShiftRepository>.value(value: shiftRepository),
        Provider<ShopRepository>.value(value: shopRepository),
        Provider<RpcClient>(
          create: (_) => SupabaseRpcClient(Supabase.instance.client),
        ),
        Provider<RpcInventoryRepository>(
          create: (context) =>
              RpcInventoryRepository(context.read<RpcClient>()),
        ),
        Provider<InventoryRepository>(
          create: (context) => context.read<RpcInventoryRepository>(),
        ),
        Provider<CashRepository>(
          create: (context) => context.read<RpcInventoryRepository>(),
        ),
        Provider<OwnerDashboardDataSource>(
          create: (_) => OwnerDashboardRepository(Supabase.instance.client),
        ),
        Provider<OwnerMenuRepository>(
          create: (_) => SupabaseOwnerMenuRepository(Supabase.instance.client),
        ),
        ChangeNotifierProvider<ShiftController>(
          create: (_) => ShiftController(shiftRepository),
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
