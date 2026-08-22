import 'package:flutter/material.dart';

/// A home promo banner slide. Presentation decoration (holds gradient colors),
/// so it lives in the presentation model layer rather than a future domain
/// entity. Immutable, no logic.
class PromoBanner {
  const PromoBanner({
    required this.gradient,
    required this.title,
    required this.body,
    required this.hasImage,
  });

  /// Two-stop gradient (135deg in the design; the UI applies the angle).
  final List<Color> gradient;

  final String title;
  final String body;

  /// Whether the right-masked doctor photo is shown on this slide.
  final bool hasImage;
}
