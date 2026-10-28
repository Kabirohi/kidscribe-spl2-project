import 'dart:ui';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../models/trace_item.dart';
import '../../services/badge_service.dart';
import '../../services/progress_service.dart';
import '../../services/trace_evaluator.dart';
import '../common/ui_message.dart';

class TracingState extends Equatable {
  final int index;
  final Map<String, int> stars; // item id -> best stars
  final bool checking;

  /// The last check. [resultTick] changes each time, so the screen shows
  /// the result dialog exactly once.
  final TraceResult? result;
  final int resultTick;
  final List<BadgeDef> newBadges;

  /// Changes when the tutorial video should play by itself (a new shape
  /// the child has not passed yet).
  final int introTick;
  final UiMessage? message;

  const TracingState({
    this.index = 0,
    this.stars = const {},
    this.checking = false,
    this.result,
    this.resultTick = 0,
    this.newBadges = const [],
    this.introTick = 0,
    this.message,
  });

  TracingState copyWith({
    int? index,
    Map<String, int>? stars,
    bool? checking,
    TraceResult? result,
    int? resultTick,
    List<BadgeDef>? newBadges,
    int? introTick,
    UiMessage? message,
  }) =>
      TracingState(
        index: index ?? this.index,
        stars: stars ?? this.stars,
        checking: checking ?? this.checking,
        result: result ?? this.result,
        resultTick: resultTick ?? this.resultTick,
        newBadges: newBadges ?? this.newBadges,
        introTick: introTick ?? this.introTick,
        message: message ?? this.message,
      );

  @override
  List<Object?> get props => [
        index, stars.entries.map((e) => '${e.key}:${e.value}').join(','),
        checking, resultTick,
        newBadges.length, introTick, message
      ];
}

/// Stage 1 tracing (SRS FR_5, FR_6, FR_7): check the trace, give stars,
/// save them, and hand out any new badge. The pen lines themselves stay
/// in the screen's WritingPadController.
class TracingCubit extends Cubit<TracingState> {
  final ProgressService _progress;
  final BadgeService _badges;
  final List<TraceItem> items;
  final bool examMode;
  int _tick = 0;

  TracingCubit({
    required ProgressService progress,
    required BadgeService badges,
    required this.items,
    required int startIndex,
    this.examMode = false,
  })  : _progress = progress,
        _badges = badges,
        super(TracingState(index: startIndex));

  TraceItem get item => items[state.index];
  bool get hasNext => state.index + 1 < items.length;

  Future<void> load() async {
    final all = await _progress.loadAll();
    if (isClosed) return;
    // Play the tutorial first for a shape not passed yet (ages 5-8: show
    // first, then try). Never in a test (SRS US_33).
    final showIntro = (all[item.id] ?? 0) == 0 && !examMode;
    emit(state.copyWith(
        stars: Map.of(all),
        introTick: showIntro ? state.introTick + 1 : state.introTick));
  }

  Future<void> check(List<List<Offset>> drawn) async {
    if (state.checking) return;
    if (drawn.isEmpty) {
      emit(state.copyWith(
          message: UiMessage('Draw the shape first!', tick: ++_tick)));
      return;
    }
    emit(state.copyWith(checking: true));
    final result = TraceEvaluator.evaluate(drawn: drawn, template: item.strokes);
    var stars = state.stars;
    var badges = const <BadgeDef>[];
    if (result.passed) {
      await _progress.saveStars(item.id, result.stars);
      if (result.stars > (stars[item.id] ?? 0)) {
        stars = {...stars, item.id: result.stars};
      }
      badges = await _badges.claimNewBadges(); // SRS T_43
    }
    if (isClosed) return;
    emit(state.copyWith(
      checking: false,
      stars: stars,
      result: result,
      resultTick: state.resultTick + 1,
      newBadges: badges,
    ));
  }

  void badgesShown() => emit(state.copyWith(newBadges: const []));

  Future<void> next() async {
    if (!hasNext) return;
    emit(state.copyWith(index: state.index + 1));
    await load(); // auto-plays the tutorial for the next shape too
  }
}
