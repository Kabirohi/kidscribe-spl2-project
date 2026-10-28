import 'dart:math';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../services/badge_service.dart';
import '../../services/progress_service.dart';

class MatchCard extends Equatable {
  final int id;
  final String letter;
  final bool faceUp;
  final bool matched;

  const MatchCard(this.id, this.letter,
      {this.faceUp = false, this.matched = false});

  MatchCard copyWith({bool? faceUp, bool? matched}) => MatchCard(id, letter,
      faceUp: faceUp ?? this.faceUp, matched: matched ?? this.matched);

  @override
  List<Object?> get props => [id, letter, faceUp, matched];
}

class MatchState extends Equatable {
  final int level;
  final List<MatchCard> cards;
  final int? firstPick;   // index of the first card turned over
  final int score;        // pairs found (whole game)
  final int misses;       // wrong pairs this level
  final bool busy;        // cards are turning back — wait
  final bool peeking;     // all cards shown for a moment at the start
  final String? message;
  final bool messageGood;
  final bool levelDone;
  final int best;         // best level ever reached
  final List<BadgeDef> newBadges;

  const MatchState({
    this.level = 1,
    this.cards = const [],
    this.firstPick,
    this.score = 0,
    this.misses = 0,
    this.busy = false,
    this.peeking = false,
    this.message,
    this.messageGood = true,
    this.levelDone = false,
    this.best = 0,
    this.newBadges = const [],
  });

  bool get isLastLevel => level >= MatchCubit.maxLevel;

  MatchState copyWith({
    int? level,
    List<MatchCard>? cards,
    int? firstPick,
    bool clearPick = false,
    int? score,
    int? misses,
    bool? busy,
    bool? peeking,
    String? message,
    bool? messageGood,
    bool? levelDone,
    int? best,
    List<BadgeDef>? newBadges,
  }) =>
      MatchState(
        level: level ?? this.level,
        cards: cards ?? this.cards,
        firstPick: clearPick ? null : (firstPick ?? this.firstPick),
        score: score ?? this.score,
        misses: misses ?? this.misses,
        busy: busy ?? this.busy,
        peeking: peeking ?? this.peeking,
        message: message ?? this.message,
        messageGood: messageGood ?? this.messageGood,
        levelDone: levelDone ?? this.levelDone,
        best: best ?? this.best,
        newBadges: newBadges ?? this.newBadges,
      );

  @override
  List<Object?> get props => [level, cards, firstPick, score, misses, busy,
        peeking, message, messageGood, levelDone, best, newBadges.length];
}

/// Letter Match (SRS FR_11 / US_15): turn over two cards; the same
/// letter scores a point, two different letters score nothing and turn
/// back so the child can try again.
///
/// It gets harder as the child plays: more cards each level, a shorter
/// look at the start, and from level 3 letters that look alike
/// (E and F, O and Q, M and N...) are mixed in.
class MatchCubit extends Cubit<MatchState> {
  final ProgressService _progress;
  final BadgeService _badges;
  final _rand = Random();
  int _gen = 0; // stops old timers from changing a new level

  static const maxLevel = 5;
  static const _pairsByLevel = [3, 4, 6, 8, 10];
  static const _peekMs = [3000, 2600, 2200, 1800, 1500];
  static const _lookAlike = ['E', 'F', 'O', 'Q', 'M', 'N', 'P', 'R', 'C', 'G',
    'U', 'V', 'I', 'L', 'B', 'D'];

  MatchCubit({required ProgressService progress, required BadgeService badges})
      : _progress = progress,
        _badges = badges,
        super(const MatchState()) {
    _init();
  }

  Future<void> _init() async {
    final games = await _progress.loadGames();
    emit(state.copyWith(best: games['match_best'] ?? 0));
    await startLevel(1);
  }

  Future<void> startLevel(int level) async {
    final gen = ++_gen;
    final pairs = _pairsByLevel[level - 1];
    final letters = _pickLetters(pairs, hard: level >= 3);
    final cards = <MatchCard>[];
    var id = 0;
    for (final l in letters) {
      cards.add(MatchCard(id++, l, faceUp: true));
      cards.add(MatchCard(id++, l, faceUp: true));
    }
    cards.shuffle(_rand);

    // Show every card for a moment, then turn them all over.
    emit(state.copyWith(
      level: level,
      cards: cards,
      clearPick: true,
      misses: 0,
      busy: true,
      peeking: true,
      levelDone: false,
      message: 'Look carefully and remember!',
      messageGood: true,
    ));
    await Future.delayed(Duration(milliseconds: _peekMs[level - 1]));
    if (gen != _gen || isClosed) return;
    emit(state.copyWith(
      cards: [for (final c in state.cards) c.copyWith(faceUp: false)],
      busy: false,
      peeking: false,
      message: 'Find two cards with the same letter!',
    ));
  }

  List<String> _pickLetters(int count, {required bool hard}) {
    final all = List.generate(26, (i) => String.fromCharCode(65 + i));
    final chosen = <String>{};
    if (hard) {
      // Add look-alike letters, so the child must look closely.
      final alike = [..._lookAlike]..shuffle(_rand);
      chosen.addAll(alike.take(count ~/ 2));
    }
    all.shuffle(_rand);
    for (final l in all) {
      if (chosen.length >= count) break;
      chosen.add(l);
    }
    return chosen.toList();
  }

  Future<void> tapCard(int index) async {
    if (state.busy || state.levelDone) return;
    final card = state.cards[index];
    if (card.faceUp || card.matched) return;

    final cards = [...state.cards]..[index] = card.copyWith(faceUp: true);

    // First card of the pair.
    if (state.firstPick == null) {
      emit(state.copyWith(cards: cards, firstPick: index));
      return;
    }

    // Second card: compare.
    final first = state.firstPick!;
    if (cards[first].letter == card.letter) {
      // Same letter — the score goes up (SRS T_37).
      cards[first] = cards[first].copyWith(matched: true);
      cards[index] = cards[index].copyWith(matched: true);
      final allDone = cards.every((c) => c.matched);
      emit(state.copyWith(
        cards: cards,
        clearPick: true,
        score: state.score + 1,
        message: allDone
            ? 'You found them all!'
            : 'Yes! Both are ${card.letter}!',
        messageGood: true,
        levelDone: allDone,
      ));
      if (allDone) await _finishLevel();
      return;
    }

    // Different letters — no score, turn them back, try again (SRS T_38).
    final gen = _gen;
    emit(state.copyWith(
      cards: cards,
      clearPick: true,
      busy: true,
      misses: state.misses + 1,
      message: '${cards[first].letter} and ${card.letter} are not the same. '
          'Try again!',
      messageGood: false,
    ));
    await Future.delayed(const Duration(milliseconds: 1000));
    if (gen != _gen || isClosed) return;
    final back = [...state.cards];
    back[first] = back[first].copyWith(faceUp: false);
    back[index] = back[index].copyWith(faceUp: false);
    emit(state.copyWith(cards: back, busy: false));
  }

  Future<void> _finishLevel() async {
    await _progress.saveGameBest('match_best', state.level);
    final badges = await _badges.claimNewBadges();
    emit(state.copyWith(
      best: state.level > state.best ? state.level : state.best,
      newBadges: badges,
    ));
  }

  Future<void> nextLevel() async {
    if (!state.isLastLevel) await startLevel(state.level + 1);
  }

  Future<void> restart() async {
    emit(state.copyWith(score: 0));
    await startLevel(1);
  }

  void badgesShown() => emit(state.copyWith(newBadges: const []));
}
