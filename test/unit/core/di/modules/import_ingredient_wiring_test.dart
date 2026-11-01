/// BUT-1508: the text parser is built in many places (text, photo, voice, URL
/// and the three caption pipelines). A place that is not handed the shared
/// ingredient reader quietly drops back to the regex deriver, so every place
/// has its own witness here: the reader registered in the container must be
/// the one that parses that route's text.
library;

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/core/di/modules/content_module.dart';
import 'package:butlery/core/di/modules/import_registrations.dart';
import 'package:butlery/models/parsing/field_result.dart';
import 'package:butlery/models/parsing/parsed_ingredient.dart';
import 'package:butlery/services/import/import_links.dart';
import 'package:butlery/services/import/import_manager.dart';
import 'package:butlery/services/import/llm/llm_enhancement_service.dart';
import 'package:butlery/services/import/models/import_result_v2.dart';
import 'package:butlery/services/import/photo_import_strategy.dart';
import 'package:butlery/services/import/pipelines/instagram_pipeline.dart';
import 'package:butlery/services/import/pipelines/tiktok_pipeline.dart';
import 'package:butlery/services/import/text_import_strategy.dart';
import 'package:butlery/services/import/url_import_strategy.dart';
import 'package:butlery/services/import/voice_import_strategy.dart';
import 'package:butlery/services/import/youtube/youtube_import_strategy.dart';
import 'package:butlery/services/import/youtube/youtube_transcript_service.dart';
import 'package:butlery/services/parsing/ingredient_parsing_strategy.dart';
import 'package:butlery/services/unified/operations/personal_recipe_operations.dart';
import 'package:http/http.dart' as http;

class _CountingReader extends IngredientParsingStrategy {
  int calls = 0;

  @override
  Future<FieldResult<List<ParsedIngredient>>> parseLines(
    List<String> lines, {
    bool ocrCorrection = false,
  }) {
    calls++;
    return super.parseLines(lines, ocrCorrection: ocrCorrection);
  }
}

class _Personal extends Mock implements PersonalRecipeOperations {}

class _Llm extends Mock implements LlmEnhancementService {}

class _Transcripts extends Mock implements YouTubeTranscriptService {}

class _Client extends Mock implements http.Client {}

const _recipeText =
    'Pannkakor\n'
    'Ingredienser:\n'
    '3 ägg\n'
    '5 dl mjölk\n'
    '2 dl vetemjöl\n'
    'Gör så här:\n'
    'Vispa ihop och stek i smör.';

Future<void> _expectParsedBy(
  _CountingReader reader,
  TextImportStrategy? text,
  String route,
) async {
  expect(text, isNotNull, reason: '$route has no text parser handed in');
  final before = reader.calls;
  await text!.import(_recipeText);
  expect(
    reader.calls,
    greaterThan(before),
    reason: '$route parsed its ingredients without the shared reader',
  );
}

void main() {
  late _CountingReader reader;
  late GetIt userScope;

  setUpAll(() => registerFallbackValue(Uint8List(0)));

  setUp(() async {
    reader = _CountingReader();
    userScope = GetIt.asNewInstance()
      ..registerSingleton<IngredientParsingStrategy>(reader);
  });

  tearDown(() async {
    await userScope.reset();
    await GetIt.instance.reset();
  });

  test('the link reaches the reader of the signed-in container, or null', () {
    expect(
      ImportRegistrations.links(userScope).ingredientStrategy(),
      same(reader),
    );
    final bare = GetIt.asNewInstance();
    addTearDown(bare.reset);
    expect(ImportRegistrations.links(bare).ingredientStrategy(), isNull);
  });

  group('the import manager hands the reader to', () {
    late ImportManager manager;

    setUp(() {
      manager = ImportManager(
        _Personal(),
        links: ImportLinks(ingredientStrategy: () => reader),
      );
    });

    test('text import', () async {
      await _expectParsedBy(reader, manager.getTextImportStrategy(), 'text');
    });

    test('photo import, which shares the manager text parser', () async {
      final photo = manager.availableStrategies
          .whereType<PhotoImportStrategy>()
          .single;
      expect(photo.textStrategy, same(manager.getTextImportStrategy()));
      await _expectParsedBy(reader, photo.textStrategy, 'photo');
    });

    test('voice import, which shares the manager text parser', () async {
      final voice = manager.availableStrategies
          .whereType<VoiceImportStrategy>()
          .single;
      expect(voice.textStrategy, same(manager.getTextImportStrategy()));
      await _expectParsedBy(reader, voice.textStrategy, 'voice');
    });

    test('photo AI vision, through the same links', () async {
      final llm = _Llm();
      when(
        () => llm.extractFromImage(
          any(),
          context: any(named: 'context'),
          isHandwritten: any(named: 'isHandwritten'),
        ),
      ).thenAnswer(
        (_) async => ImportFailure(
          message: 'vision failed',
          errorCode: ImportErrorCode.ocrFailed,
          pipeline: 'photo',
          tier: 4,
        ),
      );
      final withLlm = ImportManager(
        _Personal(),
        links: ImportLinks(llmEnhancement: () => llm),
      );
      final photo = withLlm.availableStrategies
          .whereType<PhotoImportStrategy>()
          .single;

      await photo.import(
        'photo',
        options: {
          'imageBytes': Uint8List.fromList([1, 2, 3]),
          'visionOnly': true,
        },
      );

      verify(
        () => llm.extractFromImage(
          any(),
          context: any(named: 'context'),
          isHandwritten: any(named: 'isHandwritten'),
        ),
      ).called(1);
    });

    test('URL import, which builds a text parser per use', () async {
      final url = manager.availableStrategies
          .whereType<UrlImportStrategy>()
          .single;
      await _expectParsedBy(reader, url.newTextStrategy(), 'url');
    });
  });

  test('a manager without the link still parses (regex fallback)', () async {
    final manager = ImportManager(_Personal());
    final result = await manager.getTextImportStrategy().import(_recipeText);
    expect(result.isSuccess, isTrue);
    expect(reader.calls, 0);
  });

  test('the caption reader built by the registrations uses it', () async {
    final rules = ImportRegistrations.captionRules(userScope);
    await _expectParsedBy(reader, rules.text, 'caption rules');
  });

  test(
    'YouTube, TikTok and Instagram are each built with that caption reader',
    () async {
      final app = GetIt.instance
        ..registerSingleton<YouTubeTranscriptService>(_Transcripts())
        ..registerSingleton<http.Client>(_Client());
      final scope = GetIt.asNewInstance();
      addTearDown(scope.reset);
      await ContentModule().configureUserScope(scope);
      if (scope.isRegistered<LlmEnhancementService>()) {
        scope.unregister<LlmEnhancementService>();
      }
      scope.registerSingleton<LlmEnhancementService>(_Llm());
      if (scope.isRegistered<IngredientParsingStrategy>()) {
        scope.unregister<IngredientParsingStrategy>();
      }
      scope.registerSingleton<IngredientParsingStrategy>(reader);
      expect(app.isRegistered<http.Client>(), isTrue);

      await _expectParsedBy(
        reader,
        scope<YouTubeImportStrategy>().rules.text,
        'YouTube',
      );
      await _expectParsedBy(
        reader,
        scope<TikTokPipeline>().rules.text,
        'TikTok',
      );
      await _expectParsedBy(
        reader,
        scope<InstagramPipeline>().rules.text,
        'Instagram',
      );
    },
  );
}
