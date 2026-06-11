import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/theme/theme_provider.dart';
import 'services/account_manager.dart';
import 'services/notification_service.dart';
import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Local settings store (theme mode, etc.) + remembered accounts
  await Hive.initFlutter();
  await Hive.openBox(kSettingsBox);
  await Hive.openBox(AccountManager.kAccountsBox);

  await dotenv.load(fileName: '.env');

  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    // ignore: deprecated_member_use
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );

  // Keep the per-account refresh token fresh: Supabase rotates it on every
  // refresh, and only the newest one can restore a session later.
  Supabase.instance.client.auth.onAuthStateChange.listen((data) {
    final s = data.session;
    if (s != null) AccountManager.saveCurrent(s);
  });

  await NotificationService().init();

  runApp(const ProviderScope(child: AccountabilityApp()));
}
