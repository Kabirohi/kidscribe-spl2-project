import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../blocs/free_writing/free_writing_cubit.dart';
import '../../services/badge_service.dart';
import '../../services/progress_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common.dart';
import '../../widgets/writing_pad.dart';
import '../learn/badge_popup.dart';

/// Free Writing: a blank page, write any letter (SRS FR_13 / US_17).
class FreeWritingScreen extends StatelessWidget {
  const FreeWritingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (ctx) => FreeWritingCubit(
        progress: ctx.read<ProgressService>(),
        badges: ctx.read<BadgeService>(),
      ),
      child: const _FreeView(),
    );
  }
}

class _FreeView extends StatefulWidget {
  const _FreeView();

  @override
  State<_FreeView> createState() => _FreeViewState();
}

class _FreeViewState extends State<_FreeView> {
  final _pad = WritingPadController();
  final AudioPlayer _player = AudioPlayer();

  @override
  void dispose() {
    _pad.dispose();
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<FreeWritingCubit, FreeWritingState>(
      listenWhen: (a, b) =>
          a.tick != b.tick ||
          (b.newBadges.isNotEmpty && a.newBadges != b.newBadges),
      listener: (context, s) async {
        final cubit = context.read<FreeWritingCubit>();
        if (s.lastGood) {
          _player.play(AssetSource('sounds/success.wav'));
          _pad.clear(); // a fresh page for the next letter
        }
        if (s.newBadges.isNotEmpty) {
          await showBadgePopup(context, s.newBadges);
          cubit.badgesShown();
        }
      },
      builder: (context, s) {
        final cubit = context.read<FreeWritingCubit>();
        return KidPage(
          child: Column(
            children: [
              KidHeader('Free Writing', actions: [
                KidHeaderPill('${s.goodCount}', icon: Icons.star_rounded),
              ]),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  'Write any capital letter you like. I will read it and '
                  'tell you how neat it is!',
                  textAlign: TextAlign.center,
                  style: kid(15),
                ),
              ),
              // The recent letters: green = good, red = marked wrong
              SizedBox(
                height: 54,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  children: [
                    for (final a in s.history)
                      Container(
                        margin: const EdgeInsets.only(right: 8),
                        width: 38,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: a.good
                              ? AppColors.success
                              : AppColors.error.withValues(alpha: 0.85),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(a.letter ?? '?',
                            style: kid(18,
                                weight: FontWeight.bold, color: Colors.white)),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: WritingPad(controller: _pad),
                  ),
                ),
              ),
              if (s.message != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: (s.lastGood ? AppColors.success : AppColors.error)
                          .withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(s.message!,
                        textAlign: TextAlign.center,
                        style: kid(15,
                            weight: FontWeight.w600,
                            color: s.lastGood
                                ? AppColors.success
                                : AppColors.error)),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
                child: Row(
                  children: [
                    Expanded(
                      child: KidButton('Clear',
                          color: AppColors.secondary, onPressed: _pad.clear),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: KidButton(
                        'Check',
                        color: AppColors.purple,
                        busy: s.checking,
                        onPressed: () =>
                            cubit.check(_pad.strokes, _pad.times, _pad.side),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
