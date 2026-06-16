import 'package:flutter/foundation.dart';

/// A single app-wide "something changed, refresh" signal.
///
/// Screens kept alive by `StatefulShellRoute` (Home, Calendar) don't rebuild
/// when you act on a *different* tab, or when the account switches — so they
/// could show stale or even another account's data. They listen to
/// [dataRevision] and reload when it ticks. Bumped by:
///   • every task mutation in `SupabaseService`
///   • account switch / sign-out in `AccountManager`
final ValueNotifier<int> dataRevision = ValueNotifier<int>(0);

void bumpData() => dataRevision.value++;
