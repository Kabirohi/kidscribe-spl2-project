import 'dart:ui';

/// One thing a child can trace on the canvas:
/// a practice stroke (Stage 1) or a full letter (Stage 2).
class TraceItem {
  final String id;    // unique id used to save progress (e.g. "s1_circle", "letter_A")
  final String glyph; // big symbol shown on the selection card (e.g. "O", "A", "/")
  final String name;  // kid-friendly name (e.g. "Circle", "Letter A")
  final String hint;  // one-line tip shown above the drawing canvas

  /// The template shape. Each inner list is ONE pen stroke:
  /// a connected chain of points inside a 0..1 square.
  /// (Using 0..1 instead of pixels means the same shape data works on any
  /// screen size — the canvas simply multiplies by its own width.)
  final List<List<Offset>> strokes;

  const TraceItem({
    required this.id,
    required this.glyph,
    required this.name,
    required this.hint,
    required this.strokes,
  });
}

/// A group of letters practised together (Stage 2), e.g. "Line Letters".
/// The proposal says: "Focus on one letter family at a time."
class LetterFamily {
  final String id;
  final String name;
  final String description;
  final List<TraceItem> items;

  const LetterFamily({
    required this.id,
    required this.name,
    required this.description,
    required this.items,
  });
}
