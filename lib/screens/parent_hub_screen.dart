import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/premium/premium_cubit.dart';
import '../blocs/sync/sync_cubit.dart';
import '../services/premium_service.dart';
import '../services/sync_service.dart';
import '../theme/app_colors.dart';
import '../widgets/common.dart';
import 'advanced_report_screen.dart';

/// Stage 5 of the proposal — "Parent Sync & Premium":
///  - sync progress across devices   (SRS FR_20 / US_27)
///  - the premium plan               (SRS FR_21 / US_28)
///  - advanced reports (premium)     (SRS FR_21 / US_29)
class ParentHubScreen extends StatelessWidget {
  const ParentHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
            create: (ctx) =>
                SyncCubit(sync: ctx.read<SyncService>())..load()),
        BlocProvider(
            create: (ctx) =>
                PremiumCubit(premium: ctx.read<PremiumService>())..load()),
      ],
      child: MultiBlocListener(
        listeners: [
          BlocListener<SyncCubit, SyncState>(
            listenWhen: (a, b) => a.messageTick != b.messageTick,
            listener: (context, s) => showKidSnack(context, s.message!,
                color: s.lastOutcome == SyncOutcome.synced
                    ? AppColors.success
                    : AppColors.error),
          ),
          BlocListener<PremiumCubit, PremiumState>(
            listenWhen: (a, b) => a.messageTick != b.messageTick,
            listener: (context, s) => showKidSnack(context, s.message!,
                color: s.messageIsError ? AppColors.error : AppColors.success),
          ),
        ],
        child: KidPage(
          child: Column(
            children: [
              const KidHeader('Sync & Premium'),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                  children: const [
                    _SyncCard(),
                    SizedBox(height: 16),
                    _PremiumCard(),
                    SizedBox(height: 16),
                    _ReportCard(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SyncCard extends StatelessWidget {
  const _SyncCard();

  String _when(DateTime? d) {
    if (d == null) return 'Never synced yet';
    final mins = DateTime.now().difference(d).inMinutes;
    if (mins < 1) return 'Last synced just now';
    if (mins < 60) return 'Last synced $mins min ago';
    return 'Last synced ${d.day}/${d.month} at ${d.hour}:${d.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SyncCubit, SyncState>(
      builder: (context, s) {
        final cubit = context.read<SyncCubit>();
        return KidCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const KidIconBadge(Icons.cloud_sync_rounded,
                      color: AppColors.secondary, size: 48),
                  const SizedBox(width: 14),
                  Text('Sync across devices',
                      style: kid(20, weight: FontWeight.w900)),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'See the same progress on your phone and your child\'s '
                'tablet. Nothing is lost: when two devices differ, we keep '
                'the best of both.',
                style: kid(14, color: AppColors.textMuted),
              ),
              const SizedBox(height: 8),
              Text(_when(s.lastSync),
                  style: kid(14,
                      weight: FontWeight.w800, color: AppColors.primary)),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                activeThumbColor: AppColors.secondary,
                title: Text('Sync by itself when the app opens',
                    style: kid(15)),
                value: s.auto,
                onChanged: s.syncing ? null : cubit.setAuto,
              ),
              KidButton('Sync now',
                  color: AppColors.secondary,
                  busy: s.syncing,
                  onPressed: cubit.syncNow),
            ],
          ),
        );
      },
    );
  }
}

class _PremiumCard extends StatelessWidget {
  const _PremiumCard();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PremiumCubit, PremiumState>(
      builder: (context, s) {
        final cubit = context.read<PremiumCubit>();

        // Already premium: a calm white card with a gold outline.
        if (s.isPremium) {
          return KidCard(
            borderColor: AppColors.gold,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const KidIconBadge(Icons.workspace_premium_rounded,
                        color: AppColors.gold, size: 48),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text('KidScribe Premium',
                          style: kid(20, weight: FontWeight.w900)),
                    ),
                    // Payment status, shown to the parent (SRS US_28).
                    const KidTag('Active ✓', color: AppColors.success),
                  ],
                ),
                const SizedBox(height: 14),
                for (final f in PremiumService.features)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.check_circle_rounded,
                            size: 20, color: AppColors.success),
                        const SizedBox(width: 10),
                        Expanded(child: Text(f, style: kid(15))),
                      ],
                    ),
                  ),
                const SizedBox(height: 6),
                if (s.since != null)
                  Text(
                      'Active since ${s.since!.day}/${s.since!.month}/${s.since!.year}',
                      style: kid(14, color: AppColors.textMuted)),
                TextButton(
                  onPressed: cubit.cancel,
                  style: TextButton.styleFrom(foregroundColor: AppColors.error),
                  child: const Text('Cancel premium'),
                ),
              ],
            ),
          );
        }

        // Not premium yet: the upgrade card.
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: AppColors.heroGradient,
            borderRadius: BorderRadius.circular(30),
            boxShadow: const [
              BoxShadow(color: Color(0xFF4A2BC4), offset: Offset(0, 5)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const KidIconBadge(Icons.workspace_premium_rounded,
                      color: AppColors.accent, size: 48),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text('Unlock KidScribe Premium',
                        style: kid(22,
                            weight: FontWeight.w900, color: Colors.white)),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              for (final f in PremiumService.features)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.check_circle_rounded,
                          size: 20, color: AppColors.sun),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(f,
                            style: kid(15,
                                weight: FontWeight.w700, color: Colors.white)),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Text(PremiumService.priceText,
                    textAlign: TextAlign.center,
                    style: kid(17, weight: FontWeight.w900, color: Colors.white)),
              ),
              const SizedBox(height: 8),
              Text(
                'This is a DEMO payment for our class project: no money is '
                'taken and no card details are asked for.',
                style: kid(12.5,
                    weight: FontWeight.w600,
                    color: Colors.white.withValues(alpha: 0.8)),
              ),
              const SizedBox(height: 16),
              KidButton('Buy premium (demo)',
                  color: AppColors.accent,
                  busy: s.paying,
                  onPressed: () => cubit.buy()),
              Center(
                child: TextButton(
                  onPressed: s.paying
                      ? null
                      : () => cubit.buy(simulateFailure: true),
                  style: TextButton.styleFrom(foregroundColor: Colors.white),
                  child: const Text('Test a failed payment'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ReportCard extends StatelessWidget {
  const _ReportCard();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PremiumCubit, PremiumState>(
      builder: (context, s) {
        return KidCard(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AdvancedReportScreen()),
            ).then((_) {
              if (context.mounted) context.read<PremiumCubit>().load();
            });
          },
          child: Row(
            children: [
              KidIconBadge(
                  s.isPremium ? Icons.bar_chart_rounded : Icons.lock_rounded,
                  color: AppColors.purple,
                  size: 48),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Advanced report',
                        style: kid(20, weight: FontWeight.w900)),
                    Text(
                        s.isPremium
                            ? 'Charts for every letter and the weak spots'
                            : 'Premium only — tap to see',
                        style: kid(14, color: AppColors.textMuted)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded,
                  size: 30, color: AppColors.purple),
            ],
          ),
        );
      },
    );
  }
}
