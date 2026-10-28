import 'dart:math' as math;
import 'dart:ui';
import 'package:google_mlkit_digital_ink_recognition/google_mlkit_digital_ink_recognition.dart'
    as mlkit;
import 'trace_evaluator.dart';

/// The result of the free-hand ML check.
class FreehandResult {
  final int percent;         // 0..100 — how close the letter is
  final bool passed;         // percent >= 70 unlocks the next letter
  final String? recognizedAs; // what the ML model thinks was written
  final bool usedMl;         // false = model unavailable, geometry-only check
  final String kidMessage;   // friendly message for the child
  final String grownUpReport; // detail line for parent / teacher

  const FreehandResult({
    required this.percent,
    required this.passed,
    required this.recognizedAs,
    required this.usedMl,
    required this.kidMessage,
    required this.grownUpReport,
  });
}

/// Checks a FREE-HAND letter (no guide to trace) in two steps:
///
///  1. MACHINE LEARNING — Google's ML Kit "Digital Ink Recognition" API.
///     It was trained on millions of handwriting samples and tells us which
///     character the strokes look like. Runs ON the device (offline after a
///     one-time model download), which fits KidScribe's offline design.
///
///  2. GEOMETRY — the drawing is scaled onto the ideal letter template and
///     compared region by region (top / middle / bottom), so we can tell the
///     child WHICH PART of the letter needs work — something recognition
///     alone cannot do.
///
///  Final score = 55% ML opinion + 45% shape similarity.
class FreehandChecker {
  static const String _lang = 'en-US';
  static const int passMark = 70;

  final mlkit.DigitalInkRecognizerModelManager _modelManager =
      mlkit.DigitalInkRecognizerModelManager();
  final mlkit.DigitalInkRecognizer _recognizer =
      mlkit.DigitalInkRecognizer(languageCode: _lang);

  /// Downloads the handwriting model the first time (needs internet once).
  Future<bool> ensureModelReady() async {
    try {
      if (await _modelManager.isModelDownloaded(_lang)) return true;
      return await _modelManager.downloadModel(_lang);
    } catch (_) {
      return false;
    }
  }

  void dispose() {
    _recognizer.close();
  }

  mlkit.Ink _toInk(
      List<List<Offset>> drawn, List<List<int>> times, double side) {
    final ink = mlkit.Ink();
    for (var s = 0; s < drawn.length; s++) {
      final stroke = mlkit.Stroke();
      for (var i = 0; i < drawn[s].length; i++) {
        stroke.points.add(mlkit.StrokePoint(
          x: drawn[s][i].dx * side,
          y: drawn[s][i].dy * side,
          t: times[s][i],
        ));
      }
      ink.strokes.add(stroke);
    }
    return ink;
  }

  /// "Which capital letter is this?" — used by Free Writing (SRS FR_13),
  /// where the child may write any letter they like.
  ///
  /// Returns the first A-Z letter among the model's guesses, or null when
  /// the model cannot read a letter at all (or the model is not ready).
  Future<String?> recognizeLetter({
    required List<List<Offset>> drawn,
    required List<List<int>> times,
    required double canvasSide,
  }) async {
    if (!await ensureModelReady()) return null;
    try {
      final candidates =
          await _recognizer.recognize(_toInk(drawn, times, canvasSide));
      for (final c in candidates.take(5)) {
        final t = c.text.trim().toUpperCase();
        if (t.length == 1 && t.codeUnitAt(0) >= 65 && t.codeUnitAt(0) <= 90) {
          return t;
        }
      }
    } catch (_) {}
    return null;
  }

  Future<FreehandResult> check({
    required String letter,
    required List<List<Offset>> drawn,  // strokes in 0..1 canvas space
    required List<List<int>> times,     // millisecond timestamp per point
    required List<List<Offset>> template,
    required double canvasSide,         // canvas size in pixels (for ML)
  }) async {
    // ---------- Step 1: ask the ML model what letter this looks like ----------
    var usedMl = false;
    var mlComponent = 25; // pessimistic default if ML can't run
    String? recognized;

    if (await ensureModelReady()) {
      try {
        final ink = mlkit.Ink();
        for (var s = 0; s < drawn.length; s++) {
          final stroke = mlkit.Stroke();
          for (var i = 0; i < drawn[s].length; i++) {
            stroke.points.add(mlkit.StrokePoint(
              x: drawn[s][i].dx * canvasSide,
              y: drawn[s][i].dy * canvasSide,
              t: times[s][i],
            ));
          }
          ink.strokes.add(stroke);
        }

        final candidates = await _recognizer.recognize(ink);
        usedMl = true;
        if (candidates.isNotEmpty) recognized = candidates.first.text;

        // Where does OUR letter appear in the model's guesses?
        final rank = candidates
            .indexWhere((c) => c.text.toUpperCase() == letter.toUpperCase());
        if (rank == 0) {
          mlComponent = 96; // top guess — clearly recognizable
        } else if (rank >= 1 && rank <= 2) {
          mlComponent = 82; // close — in the top 3
        } else if (rank >= 3) {
          mlComponent = 62; // recognizable but not confident
        } else {
          mlComponent = 25; // the model does not see this letter at all
        }
      } catch (_) {
        usedMl = false;
      }
    }

    // ---------- Step 2: shape comparison against the ideal letter ----------
    final fitted = _fitToTemplate(drawn, template);
    final templatePts = template.expand((s) => s).toList();
    final drawnPts = fitted.expand((s) => s).toList();

    const tol = 0.11; // free-hand is judged a bit more kindly than tracing
    var covered = 0;
    for (final t in templatePts) {
      if (_nearAny(t, drawnPts, tol)) covered++;
    }
    final coverage = templatePts.isEmpty ? 0.0 : covered / templatePts.length;

    var onShape = 0;
    for (final d in drawnPts) {
      if (_nearAny(d, templatePts, tol)) onShape++;
    }
    final precision = drawnPts.isEmpty ? 0.0 : onShape / drawnPts.length;

    final geomScore = 100 * coverage * math.pow(precision, 0.7);

    // Which third of the letter (top / middle / bottom) is weakest?
    final zoneNames = ['top', 'middle', 'bottom'];
    final zoneCoverage = _zoneCoverage(templatePts, drawnPts, tol);
    var weakest = 0;
    for (var z = 1; z < 3; z++) {
      if (zoneCoverage[z] < zoneCoverage[weakest]) weakest = z;
    }

    // ---------- Step 3: blend into one percentage ----------
    var percent = usedMl
        ? (0.55 * mlComponent + 0.45 * geomScore).round().clamp(0, 100)
        : geomScore.round().clamp(0, 100);

    // ---------- Step 3b: DESIGNATED MANNER check ----------
    // The free-hand letter must be written the same way as the points
    // side: same strokes, same order, same direction. Otherwise the
    // child's handwriting will be slow later — so it cannot pass.
    final order = TraceEvaluator.checkOrder(
        drawn: fitted, template: template, tol: 0.17);
    if (!order.ok && percent > passMark - 5) {
      percent = passMark - 5; // capped below the pass mark
    }
    final passed = order.ok && percent >= passMark;

    // ---------- Step 4: friendly words ----------
    final weakZoneBad = zoneCoverage[weakest] < 0.75;
    String kidMessage;
    if (!order.ok) {
      // The letter may LOOK fine, but it was not written the KidScribe way.
      kidMessage =
          'Oops — your $letter was not written the KidScribe way!\n'
          '${order.kidTip ?? 'Write it just like the points side: 1 ➜ 2, then the next numbers.'}\n'
          'Writing the right way makes your hand super fast!';
    } else if (percent >= 95) {
      kidMessage = 'WOW! $percent%! Your $letter is amazing!';
    } else if (passed) {
      kidMessage =
          'You got $percent%! Can you make it 100%? Try once more!';
    } else {
      kidMessage =
          '$percent% — so close! You need $passMark% to unlock the next letter. '
          'Watch how it\'s drawn and try again!';
    }
    if (order.ok && weakZoneBad) {
      kidMessage +=
          '\nThe ${zoneNames[weakest]} part of your $letter needs a little love';
    }

    // ---- a short, plain-words report for parents and teachers ----
    String readLine;
    if (!usedMl) {
      readLine =
          'We checked the shape only this time (the smart reader was not available).';
    } else if (recognized != null &&
        recognized.toUpperCase() == letter.toUpperCase()) {
      readLine = 'Our smart reader looked at it and said: "That\'s a $letter!"';
    } else if (recognized != null) {
      readLine =
          'Our smart reader thought it looked more like "$recognized" than "$letter".';
    } else {
      readLine = 'Our smart reader could not recognize a letter yet.';
    }

    String partsLine;
    if (weakZoneBad) {
      partsLine =
          'The ${zoneNames[weakest]} part of the letter needs the most practice — '
          'only ${(zoneCoverage[weakest] * 100).round()}% of it was drawn.';
    } else if (precision < 0.75) {
      partsLine =
          'All parts of the letter are there, but the lines wander off the ideal shape a little.';
    } else {
      partsLine =
          'All parts of the letter look good — top, middle and bottom.';
    }

    final advice = !order.ok
        ? 'The letter was not written in the designated stroke order or direction. Have the child follow the numbered points (with the guide) — the standard way builds fast, fluent handwriting.'
        : weakZoneBad
            ? 'Practice the ${zoneNames[weakest]} part on the points side a few times, then try free-hand again.'
            : (precision < 0.75
                ? 'Slower strokes are neater strokes — try writing it a little more slowly.'
                : 'Just keep practicing to make it perfect!');

    final grownUpReport = '$readLine\n$partsLine\nTip: $advice';

    return FreehandResult(
      percent: percent,
      passed: passed,
      recognizedAs: recognized,
      usedMl: usedMl,
      kidMessage: kidMessage,
      grownUpReport: grownUpReport,
    );
  }

  // ---------- helpers ----------

  /// Scales + moves the child's drawing so its bounding box sits on the
  /// template's bounding box. Free-hand letters can be small or off-center —
  /// position should not change the score, only SHAPE should.
  List<List<Offset>> _fitToTemplate(
      List<List<Offset>> drawn, List<List<Offset>> template) {
    final d = _bbox(drawn.expand((s) => s));
    final t = _bbox(template.expand((s) => s));
    if (d == null || t == null) return drawn;

    // A nearly flat box (a dot or a straight line) cannot be stretched.
    final sx = d.width < 0.04 ? 1.0 : t.width / d.width;
    final sy = d.height < 0.04 ? 1.0 : t.height / d.height;

    return [
      for (final stroke in drawn)
        [
          for (final p in stroke)
            Offset(
              t.left + (p.dx - d.left) * sx,
              t.top + (p.dy - d.top) * sy,
            )
        ]
    ];
  }

  Rect? _bbox(Iterable<Offset> pts) {
    if (pts.isEmpty) return null;
    var minX = double.infinity, minY = double.infinity;
    var maxX = -double.infinity, maxY = -double.infinity;
    for (final p in pts) {
      minX = math.min(minX, p.dx);
      minY = math.min(minY, p.dy);
      maxX = math.max(maxX, p.dx);
      maxY = math.max(maxY, p.dy);
    }
    return Rect.fromLTRB(minX, minY, maxX, maxY);
  }

  /// Coverage of the template split into three horizontal zones
  /// (top / middle / bottom third of the letter).
  List<double> _zoneCoverage(
      List<Offset> templatePts, List<Offset> drawnPts, double tol) {
    final box = _bbox(templatePts)!;
    final third = box.height / 3;
    final result = <double>[];
    for (var z = 0; z < 3; z++) {
      final zTop = box.top + third * z;
      final zBottom = zTop + third;
      final zonePts = templatePts
          .where((p) => p.dy >= zTop && p.dy < zBottom + (z == 2 ? 0.001 : 0))
          .toList();
      if (zonePts.isEmpty) {
        result.add(1);
        continue;
      }
      final hit = zonePts.where((p) => _nearAny(p, drawnPts, tol)).length;
      result.add(hit / zonePts.length);
    }
    return result;
  }

  bool _nearAny(Offset p, List<Offset> pts, double tol) {
    for (final q in pts) {
      if ((p - q).distance <= tol) return true;
    }
    return false;
  }
}
