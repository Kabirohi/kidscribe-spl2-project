import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/profile_models.dart';
import 'current_user.dart';

/// Stores the Parent's child profiles (SRS US_6) and the Teacher's classes
/// (SRS US_7) locally on the device, separately per logged-in account.
///
/// The parent can mark ONE child as the "active" learner — the learning
/// progress (strokes + letters) is then saved under that child, so every
/// child keeps their own stars and levels.
class FamilyService {
  String get _uid => currentUid();

  static String activeChildKey(String uid) => 'active_child_$uid';
  static String activeStudentScopeKey(String uid) =>
      'active_student_scope_$uid';
  static String activeStudentLabelKey(String uid) =>
      'active_student_label_$uid';
  String get _childrenKey => 'children_$_uid';
  String get _classesKey => 'classes_$_uid';

  /// The progress-storage scope for one student of one class
  /// (classroom mode: the teacher hands the tablet to this student).
  String studentScope(String classId, String studentName) =>
      '${_uid}_s${classId}_${studentName.trim().replaceAll(RegExp(r'\s+'), '_')}';

  /// The progress-storage scope for one child of this parent. Must match
  /// the rule used inside ProgressService.
  String childScope(String childId) => '${_uid}_c$childId';

  Future<void> setActiveStudent(String? scope, String? label) async {
    final prefs = await SharedPreferences.getInstance();
    if (scope == null) {
      await prefs.remove(activeStudentScopeKey(_uid));
      await prefs.remove(activeStudentLabelKey(_uid));
    } else {
      await prefs.setString(activeStudentScopeKey(_uid), scope);
      await prefs.setString(activeStudentLabelKey(_uid), label ?? '');
    }
  }

  Future<String?> getActiveStudentScope() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(activeStudentScopeKey(_uid));
  }

  Future<String?> getActiveStudentLabel() async {
    final prefs = await SharedPreferences.getInstance();
    final label = prefs.getString(activeStudentLabelKey(_uid));
    return (label == null || label.isEmpty) ? null : label;
  }

  // ================= child profiles (Parent) =================

  Future<List<ChildProfile>> loadChildren() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_childrenKey);
    if (raw == null) return [];
    return (jsonDecode(raw) as List)
        .map((m) => ChildProfile.fromMap(Map<String, dynamic>.from(m)))
        .toList();
  }

  Future<void> _saveChildren(List<ChildProfile> children) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _childrenKey, jsonEncode(children.map((c) => c.toMap()).toList()));
  }

  /// Adds a new profile, or updates the one with the same id.
  Future<void> saveChild(ChildProfile child) async {
    final children = await loadChildren();
    final i = children.indexWhere((c) => c.id == child.id);
    if (i >= 0) {
      children[i] = child;
    } else {
      children.add(child);
    }
    await _saveChildren(children);
  }

  Future<void> deleteChild(String id) async {
    final children = await loadChildren();
    children.removeWhere((c) => c.id == id);
    await _saveChildren(children);
    // If the removed child was the active learner, clear the selection.
    if (await getActiveChildId() == id) await setActiveChild(null);
  }

  Future<String?> getActiveChildId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(activeChildKey(_uid));
  }

  Future<void> setActiveChild(String? id) async {
    final prefs = await SharedPreferences.getInstance();
    if (id == null) {
      await prefs.remove(activeChildKey(_uid));
    } else {
      await prefs.setString(activeChildKey(_uid), id);
    }
  }

  /// The active child's profile, or null when none is selected.
  Future<ChildProfile?> getActiveChild() async {
    final id = await getActiveChildId();
    if (id == null) return null;
    final children = await loadChildren();
    for (final c in children) {
      if (c.id == id) return c;
    }
    return null;
  }

  // ================= classes (Teacher) =================

  Future<List<SchoolClass>> loadClasses() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_classesKey);
    if (raw == null) return [];
    return (jsonDecode(raw) as List)
        .map((m) => SchoolClass.fromMap(Map<String, dynamic>.from(m)))
        .toList();
  }

  Future<void> _saveClasses(List<SchoolClass> classes) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _classesKey, jsonEncode(classes.map((c) => c.toMap()).toList()));
  }

  /// Adds a new class, or updates the one with the same id.
  Future<void> saveClass(SchoolClass schoolClass) async {
    final classes = await loadClasses();
    final i = classes.indexWhere((c) => c.id == schoolClass.id);
    if (i >= 0) {
      classes[i] = schoolClass;
    } else {
      classes.add(schoolClass);
    }
    await _saveClasses(classes);
  }

  Future<void> deleteClass(String id) async {
    final classes = await loadClasses();
    classes.removeWhere((c) => c.id == id);
    await _saveClasses(classes);
  }
}
