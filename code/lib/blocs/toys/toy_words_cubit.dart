import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../services/badge_service.dart';
import '../../services/custom_word_service.dart';

enum ToyStep { list, checkingPhoto, naming, saving }

class ToyWordsState extends Equatable {
  final bool loading;
  final List<CustomWord> words;
  final ToyStep step;
  final String? photoPath;          // the photo being named
  final List<String> suggestions;   // what ML Kit thinks the toy is
  final String? message;
  final bool messageIsError;
  final int messageTick;
  final List<BadgeDef> newBadges;

  const ToyWordsState({
    this.loading = true,
    this.words = const [],
    this.step = ToyStep.list,
    this.photoPath,
    this.suggestions = const [],
    this.message,
    this.messageIsError = false,
    this.messageTick = 0,
    this.newBadges = const [],
  });

  ToyWordsState copyWith({
    bool? loading,
    List<CustomWord>? words,
    ToyStep? step,
    String? photoPath,
    bool clearPhoto = false,
    List<String>? suggestions,
    String? message,
    bool? messageIsError,
    int? messageTick,
    List<BadgeDef>? newBadges,
  }) =>
      ToyWordsState(
        loading: loading ?? this.loading,
        words: words ?? this.words,
        step: step ?? this.step,
        photoPath: clearPhoto ? null : (photoPath ?? this.photoPath),
        suggestions: suggestions ?? this.suggestions,
        message: message ?? this.message,
        messageIsError: messageIsError ?? this.messageIsError,
        messageTick: messageTick ?? this.messageTick,
        newBadges: newBadges ?? this.newBadges,
      );

  @override
  List<Object?> get props => [loading, words.map((w) => w.word).toList(), step,
        photoPath, suggestions, message, messageIsError, messageTick,
        newBadges.length];
}

/// The toy camera (SRS FR_16 / US_20):
///  1. the parent takes a photo of the child's toy,
///  2. a blurry photo is refused and must be taken again (SRS T_48),
///  3. ML Kit suggests a name; the parent picks it or types one,
///  4. the word is saved and appears in word practice and in the games.
class ToyWordsCubit extends Cubit<ToyWordsState> {
  final CustomWordService _toys;
  final BadgeService _badges;

  ToyWordsCubit({required CustomWordService toys, required BadgeService badges})
      : _toys = toys,
        _badges = badges,
        super(const ToyWordsState());

  Future<void> load() async {
    final words = await _toys.load();
    emit(state.copyWith(loading: false, words: words));
  }

  void _say(String msg, {bool error = false}) => emit(state.copyWith(
      message: msg, messageIsError: error, messageTick: state.messageTick + 1));

  /// The screen took a photo and gives us its path.
  Future<void> processPhoto(String path) async {
    emit(state.copyWith(step: ToyStep.checkingPhoto, photoPath: path));
    final check = await _toys.checkPhoto(path);
    if (!check.clear) {
      // Not clear enough: no word is added, ask for a new photo.
      emit(state.copyWith(step: ToyStep.list, clearPhoto: true));
      _say(check.message ?? 'Please take the photo again.', error: true);
      return;
    }
    final names = await _toys.suggestNames(path);
    emit(state.copyWith(step: ToyStep.naming, suggestions: names));
  }

  Future<void> saveWord(String word) async {
    final error = CustomWordService.validateWord(word);
    if (error != null) {
      _say(error, error: true);
      return;
    }
    final path = state.photoPath;
    if (path == null) return;
    emit(state.copyWith(step: ToyStep.saving));
    final saved = await _toys.add(word, path);
    final words = await _toys.load();
    final badges = await _badges.claimNewBadges();
    emit(state.copyWith(
      step: ToyStep.list,
      clearPhoto: true,
      words: words,
      suggestions: const [],
      newBadges: badges,
    ));
    _say('"${saved.word}" was added! It is now in word practice and the '
        'games.');
  }

  void cancelNaming() =>
      emit(state.copyWith(step: ToyStep.list, clearPhoto: true));

  Future<void> delete(CustomWord w) async {
    await _toys.delete(w.word);
    await load();
    _say('"${w.word}" was removed');
  }

  void badgesShown() => emit(state.copyWith(newBadges: const []));
}
