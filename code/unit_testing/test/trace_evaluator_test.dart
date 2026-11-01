// SRS US_8, US_9 and US_10 - tracing a stroke, writing a letter, and
// the instant feedback. Covers T_23, T_25, T_26, T_27, T_28.
//
// These tests drive TraceEvaluator, which is the part of the app that
// decides whether what the child drew is correct.

import 'package:flutter_test/flutter_test.dart';
import 'package:kidscribe/data/trace_templates.dart';
import 'package:kidscribe/services/trace_evaluator.dart';

import 'helpers.dart';

void main() {
  final stroke = stage1Items.first;          // the first Stage 1 shape
  final letterA = allLetterItems.firstWhere((l) => l.glyph == 'A');
  final letterB = allLetterItems.firstWhere((l) => l.glyph == 'B');

  group('US_8 practice basic strokes', () {
    test('T_23 a traced stroke is accepted', () {
      final r = TraceEvaluator.evaluate(
        drawn: traceExactly(stroke.strokes),
        template: stroke.strokes,
      );
      expect(r.passed, isTrue);
      expect(r.stars, greaterThanOrEqualTo(1));
      expect(r.score, greaterThanOrEqualTo(55));
    });

    test('T_24 a drawing that is only a dot is not a real attempt', () {
      final r = TraceEvaluator.evaluate(
        drawn: [
          [stroke.strokes.first.first]
        ],
        template: stroke.strokes,
      );
      expect(r.passed, isFalse);
      expect(r.stars, 0);
    });
  });

  group('US_9 write letters A to Z', () {
    test('T_25 letter A traced on the guide is marked correct', () {
      final r = TraceEvaluator.evaluate(
        drawn: traceExactly(letterA.strokes),
        template: letterA.strokes,
      );
      expect(r.passed, isTrue);
      expect(r.stars, 3);
      expect(r.tip, isNull); // nothing to fix
    });

    test('T_26 a messy A far from the guide gets feedback on what to fix', () {
      final r = TraceEvaluator.evaluate(
        drawn: scribble(),
        template: letterA.strokes,
      );
      expect(r.passed, isFalse);
      expect(r.tip, isNotNull);
      expect(r.tip, isNotEmpty);
    });

    test('a small wobble still passes, because little hands shake', () {
      final r = TraceEvaluator.evaluate(
        drawn: traceExactly(letterA.strokes, wobble: 0.02),
        template: letterA.strokes,
      );
      expect(r.passed, isTrue);
    });
  });

  group('US_10 instant feedback', () {
    test('T_27 a clear B gets a success result', () {
      final r = TraceEvaluator.evaluate(
        drawn: traceExactly(letterB.strokes),
        template: letterB.strokes,
      );
      expect(r.passed, isTrue);
      expect(r.stars, greaterThanOrEqualTo(2));
    });

    test('T_28 an unclear B is told what needs to be fixed', () {
      // Only the first stroke of B is drawn, so half the letter is missing.
      final r = TraceEvaluator.evaluate(
        drawn: traceExactly([letterB.strokes.first]),
        template: letterB.strokes,
      );
      expect(r.passed, isFalse);
      expect(r.tip, isNotNull);
    });
  });

  group('writing in the designated manner', () {
    test('the right strokes in the right order pass the order check', () {
      final order = TraceEvaluator.checkOrder(
        drawn: traceExactly(letterA.strokes),
        template: letterA.strokes,
      );
      expect(order.ok, isTrue);
      expect(order.kidTip, isNull);
    });

    test('drawing a stroke backwards is caught and explained', () {
      final backwards = [
        for (final s in traceExactly(letterA.strokes)) s.reversed.toList()
      ];
      final order = TraceEvaluator.checkOrder(
        drawn: backwards,
        template: letterA.strokes,
      );
      expect(order.ok, isFalse);
      expect(order.kidTip, isNotNull);
    });

    test('a wrong number of strokes is caught', () {
      final order = TraceEvaluator.checkOrder(
        drawn: traceExactly([letterA.strokes.first]),
        template: letterA.strokes,
      );
      expect(order.ok, isFalse);
      expect(order.kidTip, isNotNull);
    });
  });
}
