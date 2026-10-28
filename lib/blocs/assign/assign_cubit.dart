import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/sentence_list.dart';
import '../../data/trace_templates.dart';
import '../../data/word_list.dart';
import '../../models/assignment_models.dart';
import '../../services/assignment_service.dart';
import '../../services/custom_word_service.dart';
import '../../services/premium_service.dart';
import '../common/ui_message.dart';

class AssignState extends Equatable {
  final AssignKind kind;
  final Set<String> strokes;
  final Set<String> letters;
  final Set<String> words;
  final Set<String> sentences;
  final bool inOrder;
  final int? days; // deadline for practice work (null = no limit)
  final int minutes; // time limit for a test
  final bool canGiveTests; // teachers always; parents with Premium
  final List<String> toyWords; // the child's own toy words
  final bool saving;
  final bool saved; // the screen closes when this turns true
  final UiMessage? message;

  const AssignState({
    this.kind = AssignKind.practice,
    this.strokes = const {},
    this.letters = const {},
    this.words = const {},
    this.sentences = const {},
    this.inOrder = true,
    this.days,
    this.minutes = 10,
    this.canGiveTests = false,
    this.toyWords = const [],
    this.saving = false,
    this.saved = false,
    this.message,
  });

  int get picked =>
      strokes.length + letters.length + words.length + sentences.length;

  AssignState copyWith({
    AssignKind? kind,
    Set<String>? strokes,
    Set<String>? letters,
    Set<String>? words,
    Set<String>? sentences,
    bool? inOrder,
    int? days,
    bool noLimit = false,
    int? minutes,
    bool? canGiveTests,
    List<String>? toyWords,
    bool? saving,
    bool? saved,
    UiMessage? message,
  }) =>
      AssignState(
        kind: kind ?? this.kind,
        strokes: strokes ?? this.strokes,
        letters: letters ?? this.letters,
        words: words ?? this.words,
        sentences: sentences ?? this.sentences,
        inOrder: inOrder ?? this.inOrder,
        days: noLimit ? null : (days ?? this.days),
        minutes: minutes ?? this.minutes,
        canGiveTests: canGiveTests ?? this.canGiveTests,
        toyWords: toyWords ?? this.toyWords,
        saving: saving ?? this.saving,
        saved: saved ?? this.saved,
        message: message ?? this.message,
      );

  @override
  List<Object?> get props => [
        kind, strokes.join(','), letters.join(','), words.join(','),
        sentences.join(','), inOrder, days, minutes, canGiveTests,
        toyWords.length, saving, saved, message
      ];
}

/// Making a task for one child.
///  - A Teacher gives homework or a timed test
///    (SRS FR_18/US_23, FR_23/US_31, FR_24/US_33).
///  - A Parent gives a writing challenge with a time limit
///    (SRS FR_17/US_21, FR_23/US_32). A timed test is a Premium extra
///    for parents (SRS FR_20).
class AssignCubit extends Cubit<AssignState> {
  final AssignmentService _service;
  final PremiumService _premium;
  final CustomWordService _toys;
  final String scope;
  final String fromRole;
  int _tick = 0;

  AssignCubit({
    required this.scope,
    required this.fromRole,
    required AssignmentService assignments,
    required PremiumService premium,
    required CustomWordService toys,
  })  : _service = assignments,
        _premium = premium,
        _toys = toys,
        super(const AssignState());

  bool get isTeacher => fromRole == 'Teacher';

  Future<void> load() async {
    final canTest = isTeacher || await _premium.isPremium();
    final toys = await _toys.loadFor(scope);
    if (isClosed) return;
    emit(state.copyWith(
        canGiveTests: canTest, toyWords: [for (final t in toys) t.word]));
  }

  void _say(String text, {bool error = false}) =>
      emit(state.copyWith(message: UiMessage(text, isError: error, tick: ++_tick)));

  void setKind(AssignKind k) {
    if (k == AssignKind.test && !state.canGiveTests) {
      _say('A timed test for parents is part of Premium. '
          'Open "Sync & Premium" to get it.', error: true);
      return;
    }
    emit(state.copyWith(kind: k));
  }

  Set<String> _flip(Set<String> s, String v) =>
      s.contains(v) ? ({...s}..remove(v)) : {...s, v};

  void toggleStroke(String id) =>
      emit(state.copyWith(strokes: _flip(state.strokes, id)));
  void toggleLetter(String g) =>
      emit(state.copyWith(letters: _flip(state.letters, g)));
  void toggleWord(String w) =>
      emit(state.copyWith(words: _flip(state.words, w)));
  void toggleSentence(String id) =>
      emit(state.copyWith(sentences: _flip(state.sentences, id)));
  void setInOrder(bool v) => emit(state.copyWith(inOrder: v));
  void setDays(int? d) =>
      emit(d == null ? state.copyWith(noLimit: true) : state.copyWith(days: d));
  void setMinutes(int m) => emit(state.copyWith(minutes: m));

  Future<void> save(String title) async {
    title = title.trim();
    // SRS US_21 / US_23: with no goal the task is not made.
    if (title.isEmpty) {
      _say('Please write a name for the task', error: true);
      return;
    }
    if (state.picked == 0) {
      _say('Pick at least one thing for the child to do', error: true);
      return;
    }
    emit(state.copyWith(saving: true));

    final s = state;
    final items = <AssignItem>[
      for (final x in stage1Items)
        if (s.strokes.contains(x.id)) AssignItem(ItemKind.stroke, x.id),
      for (final l in allLetterItems)
        if (s.letters.contains(l.glyph)) AssignItem(ItemKind.letter, l.glyph),
      for (final w in [...practiceWords.map((p) => p.word), ...s.toyWords])
        if (s.words.contains(w)) AssignItem(ItemKind.word, w),
      for (final p in practiceSentences)
        if (s.sentences.contains(p.id)) AssignItem(ItemKind.sentence, p.id),
    ];

    final now = DateTime.now().millisecondsSinceEpoch;
    await _service.save(
      scope,
      Assignment(
        id: now.toString(),
        title: title,
        kind: s.kind,
        fromRole: fromRole,
        items: items,
        inOrder: s.inOrder,
        dueAtMs: s.kind == AssignKind.practice && s.days != null
            ? now + s.days! * 24 * 60 * 60 * 1000
            : null,
        testMinutes: s.kind == AssignKind.test ? s.minutes : null,
      ),
    );
    if (!isClosed) emit(state.copyWith(saving: false, saved: true));
  }
}
