import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:path_drawing/path_drawing.dart';

/// A tiny "puppet" engine for the home-screen characters.
///
/// Each character is drawn once as an SVG (see tool/art). The drawing is
/// split into named parts — head, ears, tail, eyes… — and every part has a
/// joint (pivot). tool/svg2rig.py turns the drawings into Dart data, and
/// [RigPainter] draws it with each part moved by a [RigPose], so a giraffe
/// can blink, wiggle its ears and swish its tail without any video files.

/// One shape of a drawing.
class RigShape {
  final List<String> g; // the parts it belongs to, outermost first
  final int k; // 0 path, 1 circle, 2 ellipse, 3 rounded rect
  final int c; // ARGB colour
  final String d; // SVG path data (k == 0)
  final List<double> n; // numbers for circle / ellipse / rect
  final double o; // opacity
  final double sw; // stroke width; 0 = filled shape
  final List<double> rot; // [degrees, cx, cy] or empty

  const RigShape({
    required this.g,
    required this.k,
    required this.c,
    this.d = '',
    this.n = const [],
    this.o = 1,
    this.sw = 0,
    this.rot = const [],
  });
}

/// A whole character: its drawing size, joints and shapes.
class RigData {
  final double width;
  final double height;
  final Map<String, Offset> pivots;
  final List<RigShape> shapes;

  const RigData({
    required this.width,
    required this.height,
    required this.pivots,
    required this.shapes,
  });
}

/// How one part is moved right now, around its joint.
class RigPose {
  final double rot; // radians
  final double sx;
  final double sy;
  final double dx;
  final double dy;

  const RigPose(
      {this.rot = 0, this.sx = 1, this.sy = 1, this.dx = 0, this.dy = 0});
}

/// The shapes turned into Paths once, then reused every frame.
class _Built {
  final List<Path> paths;
  final List<Paint> paints;
  _Built(this.paths, this.paints);
}

final Map<RigData, _Built> _cache = {};

_Built _build(RigData rig) => _cache.putIfAbsent(rig, () {
      final paths = <Path>[];
      final paints = <Paint>[];
      for (final s in rig.shapes) {
        Path p;
        switch (s.k) {
          case 0:
            p = parseSvgPathData(s.d);
          case 1:
            p = Path()
              ..addOval(Rect.fromCircle(
                  center: Offset(s.n[0], s.n[1]), radius: s.n[2]));
          case 2:
            p = Path()
              ..addOval(Rect.fromCenter(
                  center: Offset(s.n[0], s.n[1]),
                  width: s.n[2] * 2,
                  height: s.n[3] * 2));
          default:
            p = Path()
              ..addRRect(RRect.fromRectAndRadius(
                  Rect.fromLTWH(s.n[0], s.n[1], s.n[2], s.n[3]),
                  Radius.circular(s.n[4])));
        }
        if (s.rot.isNotEmpty) {
          final m = Matrix4.identity()
            ..translateByDouble(s.rot[1], s.rot[2], 0, 1)
            ..rotateZ(s.rot[0] * math.pi / 180)
            ..translateByDouble(-s.rot[1], -s.rot[2], 0, 1);
          p = p.transform(m.storage);
        }
        paths.add(p);
        final paint = Paint()
          ..isAntiAlias = true
          ..color = Color(s.c).withValues(alpha: s.o);
        if (s.sw > 0) {
          paint
            ..style = PaintingStyle.stroke
            ..strokeWidth = s.sw
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round;
        }
        paints.add(paint);
      }
      return _Built(paths, paints);
    });

/// Draws a [RigData] fitted inside the box (centred, standing on the
/// bottom edge), with each named part moved by its pose.
class RigPainter extends CustomPainter {
  final RigData rig;
  final Map<String, RigPose> Function() poses;

  RigPainter(this.rig, this.poses, {super.repaint});

  Matrix4 _matrixFor(String part, RigPose pose) {
    final p = rig.pivots[part]!;
    return Matrix4.identity()
      ..translateByDouble(p.dx + pose.dx, p.dy + pose.dy, 0, 1)
      ..rotateZ(pose.rot)
      ..scaleByDouble(pose.sx, pose.sy, 1, 1)
      ..translateByDouble(-p.dx, -p.dy, 0, 1);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final built = _build(rig);
    final now = poses();
    final scale = math.min(size.width / rig.width, size.height / rig.height);
    canvas.save();
    canvas.translate((size.width - rig.width * scale) / 2,
        size.height - rig.height * scale);
    canvas.scale(scale);
    final chainCache = <String, Matrix4?>{};
    for (int i = 0; i < rig.shapes.length; i++) {
      final g = rig.shapes[i].g;
      final m = chainCache.putIfAbsent(g.join('/'), () {
        Matrix4? acc;
        for (final part in g) {
          final pose = now[part];
          if (pose == null || !rig.pivots.containsKey(part)) continue;
          acc = (acc ?? Matrix4.identity())..multiply(_matrixFor(part, pose));
        }
        return acc;
      });
      if (m == null) {
        canvas.drawPath(built.paths[i], built.paints[i]);
      } else {
        canvas.save();
        canvas.transform(m.storage);
        canvas.drawPath(built.paths[i], built.paints[i]);
        canvas.restore();
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant RigPainter old) => true;
}
