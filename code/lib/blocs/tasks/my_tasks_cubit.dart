import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../models/assignment_models.dart';
import '../../services/assignment_service.dart';
import '../../services/custom_word_service.dart';
import '../common/ui_message.dart';

class MyTasksState extends Equatable {
  final bool loading;
  final List<Assignment> tasks; // newest first
  final List<FeedbackNote> notes;
  final List<CustomWord> toyWords;
  final int clock; // goes up every second so the countdown redraws
  final UiMessage? message;

  const MyTasksState({
    this.loading = true,
    this.tasks = const [],
    this.notes = const [],
    this.toyWords = const [],
    this.clock = 0,
    this.message,
  });

  MyTasksState copyWith({int? clock, UiMessage? message}) => MyTasksState(
        loading: loading,
        tasks: tasks,
        notes: notes,
        toyWords: toyWords,
        clock: clock ?? this.clock,
        message: message ?? this.message,
      );

  @override
  List<Object?> get props => [
        loading,
        [
          for (final t in tasks)
            '${t.id}:${t.doneCount}:${t.submitted}:${t.graded}:${t.startedAtMs}:${t.dueAtMs}'
        ],
        notes.length,
        toyWords.length,
        clock,
        message,
      ];
}

/// What can happen when the child taps a step.
sealed class OpenResult {
  const OpenResult();
}

/// The step may be done now: open this screen.
class OpenStep extends OpenResult {
  final AssignItem item;
  final bool exam;
  const OpenStep(this.item, this.exam);
}

/// The step may not be opened (the reason was already shown).
class OpenRefused extends OpenResult {
  const OpenRefused();
}

/// The child's tasks and the feedback about their work.
///  - steps open in order when the grown-up asked for that (US_23)
///  - a task is closed when its time is over (US_31, US_32)
///  - a test hides all help and is sent by itself at the end (US_33)
///  - written feedback is shown to the child (US_30)
class MyTasksCubit extends Cubit<MyTasksState> {
  final AssignmentService _service;
  final CustomWordService _toys;
  String _scope = '';
  Timer? _ticker;
  int _tick = 0;

  MyTasksCubit({
    required AssignmentService assignments,
    required CustomWordService toys,
  })  : _service = assignments,
        _toys = toys,
        super(const MyTasksState()) {
    // Tick every second so the countdown moves and the clock can send a
    // test by itself the moment its time is over.
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _onTick());
  }

  Future<void> load() async {
    _scope = await _service.currentScope();
    await _service.autoSubmitExpired(_scope);
    final tasks = await _service.loadFor(_scope);
    final notes = await _service.loadFeedbackFor(_scope);
    final toys = await _toys.load();
    if (isClosed) return;
    emit(MyTasksState(
      loading: false,
      tasks: tasks.reversed.toList(),
      notes: notes,
      toyWords: toys,
      clock: state.clock,
      message: state.message,
    ));
  }

  void _say(String text, {bool error = false}) =>
      emit(state.copyWith(message: UiMessage(text, isError: error, tick: ++_tick)));

  Future<void> _onTick() async {
    if (isClosed || _scope.isEmpty) return;
    final running = state.tasks.any((a) => !a.submitted && a.endsAtMs != null);
    if (!running) return;
    if (state.tasks.any((a) => !a.submitted && a.timeIsOver)) {
      await _service.autoSubmitExpired(_scope);
      await load();
      if (!isClosed) {
        _say('Time is over! Your work was sent.', error: true);
      }
    } else {
      emit(state.copyWith(clock: state.clock + 1));
    }
  }

  /// Checks the rules before a step is opened, and starts a test clock
  /// the first time.
  Future<OpenResult> tryOpen(Assignment a, int index) async {
    if (a.blocked) {
      _say(a.submitted
          ? 'This one is finished and already sent!'
          : 'The time for this task is over. Ask for more time.');
      return const OpenRefused();
    }
    if (!a.isItemOpen(index)) {
      _say('Finish the step before this one first!');
      return const OpenRefused();
    }
    if (a.kind == AssignKind.test && a.startedAtMs == null) {
      await _service.startIfTest(_scope, a);
      _say('Your test has started: ${a.testMinutes} minutes!');
      await load();
    }
    return OpenStep(a.items[index], a.kind == AssignKind.test);
  }

  /// Called when the child comes back from a step.
  Future<void> stepClosed(Assignment a, AssignItem item) async {
    if (await _service.isItemPassed(_scope, item)) {
      await _service.markItemDone(_scope, a.id, item.key);
      await load();
      _say('Step done!');
    } else {
      await load();
    }
  }

  @override
  Future<void> close() {
    _ticker?.cancel();
    return super.close();
  }
}
