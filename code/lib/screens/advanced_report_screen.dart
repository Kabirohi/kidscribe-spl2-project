import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/report/advanced_report_cubit.dart';
import '../services/family_service.dart';
import '../services/premium_service.dart';
import '../services/progress_service.dart';
import '../theme/app_colors.dart';
import '../widgets/common.dart';

/// Premium advanced report (SRS FR_21 / US_29).
/// Without premium it shows a lock and an upgrade message (SRS T_68).
class AdvancedReportScreen extends StatelessWidget {
  const AdvancedReportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (ctx) => AdvancedReportCubit(
        progress: ctx.read<ProgressService>(),
        premium: ctx.read<PremiumService>(),
        family: ctx.read<FamilyService>(),
      )..load(),
      child: BlocBuilder<AdvancedReportCubit, AdvancedReportState>(
        builder: (context, s) {
          return KidPage(
            child: Column(
              children: [
                const KidHeader('Advanced report', fontSize: 23),
                Expanded(
                  child: s.loading
                      ? const Center(child: CircularProgressIndicator())
                      : !s.isPremium
                          ? const _Locked()
                          : _Report(s),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Locked extends StatelessWidget {
  const _Locked();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.lock, size: 80, color: Color(0xFFF59E0B)),
          const SizedBox(height: 14),
          Text('This report is part of Premium',
              textAlign: TextAlign.center,
              style: kid(21, weight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(
            'Upgrade to Premium to see a chart for every letter, your '
            "child's weak letters, and two weeks of practice. Go back and "
            'tap "Buy premium".',
            textAlign: TextAlign.center,
            style: kid(15, color: Colors.grey.shade700),
          ),
        ],
      ),
    );
  }
}

class _Report extends StatelessWidget {
  final AdvancedReportState s;
  const _Report(this.s);

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        if (s.learnerName != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text('For ${s.learnerName}',
                style: kid(17, weight: FontWeight.w600, color: AppColors.purple)),
          ),
        // ---- weak letters ----
        KidCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Letters to practice next',
                  style: kid(17, weight: FontWeight.bold)),
              const SizedBox(height: 8),
              if (s.weakLetters.isEmpty)
                Text('No weak letters right now. Great work!',
                    style: kid(14, color: AppColors.success))
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final l in s.weakLetters)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.error.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text('${l.letter}  ${l.freePercent}%',
                            style: kid(16,
                                weight: FontWeight.bold,
                                color: AppColors.error)),
                      ),
                  ],
                ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        // ---- every letter ----
        KidCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Free-hand score for every letter',
                  style: kid(17, weight: FontWeight.bold)),
              Text('Green = passed (70% or more)',
                  style: kid(12, color: Colors.grey.shade600)),
              const SizedBox(height: 12),
              SizedBox(
                height: 150,
                child: _LetterBars(s.letters),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        // ---- last 14 days ----
        KidCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Practice in the last 14 days',
                  style: kid(17, weight: FontWeight.bold)),
              const SizedBox(height: 12),
              SizedBox(height: 110, child: _DayBars(s.last14Days)),
            ],
          ),
        ),
        const SizedBox(height: 14),
        KidCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Everything else', style: kid(17, weight: FontWeight.bold)),
              const SizedBox(height: 8),
              _row('Words written', '${s.wordsDone} / ${s.wordsTotal}'),
              _row('Sentences made', '${s.sentencesDone} / ${s.sentencesTotal}'),
              _row('Letter Match — best level', '${s.games['match_best'] ?? 0}'),
              _row('Letter Ninja — best round', '${s.games['ninja_best'] ?? 0}'),
              _row('Good free-writing letters', '${s.games['free_good'] ?? 0}'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _row(String a, String b) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Expanded(child: Text(a, style: kid(15))),
            Text(b, style: kid(15, weight: FontWeight.bold)),
          ],
        ),
      );
}

/// 26 thin bars, one per letter, height = best free-hand %.
class _LetterBars extends StatelessWidget {
  final List<LetterStat> letters;
  const _LetterBars(this.letters);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final w = c.maxWidth / max(letters.length, 1);
      return Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final l in letters)
            SizedBox(
              width: w,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Container(
                    height: max(2.0, (c.maxHeight - 18) * l.freePercent / 100),
                    margin: EdgeInsets.symmetric(horizontal: w * 0.15),
                    decoration: BoxDecoration(
                      color: l.complete
                          ? AppColors.success
                          : l.tried
                              ? AppColors.error.withValues(alpha: 0.7)
                              : Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(l.letter, style: kid(10)),
                ],
              ),
            ),
        ],
      );
    });
  }
}

/// 14 bars, one per day, height = how many checks were done.
class _DayBars extends StatelessWidget {
  final List<int> days;
  const _DayBars(this.days);

  @override
  Widget build(BuildContext context) {
    final top = max(1, days.fold<int>(0, max));
    return LayoutBuilder(builder: (context, c) {
      final w = c.maxWidth / max(days.length, 1);
      return Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < days.length; i++)
            SizedBox(
              width: w,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (days[i] > 0) Text('${days[i]}', style: kid(9)),
                  Container(
                    height: max(2.0, (c.maxHeight - 28) * days[i] / top),
                    margin: EdgeInsets.symmetric(horizontal: w * 0.18),
                    decoration: BoxDecoration(
                      color: i == days.length - 1
                          ? AppColors.primary
                          : AppColors.secondary,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(i == days.length - 1 ? 'today' : '',
                      style: kid(9, color: Colors.grey.shade600)),
                ],
              ),
            ),
        ],
      );
    });
  }
}
