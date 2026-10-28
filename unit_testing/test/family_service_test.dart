// SRS US_6 and US_7 - child profiles and classes.
// Covers T_17, T_19, T_20, T_21.

import 'package:flutter_test/flutter_test.dart';
import 'package:kidscribe/models/profile_models.dart';
import 'package:kidscribe/services/family_service.dart';

import 'helpers.dart';

void main() {
  late FamilyService family;

  setUp(() async {
    await useEmptyStorage();
    family = FamilyService();
  });

  group('US_6 child profiles', () {
    test('T_17 a child profile is saved and shown in the list', () async {
      await family.saveChild(
          const ChildProfile(id: '1', name: 'Sara', age: 5));

      final children = await family.loadChildren();
      expect(children.length, 1);
      expect(children.first.name, 'Sara');
      expect(children.first.age, 5);
    });

    test('T_19 a profile can be removed from the list', () async {
      await family.saveChild(const ChildProfile(id: '1', name: 'Sara', age: 5));
      await family.saveChild(const ChildProfile(id: '2', name: 'Rafi', age: 6));

      await family.deleteChild('1');

      final left = await family.loadChildren();
      expect(left.length, 1);
      expect(left.first.name, 'Rafi');
    });

    test('more than one child can be added', () async {
      await family.saveChild(const ChildProfile(id: '1', name: 'Sara', age: 5));
      await family.saveChild(const ChildProfile(id: '2', name: 'Rafi', age: 6));
      expect((await family.loadChildren()).length, 2);
    });

    test('a profile can be edited', () async {
      await family.saveChild(const ChildProfile(id: '1', name: 'Sara', age: 5));
      await family.saveChild(const ChildProfile(id: '1', name: 'Sara', age: 6));

      final children = await family.loadChildren();
      expect(children.length, 1, reason: 'editing must not add a second row');
      expect(children.first.age, 6);
    });

    test('removing the learning child clears who is learning', () async {
      await family.saveChild(const ChildProfile(id: '1', name: 'Sara', age: 5));
      await family.setActiveChild('1');
      expect(await family.getActiveChildId(), '1');

      await family.deleteChild('1');
      expect(await family.getActiveChildId(), isNull);
    });
  });

  group('US_7 classes and students', () {
    test('T_20 a student shows in the class list', () async {
      await family.saveClass(
          const SchoolClass(id: 'c1', name: 'Class A', students: ['Sara']));

      final classes = await family.loadClasses();
      expect(classes.length, 1);
      expect(classes.first.name, 'Class A');
      expect(classes.first.students, ['Sara']);
    });

    test('T_21 a student can be removed from the class', () async {
      await family.saveClass(const SchoolClass(
          id: 'c1', name: 'Class A', students: ['Sara', 'Rafi']));

      await family.saveClass(
          const SchoolClass(id: 'c1', name: 'Class A', students: ['Rafi']));

      final classes = await family.loadClasses();
      expect(classes.first.students, ['Rafi']);
    });

    test('each student gets their own storage scope', () async {
      final sara = family.studentScope('c1', 'Sara');
      final rafi = family.studentScope('c1', 'Rafi');
      expect(sara, isNot(rafi));
      // a space in the name must not break the scope
      expect(family.studentScope('c1', 'Abu  Sayed'), contains('Abu_Sayed'));
    });

    test('classroom practice mode remembers who is writing', () async {
      await family.setActiveStudent(
          family.studentScope('c1', 'Sara'), 'Sara (Class A)');
      expect(await family.getActiveStudentLabel(), 'Sara (Class A)');

      await family.setActiveStudent(null, null);
      expect(await family.getActiveStudentScope(), isNull);
      expect(await family.getActiveStudentLabel(), isNull);
    });
  });
}
