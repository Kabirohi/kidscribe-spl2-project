/// Stage 3 vocabulary (SRS FR_8 / US_11): common words the child learns
/// to write letter-by-letter. Easiest (3 letters) first.
class PracticeWord {
  final String word;  // uppercase, e.g. "CAT"
  final String emoji; // friendly picture for the card

  const PracticeWord(this.word, this.emoji);
}

const List<PracticeWord> practiceWords = [
  // --- 3-letter words ---
  PracticeWord('CAT', '🐱'),
  PracticeWord('DOG', '🐶'),
  PracticeWord('SUN', '☀️'),
  PracticeWord('BAT', '🦇'),
  PracticeWord('HAT', '🎩'),
  PracticeWord('CAR', '🚗'),
  PracticeWord('BUS', '🚌'),
  PracticeWord('EGG', '🥚'),
  PracticeWord('BEE', '🐝'),
  PracticeWord('ANT', '🐜'),
  PracticeWord('COW', '🐮'),
  PracticeWord('PIG', '🐷'),
  PracticeWord('TOY', '🧸'),
  // --- 4-letter words ---
  PracticeWord('BALL', '⚽'),
  PracticeWord('FISH', '🐟'),
  PracticeWord('BIRD', '🐦'),
  PracticeWord('CAKE', '🎂'),
  PracticeWord('MILK', '🥛'),
  PracticeWord('STAR', '⭐'),
  PracticeWord('TREE', '🌳'),
  PracticeWord('BOOK', '📚'),
  PracticeWord('MOON', '🌙'),
  PracticeWord('FROG', '🐸'),
  PracticeWord('DUCK', '🦆'),
];
