// Small helpers shared by the test files.
// This file has no "_test" in its name, so it is not run as a test.

import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Starts every test with an empty, fake phone storage.
///
/// Nobody is logged in during a test, so every service saves under the
/// scope 'guest'. That keeps one test from seeing another test's data.
Future<void> useEmptyStorage() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});
}

/// The storage scope used when nobody is logged in.
const guestScope = 'guest';

/// Today written the way the app writes it: 2026-10-21.
String dayKey(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Copies a template shape, so the test "draws" it perfectly.
/// [wobble] moves each point a tiny bit, like a real child's hand.
List<List<Offset>> traceExactly(List<List<Offset>> template,
    {double wobble = 0}) {
  final rand = math.Random(7); // same numbers every run, so tests are stable
  return [
    for (final stroke in template)
      [
        for (final p in _denser(stroke))
          wobble == 0
              ? p
              : Offset(p.dx + (rand.nextDouble() - .5) * wobble,
                  p.dy + (rand.nextDouble() - .5) * wobble)
      ]
  ];
}

/// Adds points between the template points, because a real pen draws
/// many more points than the template has.
List<Offset> _denser(List<Offset> stroke) {
  final out = <Offset>[];
  for (var i = 0; i < stroke.length - 1; i++) {
    for (var s = 0; s < 4; s++) {
      out.add(Offset.lerp(stroke[i], stroke[i + 1], s / 4)!);
    }
  }
  out.add(stroke.last);
  return out;
}

/// A scribble in the corner: nothing like the real shape.
List<List<Offset>> scribble() => [
      [for (var i = 0; i < 20; i++) Offset(0.05 + i * 0.002, 0.05 + i * 0.001)]
    ];
