// SRS US_18 - badges, rewards and the daily streak.
// Covers T_43 and T_44.

import 'package:flutter_test/flutter_test.dart';
import 'package:kidscribe/services/badge_service.dart';
import 'package:kidscribe/services/progress_service.dart';

import 'helpers.dart';

void main() {
  late BadgeService badges;
  late ProgressService progress;

  setUp(() async {
    await useEmptyStorage();
    badges = BadgeService();
    progress = ProgressService();
  });

  group('US_18 earning badges', () {
    test('T_43 finishing a practice task gives a badge', () async {
      expect(await badges.computeEarnedIds(), isEmpty);

      await progress.saveStars('s1_line', 2); // one real practice

      final earned = await badges.computeEarnedIds();
      expect(earned, contains('first_check'));
    });

    test('T_43 a new badge is handed over only once', () async {
      await progress.saveStars('s1_line', 3);

      final first = await badges.claimNewBadges();
      expect(first, isNotEmpty);

      final second = await badges.claimNewBadges();
      expect(second, isEmpty, reason: 'the same badge must not pop up twice');
    });

    test('three stars gives the Perfect Tracer badge', () async {
      await progress.saveStars('s1_line', 3);
      expect(await badges.computeEarnedIds(), contains('perfect_trace'));
    });

    test('finishing a letter gives the Letter Starter badge', () async {
      await progress.saveGuided('A', 2);
      await progress.saveFree('A', 80);
      expect(await badges.computeEarnedIds(), contains('first_letter'));
    });

    test('a first sentence gives the Sentence Maker badge', () async {
      await progress.saveSentenceDone('s01');
      expect(await badges.computeEarnedIds(), contains('first_sentence'));
    });

    test('winning Letter Ninja gives the Ninja badge', () async {
      await progress.saveGameBest('ninja_best', 1);
      expect(await badges.computeEarnedIds(), contains('ninja'));
    });

    test('reaching level 3 of Letter Match gives the Match badge', () async {
      await progress.saveGameBest('match_best', 3);
      expect(await badges.computeEarnedIds(), contains('match_champ'));
    });

    test('every badge is still locked for a brand new child', () async {
      final earned = await badges.computeEarnedIds();
      expect(earned, isEmpty);
      expect(allBadges.length, greaterThan(10));
    });
  });

  group('US_18 the daily streak', () {
    final today = DateTime.now();

    test('practising today starts a 1 day streak', () {
      final log = {dayKey(today): 3};
      expect(badges.currentStreak(log), 1);
    });

    test('three days in a row is a 3 day streak', () {
      final log = {
        dayKey(today): 1,
        dayKey(today.subtract(const Duration(days: 1))): 1,
        dayKey(today.subtract(const Duration(days: 2))): 1,
      };
      expect(badges.currentStreak(log), 3);
    });

    test('the streak still lives if they practised yesterday', () {
      final log = {dayKey(today.subtract(const Duration(days: 1))): 1};
      expect(badges.currentStreak(log), 1);
    });

    test('T_44 missing one full day puts the streak back to zero', () {
      // practised 2 and 3 days ago, but nothing yesterday or today
      final log = {
        dayKey(today.subtract(const Duration(days: 2))): 1,
        dayKey(today.subtract(const Duration(days: 3))): 1,
      };
      expect(badges.currentStreak(log), 0);
    });

    test('an empty practice log has no streak', () {
      expect(badges.currentStreak({}), 0);
    });

    test('the best streak ever is remembered', () {
      final log = {
        // a run of 3, long ago
        '2026-01-01': 1, '2026-01-02': 1, '2026-01-03': 1,
        // and a run of 2
        '2026-02-01': 1, '2026-02-02': 1,
      };
      expect(badges.bestStreak(log), 3);
    });
  });
}
