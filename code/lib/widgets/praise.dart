import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_colors.dart';
import 'art.dart';
import 'common.dart';
import 'fun.dart';

/// Warm, varied praise shown after every activity, instead of a plain
/// "Good job!". Each message is a little card: a picture, a headline and a
/// sentence that tells the child WHY they did well.
///
/// Milestones get their own words: three wins in a row, halfway through a
/// stage, and finishing a whole stage. A miss gets encouragement, never
/// a telling-off, and the "what to fix" tip is shown kindly underneath.

class Praise {
  final String title;
  final String message;
  final String art; // a picture from assets/art
  final Color color; // card background
  final Color accent; // headline + button colour

  const Praise(this.title, this.message, this.art, this.color, this.accent);
}

/// Where the child is in their work, so milestones can be celebrated.
enum PraiseMoment { step, halfway, finished }

class PraiseBook {
  PraiseBook._();

  static int _turn = 0; // rotates the everyday praise
  static int _streak = 0; // wins in a row this session
  static int _miss = 0;

  static const _everyday = [
    Praise(
        "You're Absolutely Amazing!",
        'You did it! Every step you take makes you smarter and stronger. '
            'Keep shining, little superstar!',
        'glowing_star',
        Color(0xFFFFF4D1),
        Color(0xFFD98A00)),
    Praise(
        "Look Who's a Genius!",
        'Wow! You conquered another challenge. Your hard work is turning '
            'you into an incredible learner!',
        'light_bulb',
        Color(0xFFDDF1FF),
        Color(0xFF1C7FC4)),
    Praise(
        "You're a Champion!",
        'Another mission completed! You showed determination, courage and '
            'a brilliant mind. Be proud of yourself!',
        'crown',
        Color(0xFFEDE5FF),
        Color(0xFF6C4BFF)),
    Praise(
        "You're Going Places!",
        'One more step toward your dreams! Your effort today is building an '
            'amazing future. Keep up the fantastic work!',
        'rocket',
        Color(0xFFDDF7E8),
        Color(0xFF15935A)),
    Praise(
        'You Should Be So Proud!',
        'You kept going, and you made it! That is what makes you special. '
            'Every little victory deserves a big celebration!',
        'red_heart',
        Color(0xFFFFE3EC),
        Color(0xFFD6336C)),
    Praise(
        'A Super Learner in Action!',
        'You faced your challenge and came out stronger. That is real '
            'superhero energy! What is your next adventure?',
        'high_voltage',
        Color(0xFFE2F0FF),
        Color(0xFF3B6FD9)),
  ];

  static const _threeInARow = Praise(
      'Three in a Row!',
      'Whoa! Three victories in a row! You are unstoppable!',
      'fire',
      Color(0xFFFFE8D6),
      Color(0xFFE0590B));

  static const _halfway = Praise(
      'Look How Far You Have Come!',
      'You are halfway there! Your dedication is incredible. Keep going!',
      'chequered_flag',
      Color(0xFFE5F6FF),
      Color(0xFF1C7FC4));

  static const _finished = Praise(
      'YOU DID IT!',
      'You finished every single one! That takes real practice and a '
          'brave heart. Time to celebrate!',
      'trophy',
      Color(0xFFFFF1C7),
      Color(0xFFC77700));

  static const _tryAgain = [
    Praise(
        'So Close!',
        'You are nearly there. Take a deep breath and try once more. '
            'You can do it!',
        'flexed_biceps',
        Color(0xFFFFF0E0),
        Color(0xFFE0700B)),
    Praise(
        'Great Try!',
        'Every try makes your hand a little stronger. Let us do it again '
            'together!',
        'thumbs_up',
        Color(0xFFEAF2FF),
        Color(0xFF3B6FD9)),
    Praise(
        'Practice Makes Progress!',
        'Mistakes help us learn. Look at the tip below and give it '
            'another go!',
        'sparkles',
        Color(0xFFF1EAFF),
        Color(0xFF6C4BFF)),
  ];

  /// Picks the right words for this result.
  static Praise pick(
      {required bool passed, PraiseMoment moment = PraiseMoment.step}) {
    if (!passed) {
      _streak = 0;
      return _tryAgain[_miss++ % _tryAgain.length];
    }
    _streak++;
    if (moment == PraiseMoment.finished) return _finished;
    if (moment == PraiseMoment.halfway) return _halfway;
    if (_streak > 0 && _streak % 3 == 0) return _threeInARow;
    return _everyday[_turn++ % _everyday.length];
  }

  /// Which milestone the item at [index] (0-based) of [total] is.
  static PraiseMoment momentFor(int index, int total) {
    if (total <= 1) return PraiseMoment.step;
    if (index == total - 1) return PraiseMoment.finished;
    if (total >= 4 && index == (total / 2).ceil() - 1) {
      return PraiseMoment.halfway;
    }
    return PraiseMoment.step;
  }
}

/// A button on the praise card.
class PraiseAction {
  final String label;
  final VoidCallback onTap;
  final bool primary;
  const PraiseAction(this.label, this.onTap, {this.primary = false});
}

/// Shows the praise card. [score] sits under the message (stars or a
/// percentage); [tip] is the friendly "what to fix" line; [grownUp] adds
/// a small note for parents and teachers.
Future<void> showPraiseCard(
  BuildContext context, {
  required Praise praise,
  Widget? score,
  String? tip,
  String? grownUp,
  required List<PraiseAction> Function(BuildContext dialog) actions,
  bool dismissible = false,
}) {
  return showGeneralDialog(
    context: context,
    barrierDismissible: dismissible,
    barrierLabel: 'praise',
    barrierColor: const Color(0x991B1257),
    transitionDuration: const Duration(milliseconds: 450),
    transitionBuilder: (ctx, a, _, child) => ScaleTransition(
      scale: CurvedAnimation(parent: a, curve: Curves.elasticOut),
      child: FadeTransition(opacity: a, child: child),
    ),
    pageBuilder: (ctx, _, __) {
      final buttons = actions(ctx);
      return Center(
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: 420,
            margin: const EdgeInsets.all(24),
            constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(ctx).height * 0.9),
            decoration: BoxDecoration(
              color: praise.color,
              borderRadius: BorderRadius.circular(34),
              border: Border.all(color: Colors.white, width: 5),
              boxShadow: [
                BoxShadow(
                    color: praise.accent.withValues(alpha: 0.35),
                    offset: const Offset(0, 8)),
              ],
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 22, 24, 22),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  PopIn(child: KidArt(praise.art, size: 96)),
                  const SizedBox(height: 8),
                  Text(praise.title,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.fredoka(
                          fontSize: 28,
                          fontWeight: FontWeight.w600,
                          height: 1.1,
                          color: praise.accent)),
                  const SizedBox(height: 8),
                  Text(praise.message,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.nunito(
                          fontSize: 16.5,
                          fontWeight: FontWeight.w700,
                          height: 1.35,
                          color: AppColors.textDark)),
                  if (score != null) ...[
                    const SizedBox(height: 14),
                    score,
                  ],
                  if (tip != null && tip.trim().isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(12, 10, 14, 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.lightbulb_rounded,
                              size: 22, color: praise.accent),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(tip.trim(),
                                style: GoogleFonts.nunito(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textDark)),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (grownUp != null) ...[
                    const SizedBox(height: 12),
                    Theme(
                      data: Theme.of(ctx)
                          .copyWith(dividerColor: Colors.transparent),
                      child: ExpansionTile(
                        tilePadding: EdgeInsets.zero,
                        title: Text('For grown-ups',
                            style: GoogleFonts.nunito(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textMuted)),
                        children: [
                          Text(grownUp,
                              style: GoogleFonts.nunito(
                                  fontSize: 13.5,
                                  height: 1.4,
                                  color: AppColors.textMuted)),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      for (int i = 0; i < buttons.length; i++) ...[
                        if (i > 0) const SizedBox(width: 12),
                        Expanded(
                          child: buttons[i].primary
                              ? KidButton(buttons[i].label,
                                  color: praise.accent,
                                  height: 52,
                                  onPressed: buttons[i].onTap)
                              : KidOutlineButton(buttons[i].label,
                                  color: praise.accent,
                                  height: 52,
                                  onPressed: buttons[i].onTap),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}

/// Three big stars for a 0..3 star result.
Widget praiseStars(int stars) => Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (int i = 0; i < 3; i++)
          Icon(Icons.star_rounded,
              size: 46,
              color: i < stars
                  ? const Color(0xFFFFB800)
                  : const Color(0x33000000)),
      ],
    );

/// A big percentage, for free-hand checks.
Widget praisePercent(int percent, Color color) => Text('$percent%',
    style: GoogleFonts.fredoka(
        fontSize: 44, fontWeight: FontWeight.w600, color: color));
