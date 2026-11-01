import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Hand-drawn doodles for the empty space beside a writing pad.
///
/// Sketch-and-scribble style: wobbly pen lines gone over twice (like a real
/// pen), soft ink with some blue, and a few little handwritten notes. They
/// are drawn faintly and blended into the page (like pencil on paper), so
/// they feel part of the background rather than stuck on top. They are
/// still: nothing moves, so the writing stays the centre of attention.

// Soft inks that lean toward the lavender page, so they blend in.
const _ink = Color(0xFF4A4580);
const _blue = Color(0xFF5B7BD6);

/// Wraps a square writing pad and fills the margins on either side with
/// doodles. On narrow screens (no real margin) it just shows the pad.
class DoodleFrame extends StatelessWidget {
  final Widget child;
  final int seed;

  const DoodleFrame({super.key, required this.child, this.seed = 1});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      if (!c.hasBoundedWidth || !c.hasBoundedHeight) return child;
      final side = math.min(c.maxWidth, c.maxHeight);
      final margin = (c.maxWidth - side) / 2;
      if (margin < 90) return Center(child: child);
      return SizedBox(
        width: c.maxWidth,
        height: c.maxHeight,
        child: Row(
          children: [
            SizedBox(
                width: margin,
                child: _DoodleColumn(seed: seed * 7 + 1, alignRight: true)),
            SizedBox(width: side, child: Center(child: child)),
            SizedBox(
                width: margin,
                child: _DoodleColumn(seed: seed * 7 + 4, alignRight: false)),
          ],
        ),
      );
    });
  }
}

class _DoodleColumn extends StatelessWidget {
  final int seed;
  final bool alignRight; // hug the pad side a little
  const _DoodleColumn({required this.seed, required this.alignRight});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: RepaintBoundary(
        child: CustomPaint(
          size: Size.infinite,
          painter: _DoodlePainter(seed: seed, alignRight: alignRight),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------
// The doodles, each drawn in a 0..1 box as a list of pen strokes.
// ---------------------------------------------------------------------

typedef _Doodle = List<List<Offset>> Function(math.Random r);

List<Offset> _circle(double cx, double cy, double rx, double ry,
    {double from = 0, double to = math.pi * 2, int n = 36}) {
  return [
    for (var i = 0; i <= n; i++)
      Offset(cx + rx * math.cos(from + (to - from) * i / n),
          cy + ry * math.sin(from + (to - from) * i / n)),
  ];
}

List<Offset> _l(double x1, double y1, double x2, double y2) =>
    [Offset(x1, y1), Offset(x2, y2)];

final List<_Doodle> _doodles = [
  // Star, not quite closed — like a quick pen star.
  (r) {
    final pts = <Offset>[];
    for (var i = 0; i <= 5; i++) {
      final a = -math.pi / 2 + i * 4 * math.pi / 5;
      pts.add(Offset(0.5 + 0.4 * math.cos(a), 0.52 + 0.4 * math.sin(a)));
    }
    pts.add(Offset(pts[1].dx + 0.04, pts[1].dy + 0.02));
    return [pts];
  },
  // Smiling sun.
  (r) => [
        _circle(0.5, 0.5, 0.2, 0.2, n: 30),
        for (var i = 0; i < 9; i++)
          () {
            final a = i * math.pi * 2 / 9 + 0.2;
            return _l(0.5 + 0.28 * math.cos(a), 0.5 + 0.28 * math.sin(a),
                0.5 + 0.42 * math.cos(a), 0.5 + 0.42 * math.sin(a));
          }(),
        _circle(0.5, 0.5, 0.1, 0.08, from: 0.3, to: math.pi - 0.3, n: 10),
        _circle(0.43, 0.44, 0.012, 0.012, n: 6),
        _circle(0.57, 0.44, 0.012, 0.012, n: 6),
      ],
  // Spiral.
  (r) => [
        [
          for (var i = 0; i <= 90; i++)
            Offset(0.5 + (0.02 + 0.4 * i / 90) * math.cos(i * 0.21),
                0.5 + (0.02 + 0.4 * i / 90) * math.sin(i * 0.21)),
        ],
      ],
  // Paper plane with a looping dashed trail.
  (r) {
    final trail = <List<Offset>>[];
    final path = [
      for (var i = 0; i <= 60; i++)
        () {
          final t = i / 60;
          return Offset(0.05 + t * 0.5 + 0.12 * math.sin(t * math.pi * 2),
              0.85 - t * 0.45 - 0.12 * math.cos(t * math.pi * 2) + 0.12);
        }(),
    ];
    for (var i = 0; i < path.length - 3; i += 6) {
      trail.add([path[i], path[i + 2]]);
    }
    return [
      ...trail,
      [
        const Offset(0.55, 0.42),
        const Offset(0.95, 0.15),
        const Offset(0.68, 0.55),
        const Offset(0.55, 0.42)
      ],
      [
        const Offset(0.95, 0.15),
        const Offset(0.66, 0.4),
        const Offset(0.62, 0.6)
      ],
    ];
  },
  // Pencil.
  (r) => [
        [
          const Offset(0.2, 0.8),
          const Offset(0.7, 0.3),
          const Offset(0.82, 0.42),
          const Offset(0.32, 0.92),
          const Offset(0.2, 0.8),
        ],
        [
          const Offset(0.2, 0.8),
          const Offset(0.1, 0.98),
          const Offset(0.32, 0.92)
        ],
        _l(0.62, 0.38, 0.74, 0.5),
        _l(0.14, 0.88, 0.2, 0.94),
      ],
  // Heart.
  (r) => [
        [
          for (var i = 0; i <= 50; i++)
            () {
              final t = i / 50 * math.pi * 2;
              final x = 16 * math.pow(math.sin(t), 3);
              final y = 13 * math.cos(t) -
                  5 * math.cos(2 * t) -
                  2 * math.cos(3 * t) -
                  math.cos(4 * t);
              return Offset(0.5 + x / 40, 0.48 - y / 40);
            }(),
        ],
      ],
  // Cloud.
  (r) => [
        [
          ..._circle(0.3, 0.6, 0.14, 0.12,
              from: math.pi * 0.6, to: math.pi * 1.6, n: 10),
          ..._circle(0.48, 0.48, 0.17, 0.16,
              from: math.pi * 1.1, to: math.pi * 1.95, n: 12),
          ..._circle(0.7, 0.58, 0.14, 0.13,
              from: math.pi * 1.35, to: math.pi * 2.4, n: 10),
          const Offset(0.26, 0.72),
        ],
      ],
  // Cat face.
  (r) => [
        _circle(0.5, 0.58, 0.3, 0.26, n: 32),
        [
          const Offset(0.27, 0.42),
          const Offset(0.28, 0.16),
          const Offset(0.42, 0.34)
        ],
        [
          const Offset(0.73, 0.42),
          const Offset(0.72, 0.16),
          const Offset(0.58, 0.34)
        ],
        _circle(0.4, 0.54, 0.02, 0.03, n: 6),
        _circle(0.6, 0.54, 0.02, 0.03, n: 6),
        [
          const Offset(0.45, 0.66),
          const Offset(0.5, 0.7),
          const Offset(0.55, 0.66)
        ],
        _l(0.12, 0.62, 0.34, 0.64),
        _l(0.14, 0.72, 0.34, 0.68),
        _l(0.88, 0.62, 0.66, 0.64),
        _l(0.86, 0.72, 0.66, 0.68),
      ],
  // Rocket.
  (r) => [
        [
          const Offset(0.5, 0.06),
          const Offset(0.66, 0.3),
          const Offset(0.64, 0.7),
          const Offset(0.36, 0.7),
          const Offset(0.34, 0.3),
          const Offset(0.5, 0.06),
        ],
        _circle(0.5, 0.36, 0.06, 0.06, n: 12),
        [
          const Offset(0.36, 0.56),
          const Offset(0.22, 0.76),
          const Offset(0.36, 0.7)
        ],
        [
          const Offset(0.64, 0.56),
          const Offset(0.78, 0.76),
          const Offset(0.64, 0.7)
        ],
        [
          const Offset(0.42, 0.74),
          const Offset(0.46, 0.88),
          const Offset(0.5, 0.78),
          const Offset(0.54, 0.92),
          const Offset(0.58, 0.74),
        ],
      ],
  // Flower.
  (r) => [
        _circle(0.5, 0.32, 0.07, 0.07, n: 12),
        for (var i = 0; i < 6; i++)
          _circle(0.5 + 0.15 * math.cos(i * math.pi / 3),
              0.32 + 0.15 * math.sin(i * math.pi / 3), 0.08, 0.08,
              n: 14),
        [
          const Offset(0.5, 0.48),
          const Offset(0.47, 0.7),
          const Offset(0.5, 0.95)
        ],
        [
          const Offset(0.48, 0.74),
          const Offset(0.3, 0.64),
          const Offset(0.34, 0.8),
          const Offset(0.48, 0.78)
        ],
      ],
  // Tangled scribble ball: lots of quick overlapping loops.
  (r) {
    final pts = <Offset>[];
    final k = r.nextDouble() * 6;
    for (var i = 0; i <= 150; i++) {
      final a = i * 0.55;
      final rad = 0.14 + 0.13 * math.sin(i * 0.13 + k).abs();
      pts.add(Offset(0.5 + 0.1 * math.sin(i * 0.05 + k) + rad * math.cos(a),
          0.5 + 0.1 * math.cos(i * 0.07 + k) + rad * math.sin(a)));
    }
    return [pts];
  },
  // Loop-de-loop arrow.
  (r) {
    final pts = <Offset>[
      for (var i = 0; i <= 50; i++)
        () {
          final t = i / 50;
          return Offset(0.08 + t * 0.78 + 0.1 * math.sin(t * math.pi * 4),
              0.6 - 0.1 * math.cos(t * math.pi * 4) - t * 0.1);
        }(),
    ];
    final end = pts.last;
    return [
      pts,
      [
        Offset(end.dx - 0.12, end.dy - 0.06),
        end,
        Offset(end.dx - 0.08, end.dy + 0.1)
      ],
    ];
  },
  // Smiley.
  (r) => [
        _circle(0.5, 0.5, 0.36, 0.34, n: 34),
        _circle(0.38, 0.42, 0.025, 0.04, n: 8),
        _circle(0.62, 0.42, 0.025, 0.04, n: 8),
        _circle(0.5, 0.52, 0.2, 0.16, from: 0.35, to: math.pi - 0.35, n: 14),
      ],
];

const _notes = [
  'a b c',
  '1 2 3',
  'wow!',
  'hello!',
  'A+',
  'draw!',
  'yay',
  'x o x'
];

class _DoodlePainter extends CustomPainter {
  final int seed;
  final bool alignRight;

  _DoodlePainter({required this.seed, required this.alignRight});

  @override
  void paint(Canvas canvas, Size size) {
    final rnd = math.Random(seed);
    final cell =
        math.min(math.min(size.width * 0.66, size.height / 3.3), 160.0);
    final rows = math.max(1, (size.height / (cell * 1.1)).floor());
    final gap = size.height / rows;

    // Shuffle the doodles so each margin looks different.
    final order = List<int>.generate(_doodles.length, (i) => i)..shuffle(rnd);
    var noteIndex = rnd.nextInt(_notes.length);

    for (var i = 0; i < rows; i++) {
      final cy = gap * (i + 0.5);
      // Zig-zag a little so the column does not look like a list.
      final wiggle = (i.isEven ? 1 : -1) * size.width * 0.08;
      final cx = size.width / 2 + wiggle + (alignRight ? 6 : -6);
      final colour = rnd.nextDouble() < 0.35 ? _blue : _ink;
      final angle = (rnd.nextDouble() - 0.5) * 0.4;

      canvas.save();
      canvas.translate(cx, cy);
      canvas.rotate(angle);

      // Every third slot is a handwritten note instead of a drawing.
      if (i % 3 == 2) {
        _note(canvas, _notes[noteIndex++ % _notes.length], cell, colour);
      } else {
        final d = _doodles[order[i % order.length]](rnd);
        _drawStrokes(canvas, d, cell, colour, rnd);
      }
      canvas.restore();
    }
  }

  /// A soft pencil-like line: multiplied into the page and slightly
  /// softened at the edges, so it looks drawn ON the paper.
  Paint _pen(Color colour, double alpha, double width) => Paint()
    ..color = colour.withValues(alpha: alpha)
    ..style = PaintingStyle.stroke
    ..strokeWidth = width
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..blendMode = BlendMode.multiply
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 0.6);

  /// Draws strokes like a pen: wobbly and gone over twice.
  void _drawStrokes(Canvas canvas, List<List<Offset>> strokes, double cell,
      Color colour, math.Random rnd) {
    final w = cell * 0.02;
    for (var pass = 0; pass < 2; pass++) {
      final paint =
          pass == 0 ? _pen(colour, 0.34, w) : _pen(colour, 0.16, w * 0.7);
      final wob = cell * (pass == 0 ? 0.008 : 0.016);
      final phase = rnd.nextDouble() * 10;

      for (final s in strokes) {
        final pts = _densify(s);
        if (pts.length < 2) continue;
        Offset at(int k) {
          final o = pts[k];
          return Offset(
              (o.dx - 0.5) * cell + math.sin(k * 0.7 + phase) * wob,
              (o.dy - 0.5) * cell + math.cos(k * 0.9 + phase) * wob);
        }

        final path = Path()..moveTo(at(0).dx, at(0).dy);
        for (var k = 1; k < pts.length - 1; k++) {
          final a = at(k), b = at(k + 1);
          path.quadraticBezierTo(
              a.dx, a.dy, (a.dx + b.dx) / 2, (a.dy + b.dy) / 2);
        }
        final last = at(pts.length - 1);
        path.lineTo(last.dx, last.dy);
        canvas.drawPath(path, paint);
      }
    }
  }

  /// Adds points between far-apart ones so the wobble looks natural.
  List<Offset> _densify(List<Offset> s) {
    final out = <Offset>[];
    for (var i = 0; i < s.length - 1; i++) {
      final steps = math.max(1, ((s[i + 1] - s[i]).distance / 0.04).ceil());
      for (var j = 0; j < steps; j++) {
        out.add(Offset.lerp(s[i], s[i + 1], j / steps)!);
      }
    }
    if (s.isNotEmpty) out.add(s.last);
    return out;
  }

  void _note(Canvas canvas, String text, double cell, Color colour) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: GoogleFonts.caveat(
          fontSize: cell * 0.3,
          fontWeight: FontWeight.w700,
          color: colour.withValues(alpha: 0.42),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
    // A quick wobbly underline.
    final y = tp.height / 2 + cell * 0.02;
    final path = Path();
    for (var i = 0; i <= 12; i++) {
      final o = Offset(-tp.width / 2 + tp.width * i / 12,
          y + math.sin(i * 1.3) * cell * 0.012);
      i == 0 ? path.moveTo(o.dx, o.dy) : path.lineTo(o.dx, o.dy);
    }
    canvas.drawPath(path, _pen(colour, 0.3, cell * 0.016));
  }

  @override
  bool shouldRepaint(covariant _DoodlePainter old) =>
      old.seed != seed || old.alignRight != alignRight;
}
