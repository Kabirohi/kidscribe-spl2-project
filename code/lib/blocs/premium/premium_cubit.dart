import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../services/premium_service.dart';

class PremiumState extends Equatable {
  final bool loading;
  final bool isPremium;
  final DateTime? since;
  final bool paying;
  final String? message;
  final bool messageIsError;
  final int messageTick;

  const PremiumState({
    this.loading = true,
    this.isPremium = false,
    this.since,
    this.paying = false,
    this.message,
    this.messageIsError = false,
    this.messageTick = 0,
  });

  PremiumState copyWith({
    bool? loading,
    bool? isPremium,
    DateTime? since,
    bool clearSince = false,
    bool? paying,
    String? message,
    bool? messageIsError,
    int? messageTick,
  }) =>
      PremiumState(
        loading: loading ?? this.loading,
        isPremium: isPremium ?? this.isPremium,
        since: clearSince ? null : (since ?? this.since),
        paying: paying ?? this.paying,
        message: message ?? this.message,
        messageIsError: messageIsError ?? this.messageIsError,
        messageTick: messageTick ?? this.messageTick,
      );

  @override
  List<Object?> get props =>
      [loading, isPremium, since, paying, message, messageIsError, messageTick];
}

/// The parent plan: see it, buy it (demo), and see whether it is active
/// (SRS FR_21 / US_28).
class PremiumCubit extends Cubit<PremiumState> {
  final PremiumService _premium;

  PremiumCubit({required PremiumService premium})
      : _premium = premium,
        super(const PremiumState());

  Future<void> load() async {
    emit(state.copyWith(
      loading: false,
      isPremium: await _premium.isPremium(),
      since: await _premium.since(),
    ));
  }

  Future<void> buy({bool simulateFailure = false}) async {
    emit(state.copyWith(paying: true));
    final r = await _premium.buy(simulateFailure: simulateFailure);
    emit(state.copyWith(
      paying: false,
      isPremium: await _premium.isPremium(),
      since: await _premium.since(),
      message: r.message,
      messageIsError: !r.success,
      messageTick: state.messageTick + 1,
    ));
  }

  Future<void> cancel() async {
    await _premium.cancel();
    emit(state.copyWith(
      isPremium: false,
      clearSince: true,
      message: 'Premium was cancelled.',
      messageIsError: false,
      messageTick: state.messageTick + 1,
    ));
  }
}
