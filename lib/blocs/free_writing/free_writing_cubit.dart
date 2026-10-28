import 'dart:ui';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/trace_templates.dart';
import '../../services/badge_service.dart';
import '../../services/freehand_checker.dart';
import '../../services/progress_service.dart';

/// One letter the child wrote on the blank page.
class FreeAttempt extends Equatable {
  final String? letter; // what the app read (null = could not read it)
  final int percent;
  final bool good;
  const FreeAttempt(this.letter, this.percent, this.good);

  @override
  List<Object?> get props => [letter, percent, good];
}

class FreeWritingState extends Equatable {
  final bool checking;
  final List<FreeAttempt> history; // newest first
  final String? message;           // what to tell the child
  final bool lastGood;
  final int goodCount;             // all time
  final int tick;                  // goes up after every check
  final List<BadgeDef> newBadges;

  const FreeWritingState({
    this.checking = false,
    this.history = const [],
    this.message,
    this.lastGood = false,
    this.goodCount = 0,
    this.tick = 0,
    this.newBadges = const [],
  });

  FreeWritingState copyWith({
    bool? checking,
    List<FreeAttempt>? history,
    String? message,
    bool? lastGood,
    int? goodCount,
    int? tick,
    List<BadgeDef>? newBadges,
  }) =>
      FreeWritingState(
        checking: checking ?? this.checking,
        history: history ?? this.history,
        message: message ?? this.message,
        lastGood: lastGood ?? this.lastGood,
        goodCount: goodCount ?? this.goodCount,
        tick: tick ?? this.tick,
        newBadges: newBadges ?? this.newBadges,
      );

  @override
  List<Object?> get props => [checking, history, message, lastGood, goodCount,
        tick, newBadges.length];
}

/// Free Writing on a blank page (SRS FR_13 / US_17).
///
/// The child writes ANY capital letter. The ML model reads which letter
/// it is, and then the normal checker scores how neat it is. A letter
/// the model cannot read, or a messy one, is marked wrong with a tip.
class FreeWritingCubit extends Cubit<FreeWritingState> {
  final ProgressService _progress;
  final BadgeService _badges;
  final FreehandChecker _checker = FreehandChecker();

  static const counterKey = 'free_good';

  FreeWritingCubit({
    required ProgressService progress,
    required BadgeService badges,
  })  : _progress = progress,
        _badges = badges,
        super(const FreeWritingState()) {
    _loadCount();
  }

  Future<void> _loadCount() async {
    final games = await _progress.loadGames();
    emit(state.copyWith(goodCount: games[counterKey] ?? 0));
  }

  Future<void> check(
      List<List<Offset>> drawn, List<List<int>> times, double side) async {
    if (drawn.isEmpty) {
      emit(state.copyWith(
          message: 'Write a letter on the page first!',
          lastGood: false,
          tick: state.tick + 1));
      return;
    }
    emit(state.copyWith(checking: true));

    // 1. Which letter is it?
    final letter = await _checker.recognizeLetter(
        drawn: drawn, times: times, canvasSide: side);

    if (letter == null) {
      _record(const FreeAttempt(null, 0, false),
          "Hmm, I can't read a letter there. Try writing ONE big capital "
          'letter, slowly.');
      return;
    }

    // 2. How neat is it? Compare with that letter's shape and stroke order.
    final item = allLetterItems.where((l) => l.glyph == letter).firstOrNull;
    if (item == null) {
      _record(FreeAttempt(letter, 0, false),
          'I read "$letter", but it is not a letter we practice yet.');
      return;
    }
    final r = await _checker.check(
      letter: letter,
      drawn: drawn,
      times: times,
      template: item.strokes,
      canvasSide: side,
    );

    if (r.passed) {
      final total = await _progress.addToCounter(counterKey);
      final badges = await _badges.claimNewBadges();
      emit(state.copyWith(goodCount: total, newBadges: badges));
      _record(FreeAttempt(letter, r.percent, true),
          'You wrote "$letter" — ${r.percent}%! Beautiful!');
    } else {
      _record(FreeAttempt(letter, r.percent, false),
          'I think that is "$letter", but it is marked wrong (${r.percent}%).\n'
          '${r.kidMessage}');
    }
  }

  void _record(FreeAttempt a, String message) {
    emit(state.copyWith(
      checking: false,
      history: [a, ...state.history].take(12).toList(),
      message: message,
      lastGood: a.good,
      tick: state.tick + 1,
    ));
  }

  void badgesShown() => emit(state.copyWith(newBadges: const []));

  @override
  Future<void> close() {
    _checker.dispose();
    return super.close();
  }
}
