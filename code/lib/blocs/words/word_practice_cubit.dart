import 'dart:ui';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/trace_templates.dart';
import '../../data/word_list.dart';
import '../../models/trace_item.dart';
import '../../services/badge_service.dart';
import '../../services/freehand_checker.dart';
import '../../services/progress_service.dart';

/// What happened at the last check, so the screen can react once.
enum WordEvent { none, letterOk, letterWrong, wordDone }

class WordPracticeState extends Equatable {
  final List<PracticeWord> words;
  final int wordIndex;
  final int letterIndex;     // which letter of the word is being written
  final bool wordDone;
  final bool checking;
  final WordEvent event;
  final int eventTick;       // goes up after every check
  final FreehandResult? lastResult;
  final String? message;
  final List<BadgeDef> newBadges;

  const WordPracticeState({
    required this.words,
    this.wordIndex = 0,
    this.letterIndex = 0,
    this.wordDone = false,
    this.checking = false,
    this.event = WordEvent.none,
    this.eventTick = 0,
    this.lastResult,
    this.message,
    this.newBadges = const [],
  });

  PracticeWord get word => words[wordIndex];
  String get currentChar => word.word[letterIndex];
  TraceItem get currentItem =>
      allLetterItems.firstWhere((i) => i.glyph == currentChar);
  bool get hasNext => wordIndex + 1 < words.length;

  WordPracticeState copyWith({
    int? wordIndex,
    int? letterIndex,
    bool? wordDone,
    bool? checking,
    WordEvent? event,
    int? eventTick,
    FreehandResult? lastResult,
    String? message,
    List<BadgeDef>? newBadges,
  }) =>
      WordPracticeState(
        words: words,
        wordIndex: wordIndex ?? this.wordIndex,
        letterIndex: letterIndex ?? this.letterIndex,
        wordDone: wordDone ?? this.wordDone,
        checking: checking ?? this.checking,
        event: event ?? this.event,
        eventTick: eventTick ?? this.eventTick,
        lastResult: lastResult ?? this.lastResult,
        message: message ?? this.message,
        newBadges: newBadges ?? this.newBadges,
      );

  @override
  List<Object?> get props => [wordIndex, letterIndex, wordDone, checking,
        event, eventTick, message, newBadges.length];
}

/// Stage 3: write a word letter by letter (SRS FR_8 / US_11).
/// Every letter is checked by the ML checker; the word is saved only
/// when EVERY letter is right (SRS T_29, T_30).
class WordPracticeCubit extends Cubit<WordPracticeState> {
  final ProgressService _progress;
  final BadgeService _badges;
  final FreehandChecker _checker = FreehandChecker();

  WordPracticeCubit({
    required ProgressService progress,
    required BadgeService badges,
    required List<PracticeWord> words,
    int startIndex = 0,
  })  : _progress = progress,
        _badges = badges,
        super(WordPracticeState(words: words, wordIndex: startIndex));

  Future<void> check(
      List<List<Offset>> drawn, List<List<int>> times, double side) async {
    if (state.wordDone || state.checking) return;
    if (drawn.isEmpty) {
      emit(state.copyWith(
        event: WordEvent.none,
        eventTick: state.eventTick + 1,
        message: 'Write the letter ${state.currentChar} first!',
      ));
      return;
    }
    emit(state.copyWith(checking: true));
    final r = await _checker.check(
      letter: state.currentChar,
      drawn: drawn,
      times: times,
      template: state.currentItem.strokes,
      canvasSide: side,
    );
    if (isClosed) return;

    if (!r.passed) {
      emit(state.copyWith(
        checking: false,
        event: WordEvent.letterWrong,
        eventTick: state.eventTick + 1,
        lastResult: r,
      ));
      return;
    }

    // This letter is right.
    if (state.letterIndex + 1 < state.word.word.length) {
      final next = state.word.word[state.letterIndex + 1];
      emit(state.copyWith(
        checking: false,
        letterIndex: state.letterIndex + 1,
        event: WordEvent.letterOk,
        eventTick: state.eventTick + 1,
        message: '$next is next — keep going!',
      ));
      return;
    }

    // The whole word is right: save it.
    await _progress.saveWordDone(state.word.word);
    final badges = await _badges.claimNewBadges();
    emit(state.copyWith(
      checking: false,
      wordDone: true,
      event: WordEvent.wordDone,
      eventTick: state.eventTick + 1,
      newBadges: badges,
    ));
  }

  void nextWord() {
    if (!state.hasNext) return;
    emit(WordPracticeState(
        words: state.words,
        wordIndex: state.wordIndex + 1,
        eventTick: state.eventTick + 1));
  }

  void badgesShown() => emit(state.copyWith(newBadges: const []));

  @override
  Future<void> close() {
    _checker.dispose();
    return super.close();
  }
}
