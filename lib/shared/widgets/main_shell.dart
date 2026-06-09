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
  // (computing direction inside onTap races with go_router's async update).
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

    // +1 = moving to a higher tab → new screen enters from the right.
    // -1 = moving to a lower tab → new screen enters from the left
    //      (e.g. Calendar→Home is a left→right sweep).
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
      body: ClipRect(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 340),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (child, animation) {
            final entering = child.key == ValueKey(routeIndex);
            // Full-width slide — a clear, whole-screen transition.
            final begin = Offset(entering ? dir.toDouble() : -dir.toDouble(), 0);
            return SlideTransition(
              position: Tween<Offset>(begin: begin, end: Offset.zero).animate(animation),
              child: child,
            );
          },
          layoutBuilder: (current, previous) =>
              Stack(fit: StackFit.expand, children: [...previous, ?current]),
          child: KeyedSubtree(key: ValueKey(routeIndex), child: widget.child),
        ),
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
                  // ── Sliding ink bubble (vertically centred) ─────
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 340),
                    curve: Curves.easeOutCubic,
                    left: routeIndex * slot,
                    top: 0, bottom: 0, width: slot,
                    child: Center(
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
                        decoration: BoxDecoration(
                          color: AppColors.label,
                          borderRadius: BorderRadius.circular(24),
                        ),
                      ),
                    ),
                  ),
                  // ── Tab buttons (fill height, centred content) ──
                  Positioned.fill(
                    child: Row(
                      children: List.generate(_items.length, (i) {
                        final item     = _items[i];
                        final selected = routeIndex == i;
                        return Expanded(
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => _onTab(context, i, routeIndex),
                            child: Center(
                              child: Row(mainAxisSize: MainAxisSize.min, children: [
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
                              ]),
                            ),
                          ),
                        );
                      }),
                    ),
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
