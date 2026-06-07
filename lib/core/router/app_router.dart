import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/dashboard/screens/dashboard_screen.dart';
import '../../features/tasks/screens/task_detail_screen.dart';
import '../../features/subscriptions/screens/subscription_screen.dart';
import '../../shared/widgets/main_shell.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/login',
    routes: [
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      ShellRoute(
        builder: (_, __, child) => MainShell(child: child),
        routes: [
          GoRoute(path: '/dashboard', builder: (_, __) => const DashboardScreen()),
          GoRoute(path: '/tasks/:id', builder: (_, state) => TaskDetailScreen(taskId: state.pathParameters['id']!)),
          GoRoute(path: '/subscriptions', builder: (_, __) => const SubscriptionScreen()),
        ],
      ),
    ],
  );
});
