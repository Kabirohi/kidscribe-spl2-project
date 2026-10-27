/// The password rules for a new account (SRS FR_1 / US_3):
/// 8 or more characters, one capital letter, and one number.
///
/// The rules live here, in one place, so the sign up screen and the
/// unit tests always agree on what a good password is.
class PasswordRules {
  static const minLength = 8;

  static bool hasMinLength(String p) => p.length >= minLength;
  static bool hasCapital(String p) => p.contains(RegExp(r'[A-Z]'));
  static bool hasNumber(String p) => p.contains(RegExp(r'[0-9]'));

  /// The rule list shown on the sign up screen, ticking green as the
  /// user types.
  static List<(String, bool)> checklist(String p) => [
        ('At least $minLength characters', hasMinLength(p)),
        ('One capital letter (A-Z)', hasCapital(p)),
        ('One number (0-9)', hasNumber(p)),
      ];

  /// The error to show, or null when the password is fine.
  static String? validate(String? p) {
    if (p == null || p.isEmpty) return 'Please enter a password';
    if (!hasMinLength(p)) {
      return 'Password must be at least $minLength characters';
    }
    if (!hasCapital(p)) return 'Password needs one capital letter';
    if (!hasNumber(p)) return 'Password needs one number';
    return null;
  }

  /// The confirm box must match exactly.
  static String? validateConfirm(String? confirm, String password) =>
      confirm != password ? 'Passwords do not match' : null;

  static bool isValid(String p) => validate(p) == null;
}
