import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../blocs/assign/manage_learner_cubit.dart';
import '../../models/assignment_models.dart';
import '../../services/assignment_service.dart';
import '../../services/progress_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common.dart';
import 'assign_screen.dart';

/// What a grown-up sees about ONE child: the tasks they gave, and the
/// written feedback they left.
///
///  - give a task or a test          (FR_18/US_23, FR_24/US_33)
///  - give more time                 (FR_23/US_31, US_32)
///  - grade the work and add the key (FR_24/US_33)
///  - write feedback                 (FR_22/US_30)
class ManageLearnerScreen extends StatelessWidget {
  final String scope;
  final String learnerName;
  final String fromRole; // 'Teacher' or 'Parent'

  const ManageLearnerScreen({
    super.key,
    required this.scope,
    required this.learnerName,
    required this.fromRole,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (ctx) => ManageLearnerCubit(
        scope: scope,
        fromRole: fromRole,
        assignments: ctx.read<AssignmentService>(),
        progress: ctx.read<ProgressService>(),
      )..load(),
      child: BlocConsumer<ManageLearnerCubit, ManageLearnerState>(
        listenWhen: (a, b) => b.message != null && a.message != b.message,
        listener: (context, s) => showKidSnack(context, s.message!.text,
            color: s.message!.isError ? AppColors.error : AppColors.success),
        builder: (context, s) => DefaultTabController(
          length: 2,
          child: KidPage(
            floatingActionButton: FloatingActionButton.extended(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              onPressed: () => _newTask(context),
              icon: const Icon(Icons.add_task),
              label: Text(fromRole == 'Teacher' ? 'New task' : 'New challenge',
                  style: kid(15, weight: FontWeight.w600, color: Colors.white)),
            ),
            child: Column(
              children: [
                KidHeader(learnerName, fontSize: 24),
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
                          _feedbackTab(context, s),
                        ]),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---------------- actions ----------------

  Future<void> _newTask(BuildContext context) async {
    final cubit = context.read<ManageLearnerCubit>();
    final made = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => AssignScreen(
            scope: scope, learnerName: learnerName, fromRole: fromRole),
      ),
    );
    if (made == true) cubit.load();
  }

  void _gradeDialog(BuildContext context, Assignment a) {
    final cubit = context.read<ManageLearnerCubit>();
    final markCtrl = TextEditingController(text: a.grade?.toString() ?? '');
    final keyCtrl = TextEditingController(text: a.answerKey ?? '');
    final noteCtrl = TextEditingController(text: a.note ?? '');
    InputDecoration box(String label) => InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        );
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: Text('Grade "${a.title}"', style: kid(20, weight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                  controller: markCtrl,
                  keyboardType: TextInputType.number,
                  decoration: box('Mark out of 100')),
              const SizedBox(height: 12),
              TextField(
                  controller: keyCtrl,
                  maxLines: 2,
                  decoration: box('Answer key (shown after grading)')),
              const SizedBox(height: 12),
              TextField(
                  controller: noteCtrl,
                  maxLines: 3,
                  decoration: box('Correction / suggestion')),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: kid(16)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white),
            onPressed: () async {
              final ok = await cubit.grade(a,
                  mark: markCtrl.text, key: keyCtrl.text, note: noteCtrl.text);
              if (ok && ctx.mounted) Navigator.pop(ctx);
            },
            child: Text('Save', style: kid(16, color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _feedbackDialog(BuildContext context, List<String> finishedLetters) {
    final cubit = context.read<ManageLearnerCubit>();
    final ctrl = TextEditingController();
    var chosen = 'profile';
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          title: Text('Write feedback', style: kid(20, weight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Where should this note go?', style: kid(14)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  children: [
                    _smallChip('Whole profile', chosen == 'profile',
                        () => setLocal(() => chosen = 'profile')),
                    for (final g in finishedLetters)
                      _smallChip('Letter $g', chosen == 'letter:$g',
                          () => setLocal(() => chosen = 'letter:$g')),
                  ],
                ),
                if (finishedLetters.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      'The child has not finished a letter yet, so you can '
                      'only write on the whole profile now.',
                      style: kid(12, color: Colors.grey.shade600),
                    ),
                  ),
                const SizedBox(height: 14),
                TextField(
                  controller: ctrl,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: 'Your feedback',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel', style: kid(16)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white),
              onPressed: () async {
                final ok =
                    await cubit.addFeedback(target: chosen, text: ctrl.text);
                if (ok && ctx.mounted) Navigator.pop(ctx);
              },
              child: Text('Save', style: kid(16, color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------- UI ----------------

  Widget _tasksTab(BuildContext context, ManageLearnerState s) {
    if (s.tasks.isEmpty) {
      return const KidEmpty(
          Icons.assignment, 'No tasks yet. Tap the button below!');
    }
    final cubit = context.read<ManageLearnerCubit>();
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
      itemCount: s.tasks.length,
      itemBuilder: (context, i) {
        final a = s.tasks[i];
        final isTest = a.kind == AssignKind.test;
        final (status, color) = _statusOf(a);
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: KidCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(isTest ? Icons.timer : Icons.menu_book,
                        color: isTest ? AppColors.purple : AppColors.secondary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(a.title,
                          style: kid(18, weight: FontWeight.bold)),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(status, style: kid(12, color: color)),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  '${a.items.length} step${a.items.length == 1 ? '' : 's'}'
                  '${a.inOrder ? ' · in order' : ''}'
                  '${isTest ? ' · ${a.testMinutes} min test' : ''}',
                  style: kid(13, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 8),
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
                if (a.graded) ...[
                  const SizedBox(height: 6),
                  Text('Mark: ${a.grade}/100',
                      style: kid(14,
                          weight: FontWeight.w600, color: AppColors.success)),
                ],
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  children: [
                    TextButton.icon(
                      onPressed: () => cubit.giveMoreTime(a),
                      icon: const Icon(Icons.more_time, size: 18),
                      label: Text('Give more time', style: kid(13)),
                    ),
                    TextButton.icon(
                      onPressed: () => _gradeDialog(context, a),
                      icon: const Icon(Icons.grading, size: 18),
                      label: Text(a.graded ? 'Change mark' : 'Give a mark',
                          style: kid(13)),
                    ),
                    TextButton.icon(
                      onPressed: () => showConfirmDialog(
                        context,
                        title: 'Remove "${a.title}"?',
                        text: 'The child will not see this task any more.',
                        yesText: 'Remove',
                        onYes: () => cubit.deleteTask(a),
                      ),
                      icon: const Icon(Icons.delete_outline,
                          size: 18, color: AppColors.error),
                      label: Text('Remove',
                          style: kid(13, color: AppColors.error)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  (String, Color) _statusOf(Assignment a) {
    if (a.graded) return ('graded', AppColors.success);
    if (a.allDone) return ('finished', AppColors.success);
    if (a.submitted) return ('sent', AppColors.purple);
    if (a.timeIsOver) return ('time over', AppColors.error);
    final left = a.msLeft;
    if (left != null) {
      final h = left ~/ (1000 * 60 * 60);
      return (
        h >= 24 ? '${h ~/ 24} d left' : '${h + 1} h left',
        AppColors.primary
      );
    }
    return ('open', AppColors.secondary);
  }

  Widget _feedbackTab(BuildContext context, ManageLearnerState s) {
    final cubit = context.read<ManageLearnerCubit>();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton.icon(
              onPressed: () => _feedbackDialog(context, s.finishedLetters),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.secondary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              icon: const Icon(Icons.rate_review),
              label: Text('Write feedback',
                  style:
                      kid(16, weight: FontWeight.w600, color: Colors.white)),
            ),
          ),
        ),
        Expanded(
          child: s.notes.isEmpty
              ? const KidEmpty(Icons.rate_review, 'No feedback yet.')
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
                  itemCount: s.notes.length,
                  itemBuilder: (context, i) {
                    final n = s.notes[i];
                    final d = DateTime.fromMillisecondsSinceEpoch(n.atMs);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: KidCard(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                    n.isProfile
                                        ? Icons.person
                                        : Icons.bookmark_border,
                                    size: 18,
                                    color: AppColors.purple),
                                const SizedBox(width: 6),
                                Text(
                                  n.isProfile
                                      ? 'On the profile'
                                      : 'On ${n.target.replaceFirst('letter:', 'letter ')}',
                                  style: kid(13, color: AppColors.purple),
                                ),
                                const Spacer(),
                                Text('${d.day}/${d.month}',
                                    style:
                                        kid(12, color: Colors.grey.shade500)),
                                IconButton(
                                  visualDensity: VisualDensity.compact,
                                  icon: const Icon(Icons.delete_outline,
                                      size: 18, color: AppColors.error),
                                  onPressed: () => cubit.deleteFeedback(n),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(n.text, style: kid(15)),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _smallChip(String text, bool on, VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: on ? AppColors.primary : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color: on ? AppColors.primary : Colors.grey.shade300),
          ),
          child: Text(text,
              style: kid(13, color: on ? Colors.white : AppColors.textDark)),
        ),
      );
}
