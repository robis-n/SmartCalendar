import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/dashboard/screens/dashboard_screen.dart';
import '../../features/calendar/screens/calendar_screen.dart';
import '../../features/friends/screens/friends_screen.dart';
import '../../features/analytics/screens/analytics_screen.dart';
import '../../features/settings/screens/settings_screen.dart';
import '../../features/tasks/screens/task_detail_screen.dart';
import '../../features/subscriptions/screens/subscription_screen.dart';
import '../../shared/widgets/main_shell.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/login',
    routes: [
      GoRoute(path: '/login', builder: (ctx, state) => const LoginScreen()),
      ShellRoute(
        builder: (ctx, state, child) => MainShell(child: child),
        routes: [
          GoRoute(path: '/dashboard', builder: (ctx, state) => const DashboardScreen()),
          GoRoute(path: '/calendar', builder: (ctx, state) => const CalendarScreen()),
          GoRoute(path: '/friends', builder: (ctx, state) => const FriendsScreen()),
          GoRoute(path: '/analytics', builder: (ctx, state) => const AnalyticsScreen()),
          GoRoute(path: '/settings', builder: (ctx, state) => const SettingsScreen()),
          GoRoute(path: '/subscriptions', builder: (ctx, state) => const SubscriptionScreen()),
          GoRoute(path: '/tasks/:id', builder: (ctx, state) => TaskDetailScreen(taskId: state.pathParameters['id']!)),
        ],
      ),
    ],
  );
});
