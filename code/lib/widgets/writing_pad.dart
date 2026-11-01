import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Holds what the child has drawn on a [WritingPad].
///
/// This is short-lived UI state: the pen sends a new point about 60
/// times a second, so it stays here instead of going through a bloc.
/// When the child taps "Check", the screen hands [strokes] and [times]
/// to its cubit, which does the real work.
class WritingPadController extends ChangeNotifier {
  final List<List<Offset>> strokes = []; // finished strokes, 0..1 space
  final List<List<int>> times = [];      // ms timestamp for each point
  List<Offset>? current;                 // the stroke being drawn now
  List<int>? _currentTimes;
  double side = 300;                     // pad size in pixels (for ML)

  bool get isEmpty => strokes.isEmpty;

  /// Everything drawn, including a stroke that is still in progress.
  List<List<Offset>> get allStrokes =>
      [...strokes, if (current != null) current!];

  void clear() {
    strokes.clear();
    times.clear();
    current = null;
    _currentTimes = null;
    notifyListeners();
  }

  void _start(Offset p) {
    current = [p];
    _currentTimes = [DateTime.now().millisecondsSinceEpoch];
    notifyListeners();
  }

  void _add(Offset p) {
    if (current == null) return;
    if ((p - current!.last).distance < 0.004) return; // skip tiny jitters
    current!.add(p);
    _currentTimes!.add(DateTime.now().millisecondsSinceEpoch);
    notifyListeners();
  }

  void _end() {
    if (current != null && current!.length > 1) {
      strokes.add(current!);
      times.add(_currentTimes!);
    }
    current = null;
    _currentTimes = null;
    notifyListeners();
  }
}

/// A square page the child writes on with the tablet pen (or a finger).
///
/// - Palm rejection: once the pen has been used, finger touches are
///   ignored, so a hand resting on the screen does not draw.
/// - [lines] draws faint exercise-book lines to help with letter size.
class WritingPad extends StatefulWidget {
  final WritingPadController controller;
  final bool lines;
  final Color ink;
  final Widget? background; // e.g. a faint guide drawn under the ink
  final bool enabled;       // false = the pen does nothing (e.g. demo playing)
  final VoidCallback? onPenDown; // told when a new stroke starts

  const WritingPad({
    super.key,
    required this.controller,
    this.lines = true,
    this.ink = AppColors.purple,
    this.background,
    this.enabled = true,
    this.onPenDown,
  });

  @override
  State<WritingPad> createState() => _WritingPadState();
}

class _WritingPadState extends State<WritingPad> {
  int? _pointer;
  bool _stylusSeen = false;

  Offset _norm(Offset local, double side) => Offset(
        (local.dx / side).clamp(0.0, 1.0),
        (local.dy / side).clamp(0.0, 1.0),
      );

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: LayoutBuilder(
        builder: (context, cons) {
          final side = cons.biggest.shortestSide;
          return Listener(
            onPointerDown: (e) {
              if (!widget.enabled || _pointer != null) return;
              if (e.kind == PointerDeviceKind.stylus) _stylusSeen = true;
              if (_stylusSeen && e.kind == PointerDeviceKind.touch) return;
              _pointer = e.pointer;
              widget.controller.side = side;
              widget.controller._start(_norm(e.localPosition, side));
              widget.onPenDown?.call();
            },
            onPointerMove: (e) {
              if (e.pointer != _pointer) return;
              widget.controller._add(_norm(e.localPosition, side));
            },
            onPointerUp: (e) {
              if (e.pointer != _pointer) return;
              _pointer = null;
              widget.controller._end();
            },
            onPointerCancel: (e) {
              if (e.pointer != _pointer) return;
              _pointer = null;
              widget.controller._end();
            },
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFFFFDF7),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.grey.shade200),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Stack(
                  children: [
                    if (widget.background != null)
                      Positioned.fill(child: widget.background!),
                    Positioned.fill(
                      child: AnimatedBuilder(
                        animation: widget.controller,
                        builder: (context, _) => CustomPaint(
                          painter: _PadPainter(
                            strokes: widget.controller.allStrokes,
                            lines: widget.lines,
                            ink: widget.ink,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _PadPainter extends CustomPainter {
  final List<List<Offset>> strokes;
  final bool lines;
  final Color ink;

  _PadPainter({required this.strokes, required this.lines, required this.ink});

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    if (lines) {
      final line = Paint()
        ..color = AppColors.secondary.withValues(alpha: 0.35)
        ..strokeWidth = 1.5;
      canvas.drawLine(Offset(0, s * 0.15), Offset(s, s * 0.15), line);
      canvas.drawLine(Offset(0, s * 0.85), Offset(s, s * 0.85), line);
      final dashed = Paint()
        ..color = AppColors.secondary.withValues(alpha: 0.25)
        ..strokeWidth = 1.2;
      for (var x = 0.0; x < s; x += s * 0.05) {
        canvas.drawLine(
            Offset(x, s * 0.5), Offset(x + s * 0.025, s * 0.5), dashed);
      }
    }
    final paint = Paint()
      ..color = ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.04
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    for (final stroke in strokes) {
      if (stroke.length < 2) continue;
      final path = Path()..moveTo(stroke.first.dx * s, stroke.first.dy * s);
      for (final p in stroke.skip(1)) {
        path.lineTo(p.dx * s, p.dy * s);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _PadPainter old) => true;
}
