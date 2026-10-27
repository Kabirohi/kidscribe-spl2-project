import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_colors.dart';

/// Playful motion pieces used all over the app, so every screen feels alive
/// in the same way: things pop in, squish when tapped, wiggle and float.

/// Pops its child in with a springy scale + fade + slide.
/// Give each item in a list a growing [delay] for a staggered entrance.
class PopIn extends StatefulWidget {
  final Widget child;
  final Duration delay;
  final double fromY;

  const PopIn({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.fromY = 30,
  });

  @override
  State<PopIn> createState() => _PopInState();
}

class _PopInState extends State<PopIn> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 700));

  @override
  void initState() {
    super.initState();
    Future.delayed(widget.delay, () {
      if (mounted) _c.forward();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scale = CurvedAnimation(parent: _c, curve: Curves.elasticOut);
    final fade = CurvedAnimation(parent: _c, curve: const Interval(0, 0.4));
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) => Opacity(
        opacity: fade.value,
        child: Transform.translate(
          offset: Offset(0, widget.fromY * (1 - _c.value.clamp(0, 1))),
          child: Transform.scale(scale: 0.6 + 0.4 * scale.value, child: child),
        ),
      ),
      child: widget.child,
    );
  }
}

/// Wraps anything tappable: it squishes down when pressed and springs back.
class Bouncy extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double pressedScale;

  const Bouncy(
      {super.key, required this.child, this.onTap, this.pressedScale = 0.92});

  @override
  State<Bouncy> createState() => _BouncyState();
}

class _BouncyState extends State<Bouncy> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 110),
    reverseDuration: const Duration(milliseconds: 420),
  );

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: enabled ? (_) => _c.forward() : null,
      onTapCancel: enabled ? () => _c.reverse() : null,
      onTapUp: enabled
          ? (_) async {
              await _c.forward();
              _c.reverse();
            }
          : null,
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, child) {
          final curve = _c.status == AnimationStatus.reverse
              ? Curves.elasticOut.flipped
              : Curves.easeOut;
          final v = curve.transform(_c.value);
          return Transform.scale(
              scale: 1 - (1 - widget.pressedScale) * v, child: child);
        },
        child: widget.child,
      ),
    );
  }
}

/// Gently rocks its child side to side (great for icons on tiles).
class Wiggle extends StatefulWidget {
  final Widget child;
  final double angle;
  final Duration period;
  final Duration offset;

  const Wiggle({
    super.key,
    required this.child,
    this.angle = 0.08,
    this.period = const Duration(milliseconds: 2600),
    this.offset = Duration.zero,
  });

  @override
  State<Wiggle> createState() => _WiggleState();
}

class _WiggleState extends State<Wiggle> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: widget.period);

  @override
  void initState() {
    super.initState();
    _c.value =
        (widget.offset.inMilliseconds / widget.period.inMilliseconds) % 1;
    _c.repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) {
        // Quick wiggle in the first fifth, then rest.
        final t = _c.value;
        final a = t < 0.2
            ? math.sin(t / 0.2 * math.pi * 4) * (1 - t / 0.2) * widget.angle * 2
            : 0.0;
        final bob = math.sin(t * math.pi * 2) * 3;
        return Transform.translate(
          offset: Offset(0, bob),
          child: Transform.rotate(angle: a, child: child),
        );
      },
      child: widget.child,
    );
  }
}

/// Stars, bubbles and letters slowly drifting behind the content.
class FloatingShapes extends StatefulWidget {
  final int count;
  final double opacity;
  final List<Color> colors;

  const FloatingShapes({
    super.key,
    this.count = 14,
    this.opacity = 0.35,
    this.colors = const [
      AppColors.sun,
      AppColors.pink,
      AppColors.secondary,
      AppColors.accent,
      AppColors.purple,
      Color(0xFF4CC9F0),
    ],
  });

  @override
  State<FloatingShapes> createState() => _FloatingShapesState();
}

class _FloatingShapesState extends State<FloatingShapes>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(seconds: 30))
        ..repeat();
  late final List<_Shape> _shapes;

  @override
  void initState() {
    super.initState();
    final rnd = math.Random(7);
    _shapes = List.generate(widget.count, (i) {
      return _Shape(
        x: rnd.nextDouble(),
        y: rnd.nextDouble(),
        size: 14 + rnd.nextDouble() * 26,
        speed: 0.5 + rnd.nextDouble(),
        phase: rnd.nextDouble() * math.pi * 2,
        kind: i % 4,
        color: widget.colors[i % widget.colors.length],
        letter: 'ABCKSWamz'[i % 9],
      );
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) => CustomPaint(
            size: Size.infinite,
            painter: _ShapesPainter(_shapes, _c.value, widget.opacity),
          ),
        ),
      ),
    );
  }
}

class _Shape {
  final double x, y, size, speed, phase;
  final int kind;
  final Color color;
  final String letter;
  _Shape({
    required this.x,
    required this.y,
    required this.size,
    required this.speed,
    required this.phase,
    required this.kind,
    required this.color,
    required this.letter,
  });
}

class _ShapesPainter extends CustomPainter {
  final List<_Shape> shapes;
  final double t;
  final double opacity;
  _ShapesPainter(this.shapes, this.t, this.opacity);

  @override
  void paint(Canvas canvas, Size size) {
    for (final s in shapes) {
      final a = t * math.pi * 2 * s.speed + s.phase;
      // Drift upward and loop around, swaying side to side.
      final y = ((s.y - t * s.speed * 0.6) % 1.0 + 1.0) % 1.0;
      final cx = s.x * size.width + math.sin(a) * 18;
      final cy = y * (size.height + 60) - 30;
      final p = Paint()..color = s.color.withValues(alpha: opacity);
      canvas.save();
      canvas.translate(cx, cy);
      canvas.rotate(a * 0.3);
      switch (s.kind) {
        case 0:
          canvas.drawPath(_star(s.size / 2), p);
          break;
        case 1:
          canvas.drawCircle(Offset.zero, s.size / 2, p);
          canvas.drawCircle(
              Offset(-s.size * 0.15, -s.size * 0.15),
              s.size * 0.12,
              Paint()..color = Colors.white.withValues(alpha: opacity));
          break;
        case 2:
          canvas.drawRRect(
              RRect.fromRectAndRadius(
                  Rect.fromCenter(
                      center: Offset.zero, width: s.size, height: s.size),
                  Radius.circular(s.size * 0.3)),
              p);
          break;
        default:
          final tp = TextPainter(
            text: TextSpan(
              text: s.letter,
              style: GoogleFonts.nunito(
                  fontSize: s.size * 1.3,
                  fontWeight: FontWeight.w900,
                  color: s.color.withValues(alpha: opacity)),
            ),
            textDirection: TextDirection.ltr,
          )..layout();
          tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
      }
      canvas.restore();
    }
  }

  Path _star(double r) {
    final p = Path();
    for (int i = 0; i < 10; i++) {
      final rad = i.isEven ? r : r * 0.48;
      final ang = -math.pi / 2 + i * math.pi / 5;
      final pt = Offset(math.cos(ang) * rad, math.sin(ang) * rad);
      i == 0 ? p.moveTo(pt.dx, pt.dy) : p.lineTo(pt.dx, pt.dy);
    }
    return p..close();
  }

  @override
  bool shouldRepaint(covariant _ShapesPainter old) => old.t != t;
}

/// A rounded comic speech bubble with a tail pointing down-left.
class SpeechBubble extends StatelessWidget {
  final String text;
  final Color color;
  final Color textColor;

  const SpeechBubble(this.text,
      {super.key,
      this.color = Colors.white,
      this.textColor = AppColors.textDark});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _BubblePainter(color),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
        child: Text(text,
            style: GoogleFonts.nunito(
                fontSize: 15, fontWeight: FontWeight.w900, color: textColor)),
      ),
    );
  }
}

class _BubblePainter extends CustomPainter {
  final Color color;
  _BubblePainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final body = RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.width, size.height - 10),
        const Radius.circular(18));
    final tail = Path()
      ..moveTo(22, size.height - 12)
      ..lineTo(14, size.height)
      ..lineTo(38, size.height - 12)
      ..close();
    final p = Paint()..color = color;
    canvas.drawShadow(Path()..addRRect(body), Colors.black, 3, false);
    canvas.drawRRect(body, p);
    canvas.drawPath(tail, p);
  }

  @override
  bool shouldRepaint(covariant _BubblePainter old) => old.color != color;
}

/// A wave that keeps rolling sideways — the bottom edge of a colourful header.
class RollingWave extends StatefulWidget {
  final Color color;
  final double height;
  final double amplitude;

  const RollingWave(
      {super.key, required this.color, this.height = 40, this.amplitude = 10});

  @override
  State<RollingWave> createState() => _RollingWaveState();
}

class _RollingWaveState extends State<RollingWave>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(seconds: 6))
        ..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height,
      width: double.infinity,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) => CustomPaint(
          painter: _WavePainter(widget.color, _c.value, widget.amplitude),
        ),
      ),
    );
  }
}

class _WavePainter extends CustomPainter {
  final Color color;
  final double t;
  final double amp;
  _WavePainter(this.color, this.t, this.amp);

  @override
  void paint(Canvas canvas, Size size) {
    void wave(double phase, double a, Color c) {
      final p = Path()..moveTo(0, size.height);
      for (double x = 0; x <= size.width; x += 4) {
        final y = size.height / 2 +
            math.sin(x / size.width * math.pi * 3 + t * math.pi * 2 + phase) *
                a;
        p.lineTo(x, y);
      }
      p
        ..lineTo(size.width, size.height)
        ..close();
      canvas.drawPath(p, Paint()..color = c);
    }

    wave(1.4, amp * 0.8, color.withValues(alpha: 0.45));
    wave(0, amp, color);
  }

  @override
  bool shouldRepaint(covariant _WavePainter old) => old.t != t;
}

/// A page route where the new screen pops up with a springy zoom.
class BouncyPageTransitionsBuilder extends PageTransitionsBuilder {
  const BouncyPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final scale = Tween(begin: 0.88, end: 1.0)
        .animate(CurvedAnimation(parent: animation, curve: Curves.easeOutBack));
    final fade = CurvedAnimation(parent: animation, curve: Curves.easeOut);
    final slide = Tween(begin: const Offset(0, 0.06), end: Offset.zero).animate(
        CurvedAnimation(parent: animation, curve: Curves.easeOutCubic));
    return FadeTransition(
      opacity: fade,
      child: SlideTransition(
        position: slide,
        child: ScaleTransition(scale: scale, child: child),
      ),
    );
  }
}
