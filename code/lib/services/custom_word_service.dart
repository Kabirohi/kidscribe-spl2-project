import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/word_list.dart';
import 'progress_service.dart';

/// A word a parent added from a photo of the child's own toy
/// (SRS FR_16 / US_20).
class CustomWord {
  final String word;      // uppercase letters only, e.g. "DINO"
  final String photoPath; // the toy photo, saved inside the app
  final int addedAtMs;

  const CustomWord(this.word, this.photoPath, this.addedAtMs);

  /// Shown like a normal practice word, with a toy picture.
  static const emoji = '🧸';

  PracticeWord get asPracticeWord => PracticeWord(word, emoji);

  Map<String, dynamic> toMap() =>
      {'word': word, 'photo': photoPath, 'at': addedAtMs};

  factory CustomWord.fromMap(Map<String, dynamic> m) =>
      CustomWord(m['word'] ?? '', m['photo'] ?? '', m['at'] ?? 0);
}

/// Result of checking a toy photo.
class PhotoCheck {
  final bool clear;
  final double sharpness;
  final String? message;
  const PhotoCheck(this.clear, this.sharpness, this.message);
}

/// Keeps the toy words for each child (custom_words_<scope>), and checks
/// that a toy photo is sharp enough to use.
class CustomWordService {
  final ProgressService _progress = ProgressService();

  /// Below this, the photo counts as blurry and is not used (SRS T_48).
  static const double minSharpness = 60;

  Future<String> _key() async => 'custom_words_${await _progress.currentScope()}';

  /// The toy words of the child who is learning now.
  Future<List<CustomWord>> load() async =>
      loadFor(await _progress.currentScope());

  /// The toy words of any child (used when a parent gives a task).
  Future<List<CustomWord>> loadFor(String scope) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('custom_words_$scope');
    if (raw == null) return [];
    return (jsonDecode(raw) as List)
        .map((m) => CustomWord.fromMap(Map<String, dynamic>.from(m)))
        .toList();
  }

  Future<void> _save(List<CustomWord> list) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        await _key(), jsonEncode(list.map((w) => w.toMap()).toList()));
  }

  /// Checks the word the parent typed. Returns an error, or null if fine.
  /// Only letters A-Z, because the child must be able to write every one.
  static String? validateWord(String word) {
    final w = word.trim().toUpperCase();
    if (w.isEmpty) return 'Please type the name of the toy';
    if (w.length < 2 || w.length > 8) {
      return 'Use a word with 2 to 8 letters';
    }
    if (!RegExp(r'^[A-Z]+$').hasMatch(w)) {
      return 'Use letters only (A to Z), no spaces or numbers';
    }
    return null;
  }

  /// Is the photo sharp? We measure how much the edges change
  /// (the "variance of the Laplacian"): a blurry photo has soft edges,
  /// so this number is small.
  Future<PhotoCheck> checkPhoto(String path) async {
    try {
      final bytes = await File(path).readAsBytes();
      final decoded = img.decodeImage(bytes);
      if (decoded == null) {
        return const PhotoCheck(false, 0, 'That photo could not be opened.');
      }
      // Work on a small grey copy, so it is fast.
      final small = img.grayscale(img.copyResize(decoded, width: 320));
      final w = small.width, h = small.height;
      double sum = 0, sumSq = 0;
      var n = 0;
      for (var y = 1; y < h - 1; y++) {
        for (var x = 1; x < w - 1; x++) {
          double lum(int xx, int yy) => small.getPixel(xx, yy).r.toDouble();
          final lap = 4 * lum(x, y) -
              lum(x - 1, y) -
              lum(x + 1, y) -
              lum(x, y - 1) -
              lum(x, y + 1);
          sum += lap;
          sumSq += lap * lap;
          n++;
        }
      }
      if (n == 0) return const PhotoCheck(false, 0, 'That photo is too small.');
      final mean = sum / n;
      final variance = max(0.0, sumSq / n - mean * mean);
      final clear = variance >= minSharpness;
      return PhotoCheck(
        clear,
        variance,
        clear
            ? null
            : 'The photo is blurry. Hold the tablet still and take it again.',
      );
    } catch (_) {
      return const PhotoCheck(false, 0, 'That photo could not be checked.');
    }
  }

  /// Guesses what the toy is, using ML Kit Image Labeling on the tablet
  /// (the model is inside the app, so no internet is needed). The guesses
  /// are only SUGGESTIONS — the parent picks one or types their own word.
  Future<List<String>> suggestNames(String path) async {
    final labeler =
        ImageLabeler(options: ImageLabelerOptions(confidenceThreshold: 0.45));
    try {
      final labels = await labeler.processImage(InputImage.fromFilePath(path));
      final words = <String>[];
      for (final l in labels) {
        // "Teddy bear" -> "TEDDY", "BEAR"
        for (final part in l.label.toUpperCase().split(RegExp(r'[^A-Z]+'))) {
          if (validateWord(part) == null && !words.contains(part)) {
            words.add(part);
          }
        }
      }
      return words.take(6).toList();
    } catch (_) {
      return [];
    } finally {
      await labeler.close();
    }
  }

  /// Copies the photo into the app's own folder and saves the word.
  Future<CustomWord> add(String word, String photoPath) async {
    final w = word.trim().toUpperCase();
    final dir = await getApplicationDocumentsDirectory();
    final folder = Directory('${dir.path}/toys');
    if (!await folder.exists()) await folder.create(recursive: true);
    final saved = await File(photoPath).copy(
        '${folder.path}/${w}_${DateTime.now().millisecondsSinceEpoch}.jpg');

    final list = await load();
    list.removeWhere((x) => x.word == w); // one entry per word
    final entry = CustomWord(w, saved.path, DateTime.now().millisecondsSinceEpoch);
    list.add(entry);
    await _save(list);
    return entry;
  }

  Future<void> delete(String word) async {
    final list = await load();
    final gone = list.where((x) => x.word == word).toList();
    list.removeWhere((x) => x.word == word);
    await _save(list);
    for (final g in gone) {
      try {
        await File(g.photoPath).delete();
      } catch (_) {}
    }
  }
}
