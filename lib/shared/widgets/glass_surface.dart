import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import '../../core/theme/app_theme.dart';

/// Real Apple "Liquid Glass" via `liquid_glass_widgets`. Unlike the package
/// tried in a previous round (`liquid_glass_renderer`), this one ships a
/// *separate*, deliberately simple shader for Skia/web
/// (`GlassQuality.standard`'s "lightweight" shader) instead of reusing the
/// same complex Impeller geometry shader everywhere — which is exactly what
/// broke `flutter build web --release` last time (a loop-bound construct the
/// web SkSL backend rejects). Verified here with a full web release build
/// before wiring this in. `standard` quality is also explicitly the
/// package's recommended tier for anything that might appear inside a
/// scrollable list (nav bar, sheets) — `premium` warns it "may not render
/// correctly in scrollable contexts", so we don't reach for it.
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

  @override
  Widget build(BuildContext context) {
    final dark = AppColors.isDark;
    final radius = borderRadius.topLeft.x;

    return GlassContainer(
      useOwnLayer: true,
      quality: GlassQuality.standard,
      clipBehavior: Clip.antiAlias,
      shape: LiquidRoundedSuperellipse(borderRadius: radius),
      settings: LiquidGlassSettings(
        glassColor: AppColors.glass,
        thickness: 22,
        blur: sigma * 0.6,
        chromaticAberration: 0.01,
        lightIntensity: dark ? 0.45 : 0.7,
        ambientStrength: 0.12,
        refractiveIndex: 1.25,
        saturation: saturation,
      ),
      child: child,
    );
  }
}
