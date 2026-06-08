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

  static const _routes = ['/dashboard', '/calendar', '/friends', '/analytics', '/settings'];

  static const _items = [
    _NavItem(Icons.home_rounded,            Icons.home_outlined,            'Home'),
    _NavItem(Icons.calendar_month_rounded,  Icons.calendar_month_outlined,  'Calendar'),
    _NavItem(Icons.people_rounded,          Icons.people_outline,           'Friends'),
    _NavItem(Icons.bar_chart_rounded,       Icons.bar_chart_outlined,       'Stats'),
    _NavItem(Icons.person_rounded,          Icons.person_outline_rounded,   'Profile'),
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
        duration: const Duration(milliseconds: 220),
        transitionBuilder: (child, animation) {
          final isEntering = child.key == ValueKey(routeIndex);
          final begin = isEntering
              ? Offset(_direction.toDouble(), 0)
              : Offset(-_direction.toDouble(), 0);
          return SlideTransition(
            position: Tween<Offset>(begin: begin, end: Offset.zero)
                .animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
            child: child,
          );
        },
        layoutBuilder: (current, previous) => Stack(
          fit: StackFit.expand,
          children: [...previous, ?current],
        ),
        child: KeyedSubtree(key: ValueKey(routeIndex), child: widget.child),
      ),

      // ── Floating dark pill nav ──────────────────────────────────────────
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Container(
          height: 68,
          decoration: BoxDecoration(
            color: const Color(0xFF1C1B2E),
            borderRadius: BorderRadius.circular(34),
            boxShadow: [
              BoxShadow(
                color: AppColors.accent.withValues(alpha: 0.35),
                blurRadius: 28,
                offset: const Offset(0, 10),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(_items.length, (i) {
              final item    = _items[i];
              final selected = routeIndex == i;
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _onTab(context, i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  padding: selected
                      ? const EdgeInsets.symmetric(horizontal: 16, vertical: 10)
                      : const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: selected ? AppColors.accent : Colors.transparent,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(
                      selected ? item.activeIcon : item.icon,
                      color: selected ? Colors.white : Colors.white.withValues(alpha: 0.45),
                      size: 22,
                    ),
                    if (selected) ...[
                      const SizedBox(width: 6),
                      Text(item.label,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
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
    );
  }
}

class _NavItem {
  final IconData activeIcon, icon;
  final String label;
  const _NavItem(this.activeIcon, this.icon, this.label);
}
