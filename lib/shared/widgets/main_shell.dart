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
  // Last rendered tab — used to derive slide direction deterministically
  // (computing direction inside onTap races with go_router's async route update).
  int _prev = 0;
  int _lastDir = 1;

  static const _routes = ['/dashboard', '/calendar', '/settings'];

  static const _items = [
    _NavItem(Icons.house_rounded,          Icons.house_outlined,          'Home'),
    _NavItem(Icons.calendar_today_rounded, Icons.calendar_today_outlined, 'Calendar'),
    _NavItem(Icons.person_rounded,         Icons.person_outline_rounded,  'Profile'),
  ];

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

  void _onTab(BuildContext context, int i, int current) {
    if (i == current) return;
    context.go(_routes[i]);
  }

  @override
  Widget build(BuildContext context) {
    final path       = GoRouterState.of(context).uri.path;
    final routeIndex = _indexFor(path);

    // Direction: moving to a higher index slides content from the right (+1),
    // lower index slides from the left (-1). Going LEFT (e.g. Calendar→Home)
    // therefore enters from the left = a left→right sweep.
    final dir = routeIndex > _prev ? 1 : (routeIndex < _prev ? -1 : _lastDir);
    _lastDir = dir;
    if (routeIndex != _prev) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _prev = routeIndex;
      });
    }

    return Scaffold(
      extendBody: true,
      backgroundColor: AppColors.bg,
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 320),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, animation) {
          final entering = child.key == ValueKey(routeIndex);
          final dx = entering ? dir * 0.10 : -dir * 0.10;
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

      bottomNavigationBar: Padding(
        padding: const EdgeInsets.fromLTRB(40, 0, 40, 26),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(36),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
            child: Container(
              height: 68,
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
              child: LayoutBuilder(builder: (ctx, c) {
                final slot = c.maxWidth / _items.length;
                return Stack(children: [
                  // ── Sliding ink bubble ──────────────────────────
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 340),
                    curve: Curves.easeOutCubic,
                    left: routeIndex * slot,
                    top: 0, bottom: 0, width: slot,
                    child: Center(
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppColors.label,
                          borderRadius: BorderRadius.circular(24),
                        ),
                      ),
                    ),
                  ),
                  // ── Tab buttons ─────────────────────────────────
                  Row(
                    children: List.generate(_items.length, (i) {
                      final item     = _items[i];
                      final selected = routeIndex == i;
                      return Expanded(
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => _onTab(context, i, routeIndex),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                selected ? item.activeIcon : item.icon,
                                color: selected ? AppColors.bg : AppColors.label3,
                                size: 23,
                              ),
                              AnimatedSize(
                                duration: const Duration(milliseconds: 280),
                                curve: Curves.easeOutCubic,
                                child: selected
                                    ? Padding(
                                        padding: const EdgeInsets.only(left: 8),
                                        child: Text(item.label,
                                            style: TextStyle(
                                              color: AppColors.bg,
                                              fontSize: 14,
                                              fontWeight: FontWeight.w700,
                                              letterSpacing: -0.2,
                                            )),
                                      )
                                    : const SizedBox.shrink(),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ),
                ]);
              }),
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
