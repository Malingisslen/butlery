/// Direct unit tests for [InstructionCorrection] (BUT-1149 coverage burndown —
/// previously zero direct coverage).
///
/// Records a single instruction-step edit (add/remove/modify/reorder). The logic
/// worth pinning: each factory sets the right type + index/text fields (null
/// where the edit has no such side), the 200-char truncation, null-omitting
/// toJson, and the fromJson round-trip with the textModified type fallback.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/models/parsing/instruction_correction.dart';

void main() {
  group('factories', () {
    test('added sets corrected side only', () {
      final c = InstructionCorrection.added(
        correctedIndex: 2,
        correctedText: 'Stir well',
      );
      expect(c.type, InstructionCorrectionType.added);
      expect(c.correctedIndex, 2);
      expect(c.correctedText, 'Stir well');
      expect(c.originalIndex, isNull);
      expect(c.originalText, isNull);
    });

    test('removed sets original side only', () {
      final c = InstructionCorrection.removed(
        originalIndex: 1,
        originalText: 'Old step',
      );
      expect(c.type, InstructionCorrectionType.removed);
      expect(c.originalIndex, 1);
      expect(c.originalText, 'Old step');
      expect(c.correctedIndex, isNull);
      expect(c.correctedText, isNull);
    });

    test('modified sets both sides', () {
      final c = InstructionCorrection.modified(
        originalIndex: 0,
        correctedIndex: 0,
        originalText: 'Before',
        correctedText: 'After',
      );
      expect(c.type, InstructionCorrectionType.textModified);
      expect(c.originalText, 'Before');
      expect(c.correctedText, 'After');
    });

    test('reordered carries the same text on both sides', () {
      final c = InstructionCorrection.reordered(
        originalIndex: 3,
        correctedIndex: 1,
        text: 'Move me',
      );
      expect(c.type, InstructionCorrectionType.reordered);
      expect(c.originalText, 'Move me');
      expect(c.correctedText, 'Move me');
      expect(c.originalIndex, 3);
      expect(c.correctedIndex, 1);
    });
  });

  group('truncation', () {
    test('text over 200 chars is truncated with an ellipsis', () {
      final long = 'x' * 250;
      final c = InstructionCorrection.added(
        correctedIndex: 0,
        correctedText: long,
      );
      expect(c.correctedText, hasLength(200));
      expect(c.correctedText!.endsWith('...'), isTrue);
    });

    test('text at or under 200 chars is left intact', () {
      final exact = 'y' * 200;
      final c = InstructionCorrection.added(
        correctedIndex: 0,
        correctedText: exact,
      );
      expect(c.correctedText, exact);
    });
  });

  group('JSON', () {
    test('toJson always carries type and omits null fields', () {
      final json = InstructionCorrection.added(
        correctedIndex: 1,
        correctedText: 'Add',
      ).toJson();
      expect(json['type'], 'added');
      expect(json['correctedIndex'], 1);
      expect(json.containsKey('originalIndex'), isFalse);
      expect(json.containsKey('originalText'), isFalse);
    });

    test('round-trips through fromJson', () {
      final original = InstructionCorrection.modified(
        originalIndex: 0,
        correctedIndex: 1,
        originalText: 'Before',
        correctedText: 'After',
      );
      final restored = InstructionCorrection.fromJson(original.toJson());
      expect(restored.type, InstructionCorrectionType.textModified);
      expect(restored.originalIndex, 0);
      expect(restored.correctedIndex, 1);
      expect(restored.originalText, 'Before');
      expect(restored.correctedText, 'After');
    });

    test('fromJson falls back to textModified for an unknown type', () {
      final c = InstructionCorrection.fromJson({'type': 'bogus'});
      expect(c.type, InstructionCorrectionType.textModified);
    });
  });
}
