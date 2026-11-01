import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../blocs/tasks/my_tasks_cubit.dart';
import '../../data/sentence_list.dart';
import '../../data/trace_templates.dart';
import '../../data/word_list.dart';
import '../../models/assignment_models.dart';
import '../../services/assignment_service.dart';
import '../../services/custom_word_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common.dart';
import 'letter_practice_screen.dart';
import 'sentence_practice_screen.dart';
import 'tracing_screen.dart';
import 'word_practice_screen.dart';

/// What the CHILD sees: the tasks a grown-up gave them, and the
/// feedback written about their work.
///
///  - steps open in order when the grown-up asked for that (US_23)
///  - a task is blocked when its time is over (US_31, US_32)
///  - a test hides all help and is sent by itself when time is up (US_33)
///  - the mark, the correction and the answer key appear after grading
///  - written feedback is shown to the child (US_30)
class MyTasksScreen extends StatelessWidget {
  const MyTasksScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (ctx) => MyTasksCubit(
        assignments: ctx.read<AssignmentService>(),
        toys: ctx.read<CustomWordService>(),
      )..load(),
      child: BlocConsumer<MyTasksCubit, MyTasksState>(
        listenWhen: (a, b) => b.message != null && a.message != b.message,
        listener: (context, s) => showKidSnack(context, s.message!.text,
            color: s.message!.isError ? AppColors.error : AppColors.purple),
        builder: (context, s) => DefaultTabController(
          length: 2,
          child: KidPage(
            child: Column(
              children: [
                const KidHeader('My Tasks'),
                TabBar(
                  labelColor: AppColors.primary,
                  unselectedLabelColor: Colors.grey,
                  indicatorColor: AppColors.primary,
                  labelStyle: kid(15, weight: FontWeight.w600),
                  tabs: const [Tab(text: 'Tasks'), Tab(text: 'Feedback')],
                ),
                Expanded(
                  child: s.loading
                      ? const Center(child: CircularProgressIndicator())
                      : TabBarView(children: [
                          _tasksTab(context, s),
                          _notesTab(s),
                        ]),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---------------- doing a step ----------------

  Future<void> _openItem(
      BuildContext context, MyTasksState s, Assignment a, int index) async {
    final cubit = context.read<MyTasksCubit>();
    final result = await cubit.tryOpen(a, index);
    if (result is! OpenStep || !context.mounted) return;

    final screen = _screenFor(result.item, result.exam, s.toyWords);
    if (screen == null) {
      showKidSnack(context, 'This step is not here any more.');
      return;
    }
    await Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
    await cubit.stepClosed(a, result.item);
  }

  Widget? _screenFor(AssignItem item, bool exam, List<CustomWord> toys) {
    switch (item.kind) {
      case ItemKind.stroke:
        final i = stage1Items.indexWhere((x) => x.id == item.ref);
        return i < 0
            ? null
            : TracingScreen(items: stage1Items, startIndex: i, examMode: exam);
      case ItemKind.letter:
        final i = allLetterItems.indexWhere((l) => l.glyph == item.ref);
        return i < 0 ? null : LetterPracticeScreen(levelIndex: i, examMode: exam);
      case ItemKind.word:
        final i = practiceWords.indexWhere((w) => w.word == item.ref);
        if (i >= 0) return WordPracticeScreen(wordIndex: i, examMode: exam);
        final toy = toys.where((t) => t.word == item.ref).firstOrNull;
        return toy == null
            ? null
            : WordPracticeScreen(
                wordIndex: 0, words: [toy.asPracticeWord], examMode: exam);
      case ItemKind.sentence:
        final i = practiceSentences.indexWhere((p) => p.id == item.ref);
        return i < 0 ? null : SentencePracticeScreen(startIndex: i);
    }
  }

  String _labelOf(AssignItem item) {
    switch (item.kind) {
      case ItemKind.stroke:
        return stage1Items.where((x) => x.id == item.ref).firstOrNull?.name ??
            item.ref;
      case ItemKind.letter:
        return 'Letter ${item.ref}';
      case ItemKind.word:
        return item.ref;
      case ItemKind.sentence:
        final p =
            practiceSentences.where((x) => x.id == item.ref).firstOrNull;
        return p == null ? 'Sentence' : p.text;
    }
  }

  String _timeText(Assignment a) {
    final left = a.msLeft;
    if (left == null) return 'No time limit';
    if (left <= 0) return 'Time is over';
    final d = Duration(milliseconds: left);
    if (d.inDays >= 1) return '${d.inDays} day${d.inDays == 1 ? '' : 's'} left';
    if (d.inHours >= 1) return '${d.inHours} h ${d.inMinutes % 60} min left';
    return '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')} left';
  }

  // ---------------- UI ----------------

  Widget _tasksTab(BuildContext context, MyTasksState s) {
    if (s.tasks.isEmpty) {
      return const KidEmpty(Icons.assignment_turned_in,
          'No tasks right now.\nGo and practice on your own!');
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: s.tasks.length,
      itemBuilder: (context, i) => _taskCard(context, s, s.tasks[i]),
    );
  }

  Widget _taskCard(BuildContext context, MyTasksState s, Assignment a) {
    final isTest = a.kind == AssignKind.test;
    final color = a.graded
        ? AppColors.success
        : a.blocked
            ? Colors.grey
            : (isTest ? AppColors.purple : AppColors.secondary);

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: KidCard(
        borderColor: color.withValues(alpha: 0.5),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(isTest ? Icons.timer : Icons.menu_book, color: color),
                const SizedBox(width: 8),
                Expanded(
                    child: Text(a.title,
                        style: kid(19, weight: FontWeight.bold))),
                if (isTest)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.purple.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text('TEST: no help',
                        style: kid(11, color: AppColors.purple)),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'From your ${a.fromRole == 'Teacher' ? 'teacher' : 'parent'} · '
              '${_timeText(a)}',
              style: kid(13,
                  color:
                      a.timeIsOver ? AppColors.error : Colors.grey.shade600),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var i = 0; i < a.items.length; i++)
                  _stepChip(context, s, a, i),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: a.items.isEmpty ? 0 : a.doneCount / a.items.length,
                minHeight: 8,
                backgroundColor: Colors.grey.shade200,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text('${a.doneCount} of ${a.items.length} done',
                style: kid(12, color: Colors.grey.shade600)),
            if (a.allDone && !a.graded) ...[
              const SizedBox(height: 8),
              Text('All done! Sent to your ${a.fromRole.toLowerCase()}',
                  style: kid(14,
                      weight: FontWeight.w600, color: AppColors.success)),
            ],
            if (a.timeIsOver && !a.allDone && !a.graded) ...[
              const SizedBox(height: 8),
              Text('The time is over. Ask for more time.',
                  style: kid(14, color: AppColors.error)),
            ],
            if (a.graded) ...[
              const Divider(height: 20),
              Row(
                children: [
                  const Icon(Icons.grading, color: AppColors.success),
                  const SizedBox(width: 8),
                  Text('Your mark: ${a.grade}/100',
                      style: kid(17,
                          weight: FontWeight.bold, color: AppColors.success)),
                ],
              ),
              if (a.note != null && a.note!.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text('What to fix: ${a.note}', style: kid(14)),
              ],
              if (a.answerKey != null && a.answerKey!.isNotEmpty) ...[
                const SizedBox(height: 6),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text('Answer key: ${a.answerKey}', style: kid(14)),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _stepChip(
      BuildContext context, MyTasksState s, Assignment a, int i) {
    final item = a.items[i];
    final done = a.doneKeys.contains(item.key);
    final open = a.isItemOpen(i);
    final color = done
        ? AppColors.success
        : open
            ? AppColors.primary
            : Colors.grey;
    return GestureDetector(
      onTap: () => _openItem(context, s, a, i),
      child: Opacity(
        opacity: open || done ? 1 : 0.55,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: done ? color.withValues(alpha: 0.15) : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color, width: 1.6),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(done ? Icons.check_circle : (open ? Icons.edit : Icons.lock),
                  size: 16, color: color),
              const SizedBox(width: 6),
              Text(_labelOf(item), style: kid(14)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _notesTab(MyTasksState s) {
    if (s.notes.isEmpty) {
      return const KidEmpty(Icons.rate_review, 'No feedback yet.');
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: s.notes.length,
      itemBuilder: (context, i) {
        final n = s.notes[i];
        final d = DateTime.fromMillisecondsSinceEpoch(n.atMs);
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: KidCard(
            borderColor: AppColors.secondary.withValues(alpha: 0.4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.chat_bubble_outline,
                        size: 18, color: AppColors.secondary),
                    const SizedBox(width: 6),
                    Text(
                      n.isProfile
                          ? 'From your ${n.fromRole.toLowerCase()}'
                          : 'About ${n.target.replaceFirst('letter:', 'letter ')}',
                      style: kid(13, color: AppColors.secondary),
                    ),
                    const Spacer(),
                    Text('${d.day}/${d.month}',
                        style: kid(12, color: Colors.grey.shade500)),
                  ],
                ),
                const SizedBox(height: 6),
                Text(n.text, style: kid(16)),
              ],
            ),
          ),
        );
      },
    );
  }
}
