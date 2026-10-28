import 'dart:async';
import 'dart:math';
import 'dart:ui';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/trace_templates.dart';
import '../../services/badge_service.dart';
import '../../services/custom_word_service.dart';
import '../../services/freehand_checker.dart';
import '../../services/progress_service.dart';

enum NinjaStatus { ready, playing, checking, won, lost }

class NinjaState extends Equatable {
  final NinjaStatus status;
  final int round;             // 1, 2, 3 ... gets faster
  final List<String> letters;  // the letters of this round
  final int index;             // which letter now
  final int secondsLeft;
  final int secondsPerLetter;
  final int score;             // letters written right (all time, this visit)
  final String? message;
  final bool messageGood;
  final int best;              // best round ever won
  final int clearTick;         // tells the screen to clear the pad
  final List<BadgeDef> newBadges;

  const NinjaState({
    this.status = NinjaStatus.ready,
    this.round = 1,
    this.letters = const [],
    this.index = 0,
    this.secondsLeft = 0,
    this.secondsPerLetter = 20,
    this.score = 0,
    this.message,
    this.messageGood = true,
    this.best = 0,
    this.clearTick = 0,
    this.newBadges = const [],
  });

  String get letter => letters.isEmpty ? '' : letters[index];

  NinjaState copyWith({
    NinjaStatus? status,
    int? round,
    List<String>? letters,
    int? index,
    int? secondsLeft,
    int? secondsPerLetter,
    int? score,
    String? message,
    bool? messageGood,
    int? best,
    int? clearTick,
    List<BadgeDef>? newBadges,
  }) =>
      NinjaState(
        status: status ?? this.status,
        round: round ?? this.round,
        letters: letters ?? this.letters,
        index: index ?? this.index,
        secondsLeft: secondsLeft ?? this.secondsLeft,
        secondsPerLetter: secondsPerLetter ?? this.secondsPerLetter,
        score: score ?? this.score,
        message: message ?? this.message,
        messageGood: messageGood ?? this.messageGood,
        best: best ?? this.best,
        clearTick: clearTick ?? this.clearTick,
        newBadges: newBadges ?? this.newBadges,
      );

  @override
  List<Object?> get props => [status, round, letters, index, secondsLeft,
        secondsPerLetter, score, message, messageGood, best, clearTick,
        newBadges.length];
}

/// Letter Ninja (SRS FR_12 / US_16): a timed writing race.
///
/// A round is 5 letters. A clock runs for every letter, and each letter is
/// checked by the ML checker. Write all 5 before their clocks run out and
/// you win the round (a reward). If a clock reaches zero, the round ends
/// and there is no reward (SRS T_40). Every round the clock is shorter.
///
/// The letters come from ones the child has already learned, and from the
/// child's own toy words (SRS FR_16: toy words show up in games).
class NinjaCubit extends Cubit<NinjaState> {
  final ProgressService _progress;
  final BadgeService _badges;
  final CustomWordService _toys;
  final FreehandChecker _checker = FreehandChecker();
  final _rand = Random();
  Timer? _timer;

  static const lettersPerRound = 5;

  NinjaCubit({
    required ProgressService progress,
    required BadgeService badges,
    required CustomWordService toys,
  })  : _progress = progress,
        _badges = badges,
        _toys = toys,
        super(const NinjaState()) {
    _loadBest();
  }

  Future<void> _loadBest() async {
    final games = await _progress.loadGames();
    emit(state.copyWith(best: games['ninja_best'] ?? 0));
  }

  /// 20 seconds per letter in round 1, then 3 fewer each round (min 8).
  int _secondsFor(int round) => max(8, 20 - (round - 1) * 3);

  Future<List<String>> _pickLetters() async {
    final letters = await _progress.loadLetters();
    final learned = allLetterItems
        .where((l) => ProgressService.letterComplete(letters[l.glyph]))
        .map((l) => l.glyph)
        .toList();
    final toyLetters = (await _toys.load())
        .expand((w) => w.word.split(''))
        .toSet()
        .toList();

    final pool = <String>{...learned, ...toyLetters}.toList();
    if (pool.length < lettersPerRound) {
      pool.addAll('ILTEFH'.split('').where((c) => !pool.contains(c)));
    }
    pool.shuffle(_rand);
    // Put a toy letter in the round when there is one, so it feels personal.
    final picked = pool.take(lettersPerRound).toList();
    if (toyLetters.isNotEmpty && !picked.any(toyLetters.contains)) {
      picked[0] = toyLetters[_rand.nextInt(toyLetters.length)];
    }
    return picked;
  }

  Future<void> startRound({int? round}) async {
    _timer?.cancel();
    final r = round ?? state.round;
    final letters = await _pickLetters();
    final secs = _secondsFor(r);
    emit(state.copyWith(
      status: NinjaStatus.playing,
      round: r,
      letters: letters,
      index: 0,
      secondsLeft: secs,
      secondsPerLetter: secs,
      message: 'Write the letter ${letters.first} — quick!',
      messageGood: true,
      clearTick: state.clearTick + 1,
    ));
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _tick() {
    if (isClosed) return;
    if (state.status != NinjaStatus.playing &&
        state.status != NinjaStatus.checking) {
      return;
    }
    final left = state.secondsLeft - 1;
    if (left > 0) {
      emit(state.copyWith(secondsLeft: left));
      return;
    }
    // Time is over: the round ends with no reward.
    _timer?.cancel();
    emit(state.copyWith(
      status: NinjaStatus.lost,
      secondsLeft: 0,
      message: "Time's up! The round is over — no reward this time. "
          'Try again, ninja!',
      messageGood: false,
    ));
  }

  Future<void> check(
      List<List<Offset>> drawn, List<List<int>> times, double side) async {
    if (state.status != NinjaStatus.playing) return;
    if (drawn.isEmpty) {
      emit(state.copyWith(
          message: 'Write ${state.letter} first!', messageGood: false));
      return;
    }
    emit(state.copyWith(status: NinjaStatus.checking));
    final item = allLetterItems.firstWhere((l) => l.glyph == state.letter);
    final r = await _checker.check(
      letter: state.letter,
      drawn: drawn,
      times: times,
      template: item.strokes,
      canvasSide: side,
    );
    if (isClosed) return;
    // The clock may have run out while we were checking.
    if (state.status == NinjaStatus.lost) return;

    if (!r.passed) {
      emit(state.copyWith(
        status: NinjaStatus.playing,
        message: 'Not quite (${r.percent}%) — write ${state.letter} again, '
            'fast!',
        messageGood: false,
        clearTick: state.clearTick + 1,
      ));
      return;
    }

    final score = state.score + 1;
    if (state.index + 1 < state.letters.length) {
      final next = state.letters[state.index + 1];
      emit(state.copyWith(
        status: NinjaStatus.playing,
        index: state.index + 1,
        score: score,
        secondsLeft: state.secondsPerLetter, // a fresh clock for each letter
        message: 'Slice! Now write $next!',
        messageGood: true,
        clearTick: state.clearTick + 1,
      ));
      return;
    }

    // All five letters written in time: the round is won (SRS T_39).
    _timer?.cancel();
    await _progress.saveGameBest('ninja_best', state.round);
    final badges = await _badges.claimNewBadges();
    emit(state.copyWith(
      status: NinjaStatus.won,
      score: score,
      best: max(state.best, state.round),
      message: 'Round ${state.round} won! You are a Letter Ninja!',
      messageGood: true,
      clearTick: state.clearTick + 1,
      newBadges: badges,
    ));
  }

  Future<void> nextRound() => startRound(round: state.round + 1);
  Future<void> tryAgain() => startRound(round: state.round);

  void badgesShown() => emit(state.copyWith(newBadges: const []));

  @override
  Future<void> close() {
    _timer?.cancel();
    _checker.dispose();
    return super.close();
  }
}
