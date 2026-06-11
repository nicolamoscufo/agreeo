import 'package:flutter/material.dart';

/// Daylight design-system tokens, exposed as a [ThemeExtension] so every widget
/// can read them with `Theme.of(context).extension<AgreeoTokens>()!` (or the
/// `context.tokens` helper below) and automatically get the right Light/Dark value.
///
/// Values are copied verbatim from `design_reference/Agreeo Daylight Grid.html`
/// (`DAYLIGHT_LIGHT` / `DAYLIGHT_DARK`). Do NOT hardcode hex in widgets — read here.
@immutable
class AgreeoTokens extends ThemeExtension<AgreeoTokens> {
  const AgreeoTokens({
    required this.brightness,
    required this.bg,
    required this.bg2,
    required this.surface,
    required this.surface2,
    required this.line,
    required this.line2,
    required this.text,
    required this.sub,
    required this.faint,
    required this.red,
    required this.redDeep,
    required this.purple,
    required this.purpleDeep,
    required this.gold,
    required this.green,
    required this.onText,
    required this.glass,
    required this.heroBg,
    required this.grad,
    required this.gradSoft,
  });

  final Brightness brightness;

  /// Scaffold background.
  final Color bg;

  /// Sheet / modal background.
  final Color bg2;

  /// Cards, inputs, containers.
  final Color surface;

  /// Elevated containers.
  final Color surface2;

  /// Hairline borders.
  final Color line;

  /// Emphasized borders.
  final Color line2;

  /// Primary text.
  final Color text;

  /// Secondary text.
  final Color sub;

  /// Tertiary text / placeholders.
  final Color faint;

  /// Primary accent (coral).
  final Color red;

  /// Deep coral / dislike.
  final Color redDeep;

  /// Secondary accent (violet).
  final Color purple;

  /// Deep violet.
  final Color purpleDeep;

  /// Ratings, stars, watchlist.
  final Color gold;

  /// Success / online.
  final Color green;

  /// Text on accent / gradient fills.
  final Color onText;

  /// Glassmorphism fill.
  final Color glass;

  /// Dark hero section background.
  final Color heroBg;

  /// Brand gradient (coral → violet, 135°). Used on CTAs, active chips, progress.
  final LinearGradient grad;

  /// Soft brand gradient (low-alpha) for tinted backgrounds.
  final LinearGradient gradSoft;

  bool get isDark => brightness == Brightness.dark;

  /// Poster / elevated-card shadow (black, blur 26, y10). Alpha differs by mode.
  BoxShadow get posterShadow => BoxShadow(
        color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.18),
        blurRadius: 26,
        offset: const Offset(0, 10),
      );

  /// Accent glow placed under gradient buttons.
  BoxShadow get accentGlow => BoxShadow(
        color: purple.withValues(alpha: 0.45),
        blurRadius: 26,
        offset: const Offset(0, 10),
        spreadRadius: -8,
      );

  /// The two stop colors of the brand gradient, for shaders / foregrounds.
  List<Color> get gradColors => grad.colors;

  static const _gradBegin = Alignment.topLeft;
  static const _gradEnd = Alignment.bottomRight;

  static const AgreeoTokens light = AgreeoTokens(
    brightness: Brightness.light,
    bg: Color(0xFFF7F2EA),
    bg2: Color(0xFFFCF8F1),
    surface: Color(0xFFFFFFFF),
    surface2: Color(0xFFF1EADF),
    line: Color.fromRGBO(28, 22, 16, 0.09),
    line2: Color.fromRGBO(28, 22, 16, 0.16),
    text: Color(0xFF221A14),
    sub: Color.fromRGBO(34, 26, 20, 0.62),
    faint: Color.fromRGBO(34, 26, 20, 0.42),
    red: Color(0xFFEF563B),
    redDeep: Color(0xFFD8442B),
    purple: Color(0xFF6B45F0),
    purpleDeep: Color(0xFF5A33E0),
    gold: Color(0xFFC9890F),
    green: Color(0xFF1E9E73),
    onText: Color(0xFFFFF8F0),
    glass: Color.fromRGBO(255, 255, 255, 0.82),
    heroBg: Color(0xFF1A120C),
    grad: LinearGradient(
      begin: _gradBegin,
      end: _gradEnd,
      colors: [Color(0xFFEF563B), Color(0xFF6B45F0)],
    ),
    gradSoft: LinearGradient(
      begin: _gradBegin,
      end: _gradEnd,
      colors: [Color.fromRGBO(239, 86, 59, 0.10), Color.fromRGBO(107, 69, 240, 0.10)],
    ),
  );

  static const AgreeoTokens dark = AgreeoTokens(
    brightness: Brightness.dark,
    bg: Color(0xFF161310),
    bg2: Color(0xFF1E1A16),
    surface: Color(0xFF221D18),
    surface2: Color(0xFF2C251F),
    line: Color.fromRGBO(255, 255, 255, 0.08),
    line2: Color.fromRGBO(255, 255, 255, 0.15),
    text: Color(0xFFF7F0E8),
    sub: Color.fromRGBO(247, 240, 232, 0.62),
    faint: Color.fromRGBO(247, 240, 232, 0.40),
    red: Color(0xFFFF6F52),
    redDeep: Color(0xFFE8542F),
    purple: Color(0xFF9B7BFF),
    purpleDeep: Color(0xFF7A5AF0),
    gold: Color(0xFFFFC24B),
    green: Color(0xFF46D4A0),
    onText: Color(0xFF1A120C),
    glass: Color.fromRGBO(34, 29, 24, 0.82),
    heroBg: Color(0xFF161310),
    grad: LinearGradient(
      begin: _gradBegin,
      end: _gradEnd,
      colors: [Color(0xFFFF6F52), Color(0xFF9B7BFF)],
    ),
    gradSoft: LinearGradient(
      begin: _gradBegin,
      end: _gradEnd,
      colors: [Color.fromRGBO(255, 111, 82, 0.16), Color.fromRGBO(155, 123, 255, 0.16)],
    ),
  );

  @override
  AgreeoTokens copyWith({
    Brightness? brightness,
    Color? bg,
    Color? bg2,
    Color? surface,
    Color? surface2,
    Color? line,
    Color? line2,
    Color? text,
    Color? sub,
    Color? faint,
    Color? red,
    Color? redDeep,
    Color? purple,
    Color? purpleDeep,
    Color? gold,
    Color? green,
    Color? onText,
    Color? glass,
    Color? heroBg,
    LinearGradient? grad,
    LinearGradient? gradSoft,
  }) {
    return AgreeoTokens(
      brightness: brightness ?? this.brightness,
      bg: bg ?? this.bg,
      bg2: bg2 ?? this.bg2,
      surface: surface ?? this.surface,
      surface2: surface2 ?? this.surface2,
      line: line ?? this.line,
      line2: line2 ?? this.line2,
      text: text ?? this.text,
      sub: sub ?? this.sub,
      faint: faint ?? this.faint,
      red: red ?? this.red,
      redDeep: redDeep ?? this.redDeep,
      purple: purple ?? this.purple,
      purpleDeep: purpleDeep ?? this.purpleDeep,
      gold: gold ?? this.gold,
      green: green ?? this.green,
      onText: onText ?? this.onText,
      glass: glass ?? this.glass,
      heroBg: heroBg ?? this.heroBg,
      grad: grad ?? this.grad,
      gradSoft: gradSoft ?? this.gradSoft,
    );
  }

  @override
  AgreeoTokens lerp(covariant ThemeExtension<AgreeoTokens>? other, double t) {
    if (other is! AgreeoTokens) return this;
    return AgreeoTokens(
      brightness: t < 0.5 ? brightness : other.brightness,
      bg: Color.lerp(bg, other.bg, t)!,
      bg2: Color.lerp(bg2, other.bg2, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surface2: Color.lerp(surface2, other.surface2, t)!,
      line: Color.lerp(line, other.line, t)!,
      line2: Color.lerp(line2, other.line2, t)!,
      text: Color.lerp(text, other.text, t)!,
      sub: Color.lerp(sub, other.sub, t)!,
      faint: Color.lerp(faint, other.faint, t)!,
      red: Color.lerp(red, other.red, t)!,
      redDeep: Color.lerp(redDeep, other.redDeep, t)!,
      purple: Color.lerp(purple, other.purple, t)!,
      purpleDeep: Color.lerp(purpleDeep, other.purpleDeep, t)!,
      gold: Color.lerp(gold, other.gold, t)!,
      green: Color.lerp(green, other.green, t)!,
      onText: Color.lerp(onText, other.onText, t)!,
      glass: Color.lerp(glass, other.glass, t)!,
      heroBg: Color.lerp(heroBg, other.heroBg, t)!,
      grad: LinearGradient.lerp(grad, other.grad, t)!,
      gradSoft: LinearGradient.lerp(gradSoft, other.gradSoft, t)!,
    );
  }
}

/// Convenience accessor: `context.tokens.red`.
extension AgreeoTokensX on BuildContext {
  AgreeoTokens get tokens =>
      Theme.of(this).extension<AgreeoTokens>() ?? AgreeoTokens.dark;
}
