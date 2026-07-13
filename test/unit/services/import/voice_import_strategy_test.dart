/// Voice import path tests (voice plan roadmap #2, Data/Integrations
/// panel conditions).
///
/// Intention: prove voice's END-TO-END identity — a dictated import must
/// (a) parse via the text pipeline, (b) carry SourceArtefactType
/// .voiceDictation (never textPaste), and (c) log its parse event under
/// source 'voice' through the ImportManager choke point — so dictation
/// never pollutes the pasted-text telemetry bucket and its LLM-escalation
/// rate is measurable.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart'
    as app_provider;
import 'package:butlery/models/recipe/source_artefact.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/services/import/import_manager.dart';
import 'package:butlery/services/import/import_rate_limiter.dart';
import 'package:butlery/services/import/import_strategy.dart';
import 'package:butlery/services/import/models/rate_limit_models.dart';
import 'package:butlery/services/import/text_import_strategy.dart';
import 'package:butlery/services/import/voice_import_strategy.dart';
import 'package:butlery/services/parsing/parse_event_logger.dart';

import '../../../test_support/base_unit_test.dart';
import '../../../infrastructure/factories/recipe_factory.dart';
import '../../../infrastructure/mocks/production_mocks.dart';
import '../../../infrastructure/di/test_service_locator.dart';

const _assembledTranscript = '''
Mormors köttbullar

Ingredienser:
500 g köttfärs
2 dl mjölk

Gör så här:
Blanda och stek.''';

class _SpyParseEventLogger extends ParseEventLogger {
  final List<({String source, bool success})> events = [];

  @override
  void logEvent({
    required String? url,
    required String source,
    required bool success,
    bool fromCache = false,
    required int parseTimeMs,
    String? parserVersion,
    String? domain,
    String? successfulTier,
    double? finalQuality,
    bool? usedLlm,
    double? totalCostSek,
    List<Map<String, dynamic>>? tierAttempts,
    bool unknownDomain = false,
    String? promptVersion,
  }) {
    events.add((source: source, success: success));
  }
}

/// Allows every checkLimit and captures recorded usage, so the test can
/// prove a successful voice import actually counts against the quota.
class _RecordingRateLimiter extends Fake implements ImportRateLimiter {
  final List<ImportOperation> recorded = [];

  @override
  Future<RateLimitResult> checkLimit(ImportOperation operation) async =>
      const RateLimitAllowed(
        remainingInWindow: 5,
        limitType: LimitType.perMinute,
      );

  @override
  Future<void> recordUsage(ImportOperation operation, {double? llmCost}) async {
    recorded.add(operation);
  }
}

class _StubTextStrategy extends TextImportStrategy {
  _StubTextStrategy(this._result);
  final ImportResult _result;
  String? seenInput;

  @override
  Future<ImportResult> import(
    String input, {
    Map<String, dynamic>? options,
  }) async {
    seenInput = input;
    return _result;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Recipe parsedRecipe;

  setUpAll(() async {
    await BaseUnitTest.setupUnit();
    SharedPreferences.setMockInitialValues({});
    registerFallbackValue(RecipeFactory.build());
  });

  setUp(() {
    parsedRecipe = RecipeFactory.build(id: 'r1', title: 'Mormors köttbullar');
  });

  tearDown(() async {
    BaseUnitTest.resetMocks();
    await TestServiceLocator.reset();
  });

  tearDownAll(() async {
    await BaseUnitTest.teardownUnit();
  });

  group('VoiceImportStrategy', () {
    test('delegates parsing to the text strategy and re-stamps the '
        'artefact as voiceDictation with the transcript payload', () async {
      final stub = _StubTextStrategy(ImportResult.success(parsedRecipe));
      final strategy = VoiceImportStrategy(textStrategy: stub);

      final result = await strategy.import(_assembledTranscript);

      expect(stub.seenInput, _assembledTranscript);
      expect(result.isSuccess, isTrue);
      final artefact = result.recipe!.core.sourceArtefact;
      expect(
        artefact?.type,
        SourceArtefactType.voiceDictation,
        reason:
            'a dictated recipe stamped textPaste would corrupt provenance '
            'and the text telemetry bucket (panel condition)',
      );
      expect(
        artefact?.payload,
        _assembledTranscript,
        reason: 'the transcript is the re-extract source (audio not stored)',
      );
    });

    test('a failed text parse passes through unmodified', () async {
      final strategy = VoiceImportStrategy(
        textStrategy: _StubTextStrategy(ImportResult.failure('no recipe')),
      );

      final result = await strategy.import('bara brus');

      expect(result.isSuccess, isFalse);
      expect(result.errorMessage, 'no recipe');
    });

    test('is never auto-selected: canHandle is false even for recipe text', () {
      expect(VoiceImportStrategy().canHandle(_assembledTranscript), isFalse);
    });
  });

  group('ImportManager.importVoiceTranscript', () {
    test('routes through the telemetry choke point: one parse event with '
        'source=voice', () async {
      final spyLogger = _SpyParseEventLogger();
      final strategy = VoiceImportStrategy(
        textStrategy: _StubTextStrategy(ImportResult.success(parsedRecipe)),
      );
      final manager = ImportManager.withStrategies(
        MockPersonalRecipeOperations(),
        [strategy],
        eventLogger: spyLogger,
      );

      final result = await manager.importVoiceTranscript(_assembledTranscript);

      expect(result.isSuccess, isTrue);
      expect(spyLogger.events, hasLength(1));
      expect(
        spyLogger.events.single.source,
        'voice',
        reason:
            "source must be 'voice', not 'text' — the distinct bucket is "
            'what makes the LLM-escalation rate of dictation measurable',
      );
      expect(spyLogger.events.single.success, isTrue);
    });

    test('a failed voice parse logs a failure event under voice', () async {
      final spyLogger = _SpyParseEventLogger();
      final strategy = VoiceImportStrategy(
        textStrategy: _StubTextStrategy(ImportResult.failure('unparseable')),
      );
      final manager = ImportManager.withStrategies(
        MockPersonalRecipeOperations(),
        [strategy],
        eventLogger: spyLogger,
      );

      final result = await manager.importVoiceTranscript('brus');

      expect(result.isSuccess, isFalse);
      expect(spyLogger.events.single.source, 'voice');
      expect(spyLogger.events.single.success, isFalse);
    });

    test('a successful voice import records rate-limit usage under '
        "'voice'; a failed one records nothing (review finding #6)", () async {
      // Without recordUsage the up-front checkLimit never sees any usage —
      // voice imports would be effectively unlimited.
      final limiter = _RecordingRateLimiter();
      final getIt = GetIt.instance;
      if (getIt.isRegistered<ImportRateLimiter>()) {
        getIt.unregister<ImportRateLimiter>();
      }
      getIt.registerSingleton<ImportRateLimiter>(limiter);
      app_provider.ServiceLocator.reset();
      app_provider.ServiceLocator.initialize(DIContainer());
      addTearDown(() {
        if (getIt.isRegistered<ImportRateLimiter>()) {
          getIt.unregister<ImportRateLimiter>();
        }
        app_provider.ServiceLocator.reset();
      });

      final okManager = ImportManager.withStrategies(
        MockPersonalRecipeOperations(),
        [
          VoiceImportStrategy(
            textStrategy: _StubTextStrategy(ImportResult.success(parsedRecipe)),
          ),
        ],
        eventLogger: _SpyParseEventLogger(),
      );
      final okResult = await okManager.importVoiceTranscript(
        _assembledTranscript,
      );
      expect(okResult.isSuccess, isTrue);
      expect(limiter.recorded, hasLength(1));
      expect(
        limiter.recorded.single.sourceType,
        'voice',
        reason: 'usage must count in the voice bucket, not blend into text',
      );
      expect(limiter.recorded.single.requiresLlm, isFalse);

      final failManager = ImportManager.withStrategies(
        MockPersonalRecipeOperations(),
        [
          VoiceImportStrategy(
            textStrategy: _StubTextStrategy(ImportResult.failure('nej')),
          ),
        ],
        eventLogger: _SpyParseEventLogger(),
      );
      final failResult = await failManager.importVoiceTranscript('brus');
      expect(failResult.isSuccess, isFalse);
      expect(
        limiter.recorded,
        hasLength(1),
        reason: 'a failed parse must not consume quota',
      );
    });

    test('without a registered voice strategy the failure is structured, '
        'not thrown', () async {
      final manager = ImportManager.withStrategies(
        MockPersonalRecipeOperations(),
        const [],
        eventLogger: _SpyParseEventLogger(),
      );

      final result = await manager.importVoiceTranscript('x');

      expect(result.isSuccess, isFalse);
    });
  });
}
