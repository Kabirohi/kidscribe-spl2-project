import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/trace_item.dart';
import '../../theme/app_colors.dart';
import '../../widgets/fun.dart';

// =====================================================================
//  Shared pieces for the "how to write it" tutorial video and the
//  on-canvas guide: waypoints, lengths, and the demo painter.
// =====================================================================

/// A numbered dot on the letter.
///
/// Dots are numbered in the order the pencil reaches them in the "how to
/// write" video. A spot the pencil comes back to keeps its first number,
/// so every dot has exactly one number and nothing hides another.
/// Example — A: 1 ➜ 2 (left side), 1 ➜ 3 (right side), 4 ➜ 5 (the bar).
class Waypoint {
  final Offset pos; // 0..1 space
  final int number;
  final bool isStart; // green = a line starts here, orange = it only stops
  const Waypoint(this.pos, this.number, this.isStart);
}

/// The numbered spots of a letter plus, for every stroke, the number it
/// starts at and the number it ends at (end is null for O-like loops).
class _Numbering {
  final List<Waypoint> points;
  final List<(int, int?)> steps;
  _Numbering(this.points, this.steps);
}

_Numbering _number(List<List<Offset>> strokes) {
  final spots = <Offset>[];
  final starts = <bool>[];
  final steps = <(int, int?)>[];
  int spotFor(Offset p, bool start) {
    for (var i = 0; i < spots.length; i++) {
      if ((spots[i] - p).distance < 0.05) {
        if (start) starts[i] = true;
        return i + 1;
      }
    }
    spots.add(p);
    starts.add(start);
    return spots.length;
  }

  for (final s in strokes) {
    final closed = (s.first - s.last).distance < 0.05; // e.g. the letter O
    final a = spotFor(s.first, true);
    final b = closed ? null : spotFor(s.last, false);
    steps.add((a, b));
  }
  return _Numbering([
    for (var i = 0; i < spots.length; i++) Waypoint(spots[i], i + 1, starts[i]),
  ], steps);
}

List<Waypoint> waypointsFor(List<List<Offset>> strokes) =>
    _number(strokes).points;

/// Draws the numbered dots for a letter, [s] = canvas size.
void paintWaypoints(Canvas canvas, List<List<Offset>> strokes, double s) {
  for (final w in waypointsFor(strokes)) {
    final c = Offset(w.pos.dx * s, w.pos.dy * s);
    canvas.drawCircle(c, s * 0.048, Paint()..color = Colors.white);
    canvas.drawCircle(
        c,
        s * 0.042,
        Paint()
          ..color = w.isStart ? AppColors.success : const Color(0xFFF59E0B));
    final tp = TextPainter(
      text: TextSpan(
        text: '${w.number}',
        style: TextStyle(
          color: Colors.white,
          fontSize: s * 0.05,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, c - Offset(tp.width / 2, tp.height / 2));
  }
}

/// Point and direction at distance [d] along [stroke].
(Offset, Offset)? _pointDir(List<Offset> stroke, double d) {
  var left = d;
  for (var i = 0; i < stroke.length - 1; i++) {
    final seg = (stroke[i + 1] - stroke[i]).distance;
    if (seg == 0) continue;
    if (left <= seg) {
      return (
        Offset.lerp(stroke[i], stroke[i + 1], left / seg)!,
        (stroke[i + 1] - stroke[i]) / seg,
      );
    }
    left -= seg;
  }
  return null;
}

/// Purple arrows that show which way to move the pencil.
///
/// They are spaced evenly along the WHOLE path, so a letter drawn in one
/// go (N, M, W, U, S…) shows the way on every part of it, starting with
/// the very first move. Arrows never sit on a numbered dot, and never on
/// top of another arrow where lines cross.
void paintDirectionArrows(
    Canvas canvas, List<List<Offset>> strokes, double s) {
  final dots = waypointsFor(strokes).map((w) => w.pos).toList();
  final placed = <Offset>[];
  final paint = Paint()..color = AppColors.purple;
  for (final stroke in strokes) {
    final len = strokesLength([stroke]);
    if (len < 0.12) continue;
    final n = (len / 0.2).round().clamp(2, 9);
    for (var i = 0; i < n; i++) {
      final hit = _pointDir(stroke, len * (i + 0.5) / n);
      if (hit == null) continue;
      final (p, dir) = hit;
      if (dots.any((d) => (d - p).distance < 0.08)) continue;
      if (placed.any((q) => (q - p).distance < 0.07)) continue;
      placed.add(p);
      // A notched arrowhead (like ➤): long and narrow, so it can only
      // be read one way, even on a curve or a slant.
      final c = Offset(p.dx * s, p.dy * s);
      final normal = Offset(-dir.dy, dir.dx);
      final a = s * 0.03;
      final tip = c + dir * (a * 1.2);
      final left = c - dir * (a * 1.1) + normal * (a * 0.95);
      final right = c - dir * (a * 1.1) - normal * (a * 0.95);
      final notch = c - dir * (a * 0.35);
      final head = Path()
        ..moveTo(tip.dx, tip.dy)
        ..lineTo(left.dx, left.dy)
        ..lineTo(notch.dx, notch.dy)
        ..lineTo(right.dx, right.dy)
        ..close();
      canvas.drawPath(
          head,
          Paint()
            ..color = Colors.white
            ..style = PaintingStyle.stroke
            ..strokeWidth = s * 0.008
            ..strokeJoin = StrokeJoin.round);
      canvas.drawPath(head, paint);
    }
  }
}

/// Label for one stroke-step, matching the video: "join 1 ➜ 3", or
/// "go around from 1" for a loop.
String stepPointsLabel(List<List<Offset>> strokes, int step) {
  final steps = _number(strokes).steps;
  if (step < 0 || step >= steps.length) return '';
  final (a, b) = steps[step];
  return b == null ? 'go around from $a' : 'join $a ➜ $b';
}

/// Which stroke the pencil is drawing at [progress] (0..1 of the whole
/// letter), so the caption can say "join 1 ➜ 3" at the right moment.
int strokeAt(List<List<Offset>> strokes, double progress) {
  final total = strokesLength(strokes);
  if (total <= 0) return 0;
  var left = progress.clamp(0.0, 1.0) * total;
  for (var i = 0; i < strokes.length; i++) {
    final len = strokesLength([strokes[i]]);
    if (left <= len || i == strokes.length - 1) return i;
    left -= len;
  }
  return 0;
}

double strokesLength(List<List<Offset>> strokes) {
  var total = 0.0;
  for (final s in strokes) {
    for (var i = 0; i < s.length - 1; i++) {
      total += (s[i + 1] - s[i]).distance;
    }
  }
  return total;
}

// =====================================================================
//  TUTORIAL VIDEO DIALOG — plays like a little YouTube video:
//  play/pause, -10s / +10s, a draggable progress bar, and 1x/1.5x/2x
//  speed. Slow by default because the app is for ages 5-8.
//  For letters it has two parts on one timeline: first half follows the
//  numbered points, second half writes the letter free-hand.
// =====================================================================

class DemoVideoDialog extends StatefulWidget {
  final TraceItem item;
  final bool twoPhase; // true for letters (points + free hand), false for strokes

  const DemoVideoDialog({super.key, required this.item, required this.twoPhase});

  @override
  State<DemoVideoDialog> createState() => _DemoVideoDialogState();
}

class _DemoVideoDialogState extends State<DemoVideoDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final double _totalBaseMs; // video length at 1x speed
  double _speed = 1.0;
  bool _playing = true; // what the child WANTS (play vs pause)

  bool get _finished => _ctrl.value >= 1.0;

  @override
  void initState() {
    super.initState();
    // SLOW pace for small hands and eyes: ~3 seconds per unit of length.
    final phaseSecs = (strokesLength(widget.item.strokes) * 3.0).clamp(4.0, 10.0);
    _totalBaseMs = phaseSecs * 1000 * (widget.twoPhase ? 2 : 1);
    _ctrl = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: _totalBaseMs.round()),
    )
      ..addListener(() => setState(() {}))
      ..forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  // ---------- player controls ----------

  void _togglePlay() {
    if (_ctrl.isAnimating) {
      _ctrl.stop();
      setState(() => _playing = false);
    } else {
      setState(() => _playing = true);
      _ctrl.forward(from: _finished ? 0 : _ctrl.value); // replay when ended
    }
  }

  void _seek(double deltaSecs) {
    final v = (_ctrl.value + deltaSecs * 1000 / _totalBaseMs).clamp(0.0, 1.0);
    _ctrl.stop();
    _ctrl.value = v;
    if (_playing && v < 1.0) _ctrl.forward(from: v);
  }

  void _cycleSpeed() {
    final next = _speed == 1.0 ? 1.5 : _speed == 1.5 ? 2.0 : 1.0;
    final pos = _ctrl.value;
    final wasAnimating = _ctrl.isAnimating;
    _speed = next;
    _ctrl.duration = Duration(milliseconds: (_totalBaseMs / _speed).round());
    if (wasAnimating) {
      _ctrl.forward(from: pos);
    }
    setState(() {});
  }

  String _fmt(double fraction) {
    final s = (fraction * _totalBaseMs / 1000).round();
    return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.of(context).size;
    final side = math.min(math.min(screen.width, screen.height) * 0.5, 340.0);

    final inPhase2 = widget.twoPhase && _ctrl.value >= 0.5;
    final phaseProgress = widget.twoPhase
        ? (inPhase2 ? (_ctrl.value - 0.5) * 2 : _ctrl.value * 2)
        : _ctrl.value;
    final caption = !widget.twoPhase
        ? 'Watch slowly, then you try!'
        : inPhase2
            ? 'Part 2: now FREE HAND — no dots!'
            : 'Part 1: ${stepPointsLabel(widget.item.strokes, strokeAt(widget.item.strokes, phaseProgress))}';

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'How to write ${widget.item.glyph}',
                style: GoogleFonts.nunito(
                  fontSize: 21,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                caption,
                style: GoogleFonts.nunito(
                    fontSize: 15, color: AppColors.textDark),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: side,
                height: side,
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFDF7),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: CustomPaint(
                      painter: DemoPainter(
                        template: widget.item.strokes,
                        progress: phaseProgress.clamp(0.0, 1.0),
                        showGuide: !inPhase2,
                      ),
                      child: const SizedBox.expand(),
                    ),
                  ),
                ),
              ),
              // ---- progress bar + times (like a video player) ----
              SizedBox(
                width: side,
                child: Row(
                  children: [
                    Text(_fmt(_ctrl.value),
                        style: GoogleFonts.nunito(
                            fontSize: 12, color: Colors.grey.shade600)),
                    Expanded(
                      child: Slider(
                        value: _ctrl.value,
                        activeColor: AppColors.primary,
                        inactiveColor: Colors.grey.shade300,
                        onChanged: (v) {
                          _ctrl.stop();
                          _ctrl.value = v;
                        },
                        onChangeEnd: (v) {
                          if (_playing && v < 1.0) _ctrl.forward(from: v);
                        },
                      ),
                    ),
                    Text(_fmt(1.0),
                        style: GoogleFonts.nunito(
                            fontSize: 12, color: Colors.grey.shade600)),
                  ],
                ),
              ),
              // ---- controls: -10s | play/pause | +10s | speed ----
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    tooltip: '10 seconds back',
                    iconSize: 30,
                    icon: const Icon(Icons.replay_10, color: AppColors.textDark),
                    onPressed: () => _seek(-10),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      tooltip: _ctrl.isAnimating ? 'Pause' : 'Play',
                      iconSize: 34,
                      icon: Icon(
                        _ctrl.isAnimating
                            ? Icons.pause
                            : (_finished ? Icons.replay : Icons.play_arrow),
                        color: Colors.white,
                      ),
                      onPressed: _togglePlay,
                    ),
                  ),
                  const SizedBox(width: 6),
                  IconButton(
                    tooltip: '10 seconds forward',
                    iconSize: 30,
                    icon: const Icon(Icons.forward_10, color: AppColors.textDark),
                    onPressed: () => _seek(10),
                  ),
                  const SizedBox(width: 6),
                  TextButton(
                    onPressed: _cycleSpeed,
                    style: TextButton.styleFrom(
                      backgroundColor: Colors.grey.shade100,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(
                      _speed == 1.0 ? '1x' : (_speed == 1.5 ? '1.5x' : '2x'),
                      style: GoogleFonts.nunito(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textDark,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: side,
                height: 46,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        _finished ? AppColors.primary : Colors.grey.shade200,
                    foregroundColor:
                        _finished ? Colors.white : AppColors.textDark,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Text(
                    _finished ? "Let's write!" : 'Skip',
                    style: GoogleFonts.nunito(
                        fontSize: 17, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Draws the tutorial frame: the letter appears progressively with a
/// pencil at the tip. With [showGuide] the gray letter + numbered points
/// are visible; without it, the pencil writes on a blank page (free-hand).
class DemoPainter extends CustomPainter {
  final List<List<Offset>> template;
  final double progress;
  final bool showGuide;

  DemoPainter({
    required this.template,
    required this.progress,
    required this.showGuide,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;

    if (showGuide) {
      final guide = Paint()
        ..color = const Color(0xFF9E9E9E).withValues(alpha: 0.30)
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.13
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      for (final stroke in template) {
        canvas.drawPath(_path(stroke, s), guide);
      }
      paintWaypoints(canvas, template, s);
    }

    var total = strokesLength(template);
    if (total <= 0) return;

    var remaining = progress * total;
    final ink = Paint()
      ..color = showGuide ? AppColors.secondary : AppColors.purple
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.05
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    var tip = Offset(template.first.first.dx * s, template.first.first.dy * s);
    for (final stroke in template) {
      if (remaining <= 0) break;
      final path = Path()..moveTo(stroke.first.dx * s, stroke.first.dy * s);
      var drewAny = false;
      for (var i = 0; i < stroke.length - 1; i++) {
        final segLen = (stroke[i + 1] - stroke[i]).distance;
        if (segLen == 0) continue;
        if (remaining >= segLen) {
          path.lineTo(stroke[i + 1].dx * s, stroke[i + 1].dy * s);
          tip = Offset(stroke[i + 1].dx * s, stroke[i + 1].dy * s);
          remaining -= segLen;
          drewAny = true;
        } else {
          final p = Offset.lerp(stroke[i], stroke[i + 1], remaining / segLen)!;
          path.lineTo(p.dx * s, p.dy * s);
          tip = Offset(p.dx * s, p.dy * s);
          remaining = 0;
          drewAny = true;
          break;
        }
      }
      if (drewAny) canvas.drawPath(path, ink);
    }

    canvas.drawCircle(tip, s * 0.03, Paint()..color = Colors.white);
    canvas.drawCircle(
      tip,
      s * 0.03,
      Paint()
        ..color = showGuide ? AppColors.secondary : AppColors.purple
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
    drawPencilCursor(canvas, tip, s);
  }

  Path _path(List<Offset> pts, double s) {
    final path = Path()..moveTo(pts.first.dx * s, pts.first.dy * s);
    for (final p in pts.skip(1)) {
      path.lineTo(p.dx * s, p.dy * s);
    }
    return path;
  }

  @override
  bool shouldRepaint(covariant DemoPainter oldDelegate) => true;
}
