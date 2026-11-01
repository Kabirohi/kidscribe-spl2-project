import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/trace_templates.dart';
import '../../services/progress_service.dart';

class LetterLevelsState extends Equatable {
  final bool loading;
  final Map<String, Map<String, int>> letters; // glyph -> {guided, free}

  const LetterLevelsState({this.loading = true, this.letters = const {}});

  bool isComplete(String glyph) => ProgressService.letterComplete(letters[glyph]);

  /// A level opens only when every letter BEFORE it is complete
  /// (guided side passed + free-hand side at least 70%).
  bool isUnlocked(int level) {
    for (var i = 0; i < level; i++) {
      if (!isComplete(allLetterItems[i].glyph)) return false;
    }
    return true;
  }

  @override
  List<Object?> get props => [
        loading,
        [for (final e in letters.entries) '${e.key}:${e.value['guided']}:${e.value['free']}']
      ];
}

/// Stage 2 as a level path (SRS FR_7 / US_9).
class LetterLevelsCubit extends Cubit<LetterLevelsState> {
  final ProgressService _progress;

  LetterLevelsCubit({required ProgressService progress})
      : _progress = progress,
        super(const LetterLevelsState());

  Future<void> load() async {
    final all = await _progress.loadLetters();
    if (!isClosed) emit(LetterLevelsState(loading: false, letters: all));
  }
}
