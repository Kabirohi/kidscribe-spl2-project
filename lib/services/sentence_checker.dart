import '../data/sentence_list.dart';

/// What kind of mistake the child made (so the screen can explain it).
enum SentenceProblem { none, missingWord, wrongOrder, fullStop, capital }

class SentenceCheck {
  final SentenceProblem problem;
  final String message;        // kid-friendly: what to fix
  final List<int> badSlots;    // which boxes to show in red

  const SentenceCheck(this.problem, this.message, this.badSlots);

  bool get ok => problem == SentenceProblem.none;
}

/// The grammar rules of Stage 4 (SRS FR_9):
///  - all the words must be there, in the right order   (US_12)
///  - the sentence ends with a full stop                 (US_13)
///  - the first word starts with a capital letter        (US_13)
///  - the word "I" is always a capital letter            (US_13)
///  - no other word gets a capital letter
///
/// [placed] is what the child put in the boxes, left to right. A null
/// means an empty box. The full stop is the text ".".
class SentenceChecker {
  static const stop = '.';

  static SentenceCheck check(PracticeSentence s, List<String?> placed) {
    final n = s.words.length;

    // 1. Is a box still empty? (a word or the full stop is missing)
    final empty = [
      for (var i = 0; i < placed.length; i++)
        if (placed[i] == null) i
    ];
    if (empty.isNotEmpty) {
      return SentenceCheck(
        SentenceProblem.missingWord,
        'Some boxes are still empty. Put a card in every box!',
        empty,
      );
    }

    // 2. Full stop: it must be there, and only at the very end.
    final stopAt = placed.indexOf(stop);
    if (stopAt == -1) {
      return SentenceCheck(
        SentenceProblem.fullStop,
        'A sentence ends with a full stop ( . ) — add the dot at the end!',
        [placed.length - 1],
      );
    }
    if (stopAt != n) {
      return SentenceCheck(
        SentenceProblem.fullStop,
        'The full stop goes at the very END of the sentence.',
        [stopAt],
      );
    }

    // 3. Word order (compare without caring about capitals yet).
    final wrong = [
      for (var i = 0; i < n; i++)
        if (placed[i]!.toLowerCase() != s.words[i].toLowerCase()) i
    ];
    if (wrong.isNotEmpty) {
      return SentenceCheck(
        SentenceProblem.wrongOrder,
        'Some words are in the wrong place. Look at the picture and try '
        'again!',
        wrong,
      );
    }

    // 4. Capital letters.
    final first = placed[0]!;
    if (!_startsCapital(first)) {
      return const SentenceCheck(
        SentenceProblem.capital,
        'A sentence starts with a CAPITAL letter! Tap "Aa" on the first '
        'word to make it big.',
        [0],
      );
    }
    for (var i = 1; i < n; i++) {
      final word = placed[i]!;
      final isI = s.words[i] == 'I';
      if (isI && word != 'I') {
        return SentenceCheck(
          SentenceProblem.capital,
          'The word "I" is ALWAYS a capital letter!',
          [i],
        );
      }
      if (!isI && _startsCapital(word)) {
        return SentenceCheck(
          SentenceProblem.capital,
          'Only the first word needs a capital here. Make "${word.toLowerCase()}" '
          'small again.',
          [i],
        );
      }
    }

    return const SentenceCheck(
        SentenceProblem.none, 'Perfect sentence!', []);
  }

  static bool _startsCapital(String w) =>
      w.isNotEmpty && w[0] == w[0].toUpperCase() && w[0] != w[0].toLowerCase();

  /// Makes the first letter big or small.
  static String toggleCapital(String w) {
    if (w.isEmpty || w == stop) return w;
    final head = _startsCapital(w) ? w[0].toLowerCase() : w[0].toUpperCase();
    return head + w.substring(1);
  }
}
