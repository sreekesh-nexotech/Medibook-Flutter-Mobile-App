import 'package:flutter/material.dart';

/// Medibook color tokens.
///
/// Ported verbatim from the design-system token layer
/// (`_ds/.../tokens/colors.css`). Names mirror the CSS custom properties so the
/// design spec keeps reading true against the code. Color is used sparingly —
/// navy + white + grey does ~90% of the work.
///
/// Do NOT introduce literal hex anywhere else in the app; reference these.
abstract final class AppColors {
  AppColors._();

  // ---- Primary (brand navy / blue ramp) ----
  static const Color primary100 = Color(0xFFE6ECFA); // tint surfaces, soft chips
  static const Color primary200 = Color(0xFFB0C4EF);
  static const Color primary300 = Color(0xFF739EE4);
  static const Color primary400 = Color(0xFF4979BE);
  static const Color primary500 = Color(0xFF325689);
  static const Color primary600 = Color(0xFF1D3557); // BRAND
  static const Color primary700 = Color(0xFF0A172A); // deepest

  /// The single canonical brand color (Figma token "P500" / "Primary").
  static const Color brand = primary600;
  static const Color brandDeep = primary700;

  // ---- Accent blues (links / highlight numerals) ----
  static const Color accentBlue = Color(0xFF1648CE); // "Your Token", "View All"
  static const Color infoBlue = Color(0xFF006BD5);

  // ---- Neutral grey ramp ----
  static const Color grey100 = Color(0xFFEBECEE); // hairlines, track
  static const Color grey200 = Color(0xFFC1C5C9);
  static const Color grey300 = Color(0xFF999EA3); // radio/checkbox hairlines
  static const Color grey400 = Color(0xFF75797D);
  static const Color grey500 = Color(0xFF535659);
  static const Color grey600 = Color(0xFF333537);
  static const Color coal = Color(0xFF1C1C1C); // toast background
  static const Color ink = Color(0xFF141414); // true text black

  // ---- Surfaces ----
  static const Color bgApp = Color(0xFFF3F3F3); // base background behind cards
  static const Color surface = Color(0xFFFFFFFF); // cards, sheets
  static const Color surfaceAlt = Color(0xFFF7F8FA); // input fields, inset rows
  static const Color surfaceTint = Color(0xFFE6ECFA); // primary-100 wash

  // ---- Borders ----
  static const Color border = Color(0xFFD1D4DB); // input + card borders
  static const Color borderSubtle = Color(0xFFEBECEE); // faint dividers

  // ---- Text ----
  static const Color textStrong = Color(0xFF1D3557); // navy headings
  static const Color textPrimary = Color(0xFF141414); // default body heading
  static const Color textBody = Color(0xFF5E5D5D); // paragraph

  /// Captions, placeholders, meta text.
  ///
  /// A11Y (audit §3.3.7): this was `#8E98A8`, which measures **2.91:1** on
  /// `surface` — below the WCAG AA 4.5:1 floor for body text. Darkened to
  /// `#646E7B`, which measures 5.17:1 on `surface` (#FFFFFF), 4.66:1 on
  /// [bgApp] (#F3F3F3) and 4.87:1 on [surfaceAlt] (#F7F8FA) — every surface
  /// this token is painted on passes. The original value survives as
  /// [textMutedDecorative] for non-text use only.
  static const Color textMuted = Color(0xFF646E7B);

  /// The pre-fix `textMuted` value (`#8E98A8`, 2.91:1 on white).
  ///
  /// **Never use this for text.** It exists only for decorative, non-textual
  /// marks (hairlines, inactive tick marks, chart gridlines) where WCAG's text
  /// contrast minimum does not apply.
  static const Color textMutedDecorative = Color(0xFF8E98A8);

  /// Inactive bottom-nav / inactive tab label colour.
  ///
  /// A11Y (audit §3.3.7): the nav previously reused [grey300] (`#999EA3`,
  /// **2.70:1** on `surface`). [grey300] is also the checkbox/radio hairline
  /// colour, so darkening it would have changed decorative strokes; this is a
  /// dedicated text token instead. `#6A6E72` measures 5.14:1 on `surface`.
  static const Color textInactive = Color(0xFF6A6E72);

  static const Color textOnBrand = Color(0xFFFFFFFF);
  static const Color textLink = Color(0xFF1648CE);

  // ---- Semantic ----
  static const Color success = Color(0xFF2E9E5B);
  static const Color successSoft = Color(0xFFBFE6CC); // "Completed" pill bg
  static const Color successText = Color(0xFF1B6B3A);
  static const Color danger = Color(0xFFE14C4C);
  static const Color dangerSoft = Color(0xFFF3C2C2); // "Pending"/"Cancelled" pill bg
  static const Color dangerText = Color(0xFFB23535);
  static const Color warning = Color(0xFFF5A623); // rating stars
  static const Color warningSoft = Color(0xFFFCE6BE);

  // ---- Overlays ----
  static const Color scrim = Color(0x73141414); // rgba(20,20,20,0.45) modal scrim
}
