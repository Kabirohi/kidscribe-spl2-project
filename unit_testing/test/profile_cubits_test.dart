// SRS US_6 and US_7 - the rules the screens follow when a grown-up adds
// a child or a class. Covers T_18 and T_22.

import 'package:flutter_test/flutter_test.dart';
import 'package:kidscribe/blocs/children/children_cubit.dart';
import 'package:kidscribe/blocs/classes/classes_cubit.dart';
import 'package:kidscribe/models/profile_models.dart';
import 'package:kidscribe/services/family_service.dart';
import 'package:kidscribe/services/progress_service.dart';
import 'package:kidscribe/services/report_service.dart';

import 'helpers.dart';

void main() {
  late FamilyService family;

  setUp(() async {
    await useEmptyStorage();
    family = FamilyService();
  });

  group('US_6 adding a child', () {
    test('T_18 an empty name saves nothing and shows a message', () async {
      final cubit = ChildrenCubit(family: family);
      await cubit.load();

      await cubit.saveChild(name: '   ', age: 5);

      expect(cubit.state.messageIsError, isTrue);
      expect(cubit.state.message, contains("child's name"));
      expect(await family.loadChildren(), isEmpty);
      await cubit.close();
    });

    test('an age that is not a number saves nothing', () async {
      final cubit = ChildrenCubit(family: family);
      await cubit.load();

      await cubit.saveChild(name: 'Sara', age: 0);

      expect(cubit.state.messageIsError, isTrue);
      expect(await family.loadChildren(), isEmpty);
      await cubit.close();
    });

    test('a good name and age saves the child and picks them', () async {
      final cubit = ChildrenCubit(family: family);
      await cubit.load();

      await cubit.saveChild(name: 'Sara', age: 5);

      expect(cubit.state.messageIsError, isFalse);
      expect(cubit.state.children.length, 1);
      // the first child added becomes the learner right away
      expect(cubit.state.activeId, isNotNull);
      await cubit.close();
    });
  });

  group('US_7 creating a class', () {
    test('T_22 an empty class name creates nothing and shows a message',
        () async {
      final cubit = ClassesCubit(family: family);
      await cubit.load();

      final made = await cubit.create('  ');

      expect(made, isFalse);
      expect(cubit.state.message?.isError, isTrue);
      expect(cubit.state.message?.text, contains('class name'));
      expect(await family.loadClasses(), isEmpty);
      await cubit.close();
    });

    test('a good class name creates the class', () async {
      final cubit = ClassesCubit(family: family);
      await cubit.load();

      final made = await cubit.create('Class A');

      expect(made, isTrue);
      expect(cubit.state.classes.length, 1);
      expect(cubit.state.classes.first.name, 'Class A');
      await cubit.close();
    });

    test('the same student cannot be added twice', () async {
      await family.saveClass(
          const SchoolClass(id: 'c1', name: 'Class A', students: ['Sara']));
      final cubit = ClassDetailCubit(
        classId: 'c1',
        family: family,
        progress: ProgressService(),
        reports: ReportService(),
      );
      await cubit.load();

      final added = await cubit.addStudent('sara'); // same name, small letters

      expect(added, isFalse);
      expect(cubit.state.message?.isError, isTrue);
      expect(cubit.state.schoolClass!.students.length, 1);
      await cubit.close();
    });
  });
}
