import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../blocs/stages/stages_cubit.dart';
import '../../data/trace_templates.dart';
import '../../services/family_service.dart';
import '../../services/progress_service.dart';
import '../../theme/app_colors.dart';
import 'dart:math' as math;
import 'package:google_fonts/google_fonts.dart';
import '../../widgets/art.dart';
import '../../widgets/common.dart';
import '../../widgets/fun.dart';
import '../../widgets/mascot.dart';
import '../../widgets/parent_gate.dart';
import '../parent_hub_screen.dart';
import 'letter_levels_screen.dart';
import 'sentence_list_screen.dart';
import 'trace_items_screen.dart';
import 'word_list_screen.dart';

/// The Learning Journey: all five stages in order (SRS FR_10 / US_14).
/// A stage opens only when the stage before it is finished.
class StagesScreen extends StatelessWidget {
  const StagesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (ctx) => StagesCubit(
        progress: ctx.read<ProgressService>(),
        family: ctx.read<FamilyService>(),
      )..load(),
      child: const _StagesView(),
    );
  }
}

class _StagesView extends StatelessWidget {
  const _StagesView();

  void _open(BuildContext context, Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen))
        .then((_) {
      if (context.mounted) context.read<StagesCubit>().load();
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<StagesCubit, StagesState>(
      builder: (context, s) {
        final stops = s.loading
            ? const <_Stop>[]
            : [
                _Stop(
                  number: 1,
                  art: 'crayon',
                  color: const Color(0xFF14B8A6),
                  title: 'Strokes',
                  done: s.strokesDone,
                  total: s.strokesTotal,
                  locked: false,
                  onTap: () => _open(
                    context,
                    TraceItemsScreen(
                        title: 'Stage 1: Strokes', items: stage1Items),
                  ),
                ),
                _Stop(
                  number: 2,
                  art: 'input_latin_uppercase',
                  color: const Color(0xFF6C4BFF),
                  title: 'Letters',
                  done: s.lettersDone,
                  total: s.lettersTotal,
                  locked: !s.stage1Complete,
                  onTap: () => _open(context, const LetterLevelsScreen()),
                ),
                _Stop(
                  number: 3,
                  art: 'books',
                  color: const Color(0xFFFFA41B),
                  title: 'Words',
                  done: s.wordsDone,
                  total: s.wordsTotal,
                  locked: !s.stage2Complete,
                  onTap: () => _open(context, const WordListScreen()),
                ),
                _Stop(
                  number: 4,
                  art: 'memo',
                  color: const Color(0xFFFF5FA2),
                  title: 'Sentences',
                  done: s.sentencesDone,
                  total: s.sentencesTotal,
                  locked: !s.stage3Complete,
                  onTap: () => _open(context, const SentenceListScreen()),
                ),
                _Stop(
                  number: 5,
                  art: 'graduation_cap',
                  color: const Color(0xFF2EB5F0),
                  title: 'Grown-up zone',
                  done: s.stage4Complete ? 1 : 0,
                  total: 1,
                  locked: !s.stage4Complete,
                  onTap: () async {
                    final ok = await askParentGate(context);
                    if (ok && context.mounted) {
                      _open(context, const ParentHubScreen());
                    }
                  },
                ),
              ];
        return KidPage(
          color: const Color(0xFF14B8A6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              KidHeader(s.learnerName == null
                  ? 'Learning Journey'
                  : "${s.learnerName}'s Journey"),
              if (s.loading)
                const Expanded(
                    child: Center(child: CircularProgressIndicator()))
              else
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
                    child: LayoutBuilder(
                      builder: (context, c) =>
                          _map(context, s, stops, c.maxWidth),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  static const _step = 200.0;
  static const _node = 112.0;

  /// The stops sit left and right along a winding road, like a board game.
  Widget _map(
      BuildContext context, StagesState s, List<_Stop> stops, double width) {
    final swing = math.min(width * 0.24, 200.0);
    Offset centre(int i) => Offset(
        width / 2 + (i.isEven ? -swing : swing) * (i == 0 ? 0.6 : 1),
        _node / 2 + 20 + i * _step);
    final points = [for (int i = 0; i < stops.length; i++) centre(i)];
    final height = points.last.dy + _node / 2 + 70;

    return SizedBox(
      height: height,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _RoadPainter(points, s.currentStage - 1),
            ),
          ),
          for (int i = 0; i < stops.length; i++)
            Positioned(
              left: points[i].dx - 90,
              top: points[i].dy - _node / 2,
              width: 180,
              child: PopIn(
                delay: Duration(milliseconds: 100 + i * 120),
                child: _stopWidget(context, s, stops[i]),
              ),
            ),
          // Penny waits next to the stage you are on.
          if (s.currentStage >= 1 && s.currentStage <= stops.length)
            Positioned(
              left: points[s.currentStage - 1].dx +
                  ((s.currentStage - 1).isEven ? 58 : -58 - 96),
              top: points[s.currentStage - 1].dy - 84,
              child: const PennyMascot(size: 96),
            ),
        ],
      ),
    );
  }

  Widget _stopWidget(BuildContext context, StagesState s, _Stop st) {
    final isCurrent = st.number == s.currentStage;
    final finished = !st.locked && st.total > 0 && st.done >= st.total;
    final face = st.locked ? const Color(0xFFDCD8EE) : st.color;

    return Bouncy(
      onTap: () {
        // A locked stage STAYS locked (SRS T_36).
        if (st.locked) {
          showKidSnack(context, 'Finish Stage ${st.number - 1} first!');
        } else {
          st.onTap();
        }
      },
      child: Column(
        children: [
          Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              if (isCurrent) const _Ring(size: _node + 26),
              Container(
                width: _node,
                height: _node,
                decoration: BoxDecoration(
                  color: face,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 6),
                  boxShadow: [
                    BoxShadow(
                        color: st.locked
                            ? const Color(0xFFBDB8D6)
                            : AppColors.ledge(st.color, 0.16),
                        offset: const Offset(0, 7)),
                  ],
                ),
                alignment: Alignment.center,
                child: KidArt(st.art, size: 66, grey: st.locked),
              ),
              if (st.locked || finished)
                Positioned(
                  right: 30,
                  bottom: -4,
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: finished ? AppColors.success : AppColors.textMuted,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 3),
                    ),
                    child: Icon(
                        finished ? Icons.check_rounded : Icons.lock_rounded,
                        size: 18,
                        color: Colors.white),
                  ),
                ),
              Positioned(
                left: 26,
                top: -2,
                child: Container(
                  width: 32,
                  height: 32,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(color: Color(0x222A1F5C), offset: Offset(0, 2)),
                    ],
                  ),
                  child: Text('${st.number}',
                      style: GoogleFonts.fredoka(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: st.locked ? AppColors.textMuted : st.color)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(st.title,
              textAlign: TextAlign.center,
              style: GoogleFonts.fredoka(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: st.locked ? AppColors.textMuted : AppColors.textDark)),
          const SizedBox(height: 4),
          if (!st.locked)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: isCurrent ? st.color : Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                  isCurrent && st.done == 0
                      ? 'Start!'
                      : '${st.done} / ${st.total}',
                  style: GoogleFonts.nunito(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      color: isCurrent ? Colors.white : AppColors.textMuted)),
            ),
        ],
      ),
    );
  }
}

class _Stop {
  final int number;
  final String art;
  final Color color;
  final String title;
  final int done;
  final int total;
  final bool locked;
  final VoidCallback onTap;
  const _Stop({
    required this.number,
    required this.art,
    required this.color,
    required this.title,
    required this.done,
    required this.total,
    required this.locked,
    required this.onTap,
  });
}

/// A soft ring that breathes around the current stop.
class _Ring extends StatefulWidget {
  final double size;
  const _Ring({required this.size});

  @override
  State<_Ring> createState() => _RingState();
}

class _RingState extends State<_Ring> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1400))
    ..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final t = Curves.easeOut.transform(_c.value);
        return Container(
          width: widget.size * (0.9 + t * 0.25),
          height: widget.size * (0.9 + t * 0.25),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: 0.0),
            border: Border.all(
                color: AppColors.sun.withValues(alpha: 1 - t), width: 6),
          ),
        );
      },
    );
  }
}

/// The dotted road between the stops. The part already travelled is gold.
class _RoadPainter extends CustomPainter {
  final List<Offset> points;
  final int reached;
  _RoadPainter(this.points, this.reached);

  Path _segment(Offset a, Offset b) {
    final midY = (a.dy + b.dy) / 2;
    return Path()
      ..moveTo(a.dx, a.dy)
      ..cubicTo(a.dx, midY, b.dx, midY, b.dx, b.dy);
  }

  @override
  void paint(Canvas canvas, Size size) {
    for (int i = 0; i < points.length - 1; i++) {
      final path = _segment(points[i], points[i + 1]);
      final travelled = i < reached;
      // Wide soft road.
      canvas.drawPath(
          path,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 30
            ..strokeCap = StrokeCap.round
            ..color =
                travelled ? const Color(0xFFFFE7A3) : const Color(0xFFE7E3F6));
      // Dashes down the middle.
      for (final m in path.computeMetrics()) {
        for (double d = 0; d < m.length; d += 26) {
          final seg = m.extractPath(d, math.min(d + 12, m.length));
          canvas.drawPath(
              seg,
              Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = 6
                ..strokeCap = StrokeCap.round
                ..color = travelled ? AppColors.sun : Colors.white);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _RoadPainter old) =>
      old.points != points || old.reached != reached;
}
