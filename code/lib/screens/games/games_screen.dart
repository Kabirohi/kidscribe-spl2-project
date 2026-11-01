import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_colors.dart';
import '../../widgets/art.dart';
import '../../widgets/common.dart';
import '../../widgets/fun.dart';
import 'free_writing_screen.dart';
import 'letter_match_screen.dart';
import 'letter_ninja_screen.dart';

/// The three activities from the proposal: Free Writing, Letter Match and
/// Letter Ninja (SRS FR_11, FR_12, FR_13). This menu has no state of its
/// own, so it is a plain StatelessWidget — each game has its own cubit.
class GamesScreen extends StatelessWidget {
  const GamesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final games = [
      const _Game('writing_hand', Color(0xFF6C4BFF), 'Free Writing',
          'Write any letter — I will read it!', FreeWritingScreen()),
      const _Game('joker', Color(0xFF14B8A6), 'Letter Match',
          'Find the matching cards', LetterMatchScreen()),
      const _Game('ninja', Color(0xFFFF5FA2), 'Letter Ninja',
          'Write fast, beat the clock!', LetterNinjaScreen()),
    ];
    return KidPage(
      color: const Color(0xFFFF5FA2),
      child: Column(
        children: [
          const KidHeader('Games'),
          Expanded(
            child: LayoutBuilder(builder: (context, c) {
              final wide = c.maxWidth >= 760;
              final cards = [
                for (int i = 0; i < games.length; i++)
                  PopIn(
                    delay: Duration(milliseconds: 80 + i * 110),
                    child: _card(context, games[i], wide),
                  ),
              ];
              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                child: wide
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (int i = 0; i < cards.length; i++) ...[
                            if (i > 0) const SizedBox(width: 18),
                            Expanded(child: cards[i]),
                          ],
                        ],
                      )
                    : Column(
                        children: [
                          for (final card in cards)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 20),
                              child: card,
                            ),
                        ],
                      ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _card(BuildContext context, _Game g, bool tall) {
    void go() =>
        Navigator.push(context, MaterialPageRoute(builder: (_) => g.screen));
    final title = Text(g.title,
        style: GoogleFonts.fredoka(
            fontSize: 28, fontWeight: FontWeight.w600, color: Colors.white));
    final line = Text(g.line,
        maxLines: 2,
        style: GoogleFonts.nunito(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: Colors.white.withValues(alpha: 0.92)));
    final play = Container(
      width: 58,
      height: 58,
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: Color(0x332A1F5C), offset: Offset(0, 4))],
      ),
      child: Icon(Icons.play_arrow_rounded, size: 38, color: g.color),
    );

    return Bouncy(
      onTap: go,
      child: Container(
        height: tall ? 330 : 184,
        decoration: BoxDecoration(
          color: g.color,
          borderRadius: BorderRadius.circular(32),
          boxShadow: [
            BoxShadow(
                color: AppColors.ledge(g.color, 0.16),
                offset: const Offset(0, 7)),
            const BoxShadow(
                color: Color(0x222A1F5C),
                blurRadius: 20,
                offset: Offset(0, 12)),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(32),
          child: Stack(
            children: [
              Positioned(
                right: -50,
                top: -50,
                child: Container(
                  width: 220,
                  height: 220,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.15),
                  ),
                ),
              ),
              if (tall) ...[
                Positioned(
                    top: 26,
                    left: 0,
                    right: 0,
                    child: Center(child: KidArt(g.art, size: 150))),
                Positioned(
                  left: 22,
                  right: 22,
                  bottom: 22,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [title, line],
                        ),
                      ),
                      play,
                    ],
                  ),
                ),
              ] else ...[
                Positioned(right: 14, top: 14, child: KidArt(g.art, size: 130)),
                Positioned(
                  left: 22,
                  top: 22,
                  right: 150,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [title, const SizedBox(height: 2), line],
                  ),
                ),
                Positioned(left: 22, bottom: 20, child: play),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Game {
  final String art;
  final Color color;
  final String title;
  final String line;
  final Widget screen;
  const _Game(this.art, this.color, this.title, this.line, this.screen);
}
