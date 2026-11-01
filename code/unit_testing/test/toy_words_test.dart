// SRS US_20 - a parent adds a word by photographing the child's toy.
// Covers T_48 (an unclear photo is refused) and the word rules.
//
// The camera and the name guessing need a real phone, so they are tested
// by hand. The blurry-photo check is pure maths on the picture, so it is
// tested here with pictures made inside the test.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:kidscribe/services/custom_word_service.dart';

import 'helpers.dart';

/// A sharp picture: a black and white checkerboard has very hard edges.
File sharpPhoto(Directory dir) {
  final im = img.Image(width: 320, height: 320);
  for (var y = 0; y < 320; y++) {
    for (var x = 0; x < 320; x++) {
      final on = ((x ~/ 8) + (y ~/ 8)) % 2 == 0;
      im.setPixelRgb(x, y, on ? 255 : 0, on ? 255 : 0, on ? 255 : 0);
    }
  }
  final f = File('${dir.path}/sharp.png')..writeAsBytesSync(img.encodePng(im));
  return f;
}

/// A blurry picture: one flat colour, so there are no edges at all.
File blurryPhoto(Directory dir) {
  final im = img.Image(width: 320, height: 320);
  img.fill(im, color: img.ColorRgb8(128, 128, 128));
  final f = File('${dir.path}/blurry.png')..writeAsBytesSync(img.encodePng(im));
  return f;
}

void main() {
  late Directory tempDir;
  late CustomWordService toys;

  setUp(() async {
    await useEmptyStorage();
    tempDir = await Directory.systemTemp.createTemp('kidscribe_toys');
    toys = CustomWordService();
  });

  tearDown(() async {
    if (tempDir.existsSync()) await tempDir.delete(recursive: true);
  });

  group('US_20 the photo check', () {
    test('T_48 a blurry photo is refused and the parent is asked again',
        () async {
      final check = await toys.checkPhoto(blurryPhoto(tempDir).path);

      expect(check.clear, isFalse);
      expect(check.message, isNotNull);
      expect(check.message, contains('blurry'));
    });

    test('a sharp photo is accepted', () async {
      final check = await toys.checkPhoto(sharpPhoto(tempDir).path);

      expect(check.clear, isTrue);
      expect(check.sharpness,
          greaterThanOrEqualTo(CustomWordService.minSharpness));
      expect(check.message, isNull);
    });

    test('a file that is not a photo is refused politely', () async {
      final notAPhoto = File('${tempDir.path}/notes.txt')
        ..writeAsStringSync('hello');

      final check = await toys.checkPhoto(notAPhoto.path);

      expect(check.clear, isFalse);
      expect(check.message, isNotNull);
    });
  });

  group('US_20 the toy word rules', () {
    test('a good word is accepted', () {
      expect(CustomWordService.validateWord('DINOSAUR'), isNull);
      expect(CustomWordService.validateWord('ball'), isNull);
    });

    test('an empty word is refused', () {
      expect(CustomWordService.validateWord('  '), isNotNull);
    });

    test('a word that is too short or too long is refused', () {
      expect(CustomWordService.validateWord('A'), contains('2 to 8'));
      expect(CustomWordService.validateWord('ELEPHANTS'), contains('2 to 8'));
    });

    test('numbers and spaces are refused, because the child must write it',
        () {
      expect(CustomWordService.validateWord('CAR 2'), contains('letters only'));
      expect(CustomWordService.validateWord('T0Y'), contains('letters only'));
    });

    test('a toy word becomes a word the child can practice', () {
      const word = CustomWord('TEDDY', '', 0);
      expect(word.asPracticeWord.word, 'TEDDY');
      expect(word.asPracticeWord.emoji, CustomWord.emoji);
    });
  });
}
