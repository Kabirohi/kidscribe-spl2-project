import 'package:audioplayers/audioplayers.dart';
import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../blocs/games/ninja_cubit.dart';
import '../../services/badge_service.dart';
import '../../services/custom_word_service.dart';
import '../../services/progress_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common.dart';
import '../../widgets/writing_pad.dart';
import '../learn/badge_popup.dart';
import '../../widgets/art.dart';

/// Letter Ninja: write letters fast before the clock runs out
/// (SRS FR_12 / US_16).
class LetterNinjaScreen extends StatelessWidget {
  const LetterNinjaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (ctx) => NinjaCubit(
        progress: ctx.read<ProgressService>(),
        badges: ctx.read<BadgeService>(),
        toys: ctx.read<CustomWordService>(),
      ),
      child: const _NinjaView(),
    );
  }
}

class _NinjaView extends StatefulWidget {
  const _NinjaView();

  @override
  State<_NinjaView> createState() => _NinjaViewState();
}

class _NinjaViewState extends State<_NinjaView> {
  final _pad = WritingPadController();
  late final ConfettiController _confetti =
      ConfettiController(duration: const Duration(seconds: 2));
  final AudioPlayer _player = AudioPlayer();

  @override
  void dispose() {
    _pad.dispose();
    _confetti.dispose();
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<NinjaCubit, NinjaState>(
      listenWhen: (a, b) =>
          a.clearTick != b.clearTick ||
          a.status != b.status ||
          (b.newBadges.isNotEmpty && a.newBadges != b.newBadges),
      listener: (context, s) async {
        final cubit = context.read<NinjaCubit>();
        _pad.clear();
        if (s.status == NinjaStatus.won) {
          _confetti.play();
          _player.play(AssetSource('sounds/success.wav'));
        }
        if (s.newBadges.isNotEmpty) {
          await Future.delayed(const Duration(milliseconds: 600));
          if (!context.mounted) return;
          await showBadgePopup(context, s.newBadges);
          cubit.badgesShown();
        }
      },
      builder: (context, s) {
        final cubit = context.read<NinjaCubit>();
        final playing = s.status == NinjaStatus.playing ||
            s.status == NinjaStatus.checking;
        return Stack(
          children: [
            KidPage(
              child: Column(
                children: [
                  KidHeader('Letter Ninja', actions: [
                    KidHeaderPill('${s.score}', icon: Icons.star_rounded),
                  ]),
                  if (s.status == NinjaStatus.ready)
                    Expanded(child: _intro(cubit, s))
                  else ...[
                    _topBar(s),
                    if (s.message != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 4),
                        child: Text(s.message!,
                            textAlign: TextAlign.center,
                            style: kid(16,
                                weight: FontWeight.w600,
                                color: s.messageGood
                                    ? AppColors.success
                                    : AppColors.error)),
                      ),
                    Expanded(
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: IgnorePointer(
                            ignoring: !playing,
                            child: Opacity(
                              opacity: playing ? 1 : 0.45,
                              child: WritingPad(controller: _pad),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                      child: _bottom(cubit, s),
                    ),
                  ],
                ],
              ),
            ),
            Align(
              alignment: Alignment.topCenter,
              child: ConfettiWidget(
                confettiController: _confetti,
                blastDirectionality: BlastDirectionality.explosive,
                numberOfParticles: 30,
                gravity: 0.25,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _intro(NinjaCubit cubit, NinjaState s) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const KidArt('ninja', size: 130),
            const SizedBox(height: 12),
            Text('Write 5 letters before the clock runs out!',
                textAlign: TextAlign.center,
                style: kid(20, weight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
              'Every letter has its own clock. If a clock reaches zero, the '
              'round is over. Each round the clock gets faster!',
              textAlign: TextAlign.center,
              style: kid(15, color: Colors.grey.shade700),
            ),
            if (s.best > 0) ...[
              const SizedBox(height: 10),
              Text('Your best: round ${s.best}',
                  style: kid(15, color: AppColors.purple)),
            ],
            const SizedBox(height: 24),
            KidButton('Start!', onPressed: () => cubit.startRound(round: 1)),
          ],
        ),
      );

  Widget _topBar(NinjaState s) {
    final frac = s.secondsPerLetter == 0
        ? 0.0
        : s.secondsLeft / s.secondsPerLetter;
    final danger = s.secondsLeft <= 5;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          Row(
            children: [
              Text('Round ${s.round}', style: kid(15)),
              const Spacer(),
              for (var i = 0; i < s.letters.length; i++)
                Container(
                  margin: const EdgeInsets.only(left: 6),
                  width: 34,
                  height: 38,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: i < s.index ||
                            s.status == NinjaStatus.won
                        ? AppColors.success
                        : i == s.index
                            ? AppColors.primary
                            : Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.primary),
                  ),
                  child: Text(
                    i <= s.index || s.status == NinjaStatus.won
                        ? s.letters[i]
                        : '?',
                    style: kid(17,
                        weight: FontWeight.bold,
                        color: i <= s.index || s.status == NinjaStatus.won
                            ? Colors.white
                            : Colors.grey),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(Icons.timer,
                  color: danger ? AppColors.error : AppColors.secondary),
              const SizedBox(width: 6),
              Text('${s.secondsLeft}s',
                  style: kid(20,
                      weight: FontWeight.bold,
                      color: danger ? AppColors.error : AppColors.textDark)),
              const SizedBox(width: 10),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: frac.clamp(0.0, 1.0),
                    minHeight: 12,
                    backgroundColor: Colors.grey.shade200,
                    color: danger ? AppColors.error : AppColors.secondary,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _bottom(NinjaCubit cubit, NinjaState s) {
    switch (s.status) {
      case NinjaStatus.won:
        return KidButton('Next round (faster!)', onPressed: cubit.nextRound);
      case NinjaStatus.lost:
        return KidButton('Try again',
            color: AppColors.secondary, onPressed: cubit.tryAgain);
      default:
        return Row(
          children: [
            Expanded(
              child: KidButton('Clear',
                  color: AppColors.secondary, onPressed: _pad.clear),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: KidButton(
                'Check ✓',
                color: AppColors.purple,
                busy: s.status == NinjaStatus.checking,
                onPressed: () =>
                    cubit.check(_pad.strokes, _pad.times, _pad.side),
              ),
            ),
          ],
        );
    }
  }
}
