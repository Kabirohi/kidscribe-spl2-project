import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/trace_templates.dart';
import '../../models/assignment_models.dart';
import '../../services/assignment_service.dart';
import '../../services/progress_service.dart';
import '../common/ui_message.dart';

class ManageLearnerState extends Equatable {
  final bool loading;
  final List<Assignment> tasks; // newest first
  final List<FeedbackNote> notes;
  final List<String> finishedLetters;
  final UiMessage? message;

  const ManageLearnerState({
    this.loading = true,
    this.tasks = const [],
    this.notes = const [],
    this.finishedLetters = const [],
    this.message,
  });

  ManageLearnerState withMessage(UiMessage m) => ManageLearnerState(
      loading: loading,
      tasks: tasks,
      notes: notes,
      finishedLetters: finishedLetters,
      message: m);

  @override
  List<Object?> get props => [
        loading,
        [
          for (final t in tasks)
            '${t.id}:${t.doneCount}:${t.grade}:${t.submitted}:${t.dueAtMs}:${t.startedAtMs}'
        ],
        [for (final n in notes) n.id],
        finishedLetters.length,
        message,
      ];
}

/// What a grown-up manages for ONE child:
///  - tasks and tests       (FR_18 / US_23, FR_24 / US_33)
///  - more time             (FR_23 / US_31, US_32)
///  - grades + answer key   (FR_24 / US_33)
///  - written feedback      (FR_22 / US_30)
class ManageLearnerCubit extends Cubit<ManageLearnerState> {
  final AssignmentService _service;
  final ProgressService _progress;
  final String scope;
  final String fromRole;
  int _tick = 0;

  ManageLearnerCubit({
    required this.scope,
    required this.fromRole,
    required AssignmentService assignments,
    required ProgressService progress,
  })  : _service = assignments,
        _progress = progress,
        super(const ManageLearnerState());

  Future<void> load() async {
    await _service.autoSubmitExpired(scope); // the clock sends late work
    final tasks = await _service.loadFor(scope);
    final notes = await _service.loadFeedbackFor(scope);
    final letters = await _progress.loadLettersFor(scope);
    if (isClosed) return;
    emit(ManageLearnerState(
      loading: false,
      tasks: tasks.reversed.toList(),
      notes: notes,
      finishedLetters: [
        for (final l in allLetterItems)
          if (ProgressService.letterComplete(letters[l.glyph])) l.glyph
      ],
      message: state.message,
    ));
  }

  void _say(String text, {bool error = false}) =>
      emit(state.withMessage(UiMessage(text, isError: error, tick: ++_tick)));

  Future<void> giveMoreTime(Assignment a) async {
    if (a.kind == AssignKind.test) {
      await _service.giveMoreTime(scope, a.id, Duration.zero);
      await load();
      _say('${a.title}: the test clock starts again');
    } else {
      await _service.giveMoreTime(scope, a.id, const Duration(days: 1));
      await load();
      _say('${a.title}: 1 more day given');
    }
  }

  /// Returns true when the grade was saved.
  Future<bool> grade(Assignment a,
      {required String mark, required String key, required String note}) async {
    final m = int.tryParse(mark.trim());
    if (m == null || m < 0 || m > 100) {
      _say('Please write a mark from 0 to 100', error: true);
      return false;
    }
    await _service.grade(scope, a.id,
        mark: m,
        answerKey: key.trim().isEmpty ? null : key.trim(),
        note: note.trim().isEmpty ? null : note.trim());
    await load();
    _say('Graded');
    return true;
  }

  Future<void> deleteTask(Assignment a) async {
    await _service.delete(scope, a.id);
    await load();
    _say('"${a.title}" was removed');
  }

  /// An empty box saves nothing (SRS US_30). Returns true when saved.
  Future<bool> addFeedback({required String target, required String text}) async {
    if (text.trim().isEmpty) {
      _say('Please write your feedback first', error: true);
      return false;
    }
    await _service.addFeedback(
      scope,
      FeedbackNote(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        target: target,
        text: text.trim(),
        fromRole: fromRole,
        atMs: DateTime.now().millisecondsSinceEpoch,
      ),
    );
    await load();
    _say('Feedback saved');
    return true;
  }

  Future<void> deleteFeedback(FeedbackNote n) async {
    await _service.deleteFeedback(scope, n.id);
    await load();
  }
}
