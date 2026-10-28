// SRS US_12 and US_13 - Stage 4 sentences and grammar.
// Covers T_31, T_32, T_33, T_34.

import 'package:flutter_test/flutter_test.dart';
import 'package:kidscribe/data/sentence_list.dart';
import 'package:kidscribe/services/sentence_checker.dart';

void main() {
  // "The cat is big" - the sentence used in the SRS test steps.
  final s = practiceSentences.firstWhere(
      (p) => p.words.join(' ').toLowerCase() == 'the cat is big');

  group('US_12 build a sentence', () {
    test('T_31 a correct sentence is accepted', () {
      final r = SentenceChecker.check(s, ['The', 'cat', 'is', 'big', '.']);
      expect(r.ok, isTrue);
      expect(r.problem, SentenceProblem.none);
      expect(r.message, contains('Perfect'));
    });

    test('T_32 wrong word order is not accepted and feedback is shown', () {
      final r = SentenceChecker.check(s, ['big', 'cat', 'The', 'is', '.']);
      expect(r.ok, isFalse);
      expect(r.problem, SentenceProblem.wrongOrder);
      expect(r.message, isNotEmpty);
      expect(r.badSlots, isNotEmpty); // the wrong boxes are marked
    });

    test('an empty box is reported before anything else', () {
      final r = SentenceChecker.check(s, ['The', null, 'is', 'big', '.']);
      expect(r.problem, SentenceProblem.missingWord);
      expect(r.badSlots, [1]);
    });
  });

  group('US_13 punctuation and capital letters', () {
    test('T_33 capital letter and full stop are accepted', () {
      final r = SentenceChecker.check(s, ['The', 'cat', 'is', 'big', '.']);
      expect(r.ok, isTrue);
    });

    test('T_34 a missing capital letter is reported', () {
      final r = SentenceChecker.check(s, ['the', 'cat', 'is', 'big', '.']);
      expect(r.ok, isFalse);
      expect(r.problem, SentenceProblem.capital);
      expect(r.message, contains('CAPITAL'));
      expect(r.badSlots, [0]);
    });

    test('a missing full stop is reported', () {
      final r = SentenceChecker.check(s, ['The', 'cat', 'is', 'big', 'big']);
      expect(r.problem, SentenceProblem.fullStop);
    });

    test('a full stop in the middle is reported', () {
      final r = SentenceChecker.check(s, ['The', 'cat', '.', 'big', 'is']);
      expect(r.problem, SentenceProblem.fullStop);
      expect(r.badSlots, [2]);
    });

    test('a capital letter on a middle word is reported', () {
      final r = SentenceChecker.check(s, ['The', 'Cat', 'is', 'big', '.']);
      expect(r.problem, SentenceProblem.capital);
      expect(r.badSlots, [1]);
    });

    test('the word "I" must always be a capital', () {
      // In every sentence we ship, "I" is the first word, and the first
      // word must be a capital anyway. So we build a sentence that has
      // "I" in the middle, to check that rule on its own.
      const middleI = PracticeSentence('test', ['Mum', 'and', 'I', 'run'], '🏃');
      final r = SentenceChecker.check(
          middleI, ['Mum', 'and', 'i', 'run', '.']); // small i - not allowed
      expect(r.problem, SentenceProblem.capital);
      expect(r.message, contains('"I"'));
      expect(r.badSlots, [2]);

      // With the capital I it is a perfect sentence.
      expect(
          SentenceChecker.check(middleI, ['Mum', 'and', 'I', 'run', '.']).ok,
          isTrue);
    });

    test('every sentence we ship passes when it is built correctly', () {
      for (final p in practiceSentences) {
        final placed = <String?>[...p.words, '.'];
        expect(SentenceChecker.check(p, placed).ok, isTrue,
            reason: 'sentence ${p.id} should be accepted');
      }
    });

    test('toggleCapital makes the first letter big, then small again', () {
      expect(SentenceChecker.toggleCapital('cat'), 'Cat');
      expect(SentenceChecker.toggleCapital('Cat'), 'cat');
      expect(SentenceChecker.toggleCapital('.'), '.'); // the dot never changes
    });
  });
}
