/// What kind of thing the child must do for one step of a task.
enum ItemKind { stroke, letter, word, sentence }

/// A task can be normal practice, or a test with no help (SRS FR_24).
enum AssignKind { practice, test }

/// One step inside a task: one stroke, one letter, one word or one
/// Stage 4 sentence.
class AssignItem {
  final ItemKind kind;
  final String ref; // stroke id, letter (A-Z), the word, or sentence id

  const AssignItem(this.kind, this.ref);

  /// Short key used to remember that this step is finished.
  String get key => '${kind.name}:$ref';

  Map<String, dynamic> toMap() => {'kind': kind.name, 'ref': ref};

  factory AssignItem.fromMap(Map<String, dynamic> m) => AssignItem(
        ItemKind.values.firstWhere((k) => k.name == m['kind'],
            orElse: () => ItemKind.letter),
        m['ref'] ?? '',
      );
}

/// A task a grown-up gives to one child.
///
/// A Teacher gives homework and tests (SRS FR_18/US_23, FR_23/US_31,
/// FR_24/US_33). A Parent gives a writing challenge with a time limit
/// (SRS FR_17/US_21, FR_23/US_32). Both use this same class.
class Assignment {
  final String id;
  final String title;
  final AssignKind kind;
  final String fromRole;      // 'Teacher' or 'Parent'
  final List<AssignItem> items;
  final bool inOrder;         // next step opens only when the one before is done
  int? dueAtMs;               // deadline / time limit end (null = no limit)
  int? startedAtMs;           // when the child opened a test the first time
  final int? testMinutes;     // how long a test may take
  Set<String> doneKeys;       // steps the child finished for THIS task
  bool submitted;             // sent to the grown-up (by hand or by the clock)
  bool graded;
  int? grade;                 // 0..100
  String? answerKey;          // shown after grading
  String? note;               // the grown-up's correction / suggestion

  Assignment({
    required this.id,
    required this.title,
    required this.kind,
    required this.fromRole,
    required this.items,
    required this.inOrder,
    this.dueAtMs,
    this.startedAtMs,
    this.testMinutes,
    Set<String>? doneKeys,
    this.submitted = false,
    this.graded = false,
    this.grade,
    this.answerKey,
    this.note,
  }) : doneKeys = doneKeys ?? <String>{};

  // ---------------- time rules ----------------

  /// A test ends [testMinutes] after the child started it. Normal
  /// homework ends at its deadline.
  int? get endsAtMs {
    if (kind == AssignKind.test) {
      if (startedAtMs == null || testMinutes == null) return null;
      return startedAtMs! + testMinutes! * 60 * 1000;
    }
    return dueAtMs;
  }

  /// Milliseconds left, or null when there is no time limit.
  int? get msLeft {
    final end = endsAtMs;
    if (end == null) return null;
    return end - DateTime.now().millisecondsSinceEpoch;
  }

  bool get timeIsOver {
    final left = msLeft;
    return left != null && left <= 0;
  }

  bool get allDone => items.every((i) => doneKeys.contains(i.key));

  /// The child may not work on it any more.
  bool get blocked => submitted || (timeIsOver && !allDone);

  /// With "in order" on, a step opens only when the one before it is done.
  bool isItemOpen(int index) {
    if (blocked) return false;
    if (!inOrder) return true;
    for (var i = 0; i < index; i++) {
      if (!doneKeys.contains(items[i].key)) return false;
    }
    return true;
  }

  int get doneCount =>
      items.where((i) => doneKeys.contains(i.key)).length;

  // ---------------- storage ----------------

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'kind': kind.name,
        'fromRole': fromRole,
        'items': items.map((i) => i.toMap()).toList(),
        'inOrder': inOrder,
        'dueAtMs': dueAtMs,
        'startedAtMs': startedAtMs,
        'testMinutes': testMinutes,
        'doneKeys': doneKeys.toList(),
        'submitted': submitted,
        'graded': graded,
        'grade': grade,
        'answerKey': answerKey,
        'note': note,
      };

  factory Assignment.fromMap(Map<String, dynamic> m) => Assignment(
        id: m['id'] ?? '',
        title: m['title'] ?? '',
        kind: AssignKind.values.firstWhere((k) => k.name == m['kind'],
            orElse: () => AssignKind.practice),
        fromRole: m['fromRole'] ?? 'Teacher',
        items: (m['items'] as List? ?? [])
            .map((e) => AssignItem.fromMap(Map<String, dynamic>.from(e)))
            .toList(),
        inOrder: m['inOrder'] ?? false,
        dueAtMs: m['dueAtMs'],
        startedAtMs: m['startedAtMs'],
        testMinutes: m['testMinutes'],
        doneKeys: Set<String>.from(m['doneKeys'] ?? const []),
        submitted: m['submitted'] ?? false,
        graded: m['graded'] ?? false,
        grade: m['grade'],
        answerKey: m['answerKey'],
        note: m['note'],
      );
}

/// One written note from a grown-up (SRS FR_22/US_30).
/// [target] is 'profile' for the whole child, or an item key like
/// 'letter:A' for one finished level.
class FeedbackNote {
  final String id;
  final String target;
  final String text;
  final String fromRole;
  final int atMs;

  const FeedbackNote({
    required this.id,
    required this.target,
    required this.text,
    required this.fromRole,
    required this.atMs,
  });

  bool get isProfile => target == 'profile';

  Map<String, dynamic> toMap() => {
        'id': id,
        'target': target,
        'text': text,
        'fromRole': fromRole,
        'atMs': atMs,
      };

  factory FeedbackNote.fromMap(Map<String, dynamic> m) => FeedbackNote(
        id: m['id'] ?? '',
        target: m['target'] ?? 'profile',
        text: m['text'] ?? '',
        fromRole: m['fromRole'] ?? 'Teacher',
        atMs: m['atMs'] ?? 0,
      );
}
