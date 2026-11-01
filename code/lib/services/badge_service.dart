import 'package:shared_preferences/shared_preferences.dart';
import '../data/sentence_list.dart';
import '../data/trace_templates.dart';
import 'custom_word_service.dart';
import 'progress_service.dart';

/// One badge the child can earn (SRS FR_14 / US_18).
class BadgeDef {
  final String id;
  final String emoji;
  final String name;
  final String description; // how to earn it (shown while locked)

  const BadgeDef(this.id, this.emoji, this.name, this.description);
}

/// All badges, easiest first. Badges are COMPUTED from real progress,
/// so they can never lie about what the child has done.
const List<BadgeDef> allBadges = [
  BadgeDef('first_check', '🐾', 'First Steps', 'Do your very first practice'),
  BadgeDef('perfect_trace', '🌟', 'Perfect Tracer', 'Get 3 stars on any tracing'),
  BadgeDef('stroke_master', '📏', 'Line Master', 'Finish all 6 strokes of Stage 1'),
  BadgeDef('first_letter', '🔤', 'Letter Starter', 'Complete your first letter'),
  BadgeDef('letter_five', '🚀', 'Letter Explorer', 'Complete 5 letters'),
  BadgeDef('alphabet_hero', '🏆', 'Alphabet Hero', 'Complete all 26 letters'),
  BadgeDef('robot_ace', '🤖', "Robot's Favorite", 'Score 95%+ on a free-hand letter'),
  BadgeDef('first_word', '🧱', 'Word Builder', 'Write your first whole word'),
  BadgeDef('word_wizard', '🪄', 'Word Wizard', 'Write 5 whole words'),
  BadgeDef('streak_3', '🔥', 'On Fire', 'Practice 3 days in a row'),
  BadgeDef('streak_7', '⚡', 'Super Streak', 'Practice 7 days in a row'),
  BadgeDef('first_sentence', '🧩', 'Sentence Maker', 'Make your first sentence'),
  BadgeDef('grammar_hero', '📝', 'Grammar Hero', 'Make all 12 sentences'),
  BadgeDef('free_writer', '✍️', 'Free Writer', 'Write a good letter in Free Writing'),
  BadgeDef('free_ten', '🖊️', 'Pen Pro', 'Write 10 good letters in Free Writing'),
  BadgeDef('match_champ', '🃏', 'Match Champion', 'Finish level 3 of Letter Match'),
  BadgeDef('ninja', '🥷', 'Letter Ninja', 'Win a round of Letter Ninja'),
  BadgeDef('toy_word', '🧸', 'Toy Writer', 'Write one of your own toy words'),
];

/// Works out which badges are earned, tracks the daily practice streak,
/// and remembers which badges were already celebrated so a new one pops
/// up exactly once (SRS T_43).
class BadgeService {
  final ProgressService _progress = ProgressService();

  String _dayKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  // ---------------- streaks ----------------

  /// Days practiced in a row. The streak survives until a FULL day is
  /// missed — then it goes back to zero (SRS T_44).
  int currentStreak(Map<String, int> log) {
    final today = DateTime.now();
    bool practiced(DateTime d) => log.containsKey(_dayKey(d));

    var day = today;
    if (!practiced(day)) {
      // Not practiced yet today — the streak is still alive if they
      // practiced yesterday; two silent days means it is broken.
      day = today.subtract(const Duration(days: 1));
      if (!practiced(day)) return 0;
    }
    var streak = 0;
    while (practiced(day)) {
      streak++;
      day = day.subtract(const Duration(days: 1));
    }
    return streak;
  }

  /// The longest run of practice days ever (for the badges screen).
  int bestStreak(Map<String, int> log) {
    final days = log.keys.map(DateTime.parse).toList()..sort();
    var best = 0, run = 0;
    DateTime? prev;
    for (final d in days) {
      run = (prev != null && d.difference(prev).inDays == 1) ? run + 1 : 1;
      if (run > best) best = run;
      prev = d;
    }
    return best;
  }

  // ---------------- earned badges ----------------

  Future<Set<String>> computeEarnedIds() async {
    final scope = await _progress.currentScope();
    final strokes = await _progress.loadAllFor(scope);
    final letters = await _progress.loadLettersFor(scope);
    final words = await _progress.loadWordsFor(scope);
    final log = await _progress.loadPracticeLogFor(scope);

    final lettersDone =
        _progress.completedLetterCount(letters, allLetterItems);
    final streak = currentStreak(log);

    final earned = <String>{};
    if (log.isNotEmpty) earned.add('first_check');
    if (strokes.values.any((s) => s >= 3) ||
        letters.values.any((e) => (e['guided'] ?? 0) >= 3)) {
      earned.add('perfect_trace');
    }
    if (_progress.completedCount(strokes, stage1Items) >= stage1Items.length) {
      earned.add('stroke_master');
    }
    if (lettersDone >= 1) earned.add('first_letter');
    if (lettersDone >= 5) earned.add('letter_five');
    if (lettersDone >= allLetterItems.length) earned.add('alphabet_hero');
    if (letters.values.any((e) => (e['free'] ?? 0) >= 95)) {
      earned.add('robot_ace');
    }
    if (words.isNotEmpty) earned.add('first_word');
    if (_progress.completedWordCount(words) >= 5) earned.add('word_wizard');
    if (streak >= 3) earned.add('streak_3');
    if (streak >= 7) earned.add('streak_7');

    // Stage 4, the games and the toy words
    final sentences = await _progress.loadSentencesFor(scope);
    final games = await _progress.loadGamesFor(scope);
    final doneSentences =
        practiceSentences.where((s) => sentences.containsKey(s.id)).length;
    if (doneSentences >= 1) earned.add('first_sentence');
    if (doneSentences >= practiceSentences.length) earned.add('grammar_hero');
    if ((games['free_good'] ?? 0) >= 1) earned.add('free_writer');
    if ((games['free_good'] ?? 0) >= 10) earned.add('free_ten');
    if ((games['match_best'] ?? 0) >= 3) earned.add('match_champ');
    if ((games['ninja_best'] ?? 0) >= 1) earned.add('ninja');
    final toyWords = (await CustomWordService().load()).map((w) => w.word);
    if (toyWords.any(words.containsKey)) earned.add('toy_word');
    return earned;
  }

  /// Badges earned since the last check — each is returned (and
  /// celebrated) exactly once, then remembered.
  Future<List<BadgeDef>> claimNewBadges() async {
    final scope = await _progress.currentScope();
    final earned = await computeEarnedIds();

    final prefs = await SharedPreferences.getInstance();
    final seenKey = 'badges_seen_$scope';
    final seen = (prefs.getStringList(seenKey) ?? []).toSet();

    final fresh = earned.difference(seen);
    if (fresh.isEmpty) return const [];

    await prefs.setStringList(seenKey, earned.toList());
    return allBadges.where((b) => fresh.contains(b.id)).toList();
  }

  /// (earned, total, current streak) — for the home-screen card.
  Future<(int, int, int)> summary() async {
    final earned = await computeEarnedIds();
    final log = await _progress.loadPracticeLog();
    return (earned.length, allBadges.length, currentStreak(log));
  }
}
