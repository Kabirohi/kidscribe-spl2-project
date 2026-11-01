import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../models/profile_models.dart';
import '../../services/family_service.dart';
import '../../services/progress_service.dart';
import '../../services/report_service.dart';
import '../common/ui_message.dart';

// ======================= the class list =======================

class ClassesState extends Equatable {
  final bool loading;
  final List<SchoolClass> classes;
  final UiMessage? message;

  const ClassesState(
      {this.loading = true, this.classes = const [], this.message});

  @override
  List<Object?> get props => [
        loading,
        [for (final c in classes) '${c.id}:${c.name}:${c.students.length}'],
        message
      ];
}

/// The teacher's classes (SRS FR_4 / US_7).
class ClassesCubit extends Cubit<ClassesState> {
  final FamilyService _family;
  int _tick = 0;

  ClassesCubit({required FamilyService family})
      : _family = family,
        super(const ClassesState());

  Future<void> load() async {
    final classes = await _family.loadClasses();
    if (!isClosed) {
      emit(ClassesState(
          loading: false, classes: classes, message: state.message));
    }
  }

  void _say(String text, {bool error = false}) => emit(ClassesState(
      loading: state.loading,
      classes: state.classes,
      message: UiMessage(text, isError: error, tick: ++_tick)));

  /// An empty name makes no class (SRS US_7). Returns true when made.
  Future<bool> create(String name) async {
    if (name.trim().isEmpty) {
      _say('Please enter a class name', error: true);
      return false;
    }
    await _family.saveClass(SchoolClass(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name.trim(),
      students: const [],
    ));
    await load();
    _say('Class "${name.trim()}" created!');
    return true;
  }

  Future<void> delete(SchoolClass c) async {
    // If a student of this class was practicing, stop that too.
    final active = await _family.getActiveStudentScope();
    if (c.students.any((n) => _family.studentScope(c.id, n) == active)) {
      await _family.setActiveStudent(null, null);
    }
    await _family.deleteClass(c.id);
    await load();
    _say('Class "${c.name}" deleted');
  }
}

// ======================= one class =======================

class ClassDetailState extends Equatable {
  final bool loading;
  final SchoolClass? schoolClass;
  final Map<String, ScopeSummary> summaries; // student name -> summary
  final String? activeScope; // the student practicing right now
  final UiMessage? message;

  /// Set when a report was saved, so the screen can show it once.
  final String? reportPath;
  final String? reportText;
  final int reportTick;

  const ClassDetailState({
    this.loading = true,
    this.schoolClass,
    this.summaries = const {},
    this.activeScope,
    this.message,
    this.reportPath,
    this.reportText,
    this.reportTick = 0,
  });

  ClassDetailState copyWith({
    UiMessage? message,
    String? reportPath,
    String? reportText,
    int? reportTick,
  }) =>
      ClassDetailState(
        loading: loading,
        schoolClass: schoolClass,
        summaries: summaries,
        activeScope: activeScope,
        message: message ?? this.message,
        reportPath: reportPath ?? this.reportPath,
        reportText: reportText ?? this.reportText,
        reportTick: reportTick ?? this.reportTick,
      );

  /// The best letter count in the class — to spot who is behind.
  int get maxLetters => summaries.values.isEmpty
      ? 0
      : summaries.values
          .map((s) => s.lettersDone)
          .reduce((a, b) => a > b ? a : b);

  /// SRS US_22: 'not started', 'needs help' (far behind the class
  /// leader) or 'on track'.
  StudentStatus statusFor(String name) {
    final s = summaries[name];
    if (s == null || !s.hasActivity) return StudentStatus.notStarted;
    if (maxLetters >= 4 && s.lettersDone <= maxLetters ~/ 2) {
      return StudentStatus.needsHelp;
    }
    return StudentStatus.onTrack;
  }

  @override
  List<Object?> get props => [
        loading,
        schoolClass?.name,
        schoolClass?.students.join('|'),
        [for (final e in summaries.entries) '${e.key}:${e.value.totalChecks}'],
        activeScope,
        message,
        reportTick,
      ];
}

enum StudentStatus { notStarted, needsHelp, onTrack }

/// One class = the teacher dashboard (SRS US_7, US_22, US_24).
class ClassDetailCubit extends Cubit<ClassDetailState> {
  final FamilyService _family;
  final ProgressService _progress;
  final ReportService _reports;
  final String classId;
  int _tick = 0;

  ClassDetailCubit({
    required this.classId,
    required FamilyService family,
    required ProgressService progress,
    required ReportService reports,
  })  : _family = family,
        _progress = progress,
        _reports = reports,
        super(const ClassDetailState());

  String scopeOf(String name) => _family.studentScope(classId, name);

  Future<void> load() async {
    final classes = await _family.loadClasses();
    final cls = classes.where((c) => c.id == classId).firstOrNull;
    final summaries = <String, ScopeSummary>{};
    if (cls != null) {
      // Re-read every student's progress each time, so the list stays
      // up to date as students practice (SRS T_53).
      for (final name in cls.students) {
        summaries[name] = await _progress.summarizeScope(scopeOf(name));
      }
    }
    final active = await _family.getActiveStudentScope();
    if (isClosed) return;
    emit(ClassDetailState(
      loading: false,
      schoolClass: cls,
      summaries: summaries,
      activeScope: active,
      message: state.message,
      reportPath: state.reportPath,
      reportText: state.reportText,
      reportTick: state.reportTick,
    ));
  }

  void _say(String text, {bool error = false}) => emit(
      state.copyWith(message: UiMessage(text, isError: error, tick: ++_tick)));

  /// Returns true when the student was added.
  Future<bool> addStudent(String name) async {
    final c = state.schoolClass;
    if (c == null) return false;
    name = name.trim();
    if (name.isEmpty) {
      _say("Please enter the student's name", error: true);
      return false;
    }
    if (c.students.any((s) => s.toLowerCase() == name.toLowerCase())) {
      _say('$name is already in ${c.name}', error: true);
      return false;
    }
    await _family.saveClass(
        SchoolClass(id: c.id, name: c.name, students: [...c.students, name]));
    // The first student becomes the learner right away.
    if (await _family.getActiveStudentScope() == null) {
      await _family.setActiveStudent(scopeOf(name), '$name (${c.name})');
    }
    await load();
    _say('$name joined ${c.name}!');
    return true;
  }

  Future<void> removeStudent(String name) async {
    final c = state.schoolClass;
    if (c == null) return;
    if (state.activeScope == scopeOf(name)) {
      await _family.setActiveStudent(null, null);
    }
    await _family.saveClass(SchoolClass(
        id: c.id,
        name: c.name,
        students: [...c.students]..remove(name)));
    await load();
    _say('$name was removed from ${c.name}');
  }

  /// Classroom practice mode: this student is the learner now.
  Future<void> togglePractice(String name) async {
    final c = state.schoolClass;
    if (c == null) return;
    if (state.activeScope == scopeOf(name)) {
      await _family.setActiveStudent(null, null);
      await load();
      _say('Practice mode off');
    } else {
      await _family.setActiveStudent(scopeOf(name), '$name (${c.name})');
      await load();
      _say('$name is practicing now. Open "Start Learning"!');
    }
  }

  Future<void> exportReport(String name) async {
    final (path, content) =
        await _reports.exportReport(displayName: name, scope: scopeOf(name));
    if (isClosed) return;
    emit(state.copyWith(
        reportPath: path, reportText: content, reportTick: state.reportTick + 1));
  }
}
