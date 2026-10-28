import 'package:audioplayers/audioplayers.dart';
import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../blocs/learn/tracing_cubit.dart';
import '../../models/trace_item.dart';
import '../../services/badge_service.dart';
import '../../services/progress_service.dart';
import '../../services/trace_evaluator.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common.dart';
import '../../widgets/fun.dart';
import '../../widgets/writing_pad.dart';
import 'badge_popup.dart';
import 'demo_video.dart';

/// The drawing screen: shows the gray guide shape, lets the child trace it
/// with the tablet pen (or a finger), then checks the trace and gives stars.
///
/// Extras:
///  - "Watch" button: a little pencil animates along the shape first,
///    then stays as a faint teal reference for the child to copy.
///  - 3 stars = confetti burst + a happy chime.
class TracingScreen extends StatelessWidget {
  final List<TraceItem> items; // the whole list, so "Next" can move forward
  final int startIndex;        // which item to open first

  /// TEST MODE (SRS FR_24/US_33): no tutorial video and no demo button.
  final bool examMode;

  const TracingScreen({
    super.key,
    required this.items,
    this.startIndex = 0,
    this.examMode = false,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (ctx) => TracingCubit(
        progress: ctx.read<ProgressService>(),
        badges: ctx.read<BadgeService>(),
        items: items,
        startIndex: startIndex,
        examMode: examMode,
      )..load(),
      child: _TracingView(examMode: examMode),
    );
  }
}

/// Stateful only for things that belong to the screen itself: the pen
/// lines, the demo animation, confetti and sound.
class _TracingView extends StatefulWidget {
  final bool examMode;
  const _TracingView({required this.examMode});

  @override
  State<_TracingView> createState() => _TracingViewState();
}

class _TracingViewState extends State<_TracingView>
    with SingleTickerProviderStateMixin {
  final _pad = WritingPadController();
  late final ConfettiController _confetti =
      ConfettiController(duration: const Duration(seconds: 2));
  final AudioPlayer _player = AudioPlayer();

  // "Watch how it's drawn" demo: 0 -> 1 sweeps the pencil along the shape.
  late final AnimationController _demoCtrl = AnimationController(vsync: this)
    ..addStatusListener((_) => setState(() {}));

  TracingCubit get _cubit => context.read<TracingCubit>();

  @override
  void dispose() {
    _pad.dispose();
    _demoCtrl.dispose();
    _confetti.dispose();
    _player.dispose();
    super.dispose();
  }

  void _showVideo() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => DemoVideoDialog(item: _cubit.item, twoPhase: false),
    );
  }

  void _clear() {
    _pad.clear();
    _demoCtrl.reset();
  }

  /// Plays the on-canvas "watch how it's drawn" animation. The child's
  /// drawing is KEPT; the demo just plays over it in teal.
  void _watchDemo() {
    var length = 0.0;
    for (final stroke in _cubit.item.strokes) {
      for (var i = 0; i < stroke.length - 1; i++) {
        length += (stroke[i + 1] - stroke[i]).distance;
      }
    }
    final secs = (length * 1.6).clamp(1.5, 5.0);
    _demoCtrl.duration = Duration(milliseconds: (secs * 1000).round());
    _demoCtrl.forward(from: 0);
  }

  /// The cubit gave a result: celebrate, show new badges, then the result.
  Future<void> _onResult(TracingState s) async {
    final r = s.result!;
    if (r.stars == 3) {
      _confetti.play();
      _player.play(AssetSource('sounds/success.wav'));
      await Future.delayed(const Duration(milliseconds: 700));
      if (!mounted) return;
    }
    if (s.newBadges.isNotEmpty) {
      await showBadgePopup(context, s.newBadges);
      if (!mounted) return;
      _cubit.badgesShown();
    }
    _showResult(r);
  }

  void _showResult(TraceResult r) {
    final hasNext = _cubit.hasNext;
    final title = r.stars == 3
        ? 'Amazing!'
        : r.stars == 2
            ? 'Great job!'
            : r.stars == 1
                ? 'Good work!'
                : 'Almost! Try again';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(title,
            textAlign: TextAlign.center,
            style: kid(26, weight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                3,
                (i) => Icon(
                  i < r.stars ? Icons.star_rounded : Icons.star_outline_rounded,
                  size: 44,
                  color: i < r.stars ? Colors.amber : Colors.grey.shade400,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text('Score: ${r.score}', style: kid(16)),
            // Tell the child WHAT to fix (SRS FR_7 / tests T_26, T_28)
            if (r.tip != null) ...[
              const SizedBox(height: 8),
              Text(r.tip!,
                  textAlign: TextAlign.center,
                  style: kid(15,
                      weight: FontWeight.w600, color: AppColors.purple)),
            ],
          ],
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _clear();
            },
            child: Text('Try Again',
                style: kid(18, color: AppColors.secondary)),
          ),
          if (r.passed)
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: () {
                Navigator.pop(ctx);
                if (hasNext) {
                  _clear();
                  _cubit.next();
                } else {
                  Navigator.pop(context); // back to the item list
                }
              },
              child: Text(hasNext ? 'Next' : 'Done',
                  style: kid(18, color: Colors.white)),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        BlocListener<TracingCubit, TracingState>(
          listenWhen: (a, b) => a.introTick != b.introTick,
          listener: (_, __) => _showVideo(),
        ),
        BlocListener<TracingCubit, TracingState>(
          listenWhen: (a, b) => a.resultTick != b.resultTick,
          listener: (_, s) => _onResult(s),
        ),
        BlocListener<TracingCubit, TracingState>(
          listenWhen: (a, b) => b.message != null && a.message != b.message,
          listener: (context, s) => showKidSnack(context, s.message!.text),
        ),
      ],
      child: BlocBuilder<TracingCubit, TracingState>(
        builder: (context, s) {
          final item = _cubit.item;
          return Scaffold(
            body: Stack(
              children: [
                Container(
                  decoration:
                      const BoxDecoration(gradient: AppColors.bgGradient),
                  child: SafeArea(
                    child: Column(
                      children: [
                        _header(item, s),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Text(item.hint,
                              textAlign: TextAlign.center, style: kid(15)),
                        ),
                        // The square canvas (fits portrait AND landscape)
                        Expanded(
                          child: Center(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: WritingPad(
                                controller: _pad,
                                lines: false,
                                ink: AppColors.primary,
                                // no drawing while the demo plays
                                enabled: !_demoCtrl.isAnimating,
                                // the child starts -> hide the demo
                                onPenDown: () {
                                  if (_demoCtrl.value > 0) _demoCtrl.reset();
                                },
                                background: AnimatedBuilder(
                                  animation: _demoCtrl,
                                  builder: (_, __) => CustomPaint(
                                    painter: _GuidePainter(
                                      template: item.strokes,
                                      demoProgress: _demoCtrl.value > 0
                                          ? _demoCtrl.value
                                          : null,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        _buttons(s),
                      ],
                    ),
                  ),
                ),
                // Confetti rains from the top-center for 3 stars.
                Align(
                  alignment: Alignment.topCenter,
                  child: ConfettiWidget(
                    confettiController: _confetti,
                    blastDirectionality: BlastDirectionality.explosive,
                    numberOfParticles: 24,
                    emissionFrequency: 0.03,
                    maxBlastForce: 25,
                    minBlastForce: 8,
                    gravity: 0.25,
                    shouldLoop: false,
                    colors: const [
                      AppColors.primary,
                      AppColors.secondary,
                      AppColors.purple,
                      AppColors.accent,
                      Colors.amber,
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _header(TraceItem item, TracingState s) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Row(
          children: [
            const Padding(
              padding: EdgeInsets.only(left: 8),
              child: KidBackButton(),
            ),
            Expanded(
              child: Text(item.name,
                  textAlign: TextAlign.center,
                  style: kid(26,
                      weight: FontWeight.w900, color: AppColors.textDark)),
            ),
            // Hidden during a test (SRS US_33).
            if (!widget.examMode)
              IconButton(
                tooltip: 'Watch the tutorial video',
                icon: const Icon(Icons.smart_display,
                    size: 28, color: AppColors.secondary),
                onPressed: _showVideo,
              ),
            KidTag('${s.index + 1}/${_cubit.items.length}'),
            const SizedBox(width: 12),
          ],
        ),
      );

  Widget _buttons(TracingState s) {
    ButtonStyle style(Color bg, Color fg, double elevation) =>
        ElevatedButton.styleFrom(
          backgroundColor: bg,
          foregroundColor: fg,
          elevation: elevation,
          padding: EdgeInsets.zero,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        );
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
      child: Row(
        children: [
          // No demo button during a test (SRS US_33).
          if (!widget.examMode) ...[
            Tooltip(
              message: 'Watch how to draw it',
              child: SizedBox(
                width: 56,
                height: 56,
                child: ElevatedButton(
                  onPressed: _watchDemo,
                  style: style(AppColors.secondary, Colors.white, 3),
                  child: const Icon(Icons.play_arrow_rounded, size: 34),
                ),
              ),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: SizedBox(
              height: 56,
              child: ElevatedButton(
                onPressed: _clear,
                style: style(Colors.white, AppColors.textDark, 2),
                child: Text('Clear', style: kid(19, weight: FontWeight.w600)),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: SizedBox(
              height: 56,
              child: ElevatedButton(
                onPressed: s.checking
                    ? null
                    : () => _cubit.check(List.of(_pad.strokes)),
                style: style(AppColors.primary, Colors.white, 4),
                child: Text('Check ✓',
                    style: kid(19,
                        weight: FontWeight.w600, color: Colors.white)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Paints under the child's ink: the gray guide shape, numbered start
/// dots, and the demo pencil animation.
class _GuidePainter extends CustomPainter {
  final List<List<Offset>> template;
  final double? demoProgress; // 0..1 while "watch how it's drawn" plays

  _GuidePainter({required this.template, this.demoProgress});

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;

    // 1) The gray guide shape (thick, so it is easy to stay inside)
    final guide = Paint()
      ..color = const Color(0xFF9E9E9E).withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.14
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    for (final stroke in template) {
      canvas.drawPath(_path(stroke, s), guide);
    }

    // 2) Numbered waypoints: green = start (go!), orange = stop.
    for (final w in waypointsFor(template)) {
      final center = Offset(w.pos.dx * s, w.pos.dy * s);
      canvas.drawCircle(center, s * 0.048, Paint()..color = Colors.white);
      canvas.drawCircle(
          center,
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
      tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
    }

    // 3) The "watch how it's drawn" pencil demo (teal)
    if (demoProgress != null) _drawDemo(canvas, s, demoProgress!);
  }

  /// Draws the shape up to [progress] of its length, with a little pencil
  /// at the moving tip, like a teacher showing how.
  void _drawDemo(Canvas canvas, double s, double progress) {
    var total = 0.0;
    for (final stroke in template) {
      for (var i = 0; i < stroke.length - 1; i++) {
        total += (stroke[i + 1] - stroke[i]).distance;
      }
    }
    if (total <= 0) return;

    var remaining = progress * total;
    final demoInk = Paint()
      ..color = AppColors.secondary
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
      if (drewAny) canvas.drawPath(path, demoInk);
    }

    // The moving pencil tip
    canvas.drawCircle(tip, s * 0.032, Paint()..color = Colors.white);
    canvas.drawCircle(
      tip,
      s * 0.032,
      Paint()
        ..color = AppColors.secondary
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
    drawPencilCursor(canvas, tip, s);
  }

  /// Turns a list of 0..1 points into a pixel Path.
  Path _path(List<Offset> pts, double s) {
    final path = Path()..moveTo(pts.first.dx * s, pts.first.dy * s);
    for (final p in pts.skip(1)) {
      path.lineTo(p.dx * s, p.dy * s);
    }
    return path;
  }

  @override
  bool shouldRepaint(covariant _GuidePainter old) =>
      old.demoProgress != demoProgress || old.template != template;
}
