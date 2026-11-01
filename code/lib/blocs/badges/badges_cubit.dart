import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../services/badge_service.dart';
import '../../services/progress_service.dart';

class BadgesState extends Equatable {
  final bool loading;
  final Set<String> earned;
  final int streak;
  final int best;
  final bool practicedToday;

  const BadgesState({
    this.loading = true,
    this.earned = const {},
    this.streak = 0,
    this.best = 0,
    this.practicedToday = false,
  });

  @override
  List<Object?> get props => [loading, earned.length, streak, best, practicedToday];
}

/// The badge gallery and the daily streak (SRS FR_14 / US_18).
class BadgesCubit extends Cubit<BadgesState> {
  final BadgeService _badges;
  final ProgressService _progress;

  BadgesCubit({required BadgeService badges, required ProgressService progress})
      : _badges = badges,
        _progress = progress,
        super(const BadgesState());

  Future<void> load() async {
    final earned = await _badges.computeEarnedIds();
    final log = await _progress.loadPracticeLog();
    final n = DateTime.now();
    final today =
        '${n.year}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
    emit(BadgesState(
      loading: false,
      earned: earned,
      streak: _badges.currentStreak(log),
      best: _badges.bestStreak(log),
      practicedToday: log.containsKey(today),
    ));
  }
}
