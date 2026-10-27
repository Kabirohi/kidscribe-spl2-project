import 'package:flutter/material.dart';
import 'dart:math' as math;

/// "Penny", the KidScribe pencil mascot, drawn in code so it needs no image
/// files and stays sharp on every tablet.
///
/// She is alive: she bounces with a little squash and stretch, blinks,
/// looks around and waves. Tap her and she jumps and giggles.
class PennyMascot extends StatefulWidget {
  final double size;
  final bool happy;

  /// Turn off for places where motion would distract (e.g. a test).
  final bool animate;

  /// Waves her arm every few seconds.
  final bool wave;

  const PennyMascot({
    super.key,
    this.size = 140,
    this.happy = true,
    this.animate = true,
    this.wave = true,
  });

  @override
  State<PennyMascot> createState() => _PennyMascotState();
}

class _PennyMascotState extends State<PennyMascot>
    with TickerProviderStateMixin {
  // One long loop drives bounce, blink, look and wave so they stay in sync.
  late final AnimationController _loop = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 4800));
  // A one-off jump when tapped.
  late final AnimationController _jump = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 650));

  @override
  void initState() {
    super.initState();
    if (widget.animate) _loop.repeat();
  }

  @override
  void dispose() {
    _loop.dispose();
    _jump.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.animate ? () => _jump.forward(from: 0) : null,
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: AnimatedBuilder(
          animation: Listenable.merge([_loop, _jump]),
          builder: (context, _) {
            final t = _loop.value; // 0..1 over 4.8s
            // Bounce 4 times per loop.
            final b = math.sin(t * math.pi * 2 * 4);
            // Blink twice per loop: eyes shut for a short window.
            double blink = 0;
            for (final at in const [0.30, 0.78]) {
              final d = (t - at).abs();
              if (d < 0.02) blink = 1 - d / 0.02;
            }
            // Look left/right slowly.
            final look = math.sin(t * math.pi * 2) * 0.6;
            // Wave in the last third of the loop.
            double wave = 0;
            if (widget.wave && t > 0.55 && t < 0.9) {
              final w = (t - 0.55) / 0.35;
              wave = math.sin(w * math.pi * 6) * math.sin(w * math.pi);
            }
            // Tap jump: up and down with a spin of joy.
            final j = _jump.value;
            final jumpY = -math.sin(j * math.pi) * 0.22;
            final spin =
                j > 0 && j < 1 ? math.sin(j * math.pi * 2) * 0.15 : 0.0;

            return CustomPaint(
              painter: _PennyPainter(
                happy: widget.happy || j > 0,
                bounce: widget.animate ? b : 0,
                blink: blink,
                look: look,
                wave: wave,
                jumpY: jumpY,
                spin: spin,
                excited: j > 0 && j < 1,
              ),
            );
          },
        ),
      ),
    );
  }
}

class _PennyPainter extends CustomPainter {
  final bool happy;
  final double bounce; // -1..1
  final double blink; // 0 open .. 1 closed
  final double look; // -1..1
  final double wave; // -1..1
  final double jumpY; // fraction of size
  final double spin;
  final bool excited;

  const _PennyPainter({
    required this.happy,
    this.bounce = 0,
    this.blink = 0,
    this.look = 0,
    this.wave = 0,
    this.jumpY = 0,
    this.spin = 0,
    this.excited = false,
  });

  static const _ink = Color(0xFF1F1A4D);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final fill = Paint()..style = PaintingStyle.fill;

    // Bounce: hop up a little and squash at the bottom.
    final hop = (bounce > 0 ? bounce : 0) * 0.05 + jumpY.abs();
    final squash = bounce < 0 ? -bounce * 0.06 : 0.0;

    // Ground shadow shrinks as she lifts.
    final shadowW = 0.48 * (1 - hop * 1.6);
    canvas.drawOval(
        Rect.fromCenter(
            center: Offset(0.5 * s, 0.96 * s),
            width: shadowW * s,
            height: 0.05 * s),
        fill..color = const Color(0x33000000));

    canvas.save();
    canvas.translate(0, -hop * s);
    // Squash around her feet.
    canvas.translate(s / 2, 0.95 * s);
    canvas.scale(1 + squash, 1 - squash);
    canvas.rotate((-8 * math.pi / 180) + spin);
    canvas.translate(-s / 2, -0.95 * s);

    Rect r(double l, double t, double w, double h) =>
        Rect.fromLTWH(l * s, t * s, w * s, h * s);

    // Arms (behind the body).
    final arm = Paint()
      ..color = const Color(0xFFF2A91B)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 0.055 * s;
    final hand = Paint()..color = const Color(0xFFFFC83D);
    // Left arm rests.
    final lShoulder = Offset(0.29 * s, 0.50 * s);
    final lHand = Offset(0.16 * s, 0.62 * s);
    canvas.drawLine(lShoulder, lHand, arm);
    canvas.drawCircle(lHand, 0.04 * s, hand);
    // Right arm waves up.
    final rShoulder = Offset(0.71 * s, 0.48 * s);
    final up = wave.abs() > 0.01 || excited;
    final ang =
        up ? (-math.pi / 3) + wave * 0.45 + (excited ? -0.3 : 0) : math.pi / 4;
    final rHand = rShoulder + Offset(math.cos(ang), math.sin(ang)) * (0.18 * s);
    canvas.drawLine(rShoulder, rHand, arm);
    canvas.drawCircle(rHand, 0.04 * s, hand);

    // Wooden tip + graphite.
    final tip = Path()
      ..moveTo(0.27 * s, 0.70 * s)
      ..lineTo(0.73 * s, 0.70 * s)
      ..lineTo(0.5 * s, 0.95 * s)
      ..close();
    canvas.drawPath(tip, fill..color = const Color(0xFFF6D3A8));
    final lead = Path()
      ..moveTo(0.42 * s, 0.86 * s)
      ..lineTo(0.58 * s, 0.86 * s)
      ..lineTo(0.5 * s, 0.95 * s)
      ..close();
    canvas.drawPath(lead, fill..color = _ink);

    // Body.
    final body = RRect.fromRectAndRadius(
        r(0.27, 0.17, 0.46, 0.56), Radius.circular(0.06 * s));
    canvas.drawRRect(body, fill..color = const Color(0xFFFFC83D));
    canvas.save();
    canvas.clipRRect(body);
    canvas.drawRect(
        r(0.62, 0.17, 0.11, 0.56), fill..color = const Color(0xFFF2A91B));
    // A shiny stripe on the left.
    canvas.drawRect(
        r(0.30, 0.17, 0.035, 0.56), fill..color = const Color(0x55FFFFFF));
    canvas.restore();

    // Metal band.
    canvas.drawRect(
        r(0.27, 0.12, 0.46, 0.07), fill..color = const Color(0xFFD9DDEA));
    canvas.drawRect(
        r(0.27, 0.145, 0.46, 0.012), fill..color = const Color(0xFFB7BDD2));

    // Eraser.
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            r(0.27, 0.02, 0.46, 0.11), Radius.circular(0.05 * s)),
        fill..color = const Color(0xFFFF5FA2));

    // Eyes (they blink and look around).
    final eyeH = 0.065 * s * (1 - blink * 0.9);
    final white = Paint()..color = Colors.white;
    for (final x in const [0.40, 0.60]) {
      canvas.drawOval(
          Rect.fromCenter(
              center: Offset(x * s, 0.40 * s),
              width: 0.13 * s,
              height: eyeH * 2),
          white);
    }
    if (blink < 0.6) {
      final dx = look * 0.02 * s;
      final pupil = Paint()..color = _ink;
      final glint = Paint()..color = Colors.white;
      final pr = (excited ? 0.038 : 0.032) * s;
      for (final x in const [0.41, 0.61]) {
        canvas.drawCircle(Offset(x * s + dx, 0.41 * s), pr, pupil);
        canvas.drawCircle(
            Offset(x * s + dx + 0.01 * s, 0.395 * s), 0.011 * s, glint);
      }
    } else {
      final lid = Paint()
        ..color = _ink
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 0.016 * s;
      for (final x in const [0.40, 0.60]) {
        canvas.drawLine(Offset((x - 0.045) * s, 0.40 * s),
            Offset((x + 0.045) * s, 0.40 * s), lid);
      }
    }

    // Cheeks.
    final blush = Paint()..color = const Color(0x66FF5FA2);
    canvas.drawCircle(Offset(0.34 * s, 0.53 * s), 0.035 * s, blush);
    canvas.drawCircle(Offset(0.66 * s, 0.53 * s), 0.035 * s, blush);

    // Mouth.
    if (excited) {
      // Big open smile.
      final m = Path()
        ..moveTo(0.42 * s, 0.52 * s)
        ..quadraticBezierTo(0.5 * s, 0.66 * s, 0.58 * s, 0.52 * s)
        ..close();
      canvas.drawPath(m, Paint()..color = _ink);
      canvas.drawCircle(Offset(0.5 * s, 0.585 * s), 0.025 * s,
          Paint()..color = const Color(0xFFFF5FA2));
    } else {
      final mouth = Paint()
        ..color = _ink
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 0.02 * s;
      if (happy) {
        canvas.drawArc(
            r(0.43, 0.49, 0.14, 0.10), 0.1, math.pi - 0.2, false, mouth);
      } else {
        canvas.drawLine(
            Offset(0.45 * s, 0.56 * s), Offset(0.55 * s, 0.56 * s), mouth);
      }
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _PennyPainter old) =>
      old.happy != happy ||
      old.bounce != bounce ||
      old.blink != blink ||
      old.look != look ||
      old.wave != wave ||
      old.jumpY != jumpY ||
      old.spin != spin ||
      old.excited != excited;
}
