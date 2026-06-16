import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/dashboard/screens/dashboard_screen.dart';
import '../../features/calendar/screens/calendar_screen.dart';
import '../../features/friends/screens/friends_screen.dart';
import '../../features/analytics/screens/analytics_screen.dart';
import '../../features/settings/screens/settings_screen.dart';
import '../../features/tasks/screens/task_detail_screen.dart';
import '../../features/subscriptions/screens/subscription_screen.dart';
import '../../shared/widgets/main_shell.dart';

// One Navigator key per tab branch, so MainShell can pop a branch's pushed
// screens back to root when its tab icon is tapped while already active.
// Needed because screens like Friends/Analytics/Subscriptions are pushed
// imperatively (Navigator.push), which go_router's branch routing doesn't
// track — `goBranch(initialLocation: true)` alone can't pop them.
final List<GlobalKey<NavigatorState>> branchNavigatorKeys =
    List.generate(3, (_) => GlobalKey<NavigatorState>());

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/login',
    redirect: (context, state) {
      final isLoggedIn = Supabase.instance.client.auth.currentUser != null;
      final isOnLogin = state.uri.path == '/login';
      if (isLoggedIn && isOnLogin) return '/dashboard';
      if (!isLoggedIn && !isOnLogin) return '/login';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (ctx, state) => const LoginScreen()),
      // StatefulShellRoute keeps each tab's Navigator (and scroll position /
      // state) alive in parallel branches — the Apple-style behaviour where
      // switching tabs is instant and lossless. We own the cross-branch
      // transition via [navigatorContainerBuilder] (see _BranchSwitcher), so
      // there is NO nested per-route push animation fighting ours — that was
      // the long-standing cause of the janky/half-missing section animation.
      StatefulShellRoute(
        builder: (ctx, state, navigationShell) =>
            MainShell(navigationShell: navigationShell),
        navigatorContainerBuilder: (ctx, navigationShell, children) =>
            BranchSwitcher(
                currentIndex: navigationShell.currentIndex, children: children),
        branches: [
          // 0 — Home
          StatefulShellBranch(
            navigatorKey: branchNavigatorKeys[0],
            routes: [
            GoRoute(path: '/dashboard', builder: (ctx, state) => const DashboardScreen()),
          ]),
          // 1 — Calendar
          StatefulShellBranch(
            navigatorKey: branchNavigatorKeys[1],
            routes: [
            GoRoute(path: '/calendar', builder: (ctx, state) => const CalendarScreen()),
          ]),
          // 2 — Profile / Settings (and the screens reachable from it)
          StatefulShellBranch(
            navigatorKey: branchNavigatorKeys[2],
            routes: [
            GoRoute(path: '/settings', builder: (ctx, state) => const SettingsScreen()),
            GoRoute(path: '/friends', builder: (ctx, state) => const FriendsScreen()),
            GoRoute(path: '/analytics', builder: (ctx, state) => const AnalyticsScreen()),
            GoRoute(path: '/subscriptions', builder: (ctx, state) => const SubscriptionScreen()),
            GoRoute(path: '/tasks/:id', builder: (ctx, state) => TaskDetailScreen(taskId: state.pathParameters['id']!)),
          ]),
        ],
      ),
    ],
  );
});
