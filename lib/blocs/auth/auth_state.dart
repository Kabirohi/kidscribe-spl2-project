import 'package:equatable/equatable.dart';
import '../../models/user_model.dart';

/// Where the login stands right now.
enum AuthStatus {
  unknown,        // the app just opened, we are still checking
  authenticated,  // somebody is logged in
  unauthenticated // nobody is logged in
}

/// Everything the login screens need to draw themselves.
class AuthState extends Equatable {
  final AuthStatus status;
  final UserModel? user;
  final bool submitting;   // true while we wait for Firebase
  final String? errorMessage;

  const AuthState({
    this.status = AuthStatus.unknown,
    this.user,
    this.submitting = false,
    this.errorMessage,
  });

  AuthState copyWith({
    AuthStatus? status,
    UserModel? user,
    bool? submitting,
    String? errorMessage,
    bool clearError = false,
    bool clearUser = false,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: clearUser ? null : (user ?? this.user),
      submitting: submitting ?? this.submitting,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [status, user?.email, user?.role, user?.name,
        submitting, errorMessage];
}
