import 'package:flutter/widgets.dart';
import 'package:google_fonts/google_fonts.dart';

/// Daylight type scale, exposed as semantic [TextStyle] tokens.
///
/// Why this exists: the app loads its two families through `google_fonts`, which
/// registers them under variant-suffixed names (e.g. `Bricolage Grotesque_w800`),
/// NOT the plain `Bricolage Grotesque`. Hand-written `fontFamily: 'Bricolage
/// Grotesque'` / `'Manrope'` literals therefore never match a loaded font and
/// silently fall back to the platform sans. Always source type from here (or the
/// [TextTheme]); never write a `fontFamily` string in a widget again.
///
/// These tokens carry **family + size + weight + tracking + line-height only**.
/// Color is intentionally left off so each call site keeps applying its
/// `context.tokens.*` color (`.copyWith(color: ...)`), which keeps the contrast
/// decisions reviewable independently of the type scale.
///
/// The scale is fixed (app UI, not fluid) on a ~1.12–1.18 ratio:
///
/// | Token       | Family    | Size | Weight | Role                                  |
/// |-------------|-----------|------|--------|---------------------------------------|
/// | display     | Bricolage | 30   | w800   | Hero one-offs, big empty states       |
/// | h1          | Bricolage | 25   | w800   | Screen titles, movie titles           |
/// | h2          | Bricolage | 22   | w800   | Profile name, large section titles    |
/// | h3          | Bricolage | 19   | w800   | Card titles                           |
/// | h4          | Bricolage | 16   | w800   | Small headings, inline section labels |
/// | lead        | Manrope   | 16   | w400   | Lead paragraphs, larger body          |
/// | body        | Manrope   | 14.5 | w400   | Default body copy                     |
/// | caption     | Manrope   | 13   | w400   | Secondary text, metadata              |
/// | micro       | Manrope   | 11.5 | w400   | Tiny meta, timestamps                 |
/// | label       | Manrope   | 13   | w700   | Buttons, actions, emphasized labels   |
/// | labelSm     | Manrope   | 11.5 | w700   | Chips, pills, small emphasized labels |
/// | overline    | Manrope   | 11.5 | w700   | All-caps eyebrows (positive tracking) |
abstract final class AgText {
  AgText._();

  static TextStyle _display(
    double size, {
    required double letterSpacing,
    required double height,
    FontWeight weight = FontWeight.w800,
  }) =>
      GoogleFonts.bricolageGrotesque(
        fontSize: size,
        fontWeight: weight,
        letterSpacing: letterSpacing,
        height: height,
      );

  static TextStyle _sans(
    double size, {
    required double height,
    FontWeight weight = FontWeight.w400,
    double letterSpacing = 0,
  }) =>
      GoogleFonts.manrope(
        fontSize: size,
        fontWeight: weight,
        height: height,
        letterSpacing: letterSpacing,
      );

  // Display / headings — Bricolage Grotesque w800.
  static TextStyle get display =>
      _display(30, letterSpacing: -0.8, height: 1.02);
  static TextStyle get h1 => _display(25, letterSpacing: -0.6, height: 1.04);
  static TextStyle get h2 => _display(22, letterSpacing: -0.5, height: 1.08);
  static TextStyle get h3 => _display(19, letterSpacing: -0.4, height: 1.12);
  static TextStyle get h4 => _display(16, letterSpacing: -0.3, height: 1.18);

  // Body — Manrope, regular weight.
  static TextStyle get lead => _sans(16, height: 1.5);
  static TextStyle get body => _sans(14.5, height: 1.55);
  static TextStyle get caption => _sans(13, height: 1.45);
  static TextStyle get micro => _sans(11.5, height: 1.4);

  // Labels — Manrope, bold for UI affordances.
  static TextStyle get label => _sans(13, height: 1.2, weight: FontWeight.w700);
  static TextStyle get labelSm =>
      _sans(11.5, height: 1.2, weight: FontWeight.w700);
  static TextStyle get overline =>
      _sans(11.5, height: 1.3, weight: FontWeight.w700, letterSpacing: 0.4);
}
