// SRS US_21, US_23, US_31, US_32, US_33 - tasks, challenges, deadlines
// and timed tests.
// Covers T_49, T_50, T_55, T_72, T_73, T_74, T_76, T_78, T_79, T_80.

import 'package:flutter_test/flutter_test.dart';
import 'package:kidscribe/models/assignment_models.dart';
import 'package:kidscribe/services/assignment_service.dart';
import 'package:kidscribe/services/progress_service.dart';

import 'helpers.dart';

/// A task with one step: write 5 words that start with A.
Assignment challenge({
  String id = 'a1',
  String title = 'Write 5 words with letter A',
  AssignKind kind = AssignKind.practice,
  String fromRole = 'Parent',
  int? dueAtMs,
  int? testMinutes,
  bool inOrder = false,
  List<AssignItem>? items,
}) =>
    Assignment(
      id: id,
      title: title,
      kind: kind,
      fromRole: fromRole,
      items: items ??
          [
            const AssignItem(ItemKind.word, 'APPLE'),
            const AssignItem(ItemKind.word, 'ANT'),
          ],
      inOrder: inOrder,
      dueAtMs: dueAtMs,
      testMinutes: testMinutes,
    );

void main() {
  late AssignmentService service;
  late ProgressService progress;

  setUp(() async {
    await useEmptyStorage();
    service = AssignmentService();
    progress = ProgressService();
  });

  group('US_21 parent writing challenge', () {
    test('T_49 a challenge with a goal is saved and the child can see it',
        () async {
      await service.save(guestScope, challenge());

      final open = await service.openTasks(guestScope);
      expect(open.length, 1);
      expect(open.first.title, 'Write 5 words with letter A');
      expect(open.first.items.length, 2);
    });

    test('T_50 the challenge is marked done when every step is finished',
        () async {
      await service.save(guestScope, challenge());

      await service.markItemDone(guestScope, 'a1', 'word:APPLE');
      var list = await service.loadFor(guestScope);
      expect(list.first.allDone, isFalse);

      await service.markItemDone(guestScope, 'a1', 'word:ANT');
      list = await service.loadFor(guestScope);
      expect(list.first.allDone, isTrue);
      // finished work goes to the grown-up by itself
      expect(list.first.submitted, isTrue);
    });
  });

  group('US_23 teacher assigns a challenge', () {
    test('T_55 the task is sent to the student', () async {
      await service.save(
          guestScope, challenge(id: 't1', fromRole: 'Teacher'));

      final list = await service.loadFor(guestScope);
      expect(list.length, 1);
      expect(list.first.fromRole, 'Teacher');
    });
  });

  group('US_31 and US_32 time limits', () {
    test('T_72 the time left is shown while the deadline is in the future',
        () async {
      final tomorrow = DateTime.now()
          .add(const Duration(days: 1))
          .millisecondsSinceEpoch;
      await service.save(guestScope, challenge(dueAtMs: tomorrow));

      final a = (await service.loadFor(guestScope)).first;
      expect(a.timeIsOver, isFalse);
      expect(a.msLeft, isNotNull);
      expect(a.msLeft, greaterThan(0));
    });

    test('T_73 a task whose deadline passed is closed and sent by itself',
        () async {
      final yesterday = DateTime.now()
          .subtract(const Duration(days: 1))
          .millisecondsSinceEpoch;
      await service.save(guestScope, challenge(dueAtMs: yesterday));

      final changed = await service.autoSubmitExpired(guestScope);

      expect(changed, isTrue);
      final a = (await service.loadFor(guestScope)).first;
      expect(a.timeIsOver, isTrue);
      expect(a.submitted, isTrue);
      expect(a.blocked, isTrue);
      expect(await service.openTasks(guestScope), isEmpty);
    });

    test('T_74 giving more time opens the task again', () async {
      final yesterday = DateTime.now()
          .subtract(const Duration(days: 1))
          .millisecondsSinceEpoch;
      await service.save(guestScope, challenge(dueAtMs: yesterday));
      await service.autoSubmitExpired(guestScope);

      await service.giveMoreTime(guestScope, 'a1', const Duration(days: 1));

      final a = (await service.loadFor(guestScope)).first;
      expect(a.timeIsOver, isFalse);
      expect(a.submitted, isFalse);
      expect(a.blocked, isFalse);
      expect(await service.openTasks(guestScope), hasLength(1));
    });

    test('T_75 a parent challenge with a 2 day limit shows the time left',
        () async {
      final inTwoDays = DateTime.now()
          .add(const Duration(days: 2))
          .millisecondsSinceEpoch;
      await service.save(guestScope,
          challenge(fromRole: 'Parent', dueAtMs: inTwoDays));

      final a = (await service.loadFor(guestScope)).first;
      expect(a.fromRole, 'Parent');
      expect(a.timeIsOver, isFalse);
      expect(a.msLeft, greaterThan(const Duration(days: 1).inMilliseconds));
      expect(a.msLeft,
          lessThanOrEqualTo(const Duration(days: 2).inMilliseconds));
    });

    test('T_76 a challenge with no time limit never closes by itself',
        () async {
      await service.save(guestScope, challenge()); // no dueAtMs
      final a = (await service.loadFor(guestScope)).first;
      expect(a.msLeft, isNull);
      expect(a.timeIsOver, isFalse);
      expect(await service.autoSubmitExpired(guestScope), isFalse);
    });
  });

  group('US_33 timed test', () {
    test('T_80 the test clock starts when the child opens it', () async {
      final test = challenge(
          id: 'x1', kind: AssignKind.test, fromRole: 'Teacher', testMinutes: 10);
      await service.save(guestScope, test);

      var a = (await service.loadFor(guestScope)).first;
      expect(a.startedAtMs, isNull, reason: 'not opened yet');
      expect(a.msLeft, isNull, reason: 'the clock has not started');

      await service.startIfTest(guestScope, a);

      a = (await service.loadFor(guestScope)).first;
      expect(a.startedAtMs, isNotNull);
      expect(a.msLeft, greaterThan(0));
      expect(a.timeIsOver, isFalse);
    });

    test('the clock does not restart when the test is opened again',
        () async {
      final test = challenge(
          id: 'x1', kind: AssignKind.test, fromRole: 'Teacher', testMinutes: 10);
      await service.save(guestScope, test);
      await service.startIfTest(guestScope, test);
      final firstStart = (await service.loadFor(guestScope)).first.startedAtMs;

      await service.startIfTest(
          guestScope, (await service.loadFor(guestScope)).first);

      expect((await service.loadFor(guestScope)).first.startedAtMs, firstStart);
    });

    test('T_78 when the time is over the test is locked and sent by itself',
        () async {
      final test = challenge(
          id: 'x1', kind: AssignKind.test, fromRole: 'Teacher', testMinutes: 10);
      // started 11 minutes ago, so the 10 minutes are gone
      test.startedAtMs = DateTime.now()
          .subtract(const Duration(minutes: 11))
          .millisecondsSinceEpoch;
      await service.save(guestScope, test);

      expect(await service.autoSubmitExpired(guestScope), isTrue);
      final a = (await service.loadFor(guestScope)).first;
      expect(a.timeIsOver, isTrue);
      expect(a.submitted, isTrue);
      expect(a.blocked, isTrue);
    });

    test('T_79 the mark and the answer key reach the child', () async {
      await service.save(guestScope, challenge());

      await service.grade(guestScope, 'a1',
          mark: 80, answerKey: 'APPLE, ANT', note: 'Make the A smaller.');

      final a = (await service.loadFor(guestScope)).first;
      expect(a.graded, isTrue);
      expect(a.grade, 80);
      expect(a.answerKey, 'APPLE, ANT');
      expect(a.note, 'Make the A smaller.');
    });
  });

  group('steps that must be done in order (US_23)', () {
    test('the second step stays locked until the first one is done',
        () async {
      await service.save(guestScope, challenge(inOrder: true));

      var a = (await service.loadFor(guestScope)).first;
      expect(a.isItemOpen(0), isTrue);
      expect(a.isItemOpen(1), isFalse);

      await service.markItemDone(guestScope, 'a1', 'word:APPLE');
      a = (await service.loadFor(guestScope)).first;
      expect(a.isItemOpen(1), isTrue);
    });
  });

  group('a step counts as done only when the child really passed it', () {
    test('a word step is passed once the word is saved', () async {
      const item = AssignItem(ItemKind.word, 'CAT');
      expect(await service.isItemPassed(guestScope, item), isFalse);

      await progress.saveWordDone('CAT');

      expect(await service.isItemPassed(guestScope, item), isTrue);
    });

    test('a letter step needs BOTH sides finished', () async {
      const item = AssignItem(ItemKind.letter, 'A');

      await progress.saveGuided('A', 3);
      expect(await service.isItemPassed(guestScope, item), isFalse,
          reason: 'the free-hand side is not done yet');

      await progress.saveFree('A', 85);
      expect(await service.isItemPassed(guestScope, item), isTrue);
    });

    test('a sentence step is passed once the sentence is saved', () async {
      const item = AssignItem(ItemKind.sentence, 's01');
      expect(await service.isItemPassed(guestScope, item), isFalse);

      await progress.saveSentenceDone('s01');

      expect(await service.isItemPassed(guestScope, item), isTrue);
    });
  });
}
