import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../models/user_model.dart';
import '../../services/assignment_service.dart';
import '../../services/badge_service.dart';
import '../../services/family_service.dart';
import '../../services/sync_service.dart';

/// Everything the home screen shows.
class HomeState extends Equatable {
  final bool loading;
  final UserModel? user;
  final String? activeChildName;    // learner picked by a Parent
  final String? activeStudentLabel; // learner picked by a Teacher
  final int childCount;
  final int badgesEarned;
  final int badgesTotal;
  final int streak;
  final int openTasks;

  const HomeState({
    this.loading = true,
    this.user,
    this.activeChildName,
    this.activeStudentLabel,
    this.childCount = 0,
    this.badgesEarned = 0,
    this.badgesTotal = 0,
    this.streak = 0,
    this.openTasks = 0,
  });

  /// Only a CHILD may practice, so a grown-up must pick who is learning.
  bool get canLearn {
    final role = user?.role;
    if (role == 'Parent') return activeChildName != null;
    if (role == 'Teacher') return activeStudentLabel != null;
    return true; // a Student account is the learner itself
  }

  String? get learnerName =>
      user?.role == 'Teacher' ? activeStudentLabel : activeChildName;

  @override
  List<Object?> get props => [loading, user?.name, user?.role, activeChildName,
        activeStudentLabel, childCount, badgesEarned, badgesTotal, streak,
        openTasks];
}

/// Collects the home screen data from the repositories.
class HomeCubit extends Cubit<HomeState> {
  final FamilyService _family;
  final BadgeService _badges;
  final AssignmentService _assignments;
  final SyncService? _sync;

  /// Auto-sync runs once per app launch, not on every visit to home.
  static bool _autoSyncedThisLaunch = false;

  HomeCubit({
    required FamilyService family,
    required BadgeService badges,
    required AssignmentService assignments,
    SyncService? sync,
  })  : _family = family,
        _badges = badges,
        _assignments = assignments,
        _sync = sync,
        super(const HomeState());

  /// [user] comes from AuthBloc, so this cubit never touches Firebase
  /// login itself.
  Future<void> load(UserModel? user) async {
    await _loadData(user);
    // "Synced data stays up to date" (SRS US_27): if the parent turned
    // on auto-sync, sync quietly once, then refresh what we show.
    final sync = _sync;
    if (sync != null && !_autoSyncedThisLaunch && await sync.isAuto()) {
      _autoSyncedThisLaunch = true;
      final r = await sync.syncNow();
      if (r.ok && !isClosed) await _loadData(user);
    }
  }

  Future<void> _loadData(UserModel? user) async {
    final activeChild = await _family.getActiveChild();
    final studentLabel = await _family.getActiveStudentLabel();
    final children = await _family.loadChildren();
    final (earned, total, streak) = await _badges.summary();
    final scope = await _assignments.currentScope();
    await _assignments.autoSubmitExpired(scope);
    final open = await _assignments.openTasks(scope);
    if (isClosed) return;

    emit(HomeState(
      loading: false,
      user: user,
      activeChildName: activeChild?.name,
      activeStudentLabel: studentLabel,
      childCount: children.length,
      badgesEarned: earned,
      badgesTotal: total,
      streak: streak,
      openTasks: open.length,
    ));
  }
}
