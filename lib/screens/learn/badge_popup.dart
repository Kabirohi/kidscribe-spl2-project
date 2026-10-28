import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/badge_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/art.dart';
import '../../widgets/common.dart';
import '../../widgets/fun.dart';

/// Celebrates freshly earned badges (SRS T_43: finish a task ->
/// the badge is given and SHOWN). Does nothing when the list is empty.
Future<void> showBadgePopup(BuildContext context, List<BadgeDef> badges) async {
  if (badges.isEmpty) return;
  await showGeneralDialog(
    context: context,
    barrierDismissible: false,
    barrierColor: const Color(0xB31B1257),
    transitionDuration: const Duration(milliseconds: 500),
    transitionBuilder: (ctx, a, _, child) => ScaleTransition(
      scale: CurvedAnimation(parent: a, curve: Curves.elasticOut),
      child: FadeTransition(opacity: a, child: child),
    ),
    pageBuilder: (ctx, _, __) => Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 360,
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.fromLTRB(24, 26, 24, 22),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(34),
            boxShadow: const [
              BoxShadow(color: Color(0xFFF3C969), offset: Offset(0, 8)),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(badges.length == 1 ? 'New badge!' : 'New badges!',
                  style: GoogleFonts.fredoka(
                      fontSize: 30,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary)),
              const SizedBox(height: 12),
              for (int i = 0; i < badges.length; i++)
                PopIn(
                  delay: Duration(milliseconds: 250 + i * 200),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Column(
                      children: [
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            Container(
                              width: badges.length == 1 ? 150 : 96,
                              height: badges.length == 1 ? 150 : 96,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: const Color(0xFFFFF4D6),
                                border:
                                    Border.all(color: AppColors.sun, width: 5),
                              ),
                            ),
                            KidEmoji(badges[i].emoji,
                                size: badges.length == 1 ? 96 : 60),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(badges[i].name,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.fredoka(
                                fontSize: 22,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textDark)),
                        Text(badges[i].description,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.nunito(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textMuted)),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              KidButton('Yay!',
                  color: AppColors.accent, onPressed: () => Navigator.pop(ctx)),
            ],
          ),
        ),
      ),
    ),
  );
}
