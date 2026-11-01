import 'dart:ui';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/trace_templates.dart';
import '../../models/trace_item.dart';
import '../../services/badge_service.dart';
import '../../services/freehand_checker.dart';
import '../../services/progress_service.dart';
import '../../services/trace_evaluator.dart';
import '../common/ui_message.dart';

class LetterPracticeState extends Equatable {
  final int level; // 0..25 into allLetterItems
  final int guidedStars; // best stars on the guided side
  final int freeBest; // best free-hand percent
  final bool checkingFree;

  final TraceResult? guidedResult;
  final int guidedTick; // changes when a guided result is ready
  final FreehandResult? freeResult;
  final int freeTick; // changes when a free-hand result is ready
  final List<BadgeDef> newBadges;

  /// Changes when the tutorial video should play by itself.
  final int introTick;

  /// True after the very last letter, so the screen can close.
  final bool finishedAll;
  final UiMessage? message;

  const LetterPracticeState({
    this.level = 0,
    this.guidedStars = 0,
    this.freeBest = 0,
    this.checkingFree = false,
    this.guidedResult,
    this.guidedTick = 0,
    this.freeResult,
    this.freeTick = 0,
    this.newBadges = const [],
    this.introTick = 0,
    this.finishedAll = false,
    this.message,
  });

  TraceItem get item => allLetterItems[level];
  bool get guidedDone => guidedStars > 0;
  bool get freeDone => freeBest >= ProgressService.freePassPercent;

  /// The next letter opens only when BOTH sides are done.
  bool get bothDone => guidedDone && freeDone;
  bool get isLast => level + 1 >= allLetterItems.length;

  LetterPracticeState copyWith({
    int? level,
    int? guidedStars,
    int? freeBest,
    bool? checkingFree,
    TraceResult? guidedResult,
    int? guidedTick,
    FreehandResult? freeResult,
    int? freeTick,
    List<BadgeDef>? newBadges,
    int? introTick,
    bool? finishedAll,
    UiMessage? message,
  }) =>
      LetterPracticeState(
        level: level ?? this.level,
        guidedStars: guidedStars ?? this.guidedStars,
        freeBest: freeBest ?? this.freeBest,
        checkingFree: checkingFree ?? this.checkingFree,
        guidedResult: guidedResult ?? this.guidedResult,
        guidedTick: guidedTick ?? this.guidedTick,
        freeResult: freeResult ?? this.freeResult,
        freeTick: freeTick ?? this.freeTick,
        newBadges: newBadges ?? this.newBadges,
        introTick: introTick ?? this.introTick,
        finishedAll: finishedAll ?? this.finishedAll,
        message: message ?? this.message,
      );

  @override
  List<Object?> get props => [
        level, guidedStars, freeBest, checkingFree, guidedTick, freeTick,
        newBadges.length, introTick, finishedAll, message
      ];
}

/// One letter level with two sides (SRS FR_7, FR_8, FR_9):
///  - guided: trace on numbered points, checked by TraceEvaluator
///  - free hand: checked by ML Kit + a shape check (70% to pass)
/// The pen lines stay in the screen; this cubit checks and saves.
class LetterPracticeCubit extends Cubit<LetterPracticeState> {
  final ProgressService _progress;
  final BadgeService _badges;
  final FreehandChecker _checker = FreehandChecker();
  final bool examMode;
  int _tick = 0;

  LetterPracticeCubit({
    required ProgressService progress,
    required BadgeService badges,
    required int levelIndex,
    this.examMode = false,
  })  : _progress = progress,
        _badges = badges,
        super(LetterPracticeState(level: levelIndex));

  void _say(String text) =>
      emit(state.copyWith(message: UiMessage(text, tick: ++_tick)));

  Future<void> load() async {
    final all = await _progress.loadLetters();
    if (isClosed) return;
    final entry = all[state.item.glyph];
    final loaded = state.copyWith(
      guidedStars: entry?['guided'] ?? 0,
      freeBest: entry?['free'] ?? 0,
    );
    // Like a video before the level: play the tutorial for new letters.
    // In a test there is no help, so nothing plays (SRS US_33).
    final showIntro = !loaded.bothDone && !examMode;
    emit(loaded.copyWith(
        introTick: showIntro ? state.introTick + 1 : state.introTick));
  }

  Future<void> checkGuided(List<List<Offset>> drawn) async {
    if (drawn.isEmpty) {
      _say('Trace the letter first. Start at point 1!');
      return;
    }
    final r = TraceEvaluator.evaluate(drawn: drawn, template: state.item.strokes);
    var stars = state.guidedStars;
    var badges = const <BadgeDef>[];
    if (r.passed) {
      await _progress.saveGuided(state.item.glyph, r.stars);
      if (r.stars > stars) stars = r.stars;
      badges = await _badges.claimNewBadges();
    }
    if (isClosed) return;
    emit(state.copyWith(
      guidedStars: stars,
      guidedResult: r,
      guidedTick: state.guidedTick + 1,
      newBadges: badges,
    ));
  }

  Future<void> checkFree(
      List<List<Offset>> drawn, List<List<int>> times, double side) async {
    if (state.checkingFree) return;
    if (drawn.isEmpty) {
      _say('Write the letter ${state.item.glyph} on the free page first!');
      return;
    }
    emit(state.copyWith(checkingFree: true));
    final r = await _checker.check(
      letter: state.item.glyph,
      drawn: drawn,
      times: times,
      template: state.item.strokes,
      canvasSide: side,
    );
    var best = state.freeBest;
    if (r.percent > best) {
      await _progress.saveFree(state.item.glyph, r.percent);
      best = r.percent;
    }
    final badges = await _badges.claimNewBadges();
    if (isClosed) return;
    emit(state.copyWith(
      checkingFree: false,
      freeBest: best,
      freeResult: r,
      freeTick: state.freeTick + 1,
      newBadges: badges,
    ));
  }

  void badgesShown() => emit(state.copyWith(newBadges: const []));

  Future<void> nextLevel() async {
    if (!state.bothDone) return;
    if (state.isLast) {
      emit(state.copyWith(finishedAll: true));
      return;
    }
    // Keep the ticks as they are, so no old result pops up again.
    emit(state.copyWith(level: state.level + 1, guidedStars: 0, freeBest: 0));
    await load();
  }

  @override
  Future<void> close() {
    _checker.dispose();
    return super.close();
  }
}
