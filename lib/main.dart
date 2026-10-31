import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/app.dart';
import 'core/config/app_config.dart';
import 'features/auth/data/supabase_auth_repository.dart';
import 'features/shift/data/supabase_shift_repository.dart';
import 'features/shop/data/supabase_shop_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final config = AppConfig.fromEnvironment();
  if (!config.isComplete) {
    throw StateError('Thiếu SUPABASE_URL / SUPABASE_ANON_KEY (xem README)');
  }
  await Supabase.initialize(
    url: config.supabaseUrl,
    publishableKey: config.supabaseAnonKey,
  );

  final client = Supabase.instance.client;
  runApp(ForeApp(
    authRepository: SupabaseAuthRepository(client),
    shiftRepository: SupabaseShiftRepository(client),
    shopRepository: SupabaseShopRepository(client),
  ));
}
