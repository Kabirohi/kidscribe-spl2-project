import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';

/// Handles login using **Firebase Authentication**.
///
/// WHY FIREBASE = TOKENS (what your teacher meant):
/// When a user signs in, Firebase gives the app a signed **ID token (a JWT)**
/// and a refresh token. Firebase stores them on the device, attaches the ID
/// token to backend requests, and refreshes it automatically (~every hour).
/// We never store or check the password ourselves — Firebase's servers do that
/// and hand back a token. That is exactly the industry token-based flow.
///
/// Firebase Auth only stores email + password (+ an optional displayName), so:
///   - the user's NAME is saved into the Firebase profile (displayName)
///   - the user's ROLE is cached locally with SharedPreferences (keyed by uid)
class AuthService {
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;

  // ===== SIGN UP =====
  Future<String?> signUp({
    required String email,
    required String password,
    required String name,
    required String role,
    String school = '',
  }) async {
    // SRS password rules (FR_1 / US_3): 8+ characters, 1 capital, 1 number.
    if (password.length < 8) {
      return "Password must be at least 8 characters.";
    }
    if (!password.contains(RegExp(r'[A-Z]'))) {
      return "Password needs one capital letter.";
    }
    if (!password.contains(RegExp(r'[0-9]'))) {
      return "Password needs one number.";
    }
    // SRS US_2: a teacher account requires a school or institute name.
    if (role == 'Teacher' && school.trim().isEmpty) {
      return "Please enter your school or institute name.";
    }

    try {
      // Firebase creates the account AND signs the user in (issuing tokens).
      final credential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final user = credential.user;
      if (user != null) {
        await user.updateDisplayName(name.trim()); // store the name on Firebase
        await _saveRole(user.uid, role);           // store the role locally
        if (school.trim().isNotEmpty) {
          await _saveSchool(user.uid, school.trim()); // teacher's school (local)
        }
      }

      return null; // null = success
    } on FirebaseAuthException catch (e) {
      return _messageFor(e);
    } catch (_) {
      return "Something went wrong. Please try again.";
    }
  }

  // ===== SIGN IN =====
  Future<String?> signIn({
    required String email,
    required String password,
  }) async {
    try {
      // On success Firebase saves the ID token + refresh token for us.
      await _firebaseAuth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      return null;
    } on FirebaseAuthException catch (e) {
      return _messageFor(e);
    } catch (_) {
      return "Something went wrong. Please try again.";
    }
  }

  // ===== SIGN OUT =====
  Future<void> signOut() async {
    await _firebaseAuth.signOut(); // clears the saved tokens
  }

  // ===== CHECK IF LOGGED IN =====
  Future<bool> isLoggedIn() async {
    // currentUser is non-null when a valid (auto-refreshed) token exists.
    return _firebaseAuth.currentUser != null;
  }

  // ===== GET CURRENT USER =====
  Future<UserModel?> getCurrentUser() async {
    final user = _firebaseAuth.currentUser;
    if (user == null) return null;

    final role = await _getRole(user.uid);
    return UserModel(
      email: user.email ?? '',
      password: '', // Firebase manages the password; never kept in the app
      name: user.displayName ?? 'Friend',
      role: role,
    );
  }

  // ===== GET THE ID TOKEN (the JWT) =====
  // Handy if you want to show the token in a demo, or send it to a backend.
  Future<String?> getIdToken() async {
    return await _firebaseAuth.currentUser?.getIdToken();
  }

  // ===== HELPER: store/read the role locally (per user) =====
  Future<void> _saveRole(String uid, String role) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('role_$uid', role);
  }

  Future<String> _getRole(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('role_$uid') ?? 'Parent';
  }

  // ===== HELPER: store/read the teacher's school (per user) =====
  Future<void> _saveSchool(String uid, String school) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('school_$uid', school);
  }

  Future<String?> getSchool() async {
    final uid = _firebaseAuth.currentUser?.uid;
    if (uid == null) return null;
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('school_$uid');
  }

  // ===== HELPER: turn Firebase error codes into kid-friendly messages =====
  String _messageFor(FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use':
        return "An account already exists with this email.";
      case 'invalid-email':
        return "Please enter a valid email.";
      case 'weak-password':
        return "Password must be at least 8 characters.";
      case 'user-not-found':
        return "No account found with this email.";
      case 'wrong-password':
      case 'invalid-credential':
        return "Wrong email or password. Try again!";
      case 'network-request-failed':
        return "No internet connection. Please check and retry.";
      case 'too-many-requests':
        return "Too many attempts. Please wait and try again.";
      default:
        return e.message ?? "Login failed. Please try again.";
    }
  }
}
