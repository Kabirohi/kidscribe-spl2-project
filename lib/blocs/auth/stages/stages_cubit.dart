import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/sentence_list.dart';
import '../../data/trace_templates.dart';
import '../../data/word_list.dart';
import '../../services/family_service.dart';
import '../../services/progress_service.dart';

/// How far the learner has come through the five stages (SRS FR_10).
class StagesState extends Equatable {
  final bool loading;
  final String? learnerName;
  final int strokesDone;
  final int strokesTotal;
  final int lettersDone;
  final int lettersTotal;
  final int wordsDone;
  final int wordsTotal;
  final int sentencesDone;
  final int sentencesTotal;

  const StagesState({
    this.loading = true,
    this.learnerName,
    this.strokesDone = 0,
    this.strokesTotal = 0,
    this.lettersDone = 0,
    this.lettersTotal = 0,
    this.wordsDone = 0,
    this.wordsTotal = 0,
    this.sentencesDone = 0,
    this.sentencesTotal = 0,
  });

  bool get stage1Complete => strokesTotal > 0 && strokesDone >= strokesTotal;
  bool get stage2Complete => lettersTotal > 0 && lettersDone >= lettersTotal;
  bool get stage3Complete => wordsTotal > 0 && wordsDone >= wordsTotal;
  bool get stage4Complete =>
      sentencesTotal > 0 && sentencesDone >= sentencesTotal;

  /// The first stage that is not finished — that is where the child is.
  int get currentStage {
    if (!stage1Complete) return 1;
    if (!stage2Complete) return 2;
    if (!stage3Complete) return 3;
    if (!stage4Complete) return 4;
    return 5;
  }

  @override
  List<Object?> get props => [loading, learnerName, strokesDone, strokesTotal,
        lettersDone, lettersTotal, wordsDone, wordsTotal, sentencesDone,
        sentencesTotal];
}

class StagesCubit extends Cubit<StagesState> {
  final ProgressService _progress;
  final FamilyService _family;

  StagesCubit({required ProgressService progress, required FamilyService family})
      : _progress = progress,
        _family = family,
        super(const StagesState());

  Future<void> load() async {
    final strokes = await _progress.loadAll();
    final letters = await _progress.loadLetters();
    final words = await _progress.loadWords();
    final sentences = await _progress.loadSentences();
    final child = await _family.getActiveChild();
    final student = await _family.getActiveStudentLabel();

    emit(StagesState(
      loading: false,
      learnerName: student ?? child?.name,
      strokesDone: _progress.completedCount(strokes, stage1Items),
      strokesTotal: stage1Items.length,
      lettersDone: _progress.completedLetterCount(letters, allLetterItems),
      lettersTotal: allLetterItems.length,
      wordsDone: _progress.completedWordCount(words),
      wordsTotal: practiceWords.length,
      sentencesDone:
          practiceSentences.where((s) => sentences.containsKey(s.id)).length,
      sentencesTotal: practiceSentences.length,
    ));
  }
}
