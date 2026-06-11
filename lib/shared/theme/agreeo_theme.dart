import 'package:agreeo/shared/theme/agreeo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Builds the Daylight [ThemeData] for the given [brightness].
///
/// Colors come exclusively from [AgreeoTokens] (registered under `extensions`),
/// so widgets read `context.tokens.*` rather than the ColorScheme where possible.
/// Display/headline/title use Bricolage Grotesque (w800); body/label use Manrope.
ThemeData buildAgreeoTheme(Brightness brightness) {
  final tokens =
      brightness == Brightness.dark ? AgreeoTokens.dark : AgreeoTokens.light;

  final colorScheme = ColorScheme(
    brightness: brightness,
    primary: tokens.red,
    onPrimary: tokens.onText,
    secondary: tokens.purple,
    onSecondary: tokens.onText,
    tertiary: tokens.gold,
    onTertiary: tokens.onText,
    surface: tokens.surface,
    onSurface: tokens.text,
    surfaceContainerHighest: tokens.surface2,
    onSurfaceVariant: tokens.sub,
    outline: tokens.line2,
    outlineVariant: tokens.line,
    error: tokens.redDeep,
    onError: tokens.onText,
  );

  // Body/label in Manrope; display/headline/title in Bricolage Grotesque w800.
  final manrope = GoogleFonts.manropeTextTheme();
  final display = GoogleFonts.bricolageGrotesqueTextTheme();

  TextStyle disp(TextStyle? s) => (s ?? const TextStyle()).copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: -0.5,
        color: tokens.text,
      );
  TextStyle body(TextStyle? s) =>
      (s ?? const TextStyle()).copyWith(color: tokens.text);

  final textTheme = TextTheme(
    displayLarge: disp(display.displayLarge),
    displayMedium: disp(display.displayMedium),
    displaySmall: disp(display.displaySmall),
    headlineLarge: disp(display.headlineLarge),
    headlineMedium: disp(display.headlineMedium),
    headlineSmall: disp(display.headlineSmall),
    titleLarge: disp(display.titleLarge),
    titleMedium: disp(display.titleMedium).copyWith(letterSpacing: -0.3),
    titleSmall: disp(display.titleSmall).copyWith(letterSpacing: -0.2),
    bodyLarge: body(manrope.bodyLarge),
    bodyMedium: body(manrope.bodyMedium),
    bodySmall: body(manrope.bodySmall).copyWith(color: tokens.sub),
    labelLarge: body(manrope.labelLarge).copyWith(fontWeight: FontWeight.w700),
    labelMedium: body(manrope.labelMedium).copyWith(fontWeight: FontWeight.w600),
    labelSmall: body(manrope.labelSmall).copyWith(color: tokens.sub),
  );

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: tokens.bg,
    canvasColor: tokens.bg,
    textTheme: textTheme,
    extensions: <ThemeExtension<dynamic>>[tokens],
    splashColor: tokens.red.withValues(alpha: 0.08),
    highlightColor: tokens.red.withValues(alpha: 0.05),
    dividerTheme: DividerThemeData(color: tokens.line, thickness: 1),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: tokens.text,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: textTheme.titleLarge,
      iconTheme: IconThemeData(color: tokens.text),
    ),
    cardTheme: CardThemeData(
      color: tokens.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(color: tokens.line, width: 1),
      ),
      elevation: 0,
      margin: EdgeInsets.zero,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: tokens.surface,
      hintStyle: TextStyle(color: tokens.faint),
      labelStyle: TextStyle(color: tokens.sub),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: tokens.line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: tokens.line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: tokens.red, width: 1.5),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: tokens.surface,
      selectedColor: tokens.red,
      side: BorderSide(color: tokens.line),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      labelStyle: TextStyle(color: tokens.sub, fontWeight: FontWeight.w600),
      secondaryLabelStyle:
          TextStyle(color: tokens.onText, fontWeight: FontWeight.w700),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 52),
        backgroundColor: tokens.red,
        foregroundColor: tokens.onText,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontWeight: FontWeight.w800),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 52),
        foregroundColor: tokens.text,
        backgroundColor: tokens.surface,
        side: BorderSide(color: tokens.line2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: tokens.red,
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: tokens.surface2,
      contentTextStyle: TextStyle(color: tokens.text),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: tokens.line2),
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: tokens.bg2,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: tokens.bg2,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: tokens.red),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: <TargetPlatform, PageTransitionsBuilder>{
        TargetPlatform.android: _AgPageTransitionsBuilder(),
        TargetPlatform.iOS: _AgPageTransitionsBuilder(),
        TargetPlatform.macOS: _AgPageTransitionsBuilder(),
        TargetPlatform.windows: _AgPageTransitionsBuilder(),
        TargetPlatform.linux: _AgPageTransitionsBuilder(),
      },
    ),
  );
}

/// Daylight page transition: slide-up + fade (easeOutCubic). Route duration
/// (~300ms) is supplied by the route itself.
class _AgPageTransitionsBuilder extends PageTransitionsBuilder {
  const _AgPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 0.03), end: Offset.zero).animate(curved),
        child: child,
      ),
    );
  }
}
