import 'package:audioplayers/audioplayers.dart';
import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../blocs/sentence/sentence_cubit.dart';
import '../../services/badge_service.dart';
import '../../services/progress_service.dart';
import '../../services/sentence_checker.dart';
import '../../theme/app_colors.dart';
import '../../widgets/art.dart';
import '../../widgets/common.dart';
import 'badge_popup.dart';

/// Stage 4: make a sentence with word cards (SRS FR_9 / US_12, US_13).
///
///  - drag a card into a box, or just tap it
///  - tap a card in a box to send it back
///  - tap "Aa" to make the first letter big or small
///  - the first box shows "Start big!" — where the capital goes (US_13)
class SentencePracticeScreen extends StatelessWidget {
  final int startIndex;
  const SentencePracticeScreen({super.key, this.startIndex = 0});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (ctx) => SentenceCubit(
        progress: ctx.read<ProgressService>(),
        badges: ctx.read<BadgeService>(),
        startIndex: startIndex,
      ),
      child: const _SentenceView(),
    );
  }
}

class _SentenceView extends StatefulWidget {
  const _SentenceView();

  @override
  State<_SentenceView> createState() => _SentenceViewState();
}

class _SentenceViewState extends State<_SentenceView> {
  // Confetti and sound are screen effects, so they live with the widget.
  late final ConfettiController _confetti =
      ConfettiController(duration: const Duration(seconds: 2));
  final AudioPlayer _player = AudioPlayer();

  @override
  void dispose() {
    _confetti.dispose();
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<SentenceCubit, SentenceState>(
      listenWhen: (a, b) =>
          a.celebrateTick != b.celebrateTick ||
          (b.newBadges.isNotEmpty && a.newBadges != b.newBadges),
      listener: (context, state) async {
        final cubit = context.read<SentenceCubit>();
        if (state.solved) {
          _confetti.play();
          _player.play(AssetSource('sounds/success.wav'));
        }
        if (state.newBadges.isNotEmpty) {
          await Future.delayed(const Duration(milliseconds: 700));
          if (!context.mounted) return;
          await showBadgePopup(context, state.newBadges);
          cubit.badgesShown();
        }
      },
      builder: (context, s) {
        final cubit = context.read<SentenceCubit>();
        return Stack(
          children: [
            KidPage(
              child: Column(
                children: [
                  KidHeader('Sentence ${s.index + 1}/12', fontSize: 22),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                      child: Column(
                        children: [
                          KidEmoji(s.sentence.emoji, size: 96),
                          Text('Make the sentence for this picture!',
                              style: kid(16)),
                          const SizedBox(height: 18),
                          _slots(context, s),
                          const SizedBox(height: 10),
                          _feedback(s),
                          const SizedBox(height: 18),
                          Text(
                              s.pool.isEmpty
                                  ? 'All cards are in the boxes!'
                                  : 'Drag or tap a card:',
                              style: kid(14, color: Colors.grey.shade600)),
                          const SizedBox(height: 10),
                          _pool(context, s),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                    child: s.solved
                        ? Row(
                            children: [
                              Expanded(
                                child: KidButton('Again',
                                    color: AppColors.secondary,
                                    onPressed: cubit.retry),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: KidButton(
                                  s.hasNext ? 'Next' : 'Finish',
                                  onPressed: s.hasNext
                                      ? cubit.next
                                      : () => Navigator.pop(context),
                                ),
                              ),
                            ],
                          )
                        : KidButton('Check ✓', onPressed: cubit.check),
                  ),
                ],
              ),
            ),
            Align(
              alignment: Alignment.topCenter,
              child: ConfettiWidget(
                confettiController: _confetti,
                blastDirectionality: BlastDirectionality.explosive,
                numberOfParticles: 24,
                gravity: 0.25,
                colors: const [
                  AppColors.primary,
                  AppColors.secondary,
                  AppColors.purple,
                  AppColors.accent,
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  /// The row of boxes the child fills in.
  Widget _slots(BuildContext context, SentenceState s) {
    final cubit = context.read<SentenceCubit>();
    final bad = s.result?.badSlots ?? const [];
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      runSpacing: 14,
      children: [
        for (var i = 0; i < s.slots.length; i++)
          DragTarget<int>(
            onAcceptWithDetails: (d) => cubit.place(d.data, i),
            builder: (context, hovering, _) {
              final card = s.slots[i];
              final isStop = i == s.slots.length - 1;
              final isBad = bad.contains(i);
              final color = s.solved
                  ? AppColors.success
                  : isBad
                      ? AppColors.error
                      : hovering.isNotEmpty
                          ? AppColors.primary
                          : Colors.grey.shade400;
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // US_13: show where the capital letter goes.
                  if (i == 0)
                    Text('Start big!',
                        style: kid(11, color: AppColors.purple))
                  else
                    const SizedBox(height: 14),
                  GestureDetector(
                    onTap: () => cubit.takeBack(i),
                    child: Container(
                      constraints: BoxConstraints(minWidth: isStop ? 38 : 64),
                      height: 50,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: card == null
                            ? Colors.white.withValues(alpha: 0.6)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: color, width: 2.4),
                      ),
                      child: Text(card?.text ?? '',
                          style: kid(22, weight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (card != null && card.text != SentenceChecker.stop)
                    GestureDetector(
                      onTap: () => cubit.toggleCapital(i),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.purple.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text('Aa',
                            style: kid(13,
                                weight: FontWeight.bold,
                                color: AppColors.purple)),
                      ),
                    )
                  else
                    const SizedBox(height: 21),
                ],
              );
            },
          ),
      ],
    );
  }

  Widget _feedback(SentenceState s) {
    final r = s.result;
    if (r == null) return const SizedBox(height: 24);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: (r.ok ? AppColors.success : AppColors.error)
            .withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Text(r.message,
              textAlign: TextAlign.center,
              style: kid(16,
                  weight: FontWeight.w600,
                  color: r.ok ? AppColors.success : AppColors.error)),
          if (r.ok) ...[
            const SizedBox(height: 6),
            Text(s.sentence.text, style: kid(22, weight: FontWeight.bold)),
          ],
        ],
      ),
    );
  }

  /// The cards waiting at the bottom.
  Widget _pool(BuildContext context, SentenceState s) {
    final cubit = context.read<SentenceCubit>();
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final card in s.pool)
          Draggable<int>(
            data: card.id,
            feedback: Material(
              color: Colors.transparent,
              child: _card(card, lifted: true),
            ),
            childWhenDragging: Opacity(opacity: 0.3, child: _card(card)),
            child: GestureDetector(
              onTap: () => cubit.placeInFirstEmpty(card.id),
              child: _card(card),
            ),
          ),
      ],
    );
  }

  Widget _card(SentenceCard c, {bool lifted = false}) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        decoration: BoxDecoration(
          color: c.text == SentenceChecker.stop
              ? AppColors.accent
              : AppColors.secondary,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: lifted ? 0.25 : 0.1),
              blurRadius: lifted ? 12 : 4,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Text(c.text,
            style: kid(22,
                weight: FontWeight.bold,
                color: c.text == SentenceChecker.stop
                    ? AppColors.textDark
                    : Colors.white)),
      );
}
