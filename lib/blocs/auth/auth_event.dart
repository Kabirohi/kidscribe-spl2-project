import 'package:equatable/equatable.dart';

/// Things the user can DO about logging in.
/// The screen sends one of these into AuthBloc; it never calls the
/// repository itself.
abstract class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => [];
}

/// Sent when the app opens: is somebody already logged in?
class AuthStarted extends AuthEvent {
  const AuthStarted();
}

class AuthLoginRequested extends AuthEvent {
  final String email;
  final String password;

  const AuthLoginRequested({required this.email, required this.password});

  @override
  List<Object?> get props => [email, password];
}

class AuthSignUpRequested extends AuthEvent {
  final String email;
  final String password;
  final String name;
  final String role;
  final String school;

  const AuthSignUpRequested({
    required this.email,
    required this.password,
    required this.name,
    required this.role,
    this.school = '',
  });

  @override
  List<Object?> get props => [email, password, name, role, school];
}

class AuthLogoutRequested extends AuthEvent {
  const AuthLogoutRequested();
}

/// Clears the red error message after the screen has shown it.
class AuthErrorCleared extends AuthEvent {
  const AuthErrorCleared();
}
