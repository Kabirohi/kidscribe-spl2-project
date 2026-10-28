import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../blocs/learn/letter_levels_cubit.dart';
import '../../data/trace_templates.dart';
import '../../services/progress_service.dart';
import '../../theme/app_colors.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../widgets/common.dart';
import '../../widgets/fun.dart';
import 'letter_practice_screen.dart';

/// Stage 2 as a LEVEL PATH: all 26 letters in order (easiest family first).
/// Each level unlocks only when the one before it is fully complete
/// (guided side passed + free-hand side >= 70%).
class LetterLevelsScreen extends StatelessWidget {
  const LetterLevelsScreen({super.key});

  static const _familyColors = [
    Color(0xFF6C4BFF),
    Color(0xFF14B8A6),
    Color(0xFFFF5FA2),
    Color(0xFFFFA41B),
  ];

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (ctx) =>
          LetterLevelsCubit(progress: ctx.read<ProgressService>())..load(),
      child: BlocBuilder<LetterLevelsCubit, LetterLevelsState>(
        builder: (context, s) {
          // Global level number for each letter (card shows "Level 8" etc.)
          var level = 0;
          return KidPage(
            color: const Color(0xFF6C4BFF),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const KidHeader('Letter Levels'),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(10, 8, 16, 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: const [
                        BoxShadow(color: AppColors.line, offset: Offset(0, 3)),
                      ],
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.lightbulb_rounded,
                            size: 28, color: Color(0xFFFFB800)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                              'Trace it, then write it on your own to unlock the next letter!',
                              style: kid(14,
                                  weight: FontWeight.w700,
                                  color: AppColors.textMuted)),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Expanded(
                  child: s.loading
                      ? const Center(child: CircularProgressIndicator())
                      : ListView(
                          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                          children: [
                            for (var f = 0; f < letterFamilies.length; f++) ...[
                              Padding(
                                padding:
                                    const EdgeInsets.fromLTRB(2, 22, 2, 14),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 14, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: _familyColors[
                                            f % _familyColors.length],
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: Text(letterFamilies[f].name,
                                          style: GoogleFonts.fredoka(
                                              fontSize: 18,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.white)),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        letterFamilies[f].description,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: kid(14,
                                            weight: FontWeight.w700,
                                            color: AppColors.textMuted),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Wrap(
                                spacing: 12,
                                runSpacing: 16,
                                children: [
                                  for (final item in letterFamilies[f].items)
                                    _levelChip(
                                        context,
                                        s,
                                        item.glyph,
                                        level++,
                                        _familyColors[
                                            f % _familyColors.length]),
                                ],
                              ),
                            ],
                            const SizedBox(height: 20),
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

  Widget _levelChip(BuildContext context, LetterLevelsState s, String glyph,
      int level, Color color) {
    final entry = s.letters[glyph];
    final complete = s.isComplete(glyph);
    final unlocked = s.isUnlocked(level);
    final guidedDone = (entry?['guided'] ?? 0) > 0;
    final freeBest = entry?['free'] ?? 0;

    final isNext = unlocked && !complete;
    final face = complete
        ? color
        : unlocked
            ? Colors.white
            : const Color(0xFFECE9F7);

    return Bouncy(
      onTap: () {
        if (!unlocked) {
          showKidSnack(context,
              'Finish letter ${allLetterItems[level - 1].glyph} first!');
          return;
        }
        final cubit = context.read<LetterLevelsCubit>();
        Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => LetterPracticeScreen(levelIndex: level)),
        ).then((_) => cubit.load());
      },
      child: SizedBox(
        width: 92,
        child: Column(
          children: [
            Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                Container(
                  width: 82,
                  height: 82,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: face,
                    shape: BoxShape.circle,
                    border: isNext
                        ? Border.all(color: color, width: 5)
                        : Border.all(color: Colors.white, width: 4),
                    boxShadow: [
                      BoxShadow(
                        color: complete
                            ? AppColors.ledge(color, 0.16)
                            : unlocked
                                ? color.withValues(alpha: 0.35)
                                : const Color(0xFFDCD8EE),
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: unlocked
                      ? Text(glyph,
                          style: GoogleFonts.fredoka(
                              fontSize: 38,
                              fontWeight: FontWeight.w600,
                              color: complete ? Colors.white : color))
                      : const Icon(Icons.lock_rounded,
                          size: 28, color: Color(0xFFB9B5D3)),
                ),
                if (complete)
                  Positioned(
                    right: -4,
                    top: -6,
                    child: Container(
                      decoration: const BoxDecoration(
                          color: Colors.white, shape: BoxShape.circle),
                      padding: const EdgeInsets.all(2),
                      child: const Icon(Icons.star_rounded,
                          size: 26, color: Color(0xFFFFB800)),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            // Two mini marks: traced (pencil) + written alone (robot check).
            Opacity(
              opacity: unlocked ? 1 : 0.4,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _mark(Icons.edit_rounded, guidedDone),
                  const SizedBox(width: 4),
                  _mark(Icons.smart_toy_rounded,
                      freeBest >= ProgressService.freePassPercent,
                      label: freeBest > 0 &&
                              freeBest < ProgressService.freePassPercent
                          ? '$freeBest%'
                          : null),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _mark(IconData icon, bool done, {String? label}) => Container(
        padding: const EdgeInsets.fromLTRB(3, 2, 6, 2),
        decoration: BoxDecoration(
          color: done ? const Color(0xFFDDF7E8) : Colors.white,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 14,
                color: done ? AppColors.success : const Color(0xFFB9B5D3)),
            const SizedBox(width: 2),
            if (label != null)
              Text(label,
                  style: kid(10.5,
                      weight: FontWeight.w900, color: AppColors.textMuted))
            else
              Icon(done ? Icons.check_rounded : Icons.remove_rounded,
                  size: 13,
                  color: done ? AppColors.success : const Color(0xFFC9C5DD)),
          ],
        ),
      );
}
