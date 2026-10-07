import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Canonical Medibook icon names — the Iconsax line/bold set the design
/// system's components render (`Button` leading icons, `IconButton`, `Input`
/// prefixes, `Rating` stars) plus the custom bottom-nav glyphs. Each maps to an
/// SVG asset exported from the design system's exact path data
/// (`assets/icons/<name>.svg`). Glyphs paint with a single color (the design's
/// `currentColor` semantics).
///
/// The screens themselves draw a second family inline — see [PhIcon] and
/// [DeptIcon]; pick the family the design uses at that spot, not by meaning.
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

/// The Phosphor glyphs the design draws inline (regular weight unless the
/// name says otherwise): meta rows, empty states, notices, chips, sheet
/// close/clear buttons, section marks and the onboarding tags. Exact path
/// data from the design's inline `<svg viewBox="0 0 256 256">` markup and its
/// `assets/ui/*-navy.svg` files (`assets/icons/ph-<name>.svg`).
abstract final class PhIcon {
  PhIcon._();

  static const String magnifyingGlass = 'ph-magnifying-glass';
  static const String mapPin = 'ph-map-pin';
  static const String starFill = 'ph-star-fill';
  static const String funnelSimple = 'ph-funnel-simple';
  static const String clock = 'ph-clock';
  static const String videoCamera = 'ph-video-camera';
  static const String calendarBlank = 'ph-calendar-blank';
  static const String plus = 'ph-plus';
  static const String folder = 'ph-folder';
  static const String pencilSimple = 'ph-pencil-simple';
  static const String bell = 'ph-bell';
  static const String caretLeft = 'ph-caret-left';
  static const String x = 'ph-x';
  static const String xCircle = 'ph-x-circle';
  static const String checkBold = 'ph-check-bold';
  static const String firstAid = 'ph-first-aid';
  static const String user = 'ph-user';
  static const String eye = 'ph-eye';
  static const String buildings = 'ph-buildings';
  static const String downloadSimple = 'ph-download-simple';
  static const String warningCircleFill = 'ph-warning-circle-fill';
}

/// The Healthicons department marks the design uses for speciality tiles and
/// chips (`assets/health-icons/<name>.svg`, 48-unit box): one per seeded
/// department plus the Home "Available Services" set
/// (`assets/icons/dept-<name>.svg`).
abstract final class DeptIcon {
  DeptIcon._();

  static const String general = 'dept-general';
  static const String cardiology = 'dept-cardiology';
  static const String orthopedics = 'dept-orthopedics';
  static const String dermatology = 'dept-dermatology';
  static const String womensHealth = 'dept-womens-health';
  static const String paediatrics = 'dept-paediatrics';
  static const String ent = 'dept-ent';
  static const String mentalWellness = 'dept-mental-wellness';
  static const String eyeCare = 'dept-eye-care';
  static const String dental = 'dept-dental';
  static const String neurology = 'dept-neurology';
  static const String pulmonology = 'dept-pulmonology';
  static const String gastroenterology = 'dept-gastroenterology';
  static const String nephrology = 'dept-nephrology';
  static const String urology = 'dept-urology';
  static const String endocrinology = 'dept-endocrinology';
}

/// Renders a Medibook icon ([MedIcon], [PhIcon] or [DeptIcon]) from its SVG
/// asset, recolored to [color] (mirrors the design's `currentColor` painting).
///
/// [size] is the raw design px; it is `.r`-scaled here so a square glyph scales
/// uniformly. Unknown assets render nothing (the DS `Icon` returned `null`).
class AppIcon extends StatelessWidget {
  const AppIcon(this.name, {super.key, this.size = 24, this.color});

  final String name;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final resolved =
        color ?? IconTheme.of(context).color ?? const Color(0xFF141414);
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
