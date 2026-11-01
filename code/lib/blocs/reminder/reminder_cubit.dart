import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../services/assignment_service.dart';
import '../../services/reminder_service.dart';

class ReminderState extends Equatable {
  final bool loading;
  final bool on;
  final int hour;
  final int minute;
  final int waiting; // tasks waiting for the learner

  /// A one-time message for the screen to show (a snack bar).
  final String? message;
  final bool messageIsError;
  final int messageTick;

  const ReminderState({
    this.loading = true,
    this.on = false,
    this.hour = 18,
    this.minute = 0,
    this.waiting = 0,
    this.message,
    this.messageIsError = false,
    this.messageTick = 0,
  });

  ReminderState copyWith({
    bool? on,
    int? hour,
    int? minute,
    String? message,
    bool? messageIsError,
  }) =>
      ReminderState(
        loading: false,
        on: on ?? this.on,
        hour: hour ?? this.hour,
        minute: minute ?? this.minute,
        waiting: waiting,
        message: message ?? this.message,
        messageIsError: messageIsError ?? false,
        messageTick: message == null ? messageTick : messageTick + 1,
      );

  @override
  List<Object?> get props =>
      [loading, on, hour, minute, waiting, message, messageTick];
}

/// The daily practice reminder (SRS FR_15 / US_19).
class ReminderCubit extends Cubit<ReminderState> {
  final AssignmentService _assignments;

  ReminderCubit({required AssignmentService assignments})
      : _assignments = assignments,
        super(const ReminderState());

  Future<void> load() async {
    final on = await ReminderService.isOn();
    final (h, m) = await ReminderService.time();
    final scope = await _assignments.currentScope();
    final open = await _assignments.openTasks(scope);
    if (isClosed) return;
    emit(ReminderState(
        loading: false, on: on, hour: h, minute: m, waiting: open.length));
  }

  /// Turns the reminder on/off or changes its time. [timeText] is the
  /// time already written the way the phone shows it (e.g. "6:00 PM").
  Future<void> apply({bool? on, int? hour, int? minute, String? timeText}) async {
    final newOn = on ?? state.on;
    final h = hour ?? state.hour;
    final m = minute ?? state.minute;
    if (newOn && !await ReminderService.askPermission()) {
      emit(state.copyWith(
          message: 'Please allow notifications for this app first',
          messageIsError: true));
      return;
    }
    await ReminderService.setDaily(on: newOn, hour: h, minute: m);
    if (isClosed) return;
    emit(state.copyWith(
      on: newOn,
      hour: h,
      minute: m,
      message: newOn
          ? 'Reminder set for ${timeText ?? '$h:${m.toString().padLeft(2, '0')}'} every day'
          : 'Reminder turned off. Nothing will be sent.',
    ));
  }

  Future<void> remindAboutTasks() async {
    await ReminderService.askPermission();
    await ReminderService.showTaskWaiting(state.waiting);
    if (!isClosed) emit(state.copyWith(message: 'Alert sent'));
  }

  Future<void> showSample() async {
    await ReminderService.askPermission();
    await ReminderService.showNow();
    if (!isClosed) {
      emit(state.copyWith(message: 'Look at the top of your screen'));
    }
  }
}
