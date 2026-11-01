import 'package:flutter_bloc/flutter_bloc.dart';
import '../../services/auth_service.dart';
import 'auth_event.dart';
import 'auth_state.dart';

export 'auth_event.dart';
export 'auth_state.dart';

/// The BLoC for logging in (SRS FR_1, FR_2).
///
/// It sits between the screens and the AuthService repository:
///
///   Screen  --event-->  AuthBloc  --calls-->  AuthService (Firebase)
///   Screen  <--state--  AuthBloc
///
/// The screens hold no login rules at all; they only send events and
/// draw whatever state comes back.
class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthService _auth;

  AuthBloc({required AuthService auth})
      : _auth = auth,
        super(const AuthState()) {
    on<AuthStarted>(_onStarted);
    on<AuthLoginRequested>(_onLogin);
    on<AuthSignUpRequested>(_onSignUp);
    on<AuthLogoutRequested>(_onLogout);
    on<AuthErrorCleared>((event, emit) => emit(state.copyWith(clearError: true)));
  }

  Future<void> _onStarted(AuthStarted event, Emitter<AuthState> emit) async {
    final loggedIn = await _auth.isLoggedIn();
    if (!loggedIn) {
      emit(state.copyWith(
          status: AuthStatus.unauthenticated, clearUser: true));
      return;
    }
    final user = await _auth.getCurrentUser();
    emit(state.copyWith(status: AuthStatus.authenticated, user: user));
  }

  Future<void> _onLogin(
      AuthLoginRequested event, Emitter<AuthState> emit) async {
    emit(state.copyWith(submitting: true, clearError: true));
    final error = await _auth.signIn(
        email: event.email, password: event.password);
    if (error != null) {
      emit(state.copyWith(submitting: false, errorMessage: error));
      return;
    }
    final user = await _auth.getCurrentUser();
    emit(state.copyWith(
        submitting: false, status: AuthStatus.authenticated, user: user));
  }

  Future<void> _onSignUp(
      AuthSignUpRequested event, Emitter<AuthState> emit) async {
    emit(state.copyWith(submitting: true, clearError: true));
    final error = await _auth.signUp(
      email: event.email,
      password: event.password,
      name: event.name,
      role: event.role,
      school: event.school,
    );
    if (error != null) {
      emit(state.copyWith(submitting: false, errorMessage: error));
      return;
    }
    final user = await _auth.getCurrentUser();
    emit(state.copyWith(
        submitting: false, status: AuthStatus.authenticated, user: user));
  }

  Future<void> _onLogout(
      AuthLogoutRequested event, Emitter<AuthState> emit) async {
    await _auth.signOut();
    emit(const AuthState(status: AuthStatus.unauthenticated));
  }
}
