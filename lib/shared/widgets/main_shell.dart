import 'dart:ui';
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
  int _direction = 1;

  // Only three primary destinations. Friends & Stats live inside Profile.
  static const _routes = ['/dashboard', '/calendar', '/settings'];

  static const _items = [
    _NavItem(Icons.house_rounded,           Icons.house_outlined,           'Home'),
    _NavItem(Icons.calendar_today_rounded,  Icons.calendar_today_outlined,  'Calendar'),
    _NavItem(Icons.person_rounded,          Icons.person_outline_rounded,   'Profile'),
  ];

  // Map any path (incl. profile sub-pages) to one of the three tabs.
  int _indexFor(String path) {
    if (path.startsWith('/calendar')) return 1;
    if (path.startsWith('/settings') ||
        path.startsWith('/friends') ||
        path.startsWith('/analytics') ||
        path.startsWith('/subscriptions')) {
      return 2;
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
    final path       = GoRouterState.of(context).uri.path;
    final routeIndex = _indexFor(path);

    if (routeIndex != _tabIndex) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _tabIndex = routeIndex);
      });
    }

    return Scaffold(
      extendBody: true,
      backgroundColor: AppColors.bg,
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, animation) {
          // Incoming child carries the *current* routeIndex key; the
          // outgoing child still carries the previous one.
          final entering = child.key == ValueKey(routeIndex);
          final dx = entering ? _direction * 0.10 : -_direction * 0.10;
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(begin: Offset(dx, 0), end: Offset.zero)
                  .animate(animation),
              child: child,
            ),
          );
        },
        layoutBuilder: (current, previous) =>
            Stack(fit: StackFit.expand, children: [...previous, ?current]),
        child: KeyedSubtree(key: ValueKey(routeIndex), child: widget.child),
      ),

      // ── Floating glass pill nav ─────────────────────────────────────────
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.fromLTRB(48, 0, 48, 26),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(36),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
            child: Container(
              height: 66,
              decoration: BoxDecoration(
                color: AppColors.glass,
                borderRadius: BorderRadius.circular(36),
                border: Border.all(color: AppColors.glassBorder, width: 0.8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: AppColors.isDark ? 0.45 : 0.10),
                    blurRadius: 30,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(_items.length, (i) {
                  final item     = _items[i];
                  final selected = routeIndex == i;
                  return GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _onTab(context, i),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 260),
                      curve: Curves.easeOutCubic,
                      padding: selected
                          ? const EdgeInsets.symmetric(horizontal: 18, vertical: 11)
                          : const EdgeInsets.all(11),
                      decoration: BoxDecoration(
                        color: selected ? AppColors.label : Colors.transparent,
                        borderRadius: BorderRadius.circular(26),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(
                          selected ? item.activeIcon : item.icon,
                          color: selected ? AppColors.bg : AppColors.label3,
                          size: 23,
                        ),
                        if (selected) ...[
                          const SizedBox(width: 8),
                          Text(item.label,
                              style: TextStyle(
                                color: AppColors.bg,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.2,
                              )),
                        ],
                      ]),
                    ),
                  );
                }),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData activeIcon, icon;
  final String label;
  const _NavItem(this.activeIcon, this.icon, this.label);
}
