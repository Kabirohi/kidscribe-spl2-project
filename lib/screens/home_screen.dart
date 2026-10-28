import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import '../blocs/auth/auth_bloc.dart';
import '../blocs/home/home_cubit.dart';
import '../services/assignment_service.dart';
import '../services/badge_service.dart';
import '../services/family_service.dart';
import '../services/sync_service.dart';
import '../theme/app_colors.dart';
import '../widgets/art.dart';
import '../widgets/common.dart';
import '../widgets/fun.dart';
import '../widgets/mascot.dart';
import '../widgets/parent_gate.dart';
import 'badges_screen.dart';
import 'children_screen.dart';
import 'classes_screen.dart';
import 'games/games_screen.dart';
import 'parent_hub_screen.dart';
import 'toy_words_screen.dart';
import 'learn/my_tasks_screen.dart';
import 'learn/stages_screen.dart';
import 'progress_screen.dart';
import 'reminder_screen.dart';

/// The home screen. It builds its own HomeCubit and only draws state.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (ctx) => HomeCubit(
        family: ctx.read<FamilyService>(),
        badges: ctx.read<BadgeService>(),
        assignments: ctx.read<AssignmentService>(),
        sync: ctx.read<SyncService>(),
      )..load(context.read<AuthBloc>().state.user),
      child: const _HomeView(),
    );
  }
}

class _HomeView extends StatelessWidget {
  const _HomeView();

  /// Reloads the home data — used after coming back from another screen.
  void _refresh(BuildContext context) {
    context.read<HomeCubit>().load(context.read<AuthBloc>().state.user);
  }

  void _open(BuildContext context, Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen))
        .then((_) {
      if (context.mounted) _refresh(context);
    });
  }

  /// Grown-up areas (sync, premium) ask for a year of birth first.
  Future<void> _openGated(BuildContext context, Widget screen) async {
    final ok = await askParentGate(context);
    if (ok && context.mounted) _open(context, screen);
  }

  void _snack(BuildContext context, String msg) => showKidSnack(context, msg);

  /// Tapped "Start Learning" with nobody chosen: say why, then help.
  void _askForLearner(BuildContext context, HomeState s) {
    if (s.user?.role == 'Teacher') {
      _snack(context,
          'Pick a student first! Open My Classes and tap a student.');
      _open(context, const ClassesScreen());
      return;
    }
    _snack(
        context,
        s.childCount == 0
            ? 'Add your child first, then they can start learning!'
            : 'Tap your child to start their practice!');
    _open(context, const ChildrenScreen());
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<HomeCubit, HomeState>(
      builder: (context, s) {
        final kids = _kidTiles(context, s);
        final grown = _grownUpRows(context, s);
        return Scaffold(
          backgroundColor: AppColors.bgStart,
          body: s.loading
              ? const _Loading()
              : SingleChildScrollView(
                  child: Column(
                    children: [
                      _header(context, s),
                      Align(
                        alignment: Alignment.topCenter,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 1100),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _sectionTitle('Play & learn'),
                                const SizedBox(height: 14),
                                _grid(kids),
                                if (grown.isNotEmpty) ...[
                                  const SizedBox(height: 34),
                                  _grownUpTitle(),
                                  const SizedBox(height: 12),
                                  _grownUpPanel(grown),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
        );
      },
    );
  }

  Widget _sectionTitle(String text) => PopIn(
        delay: const Duration(milliseconds: 200),
        child: Text(text,
            style: GoogleFonts.fredoka(
                fontSize: 26,
                fontWeight: FontWeight.w600,
                color: AppColors.textDark)),
      );

  // ---- Colourful header: top bar, greeting and the hero card ----------
  Widget _header(BuildContext context, HomeState s) {
    return Stack(
      children: [
        Positioned.fill(
          bottom: 60,
          child: Container(
            color: AppColors.primary,
            child: Stack(
              children: [
                Positioned(right: -60, top: -40, child: _blob(220, 0.08)),
                Positioned(left: -50, top: 120, child: _blob(150, 0.06)),
                Positioned(right: 140, top: 30, child: _blob(26, 0.14)),
              ],
            ),
          ),
        ),
        const Positioned(
          left: 0,
          right: 0,
          bottom: 30,
          child:
              RollingWave(color: AppColors.bgStart, height: 60, amplitude: 10),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: 31,
          child: Container(color: AppColors.bgStart),
        ),
        SafeArea(
          bottom: false,
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1100),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 30),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _topBar(context, s),
                    const SizedBox(height: 22),
                    PopIn(child: _greeting(s)),
                    const SizedBox(height: 20),
                    PopIn(
                        delay: const Duration(milliseconds: 120),
                        child: _hero(context, s)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  static Widget _blob(double size, double alpha) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: alpha),
        ),
      );

  // ---- Top bar ---------------------------------------------------------
  Widget _topBar(BuildContext context, HomeState s) {
    final name = (s.user?.name ?? '').trim();
    final initial = name.isEmpty ? '?' : name.substring(0, 1).toUpperCase();
    final isParent = s.user?.role == 'Parent';

    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.sun,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
          ),
          child: Text(initial,
              style: GoogleFonts.fredoka(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark)),
        ),
        const SizedBox(width: 10),
        Text('KidScribe',
            style: GoogleFonts.fredoka(
                fontSize: 26,
                fontWeight: FontWeight.w600,
                color: Colors.white)),
        const Spacer(),
        if (isParent) ...[
          Bouncy(
            onTap: () => _openGated(context, const ParentHubScreen()),
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 8, 16, 8),
              decoration: BoxDecoration(
                color: AppColors.sun,
                borderRadius: BorderRadius.circular(30),
                boxShadow: const [
                  BoxShadow(color: Color(0xFFE0A100), offset: Offset(0, 3)),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.workspace_premium_rounded,
                      size: 24, color: AppColors.textDark),
                  const SizedBox(width: 6),
                  Text('Premium',
                      style: GoogleFonts.nunito(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: AppColors.textDark)),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
        ],
        Bouncy(
          onTap: () =>
              context.read<AuthBloc>().add(const AuthLogoutRequested()),
          child: Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              shape: BoxShape.circle,
            ),
            child:
                const Icon(Icons.logout_rounded, color: Colors.white, size: 22),
          ),
        ),
      ],
    );
  }

  // ---- Greeting --------------------------------------------------------
  Widget _greeting(HomeState s) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Flexible(
              child: Text('Hi, ${s.user?.name ?? 'Friend'}!',
                  style: GoogleFonts.fredoka(
                      fontSize: 36,
                      fontWeight: FontWeight.w600,
                      height: 1.1,
                      color: Colors.white)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 8,
          children: [
            if (s.streak > 0)
              _stat(Icons.local_fire_department_rounded,
                  const Color(0xFFFF6A00), '${s.streak} days'),
            _stat(Icons.star_rounded, const Color(0xFFFFB800),
                '${s.badgesEarned} badges'),
            _plainPill('${s.user?.role ?? 'User'} account'),
          ],
        ),
      ],
    );
  }

  Widget _stat(IconData icon, Color color, String text) => Container(
        padding: const EdgeInsets.fromLTRB(8, 6, 14, 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 22, color: color),
            const SizedBox(width: 5),
            Text(text,
                style: GoogleFonts.nunito(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textDark)),
          ],
        ),
      );

  Widget _plainPill(String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(22),
        ),
        child: Text(text,
            style: GoogleFonts.nunito(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: Colors.white)),
      );

  // ---- Hero: Start Learning -------------------------------------------
  /// Only a child may practice, so this card is locked until a grown-up
  /// picks who is learning.
  Widget _hero(BuildContext context, HomeState s) {
    final open = s.canLearn;
    final subtitle = open
        ? 'Lines, curves and letters are waiting'
        : (s.user?.role == 'Teacher'
            ? 'Pick a student in My Classes first'
            : s.childCount == 0
                ? 'Add your child first — only children can practice'
                : 'Tap your child in My Children to start');
    final bubble = open
        ? "Let's write, ${s.learnerName ?? 'friend'}!"
        : 'Who is writing today?';
    void go() => open
        ? _open(context, const StagesScreen())
        : _askForLearner(context, s);

    return Bouncy(
      onTap: go,
      pressedScale: 0.97,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: const Color(0xFFFF8A3D),
          borderRadius: BorderRadius.circular(34),
          boxShadow: const [
            BoxShadow(color: Color(0xFFD9601A), offset: Offset(0, 7)),
            BoxShadow(
                color: Color(0x332A1F5C),
                blurRadius: 24,
                offset: Offset(0, 14)),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(34),
          child: Stack(
            children: [
              Positioned(right: -40, bottom: -70, child: _blob(230, 0.14)),
              Positioned(left: -30, top: -40, child: _blob(110, 0.10)),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 22, 14, 22),
                child: LayoutBuilder(
                  builder: (context, c) {
                    final compact = c.maxWidth < 520;
                    final text = Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Start learning',
                            style: GoogleFonts.fredoka(
                                fontSize: compact ? 30 : 38,
                                fontWeight: FontWeight.w600,
                                height: 1.05,
                                color: Colors.white)),
                        const SizedBox(height: 6),
                        Text(subtitle,
                            style: GoogleFonts.nunito(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: Colors.white.withValues(alpha: 0.95))),
                        const SizedBox(height: 18),
                        SizedBox(
                          width: compact ? 190 : 230,
                          child: KidButton(
                            open ? "Let's write!" : 'Choose a learner',
                            color:
                                open ? AppColors.primary : AppColors.nightCard,
                            onPressed: go,
                          ),
                        ),
                      ],
                    );
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(child: text),
                        const SizedBox(width: 4),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (!compact) SpeechBubble(bubble),
                            PennyMascot(size: compact ? 118 : 180, happy: open),
                          ],
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---- Kid tiles: big, bright, picture first ---------------------------
  List<Widget> _kidTiles(BuildContext context, HomeState s) {
    final isParent = s.user?.role == 'Parent';
    return [
      if (s.canLearn) ...[
        _tile(context,
            art: 'video_game',
            color: const Color(0xFFFF5FA2),
            title: 'Games',
            screen: const GamesScreen()),
        _tile(context,
            art: 'clipboard',
            color: const Color(0xFF2EB5F0),
            title: 'My Tasks',
            screen: const MyTasksScreen(),
            count: s.openTasks),
      ],
      _tile(context,
          art: 'trophy',
          color: const Color(0xFFFFB020),
          title: 'My Badges',
          caption: '${s.badgesEarned}/${s.badgesTotal}',
          screen: const BadgesScreen()),
      if (isParent)
        _tile(context,
            art: 'teddy_bear',
            color: const Color(0xFF8B5CF6),
            title: 'Toy Words',
            screen: const ToyWordsScreen()),
    ];
  }

  Widget _grid(List<Widget> tiles) {
    return LayoutBuilder(
      builder: (context, c) {
        const gap = 16.0;
        final cols = c.maxWidth >= 900 ? 4 : (c.maxWidth >= 600 ? 3 : 2);
        final w = (c.maxWidth - gap * (cols - 1)) / cols;
        return Wrap(
          spacing: gap,
          runSpacing: gap + 6,
          children: [
            for (int i = 0; i < tiles.length; i++)
              SizedBox(
                width: w,
                height: w * 0.95,
                child: PopIn(
                  delay: Duration(milliseconds: 280 + i * 90),
                  child: tiles[i],
                ),
              ),
          ],
        );
      },
    );
  }

  /// A big square sticker card: a large 3D picture and one short word.
  Widget _tile(
    BuildContext context, {
    required String art,
    required Color color,
    required String title,
    required Widget screen,
    String? caption,
    int count = 0,
  }) {
    return Bouncy(
      onTap: () => _open(context, screen),
      child: LayoutBuilder(builder: (context, c) {
        final artSize = c.maxWidth * 0.62;
        return Container(
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                  color: AppColors.ledge(color, 0.16),
                  offset: const Offset(0, 7)),
              const BoxShadow(
                  color: Color(0x222A1F5C),
                  blurRadius: 18,
                  offset: Offset(0, 12)),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(30),
            child: Stack(
              children: [
                // Soft light circle behind the picture.
                Positioned(
                  right: -c.maxWidth * 0.18,
                  top: -c.maxWidth * 0.2,
                  child: _blob(c.maxWidth * 0.95, 0.16),
                ),
                Positioned(
                  right: c.maxWidth * 0.06,
                  top: c.maxWidth * 0.06,
                  child: KidArt(art, size: artSize),
                ),
                Positioned(
                  left: 16,
                  right: 12,
                  bottom: 14,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Text(title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.fredoka(
                                fontSize: c.maxWidth < 190 ? 21 : 25,
                                fontWeight: FontWeight.w600,
                                color: Colors.white)),
                      ),
                    ],
                  ),
                ),
                if (caption != null)
                  Positioned(
                    left: 14,
                    top: 14,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.28),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(caption,
                          style: GoogleFonts.nunito(
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                              color: Colors.white)),
                    ),
                  ),
                if (count > 0)
                  Positioned(
                    left: 14,
                    top: 14,
                    child: Container(
                      constraints:
                          const BoxConstraints(minWidth: 32, minHeight: 32),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.error,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white, width: 3),
                      ),
                      child: Text('$count',
                          style: GoogleFonts.nunito(
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                              color: Colors.white)),
                    ),
                  ),
              ],
            ),
          ),
        );
      }),
    );
  }

  // ---- Grown-up area: calm list, clearly separate ----------------------
  Widget _grownUpTitle() => PopIn(
        delay: const Duration(milliseconds: 500),
        child: Row(
          children: [
            const Icon(Icons.lock_rounded,
                size: 18, color: AppColors.textMuted),
            const SizedBox(width: 6),
            Text('For grown-ups',
                style: GoogleFonts.nunito(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.3,
                    color: AppColors.textMuted)),
          ],
        ),
      );

  List<Widget> _grownUpRows(BuildContext context, HomeState s) {
    return [
      if (s.user?.role == 'Parent') ...[
        _row(context,
            icon: Icons.family_restroom_rounded,
            color: const Color(0xFF14B8A6),
            title: 'My Children',
            subtitle: s.activeChildName == null
                ? 'Add your child to save their progress'
                : 'Learning now: ${s.activeChildName}',
            screen: const ChildrenScreen()),
        _row(context,
            icon: Icons.insights_rounded,
            color: const Color(0xFF22C55E),
            title: 'Progress',
            subtitle: s.activeChildName == null
                ? 'Weekly progress and weak areas'
                : "See ${s.activeChildName}'s weekly progress",
            screen: const ProgressScreen()),
        _row(context,
            icon: Icons.alarm_rounded,
            color: const Color(0xFFFF6B6B),
            title: 'Reminders',
            subtitle: 'Set a daily practice reminder',
            screen: const ReminderScreen()),
        _row(context,
            icon: Icons.cloud_sync_rounded,
            color: const Color(0xFF2EB5F0),
            title: 'Sync & Premium',
            subtitle: 'Sync devices and advanced reports',
            screen: const ParentHubScreen(),
            gated: true),
      ],
      if (s.user?.role == 'Teacher')
        _row(context,
            icon: Icons.school_rounded,
            color: const Color(0xFF8B5CF6),
            title: 'My Classes',
            subtitle: s.activeStudentLabel == null
                ? 'Create classes and add your students'
                : 'Practicing: ${s.activeStudentLabel}',
            screen: const ClassesScreen()),
    ];
  }

  Widget _grownUpPanel(List<Widget> rows) {
    return PopIn(
      delay: const Duration(milliseconds: 560),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(26),
          boxShadow: const [
            BoxShadow(color: AppColors.line, offset: Offset(0, 4)),
          ],
        ),
        child: Column(
          children: [
            for (int i = 0; i < rows.length; i++) ...[
              if (i > 0)
                const Divider(
                    height: 1,
                    indent: 76,
                    endIndent: 18,
                    color: AppColors.line),
              rows[i],
            ],
          ],
        ),
      ),
    );
  }

  Widget _row(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required Widget screen,
    bool gated = false,
  }) {
    return Bouncy(
      pressedScale: 0.98,
      onTap: () => gated ? _openGated(context, screen) : _open(context, screen),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, size: 26, color: color),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: GoogleFonts.nunito(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textDark)),
                  Text(subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.nunito(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textMuted)),
                ],
              ),
            ),
            if (gated)
              const Padding(
                padding: EdgeInsets.only(right: 4),
                child: Icon(Icons.lock_rounded,
                    size: 16, color: AppColors.textMuted),
              ),
            const Icon(Icons.chevron_right_rounded,
                color: AppColors.textMuted, size: 26),
          ],
        ),
      ),
    );
  }
}

/// Penny bouncing while the home data loads.
class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.primary,
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const PennyMascot(size: 140),
          const SizedBox(height: 12),
          Text('Getting your pencils ready…',
              style: GoogleFonts.nunito(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Colors.white)),
        ],
      ),
    );
  }
}
