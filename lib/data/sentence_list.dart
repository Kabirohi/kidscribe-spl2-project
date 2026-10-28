/// Stage 4 sentences (SRS FR_9 / US_12, US_13).
///
/// Every sentence uses words the child already learned to write in
/// Stage 3, plus a few small helper words (the, is, a, I, my...).
/// A sentence is written in the normal way: it starts with a capital
/// letter and ends with a full stop.
class PracticeSentence {
  final String id;
  final List<String> words; // the words in the RIGHT order, e.g. The cat is big
  final String emoji;       // a picture that shows the sentence

  const PracticeSentence(this.id, this.words, this.emoji);

  /// The sentence written correctly: "The cat is big."
  String get text => '${words.join(' ')}.';
}

const List<PracticeSentence> practiceSentences = [
  PracticeSentence('s01', ['The', 'cat', 'is', 'big'], '🐱'),
  PracticeSentence('s02', ['I', 'see', 'a', 'dog'], '🐶'),
  PracticeSentence('s03', ['The', 'sun', 'is', 'hot'], '☀️'),
  PracticeSentence('s04', ['My', 'hat', 'is', 'red'], '🎩'),
  PracticeSentence('s05', ['The', 'bus', 'is', 'big'], '🚌'),
  PracticeSentence('s06', ['A', 'bee', 'can', 'fly'], '🐝'),
  PracticeSentence('s07', ['I', 'have', 'a', 'toy'], '🧸'),
  PracticeSentence('s08', ['The', 'fish', 'can', 'swim'], '🐟'),
  PracticeSentence('s09', ['I', 'like', 'my', 'cake'], '🎂'),
  PracticeSentence('s10', ['The', 'moon', 'is', 'up'], '🌙'),
  PracticeSentence('s11', ['A', 'frog', 'can', 'jump'], '🐸'),
  PracticeSentence('s12', ['I', 'read', 'a', 'book'], '📚'),
];
