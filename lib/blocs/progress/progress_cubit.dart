import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/sentence_list.dart';
import '../../data/trace_templates.dart';
import '../../services/family_service.dart';
import '../../services/progress_service.dart';
import '../../services/report_service.dart';

class ProgressState extends Equatable {
  final bool loading;
  final String learnerName;
  final ScopeSummary? summary;
  final Map<String, Map<String, int>> letters;
  final Map<String, int> words;
  final Map<String, int> log;
  final int sentencesDone;

  /// Set after an export, so the screen can show the saved report once.
  final String? exportPath;
  final String? exportText;
  final int exportTick;

  const ProgressState({
    this.loading = true,
    this.learnerName = 'your child',
    this.summary,
    this.letters = const {},
    this.words = const {},
    this.log = const {},
    this.sentencesDone = 0,
    this.exportPath,
    this.exportText,
    this.exportTick = 0,
  });

  bool get hasActivity => summary?.hasActivity ?? false;

  /// Practice counts for the last 7 days (oldest first).
  List<MapEntry<String, int>> get week {
    final now = DateTime.now();
    const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return List.generate(7, (i) {
      final d = now.subtract(Duration(days: 6 - i));
      final key =
          '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
      return MapEntry(names[d.weekday - 1], log[key] ?? 0);
    });
  }

  List<String> get doneLetters => [
        for (final i in allLetterItems)
          if (ProgressService.letterComplete(letters[i.glyph])) i.glyph
      ];

  /// Letters that were started but are not finished yet.
  List<String> get weakLetters => [
        for (final i in allLetterItems)
          if (!ProgressService.letterComplete(letters[i.glyph]) &&
              letters[i.glyph] != null &&
              (((letters[i.glyph]!['guided'] ?? 0) > 0) ||
                  ((letters[i.glyph]!['free'] ?? 0) > 0)))
            i.glyph
      ];

  int get sentencesTotal => practiceSentences.length;

  ProgressState copyWith({
    String? exportPath,
    String? exportText,
    int? exportTick,
  }) =>
      ProgressState(
        loading: loading,
        learnerName: learnerName,
        summary: summary,
        letters: letters,
        words: words,
        log: log,
        sentencesDone: sentencesDone,
        exportPath: exportPath ?? this.exportPath,
        exportText: exportText ?? this.exportText,
        exportTick: exportTick ?? this.exportTick,
      );

  @override
  List<Object?> get props => [
        loading, learnerName, summary?.totalChecks, letters.length,
        words.length, log.length, sentencesDone, exportTick
      ];
}

/// The learner's progress report (SRS FR_19 / US_25).
class ProgressCubit extends Cubit<ProgressState> {
  final ProgressService _progress;
  final FamilyService _family;
  final ReportService _reports;

  ProgressCubit({
    required ProgressService progress,
    required FamilyService family,
    required ReportService reports,
  })  : _progress = progress,
        _family = family,
        _reports = reports,
        super(const ProgressState());

  Future<void> load() async {
    final scope = await _progress.currentScope();
    final child = await _family.getActiveChild();
    final studentLabel = await _family.getActiveStudentLabel();
    final summary = await _progress.summarizeScope(scope);
    final letters = await _progress.loadLettersFor(scope);
    final words = await _progress.loadWordsFor(scope);
    final log = await _progress.loadPracticeLogFor(scope);
    final sentences = await _progress.loadSentencesFor(scope);
    if (isClosed) return;
    emit(ProgressState(
      loading: false,
      learnerName: studentLabel ?? child?.name ?? 'your child',
      summary: summary,
      letters: letters,
      words: words,
      log: log,
      sentencesDone:
          practiceSentences.where((s) => sentences.containsKey(s.id)).length,
    ));
  }

  /// Saves the report as a text file (SRS FR_19).
  Future<void> export() async {
    final scope = await _progress.currentScope();
    final (path, content) = await _reports.exportReport(
        displayName: state.learnerName, scope: scope);
    if (isClosed) return;
    emit(state.copyWith(
        exportPath: path, exportText: content, exportTick: state.exportTick + 1));
  }
}
