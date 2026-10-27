import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';
import '../widgets/fun.dart';

/// One place that decides how the whole app looks.
///
/// Material widgets that screens create directly (ElevatedButton, TextButton,
/// SnackBar, switches, progress bars...) pick their style from here, so they
/// match the chunky KidScribe look without every screen restyling them.
class AppTheme {
  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      primary: AppColors.primary,
      secondary: AppColors.accent,
      surface: Colors.white,
      error: AppColors.error,
    );

    final base = GoogleFonts.nunitoTextTheme();
    final text = base.apply(
      bodyColor: AppColors.textDark,
      displayColor: AppColors.textDark,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      primaryColor: AppColors.primary,
      scaffoldBackgroundColor: AppColors.bgStart,
      textTheme: text,
      splashFactory: InkRipple.splashFactory,
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          minimumSize: const Size(64, 50),
          padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 12),
          shape: const StadiumBorder(),
          textStyle:
              GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w800),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          shape: const StadiumBorder(),
          textStyle:
              GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w800),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.textDark,
        contentTextStyle: GoogleFonts.nunito(
            fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.primary,
        linearTrackColor: AppColors.surfaceAlt,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.all(Colors.white),
        trackColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected)
                ? AppColors.primary
                : const Color(0xFFCFCBE6)),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),
      dividerColor: AppColors.line,
      // Every new screen pops in with a springy zoom.
      pageTransitionsTheme: const PageTransitionsTheme(builders: {
        TargetPlatform.android: BouncyPageTransitionsBuilder(),
        TargetPlatform.iOS: BouncyPageTransitionsBuilder(),
        TargetPlatform.windows: BouncyPageTransitionsBuilder(),
        TargetPlatform.macOS: BouncyPageTransitionsBuilder(),
        TargetPlatform.linux: BouncyPageTransitionsBuilder(),
      }),
    );
  }
}
