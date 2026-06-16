import 'dart:ui';
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

/// Authentic-feeling iOS frosted glass. Built entirely from standard Flutter
/// compositing (blur + color matrix + gradients) rather than a custom
/// fragment shader, because the one real shader-based option on pub.dev
/// (`liquid_glass_renderer`) ships a `.frag` asset that fails to compile
/// under the web SkSL backend (non-constant loop bound), which breaks
/// `flutter build web --release` outright — a non-starter for an app that
/// ships to iOS *and* Web. This recipe instead layers: backdrop blur +
/// vibrancy (saturation boost, the way `UIVisualEffectView` works), a soft
/// top→bottom tint gradient, a top-left specular glint (light catching the
/// pane), a directional sheen, and a four-sided rim that's brightest where
/// light falls from above — all pure widgets, so it's identical and safe
/// on every platform SmartCalendar ships to.
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
    final rimTop  = dark ? Colors.white.withValues(alpha: 0.32) : Colors.white.withValues(alpha: 0.95);
    final rimSide = dark ? Colors.white.withValues(alpha: 0.14) : Colors.white.withValues(alpha: 0.55);
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
                        Colors.white.withValues(alpha: dark ? 0.06 : 0.14),
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
          // Specular glint — a soft, blurred bright patch top-left, like a
          // real pane catching a single light source. Blurred with a plain
          // ImageFilter.blur (Skia, web-safe) rather than a shader.
          Positioned(
            top: -18,
            left: -18,
            width: 90,
            height: 60,
            child: IgnorePointer(
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: dark ? 0.22 : 0.55),
                  ),
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
                      Colors.white.withValues(alpha: dark ? 0.1 : 0.4),
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
