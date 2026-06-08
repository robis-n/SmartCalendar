import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';

class MainShell extends StatefulWidget {
  final Widget child;
  const MainShell({super.key, required this.child});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _tabIndex = 0;
  int _direction = 1; // +1 = going right (slide in from right), -1 = going left

  static const _routes = [
    '/dashboard',
    '/calendar',
    '/friends',
    '/analytics',
    '/settings',
  ];

  int _indexFor(String path) {
    for (int i = 0; i < _routes.length; i++) {
      if (path.startsWith(_routes[i])) return i;
    }
    return 0;
  }

  void _onTab(BuildContext context, int i) {
    if (i == _tabIndex) return;
    setState(() {
      _direction = i > _tabIndex ? 1 : -1;
      _tabIndex = i;
    });
    context.go(_routes[i]);
  }

  @override
  Widget build(BuildContext context) {
    final path = GoRouterState.of(context).uri.path;
    final routeIndex = _indexFor(path);

    // Sync _tabIndex when route changes externally (deep-link / initial load)
    if (routeIndex != _tabIndex) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _tabIndex = routeIndex);
      });
    }

    return Scaffold(
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 240),
        transitionBuilder: (child, animation) {
          // Determine if this child is the entering one or the leaving one
          final isEntering = child.key == ValueKey(routeIndex);
          final begin = isEntering
              ? Offset(_direction.toDouble(), 0)   // enter from right or left
              : Offset(-_direction.toDouble(), 0); // exit to left or right
          return SlideTransition(
            position: Tween<Offset>(begin: begin, end: Offset.zero).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeInOut),
            ),
            child: child,
          );
        },
        layoutBuilder: (current, previous) => Stack(
          fit: StackFit.expand,
          children: [...previous, ?current],
        ),
        child: KeyedSubtree(key: ValueKey(routeIndex), child: widget.child),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppColors.card,
          boxShadow: [
            BoxShadow(
              color: AppColors.accent.withValues(alpha: 0.08),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: NavigationBar(
          selectedIndex: routeIndex,
          backgroundColor: AppColors.card,
          elevation: 0,
          height: 60,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          indicatorColor: AppColors.accentLight,
          onDestinationSelected: (i) => _onTab(context, i),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home_rounded, color: AppColors.accent),
              label: 'Home',
            ),
            NavigationDestination(
              icon: Icon(Icons.calendar_month_outlined),
              selectedIcon: Icon(Icons.calendar_month_rounded, color: AppColors.accent),
              label: 'Calendar',
            ),
            NavigationDestination(
              icon: Icon(Icons.people_outline),
              selectedIcon: Icon(Icons.people_rounded, color: AppColors.accent),
              label: 'Friends',
            ),
            NavigationDestination(
              icon: Icon(Icons.bar_chart_outlined),
              selectedIcon: Icon(Icons.bar_chart_rounded, color: AppColors.accent),
              label: 'Stats',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline_rounded),
              selectedIcon: Icon(Icons.person_rounded, color: AppColors.accent),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}
