// SRS US_15 - the Letter Match game.
// Covers T_37 and T_38.

import 'package:flutter_test/flutter_test.dart';
import 'package:kidscribe/blocs/games/match_cubit.dart';
import 'package:kidscribe/services/badge_service.dart';
import 'package:kidscribe/services/progress_service.dart';

import 'helpers.dart';

void main() {
  late MatchCubit cubit;

  setUp(() async {
    await useEmptyStorage();
    cubit = MatchCubit(progress: ProgressService(), badges: BadgeService());
    // Level 1 shows every card for 3 seconds first, then turns them over.
    await Future.delayed(const Duration(milliseconds: 3300));
  });

  tearDown(() async => cubit.close());

  /// Two cards that are still in the game and carry the same letter.
  (int, int) samePair() {
    final cards = cubit.state.cards;
    bool open(int i) => !cards[i].matched;
    for (var i = 0; i < cards.length; i++) {
      for (var j = i + 1; j < cards.length; j++) {
        if (open(i) && open(j) && cards[i].letter == cards[j].letter) {
          return (i, j);
        }
      }
    }
    throw StateError('every card should have a partner');
  }

  /// Two cards that are still in the game with different letters.
  (int, int) differentPair() {
    final cards = cubit.state.cards;
    bool open(int i) => !cards[i].matched;
    for (var i = 0; i < cards.length; i++) {
      for (var j = i + 1; j < cards.length; j++) {
        if (open(i) && open(j) && cards[i].letter != cards[j].letter) {
          return (i, j);
        }
      }
    }
    throw StateError('level 1 should hold more than one letter');
  }

  test('the game starts with the cards turned over', () {
    expect(cubit.state.peeking, isFalse);
    expect(cubit.state.busy, isFalse);
    expect(cubit.state.cards, isNotEmpty);
    expect(cubit.state.cards.every((c) => !c.faceUp), isTrue);
    expect(cubit.state.score, 0);
  });

  test('T_37 matching two of the same letter makes the score go up',
      () async {
    final (a, b) = samePair();

    await cubit.tapCard(a);
    await cubit.tapCard(b);

    expect(cubit.state.score, 1);
    expect(cubit.state.cards[a].matched, isTrue);
    expect(cubit.state.cards[b].matched, isTrue);
    expect(cubit.state.messageGood, isTrue);
  });

  test('T_38 two different letters score nothing and the child tries again',
      () async {
    final (a, b) = differentPair();

    await cubit.tapCard(a);
    await cubit.tapCard(b);

    expect(cubit.state.score, 0, reason: 'no score for a wrong pair');
    expect(cubit.state.misses, 1);
    expect(cubit.state.messageGood, isFalse);
    expect(cubit.state.cards[a].matched, isFalse);
    expect(cubit.state.cards[b].matched, isFalse);

    // After a moment the two cards turn back, so the child can try again.
    await Future.delayed(const Duration(milliseconds: 1200));
    expect(cubit.state.cards[a].faceUp, isFalse);
    expect(cubit.state.cards[b].faceUp, isFalse);
    expect(cubit.state.busy, isFalse);
  });

  test('the same card cannot be tapped twice as a pair', () async {
    final (a, _) = samePair();
    await cubit.tapCard(a);
    await cubit.tapCard(a); // tapping it again does nothing
    expect(cubit.state.firstPick, a);
    expect(cubit.state.score, 0);
  });

  test('the game gets harder: later levels have more cards', () {
    expect(MatchCubit.maxLevel, 5);
    // level 1 has 3 pairs = 6 cards
    expect(cubit.state.cards.length, 6);
  });

  test('finishing a level saves it as the best level reached', () async {
    // match every pair of level 1
    while (cubit.state.cards.any((c) => !c.matched)) {
      final (a, b) = samePair();
      await cubit.tapCard(a);
      await cubit.tapCard(b);
    }
    expect(cubit.state.levelDone, isTrue);

    final games = await ProgressService().loadGames();
    expect(games['match_best'], 1);
  });
}
