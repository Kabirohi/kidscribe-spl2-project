// SRS US_3 - the password rules on the sign up screen.
// Covers T_7, T_8, T_9, T_10, T_11.

import 'package:flutter_test/flutter_test.dart';
import 'package:kidscribe/services/password_rules.dart';

void main() {
  group('US_3 password rules', () {
    test('T_7 valid password accepted', () {
      expect(PasswordRules.validate('Kidscribe1'), isNull);
      expect(PasswordRules.isValid('Kidscribe1'), isTrue);
    });

    test('T_8 password too short is rejected', () {
      final error = PasswordRules.validate('Kid1');
      expect(error, isNotNull);
      expect(error, contains('at least 8 characters'));
    });

    test('T_9 password with no capital letter is rejected', () {
      final error = PasswordRules.validate('kidscribe1');
      expect(error, 'Password needs one capital letter');
    });

    test('T_10 password with no number is rejected', () {
      final error = PasswordRules.validate('Kidscribe');
      expect(error, 'Password needs one number');
    });

    test('T_11 confirm password that does not match is rejected', () {
      expect(PasswordRules.validateConfirm('Kidscribe2', 'Kidscribe1'),
          'Passwords do not match');
      // the same password is fine
      expect(PasswordRules.validateConfirm('Kidscribe1', 'Kidscribe1'), isNull);
    });

    test('empty password asks for a password', () {
      expect(PasswordRules.validate(''), 'Please enter a password');
      expect(PasswordRules.validate(null), 'Please enter a password');
    });

    test('the checklist ticks each rule on its own', () {
      // 'kid' breaks all three rules
      expect(PasswordRules.checklist('kid').map((r) => r.$2).toList(),
          [false, false, false]);
      // 'Kidscribe1' keeps all three
      expect(PasswordRules.checklist('Kidscribe1').map((r) => r.$2).toList(),
          [true, true, true]);
    });
  });
}
