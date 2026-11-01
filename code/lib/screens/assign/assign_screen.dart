import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../blocs/assign/assign_cubit.dart';
import '../../data/sentence_list.dart';
import '../../data/trace_templates.dart';
import '../../data/word_list.dart';
import '../../models/assignment_models.dart';
import '../../services/assignment_service.dart';
import '../../services/custom_word_service.dart';
import '../../services/premium_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common.dart';

/// Where a grown-up makes a task for one child.
///
///  - A Teacher makes homework or a timed test
///    (SRS FR_18/US_23, FR_23/US_31, FR_24/US_33).
///  - A Parent makes a writing challenge with a time limit
///    (SRS FR_17/US_21, FR_23/US_32).
class AssignScreen extends StatefulWidget {
  final String scope; // whose task this is
  final String learnerName; // shown in the title
  final String fromRole; // 'Teacher' or 'Parent'

  const AssignScreen({
    super.key,
    required this.scope,
    required this.learnerName,
    required this.fromRole,
  });

  @override
  State<AssignScreen> createState() => _AssignScreenState();
}

/// Stateful only to own the text box controller; every choice lives in
/// the AssignCubit.
class _AssignScreenState extends State<AssignScreen> {
  late final _titleCtrl = TextEditingController(
      text: widget.fromRole == 'Teacher' ? 'Homework' : 'Writing challenge');

  @override
  void dispose() {
    _titleCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isTeacher = widget.fromRole == 'Teacher';
    return BlocProvider(
      create: (ctx) => AssignCubit(
        scope: widget.scope,
        fromRole: widget.fromRole,
        assignments: ctx.read<AssignmentService>(),
        premium: ctx.read<PremiumService>(),
        toys: ctx.read<CustomWordService>(),
      )..load(),
      child: BlocConsumer<AssignCubit, AssignState>(
        listenWhen: (a, b) =>
            (b.message != null && a.message != b.message) ||
            (!a.saved && b.saved),
        listener: (context, s) {
          if (s.saved) {
            showKidSnack(context, 'Task given to ${widget.learnerName}!',
                color: AppColors.success);
            Navigator.pop(context, true);
            return;
          }
          showKidSnack(context, s.message!.text,
              color: s.message!.isError ? AppColors.error : AppColors.purple);
        },
        builder: (context, s) {
          final cubit = context.read<AssignCubit>();
          return KidPage(
            child: Column(
              children: [
                KidHeader(
                  isTeacher
                      ? 'New task for ${widget.learnerName}'
                      : 'New challenge for ${widget.learnerName}',
                  fontSize: 21,
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                    children: [
                      _card([
                        TextField(
                          controller: _titleCtrl,
                          style: const TextStyle(fontSize: 16),
                          decoration: InputDecoration(
                            labelText: 'Name of the task',
                            prefixIcon: const Icon(Icons.title,
                                color: AppColors.primary),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14)),
                          ),
                        ),
                        const SizedBox(height: 14),
                        _label('What kind of task?'),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Expanded(
                              child: _pill(
                                'Practice',
                                s.kind == AssignKind.practice,
                                () => cubit.setKind(AssignKind.practice),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _pill(
                                s.canGiveTests
                                    ? 'Test (no help)'
                                    : 'Test Premium',
                                s.kind == AssignKind.test,
                                () => cubit.setKind(AssignKind.test),
                              ),
                            ),
                          ],
                        ),
                      ]),
                      const SizedBox(height: 14),
                      _card([
                        _label('Pick what the child must do  (${s.picked} picked)'),
                        const SizedBox(height: 8),
                        _group('Strokes', [
                          for (final x in stage1Items)
                            _chip(x.name, s.strokes.contains(x.id),
                                () => cubit.toggleStroke(x.id)),
                        ]),
                        _group('Letters', [
                          for (final l in allLetterItems)
                            _chip(l.glyph, s.letters.contains(l.glyph),
                                () => cubit.toggleLetter(l.glyph)),
                        ]),
                        _group('Words', [
                          for (final w in practiceWords)
                            _chip('${w.emoji} ${w.word}',
                                s.words.contains(w.word),
                                () => cubit.toggleWord(w.word)),
                        ]),
                        if (s.toyWords.isNotEmpty)
                          _group('Toy words', [
                            for (final w in s.toyWords)
                              _chip('${CustomWord.emoji} $w',
                                  s.words.contains(w),
                                  () => cubit.toggleWord(w)),
                          ]),
                        _group('Sentences (Stage 4)', [
                          for (final p in practiceSentences)
                            _chip('${p.emoji} ${p.text}',
                                s.sentences.contains(p.id),
                                () => cubit.toggleSentence(p.id)),
                        ]),
                      ]),
                      const SizedBox(height: 14),
                      _card([
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          activeThumbColor: AppColors.primary,
                          title: Text('Do them in order',
                              style: kid(16, weight: FontWeight.w600)),
                          subtitle: Text(
                            'The next one opens only when the one before it is done',
                            style: kid(13, color: Colors.grey.shade600),
                          ),
                          value: s.inOrder,
                          onChanged: cubit.setInOrder,
                        ),
                        const Divider(),
                        const SizedBox(height: 4),
                        if (s.kind == AssignKind.test) ...[
                          _label('How long may the test take?'),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final m in [5, 10, 15, 20, 30])
                                _chip('$m min', s.minutes == m,
                                    () => cubit.setMinutes(m)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'In a test there is no video, no guide and no '
                            'numbers to help. When the time is over, the test '
                            'closes and is sent by itself.',
                            style: kid(13, color: Colors.grey.shade600),
                          ),
                        ] else ...[
                          _label('Time limit'),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _chip('No limit', s.days == null,
                                  () => cubit.setDays(null)),
                              for (final d in [1, 2, 3, 7])
                                _chip(d == 1 ? '1 day' : '$d days',
                                    s.days == d, () => cubit.setDays(d)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'When the time is over, the task is closed. You '
                            'can always give more time later.',
                            style: kid(13, color: Colors.grey.shade600),
                          ),
                        ],
                      ]),
                      const SizedBox(height: 20),
                      KidButton(
                        isTeacher ? 'Give this task' : 'Give this challenge',
                        busy: s.saving,
                        height: 54,
                        onPressed: () => cubit.save(_titleCtrl.text),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ---------------- small pieces ----------------

  Widget _card(List<Widget> children) => KidCard(
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: children),
      );

  Widget _label(String t) => Text(t, style: kid(16, weight: FontWeight.w600));

  Widget _group(String title, List<Widget> chips) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: kid(14, color: Colors.grey.shade600)),
            const SizedBox(height: 6),
            Wrap(spacing: 7, runSpacing: 7, children: chips),
          ],
        ),
      );

  Widget _chip(String text, bool on, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: on ? AppColors.primary : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: on ? AppColors.primary : Colors.grey.shade300,
                width: 1.5),
          ),
          child: Text(text,
              style: kid(14, color: on ? Colors.white : AppColors.textDark)),
        ),
      );

  Widget _pill(String text, bool on, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: on ? AppColors.secondary : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: on ? AppColors.secondary : Colors.grey.shade300,
                width: 1.5),
          ),
          child: Text(text,
              style: kid(15,
                  weight: FontWeight.w600,
                  color: on ? Colors.white : AppColors.textDark)),
        ),
      );
}
