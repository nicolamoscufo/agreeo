import 'package:flutter/material.dart';

/// Centralized color constants for the Cinema Popcorn palette.
///
/// All screens MUST reference these named tokens instead of raw hex values
/// to keep the visual identity coherent across the entire app.
abstract final class AgreeoColors {
  // ── Primary brand ──
  /// Netflix-inspired cinematic red — primary accent, buttons, active states.
  static const cinematicRed = Color(0xFFE50914);

  /// Pure white — text, secondary UI, clean contrast.
  static const popcornWhite = Color(0xFFFFFFFF);

  // ── Surfaces ──
  /// Main scaffold / surface background.
  static const anthraciteBlack = Color(0xFF1E1E1E);

  /// Cards, elevated containers, bottom sheets.
  static const darkSurface = Color(0xFF2A2A2A);

  /// Deep true-black for immersive screens (swipe, voting).
  static const deepBlack = Color(0xFF121212);

  /// Absolute black for gradient starts.
  static const trueBlack = Color(0xFF0A0A0A);

  // ── Accents ──
  /// Gold highlight — ratings, stars, watchlist badges.
  static const kernelGold = Color(0xFFFFC107);

  // ── Semantic shades (derived from the palette) ──
  /// Muted red for subtle tinted backgrounds (error, dislike).
  static Color redTint = cinematicRed.withValues(alpha: 0.15);

  /// Muted gold for subtle tinted backgrounds (watchlist, rating).
  static Color goldTint = kernelGold.withValues(alpha: 0.15);

  /// Muted white for subtle badges (watched, seen).
  static Color whiteTint = popcornWhite.withValues(alpha: 0.12);
}
