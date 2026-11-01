import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/sentence_list.dart';
import '../../services/progress_service.dart';

class SentenceListState extends Equatable {
  final bool loading;
  final Set<String> done;

  const SentenceListState({this.loading = true, this.done = const {}});

  /// A sentence opens when the one before it is finished.
  bool isOpen(int i) => i == 0 || done.contains(practiceSentences[i - 1].id);

  @override
  List<Object?> get props => [loading, done.length];
}

/// Which Stage 4 sentences the learner has finished.
class SentenceListCubit extends Cubit<SentenceListState> {
  final ProgressService _progress;

  SentenceListCubit({required ProgressService progress})
      : _progress = progress,
        super(const SentenceListState());

  Future<void> load() async {
    final done = await _progress.loadSentences();
    emit(SentenceListState(loading: false, done: done.keys.toSet()));
  }
}
