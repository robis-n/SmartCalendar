import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_provider.dart';
import 'core/router/app_router.dart';

class AccountabilityApp extends ConsumerWidget {
  const AccountabilityApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router    = ref.watch(appRouterProvider);
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: 'SmartCalendar',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      // Flip instantly: the Material lerp would cross-fade over 200ms while our
      // global ink/paper flag snaps at the midpoint — that mismatch is the
      // "lag". Zero duration makes brightness + AppColors switch in one frame.
      themeAnimationDuration: Duration.zero,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
      // The `builder` runs as a descendant of MaterialApp's resolved Theme,
      // so this reflects the brightness actually applied (light/dark/system).
      // Sync the global ink/paper flag here, before any screen builds, so the
      // direct AppColors.* getters resolve correctly every frame.
      builder: (context, child) {
        AppColors.dark = Theme.of(context).brightness == Brightness.dark;
        return child ?? const SizedBox.shrink();
      },
    );
  }
}
