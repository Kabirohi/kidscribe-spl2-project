import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'current_user.dart';

enum SyncOutcome { synced, offline, notSetUp, failed }

class SyncResult {
  final SyncOutcome outcome;
  final String message;
  const SyncResult(this.outcome, this.message);

  bool get ok => outcome == SyncOutcome.synced;
}

/// Syncs a grown-up's KidScribe data across devices with Cloud Firestore
/// (SRS FR_20 / US_27).
///
/// The app still keeps everything on the tablet first (it works with no
/// internet). Sync copies this account's data to one cloud document,
/// kidscribe_sync/<uid>, and brings back what other devices saved.
///
/// When two devices disagree we MERGE instead of overwriting, so a child
/// never loses a star:
///  - numbers   -> keep the bigger one (best stars, best %, day counts)
///  - maps      -> join them, key by key
///  - lists     -> join them (by "id" or "word" when items have one)
class SyncService {
  static const _collection = 'kidscribe_sync';
  static const _timeout = Duration(seconds: 12);

  String? get _uid => currentUidOrNull();
  String _lastKey(String uid) => 'sync_last_$uid';
  String _autoKey(String uid) => 'sync_auto_$uid';

  /// Which device picked which learner is a choice for THAT tablet,
  /// so it is not copied to other devices.
  bool _shouldSync(String key, String uid) =>
      key.contains(uid) &&
      !key.startsWith('active_child_') &&
      !key.startsWith('active_student_') &&
      !key.startsWith('sync_');

  // ---------------- settings ----------------

  Future<DateTime?> lastSync() async {
    final uid = _uid;
    if (uid == null) return null;
    final prefs = await SharedPreferences.getInstance();
    final ms = prefs.getInt(_lastKey(uid));
    return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
  }

  Future<bool> isAuto() async {
    final uid = _uid;
    if (uid == null) return false;
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_autoKey(uid)) ?? false;
  }

  Future<void> setAuto(bool on) async {
    final uid = _uid;
    if (uid == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_autoKey(uid), on);
  }

  // ---------------- the sync ----------------

  Future<SyncResult> syncNow() async {
    final uid = _uid;
    if (uid == null) {
      return const SyncResult(SyncOutcome.failed, 'Please log in first.');
    }
    final doc = FirebaseFirestore.instance.collection(_collection).doc(uid);
    try {
      // 1. Read what other devices saved (from the server, not a cache).
      final snap = await doc
          .get(const GetOptions(source: Source.server))
          .timeout(_timeout);
      final remote = Map<String, dynamic>.from(
          (snap.data()?['data'] as Map?) ?? const {});

      // 2. Join it with this tablet's data.
      final local = await _readLocal(uid);
      final merged = _mergeAll(local, remote);

      // 3. Save the joined data on this tablet AND in the cloud.
      await _writeLocal(merged);
      await doc.set({
        'data': merged,
        'updatedAt': FieldValue.serverTimestamp(),
      }).timeout(_timeout);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_lastKey(uid), DateTime.now().millisecondsSinceEpoch);
      return SyncResult(SyncOutcome.synced,
          'Synced! ${merged.length} saved items are the same on every device.');
    } on TimeoutException {
      return const SyncResult(SyncOutcome.offline,
          'No internet right now. Your progress is safe on this tablet and '
          'will sync when you try again with internet.');
    } on FirebaseException catch (e) {
      if (e.code == 'unavailable') {
        return const SyncResult(SyncOutcome.offline,
            'No internet right now. Your progress is safe on this tablet '
            'and will sync when you try again with internet.');
      }
      if (e.code == 'permission-denied' || e.code == 'not-found' ||
          e.code == 'failed-precondition') {
        return const SyncResult(SyncOutcome.notSetUp,
            'Cloud sync is not switched on for this app yet. (Firestore must '
            'be enabled in the Firebase console.)');
      }
      return SyncResult(SyncOutcome.failed, 'Sync failed: ${e.message}');
    } catch (e) {
      return SyncResult(SyncOutcome.failed, 'Sync failed: $e');
    }
  }

  // ---------------- local data <-> a plain map ----------------

  /// Each value is saved with its type: {"t": "s", "v": "..."}.
  Future<Map<String, dynamic>> _readLocal(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    final out = <String, dynamic>{};
    for (final key in prefs.getKeys()) {
      if (!_shouldSync(key, uid)) continue;
      final v = prefs.get(key);
      if (v is String) {
        out[key] = {'t': 's', 'v': v};
      } else if (v is bool) {
        out[key] = {'t': 'b', 'v': v};
      } else if (v is int) {
        out[key] = {'t': 'i', 'v': v};
      } else if (v is double) {
        out[key] = {'t': 'd', 'v': v};
      } else if (v is List) {
        out[key] = {'t': 'l', 'v': List<String>.from(v)};
      }
    }
    return out;
  }

  Future<void> _writeLocal(Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    for (final e in data.entries) {
      final item = Map<String, dynamic>.from(e.value as Map);
      final v = item['v'];
      switch (item['t']) {
        case 's':
          await prefs.setString(e.key, v as String);
          break;
        case 'b':
          await prefs.setBool(e.key, v as bool);
          break;
        case 'i':
          await prefs.setInt(e.key, (v as num).toInt());
          break;
        case 'd':
          await prefs.setDouble(e.key, (v as num).toDouble());
          break;
        case 'l':
          await prefs.setStringList(e.key, List<String>.from(v as List));
          break;
      }
    }
  }

  // ---------------- merging ----------------

  Map<String, dynamic> _mergeAll(
      Map<String, dynamic> local, Map<String, dynamic> remote) {
    final out = <String, dynamic>{...remote};
    for (final e in local.entries) {
      final r = remote[e.key];
      out[e.key] = r == null ? e.value : _mergeItem(e.value, r);
    }
    return out;
  }

  dynamic _mergeItem(dynamic localItem, dynamic remoteItem) {
    final l = Map<String, dynamic>.from(localItem as Map);
    final r = Map<String, dynamic>.from(remoteItem as Map);
    if (l['t'] != r['t']) return l;
    switch (l['t']) {
      case 's':
        // Most saved values are JSON text: join them properly.
        try {
          final a = jsonDecode(l['v'] as String);
          final b = jsonDecode(r['v'] as String);
          return {'t': 's', 'v': jsonEncode(_mergeJson(a, b))};
        } catch (_) {
          return l; // plain text: this tablet's value wins
        }
      case 'i':
      case 'd':
        final a = l['v'] as num, b = r['v'] as num;
        return {'t': l['t'], 'v': a >= b ? a : b};
      case 'l':
        final set = <String>{
          ...List<String>.from(l['v'] as List),
          ...List<String>.from(r['v'] as List),
        };
        return {'t': 'l', 'v': set.toList()};
      default:
        return l;
    }
  }

  /// Joins two JSON values without losing anything.
  dynamic _mergeJson(dynamic a, dynamic b) {
    if (a is num && b is num) return a >= b ? a : b;
    if (a is Map && b is Map) {
      final out = <String, dynamic>{...Map<String, dynamic>.from(b)};
      a.forEach((k, v) {
        out[k as String] = out.containsKey(k) ? _mergeJson(v, out[k]) : v;
      });
      return out;
    }
    if (a is List && b is List) {
      String? idOf(dynamic x) {
        if (x is Map) return (x['id'] ?? x['word'])?.toString();
        return null;
      }
      final out = <dynamic>[...b];
      for (final item in a) {
        final id = idOf(item);
        final i = id == null
            ? out.indexWhere((x) => jsonEncode(x) == jsonEncode(item))
            : out.indexWhere((x) => idOf(x) == id);
        if (i == -1) {
          out.add(item);
        } else if (id != null) {
          out[i] = _mergeJson(item, out[i]);
        }
      }
      return out;
    }
    return a; // text, true/false: this tablet wins
  }
}
