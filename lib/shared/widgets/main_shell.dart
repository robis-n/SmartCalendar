import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/theme_provider.dart';
import '../../services/supabase_service.dart';
import 'glass_surface.dart';

/// The persistent app shell: the body is the StatefulNavigationShell (three
/// always-alive branch navigators) and a floating glass tab bar on top.
class MainShell extends ConsumerStatefulWidget {
  final StatefulNavigationShell navigationShell;
  const MainShell({super.key, required this.navigationShell});
  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
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

  static const _icons = <_NavIcon>[
    _NavIcon(Icons.house_rounded, Icons.house_outlined),
    _NavIcon(Icons.calendar_today_rounded, Icons.calendar_today_outlined),
    _NavIcon(Icons.person_rounded, Icons.person_outline_rounded),
  ];

  void _onTab(int i) {
    HapticFeedback.selectionClick();
    if (i == 2 && _nudgeBadge > 0) setState(() => _nudgeBadge = 0);
    // goBranch with initialLocation:true when re-tapping the active tab pops
    // that branch back to its root — the standard iOS tab-bar gesture.
    widget.navigationShell.goBranch(
      i,
      initialLocation: i == widget.navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Watch the theme providers so the (AppColors-based) nav bar recolours
    // INSTANTLY when the accent/mode changes — this branch stays alive, so
    // without watching it wouldn't rebuild on a colour switch.
    ref.watch(accentColorProvider);
    ref.watch(themeModeProvider);
    final index = widget.navigationShell.currentIndex;

    return Scaffold(
      extendBody: true,
      backgroundColor: AppColors.bg,
      // The shell content (BranchSwitcher owns the cross-tab animation).
      body: widget.navigationShell,

      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(70, 0, 70, 18),
          child: DecoratedBox(
            // Drop shadow lives outside the glass clip so it isn't blurred away.
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(34),
              boxShadow: [
                BoxShadow(
                  color: Colors.black
                      .withValues(alpha: AppColors.isDark ? 0.40 : 0.08),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: GlassSurface(
              borderRadius: BorderRadius.circular(34),
              child: SizedBox(
                height: 62,
                child: LayoutBuilder(builder: (ctx, c) {
                  final slot = c.maxWidth / _icons.length;
                  return Stack(children: [
                    // ── Sliding accent pill — springy, like the iOS tab bar ─
                    AnimatedPositioned(
                      duration: AppMotion.base,
                      curve: AppMotion.spring,
                      left: index * slot,
                      top: 0, bottom: 0, width: slot,
                      child: Center(
                        child: Container(
                          width: 46, height: 46,
                          decoration: BoxDecoration(
                            color: AppColors.accent,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.accent.withValues(alpha: 0.32),
                                blurRadius: 14,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    // ── Tab tap targets (icon only, centred) ───────────────
                    Positioned.fill(
                      child: Row(
                        children: List.generate(_icons.length, (i) {
                          final ic = _icons[i];
                          final selected = index == i;
                          return Expanded(
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () => _onTab(i),
                              child: Center(
                                child: Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    // Gentle scale-up on the selected icon —
                                    // the subtle tactile lift Apple uses.
                                    AnimatedScale(
                                      scale: selected ? 1.0 : 0.86,
                                      duration: AppMotion.base,
                                      curve: AppMotion.spring,
                                      child: AnimatedSwitcher(
                                        duration: AppMotion.fast,
                                        switchInCurve: AppMotion.standard,
                                        child: Icon(
                                          selected ? ic.active : ic.idle,
                                          key: ValueKey(selected),
                                          color: selected
                                              ? AppColors.onAccent
                                              : AppColors.label3,
                                          size: 23,
                                        ),
                                      ),
                                    ),
                                    if (i == 2 && _nudgeBadge > 0)
                                      Positioned(
                                        top: -4, right: -4,
                                        child: Container(
                                          width: 10, height: 10,
                                          decoration: BoxDecoration(
                                            color: AppColors.bg,
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: selected
                                                  ? AppColors.accent
                                                  : AppColors.bg2,
                                              width: 1.5,
                                            ),
                                          ),
                                          child: Center(
                                            child: Container(
                                              width: 5, height: 5,
                                              decoration: BoxDecoration(
                                                color: AppColors.accent,
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

/// Owns the cross-branch transition for [StatefulShellRoute]. All three branch
/// navigators stay alive (state preserved); only the active one is on stage,
/// except during a switch when the outgoing and incoming branches slide past
/// each other and crossfade. Direction follows tab order: to a higher tab the
/// new branch enters from the right; to a lower tab, from the left.
class BranchSwitcher extends StatefulWidget {
  final int currentIndex;
  final List<Widget> children;
  const BranchSwitcher({
    super.key,
    required this.currentIndex,
    required this.children,
  });
  @override
  State<BranchSwitcher> createState() => _BranchSwitcherState();
}

class _BranchSwitcherState extends State<BranchSwitcher>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: AppMotion.base, value: 1);
  late int _index = widget.currentIndex;
  int _prev = -1;
  int _dir = 1;

  @override
  void didUpdateWidget(covariant BranchSwitcher old) {
    super.didUpdateWidget(old);
    if (widget.currentIndex != _index) {
      _prev = _index;
      _index = widget.currentIndex;
      _dir = _index > _prev ? 1 : -1;
      _c.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final t = AppMotion.emphasized.transform(_c.value);
        final animating = !_c.isCompleted && _prev >= 0;
        return Stack(
          fit: StackFit.expand,
          children: List.generate(widget.children.length, (i) {
            final isCurrent = i == _index;
            final isPrev = animating && i == _prev;

            // Keep inactive branches alive but fully off stage (no paint, no
            // hit-test, tickers paused) so their scroll/state survive.
            if (!isCurrent && !isPrev) {
              return Offstage(
                offstage: true,
                child: TickerMode(enabled: false, child: widget.children[i]),
              );
            }

            // Incoming slides from dir → 0 and fades in; outgoing slides
            // 0 → -dir and fades out. dx is a screen-width fraction.
            final dx = isCurrent ? _dir * (1 - t) : -_dir.toDouble() * t;
            final opacity = (isCurrent ? t : 1 - t).clamp(0.0, 1.0);

            return Positioned.fill(
              child: IgnorePointer(
                ignoring: !isCurrent,
                child: FractionalTranslation(
                  translation: Offset(dx, 0),
                  child: Opacity(
                    opacity: opacity,
                    child: TickerMode(
                      enabled: isCurrent,
                      child: widget.children[i],
                    ),
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}
