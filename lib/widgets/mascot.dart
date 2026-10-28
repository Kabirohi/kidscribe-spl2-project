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

  static const _ink = Color(0xFF2A1F5C);

  // Soft "clay" shading: every part is lit from the top-left, like the
  // 3D illustrations used in the rest of the app.
  Paint _grad(Rect r, List<Color> colors,
          {List<double>? stops,
          Alignment begin = Alignment.centerLeft,
          Alignment end = Alignment.centerRight}) =>
      Paint()
        ..shader =
            LinearGradient(begin: begin, end: end, colors: colors, stops: stops)
                .createShader(r);

  Paint _radial(Offset c, double r, List<Color> colors,
          {Alignment center = Alignment.center}) =>
      Paint()
        ..shader = RadialGradient(colors: colors, center: center)
            .createShader(Rect.fromCircle(center: c, radius: r));

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    Rect r(double l, double t, double w, double h) =>
        Rect.fromLTWH(l * s, t * s, w * s, h * s);
    Offset o(double x, double y) => Offset(x * s, y * s);

    // Bounce: hop up a little and squash at the bottom.
    final hop = (bounce > 0 ? bounce : 0) * 0.05 + jumpY.abs();
    final squash = bounce < 0 ? -bounce * 0.06 : 0.0;

    // Soft blurred ground shadow that shrinks as she lifts.
    final shadowW = 0.46 * (1 - hop * 1.6);
    canvas.drawOval(
        Rect.fromCenter(
            center: o(0.5, 0.955), width: shadowW * s, height: 0.055 * s),
        Paint()
          ..color = const Color(0x402A1F5C)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 0.012 * s));

    canvas.save();
    canvas.translate(0, -hop * s);
    canvas.translate(s / 2, 0.95 * s);
    canvas.scale(1 + squash, 1 - squash);
    canvas.rotate((-7 * math.pi / 180) + spin);
    canvas.translate(-s / 2, -0.95 * s);

    // ---- Arms (behind the body) ----
    void arm(Offset from, Offset to) {
      final dir = to - from;
      final len = dir.distance;
      canvas.save();
      canvas.translate(from.dx, from.dy);
      canvas.rotate(math.atan2(dir.dy, dir.dx));
      final rr = RRect.fromRectAndRadius(
          Rect.fromLTWH(0, -0.03 * s, len, 0.06 * s),
          Radius.circular(0.03 * s));
      canvas.drawRRect(
          rr,
          _grad(rr.outerRect, const [Color(0xFFFFD45A), Color(0xFFE8901A)],
              begin: Alignment.topCenter, end: Alignment.bottomCenter));
      canvas.restore();
      // Round mitten hand with a highlight.
      canvas.drawCircle(
          to,
          0.05 * s,
          _radial(to, 0.05 * s, const [Color(0xFFFFE58A), Color(0xFFF2A91B)],
              center: const Alignment(-0.4, -0.5)));
      canvas.drawCircle(to + Offset(-0.015 * s, -0.018 * s), 0.012 * s,
          Paint()..color = Colors.white.withValues(alpha: 0.7));
    }

    arm(o(0.31, 0.50), o(0.15, 0.62));
    final up = wave.abs() > 0.01 || excited;
    final ang =
        up ? (-math.pi / 3) + wave * 0.45 + (excited ? -0.3 : 0) : math.pi / 4;
    final rShoulder = o(0.69, 0.48);
    arm(rShoulder,
        rShoulder + Offset(math.cos(ang), math.sin(ang)) * (0.19 * s));

    // ---- Wooden tip + graphite ----
    final tipRect = r(0.28, 0.66, 0.44, 0.30);
    final tip = Path()
      ..moveTo(0.285 * s, 0.68 * s)
      ..lineTo(0.715 * s, 0.68 * s)
      ..quadraticBezierTo(0.62 * s, 0.84 * s, 0.53 * s, 0.935 * s)
      ..quadraticBezierTo(0.5 * s, 0.955 * s, 0.47 * s, 0.935 * s)
      ..quadraticBezierTo(0.38 * s, 0.84 * s, 0.285 * s, 0.68 * s)
      ..close();
    canvas.drawPath(
        tip,
        _grad(tipRect, const [
          Color(0xFFFFEBD0),
          Color(0xFFF4CD9C),
          Color(0xFFD9A46B),
        ], stops: const [
          0,
          0.45,
          1
        ]));
    final lead = Path()
      ..moveTo(0.435 * s, 0.875 * s)
      ..lineTo(0.565 * s, 0.875 * s)
      ..quadraticBezierTo(0.53 * s, 0.935 * s, 0.5 * s, 0.95 * s)
      ..quadraticBezierTo(0.47 * s, 0.935 * s, 0.435 * s, 0.875 * s)
      ..close();
    canvas.drawPath(
        lead, _grad(tipRect, const [Color(0xFF5A4E8C), Color(0xFF1E1645)]));

    // ---- Body: a glossy rounded cylinder ----
    final bodyRect = r(0.27, 0.15, 0.46, 0.57);
    final body = RRect.fromRectAndRadius(bodyRect, Radius.circular(0.11 * s));
    canvas.drawRRect(
        body,
        _grad(bodyRect, const [
          Color(0xFFFFE680),
          Color(0xFFFFCB3D),
          Color(0xFFF9AE22),
          Color(0xFFE38A12),
        ], stops: const [
          0,
          0.38,
          0.78,
          1
        ]));
    canvas.save();
    canvas.clipRRect(body);
    // Wavy bottom edge where the wood is sharpened.
    final scallop = Path()..moveTo(0.27 * s, 0.72 * s);
    for (int i = 0; i < 4; i++) {
      final x0 = 0.27 + i * 0.115;
      scallop.quadraticBezierTo(
          (x0 + 0.0575) * s, 0.665 * s, (x0 + 0.115) * s, 0.72 * s);
    }
    scallop
      ..lineTo(0.73 * s, 0.75 * s)
      ..lineTo(0.27 * s, 0.75 * s)
      ..close();
    canvas.drawPath(
        scallop,
        _grad(bodyRect,
            const [Color(0xFFFFEBD0), Color(0xFFF4CD9C), Color(0xFFD9A46B)]));
    // Long soft shine on the left.
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            r(0.315, 0.2, 0.045, 0.42), Radius.circular(0.03 * s)),
        Paint()..color = Colors.white.withValues(alpha: 0.45));
    canvas.restore();

    // ---- Metal band ----
    final band = r(0.265, 0.105, 0.47, 0.075);
    canvas.drawRRect(
        RRect.fromRectAndRadius(band, Radius.circular(0.02 * s)),
        _grad(band, const [
          Color(0xFFF4F6FB),
          Color(0xFFC5CBDC),
          Color(0xFFF7F8FC),
          Color(0xFFA7AEC4),
        ], stops: const [
          0,
          0.35,
          0.6,
          1
        ]));
    final ridge = Paint()
      ..color = const Color(0x339097B0)
      ..strokeWidth = 0.008 * s;
    canvas.drawLine(o(0.27, 0.13), o(0.73, 0.13), ridge);
    canvas.drawLine(o(0.27, 0.155), o(0.73, 0.155), ridge);

    // ---- Eraser ----
    final er = r(0.275, 0.015, 0.45, 0.1);
    canvas.drawRRect(
        RRect.fromRectAndCorners(er,
            topLeft: Radius.circular(0.08 * s),
            topRight: Radius.circular(0.08 * s),
            bottomLeft: Radius.circular(0.01 * s),
            bottomRight: Radius.circular(0.01 * s)),
        _grad(er, const [
          Color(0xFFFFA3CB),
          Color(0xFFFF6BAA),
          Color(0xFFE2478B),
        ], stops: const [
          0,
          0.45,
          1
        ]));
    canvas.drawOval(r(0.32, 0.03, 0.12, 0.03),
        Paint()..color = Colors.white.withValues(alpha: 0.5));

    // ---- Face ----
    // Eyebrows (raised when excited).
    final browY = excited ? 0.255 : 0.275;
    final brow = Paint()
      ..color = _ink
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 0.018 * s;
    for (final x in const [0.405, 0.595]) {
      canvas.drawArc(
          Rect.fromCenter(
              center: o(x, browY + 0.02), width: 0.09 * s, height: 0.04 * s),
          math.pi * 1.15,
          math.pi * 0.7,
          false,
          brow);
    }

    // Eyes: big glossy ovals that blink and look around.
    final eyeH = 0.165 * (1 - blink * 0.92);
    for (final x in const [0.405, 0.595]) {
      final eye = Rect.fromCenter(
          center: o(x, 0.385), width: 0.135 * s, height: eyeH * s);
      canvas.drawOval(
          eye,
          _grad(eye, const [Colors.white, Color(0xFFE6E2F5)],
              begin: Alignment.topCenter, end: Alignment.bottomCenter));
    }
    if (blink < 0.6) {
      final dx = look * 0.022 * s;
      final pr = (excited ? 0.05 : 0.044) * s;
      for (final x in const [0.41, 0.60]) {
        final c = Offset(x * s + dx, 0.398 * s);
        canvas.drawCircle(
            c,
            pr,
            _radial(c, pr, const [Color(0xFF4A3D8F), Color(0xFF1B1340)],
                center: const Alignment(0.2, 0.4)));
        canvas.drawCircle(c + Offset(0.016 * s, -0.018 * s), 0.016 * s,
            Paint()..color = Colors.white);
        canvas.drawCircle(c + Offset(-0.014 * s, 0.016 * s), 0.007 * s,
            Paint()..color = Colors.white.withValues(alpha: 0.85));
      }
    } else {
      final lid = Paint()
        ..color = _ink
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 0.018 * s;
      for (final x in const [0.405, 0.595]) {
        canvas.drawArc(
            Rect.fromCenter(
                center: o(x, 0.38), width: 0.1 * s, height: 0.05 * s),
            0.15,
            math.pi - 0.3,
            false,
            lid);
      }
    }

    // Rosy cheeks.
    for (final x in const [0.33, 0.67]) {
      final c = o(x, 0.52);
      canvas.drawCircle(c, 0.05 * s,
          _radial(c, 0.05 * s, const [Color(0x99FF6FA8), Color(0x00FF6FA8)]));
    }

    // Mouth.
    if (happy || excited) {
      final w = excited ? 0.17 : 0.13;
      final d = excited ? 0.12 : 0.08;
      final m = Path()
        ..moveTo((0.5 - w / 2) * s, 0.51 * s)
        ..quadraticBezierTo(
            0.5 * s, 0.51 * s + 0.012 * s, (0.5 + w / 2) * s, 0.51 * s)
        ..quadraticBezierTo(
            0.5 * s, (0.51 + d * 1.6) * s, (0.5 - w / 2) * s, 0.51 * s)
        ..close();
      canvas.drawPath(m, Paint()..color = const Color(0xFF3B1E4E));
      canvas.save();
      canvas.clipPath(m);
      canvas.drawCircle(o(0.5, 0.51 + d * 1.25), d * 0.55 * s,
          Paint()..color = const Color(0xFFFF6F91));
      canvas.restore();
    } else {
      canvas.drawOval(
          Rect.fromCenter(
              center: o(0.5, 0.54), width: 0.05 * s, height: 0.035 * s),
          Paint()..color = const Color(0xFF3B1E4E));
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
