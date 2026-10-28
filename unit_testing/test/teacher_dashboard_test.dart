// SRS US_22 and US_23 - the teacher's class view and giving tasks.
// Covers T_52, T_53, T_54, T_51, T_56.

import 'package:flutter_test/flutter_test.dart';
import 'package:kidscribe/blocs/assign/assign_cubit.dart';
import 'package:kidscribe/blocs/classes/classes_cubit.dart';
import 'package:kidscribe/data/trace_templates.dart';
import 'package:kidscribe/models/assignment_models.dart';
import 'package:kidscribe/models/profile_models.dart';
import 'package:kidscribe/services/assignment_service.dart';
import 'package:kidscribe/services/custom_word_service.dart';
import 'package:kidscribe/services/family_service.dart';
import 'package:kidscribe/services/premium_service.dart';
import 'package:kidscribe/services/progress_service.dart';
import 'package:kidscribe/services/report_service.dart';

import 'helpers.dart';

void main() {
  late FamilyService family;
  late ProgressService progress;

  setUp(() async {
    await useEmptyStorage();
    family = FamilyService();
    progress = ProgressService();
  });

  /// Finishes [count] letters for the student the teacher picked.
  Future<void> giveLetters(String scope, String label, int count) async {
    await family.setActiveStudent(scope, label);
    for (var i = 0; i < count; i++) {
      final glyph = allLetterItems[i].glyph;
      await progress.saveGuided(glyph, 3);
      await progress.saveFree(glyph, 90);
    }
    await family.setActiveStudent(null, null);
  }

  Future<ClassDetailCubit> openClass() async {
    final cubit = ClassDetailCubit(
      classId: 'c1',
      family: family,
      progress: progress,
      reports: ReportService(),
    );
    await cubit.load();
    return cubit;
  }

  group('US_22 the class view', () {
    setUp(() async {
      await family.saveClass(const SchoolClass(
          id: 'c1', name: 'Class A', students: ['Sara', 'Rafi', 'Nadia']));
    });

    test('T_54 a student who has not started is shown as "not started"',
        () async {
      final cubit = await openClass();

      expect(cubit.state.statusFor('Nadia'), StudentStatus.notStarted);
      await cubit.close();
    });

    test('T_52 a student who is behind the class is marked', () async {
      // Sara is doing well, Rafi is far behind.
      await giveLetters(family.studentScope('c1', 'Sara'), 'Sara', 10);
      await giveLetters(family.studentScope('c1', 'Rafi'), 'Rafi', 1);

      final cubit = await openClass();

      expect(cubit.state.statusFor('Sara'), StudentStatus.onTrack);
      expect(cubit.state.statusFor('Rafi'), StudentStatus.needsHelp);
      await cubit.close();
    });

    test('T_53 the list updates after the student practises more', () async {
      await giveLetters(family.studentScope('c1', 'Sara'), 'Sara', 10);
      await giveLetters(family.studentScope('c1', 'Rafi'), 'Rafi', 1);

      var cubit = await openClass();
      expect(cubit.state.statusFor('Rafi'), StudentStatus.needsHelp);
      expect(cubit.state.summaries['Rafi']!.lettersDone, 1);
      await cubit.close();

      // Rafi practises and catches up.
      await giveLetters(family.studentScope('c1', 'Rafi'), 'Rafi', 9);

      cubit = await openClass();
      expect(cubit.state.summaries['Rafi']!.lettersDone, 9);
      expect(cubit.state.statusFor('Rafi'), StudentStatus.onTrack);
      await cubit.close();
    });

    test('classroom practice mode picks one student at a time', () async {
      final cubit = await openClass();

      await cubit.togglePractice('Sara');
      expect(cubit.state.activeScope, family.studentScope('c1', 'Sara'));

      await cubit.togglePractice('Sara'); // tapping again stops it
      expect(cubit.state.activeScope, isNull);
      await cubit.close();
    });

    test('removing the practising student also stops practice mode',
        () async {
      final cubit = await openClass();
      await cubit.togglePractice('Sara');

      await cubit.removeStudent('Sara');

      expect(cubit.state.activeScope, isNull);
      expect(cubit.state.schoolClass!.students, isNot(contains('Sara')));
      await cubit.close();
    });
  });

  group('giving a task with no goal', () {
    AssignCubit makeCubit(String role) => AssignCubit(
          scope: guestScope,
          fromRole: role,
          assignments: AssignmentService(),
          premium: PremiumService(),
          toys: CustomWordService(),
        );

    test('T_56 a teacher task with no goal is not sent', () async {
      final cubit = makeCubit('Teacher');
      await cubit.load();

      await cubit.save('Homework'); // nothing picked

      expect(cubit.state.saved, isFalse);
      expect(cubit.state.message?.isError, isTrue);
      expect(cubit.state.message?.text, contains('at least one thing'));
      expect(await AssignmentService().loadFor(guestScope), isEmpty);
      await cubit.close();
    });

    test('T_51 a parent challenge with no goal is not created', () async {
      final cubit = makeCubit('Parent');
      await cubit.load();

      await cubit.save('Writing challenge');

      expect(cubit.state.saved, isFalse);
      expect(await AssignmentService().loadFor(guestScope), isEmpty);
      await cubit.close();
    });

    test('a task with no name is not created', () async {
      final cubit = makeCubit('Teacher');
      await cubit.load();
      cubit.toggleLetter('A');

      await cubit.save('   ');

      expect(cubit.state.saved, isFalse);
      expect(cubit.state.message?.text, contains('name for the task'));
      await cubit.close();
    });

    test('a task with a name and a goal is created', () async {
      final cubit = makeCubit('Teacher');
      await cubit.load();
      cubit.toggleLetter('A');
      cubit.toggleWord('CAT');

      await cubit.save('Homework');

      expect(cubit.state.saved, isTrue);
      final saved = await AssignmentService().loadFor(guestScope);
      expect(saved.length, 1);
      expect(saved.first.items.length, 2);
      await cubit.close();
    });

    test('a timed test is for teachers, and for parents only with Premium',
        () async {
      // A parent without Premium cannot pick a test.
      final parent = makeCubit('Parent');
      await parent.load();
      parent.setKind(AssignKind.test);
      expect(parent.state.kind, AssignKind.practice);
      expect(parent.state.message?.text, contains('Premium'));
      await parent.close();

      // A teacher can.
      final teacher = makeCubit('Teacher');
      await teacher.load();
      teacher.setKind(AssignKind.test);
      expect(teacher.state.kind, AssignKind.test);
      await teacher.close();

      // And so can a parent who bought Premium.
      await PremiumService().buy();
      final premiumParent = makeCubit('Parent');
      await premiumParent.load();
      premiumParent.setKind(AssignKind.test);
      expect(premiumParent.state.kind, AssignKind.test);
      await premiumParent.close();
    });
  });
}
