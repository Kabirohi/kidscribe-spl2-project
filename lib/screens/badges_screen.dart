import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/badges/badges_cubit.dart';
import '../services/badge_service.dart';
import '../services/progress_service.dart';
import '../theme/app_colors.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/art.dart';
import '../widgets/common.dart';
import '../widgets/fun.dart';

/// The badge gallery + daily streak (SRS FR_14 / US_18): earned badges
/// in colour, locked ones greyed with how to earn them.
class BadgesScreen extends StatelessWidget {
  const BadgesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (ctx) => BadgesCubit(
        badges: ctx.read<BadgeService>(),
        progress: ctx.read<ProgressService>(),
      )..load(),
      child: BlocBuilder<BadgesCubit, BadgesState>(
        builder: (context, s) {
          final width = MediaQuery.of(context).size.width;
          final columns = width > 900 ? 5 : width > 560 ? 4 : 3;
          return KidPage(
            color: const Color(0xFFFFA41B),
            child: Column(
              children: [
                KidHeader('My Badges', actions: [
                  Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: KidTag('${s.earned.length}/${allBadges.length}',
                        color: const Color(0xFFD97F00), solid: true),
                  ),
                ]),
                Expanded(
                  child: s.loading
                      ? const Center(child: CircularProgressIndicator())
                      : ListView(
                          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                          children: [
                            _streakCard(s),
                            const SizedBox(height: 18),
                            GridView.count(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              crossAxisCount: columns,
                              mainAxisSpacing: 18,
                              crossAxisSpacing: 16,
                              childAspectRatio: 0.82,
                              children: [
                                for (int i = 0; i < allBadges.length; i++)
                                  PopIn(
                                    delay: Duration(milliseconds: 60 + i * 40),
                                    child: _badge(allBadges[i],
                                        s.earned.contains(allBadges[i].id)),
                                  ),
                              ],
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

  Widget _streakCard(BadgesState s) {
    final lit = s.streak > 0;
    final color = lit ? const Color(0xFFFF7A2F) : AppColors.primary;
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 20, 16, 20),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
              color: AppColors.ledge(color, 0.16), offset: const Offset(0, 6)),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(lit ? '${s.streak}-day streak!' : 'No streak yet',
                    style: GoogleFonts.fredoka(
                        fontSize: 28,
                        fontWeight: FontWeight.w600,
                        color: Colors.white)),
                const SizedBox(height: 2),
                Text(
                  !lit
                      ? 'Practice today to light the fire!'
                      : s.practicedToday
                          ? 'Practiced today — keep it up!'
                          : 'Practice today to keep your streak!',
                  style: kid(14.5,
                      weight: FontWeight.w800,
                      color: Colors.white.withValues(alpha: 0.95)),
                ),
                if (s.best > 0) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                        'Best ever: ${s.best} day${s.best == 1 ? '' : 's'}',
                        style: kid(13,
                            weight: FontWeight.w900, color: Colors.white)),
                  ),
                ],
              ],
            ),
          ),
          KidArt(lit ? 'fire' : 'candle', size: 92),
        ],
      ),
    );
  }

  /// Earned badges are bright stickers; the rest are empty sticker slots.
  Widget _badge(BadgeDef b, bool earned) => Column(
        children: [
          Expanded(
            child: AspectRatio(
              aspectRatio: 1,
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: earned ? Colors.white : const Color(0xFFECE9F7),
                  border: Border.all(
                      color: earned ? AppColors.sun : const Color(0xFFDCD8EE),
                      width: earned ? 5 : 3),
                  boxShadow: earned
                      ? const [
                          BoxShadow(
                              color: Color(0xFFF3C969), offset: Offset(0, 5)),
                        ]
                      : null,
                ),
                padding: const EdgeInsets.all(14),
                child: FittedBox(
                    child: KidEmoji(b.emoji, size: 80, grey: !earned)),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(b.name,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.fredoka(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: earned ? AppColors.textDark : AppColors.textMuted)),
          Text(b.description,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: kid(12, color: AppColors.textMuted)),
        ],
      );
}
