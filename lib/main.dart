import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'features/auth/login_screen.dart';

const _url = String.fromEnvironment('SUPABASE_URL');
const _anonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (_url.isEmpty || _anonKey.isEmpty) {
    throw Exception('Thiếu SUPABASE_URL / SUPABASE_ANON_KEY (xem .env.example)');
  }
  await Supabase.initialize(url: _url, anonKey: _anonKey);
  runApp(const ForeApp());
}

class ForeApp extends StatelessWidget {
  const ForeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fore',
      theme: ThemeData(colorSchemeSeed: Colors.teal, useMaterial3: true),
      home: const LoginScreen(),
    );
  }
}
