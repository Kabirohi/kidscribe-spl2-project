// SRS US_23 and US_33 - what the child sees in "My Tasks", and the
// test mode that hides all the help.
// Covers T_77, and the rules for opening a step.

import 'package:flutter_test/flutter_test.dart';
import 'package:kidscribe/blocs/tasks/my_tasks_cubit.dart';
import 'package:kidscribe/models/assignment_models.dart';
import 'package:kidscribe/services/assignment_service.dart';
import 'package:kidscribe/services/custom_word_service.dart';

import 'helpers.dart';

void main() {
  late AssignmentService service;
  late MyTasksCubit cubit;

  setUp(() async {
    await useEmptyStorage();
    service = AssignmentService();
    cubit = MyTasksCubit(assignments: service, toys: CustomWordService());
  });

  tearDown(() async => cubit.close());

  Assignment task({
    AssignKind kind = AssignKind.practice,
    bool inOrder = false,
    int? testMinutes,
    int? dueAtMs,
  }) =>
      Assignment(
        id: 'a1',
        title: kind == AssignKind.test ? 'Spelling test' : 'Homework',
        kind: kind,
        fromRole: 'Teacher',
        items: const [
          AssignItem(ItemKind.letter, 'A'),
          AssignItem(ItemKind.letter, 'B'),
        ],
        inOrder: inOrder,
        testMinutes: testMinutes,
        dueAtMs: dueAtMs,
      );

  test('T_77 opening a test turns on test mode, which hides the help',
      () async {
    await service.save(guestScope, task(kind: AssignKind.test, testMinutes: 10));
    await cubit.load();

    final result = await cubit.tryOpen(cubit.state.tasks.first, 0);

    expect(result, isA<OpenStep>());
    // exam == true is what hides the video, the guide and the numbers.
    expect((result as OpenStep).exam, isTrue);
  });

  test('normal homework keeps all the help on screen', () async {
    await service.save(guestScope, task());
    await cubit.load();

    final result = await cubit.tryOpen(cubit.state.tasks.first, 0);

    expect((result as OpenStep).exam, isFalse);
  });

  test('opening a test for the first time starts its clock', () async {
    await service.save(guestScope, task(kind: AssignKind.test, testMinutes: 10));
    await cubit.load();
    expect(cubit.state.tasks.first.startedAtMs, isNull);

    await cubit.tryOpen(cubit.state.tasks.first, 0);

    expect(cubit.state.tasks.first.startedAtMs, isNotNull);
  });

  test('a locked step cannot be opened and the child is told why', () async {
    await service.save(guestScope, task(inOrder: true));
    await cubit.load();

    final result = await cubit.tryOpen(cubit.state.tasks.first, 1);

    expect(result, isA<OpenRefused>());
    expect(cubit.state.message?.text, contains('Finish the step before'));
  });

  test('a task whose time is over cannot be opened', () async {
    final yesterday = DateTime.now()
        .subtract(const Duration(days: 1))
        .millisecondsSinceEpoch;
    await service.save(guestScope, task(dueAtMs: yesterday));
    await cubit.load(); // load() closes the task by itself

    final result = await cubit.tryOpen(cubit.state.tasks.first, 0);

    expect(result, isA<OpenRefused>());
    expect(cubit.state.message?.text, isNotEmpty);
  });

  test('the child sees the feedback written about them', () async {
    await service.addFeedback(
      guestScope,
      FeedbackNote(
        id: 'n1',
        target: 'profile',
        text: 'Lovely round letters!',
        fromRole: 'Teacher',
        atMs: DateTime.now().millisecondsSinceEpoch,
      ),
    );

    await cubit.load();

    expect(cubit.state.notes.length, 1);
    expect(cubit.state.notes.first.text, 'Lovely round letters!');
  });
}
