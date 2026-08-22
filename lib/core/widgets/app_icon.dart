import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Canonical Medibook icon names (Iconsax line/bold set + custom bottom-nav
/// glyphs). Each maps to an SVG asset exported from the design system's exact
/// path data (`assets/icons/<name>.svg`). Glyphs paint with a single color
/// (the design's `currentColor` semantics).
abstract final class MedIcon {
  MedIcon._();

  // Iconsax line glyphs (each has a `-bold` filled variant unless noted).
  static const String calendar = 'calendar';
  static const String clock = 'clock';
  static const String location = 'location';
  static const String search = 'search';
  static const String bell = 'bell';
  static const String eye = 'eye';
  static const String download = 'download';
  static const String edit = 'edit';
  static const String star = 'star';
  static const String video = 'video';
  static const String hospital = 'hospital';
  static const String bag = 'bag';
  static const String records = 'records';
  static const String back = 'back';
  static const String close = 'close'; // bold only
  static const String closeCircle = 'close-circle'; // line only
  static const String logout = 'logout';
  static const String moon = 'moon';

  /// Returns the filled/bold variant name for [name] (falls back to [name]).
  static String bold(String name) => '$name-bold';
}

/// Renders a Medibook icon from its SVG asset, recolored to [color]
/// (mirrors the design system's `currentColor` painting).
///
/// [size] is the raw design px; it is `.r`-scaled here so a square glyph scales
/// uniformly. Unknown assets render nothing (the DS `Icon` returned `null`).
class AppIcon extends StatelessWidget {
  const AppIcon(
    this.name, {
    super.key,
    this.size = 24,
    this.color,
  });

  final String name;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final resolved = color ?? IconTheme.of(context).color ?? const Color(0xFF141414);
    final dimension = size.r;
    return SvgPicture.asset(
      'assets/icons/$name.svg',
      width: dimension,
      height: dimension,
      colorFilter: ColorFilter.mode(resolved, BlendMode.srcIn),
      // Match the design's crisp line rendering; no placeholder needed for
      // bundled assets.
      placeholderBuilder: (_) => SizedBox(width: dimension, height: dimension),
    );
  }
}
