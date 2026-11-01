import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../models/profile_models.dart';
import '../../services/family_service.dart';

class ChildrenState extends Equatable {
  final bool loading;
  final List<ChildProfile> children;
  final String? activeId;
  final String? message;      // something friendly to show
  final bool messageIsError;

  const ChildrenState({
    this.loading = true,
    this.children = const [],
    this.activeId,
    this.message,
    this.messageIsError = false,
  });

  ChildrenState copyWith({
    bool? loading,
    List<ChildProfile>? children,
    String? activeId,
    String? message,
    bool? messageIsError,
    bool clearMessage = false,
    bool clearActive = false,
  }) =>
      ChildrenState(
        loading: loading ?? this.loading,
        children: children ?? this.children,
        activeId: clearActive ? null : (activeId ?? this.activeId),
        message: clearMessage ? null : (message ?? this.message),
        messageIsError: messageIsError ?? this.messageIsError,
      );

  @override
  List<Object?> get props =>
      [loading, children.map((c) => c.id).toList(), children.length, activeId,
        message, messageIsError];
}

/// The Parent's child profiles (SRS FR_3 / US_6).
class ChildrenCubit extends Cubit<ChildrenState> {
  final FamilyService _family;

  ChildrenCubit({required FamilyService family})
      : _family = family,
        super(const ChildrenState());

  Future<void> load() async {
    final children = await _family.loadChildren();
    final active = await _family.getActiveChildId();
    emit(state.copyWith(
        loading: false, children: children, activeId: active,
        clearMessage: true));
  }

  /// Adds a new child, or edits one. An empty name saves nothing (T_18).
  Future<void> saveChild({String? id, required String name, required int age}) async {
    if (name.trim().isEmpty) {
      emit(state.copyWith(
          message: "Please enter the child's name", messageIsError: true));
      return;
    }
    if (age <= 0) {
      emit(state.copyWith(
          message: "Please enter the child's age (a number)",
          messageIsError: true));
      return;
    }
    final isNew = id == null;
    final profile = ChildProfile(
      id: id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      name: name.trim(),
      age: age,
    );
    await _family.saveChild(profile);
    // The first child added becomes the learner right away.
    if (await _family.getActiveChildId() == null) {
      await _family.setActiveChild(profile.id);
    }
    await load();
    emit(state.copyWith(
        message: isNew
            ? '${profile.name} joined KidScribe!'
            : 'Profile updated!',
        messageIsError: false));
  }

  Future<void> deleteChild(ChildProfile child) async {
    await _family.deleteChild(child.id);
    await load();
    emit(state.copyWith(
        message: '${child.name} was removed', messageIsError: false));
  }

  Future<void> setActive(ChildProfile child) async {
    await _family.setActiveChild(child.id);
    await load();
    emit(state.copyWith(
        message: '${child.name} is learning now!', messageIsError: false));
  }

  void clearMessage() => emit(state.copyWith(clearMessage: true));
}
