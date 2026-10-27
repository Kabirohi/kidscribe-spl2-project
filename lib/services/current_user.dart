import 'package:firebase_auth/firebase_auth.dart';

/// Who is logged in right now.
///
/// Firebase only answers after `Firebase.initializeApp()` has run. In a
/// unit test it has not, and asking would throw. So we catch that and
/// answer `null`, which lets every service be tested on its own without
/// a real Firebase project.
String? currentUidOrNull() {
  try {
    return FirebaseAuth.instance.currentUser?.uid;
  } catch (_) {
    return null; // Firebase is not ready (for example inside a test)
  }
}

/// The id used to keep one account's data apart from another's.
/// 'guest' is used when nobody is logged in.
String currentUid() => currentUidOrNull() ?? 'guest';
