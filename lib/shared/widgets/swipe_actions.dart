import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_theme.dart';

/// One revealed action behind a swipeable row.
class SwipeAction {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const SwipeAction({required this.icon, required this.label, required this.onTap});
}

/// Swipe a row left to reveal a strip of round action buttons, with a soft
/// springy follow + settle (the "boggly" feel). Tapping an action closes the
/// row and runs it. Fully self-contained — wrap any child.
class SwipeActions extends StatefulWidget {
  final Widget child;
  final List<SwipeAction> actions;
  const SwipeActions({super.key, required this.child, required this.actions});
  @override
  State<SwipeActions> createState() => _SwipeActionsState();
}

class _SwipeActionsState extends State<SwipeActions> {
  static const double _btn = 58;
  double _dx = 0;           // current horizontal offset (<= 0)
  bool _dragging = false;
  bool _hapticArmed = true; // fire one haptic as the strip latches open

  double get _maxReveal => widget.actions.length * _btn;

  void _close() => setState(() { _dx = 0; _dragging = false; });

  @override
  Widget build(BuildContext context) {
    final open = _dx <= -_maxReveal + 0.5;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragStart: (_) => _dragging = true,
      onHorizontalDragUpdate: (d) {
        setState(() {
          _dx = (_dx + d.delta.dx).clamp(-_maxReveal - 24, 0.0);
          if (_dx <= -_maxReveal && _hapticArmed) {
            HapticFeedback.selectionClick();
            _hapticArmed = false;
          } else if (_dx > -_maxReveal) {
            _hapticArmed = true;
          }
        });
      },
      onHorizontalDragEnd: (d) {
        final v = d.primaryVelocity ?? 0;
        // Snap open if dragged past half or flung left; otherwise spring shut.
        final shouldOpen = _dx < -_maxReveal / 2 || v < -600;
        setState(() {
          _dx = shouldOpen ? -_maxReveal : 0;
          _dragging = false;
        });
      },
      child: Stack(children: [
        // ── Action strip (revealed underneath) ──
        Positioned.fill(
          child: Align(
            alignment: Alignment.centerRight,
            child: ClipRect(
              child: SizedBox(
                width: _maxReveal,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: widget.actions.map((a) {
                    return GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () { _close(); a.onTap(); },
                      child: SizedBox(
                        width: _btn,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 40, height: 40,
                              decoration: BoxDecoration(
                                color: AppColors.bg2,
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: AppColors.separator, width: 1),
                              ),
                              child: Icon(a.icon, size: 19, color: AppColors.label),
                            ),
                            const SizedBox(height: 4),
                            Text(a.label,
                                style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.label3)),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
        ),
        // ── Foreground row (slides over the strip) ──
        // Follow the finger instantly; settle with a gentle overshoot.
        AnimatedContainer(
          duration: _dragging ? Duration.zero : AppMotion.base,
          curve: AppMotion.spring,
          transform: Matrix4.translationValues(_dx, 0, 0),
          color: AppColors.bg,
          child: widget.child,
        ),
        // Tap anywhere on the open row's surface to close it.
        if (open && !_dragging)
          Positioned.fill(
            right: _maxReveal,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _close,
            ),
          ),
      ]),
    );
  }
}
