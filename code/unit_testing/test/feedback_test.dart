// SRS US_30 - written feedback from a teacher or a parent.
// Covers T_69, T_70, T_71.

import 'package:flutter_test/flutter_test.dart';
import 'package:kidscribe/blocs/assign/manage_learner_cubit.dart';
import 'package:kidscribe/services/assignment_service.dart';
import 'package:kidscribe/services/progress_service.dart';

import 'helpers.dart';

void main() {
  late AssignmentService service;
  late ProgressService progress;
  late ManageLearnerCubit cubit;

  setUp(() async {
    await useEmptyStorage();
    service = AssignmentService();
    progress = ProgressService();
    cubit = ManageLearnerCubit(
      scope: guestScope,
      fromRole: 'Teacher',
      assignments: service,
      progress: progress,
    );
  });

  tearDown(() async => cubit.close());

  test('T_69 feedback on the whole profile is saved and shown', () async {
    await cubit.load();

    final saved =
        await cubit.addFeedback(target: 'profile', text: 'Great work on A');

    expect(saved, isTrue);
    final notes = await service.loadFeedbackFor(guestScope);
    expect(notes.length, 1);
    expect(notes.first.text, 'Great work on A');
    expect(notes.first.isProfile, isTrue);
    expect(notes.first.fromRole, 'Teacher');
  });

  test('T_70 feedback can be written on one finished letter', () async {
    // The letter must be finished before feedback can be left on it.
    await progress.saveGuided('A', 3);
    await progress.saveFree('A', 90);
    await cubit.load();

    expect(cubit.state.finishedLetters, contains('A'));

    final saved = await cubit.addFeedback(
        target: 'letter:A', text: 'Start the A at the top.');

    expect(saved, isTrue);
    final forLetter = await service.feedbackForItem(guestScope, 'letter:A');
    expect(forLetter.length, 1);
    expect(forLetter.first.isProfile, isFalse);
  });

  test('T_71 an empty feedback box saves nothing and shows a message',
      () async {
    await cubit.load();

    final saved = await cubit.addFeedback(target: 'profile', text: '   ');

    expect(saved, isFalse);
    expect(cubit.state.message?.isError, isTrue);
    expect(cubit.state.message?.text, contains('write your feedback'));
    expect(await service.loadFeedbackFor(guestScope), isEmpty);
  });

  test('feedback can be removed again', () async {
    await cubit.load();
    await cubit.addFeedback(target: 'profile', text: 'Well done');
    final note = (await service.loadFeedbackFor(guestScope)).first;

    await cubit.deleteFeedback(note);

    expect(await service.loadFeedbackFor(guestScope), isEmpty);
  });

  test('a letter that is not finished is not offered for feedback', () async {
    await progress.saveGuided('A', 2); // only one side done
    await cubit.load();
    expect(cubit.state.finishedLetters, isEmpty);
  });
}
