import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/sentence_list.dart';
import '../../services/badge_service.dart';
import '../../services/progress_service.dart';
import '../../services/sentence_checker.dart';

/// One word card (or the full stop card) the child can move.
class SentenceCard extends Equatable {
  final int id;
  final String text;
  const SentenceCard(this.id, this.text);

  SentenceCard withText(String t) => SentenceCard(id, t);

  @override
  List<Object?> get props => [id, text];
}

class SentenceState extends Equatable {
  final int index;                  // which sentence
  final List<SentenceCard> pool;    // cards not used yet
  final List<SentenceCard?> slots;  // the boxes, left to right
  final SentenceCheck? result;      // the last check
  final Set<String> doneIds;        // finished sentences
  final int celebrateTick;          // goes up when the child gets it right
  final List<BadgeDef> newBadges;   // badges to show once

  const SentenceState({
    this.index = 0,
    this.pool = const [],
    this.slots = const [],
    this.result,
    this.doneIds = const {},
    this.celebrateTick = 0,
    this.newBadges = const [],
  });

  PracticeSentence get sentence => practiceSentences[index];
  bool get solved => result?.ok ?? false;
  bool get hasNext => index + 1 < practiceSentences.length;

  SentenceState copyWith({
    int? index,
    List<SentenceCard>? pool,
    List<SentenceCard?>? slots,
    SentenceCheck? result,
    bool clearResult = false,
    Set<String>? doneIds,
    int? celebrateTick,
    List<BadgeDef>? newBadges,
  }) =>
      SentenceState(
        index: index ?? this.index,
        pool: pool ?? this.pool,
        slots: slots ?? this.slots,
        result: clearResult ? null : (result ?? this.result),
        doneIds: doneIds ?? this.doneIds,
        celebrateTick: celebrateTick ?? this.celebrateTick,
        newBadges: newBadges ?? this.newBadges,
      );

  @override
  List<Object?> get props => [index, pool, slots, result?.problem,
        result?.message, result?.badSlots, doneIds.length, celebrateTick,
        newBadges.length];
}

/// Stage 4: build a sentence with word cards (SRS FR_9 / US_12, US_13).
class SentenceCubit extends Cubit<SentenceState> {
  final ProgressService _progress;
  final BadgeService _badges;

  SentenceCubit({
    required ProgressService progress,
    required BadgeService badges,
    int startIndex = 0,
  })  : _progress = progress,
        _badges = badges,
        super(const SentenceState()) {
    open(startIndex);
  }

  /// Sets up one sentence: every word becomes a small-letter card, plus a
  /// full stop card, all mixed up. The child must add the capital.
  Future<void> open(int index) async {
    final s = practiceSentences[index];
    final cards = <SentenceCard>[
      for (var i = 0; i < s.words.length; i++)
        SentenceCard(i, s.words[i].toLowerCase()),
      SentenceCard(s.words.length, SentenceChecker.stop),
    ];
    // Mix the cards, but never leave them already in the right order.
    final mixed = [...cards]..shuffle();
    if (_sameOrder(mixed, cards)) mixed.add(mixed.removeAt(0));

    final done = await _progress.loadSentences();
    emit(SentenceState(
      index: index,
      pool: mixed,
      slots: List<SentenceCard?>.filled(cards.length, null),
      doneIds: done.keys.toSet(),
      celebrateTick: state.celebrateTick,
    ));
  }

  bool _sameOrder(List<SentenceCard> a, List<SentenceCard> b) {
    for (var i = 0; i < a.length; i++) {
      if (a[i].id != b[i].id) return false;
    }
    return true;
  }

  /// Drops a card into a box (a card already in that box goes back).
  void place(int cardId, int slot) {
    if (state.solved) return;
    final card = [
      ...state.pool,
      ...state.slots.whereType<SentenceCard>(),
    ].firstWhere((c) => c.id == cardId);
    final pool = state.pool.where((c) => c.id != cardId).toList();
    final slots = [
      for (final s in state.slots) (s?.id == cardId) ? null : s
    ];
    final old = slots[slot];
    if (old != null) pool.add(old);
    slots[slot] = card;
    emit(state.copyWith(pool: pool, slots: slots, clearResult: true));
  }

  /// A tap on a pool card puts it in the first empty box.
  void placeInFirstEmpty(int cardId) {
    final i = state.slots.indexWhere((s) => s == null);
    if (i != -1) place(cardId, i);
  }

  /// A tap on a box sends its card back to the pool.
  void takeBack(int slot) {
    if (state.solved) return;
    final card = state.slots[slot];
    if (card == null) return;
    final slots = [...state.slots]..[slot] = null;
    emit(state.copyWith(
        pool: [...state.pool, card], slots: slots, clearResult: true));
  }

  /// The "Aa" button: big or small first letter.
  void toggleCapital(int slot) {
    if (state.solved) return;
    final card = state.slots[slot];
    if (card == null || card.text == SentenceChecker.stop) return;
    final slots = [...state.slots]
      ..[slot] = card.withText(SentenceChecker.toggleCapital(card.text));
    emit(state.copyWith(slots: slots, clearResult: true));
  }

  Future<void> check() async {
    final placed = [for (final s in state.slots) s?.text];
    final result = SentenceChecker.check(state.sentence, placed);
    if (!result.ok) {
      emit(state.copyWith(result: result));
      return;
    }
    await _progress.saveSentenceDone(state.sentence.id);
    final badges = await _badges.claimNewBadges();
    emit(state.copyWith(
      result: result,
      doneIds: {...state.doneIds, state.sentence.id},
      celebrateTick: state.celebrateTick + 1,
      newBadges: badges,
    ));
  }

  void badgesShown() => emit(state.copyWith(newBadges: const []));

  Future<void> next() async {
    if (state.hasNext) await open(state.index + 1);
  }

  Future<void> retry() => open(state.index);
}
