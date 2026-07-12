import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:butlery/services/import/import_manager.dart';
import 'package:butlery/services/import/import_strategy.dart';
import 'package:butlery/services/import/url_import_strategy.dart';
import 'package:butlery/services/parsing/parse_event_logger.dart';
import 'package:butlery/models/recipe_unified.dart';

import '../../../test_support/base_unit_test.dart';
import '../../../infrastructure/factories/recipe_factory.dart';
import '../../../infrastructure/mocks/production_mocks.dart';
import '../../../infrastructure/di/test_service_locator.dart';

/// Captures every [ParseEventLogger.logEvent] call in-memory instead of firing
/// a Cloud Function, so the manager's parse-event logging can be asserted
/// without a live Firebase app.
class _SpyParseEventLogger extends ParseEventLogger {
  final List<({String source, bool success, String? url, int parseTimeMs})>
  events = [];

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
    events.add(
      (url: url, source: source, success: success, parseTimeMs: parseTimeMs),
    );
  }
}

/// A [UrlImportStrategy] whose `import` returns a canned success WITHOUT any
/// network I/O — used to prove the manager does NOT double-log the URL path
/// (the real UrlImportStrategy already logs its own per-tier parse events).
/// Being a real subclass, `strategy is UrlImportStrategy` holds, which is the
/// exclusion the manager relies on.
class _FakeUrlStrategy extends UrlImportStrategy {
  _FakeUrlStrategy(this._recipe) : super();
  final Recipe _recipe;

  @override
  Future<ImportResult> import(
    String input, {
    Map<String, dynamic>? options,
  }) async =>
      ImportResult.success(_recipe, metadata: {'strategy': strategyName});
}

void main() {
  // A real UrlImportStrategy (built in the exclusion test) constructs
  // supporting services on init, so the binding must exist.
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ImportManager parse-event logging (BUT-1470)', () {
    late MockPersonalRecipeOperations mockPersonalOps;
    late MockImportStrategy mockStrategy;
    late _SpyParseEventLogger spyLogger;
    late Recipe testRecipe;

    setUpAll(() async {
      await BaseUnitTest.setupUnit();
      SharedPreferences.setMockInitialValues({});
      registerFallbackValue(RecipeFactory.build());
    });

    setUp(() {
      mockPersonalOps = MockPersonalRecipeOperations();
      mockStrategy = MockImportStrategy();
      spyLogger = _SpyParseEventLogger();
      testRecipe = RecipeFactory.build(id: 'r1', title: 'Test');
    });

    tearDown(() async {
      BaseUnitTest.resetMocks();
      await TestServiceLocator.reset();
    });

    tearDownAll(() async {
      await BaseUnitTest.teardownUnit();
    });

    ImportManager managerWith(MockImportStrategy strategy) =>
        ImportManager.withStrategies(
          mockPersonalOps,
          [strategy],
          eventLogger: spyLogger,
        );

    test('a successful text import logs one parse event (source=text, '
        'success=true)', () async {
      mockStrategy.setStrategyState(strategyName: 'Text Import');
      when(
        () => mockStrategy.import(any(), options: any(named: 'options')),
      ).thenAnswer((_) async => ImportResult.success(testRecipe));

      await managerWith(mockStrategy).importWithStrategy('Text Import', 'text');

      expect(spyLogger.events, hasLength(1));
      expect(spyLogger.events.single.source, 'text');
      expect(spyLogger.events.single.success, isTrue);
      // These paths carry no fetchable URL — it must be logged as null.
      expect(spyLogger.events.single.url, isNull);
    });

    test('a photo/OCR import logs a parse event with source=ocr', () async {
      mockStrategy.setStrategyState(strategyName: 'Photo Import');
      when(
        () => mockStrategy.import(any(), options: any(named: 'options')),
      ).thenAnswer((_) async => ImportResult.success(testRecipe));

      await managerWith(mockStrategy).importWithStrategy('Photo Import', 'img');

      expect(spyLogger.events, hasLength(1));
      expect(spyLogger.events.single.source, 'ocr');
      expect(spyLogger.events.single.success, isTrue);
    });

    test(
      'a social (youtube) import logs a parse event with source=youtube',
      () async {
        mockStrategy.setStrategyState(strategyName: 'youtube');
        when(
          () => mockStrategy.import(any(), options: any(named: 'options')),
        ).thenAnswer((_) async => ImportResult.success(testRecipe));

        await managerWith(mockStrategy).importWithStrategy('youtube', 'url');

        expect(spyLogger.events, hasLength(1));
        expect(spyLogger.events.single.source, 'youtube');
      },
    );

    test('a failed parse logs an event with success=false', () async {
      mockStrategy.setStrategyState(strategyName: 'Text Import');
      when(
        () => mockStrategy.import(any(), options: any(named: 'options')),
      ).thenAnswer((_) async => ImportResult.failure('Parse failed'));

      await managerWith(mockStrategy).importWithStrategy('Text Import', 'text');

      expect(spyLogger.events, hasLength(1));
      expect(spyLogger.events.single.success, isFalse);
    });

    test(
      'a needsAssistance outcome logs success=false (no structured recipe)',
      () async {
        mockStrategy.setStrategyState(strategyName: 'Text Import');
        when(
          () => mockStrategy.import(any(), options: any(named: 'options')),
        ).thenAnswer(
          (_) async => ImportResult.assistance(extractedText: 'partial'),
        );

        await managerWith(
          mockStrategy,
        ).importWithStrategy('Text Import', 'text');

        expect(spyLogger.events, hasLength(1));
        expect(spyLogger.events.single.success, isFalse);
      },
    );

    test('URL imports are NOT double-logged by the manager (they self-log '
        'per-tier)', () async {
      final urlStrategy = _FakeUrlStrategy(testRecipe);
      final manager = ImportManager.withStrategies(
        mockPersonalOps,
        [urlStrategy],
        eventLogger: spyLogger,
      );

      final result = await manager.importWithStrategy(
        'URL Import',
        'https://example.com/recipe',
      );

      expect(result.isSuccess, isTrue);
      expect(
        spyLogger.events,
        isEmpty,
        reason:
            'UrlImportStrategy already logs its own parse events; the '
            'manager must skip it to avoid double-counting',
      );
    });
  });
}
