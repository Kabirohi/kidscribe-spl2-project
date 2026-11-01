import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/progress/progress_cubit.dart';
import '../data/trace_templates.dart';
import '../data/word_list.dart';
import '../services/custom_word_service.dart';
import '../services/family_service.dart';
import '../services/progress_service.dart';
import '../services/report_service.dart';
import '../theme/app_colors.dart';
import '../widgets/common.dart';
import '../widgets/art.dart';

/// The learner's progress report screen (SRS FR_19 / US_25):
/// weekly practice, finished letters & words, weak areas — and a clear
/// "no progress yet" state for a brand-new learner.
class ProgressScreen extends StatelessWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (ctx) => ProgressCubit(
        progress: ctx.read<ProgressService>(),
        family: ctx.read<FamilyService>(),
        reports: ctx.read<ReportService>(),
      )..load(),
      child: BlocConsumer<ProgressCubit, ProgressState>(
        listenWhen: (a, b) => a.exportTick != b.exportTick,
        listener: (context, s) => _showExport(context, s),
        builder: (context, s) => KidPage(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              KidHeader('Progress', actions: [
                if (s.hasActivity)
                  IconButton(
                    tooltip: 'Save report',
                    icon: const Icon(Icons.download,
                        size: 26, color: Colors.white),
                    onPressed: () => context.read<ProgressCubit>().export(),
                  ),
                const SizedBox(width: 4),
              ]),
              Expanded(child: _body(context, s)),
            ],
          ),
        ),
      ),
    );
  }

  void _showExport(BuildContext context, ProgressState s) =>
      showReportDialog(context, s.exportPath ?? '', s.exportText ?? '');

  Widget _body(BuildContext context, ProgressState s) {
    if (s.loading || s.summary == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final sum = s.summary!;
    if (!s.hasActivity) {
      // SRS T_60: a new learner sees "no progress yet"
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const KidArt('hatching_chick', size: 110),
            const SizedBox(height: 12),
            Text('No progress yet!', style: kid(22, weight: FontWeight.bold)),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                '${s.learnerName} has not practiced yet. Open "Start Learning" and begin Stage 1 together!',
                textAlign: TextAlign.center,
                style: kid(15, color: Colors.grey.shade600),
              ),
            ),
          ],
        ),
      );
    }

    final week = s.week;
    final maxDay = week.map((e) => e.value).reduce((a, b) => a > b ? a : b);

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text('How ${s.learnerName} is doing',
            style: kid(17, weight: FontWeight.w600)),
        const SizedBox(height: 12),
        // ---- stage totals ----
        Row(
          children: [
            _statCard('Strokes', sum.strokesDone, stage1Items.length,
                AppColors.secondary),
            const SizedBox(width: 10),
            _statCard('Letters', sum.lettersDone, allLetterItems.length,
                AppColors.purple),
            const SizedBox(width: 10),
            _statCard('Words', sum.wordsDone, practiceWords.length,
                AppColors.primary),
            const SizedBox(width: 10),
            _statCard('Sentences', s.sentencesDone, s.sentencesTotal,
                const Color(0xFFF59E0B)),
          ],
        ),
        const SizedBox(height: 18),
        // ---- weekly chart ----
        _card(
          title: 'This week',
          child: SizedBox(
            height: 110,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final day in week)
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (day.value > 0)
                          Text('${day.value}',
                              style: kid(11, color: Colors.grey.shade600)),
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 6),
                          height: day.value == 0
                              ? 4
                              : 12 + 64 * day.value / maxDay,
                          decoration: BoxDecoration(
                            color: day.value == 0
                                ? Colors.grey.shade300
                                : AppColors.primary,
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(day.key,
                            style: kid(11, color: Colors.grey.shade600)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        // ---- finished letters & words ----
        _card(
          title: 'Finished letters',
          child: s.doneLetters.isEmpty
              ? _emptyText('No letters finished yet')
              : Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final g in s.doneLetters) _chip(g, AppColors.success),
                  ],
                ),
        ),
        const SizedBox(height: 14),
        _card(
          title: 'Finished words',
          child: s.words.isEmpty
              ? _emptyText('No words finished yet')
              : Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final w in practiceWords)
                      if (s.words.containsKey(w.word))
                        _chip('${w.emoji} ${w.word}', AppColors.purple),
                    // words made from the child's own toys
                    for (final w in s.words.keys)
                      if (!practiceWords.any((p) => p.word == w))
                        _chip('${CustomWord.emoji} $w', AppColors.purple),
                  ],
                ),
        ),
        const SizedBox(height: 14),
        // ---- weak areas ----
        _card(
          title: 'Needs practice',
          child: s.weakLetters.isEmpty
              ? _emptyText('No weak areas — great job!')
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final g in s.weakLetters)
                          _chip('$g · ${s.letters[g]?['free'] ?? 0}%',
                              AppColors.primary),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'These letters were started but not finished. A little more practice will do it!',
                      style: kid(13, color: Colors.grey.shade600),
                    ),
                  ],
                ),
        ),
        const SizedBox(height: 30),
      ],
    );
  }

  Widget _statCard(String label, int done, int total, Color color) {
    return Expanded(
      child: KidCard(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Text('$done/$total',
                style: kid(20, weight: FontWeight.bold, color: color)),
            FittedBox(
              child: Text(label, style: kid(13, color: Colors.grey.shade600)),
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: total == 0 ? 0 : done / total,
                minHeight: 7,
                backgroundColor: Colors.grey.shade200,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _card({required String title, required Widget child}) {
    return KidCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: kid(16, weight: FontWeight.w600)),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }

  Widget _chip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(text, style: kid(14, weight: FontWeight.w600, color: color)),
    );
  }

  Widget _emptyText(String text) =>
      Text(text, style: kid(14, color: Colors.grey.shade500));
}
