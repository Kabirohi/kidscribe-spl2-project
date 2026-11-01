import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/assignment_models.dart';
import 'progress_service.dart';

/// Saves the tasks a grown-up gives to one child, and the written
/// feedback about that child. Everything is kept on the tablet, under
/// the same "scope" the progress uses, so each child has their own list.
///
///  - assignments_<scope> : the list of tasks and tests
///  - feedback_<scope>    : the written notes
class AssignmentService {
  final ProgressService _progress = ProgressService();

  Future<String> currentScope() => _progress.currentScope();

  // ===================== tasks =====================

  Future<List<Assignment>> loadFor(String scope) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('assignments_$scope');
    if (raw == null) return [];
    return (jsonDecode(raw) as List)
        .map((m) => Assignment.fromMap(Map<String, dynamic>.from(m)))
        .toList();
  }

  Future<List<Assignment>> load() async => loadFor(await currentScope());

  Future<void> _saveAll(String scope, List<Assignment> list) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        'assignments_$scope', jsonEncode(list.map((a) => a.toMap()).toList()));
  }

  /// Adds a new task, or replaces the one with the same id.
  Future<void> save(String scope, Assignment a) async {
    final list = await loadFor(scope);
    final i = list.indexWhere((x) => x.id == a.id);
    if (i >= 0) {
      list[i] = a;
    } else {
      list.add(a);
    }
    await _saveAll(scope, list);
  }

  Future<void> delete(String scope, String id) async {
    final list = await loadFor(scope)
      ..removeWhere((a) => a.id == id);
    await _saveAll(scope, list);
  }

  /// Gives more time on a task whose time is over (SRS US_31 / US_32).
  Future<void> giveMoreTime(String scope, String id, Duration extra) async {
    final list = await loadFor(scope);
    final a = list.firstWhere((x) => x.id == id);
    final now = DateTime.now().millisecondsSinceEpoch;
    if (a.kind == AssignKind.test) {
      // Restart the clock for the test, and open it again.
      a.startedAtMs = now;
    } else {
      final base = (a.dueAtMs == null || a.dueAtMs! < now) ? now : a.dueAtMs!;
      a.dueAtMs = base + extra.inMilliseconds;
    }
    a.submitted = false;
    await _saveAll(scope, list);
  }

  /// The child opened a test: start its clock the first time only.
  Future<Assignment> startIfTest(String scope, Assignment a) async {
    if (a.kind == AssignKind.test && a.startedAtMs == null) {
      a.startedAtMs = DateTime.now().millisecondsSinceEpoch;
      await save(scope, a);
    }
    return a;
  }

  /// Marks one step finished for this task.
  Future<void> markItemDone(String scope, String id, String itemKey) async {
    final list = await loadFor(scope);
    final a = list.firstWhere((x) => x.id == id);
    a.doneKeys.add(itemKey);
    if (a.allDone) a.submitted = true; // finished work goes to the grown-up
    await _saveAll(scope, list);
  }

  /// Sends the work even if it is not finished (used when time runs out).
  Future<void> submit(String scope, String id) async {
    final list = await loadFor(scope);
    final a = list.firstWhere((x) => x.id == id);
    a.submitted = true;
    await _saveAll(scope, list);
  }

  /// Any task whose time is over is sent by itself (SRS US_33).
  Future<bool> autoSubmitExpired(String scope) async {
    final list = await loadFor(scope);
    var changed = false;
    for (final a in list) {
      if (!a.submitted && a.timeIsOver) {
        a.submitted = true;
        changed = true;
      }
    }
    if (changed) await _saveAll(scope, list);
    return changed;
  }

  Future<void> grade(String scope, String id,
      {required int mark, String? answerKey, String? note}) async {
    final list = await loadFor(scope);
    final a = list.firstWhere((x) => x.id == id);
    a.grade = mark;
    a.answerKey = answerKey;
    a.note = note;
    a.graded = true;
    a.submitted = true;
    await _saveAll(scope, list);
  }

  /// Tasks the child can still work on right now.
  Future<List<Assignment>> openTasks(String scope) async {
    final list = await loadFor(scope);
    return list.where((a) => !a.submitted && !a.timeIsOver).toList();
  }

  /// True when the child has something waiting (used for the reminder).
  Future<bool> hasWaitingWork(String scope) async =>
      (await openTasks(scope)).isNotEmpty;

  // ===================== feedback (FR_22) =====================

  Future<List<FeedbackNote>> loadFeedbackFor(String scope) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('feedback_$scope');
    if (raw == null) return [];
    final list = (jsonDecode(raw) as List)
        .map((m) => FeedbackNote.fromMap(Map<String, dynamic>.from(m)))
        .toList();
    list.sort((a, b) => b.atMs.compareTo(a.atMs)); // newest first
    return list;
  }

  Future<List<FeedbackNote>> loadFeedback() async =>
      loadFeedbackFor(await currentScope());

  Future<void> addFeedback(String scope, FeedbackNote note) async {
    final list = await loadFeedbackFor(scope)..add(note);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        'feedback_$scope', jsonEncode(list.map((n) => n.toMap()).toList()));
  }

  Future<void> deleteFeedback(String scope, String id) async {
    final list = await loadFeedbackFor(scope)
      ..removeWhere((n) => n.id == id);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        'feedback_$scope', jsonEncode(list.map((n) => n.toMap()).toList()));
  }

  /// Notes written about one finished level, e.g. the letter A.
  Future<List<FeedbackNote>> feedbackForItem(String scope, String key) async =>
      (await loadFeedbackFor(scope)).where((n) => n.target == key).toList();

  // ===================== helpers =====================

  /// Did the child already pass this step? (read from their progress)
  Future<bool> isItemPassed(String scope, AssignItem item) async {
    switch (item.kind) {
      case ItemKind.stroke:
        final all = await _progress.loadAllFor(scope);
        return (all[item.ref] ?? 0) > 0;
      case ItemKind.letter:
        final letters = await _progress.loadLettersFor(scope);
        return ProgressService.letterComplete(letters[item.ref]);
      case ItemKind.word:
        final words = await _progress.loadWordsFor(scope);
        return words.containsKey(item.ref);
      case ItemKind.sentence:
        final sentences = await _progress.loadSentencesFor(scope);
        return sentences.containsKey(item.ref);
    }
  }
}
