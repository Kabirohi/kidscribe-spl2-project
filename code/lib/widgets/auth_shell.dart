import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_colors.dart';
import 'common.dart';
import 'fun.dart';
import 'mascot.dart';

/// The frame shared by Log in and Sign up.
///
/// Phone / portrait: a violet header with the mascot, then a white sheet with
/// a wavy top edge that holds the form.
/// Tablet / landscape: violet brand panel on the left, form on the right.
class AuthShell extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;
  final bool showBack;

  const AuthShell({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
    this.showBack = false,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: LayoutBuilder(
        builder: (context, c) {
          final wide = c.maxWidth >= 820;
          return wide ? _wide(context) : _narrow(context, c);
        },
      ),
    );
  }

  Widget _heading() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: GoogleFonts.nunito(
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  height: 1.1,
                  color: AppColors.textDark)),
          const SizedBox(height: 8),
          Text(subtitle,
              style:
                  kid(16, weight: FontWeight.w600, color: AppColors.textMuted)),
          const SizedBox(height: 26),
        ],
      );

  // ---- Tablet / landscape -------------------------------------------
  Widget _wide(BuildContext context) {
    return Row(
      children: [
        Expanded(
          flex: 5,
          child: Container(
            decoration: const BoxDecoration(gradient: AppColors.heroGradient),
            child: SafeArea(
              child: Stack(
                children: [
                  const Positioned.fill(
                      child: FloatingShapes(count: 14, opacity: 0.28, colors: [
                    Colors.white,
                    AppColors.sun,
                    AppColors.pink,
                    Color(0xFF4CC9F0)
                  ])),
                  if (showBack)
                    const Positioned(
                      left: 24,
                      top: 20,
                      child: KidBackButton(onDark: true),
                    ),
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(40),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const PennyMascot(size: 230),
                          const SizedBox(height: 10),
                          Text('KidScribe',
                              style: GoogleFonts.nunito(
                                  fontSize: 60,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white)),
                          const SizedBox(height: 4),
                          Text('Little hands. Big handwriting.',
                              style: kid(20,
                                  weight: FontWeight.w700,
                                  color: Colors.white.withValues(alpha: 0.9))),
                          const SizedBox(height: 34),
                          const _Perk(Icons.gesture_rounded,
                              'Trace strokes, letters and words'),
                          const _Perk(Icons.auto_awesome_rounded,
                              'Smart handwriting check'),
                          const _Perk(Icons.emoji_events_rounded,
                              'Badges, streaks and games'),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Expanded(
          flex: 6,
          child: Container(
            color: Colors.white,
            child: SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(40),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 460),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [_heading(), child],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ---- Phone / portrait ---------------------------------------------
  Widget _narrow(BuildContext context, BoxConstraints c) {
    final keyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;
    final heroHeight = (c.maxHeight * 0.27).clamp(170.0, 260.0).toDouble();
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Container(
      decoration: const BoxDecoration(gradient: AppColors.heroGradient),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            if (!keyboardOpen)
              SizedBox(
                height: heroHeight,
                child: Stack(
                  children: [
                    const Positioned.fill(
                        child: FloatingShapes(
                            count: 14,
                            opacity: 0.28,
                            colors: [
                          Colors.white,
                          AppColors.sun,
                          AppColors.pink,
                          Color(0xFF4CC9F0)
                        ])),
                    if (showBack)
                      const Positioned(
                        left: 16,
                        top: 8,
                        child: KidBackButton(onDark: true),
                      ),
                    Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const PennyMascot(size: 104),
                          Text('KidScribe',
                              style: GoogleFonts.nunito(
                                  fontSize: 34,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white)),
                        ],
                      ),
                    ),
                  ],
                ),
              )
            else if (showBack)
              const Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(16, 8, 0, 0),
                  child: KidBackButton(onDark: true),
                ),
              ),
            Expanded(
              child: ClipPath(
                clipper: const WaveClipper(),
                child: Container(
                  width: double.infinity,
                  color: Colors.white,
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(24, 40, 24, 24 + bottomInset),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 460),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [_heading(), child],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Perk extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Perk(this.icon, this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 12),
          Text(text,
              style: kid(16, weight: FontWeight.w700, color: Colors.white)),
        ],
      ),
    );
  }
}
