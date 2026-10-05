/// BUT-2238: an import writes exactly ONE parse event, from [ImportManager],
/// whatever route it took and however many strategies it tried, and every
/// attempt counts against the import quota.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart'
    as app_provider;
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/services/import/import_event.dart';
import 'package:butlery/services/import/import_manager.dart';
import 'package:butlery/services/import/import_rate_limiter.dart';
import 'package:butlery/services/import/import_strategy.dart';
import 'package:butlery/services/import/models/import_result_v2.dart';
import 'package:butlery/services/import/models/rate_limit_models.dart';
import 'package:butlery/services/import/url_import_strategy.dart';
import 'package:butlery/services/parsing/parse_event_logger.dart';

import '../../../test_support/base_unit_test.dart';
import '../../../infrastructure/factories/recipe_factory.dart';
import '../../../infrastructure/mocks/production_mocks.dart';
import '../../../infrastructure/di/test_service_locator.dart';

class _SpyParseEventLogger extends ParseEventLogger {
  final List<ImportEvent> events = [];

  @override
  void log(ImportEvent event) => events.add(event);
}

class _RecordingRateLimiter extends Fake implements ImportRateLimiter {
  _RecordingRateLimiter({this.deny = false});
  final bool deny;
  final List<ImportOperation> recorded = [];

  @override
  Future<RateLimitResult> checkLimit(ImportOperation operation) async => deny
      ? const RateLimitDenied(
          message: 'nej',
          retryAfter: Duration(minutes: 1),
          limitType: LimitType.perMinute,
          suggestedAction: FallbackAction.retryLater,
        )
      : const RateLimitAllowed(
          remainingInWindow: 5,
          limitType: LimitType.perMinute,
        );

  @override
  Future<void> recordUsage(ImportOperation operation, {double? llmCost}) async {
    recorded.add(operation);
  }
}

/// A URL strategy answering from a canned result, without network I/O.
class _CannedUrlStrategy extends UrlImportStrategy {
  _CannedUrlStrategy(this._result) : super();
  final ImportResult _result;

  @override
  Future<ImportResult> import(
    String input, {
    Map<String, dynamic>? options,
  }) async => _result;
}

class _FailingStrategy extends ImportStrategy {
  _FailingStrategy(this.strategyName, this.code);

  @override
  final String strategyName;
  final ImportErrorCode? code;
  int calls = 0;

  @override
  bool canHandle(String input) => true;
  @override
  bool validateInput(String input) => true;
  @override
  String get inputExample => '';
  @override
  String get description => '';

  @override
  Future<ImportResult> import(
    String input, {
    Map<String, dynamic>? options,
  }) async {
    calls++;
    return ImportResult.failure('$strategyName failed', errorCode: code);
  }
}

class _SucceedingStrategy extends _FailingStrategy {
  _SucceedingStrategy(this.recipe) : super('Text Import', null);
  final Recipe recipe;

  @override
  Future<ImportResult> import(
    String input, {
    Map<String, dynamic>? options,
  }) async => ImportResult.success(recipe);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockPersonalRecipeOperations ops;
  late MockImportStrategy mockStrategy;
  late _SpyParseEventLogger spy;
  late Recipe recipe;

  setUpAll(() async {
    await BaseUnitTest.setupUnit();
    SharedPreferences.setMockInitialValues({});
    registerFallbackValue(RecipeFactory.build());
  });

  setUp(() {
    ops = MockPersonalRecipeOperations();
    mockStrategy = MockImportStrategy();
    spy = _SpyParseEventLogger();
    recipe = RecipeFactory.build(id: 'r1', title: 'Test');
  });

  tearDown(() async {
    BaseUnitTest.resetMocks();
    await TestServiceLocator.reset();
  });

  tearDownAll(() async {
    await BaseUnitTest.teardownUnit();
  });

  ImportManager managerWith(List<ImportStrategy> strategies) =>
      ImportManager.withStrategies(ops, strategies, eventLogger: spy);

  _RecordingRateLimiter installLimiter({bool deny = false}) {
    final limiter = _RecordingRateLimiter(deny: deny);
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
    return limiter;
  }

  group('one event per import', () {
    test('a pasted text that two strategies fail on writes ONE event with '
        'the cause that was kept', () async {
      final first = _FailingStrategy('Text Import', null);
      final second = _FailingStrategy(
        'Archive Import',
        ImportErrorCode.noRecipeContent,
      );

      await managerWith([first, second]).autoImport('någonting');

      expect(first.calls + second.calls, 2, reason: 'both were tried');
      expect(spy.events, hasLength(1));
      final e = spy.events.single;
      expect(e.channel, ImportChannel.text);
      expect(e.outcome, 'failure');
      expect(e.errorCode, 'noRecipeContent');
      expect(e.url, isNull);
    });

    test(
      'a link import carries tier, AI use, cost and parser detail',
      () async {
        final url = _CannedUrlStrategy(
          ImportResult.success(
            recipe,
            metadata: {
              'successfulTier': 'LLM',
              'usedLlm': true,
              'llmCost': 0.0012,
              'overallQuality': 0.8,
              'unknownDomain': true,
              'tierAttempts': [
                {'tier': 'SchemaOrg', 'success': false},
              ],
            },
          ),
        );

        await managerWith([url]).autoImport('https://www.ica.se/recept/x/');

        expect(spy.events, hasLength(1));
        final e = spy.events.single;
        expect(e.channel, ImportChannel.link);
        expect(e.strategy, 'url');
        expect(e.outcome, 'recipe');
        expect(e.url, 'https://www.ica.se/recept/x/');
        expect(e.successfulTier, 'LLM');
        expect(e.usedLlm, isTrue);
        expect(e.estimatedCostUsd, 0.0012);
        expect(e.finalQuality, 0.8);
        expect(e.unknownDomain, isTrue);
        expect(e.tierAttempts, hasLength(1));
        expect(e.errorCode, isNull);
      },
    );

    test('an assisted outcome is neither a recipe nor a failure', () async {
      mockStrategy.setStrategyState(strategyName: 'Text Import');
      when(
        () => mockStrategy.import(any(), options: any(named: 'options')),
      ).thenAnswer(
        (_) async => ImportResult.assistance(extractedText: 'partial'),
      );

      await managerWith([mockStrategy]).importWithStrategy('Text Import', 'x');

      expect(spy.events.single.outcome, 'assistance');
      expect(spy.events.single.success, isFalse);
      expect(spy.events.single.errorCode, isNull);
    });

    test('a strategy that throws still writes one failure event', () async {
      mockStrategy.setStrategyState(strategyName: 'Text Import');
      when(
        () => mockStrategy.import(any(), options: any(named: 'options')),
      ).thenThrow(Exception('parser exploded'));

      final r = await managerWith([
        mockStrategy,
      ]).importWithStrategy('Text Import', 'text');

      expect(r.errorMessage, contains('Parse execution error'));
      expect(spy.events, hasLength(1));
      expect(spy.events.single.outcome, 'failure');
    });

    test('a photo page is one event under the photo channel', () async {
      await managerWith([_SucceedingStrategy(recipe)]).autoParseMulti(
        'Pannkakor\n\n3 ägg\n6 dl mjölk',
        channel: ImportChannel.photo,
      );

      expect(spy.events, hasLength(1));
      expect(spy.events.single.channel, ImportChannel.photo);
      expect(spy.events.single.outcome, 'recipe');
    });

    test('text no strategy can parse is not counted as a photo attempt, '
        "with the app's own strategy list", () async {
      final manager = ImportManager(ops, eventLogger: spy);

      await manager.autoImport('kladdkaka');

      expect(spy.events, hasLength(1));
      expect(spy.events.single.channel, ImportChannel.text);
      expect(spy.events.single.strategy, isNot('photo'));
    });
  });

  group('the import quota', () {
    test('a failed import is counted once, under its channel', () async {
      final limiter = installLimiter();

      await managerWith([
        _FailingStrategy('Text Import', ImportErrorCode.noRecipeContent),
      ]).autoImport('någonting');

      expect(limiter.recorded, hasLength(1));
      expect(limiter.recorded.single.sourceType, 'text');
    });

    test('a successful link import is counted once, not twice', () async {
      final limiter = installLimiter();

      await managerWith([
        _CannedUrlStrategy(ImportResult.success(recipe)),
      ]).autoImport('https://www.ica.se/recept/x/');

      expect(limiter.recorded, hasLength(1));
      expect(limiter.recorded.single.sourceType, 'link');
    });

    test('a refused import is neither measured nor counted', () async {
      final limiter = installLimiter(deny: true);

      final r = await managerWith([
        _FailingStrategy('Text Import', null),
      ]).autoImport('någonting');

      expect(r.rateLimitDenied, isNotNull);
      expect(spy.events, isEmpty);
      expect(limiter.recorded, isEmpty);
    });
  });

  group('ImportEvent.toPayload', () {
    test('sends the fields the Cloud Function reads, and drops nulls', () {
      const event = ImportEvent(
        channel: ImportChannel.text,
        strategy: 'text',
        outcome: 'failure',
        parseTimeMs: 12,
        errorCode: 'noRecipeContent',
      );
      expect(event.toPayload(), {
        'channel': 'text',
        'strategy': 'text',
        'outcome': 'failure',
        'success': false,
        'fromCache': false,
        'parseTimeMs': 12,
        'usedLlm': false,
        'errorCode': 'noRecipeContent',
      });
    });

    test('strategy ids: voice is told apart from text', () {
      expect(ImportEvent.strategyId('Voice Import'), 'voice');
      expect(ImportEvent.strategyId('Text Import'), 'text');
      expect(ImportEvent.strategyId('URL Import'), 'url');
      expect(ImportEvent.strategyId('Photo Import (LLM Vision)'), 'photo');
      expect(ImportEvent.strategyId('cache'), 'cache');
      expect(ImportEvent.strategyId(null), 'unknown');
    });
  });
}
