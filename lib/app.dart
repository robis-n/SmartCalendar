import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_provider.dart';
import 'core/utils/time_utils.dart';
import 'core/router/app_router.dart';
import 'services/supabase_service.dart';

class AccountabilityApp extends ConsumerStatefulWidget {
  const AccountabilityApp({super.key});
  @override
  ConsumerState<AccountabilityApp> createState() => _AccountabilityAppState();
}

class _AccountabilityAppState extends ConsumerState<AccountabilityApp> {
  StreamSubscription<AuthState>? _authSub;

  @override
  void initState() {
    super.initState();
    // Apply cloud settings on sign-in and clear local settings on sign-out.
    _authSub = Supabase.instance.client.auth.onAuthStateChange.listen((data) async {
      if (data.event == AuthChangeEvent.signedIn) {
        final prefs = await SupabaseService.loadAppearanceSettings();
        if (prefs.isNotEmpty && mounted) {
          applyCloudSettings(prefs, ref);
        }
      } else if (data.event == AuthChangeEvent.signedOut) {
        await clearLocalSettings();
      }
    });
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final router    = ref.watch(appRouterProvider);
    final themeMode = ref.watch(themeModeProvider);
    final textScale = ref.watch(textScaleProvider);
    final accentIdx   = ref.watch(accentColorProvider);
    final customColor = ref.watch(customAccentColorProvider);
    final use24h    = ref.watch(timeFormatProvider);

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
        AppColors.palette = accentPaletteForIndex(accentIdx, customColor);
        TimeFmt.use24h = use24h;
        // Apply the user's text-size choice globally, ignoring any extreme OS
        // setting so the layout stays in proportion.
        return MediaQuery.withClampedTextScaling(
          minScaleFactor: textScale,
          maxScaleFactor: textScale,
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}
