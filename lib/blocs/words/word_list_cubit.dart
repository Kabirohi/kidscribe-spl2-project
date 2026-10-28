import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/word_list.dart';
import '../../services/custom_word_service.dart';
import '../../services/progress_service.dart';

class WordListState extends Equatable {
  final bool loading;
  final Set<String> done;          // words finished
  final List<CustomWord> toyWords; // the child's own words (FR_16)

  const WordListState({
    this.loading = true,
    this.done = const {},
    this.toyWords = const [],
  });

  int get commonDone => practiceWords.where((w) => done.contains(w.word)).length;

  @override
  List<Object?> get props =>
      [loading, done.length, toyWords.map((w) => w.word).toList()];
}

/// Stage 3 word gallery: the common words plus the child's toy words.
class WordListCubit extends Cubit<WordListState> {
  final ProgressService _progress;
  final CustomWordService _toys;

  WordListCubit({required ProgressService progress, required CustomWordService toys})
      : _progress = progress,
        _toys = toys,
        super(const WordListState());

  Future<void> load() async {
    final words = await _progress.loadWords();
    final toys = await _toys.load();
    emit(WordListState(
        loading: false, done: words.keys.toSet(), toyWords: toys));
  }
}
