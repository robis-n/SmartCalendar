import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../services/supabase_service.dart';

class MainShell extends StatefulWidget {
  final Widget child;
  const MainShell({super.key, required this.child});
  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  // Last rendered tab + slide direction. Updated *synchronously in build*
  // (never post-frame): going right → content slides in from the right,
  // going left → from the left, with no race on rapid switches.
  int _lastIndex = 0;
  int _dir = 1;
  int _nudgeBadge = 0;

  @override
  void initState() {
    super.initState();
    _loadNudgeBadge();
  }

  Future<void> _loadNudgeBadge() async {
    final n = await SupabaseService.unseenNudgeCount();
    if (mounted) setState(() => _nudgeBadge = n);
  }

  static const _routes = ['/dashboard', '/calendar', '/settings'];
  // Icons-only nav per request → no label strings needed.
  static const _icons = <_NavIcon>[
    _NavIcon(Icons.house_rounded, Icons.house_outlined),
    _NavIcon(Icons.calendar_today_rounded, Icons.calendar_today_outlined),
    _NavIcon(Icons.person_rounded, Icons.person_outline_rounded),
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
    // Clear nudge badge when switching to profile/friends tab.
    if (i == 2 && _nudgeBadge > 0) setState(() => _nudgeBadge = 0);
    context.go(_routes[i]);
  }

  @override
  Widget build(BuildContext context) {
    final path       = GoRouterState.of(context).uri.path;
    final routeIndex = _indexFor(path);

    if (routeIndex != _lastIndex) {
      _dir = routeIndex > _lastIndex ? 1 : -1;
      _lastIndex = routeIndex;
    }
    final dir = _dir;

    return Scaffold(
      extendBody: true,
      backgroundColor: AppColors.bg,
      body: ClipRect(
        // Directional cross-fade: incoming slides in from the tap direction,
        // outgoing slides away to the opposite side. Both move — that's what
        // makes the motion read correctly going left AND right.
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeOutCubic,
          transitionBuilder: (child, animation) {
            final entering = child.key == ValueKey(routeIndex);
            // Incoming travels 25% from the direction of travel; outgoing
            // exits 18% the other way (its animation runs in reverse, so
            // `begin` is where it ends up).
            final begin = Offset(entering ? dir * 0.25 : -dir * 0.18, 0);
            return FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween<Offset>(begin: begin, end: Offset.zero)
                    .animate(animation),
                child: child,
              ),
            );
          },
          layoutBuilder: (current, previous) =>
              Stack(fit: StackFit.expand, children: [...previous, ?current]),
          child: KeyedSubtree(
            key: ValueKey(routeIndex),
            // Isolate each tab's painting so the glass-blur nav doesn't force
            // full-screen repaints mid-animation (a source of the lag).
            child: RepaintBoundary(child: widget.child),
          ),
        ),
      ),

      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(70, 0, 70, 18),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(34),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
              child: Container(
                height: 62,
                decoration: BoxDecoration(
                  color: AppColors.glass,
                  borderRadius: BorderRadius.circular(34),
                  border: Border.all(color: AppColors.glassBorder, width: 0.8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black
                          .withValues(alpha: AppColors.isDark ? 0.40 : 0.08),
                      blurRadius: 24,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: LayoutBuilder(builder: (ctx, c) {
                  final slot = c.maxWidth / _icons.length;
                  return Stack(children: [
                    // ── Sliding ink bubble — circular pill around the icon ─
                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 320),
                      curve: Curves.easeOutCubic,
                      left: routeIndex * slot,
                      top: 0, bottom: 0, width: slot,
                      child: Center(
                        child: Container(
                          width: 44, height: 44,
                          decoration: BoxDecoration(
                            color: AppColors.label,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ),
                    // ── Tab tap targets (icon only, centred) ───────────────
                    Positioned.fill(
                      child: Row(
                        children: List.generate(_icons.length, (i) {
                          final ic = _icons[i];
                          final selected = routeIndex == i;
                          return Expanded(
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () => _onTab(context, i, routeIndex),
                              child: Center(
                                child: Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    AnimatedSwitcher(
                                      duration: const Duration(milliseconds: 220),
                                      child: Icon(
                                        selected ? ic.active : ic.idle,
                                        key: ValueKey(selected),
                                        color: selected ? AppColors.bg : AppColors.label3,
                                        size: 22,
                                      ),
                                    ),
                                    // Nudge badge — profile tab only
                                    if (i == 2 && _nudgeBadge > 0)
                                      Positioned(
                                        top: -4, right: -4,
                                        child: Container(
                                          width: 10, height: 10,
                                          decoration: BoxDecoration(
                                            color: AppColors.bg,
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: selected ? AppColors.label : AppColors.bg2,
                                              width: 1.5,
                                            ),
                                          ),
                                          child: Center(
                                            child: Container(
                                              width: 5, height: 5,
                                              decoration: BoxDecoration(
                                                color: AppColors.label,
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
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
      ),
    );
  }
}

class _NavIcon {
  final IconData active, idle;
  const _NavIcon(this.active, this.idle);
}
