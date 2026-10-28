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

/// A numbered dot on the letter: the child goes from a green start dot
/// to the next orange dot (1 ➜ 2, 3 ➜ 4 ...).
class Waypoint {
  final Offset pos; // 0..1 space
  final int number;
  final bool isStart;
  const Waypoint(this.pos, this.number, this.isStart);
}

List<Waypoint> waypointsFor(List<List<Offset>> strokes) {
  final list = <Waypoint>[];
  var n = 1;
  for (final s in strokes) {
    final closed = (s.first - s.last).distance < 0.05; // e.g. the letter O
    list.add(Waypoint(s.first, n++, true));
    if (!closed) list.add(Waypoint(s.last, n++, false));
  }
  return list;
}

/// Label for one stroke-step, e.g. "1 ➜ 2" or "go around from 1" (circle).
String stepPointsLabel(List<List<Offset>> strokes, int step) {
  var n = 1;
  for (var i = 0; i < strokes.length; i++) {
    final closed = (strokes[i].first - strokes[i].last).distance < 0.05;
    final start = n;
    n += closed ? 1 : 2;
    if (i == step) {
      return closed ? 'go around from $start' : 'join $start ➜ ${start + 1}';
    }
  }
  return '';
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
            : 'Part 1: follow the points 1 ➜ 2!';

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
      for (final w in waypointsFor(template)) {
        final c = Offset(w.pos.dx * s, w.pos.dy * s);
        canvas.drawCircle(
            c,
            s * 0.045,
            Paint()
              ..color =
                  w.isStart ? AppColors.success : const Color(0xFFF59E0B));
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
