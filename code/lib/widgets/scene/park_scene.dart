import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'rig.dart';
import 'rig_data.dart';

/// The park behind the home screen: sky, sun, clouds, hills, a tree with a
/// swinging monkey, and a giraffe, zebra and elephant standing on the hills.
///
/// It is only scenery. Nothing here can be tapped, so the buttons on top of
/// it stay the only things a child presses. The animals still feel alive:
/// they breathe, blink, wiggle their ears and swish their tails.
class ParkBackdrop extends StatefulWidget {
  /// Where the hills meet the grass, in pixels from the top.
  final double horizon;

  /// Space kept clear at the top for the status bar and the top bar.
  final double topInset;

  const ParkBackdrop({super.key, required this.horizon, this.topInset = 0});

  @override
  State<ParkBackdrop> createState() => _ParkBackdropState();
}

class _ParkBackdropState extends State<ParkBackdrop>
    with SingleTickerProviderStateMixin {
  // One clock drives every animation in the park.
  final ValueNotifier<double> _time = ValueNotifier(0);
  late final Ticker _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((d) => _time.value = d.inMicroseconds / 1e6)
      ..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _time.dispose();
    super.dispose();
  }

  // ---- Idle poses ---------------------------------------------------------

  static double _blink(double t, double phase) {
    final f = ((t + phase) % 3.9) / 3.9;
    if (f > 0.05) return 1;
    return (1 - math.sin(f / 0.05 * math.pi)).clamp(0.08, 1.0);
  }

  /// A short ear-wiggle burst every few seconds.
  static double _burst(double t, double phase) {
    final f = (t + phase) % 5.3;
    return f < 0.7 ? math.sin(f * 30) * (1 - f / 0.7) : 0;
  }

  Map<String, RigPose> _giraffe(double t) {
    const ph = 0.0;
    final b = math.sin(t * 2.1 + ph);
    final ear = _burst(t, ph) * 0.18;
    return {
      'body': RigPose(sy: 1 + 0.014 * b, sx: 1 - 0.007 * b),
      'neck': RigPose(rot: 0.035 * math.sin(t * 0.9 + ph)),
      'head': RigPose(rot: 0.06 * math.sin(t * 1.3 + ph)),
      'earL': RigPose(rot: ear),
      'earR': RigPose(rot: -ear),
      'tail': RigPose(rot: 0.32 * math.sin(t * 2.4)),
      'eyes': RigPose(sy: _blink(t, ph)),
    };
  }

  Map<String, RigPose> _zebra(double t) {
    const ph = 1.7;
    final b = math.sin(t * 2.1 + ph);
    final ear = _burst(t, ph) * 0.18;
    return {
      'body': RigPose(sy: 1 + 0.014 * b, sx: 1 - 0.007 * b),
      'head': RigPose(rot: 0.05 * math.sin(t * 1.1 + ph)),
      'mane': RigPose(rot: 0.07 * math.sin(t * 3.2)),
      'earL': RigPose(rot: -ear),
      'earR': RigPose(rot: ear),
      'tail': RigPose(rot: 0.38 * math.sin(t * 2.8)),
      'eyes': RigPose(sy: _blink(t, ph)),
    };
  }

  Map<String, RigPose> _elephant(double t) {
    const ph = 3.4;
    final b = math.sin(t * 2.1 + ph);
    final flap = 0.5 + 0.5 * math.sin(t * 2.2);
    return {
      'body': RigPose(sy: 1 + 0.014 * b, sx: 1 - 0.007 * b),
      'head': RigPose(rot: 0.03 * math.sin(t * 1.0 + ph)),
      'earL': RigPose(sx: 1 - 0.12 * flap),
      'earR': RigPose(sx: 1 - 0.12 * flap),
      'trunk': RigPose(rot: 0.12 * math.sin(t * 1.5)),
      'tail': RigPose(rot: 0.3 * math.sin(t * 2.6)),
      'eyes': RigPose(sy: _blink(t, ph)),
    };
  }

  Map<String, RigPose> _monkey(double t) {
    const ph = 5.1;
    return {
      'body': RigPose(rot: 0.10 * math.sin(t * 1.6)),
      'arm': RigPose(rot: 0.45 * math.sin(t * 4.5)),
      'head': RigPose(rot: 0.06 * math.sin(t * 1.2 + ph)),
      'tail': RigPose(rot: 0.15 * math.sin(t * 2.0)),
      'eyes': RigPose(sy: _blink(t, ph)),
    };
  }

  // ---- Layout -------------------------------------------------------------

  /// A box with the rig's own shape, centred on [cx], standing on [bottom].
  static Rect _box(RigData rig, double cx, double bottom, double h) {
    final w = h * rig.width / rig.height;
    return Rect.fromLTWH(cx - w / 2, bottom - h, w, h);
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: LayoutBuilder(builder: (context, c) {
        final w = c.maxWidth;
        final hz = widget.horizon;
        final wide = w >= 700;
        // Animals stand just behind the "Start learning" card, so their
        // heads and backs show above it.
        final unit = wide ? 1.0 : 0.78;

        final giraffe = _box(
            giraffeRig, w * (wide ? 0.70 : 0.83), hz + 70 * unit, 300 * unit);
        final zebra = _box(
            zebraRig, w * (wide ? 0.40 : 0.18), hz + 12 * unit, 175 * unit);
        final elephant = _box(
            elephantRig, w * (wide ? 0.54 : 0.50), hz + 12 * unit, 165 * unit);
        final sun = _box(sunRig, w * (wide ? 0.55 : 0.62),
            widget.topInset + (wide ? 130 : 196), wide ? 130 : 66);

        // A tree on the right edge (wide screens), with the monkey hanging
        // from its branch.
        Rect? tree;
        Rect? monkey;
        if (wide) {
          const th = 360.0;
          final tw = th * treeRig.width / treeRig.height;
          tree = Rect.fromLTWH(w - tw * 0.72, hz + 60 - th, tw, th);
          // The tree is drawn mirrored, so the branch points left.
          final ts = th / treeRig.height;
          final tip = Offset(tree.right - 434 * ts, tree.top + 216 * ts);
          const mh = th * 0.42;
          final ms = mh / monkeyRig.height;
          monkey = Rect.fromLTWH(
              tip.dx - 237 * ms, tip.dy - 20 * ms, monkeyRig.width * ms, mh);
        }

        return Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            Positioned.fill(
              child:
                  CustomPaint(painter: _ParkPainter(horizon: hz, wide: wide)),
            ),
            _rig(sunRig, sun, (t) => {'rays': RigPose(rot: t * 0.18)}),
            for (int i = 0; i < 3; i++) _cloud(i, w, wide),
            for (final f in wide ? const [0.06, 0.26, 0.9] : const [0.04, 0.96])
              _rig(
                  bushRig,
                  _box(bushRig, w * f, hz + 18, wide ? 70 : 50),
                  (t) => {
                        'leaves':
                            RigPose(sx: 1 + 0.015 * math.sin(t * 1.4 + f * 9)),
                      }),
            if (tree != null)
              Positioned.fromRect(
                rect: tree,
                child: Transform.flip(
                  flipX: true,
                  child: CustomPaint(
                    painter: RigPainter(
                        treeRig,
                        () => {
                              'leaves': RigPose(
                                  rot: 0.012 * math.sin(_time.value * 0.8)),
                            },
                        repaint: _time),
                  ),
                ),
              ),
            _rig(zebraRig, zebra, _zebra),
            _rig(elephantRig, elephant, _elephant),
            _rig(giraffeRig, giraffe, _giraffe),
            if (monkey != null) _rig(monkeyRig, monkey, _monkey),
            for (int i = 0; i < 2; i++) _butterfly(i, w, hz),
          ],
        );
      }),
    );
  }

  Widget _rig(
      RigData rig, Rect r, Map<String, RigPose> Function(double t) pose) {
    return Positioned.fromRect(
      rect: r,
      child: RepaintBoundary(
        child: CustomPaint(
          painter: RigPainter(rig, () => pose(_time.value), repaint: _time),
        ),
      ),
    );
  }

  Widget _cloud(int i, double w, bool wide) {
    final ch = (wide ? 60.0 : 42.0) * (1 + i * 0.25);
    final cw = ch * cloudRig.width / cloudRig.height;
    final y = widget.topInset + (wide ? 60 : 70) + i * (wide ? 48 : 34);
    final speed = 9.0 + i * 5;
    return AnimatedBuilder(
      animation: _time,
      builder: (context, child) {
        final span = w + cw * 2;
        final x = ((_time.value * speed + i * span / 3) % span) - cw;
        return Positioned(
            left: x, top: y, width: cw, height: ch, child: child!);
      },
      child: CustomPaint(painter: RigPainter(cloudRig, () => const {})),
    );
  }

  Widget _butterfly(int i, double w, double hz) {
    const size = 34.0;
    return AnimatedBuilder(
      animation: _time,
      builder: (context, child) {
        final t = _time.value * (0.18 + i * 0.05) + i * 2.4;
        final x = w * (0.5 + 0.44 * math.sin(t * 1.3 + i));
        final y = hz - 150 + 40 * math.sin(t * 2.1) + i * 50;
        return Positioned(
            left: x, top: y, width: size * 1.25, height: size, child: child!);
      },
      child: CustomPaint(
        painter: RigPainter(butterflyRig, () {
          final f = 0.25 + 0.75 * math.cos(_time.value * 16 + i).abs();
          return {'wingL': RigPose(sx: f), 'wingR': RigPose(sx: f)};
        }, repaint: _time),
      ),
    );
  }
}

/// Sky, far hills with little trees, and a grassy lawn down to the bottom
/// of the page with tufts and flowers.
class _ParkPainter extends CustomPainter {
  final double horizon;
  final bool wide;
  _ParkPainter({required this.horizon, required this.wide});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final hy = horizon;

    // Sky.
    canvas.drawRect(
        Rect.fromLTWH(0, 0, w, hy + 20),
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF52C7FF), Color(0xFFB8EEFF)],
          ).createShader(Rect.fromLTWH(0, 0, w, hy)));

    // Far hills.
    final far = Path()..moveTo(0, hy - 50);
    far.cubicTo(w * 0.15, hy - 120, w * 0.3, hy - 95, w * 0.42, hy - 40);
    far.cubicTo(w * 0.55, hy - 110, w * 0.75, hy - 135, w * 0.88, hy - 55);
    far.cubicTo(w * 0.94, hy - 80, w * 0.98, hy - 80, w, hy - 65);
    far
      ..lineTo(w, hy + 20)
      ..lineTo(0, hy + 20)
      ..close();
    canvas.drawPath(far, Paint()..color = const Color(0xFF9EE6AE));

    // Little round trees on the far hills.
    final treeTop = Paint()..color = const Color(0xFF6CCB7E);
    final trunk = Paint()..color = const Color(0xFF8A6A4F);
    for (final f in const [0.12, 0.18, 0.3, 0.8, 0.86]) {
      final x = w * f;
      final y = hy - 70 + (f * 37 % 1) * 20;
      const r = 16.0;
      canvas.drawRect(
          Rect.fromCenter(
              center: Offset(x, y + r * 1.2), width: r * 0.35, height: r * 1.4),
          trunk);
      canvas.drawCircle(Offset(x, y), r, treeTop);
    }

    // The lawn: from the hills to the bottom of the page.
    final ground = Path()..moveTo(0, hy);
    ground.cubicTo(w * 0.25, hy - 30, w * 0.6, hy + 20, w, hy - 12);
    ground
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(
        ground,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF7ED957), Color(0xFF5CC24E), Color(0xFF4FB548)],
            stops: [0, 0.35, 1],
          ).createShader(Rect.fromLTWH(0, hy - 30, w, h - hy)));

    // Grass tufts and little flowers scattered over the lawn.
    final tuft = Paint()
      ..color = const Color(0xFF3F9E3A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    final rnd = math.Random(4);
    final count = ((h - hy) * w / 9000).clamp(12, 160).toInt();
    const petals = [Color(0xFFFF6FA8), Color(0xFFFFFFFF), Color(0xFFFFE066)];
    for (int i = 0; i < count; i++) {
      final x = rnd.nextDouble() * w;
      final y = hy + 30 + rnd.nextDouble() * (h - hy - 40);
      if (i % 4 == 0) {
        final c = petals[i % 3];
        for (int k = 0; k < 5; k++) {
          final a = k * math.pi * 2 / 5;
          canvas.drawCircle(Offset(x + math.cos(a) * 4, y + math.sin(a) * 4),
              3.4, Paint()..color = c);
        }
        canvas.drawCircle(
            Offset(x, y), 2.6, Paint()..color = const Color(0xFFFFB020));
      } else {
        const s = 9.0;
        canvas.drawLine(Offset(x, y), Offset(x - s * 0.5, y - s), tuft);
        canvas.drawLine(Offset(x, y), Offset(x, y - s * 1.3), tuft);
        canvas.drawLine(Offset(x, y), Offset(x + s * 0.5, y - s), tuft);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ParkPainter old) =>
      old.horizon != horizon || old.wide != wide;
}
