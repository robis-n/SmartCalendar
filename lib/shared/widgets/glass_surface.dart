import 'dart:ui';
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

/// Authentic-feeling iOS frosted glass (the recipe a flat blur+tint box was
/// missing): real `UIVisualEffectView` materials don't just blur what's
/// behind them — they also boost its saturation ("vibrancy"), have a soft
/// internal gradient rather than a flat fill, and catch a highlight along
/// the top edge where light falls on the pane plus a faint diagonal sheen.
/// This widget layers all four behind [child] in one place so every glass
/// surface in the app (nav bar, day sheet, zoom rail) looks identical.
class GlassSurface extends StatelessWidget {
  final Widget child;
  final BorderRadius borderRadius;
  final double sigma;
  final double saturation;
  const GlassSurface({
    super.key,
    required this.child,
    required this.borderRadius,
    this.sigma = AppColors.glassBlur,
    this.saturation = 1.35,
  });

  // Luminance-preserving saturation boost — the same maths behind
  // UIVisualEffectView vibrancy, so colours behind the glass read as more
  // vivid without shifting brightness.
  static List<double> _saturationMatrix(double s) {
    const lumR = 0.213, lumG = 0.715, lumB = 0.072;
    return <double>[
      lumR + (1 - lumR) * s, lumG - lumG * s,       lumB - lumB * s,       0, 0,
      lumR - lumR * s,       lumG + (1 - lumG) * s, lumB - lumB * s,       0, 0,
      lumR - lumR * s,       lumG - lumG * s,       lumB + (1 - lumB) * s, 0, 0,
      0, 0, 0, 1, 0,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final dark = AppColors.isDark;
    // Rim catches light from above: bright along the top, fading on the
    // sides, dimmest along the bottom — never a flat single-colour outline.
    final rimTop  = dark ? Colors.white.withValues(alpha: 0.28) : Colors.white.withValues(alpha: 0.95);
    final rimSide = dark ? Colors.white.withValues(alpha: 0.12) : Colors.white.withValues(alpha: 0.55);
    final rimBtm  = dark ? Colors.white.withValues(alpha: 0.05) : Colors.white.withValues(alpha: 0.30);

    return ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        filter: ImageFilter.compose(
          outer: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
          inner: ColorFilter.matrix(_saturationMatrix(saturation)),
        ),
        child: Stack(children: [
          // Fill — a soft top→bottom gradient (real glass isn't a flat tint).
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: borderRadius,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color.alphaBlend(
                        Colors.white.withValues(alpha: dark ? 0.05 : 0.12),
                        AppColors.glass),
                    AppColors.glass,
                  ],
                ),
                border: Border(
                  top: BorderSide(color: rimTop, width: 1),
                  left: BorderSide(color: rimSide, width: 0.8),
                  right: BorderSide(color: rimSide, width: 0.8),
                  bottom: BorderSide(color: rimBtm, width: 0.8),
                ),
              ),
            ),
          ),
          // Sheen — a faint diagonal highlight, like light grazing the pane.
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: borderRadius,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    stops: const [0.0, 0.45],
                    colors: [
                      Colors.white.withValues(alpha: dark ? 0.09 : 0.38),
                      Colors.white.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ),
          ),
          child,
        ]),
      ),
    );
  }
}
