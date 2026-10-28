import 'dart:math' as math;
import 'dart:ui';

import '../models/trace_item.dart';

// =====================================================================
// TEMPLATE SHAPES for Stage 1 (strokes) and Stage 2 (letters A-Z).
//
// Every shape is a list of points inside a 0..1 square, so the same
// data works on any screen size (the canvas multiplies by its width).
// A "stroke" = one continuous pen movement (pen down ... pen up).
// =====================================================================

/// Points along a straight line from (x1,y1) to (x2,y2).
List<Offset> _line(double x1, double y1, double x2, double y2,
    {int steps = 24}) {
  return List.generate(
    steps + 1,
    (i) => Offset(x1 + (x2 - x1) * i / steps, y1 + (y2 - y1) * i / steps),
  );
}

/// Points along a circular arc. Angles are in degrees:
/// 0 = right, 90 = down, 180 = left, 270 (or -90) = up.
/// endDeg may be SMALLER than startDeg to sweep the other way around.
List<Offset> _arc(double cx, double cy, double r, double startDeg,
    double endDeg, {int steps = 48}) {
  return List.generate(steps + 1, (i) {
    final deg = startDeg + (endDeg - startDeg) * i / steps;
    final rad = deg * math.pi / 180;
    return Offset(cx + r * math.cos(rad), cy + r * math.sin(rad));
  });
}

/// Glues several point-lists into ONE continuous stroke.
List<Offset> _join(List<List<Offset>> parts) => parts.expand((p) => p).toList();

/// Subdivides a hand-made point list so the curve looks smooth on screen.
List<Offset> _poly(List<Offset> pts, {int steps = 6}) {
  final out = <Offset>[];
  for (var i = 0; i < pts.length - 1; i++) {
    for (var j = 0; j < steps; j++) {
      out.add(Offset.lerp(pts[i], pts[i + 1], j / steps)!);
    }
  }
  out.add(pts.last);
  return out;
}

// ============================ STAGE 1 ================================
// Basic pen control: lines, curves, circles (proposal: takes 1-2 weeks).

final List<TraceItem> stage1Items = [
  TraceItem(
    id: 's1_standing',
    glyph: '|',
    name: 'Standing Line',
    hint: 'Start at the green dot and slide straight DOWN.',
    strokes: [_line(0.5, 0.15, 0.5, 0.85)],
  ),
  TraceItem(
    id: 's1_sleeping',
    glyph: '—',
    name: 'Sleeping Line',
    hint: 'Start at the green dot and slide LEFT to RIGHT.',
    strokes: [_line(0.15, 0.5, 0.85, 0.5)],
  ),
  TraceItem(
    id: 's1_slant_right',
    glyph: '\\',
    name: 'Slide Down-Right',
    hint: 'Slide down the hill, top-left to bottom-right.',
    strokes: [_line(0.25, 0.15, 0.75, 0.85)],
  ),
  TraceItem(
    id: 's1_slant_left',
    glyph: '/',
    name: 'Slide Down-Left',
    hint: 'Slide down the hill, top-right to bottom-left.',
    strokes: [_line(0.75, 0.15, 0.25, 0.85)],
  ),
  TraceItem(
    id: 's1_curve',
    glyph: 'C',
    name: 'Big Curve',
    hint: 'Start at the top and curve around like a moon.',
    strokes: [_arc(0.5, 0.5, 0.33, -60, -300)],
  ),
  TraceItem(
    id: 's1_circle',
    glyph: 'O',
    name: 'Circle',
    hint: 'Go all the way around and close the circle!',
    strokes: [_arc(0.5, 0.5, 0.33, -90, 270)],
  ),
];

// ============================ STAGE 2 ================================
// Full letters A-Z, built out of the Stage 1 strokes.
// Grouped into letter FAMILIES (one family at a time, like the proposal).

const String _letterHint = 'Start at dot 1 and trace each gray stroke.';

TraceItem _letter(String ch, List<List<Offset>> strokes) => TraceItem(
      id: 'letter_$ch',
      glyph: ch,
      name: 'Letter $ch',
      hint: _letterHint,
      strokes: strokes,
    );

/// Hand-made curve for the letter S (hard to build from arcs alone).
final List<Offset> _sCurve = _poly(const [
  Offset(0.70, 0.24), Offset(0.62, 0.17), Offset(0.50, 0.15),
  Offset(0.38, 0.17), Offset(0.31, 0.25), Offset(0.32, 0.35),
  Offset(0.40, 0.43), Offset(0.50, 0.48), Offset(0.60, 0.53),
  Offset(0.68, 0.60), Offset(0.69, 0.70), Offset(0.63, 0.79),
  Offset(0.52, 0.85), Offset(0.40, 0.84), Offset(0.31, 0.77),
]);

/// Every capital letter as a list of strokes (0..1 coordinate space).
final Map<String, List<List<Offset>>> _letters = {
  'A': [
    _line(0.5, 0.15, 0.22, 0.85),
    _line(0.5, 0.15, 0.78, 0.85),
    _line(0.33, 0.60, 0.67, 0.60),
  ],
  'B': [
    _line(0.3, 0.15, 0.3, 0.85),
    _arc(0.3, 0.325, 0.175, -90, 90),
    _arc(0.3, 0.675, 0.175, -90, 90),
  ],
  'C': [_arc(0.5, 0.5, 0.33, -60, -300)],
  'D': [
    _line(0.3, 0.15, 0.3, 0.85),
    _arc(0.3, 0.5, 0.35, -90, 90),
  ],
  'E': [
    _line(0.3, 0.15, 0.3, 0.85),
    _line(0.3, 0.15, 0.75, 0.15),
    _line(0.3, 0.50, 0.70, 0.50),
    _line(0.3, 0.85, 0.75, 0.85),
  ],
  'F': [
    _line(0.3, 0.15, 0.3, 0.85),
    _line(0.3, 0.15, 0.75, 0.15),
    _line(0.3, 0.50, 0.68, 0.50),
  ],
  'G': [
    _arc(0.5, 0.5, 0.33, -60, -300),
    _line(0.55, 0.55, 0.83, 0.55),
  ],
  'H': [
    _line(0.28, 0.15, 0.28, 0.85),
    _line(0.72, 0.15, 0.72, 0.85),
    _line(0.28, 0.50, 0.72, 0.50),
  ],
  'I': [
    _line(0.34, 0.15, 0.66, 0.15),
    _line(0.5, 0.15, 0.5, 0.85),
    _line(0.34, 0.85, 0.66, 0.85),
  ],
  'J': [
    _line(0.42, 0.15, 0.80, 0.15),
    _join([
      _line(0.62, 0.15, 0.62, 0.60),
      _arc(0.46, 0.60, 0.16, 0, 140),
    ]),
  ],
  'K': [
    _line(0.3, 0.15, 0.3, 0.85),
    _line(0.72, 0.15, 0.3, 0.52),
    _line(0.3, 0.52, 0.75, 0.85),
  ],
  'L': [
    _line(0.32, 0.15, 0.32, 0.85),
    _line(0.32, 0.85, 0.74, 0.85),
  ],
  'M': [
    _join([
      _line(0.2, 0.85, 0.2, 0.15),
      _line(0.2, 0.15, 0.5, 0.62),
      _line(0.5, 0.62, 0.8, 0.15),
      _line(0.8, 0.15, 0.8, 0.85),
    ]),
  ],
  'N': [
    _join([
      _line(0.26, 0.85, 0.26, 0.15),
      _line(0.26, 0.15, 0.74, 0.85),
      _line(0.74, 0.85, 0.74, 0.15),
    ]),
  ],
  'O': [_arc(0.5, 0.5, 0.33, -90, 270)],
  'P': [
    _line(0.3, 0.15, 0.3, 0.85),
    _arc(0.3, 0.34, 0.19, -90, 90),
  ],
  'Q': [
    _arc(0.5, 0.5, 0.33, -90, 270),
    _line(0.60, 0.62, 0.82, 0.86),
  ],
  'R': [
    _line(0.3, 0.15, 0.3, 0.85),
    _arc(0.3, 0.34, 0.19, -90, 90),
    _line(0.32, 0.53, 0.74, 0.85),
  ],
  'S': [_sCurve],
  'T': [
    _line(0.22, 0.15, 0.78, 0.15),
    _line(0.5, 0.15, 0.5, 0.85),
  ],
  'U': [
    _join([
      _line(0.26, 0.15, 0.26, 0.58),
      _arc(0.5, 0.58, 0.24, 180, 0),
      _line(0.74, 0.58, 0.74, 0.15),
    ]),
  ],
  'V': [
    _join([
      _line(0.22, 0.15, 0.5, 0.85),
      _line(0.5, 0.85, 0.78, 0.15),
    ]),
  ],
  'W': [
    _join([
      _line(0.14, 0.15, 0.32, 0.85),
      _line(0.32, 0.85, 0.50, 0.40),
      _line(0.50, 0.40, 0.68, 0.85),
      _line(0.68, 0.85, 0.86, 0.15),
    ]),
  ],
  'X': [
    _line(0.25, 0.15, 0.75, 0.85),
    _line(0.75, 0.15, 0.25, 0.85),
  ],
  'Y': [
    _line(0.24, 0.15, 0.5, 0.50),
    _line(0.76, 0.15, 0.5, 0.50),
    _line(0.5, 0.50, 0.5, 0.85),
  ],
  'Z': [
    _join([
      _line(0.24, 0.15, 0.76, 0.15),
      _line(0.76, 0.15, 0.24, 0.85),
      _line(0.24, 0.85, 0.76, 0.85),
    ]),
  ],
};

List<TraceItem> _lettersFor(String chars) =>
    chars.split('').map((c) => _letter(c, _letters[c]!)).toList();

/// The letter families, easiest first (line letters reuse Stage 1 lines,
/// then slants, then curves, then letters that mix lines + curves).
final List<LetterFamily> letterFamilies = [
  LetterFamily(
    id: 'fam_line',
    name: 'Line Letters',
    description: 'Made of straight lines only',
    items: _lettersFor('ILTEFH'),
  ),
  LetterFamily(
    id: 'fam_slant',
    name: 'Slant Letters',
    description: 'Made with slanting lines',
    items: _lettersFor('VXZNMWKAY'),
  ),
  LetterFamily(
    id: 'fam_curve',
    name: 'Curve Letters',
    description: 'Round and curvy letters',
    items: _lettersFor('COQGS'),
  ),
  LetterFamily(
    id: 'fam_mix',
    name: 'Mix Letters',
    description: 'Lines and curves together',
    items: _lettersFor('UJDPBR'),
  ),
];

/// All 26 letters in one list (used to count Stage 2 progress).
final List<TraceItem> allLetterItems =
    letterFamilies.expand((f) => f.items).toList();
