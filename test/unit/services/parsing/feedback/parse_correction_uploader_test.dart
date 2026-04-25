import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/models/parsing/field_correction.dart';
import 'package:butlery/models/parsing/ingredient_correction.dart';
import 'package:butlery/models/parsing/instruction_correction.dart';
import 'package:butlery/models/parsing/parse_metadata.dart';
import 'package:butlery/models/parsing/parsing_correction.dart';
import 'package:butlery/services/parsing/feedback/parse_correction_uploader.dart';

/// BUT-595: client-side fan-out + redaction-skip + error-swallow tests.
///
/// We exercise the public [ParseCorrectionUploader] surface with an in-memory
/// callable invoker. The real Cloud Function is tested separately
/// (functions/src/__tests__/log-parse-correction.test.ts).
void main() {
  ParsingCorrection makeCorrection({
    String? successfulTier = 'LLM',
    FieldCorrection? title,
    FieldCorrection? portions,
    List<IngredientCorrection> ingredients = const [],
    List<InstructionCorrection> instructions = const [],
  }) {
    return ParsingCorrection.create(
      recipeId: 'recipe-123',
      userId: 'user-abc',
      source: ImportSource.url,
      domain: 'ica.se',
      successfulTier: successfulTier,
      originalQuality: 0.6,
      titleCorrection: title,
      portionsCorrection: portions,
      ingredientCorrections: ingredients,
      instructionCorrections: instructions,
    );
  }

  group('ParseCorrectionUploader.expandFields', () {
    test('one diffed field expands to one payload', () {
      final uploader = ParseCorrectionUploader(invoker: (_, __) async {});
      final correction = makeCorrection(
        title: const FieldCorrection(
          originalValue: 'Kötbullar',
          correctedValue: 'Köttbullar',
        ),
      );

      final payloads = uploader.expandFields(correction);

      expect(payloads, hasLength(1));
      expect(payloads.first.correctedField, 'title');
      expect(payloads.first.fromValue, 'Kötbullar');
      expect(payloads.first.toValue, 'Köttbullar');
    });

    test('three diffed fields produce three payloads (per-field aggregation)',
        () {
      final uploader = ParseCorrectionUploader(invoker: (_, __) async {});
      final correction = makeCorrection(
        title: const FieldCorrection(originalValue: 'A', correctedValue: 'B'),
        portions:
            const FieldCorrection(originalValue: '4', correctedValue: '6'),
        ingredients: [
          IngredientCorrection.modified(
            originalIndex: 0,
            correctedIndex: 0,
            originalLine: '3 dl mjolk',
            correctedLine: '3 dl mjölk',
            quantityChanged: false,
            unitChanged: false,
            nameChanged: true,
          ),
        ],
      );

      final payloads = uploader.expandFields(correction);

      expect(payloads.map((p) => p.correctedField),
          containsAll(['title', 'portions', 'ingredients']));
      expect(payloads, hasLength(3));
    });

    test('whitespace-only diff is dropped before upload', () {
      final uploader = ParseCorrectionUploader(invoker: (_, __) async {});
      final correction = makeCorrection(
        title: const FieldCorrection(
          originalValue: 'Köttbullar',
          correctedValue: '  Köttbullar  ',
        ),
      );

      // The FieldCorrection.create factory itself wouldn't emit this — but a
      // raw construction can. The uploader is the second line of defence.
      final payloads = uploader.expandFields(correction);
      expect(payloads, isEmpty,
          reason: 'whitespace-only diffs carry no quality signal');
    });

    test('case-only diff is dropped before upload', () {
      final uploader = ParseCorrectionUploader(invoker: (_, __) async {});
      final correction = makeCorrection(
        title: const FieldCorrection(
          originalValue: 'Köttbullar',
          correctedValue: 'KÖTTBULLAR',
        ),
      );

      final payloads = uploader.expandFields(correction);
      expect(payloads, isEmpty);
    });
  });

  group('ParseCorrectionUploader.upload', () {
    test('upload fires one callable per corrected field', () {
      final calls = <Map<String, dynamic>>[];
      final uploader = ParseCorrectionUploader(
        invoker: (name, body) async {
          calls.add({'name': name, 'body': body});
        },
      );

      final correction = makeCorrection(
        title: const FieldCorrection(originalValue: 'a', correctedValue: 'b'),
        portions:
            const FieldCorrection(originalValue: '4', correctedValue: '6'),
      );

      final n = uploader.upload(correction: correction, salt: 'test-salt');

      expect(n, 2);
      expect(calls, hasLength(2));
      expect(calls.every((c) => c['name'] == 'logParseCorrection'), isTrue);
    });

    test('upload swallows callable errors silently', () async {
      final uploader = ParseCorrectionUploader(
        invoker: (_, __) async => throw Exception('network fail'),
      );

      final correction = makeCorrection(
        title: const FieldCorrection(originalValue: 'a', correctedValue: 'b'),
      );

      // Returns enqueued count; the awaitable failure is unawaited inside.
      final n = uploader.upload(correction: correction, salt: 'salt');

      // Let the unawaited future settle.
      await Future<void>.delayed(Duration.zero);

      expect(n, 1, reason: 'enqueued before the failure');
      // No exception should escape — the test reaching this line is the proof.
    });

    test('upload hashes userId/recipeId before sending', () {
      final calls = <Map<String, dynamic>>[];
      final uploader = ParseCorrectionUploader(
        invoker: (name, body) async {
          calls.add(body);
        },
      );

      final correction = makeCorrection(
        title: const FieldCorrection(originalValue: 'a', correctedValue: 'b'),
      );

      uploader.upload(correction: correction, salt: 'test-salt');

      expect(calls, hasLength(1));
      final sentBody = calls.first;
      // Must NOT contain raw IDs.
      expect(sentBody.values.contains('user-abc'), isFalse);
      expect(sentBody.values.contains('recipe-123'), isFalse);
      // Must contain hex SHA-256 hashes (64 hex chars).
      final userHash = sentBody['userIdHash'] as String;
      final recipeHash = sentBody['recipeIdHash'] as String;
      expect(userHash, hasLength(64));
      expect(recipeHash, hasLength(64));
      expect(RegExp(r'^[a-f0-9]+$').hasMatch(userHash), isTrue);
      // Salt actually mixes in: same id + different salt = different hash.
      final hashA = ParseCorrectionUploader.hashId('user-abc', 'salt-a');
      final hashB = ParseCorrectionUploader.hashId('user-abc', 'salt-b');
      expect(hashA, isNot(equals(hashB)));
    });

    test('upload maps Dart tier identifier to server snake_case', () {
      final calls = <Map<String, dynamic>>[];
      final uploader = ParseCorrectionUploader(
        invoker: (_, body) async {
          calls.add(body);
        },
      );

      final correction = makeCorrection(
        successfulTier: 'SchemaOrg',
        title: const FieldCorrection(originalValue: 'a', correctedValue: 'b'),
      );

      uploader.upload(correction: correction, salt: 's');
      expect(calls.first['sourceTier'], 'schema_org');
    });

    test('upload skips entirely when sourceTier is unknown', () {
      var called = 0;
      final uploader = ParseCorrectionUploader(
        invoker: (_, __) async {
          called++;
        },
      );

      final correction = makeCorrection(
        successfulTier: 'NonExistentTier',
        title: const FieldCorrection(originalValue: 'a', correctedValue: 'b'),
      );

      final n = uploader.upload(correction: correction, salt: 's');
      expect(n, 0);
      expect(called, 0);
    });

    test('upload only includes promptVersion when tier is llm', () {
      final calls = <Map<String, dynamic>>[];
      final uploader = ParseCorrectionUploader(
        invoker: (_, body) async {
          calls.add(body);
        },
      );

      // Non-llm tier: promptVersion must NOT be sent.
      final reg = makeCorrection(
        successfulTier: 'RuleBased',
        title: const FieldCorrection(originalValue: 'a', correctedValue: 'b'),
      );
      uploader.upload(correction: reg, salt: 's', promptVersion: 'v1');
      expect(calls.last.containsKey('promptVersion'), isFalse);

      // llm tier: promptVersion IS sent.
      calls.clear();
      final llm = makeCorrection(
        successfulTier: 'LLM',
        title: const FieldCorrection(originalValue: 'a', correctedValue: 'b'),
      );
      uploader.upload(correction: llm, salt: 's', promptVersion: 'v3.1');
      expect(calls.last['promptVersion'], 'v3.1');
    });

    test('truncate caps oversize values at 500 chars', () {
      final long = 'x' * 600;
      final out = ParseCorrectionUploader.truncate(long);
      expect(out.length, kMaxCorrectionValueChars);
      expect(out.length, 500);
    });

    test('upload aggregates instructions into one ingredient/instruction doc',
        () {
      final calls = <Map<String, dynamic>>[];
      final uploader = ParseCorrectionUploader(
        invoker: (_, body) async {
          calls.add(body);
        },
      );

      final correction = makeCorrection(
        instructions: [
          InstructionCorrection.modified(
            originalIndex: 0,
            correctedIndex: 0,
            originalText: 'Step one wrong',
            correctedText: 'Step one fixed',
          ),
          InstructionCorrection.modified(
            originalIndex: 1,
            correctedIndex: 1,
            originalText: 'Step two wrong',
            correctedText: 'Step two fixed',
          ),
        ],
      );

      uploader.upload(correction: correction, salt: 's');

      // Two corrected steps → still ONE per-field doc with newline-joined text.
      expect(calls, hasLength(1));
      expect(calls.first['correctedField'], 'instructions');
      expect(calls.first['fromValue'], contains('Step one wrong'));
      expect(calls.first['fromValue'], contains('Step two wrong'));
      expect(calls.first['toValue'], contains('Step one fixed'));
    });
  });

  group('ParseCorrectionUploader.isWhitespaceOrCaseOnly', () {
    test('whitespace collapse', () {
      expect(ParseCorrectionUploader.isWhitespaceOrCaseOnly('a  b', 'a b'),
          isTrue);
    });
    test('case fold', () {
      expect(
          ParseCorrectionUploader.isWhitespaceOrCaseOnly('FOO', 'foo'), isTrue);
    });
    test('real diff', () {
      expect(ParseCorrectionUploader.isWhitespaceOrCaseOnly('foo', 'bar'),
          isFalse);
    });
  });
}
