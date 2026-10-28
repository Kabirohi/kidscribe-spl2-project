import 'dart:math';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../blocs/games/match_cubit.dart';
import '../../services/badge_service.dart';
import '../../services/progress_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common.dart';
import '../learn/badge_popup.dart';

/// Letter Match game (SRS FR_11 / US_15).
class LetterMatchScreen extends StatelessWidget {
  const LetterMatchScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (ctx) => MatchCubit(
        progress: ctx.read<ProgressService>(),
        badges: ctx.read<BadgeService>(),
      ),
      child: const _MatchView(),
    );
  }
}

class _MatchView extends StatefulWidget {
  const _MatchView();

  @override
  State<_MatchView> createState() => _MatchViewState();
}

class _MatchViewState extends State<_MatchView> {
  final AudioPlayer _player = AudioPlayer();

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<MatchCubit, MatchState>(
      listenWhen: (a, b) =>
          (!a.levelDone && b.levelDone) ||
          (b.newBadges.isNotEmpty && a.newBadges != b.newBadges),
      listener: (context, s) async {
        if (s.levelDone) _player.play(AssetSource('sounds/success.wav'));
        if (s.newBadges.isNotEmpty) {
          final cubit = context.read<MatchCubit>();
          await showBadgePopup(context, s.newBadges);
          cubit.badgesShown();
        }
      },
      builder: (context, s) {
        final cubit = context.read<MatchCubit>();
        return KidPage(
          child: Column(
            children: [
              KidHeader('Letter Match', actions: [
                KidHeaderPill('${s.score}', icon: Icons.star_rounded),
              ]),
              Text('Level ${s.level} of ${MatchCubit.maxLevel}'
                  '${s.best > 0 ? '   ·   best: level ${s.best}' : ''}',
                  style: kid(15, color: Colors.grey.shade700)),
              const SizedBox(height: 8),
              if (s.message != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(s.message!,
                      textAlign: TextAlign.center,
                      style: kid(16,
                          weight: FontWeight.w600,
                          color: s.messageGood
                              ? AppColors.success
                              : AppColors.error)),
                ),
              Expanded(
                child: LayoutBuilder(builder: (context, c) {
                  final n = s.cards.length;
                  // Pick a column count that keeps the cards big.
                  final cols = n <= 6 ? 3 : n <= 12 ? 4 : 5;
                  final rows = (n / cols).ceil();
                  final size = min((c.maxWidth - 32) / cols,
                          (c.maxHeight - 16) / max(rows, 1)) -
                      10;
                  return Center(
                    child: Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      alignment: WrapAlignment.center,
                      children: [
                        for (var i = 0; i < n; i++)
                          SizedBox(
                            width: size,
                            height: size,
                            child: _card(context, s.cards[i],
                                () => cubit.tapCard(i)),
                          ),
                      ],
                    ),
                  );
                }),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: s.levelDone
                    ? (s.isLastLevel
                        ? KidButton('You are a Match Champion! Play again',
                            onPressed: cubit.restart)
                        : KidButton('Next level', onPressed: cubit.nextLevel))
                    : KidButton('Start over',
                        color: AppColors.secondary, onPressed: cubit.restart),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _card(BuildContext context, MatchCard c, VoidCallback onTap) {
    final show = c.faceUp || c.matched;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        decoration: BoxDecoration(
          color: c.matched
              ? AppColors.success
              : show
                  ? Colors.white
                  : AppColors.purple,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
              color: c.matched ? AppColors.success : AppColors.purple,
              width: 2),
          boxShadow: [
            BoxShadow(
              color: AppColors.ledge(
                  c.matched ? AppColors.success : AppColors.purple),
              offset: const Offset(0, 4),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: FittedBox(
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Text(
              show ? c.letter : '?',
              style: kid(44,
                  weight: FontWeight.bold,
                  color: c.matched
                      ? Colors.white
                      : show
                          ? AppColors.primary
                          : Colors.white),
            ),
          ),
        ),
      ),
    );
  }
}
