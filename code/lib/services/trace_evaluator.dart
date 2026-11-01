import 'dart:math' as math;
import 'dart:ui';

/// The result of checking a child's tracing against the template shape.
class TraceResult {
  final int score;        // 0..100
  final int stars;        // 0..3
  final bool passed;      // true when the child earned at least 1 star
  final double coverage;  // how much of the shape was traced (0..1)
  final double precision; // how much of the ink stayed on the shape (0..1)
  final String? orderTip; // set when the DESIGNATED stroke order was broken
  const TraceResult(this.score, this.stars, this.passed,
      {this.coverage = 0, this.precision = 0, this.orderTip});

  /// Kid-friendly advice on WHAT to fix (SRS FR_7: "A wrong letter shows
  /// what needs to be fixed"). Null when the trace was perfect.
  String? get tip {
    if (orderTip != null) return orderTip;
    if (stars == 3) return null;
    if (coverage < 0.9) return 'You missed part of the shape — cover ALL the gray!';
    if (precision < 0.8) return 'Try to stay ON the gray path!';
    return 'So close! Trace it slowly and carefully.';
  }
}

/// Result of checking whether the child wrote in the DESIGNATED manner:
/// the right number of pen strokes, in the right order, each going in
/// the right direction (green dot ➜ orange dot). Writing letters the
/// standard way is what makes handwriting fast later on.
class OrderCheck {
  final bool ok;
  final String? kidTip;
  const OrderCheck(this.ok, this.kidTip);
}

/// Compares what the child drew with the template shape.
///
/// HOW THE CHECK WORKS (two questions):
///  1. COVERAGE  — did the pen go over the WHOLE shape?
///     (for each template point: is some drawn point close to it?)
///  2. PRECISION — did the ink STAY ON the shape?
///     (for each drawn point: is it close to some template point?)
///
/// Coverage stops half-finished letters from passing; precision stops
/// random scribbling all over the canvas from passing. Direction does
/// not matter — tracing a circle either way around is fine.
class TraceEvaluator {
  /// How far a point may be from the shape and still count.
  /// 0.09 = 9% of the canvas width — generous, because small hands wobble.
  static const double tolerance = 0.09;

  /// Checks the child's writing "manner": stroke count, order, direction.
  /// Each of the child's pen strokes is compared point-by-point (after
  /// resampling by length) against the SAME-NUMBERED template stroke, so
  /// joining the points in any other manner fails with a friendly tip.
  static OrderCheck checkOrder({
    required List<List<Offset>> drawn,
    required List<List<Offset>> template,
    double tol = 0.13,
  }) {
    if (drawn.length != template.length) {
      final n = template.length;
      return OrderCheck(
        false,
        'Use exactly $n pencil ${n == 1 ? 'move' : 'moves'}, like the guide '
        'shows — one move for each pair of points!',
      );
    }
    for (var i = 0; i < template.length; i++) {
      final d = _orderedStrokeDistance(drawn[i], template[i]);
      if (d > tol) {
        // Was it just drawn backwards?
        if (_orderedStrokeDistance(
                drawn[i].reversed.toList(), template[i]) <= tol) {
          return const OrderCheck(
            false,
            'Almost! That line went BACKWARDS — always start at the '
            'GREEN dot and finish at the orange dot!',
          );
        }
        // Right line, but done at the wrong step number?
        for (var j = 0; j < template.length; j++) {
          if (j != i && _orderedStrokeDistance(drawn[i], template[j]) <= tol) {
            return const OrderCheck(
              false,
              'Right lines, wrong ORDER! Follow the numbers: '
              '1 ➜ 2 first, then the next pair!',
            );
          }
        }
        return const OrderCheck(
          false,
          'Follow the numbers in order — start at the GREEN dot '
          'and slide to the orange dot!',
        );
      }
    }
    return const OrderCheck(true, null);
  }

  /// Average distance between corresponding points of two strokes after
  /// both are resampled to the same number of points along their length.
  /// Small only when the strokes match in SHAPE **and** DIRECTION.
  static double _orderedStrokeDistance(
      List<Offset> drawn, List<Offset> template) {
    const k = 20;
    final a = _resample(drawn, k);
    final b = _resample(template, k);
    var sum = 0.0;
    for (var i = 0; i < k; i++) {
      sum += (a[i] - b[i]).distance;
    }
    return sum / k;
  }

  /// Resamples a stroke to [k] evenly spaced points along its length.
  static List<Offset> _resample(List<Offset> pts, int k) {
    if (pts.isEmpty) return List.filled(k, Offset.zero);
    final lens = <double>[0];
    var total = 0.0;
    for (var i = 0; i < pts.length - 1; i++) {
      total += (pts[i + 1] - pts[i]).distance;
      lens.add(total);
    }
    if (total == 0) return List.filled(k, pts.first);
    final out = <Offset>[];
    var j = 0;
    for (var i = 0; i < k; i++) {
      final target = total * i / (k - 1);
      while (j < lens.length - 2 && lens[j + 1] < target) {
        j++;
      }
      final segLen = lens[j + 1] - lens[j];
      final f = segLen == 0 ? 0.0 : (target - lens[j]) / segLen;
      out.add(Offset.lerp(pts[j], pts[j + 1], f)!);
    }
    return out;
  }

  static TraceResult evaluate({
    required List<List<Offset>> drawn,
    required List<List<Offset>> template,
    bool enforceOrder = true,
  }) {
    final templatePts = template.expand((s) => s).toList();
    final drawnPts = drawn.expand((s) => s).toList();

    // A couple of dots is not a real attempt.
    if (drawnPts.length < 8 || templatePts.isEmpty) {
      return const TraceResult(0, 0, false);
    }

    var covered = 0;
    for (final t in templatePts) {
      if (_nearAny(t, drawnPts)) covered++;
    }
    final coverage = covered / templatePts.length;

    var onShape = 0;
    for (final d in drawnPts) {
      if (_nearAny(d, templatePts)) onShape++;
    }
    final precision = onShape / drawnPts.length;

    // Both matter, but coverage matters most (pow softens the precision
    // penalty a little, so a wobbly-but-complete trace still passes).
    final score =
        (100 * coverage * math.pow(precision, 0.7)).round().clamp(0, 100);

    final stars = score >= 85
        ? 3
        : score >= 70
            ? 2
            : score >= 55
                ? 1
                : 0;

    // DESIGNATED MANNER: even a beautiful trace fails if it was not
    // written point-to-point in the numbered order and direction —
    // learning the standard way is what makes handwriting fast.
    if (enforceOrder) {
      final order = checkOrder(drawn: drawn, template: template);
      if (!order.ok) {
        return TraceResult(score, 0, false,
            coverage: coverage, precision: precision, orderTip: order.kidTip);
      }
    }

    return TraceResult(score, stars, stars > 0,
        coverage: coverage, precision: precision);
  }

  static bool _nearAny(Offset p, List<Offset> pts) {
    for (final q in pts) {
      if ((p - q).distance <= tolerance) return true;
    }
    return false;
  }
}
