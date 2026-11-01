import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../services/sync_service.dart';

class SyncState extends Equatable {
  final bool loading;
  final bool syncing;
  final bool auto;
  final DateTime? lastSync;
  final SyncOutcome? lastOutcome;
  final String? message;
  final int messageTick;

  const SyncState({
    this.loading = true,
    this.syncing = false,
    this.auto = false,
    this.lastSync,
    this.lastOutcome,
    this.message,
    this.messageTick = 0,
  });

  SyncState copyWith({
    bool? loading,
    bool? syncing,
    bool? auto,
    DateTime? lastSync,
    SyncOutcome? lastOutcome,
    String? message,
    int? messageTick,
  }) =>
      SyncState(
        loading: loading ?? this.loading,
        syncing: syncing ?? this.syncing,
        auto: auto ?? this.auto,
        lastSync: lastSync ?? this.lastSync,
        lastOutcome: lastOutcome ?? this.lastOutcome,
        message: message ?? this.message,
        messageTick: messageTick ?? this.messageTick,
      );

  @override
  List<Object?> get props =>
      [loading, syncing, auto, lastSync, lastOutcome, message, messageTick];
}

/// Sync across devices (SRS FR_20 / US_27).
class SyncCubit extends Cubit<SyncState> {
  final SyncService _sync;

  SyncCubit({required SyncService sync})
      : _sync = sync,
        super(const SyncState());

  Future<void> load() async {
    emit(state.copyWith(
      loading: false,
      auto: await _sync.isAuto(),
      lastSync: await _sync.lastSync(),
    ));
  }

  Future<void> syncNow() async {
    emit(state.copyWith(syncing: true));
    final r = await _sync.syncNow();
    emit(state.copyWith(
      syncing: false,
      lastOutcome: r.outcome,
      lastSync: await _sync.lastSync(),
      message: r.message,
      messageTick: state.messageTick + 1,
    ));
  }

  Future<void> setAuto(bool on) async {
    await _sync.setAuto(on);
    emit(state.copyWith(auto: on));
    if (on) await syncNow();
  }
}
