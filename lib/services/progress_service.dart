import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/trace_templates.dart';
import '../data/word_list.dart';
import '../models/trace_item.dart';
import 'current_user.dart';
import 'family_service.dart';

/// One learner's progress in numbers — used by the parent progress
/// screen, the teacher class dashboard, and the exported reports.
class ScopeSummary {
  final int strokesDone;   // Stage 1 (out of stage1Items.length)
  final int lettersDone;   // Stage 2 complete letters (both sides)
  final int wordsDone;     // Stage 3 finished words
  final int totalChecks;   // practice activity, all time
  final DateTime? lastPractice;

  const ScopeSummary({
    required this.strokesDone,
    required this.lettersDone,
    required this.wordsDone,
    required this.totalChecks,
    required this.lastPractice,
  });

  bool get hasActivity => totalChecks > 0;
}

/// Saves the learner's practice progress locally on the device
/// (SharedPreferences).
///
/// WHO the progress belongs to (the "scope") is decided in this order:
///  1. the student a Teacher selected to practice (classroom mode),
///  2. the Parent's active child profile,
///  3. the logged-in account itself.
///
/// Stores per scope:
///  - trace_progress_<scope> : {"s1_circle": stars}          (Stage 1)
///  - letters_v2_<scope>     : {"A": {"guided": 2, "free": 82}} (Stage 2)
///  - words_v1_<scope>       : {"CAT": 1}                     (Stage 3)
///  - practice_log_<scope>   : {"2026-07-15": 12}  checks per day
class ProgressService {
  /// Minimum free-hand percentage needed to unlock the next letter.
  static const int freePassPercent = 70;

  String get _uid => currentUid();

  Future<String> _scope() async {
    final prefs = await SharedPreferences.getInstance();
    final student =
        prefs.getString(FamilyService.activeStudentScopeKey(_uid));
    if (student != null && student.isNotEmpty) return student;
    final child = prefs.getString(FamilyService.activeChildKey(_uid));
    return (child == null || child.isEmpty) ? _uid : '${_uid}_c$child';
  }

  /// The scope currently being practiced (for reports/exports).
  Future<String> currentScope() => _scope();

  // =================== raw readers (work for ANY scope) ===================

  Future<Map<String, int>> loadAllFor(String scope) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('trace_progress_$scope');
    if (raw == null) return {};
    return (jsonDecode(raw) as Map<String, dynamic>)
        .map((k, v) => MapEntry(k, v as int));
  }

  Future<Map<String, Map<String, int>>> loadLettersFor(String scope) async {
    final prefs = await SharedPreferences.getInstance();
    final out = <String, Map<String, int>>{};
    final raw = prefs.getString('letters_v2_$scope');
    if (raw != null) {
      (jsonDecode(raw) as Map<String, dynamic>).forEach((k, v) {
        out[k] = Map<String, int>.from(v as Map);
      });
    }
    return out;
  }

  Future<Map<String, int>> loadWordsFor(String scope) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('words_v1_$scope');
    if (raw == null) return {};
    return (jsonDecode(raw) as Map<String, dynamic>)
        .map((k, v) => MapEntry(k, v as int));
  }

  Future<Map<String, int>> loadPracticeLogFor(String scope) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('practice_log_$scope');
    if (raw == null) return {};
    return (jsonDecode(raw) as Map<String, dynamic>)
        .map((k, v) => MapEntry(k, v as int));
  }

  /// Everything the dashboards need about one learner, in one call.
  Future<ScopeSummary> summarizeScope(String scope) async {
    final strokes = await loadAllFor(scope);
    final letters = await loadLettersFor(scope);
    final words = await loadWordsFor(scope);
    final log = await loadPracticeLogFor(scope);

    DateTime? last;
    var total = 0;
    log.forEach((day, count) {
      total += count;
      final d = DateTime.tryParse(day);
      if (d != null && (last == null || d.isAfter(last!))) last = d;
    });

    return ScopeSummary(
      strokesDone: completedCount(strokes, stage1Items),
      lettersDone: completedLetterCount(letters, allLetterItems),
      wordsDone: words.length,
      totalChecks: total,
      lastPractice: last,
    );
  }

  // ============= practice log (feeds the weekly progress chart) =============

  String _today() {
    final n = DateTime.now();
    return '${n.year}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
  }

  Future<void> _logPractice() async {
    final scope = await _scope();
    final log = await loadPracticeLogFor(scope);
    log[_today()] = (log[_today()] ?? 0) + 1;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('practice_log_$scope', jsonEncode(log));
  }

  Future<Map<String, int>> loadPracticeLog() async =>
      loadPracticeLogFor(await _scope());

  // =================== Stage 1 strokes ===================

  Future<Map<String, int>> loadAll() async => loadAllFor(await _scope());

  Future<void> saveStars(String itemId, int stars) async {
    await _logPractice();
    final all = await loadAll();
    final best = all[itemId] ?? 0;
    if (stars <= best) return; // always keep the child's BEST result
    all[itemId] = stars;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('trace_progress_${await _scope()}', jsonEncode(all));
  }

  /// How many of [items] have been passed (at least 1 star).
  int completedCount(Map<String, int> all, List<TraceItem> items) =>
      items.where((i) => (all[i.id] ?? 0) > 0).length;

  // =================== Stage 2 letters (guided + free-hand) ===================

  Future<Map<String, Map<String, int>>> loadLetters() async {
    final out = await loadLettersFor(await _scope());
    // Merge stars from the OLD letter tracing (before the split-screen
    // update) so nobody loses the letters they already traced.
    final legacy = await loadAll();
    legacy.forEach((id, stars) {
      if (id.startsWith('letter_')) {
        final ch = id.substring('letter_'.length);
        final entry = out.putIfAbsent(ch, () => {'guided': 0, 'free': 0});
        if ((entry['guided'] ?? 0) < stars) entry['guided'] = stars;
      }
    });
    return out;
  }

  Future<void> _saveLetters(Map<String, Map<String, int>> map) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('letters_v2_${await _scope()}', jsonEncode(map));
  }

  Future<void> saveGuided(String letter, int stars) async {
    await _logPractice();
    final all = await loadLetters();
    final entry = all.putIfAbsent(letter, () => {'guided': 0, 'free': 0});
    if (stars > (entry['guided'] ?? 0)) {
      entry['guided'] = stars;
      await _saveLetters(all);
    }
  }

  Future<void> saveFree(String letter, int percent) async {
    await _logPractice();
    final all = await loadLetters();
    final entry = all.putIfAbsent(letter, () => {'guided': 0, 'free': 0});
    if (percent > (entry['free'] ?? 0)) {
      entry['free'] = percent;
      await _saveLetters(all);
    }
  }

  /// Both sides done? (guided passed AND free-hand >= 70%)
  static bool letterComplete(Map<String, int>? entry) =>
      entry != null &&
      (entry['guided'] ?? 0) > 0 &&
      (entry['free'] ?? 0) >= freePassPercent;

  int completedLetterCount(
          Map<String, Map<String, int>> all, List<TraceItem> letters) =>
      letters.where((i) => letterComplete(all[i.glyph])).length;

  // =================== Stage 3 words ===================

  Future<Map<String, int>> loadWords() async => loadWordsFor(await _scope());

  Future<void> saveWordDone(String word) async {
    await _logPractice();
    final all = await loadWords();
    if (all.containsKey(word)) return;
    all[word] = 1;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('words_v1_${await _scope()}', jsonEncode(all));
  }

  int completedWordCount(Map<String, int> all) =>
      practiceWords.where((w) => all.containsKey(w.word)).length;

  // =================== Stage 4 sentences ===================
  // sentences_v1_<scope> : {"s01": 1}

  Future<Map<String, int>> loadSentencesFor(String scope) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('sentences_v1_$scope');
    if (raw == null) return {};
    return (jsonDecode(raw) as Map<String, dynamic>)
        .map((k, v) => MapEntry(k, v as int));
  }

  Future<Map<String, int>> loadSentences() async =>
      loadSentencesFor(await _scope());

  Future<void> saveSentenceDone(String id) async {
    await _logPractice();
    final all = await loadSentences();
    if (all.containsKey(id)) return;
    all[id] = 1;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('sentences_v1_${await _scope()}', jsonEncode(all));
  }

  // =================== games and free writing ===================
  // games_v1_<scope> : {"match_best": 4, "ninja_best": 5, "free_good": 7}
  // A small bag of numbers, so badges and reports can read them.

  Future<Map<String, int>> loadGamesFor(String scope) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('games_v1_$scope');
    if (raw == null) return {};
    return (jsonDecode(raw) as Map<String, dynamic>)
        .map((k, v) => MapEntry(k, v as int));
  }

  Future<Map<String, int>> loadGames() async => loadGamesFor(await _scope());

  /// Keeps the BEST value for [key] (e.g. the highest game level).
  Future<void> saveGameBest(String key, int value) async {
    await _logPractice();
    final all = await loadGames();
    if ((all[key] ?? 0) >= value) return;
    all[key] = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('games_v1_${await _scope()}', jsonEncode(all));
  }

  /// Adds [by] to a counter (e.g. how many good free-writing letters).
  Future<int> addToCounter(String key, {int by = 1}) async {
    await _logPractice();
    final all = await loadGames();
    all[key] = (all[key] ?? 0) + by;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('games_v1_${await _scope()}', jsonEncode(all));
    return all[key]!;
  }
}
