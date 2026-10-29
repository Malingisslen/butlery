/// Parser shadow comparison (ADR-0037), client half: what [ParserShadowSampler]
/// sends, and above all what it never sends — nothing without AI consent,
/// nothing for a guest, nothing for voice or file, nothing from a failed
/// import — and that a slow or failing callable never reaches the caller.
library;

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/models/account/user_consent.dart';
import 'package:butlery/models/recipe/recipe_ingredient.dart';
import 'package:butlery/models/recipe/source_artefact.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/services/import/import_event.dart';
import 'package:butlery/services/import/import_manager_result.dart';
import 'package:butlery/services/import/parser_shadow_sampler.dart';
import 'package:butlery/services/llm/llm_service.dart';

import '../../../infrastructure/factories/recipe_factory.dart';
import '../../../infrastructure/mocks/production_mocks.dart';

class _MockLlmService extends Mock implements LlmService {}

const _text = 'Pannkakor\n3 dl vetemjöl\n6 dl mjölk\nVispa och stek.';

Recipe _recipe(SourceArtefactType? type, {String payload = _text}) {
  final base = RecipeFactory.build(id: 'r1', title: 'Pannkakor');
  return base.copyWith(
    ingredients: const ['3 dl vetemjöl', 'en nypa salt'],
    structuredIngredients: const [
      RecipeIngredient(
        amount: 3,
        unit: 'dl',
        name: 'vetemjöl',
        raw: '3 dl vetemjöl',
      ),
      RecipeIngredient(name: 'salt', note: 'en nypa', raw: 'en nypa salt'),
    ],
    instructions: const ['Vispa och stek.'],
    portions: 4,
    timeMinutes: 30,
    sourceArtefact: type == null
        ? null
        : SourceArtefact(
            type: type,
            payload: payload,
            fetchedAt: DateTime.utc(2026, 10, 29),
          ),
  );
}

ImportManagerResult _ok(Recipe r, [Map<String, dynamic>? meta]) =>
    ImportManagerResult.success(r, strategy: 'Text Import', metadata: meta);

void main() {
  late MockConsentService consent;
  late _MockLlmService llm;
  late bool guest;

  setUpAll(() {
    registerFallbackValue(<String, dynamic>{});
    registerFallbackValue(ConsentPurpose.aiProcessing);
  });

  setUp(() {
    consent = MockConsentService();
    llm = _MockLlmService();
    guest = false;
    when(
      () => consent.hasConsent(ConsentPurpose.aiProcessing),
    ).thenAnswer((_) async => true);
    when(() => llm.shadowCompareImport(any())).thenAnswer((_) async => true);
  });

  ParserShadowSampler sampler({
    Duration timeout = const Duration(seconds: 30),
  }) => ParserShadowSampler(
    consentService: consent,
    llmService: llm,
    isGuest: () => guest,
    timeout: timeout,
  );

  Map<String, dynamic> sentPayload() =>
      verify(() => llm.shadowCompareImport(captureAny())).captured.single
          as Map<String, dynamic>;

  group('sends', () {
    test('a pasted text: its text, the parser output and its labels', () async {
      final took = await sampler().sample(
        ImportChannel.text,
        _ok(_recipe(SourceArtefactType.textPaste), {
          'successfulTier': 'rules',
          'parserVersion': '2.0.0',
        }),
      );

      expect(took, isTrue);
      final p = sentPayload();
      expect(p['text'], _text);
      expect(p['channel'], 'text');
      expect(p['successfulTier'], 'rules');
      expect(p['parserVersion'], '2.0.0');
      expect(
        p.containsKey('photoAiFallback'),
        isFalse,
        reason: 'only photos carry it',
      );
    });

    test(
      'a photo: its OCR text and whether the import already used the AI',
      () async {
        await sampler().sample(
          ImportChannel.photo,
          _ok(_recipe(SourceArtefactType.photoOcr), {'usedLlm': true}),
        );

        final p = sentPayload();
        expect(p['channel'], 'photo');
        expect(p['photoAiFallback'], isTrue);
      },
    );

    test(
      'a photo the parser read alone, or with no metadata, is no fallback',
      () async {
        for (final meta in [
          {'usedLlm': false},
          null,
        ]) {
          clearInteractions(llm);
          await sampler().sample(
            ImportChannel.photo,
            _ok(_recipe(SourceArtefactType.photoOcr), meta),
          );
          expect(sentPayload()['photoAiFallback'], isFalse, reason: '$meta');
        }
      },
    );

    test('the import channel names the sample, not the capture type', () async {
      for (final (channel, type, expected) in [
        (ImportChannel.photo, SourceArtefactType.textPaste, 'photo'),
        (ImportChannel.text, SourceArtefactType.photoOcr, 'text'),
      ]) {
        clearInteractions(llm);
        await sampler().sample(channel, _ok(_recipe(type), {'usedLlm': true}));
        final p = sentPayload();
        expect(p['channel'], expected, reason: '$channel / $type');
        expect(p.containsKey('photoAiFallback'), expected == 'photo');
      }
    });

    test(
      'a label the server would refuse is left out, not the sample',
      () async {
        await sampler().sample(
          ImportChannel.text,
          _ok(_recipe(SourceArtefactType.textPaste), {
            'successfulTier': 'tier 2 ü',
          }),
        );

        expect(sentPayload().containsKey('successfulTier'), isFalse);
      },
    );
  });

  group('never sends', () {
    Future<void> expectNothingSent(Future<bool> run) async {
      expect(await run, isFalse);
      verifyNever(() => llm.shadowCompareImport(any()));
    }

    test('without AI consent', () async {
      when(
        () => consent.hasConsent(ConsentPurpose.aiProcessing),
      ).thenAnswer((_) async => false);
      await expectNothingSent(
        sampler().sample(
          ImportChannel.text,
          _ok(_recipe(SourceArtefactType.textPaste)),
        ),
      );
    });

    test('for a guest, and asks for no consent first', () async {
      guest = true;
      await expectNothingSent(
        sampler().sample(
          ImportChannel.text,
          _ok(_recipe(SourceArtefactType.textPaste)),
        ),
      );
      verifyNever(() => consent.hasConsent(any()));
    });

    test('for voice or file', () async {
      for (final channel in [ImportChannel.voice, ImportChannel.file]) {
        await expectNothingSent(
          sampler().sample(channel, _ok(_recipe(SourceArtefactType.textPaste))),
        );
      }
    });

    test('for any link import: a plain URL or a caption', () async {
      for (final (type, payload) in [
        (SourceArtefactType.url, 'https://ica.se/x'),
        (SourceArtefactType.tiktokCaption, _text),
        (SourceArtefactType.youtubeTranscript, _text),
        (SourceArtefactType.instagramCaption, _text),
      ]) {
        await expectNothingSent(
          sampler().sample(
            ImportChannel.link,
            _ok(_recipe(type, payload: payload)),
          ),
        );
      }
    });

    test('for dictation, or a recipe with no capture at all', () async {
      await expectNothingSent(
        sampler().sample(
          ImportChannel.text,
          _ok(_recipe(SourceArtefactType.voiceDictation)),
        ),
      );
      await expectNothingSent(
        sampler().sample(ImportChannel.text, _ok(_recipe(null))),
      );
    });

    test('from a failed import', () async {
      await expectNothingSent(
        sampler().sample(
          ImportChannel.text,
          ImportManagerResult.failure(
            'nej',
            recipe: _recipe(SourceArtefactType.textPaste),
          ),
        ),
      );
    });
  });

  group('never reaches the caller', () {
    test('a failing callable is swallowed', () async {
      when(() => llm.shadowCompareImport(any())).thenThrow(Exception('boom'));
      expect(
        await sampler().sample(
          ImportChannel.text,
          _ok(_recipe(SourceArtefactType.textPaste)),
        ),
        isFalse,
      );
    });

    test('a failing consent read is swallowed', () async {
      when(() => consent.hasConsent(any())).thenThrow(Exception('offline'));
      expect(
        await sampler().sample(
          ImportChannel.text,
          _ok(_recipe(SourceArtefactType.textPaste)),
        ),
        isFalse,
      );
    });

    test('a callable that never answers is cut off by the timeout', () async {
      final never = Completer<bool>();
      when(
        () => llm.shadowCompareImport(any()),
      ).thenAnswer((_) => never.future);

      final took = await sampler(
        timeout: const Duration(milliseconds: 20),
      ).sample(ImportChannel.text, _ok(_recipe(SourceArtefactType.textPaste)));

      expect(took, isFalse);
    });
  });

  group('parserOutputOf: the corpus GoldRecipe shape', () {
    test('every ingredient line, with its parsed parts as strings', () {
      final out = ParserShadowSampler.parserOutputOf(
        _recipe(SourceArtefactType.textPaste),
      );

      expect(out, {
        'title': 'Pannkakor',
        'portions': '4',
        'timeMinutes': 30,
        'ingredients': [
          {
            'name': 'vetemjöl',
            'originalLine': '3 dl vetemjöl',
            'quantity': '3',
            'unit': 'dl',
          },
          {
            'name': 'salt',
            'originalLine': 'en nypa salt',
            'preparation': 'en nypa',
          },
        ],
        'instructions': ['Vispa och stek.'],
      });
    });
  });
}
