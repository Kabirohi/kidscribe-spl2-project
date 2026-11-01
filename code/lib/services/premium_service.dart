import 'package:shared_preferences/shared_preferences.dart';
import 'current_user.dart';

/// The result of a (demo) payment.
class PaymentResult {
  final bool success;
  final String message;
  const PaymentResult(this.success, this.message);
}

/// The paid parent plan (SRS FR_21 / US_28, US_29).
///
/// IMPORTANT: this is a DEMO payment for the student project. No money
/// moves and no card details are asked for or stored. A real app would
/// use Google Play Billing here; everything else (locking and unlocking
/// the premium features) would stay exactly the same.
class PremiumService {
  String get _uid => currentUid();
  String get _key => 'premium_$_uid';
  String get _sinceKey => 'premium_since_$_uid';

  static const priceText = '৳ 199 / month (demo)';

  /// What premium unlocks — shown on the plan screen (SRS US_28).
  static const features = [
    'Advanced reports with detailed charts for every letter',
    'Weak letters found for you, with what to practice next',
    'Custom timed tests (no help) for your child',
  ];

  Future<bool> isPremium() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_key) ?? false;
  }

  Future<DateTime?> since() async {
    final prefs = await SharedPreferences.getInstance();
    final ms = prefs.getInt(_sinceKey);
    return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
  }

  /// Demo checkout. [simulateFailure] lets you show what happens when a
  /// payment does not go through (SRS T_66): premium stays locked.
  Future<PaymentResult> buy({bool simulateFailure = false}) async {
    await Future.delayed(const Duration(seconds: 2)); // "talking to the bank"
    if (simulateFailure) {
      return const PaymentResult(false,
          'The payment did not go through, so Premium is still locked. '
          'Nothing was charged. Please try again.');
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, true);
    await prefs.setInt(_sinceKey, DateTime.now().millisecondsSinceEpoch);
    return const PaymentResult(
        true, 'Payment done! Premium is now open. Thank you!');
  }

  /// Ends the plan (handy for testing the locked state again).
  Future<void> cancel() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, false);
    await prefs.remove(_sinceKey);
  }
}
