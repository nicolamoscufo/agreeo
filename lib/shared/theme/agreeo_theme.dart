import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

ThemeData buildAgreeoTheme(Brightness brightness) {
  // Ignoriamo la brightness in ingresso e forziamo la dark mode
  // Il tema "Cinema Popcorn" è progettato specificamente per ambienti scuri.
  const isDark = true;

  // Palette Cinema Popcorn Edition
  const cinematicRed = Color(0xFFE50914);
  const popcornWhite = Color(0xFFFFFFFF);
  const anthraciteBlack = Color(0xFF1E1E1E);
  const darkSurface = Color(0xFF2A2A2A);
  const kernelGold = Color(0xFFFFC107);

  final colorScheme = ColorScheme.dark(
    primary: cinematicRed,
    secondary: popcornWhite,
    surface: anthraciteBlack,
    surfaceContainerHighest: darkSurface,
    onPrimary: Colors.white,
    onSurface: Colors.white,
    tertiary: kernelGold,
  );

  final baseTextTheme = GoogleFonts.spaceGroteskTextTheme();

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: colorScheme.surface,
    textTheme: baseTextTheme.apply(
      bodyColor: colorScheme.onSurface,
      displayColor: colorScheme.onSurface,
    ),
    cardTheme: CardThemeData(
      color: colorScheme.surfaceContainerHighest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28),
        side: BorderSide(
          color: popcornWhite.withValues(alpha: 0.1),
          width: 1,
        ), // Bordo sottile bianco
      ),
      elevation: 0,
      margin: EdgeInsets.zero,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: colorScheme.onSurface,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: baseTextTheme.titleLarge?.copyWith(
        color: colorScheme.onSurface,
        fontWeight: FontWeight.w700,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: colorScheme.surfaceContainerHighest,
      hintStyle: TextStyle(color: colorScheme.onSurfaceVariant),
      labelStyle: TextStyle(color: colorScheme.onSurfaceVariant),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: BorderSide(
          color: colorScheme.onSurface.withValues(
            alpha: 0.1,
          ), // Grigio molto tenue
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: BorderSide(color: colorScheme.primary, width: 1.4),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    ),
    chipTheme: ChipThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      side: BorderSide.none,
      backgroundColor: colorScheme.surfaceContainerHighest,
      selectedColor: colorScheme.primary,
      labelStyle: TextStyle(color: colorScheme.onSurface),
      secondaryLabelStyle: TextStyle(color: colorScheme.onPrimary),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        // FIX CRITICO: Cambiato Size.fromHeight in Size(0, 56)
        // Questo impedisce al bottone di espandersi all'infinito e far crashare le Row.
        minimumSize: const Size(0, 56),
        backgroundColor: cinematicRed,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        // FIX CRITICO: Anche qui, rimuoviamo l'espansione infinita
        minimumSize: const Size(0, 56),
        foregroundColor: popcornWhite,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        side: BorderSide(color: popcornWhite.withValues(alpha: 0.5)),
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: anthraciteBlack,
      contentTextStyle: const TextStyle(color: Colors.white),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: cinematicRed, width: 1),
      ),
    ),
  );
}
