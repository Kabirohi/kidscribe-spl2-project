import 'package:audioplayers/audioplayers.dart';
import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../blocs/learn/letter_practice_cubit.dart';
import '../../data/trace_templates.dart';
import '../../services/badge_service.dart';
import '../../services/freehand_checker.dart';
import '../../services/progress_service.dart';
import '../../services/trace_evaluator.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common.dart';
import '../../widgets/fun.dart';
import '../../widgets/writing_pad.dart';
import 'badge_popup.dart';
import 'demo_video.dart';

/// LEVEL screen for one letter, split into TWO halves:
///
///  GUIDED side — trace the letter following NUMBERED points
///     (1 ➜ 2, 3 ➜ 4 ...) with arrows showing the direction, plus a
///     GUIDE that animates each step ON the actual points, with
///     previous / next / auto-play controls. Available any time.
///
///  FREE-HAND side — write the same letter on a blank page;
///     Google's ML Kit handwriting model + a shape check score it 0-100%.
///
/// A tutorial video (playable, pausable, seekable, 1x/1.5x/2x) runs
/// before each level and can be re-watched at ANY time — opening it never
/// touches the child's drawing or progress.
///
/// The next letter unlocks ONLY when BOTH sides are done
/// (guided passed AND free-hand >= 70%).
class LetterPracticeScreen extends StatelessWidget {
  final int levelIndex; // 0..25 into allLetterItems (family order)

  /// TEST MODE (SRS FR_24/US_33): no tutorial video, no guide, and the
  /// numbered points are hidden, so the child works with no help.
  final bool examMode;

  const LetterPracticeScreen({
    super.key,
    required this.levelIndex,
    this.examMode = false,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (ctx) => LetterPracticeCubit(
        progress: ctx.read<ProgressService>(),
        badges: ctx.read<BadgeService>(),
        levelIndex: levelIndex,
        examMode: examMode,
      )..load(),
      child: _LetterView(examMode: examMode),
    );
  }
}

/// Stateful only for what belongs to the screen: the two pens, the
/// guide animation, confetti and sound.
class _LetterView extends StatefulWidget {
  final bool examMode;
  const _LetterView({required this.examMode});

  @override
  State<_LetterView> createState() => _LetterViewState();
}

class _LetterViewState extends State<_LetterView>
    with SingleTickerProviderStateMixin {
  final _gPad = WritingPadController(); // guided side
  final _fPad = WritingPadController(); // free-hand side

  late final ConfettiController _confetti =
      ConfettiController(duration: const Duration(seconds: 2));
  final AudioPlayer _player = AudioPlayer();

  // On-canvas GUIDE: replays each stroke on the real points.
  bool _guideOn = false;
  int _guideStep = 0;
  bool _guideAuto = true;
  late final AnimationController _guideCtrl = AnimationController(vsync: this)
    ..addStatusListener((status) {
      if (status == AnimationStatus.completed &&
          _guideAuto &&
          _guideStep + 1 < _strokes.length) {
        _guideStep++;
        _startGuideStep();
      }
      if (mounted) setState(() {}); // play / pause icon
    });

  LetterPracticeCubit get _cubit => context.read<LetterPracticeCubit>();
  List<List<Offset>> get _strokes => _cubit.state.item.strokes;

  @override
  void dispose() {
    _gPad.dispose();
    _fPad.dispose();
    _guideCtrl.dispose();
    _confetti.dispose();
    _player.dispose();
    super.dispose();
  }

  // ================= guide controls =================

  void _startGuideStep() {
    final secs = (strokesLength([_strokes[_guideStep]]) * 3.0).clamp(1.5, 6.0);
    _guideCtrl.duration = Duration(milliseconds: (secs * 1000).round());
    _guideCtrl.forward(from: 0);
  }

  void _toggleGuide() {
    setState(() => _guideOn = !_guideOn);
    if (_guideOn) {
      _guideStep = 0;
      _guideAuto = true;
      _startGuideStep();
    } else {
      _guideCtrl.stop();
      _guideCtrl.reset();
    }
  }

  void _guidePrev() {
    if (_guideStep > 0) setState(() => _guideStep--);
    _startGuideStep();
  }

  void _guideNext() {
    if (_guideStep + 1 < _strokes.length) {
      setState(() => _guideStep++);
      _startGuideStep();
    }
  }

  void _guidePlayPause() {
    if (_guideCtrl.isAnimating) {
      _guideCtrl.stop();
      setState(() => _guideAuto = false);
    } else {
      setState(() => _guideAuto = true);
      _guideCtrl.forward(from: _guideCtrl.value >= 1 ? 0 : _guideCtrl.value);
    }
  }

  // ================= results =================

  Future<void> _celebrate(bool big, List<BadgeDef> badges) async {
    if (big) {
      _confetti.play();
      _player.play(AssetSource('sounds/success.wav'));
      await Future.delayed(const Duration(milliseconds: 700));
      if (!mounted) return;
    }
    if (badges.isNotEmpty) {
      await showBadgePopup(context, badges);
      if (mounted) _cubit.badgesShown();
    }
  }

  Future<void> _onGuided(LetterPracticeState s) async {
    await _celebrate(s.guidedResult!.stars == 3, s.newBadges);
    if (mounted) _showGuidedResult(s.guidedResult!);
  }

  Future<void> _onFree(LetterPracticeState s) async {
    await _celebrate(s.freeResult!.percent >= 95, s.newBadges);
    if (mounted) _showFreeResult(s.freeResult!);
  }

  /// Opens the tutorial video. Both drawings and all progress stay.
  void _showVideo() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => DemoVideoDialog(item: _cubit.state.item, twoPhase: true),
    );
  }

  void _showGuidedResult(TraceResult r) {
    final title = r.stars == 3
        ? 'Amazing!'
        : r.stars == 2
            ? 'Great job!'
            : r.stars == 1
                ? 'Good work!'
                : 'Almost! Try again';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(title,
            textAlign: TextAlign.center,
            style: kid(24, weight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                3,
                (i) => Icon(
                  i < r.stars ? Icons.star_rounded : Icons.star_outline_rounded,
                  size: 40,
                  color: i < r.stars ? Colors.amber : Colors.grey.shade400,
                ),
              ),
            ),
            if (r.tip != null) ...[
              const SizedBox(height: 8),
              Text(r.tip!,
                  textAlign: TextAlign.center,
                  style: kid(16, color: AppColors.purple)),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _gPad.clear();
            },
            child: Text(r.passed ? 'Practice Again' : 'Try Again',
                style: kid(16, color: AppColors.secondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('OK', style: kid(16, color: AppColors.primary)),
          ),
        ],
      ),
    );
  }

  void _showFreeResult(FreehandResult r) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(r.passed ? 'You did it!' : 'Almost there!',
            textAlign: TextAlign.center,
            style: kid(24, weight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('${r.percent}%',
                  style: kid(52,
                      weight: FontWeight.bold,
                      color: r.passed ? AppColors.success : AppColors.primary)),
              const SizedBox(height: 6),
              Text(r.kidMessage, textAlign: TextAlign.center, style: kid(17)),
              const SizedBox(height: 10),
              const Divider(),
              Align(
                alignment: Alignment.centerLeft,
                child: Text('For grown-ups',
                    style: kid(15, weight: FontWeight.w600)),
              ),
              const SizedBox(height: 4),
              Text(r.grownUpReport,
                  style: kid(14, color: Colors.grey.shade700)
                      .copyWith(height: 1.4)),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _fPad.clear();
            },
            child: Text('Try Again', style: kid(16, color: AppColors.secondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('OK', style: kid(16, color: AppColors.primary)),
          ),
        ],
      ),
    );
  }

  void _nextLevel() {
    _gPad.clear();
    _fPad.clear();
    _guideCtrl.reset();
    setState(() {
      _guideOn = false;
      _guideStep = 0;
    });
    _cubit.nextLevel();
  }

  // ================= UI =================

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        BlocListener<LetterPracticeCubit, LetterPracticeState>(
          listenWhen: (a, b) => a.introTick != b.introTick,
          listener: (_, __) => _showVideo(),
        ),
        BlocListener<LetterPracticeCubit, LetterPracticeState>(
          listenWhen: (a, b) => a.guidedTick != b.guidedTick,
          listener: (_, s) => _onGuided(s),
        ),
        BlocListener<LetterPracticeCubit, LetterPracticeState>(
          listenWhen: (a, b) => a.freeTick != b.freeTick,
          listener: (_, s) => _onFree(s),
        ),
        BlocListener<LetterPracticeCubit, LetterPracticeState>(
          listenWhen: (a, b) => b.message != null && a.message != b.message,
          listener: (context, s) => showKidSnack(context, s.message!.text),
        ),
        BlocListener<LetterPracticeCubit, LetterPracticeState>(
          listenWhen: (a, b) => !a.finishedAll && b.finishedAll,
          listener: (context, _) {
            showKidSnack(context, 'You finished ALL the letters!');
            Navigator.pop(context);
          },
        ),
      ],
      child: BlocBuilder<LetterPracticeCubit, LetterPracticeState>(
        builder: (context, s) => Scaffold(
          body: Stack(
            children: [
              Container(
                decoration: const BoxDecoration(gradient: AppColors.bgGradient),
                child: SafeArea(
                  child: Column(
                    children: [
                      _header(s),
                      Expanded(
                        child: LayoutBuilder(
                          builder: (context, c) {
                            final wide = c.maxWidth > c.maxHeight;
                            final guided = _pane(s, isGuided: true);
                            final free = _pane(s, isGuided: false);
                            // Tablet landscape: side by side. Portrait: stacked.
                            return wide
                                ? Row(children: [
                                    Expanded(child: guided),
                                    Expanded(child: free),
                                  ])
                                : Column(children: [
                                    Expanded(child: guided),
                                    Expanded(child: free),
                                  ]);
                          },
                        ),
                      ),
                      _nextBar(s),
                    ],
                  ),
                ),
              ),
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
        ),
      ),
    );
  }

  Widget _header(LetterPracticeState s) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        child: Row(
          children: [
            const Padding(
              padding: EdgeInsets.only(left: 8),
              child: KidBackButton(),
            ),
            Expanded(
              child: Text('Level ${s.level + 1}: Letter ${s.item.glyph}',
                  textAlign: TextAlign.center,
                  style: kid(22,
                      weight: FontWeight.w900, color: AppColors.textDark)),
            ),
            // Re-watch the tutorial any time (hidden in a test, SRS US_33).
            if (!widget.examMode)
              IconButton(
                tooltip: 'Watch the tutorial video',
                icon: const Icon(Icons.smart_display,
                    size: 28, color: AppColors.secondary),
                onPressed: _showVideo,
              ),
            KidTag('${s.level + 1}/${allLetterItems.length}'),
            const SizedBox(width: 12),
          ],
        ),
      );

  Widget _pane(LetterPracticeState s, {required bool isGuided}) {
    final done = isGuided ? s.guidedDone : s.freeDone;
    final title = isGuided ? 'Follow the points' : 'Free hand';
    final statusText = isGuided
        ? (s.guidedDone ? '${s.guidedStars}/3 stars' : 'not done')
        : (s.freeBest > 0 ? 'best ${s.freeBest}%' : 'not done');
    final pad = isGuided ? _gPad : _fPad;

    return Padding(
      padding: const EdgeInsets.all(6),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: done ? AppColors.success : Colors.grey.shade300, width: 2),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 6, 0),
              child: Row(
                children: [
                  Expanded(
                      child: Text(title,
                          style: kid(15, weight: FontWeight.w600))),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: done
                          ? AppColors.success.withValues(alpha: 0.15)
                          : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(done ? '✓ $statusText' : statusText,
                        style: kid(12,
                            color: done
                                ? AppColors.success
                                : Colors.grey.shade600)),
                  ),
                  // The guide is hidden during a test (SRS US_33).
                  if (isGuided && !widget.examMode)
                    IconButton(
                      tooltip: 'Show me how (guide)',
                      visualDensity: VisualDensity.compact,
                      icon: Icon(Icons.tips_and_updates,
                          size: 22,
                          color:
                              _guideOn ? const Color(0xFFF59E0B) : Colors.grey),
                      onPressed: _toggleGuide,
                    ),
                ],
              ),
            ),
            if (isGuided && _guideOn) _guideBar(s),
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: WritingPad(
                    controller: pad,
                    lines: !isGuided,
                    ink: isGuided ? AppColors.primary : AppColors.purple,
                    background: isGuided
                        ? AnimatedBuilder(
                            animation: _guideCtrl,
                            builder: (_, __) => CustomPaint(
                              painter: _GuidedPainter(
                                template: s.item.strokes,
                                guideStep: _guideOn ? _guideStep : null,
                                guideProgress: _guideCtrl.value,
                                showHelp: !widget.examMode,
                              ),
                            ),
                          )
                        : null,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
              child: Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 40,
                      child: ElevatedButton(
                        onPressed: pad.clear,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey.shade100,
                          foregroundColor: AppColors.textDark,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text('Clear', style: kid(15)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SizedBox(
                      height: 40,
                      child: ElevatedButton(
                        onPressed: s.checkingFree
                            ? null
                            : isGuided
                                ? () => _cubit.checkGuided(List.of(_gPad.strokes))
                                : () => _cubit.checkFree(List.of(_fPad.strokes),
                                    List.of(_fPad.times), _fPad.side),
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              isGuided ? AppColors.secondary : AppColors.purple,
                          foregroundColor: Colors.white,
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        child: !isGuided && s.checkingFree
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2.5),
                              )
                            : Text(isGuided ? 'Check ✓' : 'Check',
                                style: kid(15, color: Colors.white)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Guide controls: step back / play-pause / step forward.
  Widget _guideBar(LetterPracticeState s) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          children: [
            Expanded(
              child: Text(
                'Step ${_guideStep + 1}/${s.item.strokes.length}: '
                '${stepPointsLabel(s.item.strokes, _guideStep)}',
                style: kid(13,
                    weight: FontWeight.w600, color: const Color(0xFFF59E0B)),
              ),
            ),
            IconButton(
              tooltip: 'Previous step',
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.skip_previous, size: 22),
              onPressed: _guideStep > 0 ? _guidePrev : null,
            ),
            IconButton(
              tooltip: _guideCtrl.isAnimating ? 'Pause' : 'Auto play',
              visualDensity: VisualDensity.compact,
              icon: Icon(
                  _guideCtrl.isAnimating
                      ? Icons.pause_circle
                      : Icons.play_circle,
                  size: 24,
                  color: AppColors.secondary),
              onPressed: _guidePlayPause,
            ),
            IconButton(
              tooltip: 'Next step',
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.skip_next, size: 22),
              onPressed:
                  _guideStep + 1 < s.item.strokes.length ? _guideNext : null,
            ),
          ],
        ),
      );

  Widget _nextBar(LetterPracticeState s) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
        child: SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: s.bothDone ? _nextLevel : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              disabledBackgroundColor: Colors.grey.shade300,
              disabledForegroundColor: Colors.grey.shade600,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
            ),
            child: Text(
              s.bothDone
                  ? (s.isLast
                      ? 'Finish!'
                      : 'Next: Letter ${allLetterItems[s.level + 1].glyph}')
                  : 'Finish BOTH sides to unlock the next letter',
              style: kid(17,
                  weight: FontWeight.w600,
                  color: s.bothDone ? Colors.white : Colors.grey.shade600),
            ),
          ),
        ),
      );
}

// =====================================================================
//  PAINTER (under the child's ink)
// =====================================================================

/// Guided side: gray letter + numbered start/end dots + direction arrows
/// + (optionally) the guide replay. The child's ink is drawn on top
/// by the WritingPad.
class _GuidedPainter extends CustomPainter {
  final List<List<Offset>> template;
  final int? guideStep;       // which stroke the guide is showing
  final double guideProgress; // 0..1 through that stroke
  /// false during a test: no numbered points and no direction arrows.
  final bool showHelp;

  _GuidedPainter({
    required this.template,
    this.guideStep,
    this.guideProgress = 0,
    this.showHelp = true,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;

    final guide = Paint()
      ..color = const Color(0xFF9E9E9E).withValues(alpha: 0.30)
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.13
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    for (final stroke in template) {
      canvas.drawPath(_path(stroke, s), guide);
    }

    // In a test there are no arrows and no numbered points (SRS US_33).
    if (!showHelp) return;

    // Direction arrows along each stroke (at 45% and 80% of its length)
    for (final stroke in template) {
      _drawArrowAt(canvas, s, stroke, 0.45);
      _drawArrowAt(canvas, s, stroke, 0.80);
    }

    // Numbered waypoints: green = start (go!), orange = stop.
    for (final w in waypointsFor(template)) {
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

    // The guide replay, ON the actual points the child will join.
    if (guideStep != null && guideStep! < template.length) {
      final demoInk = Paint()
        ..color = AppColors.secondary.withValues(alpha: 0.65)
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.055
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;

      // Steps already shown stay visible (faint), so the order is clear.
      for (var i = 0; i < guideStep!; i++) {
        canvas.drawPath(_path(template[i], s), demoInk);
      }

      // The current step draws itself with a pencil at the tip.
      final stroke = template[guideStep!];
      var total = 0.0;
      for (var i = 0; i < stroke.length - 1; i++) {
        total += (stroke[i + 1] - stroke[i]).distance;
      }
      if (total > 0) {
        var remaining = guideProgress * total;
        final path = Path()..moveTo(stroke.first.dx * s, stroke.first.dy * s);
        var tip = Offset(stroke.first.dx * s, stroke.first.dy * s);
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
            final p =
                Offset.lerp(stroke[i], stroke[i + 1], remaining / segLen)!;
            path.lineTo(p.dx * s, p.dy * s);
            tip = Offset(p.dx * s, p.dy * s);
            remaining = 0;
            drewAny = true;
            break;
          }
        }
        if (drewAny) canvas.drawPath(path, demoInk);

        // Highlight rings around the current step's own points.
        final ring = Paint()
          ..color = AppColors.secondary
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3;
        canvas.drawCircle(
            Offset(stroke.first.dx * s, stroke.first.dy * s), s * 0.062, ring);
        if ((stroke.first - stroke.last).distance >= 0.05) {
          canvas.drawCircle(
              Offset(stroke.last.dx * s, stroke.last.dy * s), s * 0.062, ring);
        }

        // The pencil
        canvas.drawCircle(tip, s * 0.03, Paint()..color = Colors.white);
        canvas.drawCircle(
          tip,
          s * 0.03,
          Paint()
            ..color = AppColors.secondary
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3,
        );
        drawPencilCursor(canvas, tip, s);
      }
    }
  }

  /// A small triangle pointing along the stroke at [fraction] of its length.
  void _drawArrowAt(
      Canvas canvas, double s, List<Offset> stroke, double fraction) {
    var total = 0.0;
    for (var i = 0; i < stroke.length - 1; i++) {
      total += (stroke[i + 1] - stroke[i]).distance;
    }
    if (total < 0.2) return; // too short for arrows

    var target = total * fraction;
    for (var i = 0; i < stroke.length - 1; i++) {
      final seg = (stroke[i + 1] - stroke[i]).distance;
      if (seg == 0) continue;
      if (target <= seg) {
        final p = Offset.lerp(stroke[i], stroke[i + 1], target / seg)!;
        final dir = (stroke[i + 1] - stroke[i]) / seg;
        final tip = Offset(p.dx * s, p.dy * s);
        final back = Offset(-dir.dx, -dir.dy);
        final normal = Offset(-dir.dy, dir.dx);
        final a = s * 0.030; // arrow size
        final p1 = tip + (back * 1.6 + normal) * a;
        final p2 = tip + (back * 1.6 - normal) * a;
        final path = Path()
          ..moveTo(tip.dx, tip.dy)
          ..lineTo(p1.dx, p1.dy)
          ..lineTo(p2.dx, p2.dy)
          ..close();
        canvas.drawPath(path, Paint()..color = AppColors.purple);
        return;
      }
      target -= seg;
    }
  }

  Path _path(List<Offset> pts, double s) {
    final path = Path()..moveTo(pts.first.dx * s, pts.first.dy * s);
    for (final p in pts.skip(1)) {
      path.lineTo(p.dx * s, p.dy * s);
    }
    return path;
  }

  @override
  bool shouldRepaint(covariant _GuidedPainter old) =>
      old.guideStep != guideStep ||
      old.guideProgress != guideProgress ||
      old.template != template ||
      old.showHelp != showHelp;
}
