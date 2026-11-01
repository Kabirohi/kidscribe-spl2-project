import 'package:flutter_bloc/flutter_bloc.dart';
import '../../services/progress_service.dart';

/// Stars earned per Stage 1 item (item id -> 0..3). A plain map is all
/// this small screen needs, so the state is just that map.
class TraceItemsCubit extends Cubit<Map<String, int>> {
  final ProgressService _progress;

  TraceItemsCubit({required ProgressService progress})
      : _progress = progress,
        super(const {});

  Future<void> load() async {
    final all = await _progress.loadAll();
    if (!isClosed) emit(Map.of(all));
  }
}
