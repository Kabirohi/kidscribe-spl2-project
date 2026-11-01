import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/sentence_list.dart';
import '../../data/trace_templates.dart';
import '../../data/word_list.dart';
import '../../services/family_service.dart';
import '../../services/premium_service.dart';
import '../../services/progress_service.dart';

/// One letter in the detailed chart.
class LetterStat extends Equatable {
  final String letter;
  final int guidedStars; // 0..3
  final int freePercent; // 0..100 (best)
  const LetterStat(this.letter, this.guidedStars, this.freePercent);

  bool get tried => guidedStars > 0 || freePercent > 0;
  bool get complete => guidedStars > 0 && freePercent >= ProgressService.freePassPercent;

  @override
  List<Object?> get props => [letter, guidedStars, freePercent];
}

class AdvancedReportState extends Equatable {
  final bool loading;
  final bool isPremium;
  final String? learnerName;
  final List<LetterStat> letters;
  final List<int> last14Days; // practice checks per day, oldest first
  final int wordsDone;
  final int sentencesDone;
  final Map<String, int> games;

  const AdvancedReportState({
    this.loading = true,
    this.isPremium = false,
    this.learnerName,
    this.letters = const [],
    this.last14Days = const [],
    this.wordsDone = 0,
    this.sentencesDone = 0,
    this.games = const {},
  });

  /// Letters the child tried but that are still weak (lowest score first).
  List<LetterStat> get weakLetters {
    final tried = letters.where((l) => l.tried && !l.complete).toList()
      ..sort((a, b) => a.freePercent.compareTo(b.freePercent));
    return tried.take(5).toList();
  }

  int get wordsTotal => practiceWords.length;
  int get sentencesTotal => practiceSentences.length;

  @override
  List<Object?> get props => [loading, isPremium, learnerName, letters,
        last14Days, wordsDone, sentencesDone, games];
}

/// The premium advanced report (SRS FR_21 / US_29): detailed charts for
/// every letter, the weak letters, and the last two weeks of practice.
/// It stays locked unless the parent has Premium (SRS T_68).
class AdvancedReportCubit extends Cubit<AdvancedReportState> {
  final ProgressService _progress;
  final PremiumService _premium;
  final FamilyService _family;

  AdvancedReportCubit({
    required ProgressService progress,
    required PremiumService premium,
    required FamilyService family,
  })  : _progress = progress,
        _premium = premium,
        _family = family,
        super(const AdvancedReportState());

  Future<void> load() async {
    final premium = await _premium.isPremium();
    if (!premium) {
      emit(const AdvancedReportState(loading: false, isPremium: false));
      return;
    }
    final letters = await _progress.loadLetters();
    final log = await _progress.loadPracticeLog();
    final words = await _progress.loadWords();
    final sentences = await _progress.loadSentences();
    final games = await _progress.loadGames();
    final child = await _family.getActiveChild();
    final student = await _family.getActiveStudentLabel();

    final now = DateTime.now();
    final days = <int>[];
    for (var i = 13; i >= 0; i--) {
      final d = now.subtract(Duration(days: i));
      final key =
          '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
      days.add(log[key] ?? 0);
    }

    emit(AdvancedReportState(
      loading: false,
      isPremium: true,
      learnerName: student ?? child?.name,
      letters: [
        for (final l in allLetterItems)
          LetterStat(l.glyph, letters[l.glyph]?['guided'] ?? 0,
              letters[l.glyph]?['free'] ?? 0),
      ]..sort((a, b) => a.letter.compareTo(b.letter)),
      last14Days: days,
      wordsDone: _progress.completedWordCount(words),
      sentencesDone:
          practiceSentences.where((s) => sentences.containsKey(s.id)).length,
      games: games,
    ));
  }
}
