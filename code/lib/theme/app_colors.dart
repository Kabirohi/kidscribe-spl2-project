import 'package:flutter/material.dart';

/// KidScribe colour palette.
///
/// The look is built on a confident violet (the brand colour), a warm orange
/// for the one big call-to-action on a screen, and a deep indigo for text and
/// the dark home screen. The old names (primary, secondary, accent, purple...)
/// are kept so every screen picks the new look up automatically.
class AppColors {
  // ---- Brand ---------------------------------------------------------
  static const Color primary = Color(0xFF5B3DF5);      // brand violet
  static const Color primaryDark = Color(0xFF3F25C7);  // button "ledge"
  static const Color secondary = Color(0xFF12B5A6);    // teal
  static const Color accent = Color(0xFFFF9F1C);       // call-to-action orange
  static const Color accentDark = Color(0xFFD97F00);   // orange "ledge"
  static const Color purple = Color(0xFF8B5CF6);       // lighter violet
  static const Color pink = Color(0xFFFF5FA2);         // playful highlight
  static const Color sun = Color(0xFFFFC83D);          // sunny yellow

  // ---- Surfaces ------------------------------------------------------
  static const Color bgStart = Color(0xFFF6F4FF);      // lavender white
  static const Color bgEnd = Color(0xFFFFFFFF);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceAlt = Color(0xFFF1EFFA);   // quiet rows / inputs
  static const Color line = Color(0xFFE4DFF7);         // borders + card ledge

  // ---- Dark home -----------------------------------------------------
  static const Color night = Color(0xFF1B1257);        // deep indigo
  static const Color nightLift = Color(0xFF2E2093);    // lighter indigo
  static const Color nightCard = Color(0xFF3A2BB0);    // tiles on dark

  // ---- Text ----------------------------------------------------------
  static const Color textDark = Color(0xFF1F1A4D);     // ink
  static const Color textMuted = Color(0xFF6B6791);    // secondary text
  static const Color textLight = Colors.white;

  // ---- Feedback ------------------------------------------------------
  static const Color error = Color(0xFFE5484D);
  static const Color success = Color(0xFF1FA463);
  static const Color gold = Color(0xFFF59E0B);

  // ---- Gradients -----------------------------------------------------
  static const LinearGradient bgGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [bgStart, bgEnd],
  );

  static const LinearGradient buttonGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primary, purple],
  );

  static const LinearGradient heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF6A4BFF), Color(0xFFB04DFF)],
  );

  static const LinearGradient nightGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [nightLift, night],
  );

  /// A slightly darker copy of [c]; used for the solid "ledge" under the
  /// chunky buttons and cards.
  static Color ledge(Color c, [double amount = 0.14]) {
    final hsl = HSLColor.fromColor(c);
    return hsl
        .withLightness((hsl.lightness - amount).clamp(0.0, 1.0).toDouble())
        .toColor();
  }
}
