import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import '../blocs/auth/auth_bloc.dart';
import '../theme/app_colors.dart';
import '../widgets/fun.dart';
import '../widgets/mascot.dart';
import 'home_screen.dart';
import 'login_screen.dart';

/// Decides which screen to show, by listening to AuthBloc.
///
/// The only thing it adds is the animated intro: it plays once when the app
/// opens, even if the login check finishes sooner.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _introDone = false;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        final Widget screen;
        if (!_introDone || state.status == AuthStatus.unknown) {
          screen = _Splash(
            key: const ValueKey('splash'),
            onDone: () => setState(() => _introDone = true),
          );
        } else if (state.status == AuthStatus.authenticated) {
          screen = const HomeScreen(key: ValueKey('home'));
        } else {
          screen = const LoginScreen(key: ValueKey('login'));
        }
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 550),
          switchInCurve: Curves.easeOutBack,
          transitionBuilder: (child, a) => FadeTransition(
            opacity: a,
            child: ScaleTransition(
                scale: Tween(begin: 0.92, end: 1.0).animate(a), child: child),
          ),
          child: screen,
        );
      },
    );
  }
}

/// The opening show: Penny drops in, the name pops up letter by letter,
/// then a violet bubble bursts across the screen.
class _Splash extends StatefulWidget {
  final VoidCallback onDone;
  const _Splash({super.key, required this.onDone});

  @override
  State<_Splash> createState() => _SplashState();
}

class _SplashState extends State<_Splash> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 2800));

  static const _name = 'KidScribe';
  static const _letterColors = [
    Colors.white,
    AppColors.sun,
    Colors.white,
    AppColors.pink,
    Colors.white,
    AppColors.sun,
    Colors.white,
    Color(0xFF4CC9F0),
    Colors.white,
  ];

  @override
  void initState() {
    super.initState();
    _c.forward().whenComplete(() {
      if (mounted) widget.onDone();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  double _seg(double from, double to, [Curve curve = Curves.linear]) =>
      curve.transform(((_c.value - from) / (to - from)).clamp(0.0, 1.0));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.accent,
      body: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final size = MediaQuery.sizeOf(context);
          final drop = _seg(0.0, 0.35, Curves.bounceOut);
          final burst = _seg(0.80, 1.0, Curves.easeInCubic);
          final maxR =
              math.sqrt(size.width * size.width + size.height * size.height);
          return Stack(
            fit: StackFit.expand,
            alignment: Alignment.center,
            children: [
              // Sunburst rays turning slowly behind everything.
              Positioned.fill(
                child: CustomPaint(painter: _RaysPainter(_c.value * 0.6)),
              ),
              const Positioned.fill(
                  child: FloatingShapes(
                      count: 16,
                      opacity: 0.5,
                      colors: [Colors.white, AppColors.sun, AppColors.pink])),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Transform.translate(
                    offset: Offset(0, -size.height * 0.6 * (1 - drop)),
                    child: const PennyMascot(size: 180),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (int i = 0; i < _name.length; i++) _letter(i),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Opacity(
                    opacity: _seg(0.62, 0.75),
                    child: Text('Little hands, big letters!',
                        style: GoogleFonts.nunito(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Colors.white)),
                  ),
                ],
              ),
              // The violet bubble that wipes to the next screen.
              if (burst > 0)
                Positioned.fill(
                  child: CustomPaint(
                    painter: _BurstPainter(burst * maxR),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _letter(int i) {
    final start = 0.28 + i * 0.035;
    final v = _seg(start, start + 0.22, Curves.elasticOut);
    return Transform.translate(
      offset: Offset(0, 40 * (1 - v)),
      child: Transform.scale(
        scale: v,
        child: Text(
          _name[i],
          style: GoogleFonts.fredoka(
            fontSize: 54,
            fontWeight: FontWeight.w700,
            color: _letterColors[i % _letterColors.length],
            shadows: const [
              Shadow(color: AppColors.accentDark, offset: Offset(0, 4)),
            ],
          ),
        ),
      ),
    );
  }
}

class _RaysPainter extends CustomPainter {
  final double turn;
  _RaysPainter(this.turn);

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.longestSide;
    final p = Paint()..color = Colors.white.withValues(alpha: 0.10);
    const n = 14;
    for (int i = 0; i < n; i++) {
      final a = turn * math.pi + i * 2 * math.pi / n;
      final path = Path()
        ..moveTo(c.dx, c.dy)
        ..lineTo(c.dx + math.cos(a) * r, c.dy + math.sin(a) * r)
        ..lineTo(c.dx + math.cos(a + math.pi / n) * r,
            c.dy + math.sin(a + math.pi / n) * r)
        ..close();
      canvas.drawPath(path, p);
    }
  }

  @override
  bool shouldRepaint(covariant _RaysPainter old) => old.turn != turn;
}

class _BurstPainter extends CustomPainter {
  final double radius;
  _BurstPainter(this.radius);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawCircle(
        size.center(Offset.zero), radius, Paint()..color = AppColors.primary);
  }

  @override
  bool shouldRepaint(covariant _BurstPainter old) => old.radius != radius;
}
