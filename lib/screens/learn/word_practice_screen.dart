import 'package:audioplayers/audioplayers.dart';
import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../blocs/words/word_practice_cubit.dart';
import '../../data/word_list.dart';
import '../../services/badge_service.dart';
import '../../services/progress_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common.dart';
import '../../widgets/writing_pad.dart';
import 'badge_popup.dart';
import 'demo_video.dart';

/// Stage 3: write one WORD letter by letter, free-hand (SRS US_11).
///
/// [words] is the list to practice — the common words, or the child's own
/// toy words (SRS FR_16). The rules live in WordPracticeCubit.
class WordPracticeScreen extends StatelessWidget {
  final int wordIndex;
  final List<PracticeWord>? words;

  /// TEST MODE (SRS FR_24/US_33): no tutorial video button.
  final bool examMode;

  const WordPracticeScreen({
    super.key,
    required this.wordIndex,
    this.words,
    this.examMode = false,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (ctx) => WordPracticeCubit(
        progress: ctx.read<ProgressService>(),
        badges: ctx.read<BadgeService>(),
        words: words ?? practiceWords,
        startIndex: wordIndex,
      ),
      child: _WordView(examMode: examMode),
    );
  }
}

class _WordView extends StatefulWidget {
  final bool examMode;
  const _WordView({required this.examMode});

  @override
  State<_WordView> createState() => _WordViewState();
}

class _WordViewState extends State<_WordView> {
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

  void _showVideo(WordPracticeState s) => showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => DemoVideoDialog(item: s.currentItem, twoPhase: true),
      );

  Future<void> _onEvent(BuildContext context, WordPracticeState s) async {
    final cubit = context.read<WordPracticeCubit>();
    switch (s.event) {
      case WordEvent.letterOk:
        _pad.clear();
        showKidSnack(context, s.message ?? 'Good!', color: AppColors.success);
        break;
      case WordEvent.letterWrong:
        _showWrong(context, s);
        break;
      case WordEvent.wordDone:
        _pad.clear();
        _confetti.play();
        _player.play(AssetSource('sounds/success.wav'));
        await Future.delayed(const Duration(milliseconds: 700));
        if (!context.mounted) return;
        if (s.newBadges.isNotEmpty) {
          await showBadgePopup(context, s.newBadges);
          cubit.badgesShown();
        }
        if (!context.mounted) return;
        _showDone(context, s);
        break;
      case WordEvent.none:
        if (s.message != null) showKidSnack(context, s.message!);
        break;
    }
  }

  void _showWrong(BuildContext context, WordPracticeState s) {
    final r = s.lastResult!;
    // A different LETTER (e.g. "O" when "A" was needed) gets its own
    // message (SRS T_30).
    final rec = r.recognizedAs?.toUpperCase();
    final wrongLetter =
        rec != null && rec.isNotEmpty && rec != s.currentChar.toUpperCase();
    final text = wrongLetter
        ? 'Hmm, that looks like "$rec"!\nWe need "${s.currentChar}" for '
            '${s.word.word}. Try again!'
        : r.kidMessage;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text('Not yet!',
            textAlign: TextAlign.center,
            style: kid(24, weight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('${r.percent}%',
                  style: kid(44,
                      weight: FontWeight.bold, color: AppColors.primary)),
              const SizedBox(height: 6),
              Text(text, textAlign: TextAlign.center, style: kid(16)),
            ],
          ),
        ),
        actions: [
          if (!widget.examMode)
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                _showVideo(s);
              },
              child: Text('Watch ${s.currentChar}',
                  style: kid(16, color: AppColors.secondary)),
            ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white),
            onPressed: () {
              Navigator.pop(ctx);
              _pad.clear();
            },
            child: Text('Try Again', style: kid(16, color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showDone(BuildContext context, WordPracticeState s) {
    final cubit = context.read<WordPracticeCubit>();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text('${s.word.word}!',
            textAlign: TextAlign.center,
            style: kid(28, weight: FontWeight.bold, color: AppColors.primary)),
        content: Text('You wrote the whole word — amazing!',
            textAlign: TextAlign.center, style: kid(16)),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            child: Text('Done', style: kid(16, color: AppColors.secondary)),
          ),
          if (s.hasNext)
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white),
              onPressed: () {
                Navigator.pop(ctx);
                cubit.nextWord();
              },
              child: Text('Next: ${s.words[s.wordIndex + 1].word}',
                  style: kid(16, color: Colors.white)),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<WordPracticeCubit, WordPracticeState>(
      listenWhen: (a, b) => a.eventTick != b.eventTick,
      listener: _onEvent,
      builder: (context, s) {
        final cubit = context.read<WordPracticeCubit>();
        return Stack(
          children: [
            KidPage(
              child: Column(
                children: [
                  KidHeader(s.word.word,
                      fontSize: 24,
                      actions: [
                        if (!widget.examMode)
                          IconButton(
                            tooltip: 'Watch how to write ${s.currentChar}',
                            icon: const Icon(Icons.smart_display,
                                size: 30, color: Colors.white),
                            onPressed: () => _showVideo(s),
                          ),
                      ]),
                  // Letter boxes: done = green, now = pink, later = grey
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (var i = 0; i < s.word.word.length; i++)
                        _slot(s, i),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    s.wordDone
                        ? 'Word complete!'
                        : 'Write the letter ${s.currentChar} free-hand!',
                    style: kid(15),
                  ),
                  Expanded(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: WritingPad(controller: _pad),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: KidButton('Clear',
                              color: AppColors.secondary,
                              onPressed: _pad.clear),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: KidButton(
                            'Check',
                            color: AppColors.purple,
                            busy: s.checking,
                            onPressed: s.wordDone
                                ? null
                                : () => cubit.check(
                                    _pad.strokes, _pad.times, _pad.side),
                          ),
                        ),
                      ],
                    ),
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
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _slot(WordPracticeState s, int i) {
    final done = i < s.letterIndex || s.wordDone;
    final now = i == s.letterIndex && !s.wordDone;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 5),
      width: 46,
      height: 54,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: done ? AppColors.success : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: done
              ? AppColors.success
              : now
                  ? AppColors.primary
                  : Colors.grey.shade300,
          width: now ? 3 : 2,
        ),
      ),
      child: Text(
        i <= s.letterIndex || s.wordDone ? s.word.word[i] : '?',
        style: kid(24,
            weight: FontWeight.bold,
            color: done
                ? Colors.white
                : now
                    ? AppColors.primary
                    : Colors.grey.shade400),
      ),
    );
  }
}
