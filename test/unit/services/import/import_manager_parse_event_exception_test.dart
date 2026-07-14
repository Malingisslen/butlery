import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:butlery/services/import/import_manager.dart';
import 'package:butlery/services/import/import_strategy.dart';
import 'package:butlery/services/import/url_import_strategy.dart';
import 'package:butlery/services/parsing/parse_event_logger.dart';

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

/// A [UrlImportStrategy] whose `import` THROWS — used to prove the manager
/// still honours the URL self-logging skip on the exception path (it must not
/// double-log a URL parse that already logs its own per-tier events).
class _ThrowingUrlStrategy extends UrlImportStrategy {
  _ThrowingUrlStrategy() : super();

  @override
  Future<ImportResult> import(
    String input, {
    Map<String, dynamic>? options,
  }) async => throw Exception('url strategy blew up');
}

void main() {
  // A real UrlImportStrategy constructs supporting services on init, so the
  // binding must exist.
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ImportManager parse-event logging on the exception path (BUT-1597)', () {
    late MockPersonalRecipeOperations mockPersonalOps;
    late MockImportStrategy mockStrategy;
    late _SpyParseEventLogger spyLogger;

    setUpAll(() async {
      await BaseUnitTest.setupUnit();
      SharedPreferences.setMockInitialValues({});
      registerFallbackValue(RecipeFactory.build());
    });

    setUp(() {
      mockPersonalOps = MockPersonalRecipeOperations();
      mockStrategy = MockImportStrategy();
      spyLogger = _SpyParseEventLogger();
    });

    tearDown(() async {
      BaseUnitTest.resetMocks();
      await TestServiceLocator.reset();
    });

    tearDownAll(() async {
      await BaseUnitTest.teardownUnit();
    });

    test(
      'a strategy that THROWS during import logs one parse event '
      '(success=false) instead of silently swallowing the failure',
      () async {
        mockStrategy.setStrategyState(strategyName: 'Text Import');
        when(
          () => mockStrategy.import(any(), options: any(named: 'options')),
        ).thenThrow(Exception('parser exploded'));

        final manager = ImportManager.withStrategies(
          mockPersonalOps,
          [mockStrategy],
          eventLogger: spyLogger,
        );

        final result = await manager.importWithStrategy('Text Import', 'text');

        // The failure still surfaces to the caller...
        expect(result.isSuccess, isFalse);
        // ...AND it is now measured as a parse event.
        expect(spyLogger.events, hasLength(1));
        expect(spyLogger.events.single.source, 'text');
        expect(spyLogger.events.single.success, isFalse);
        expect(spyLogger.events.single.url, isNull);
      },
    );

    test(
      'a URL strategy that throws is NOT logged by the manager on the '
      'exception path (it self-logs per-tier)',
      () async {
        final manager = ImportManager.withStrategies(
          mockPersonalOps,
          [_ThrowingUrlStrategy()],
          eventLogger: spyLogger,
        );

        final result = await manager.importWithStrategy(
          'URL Import',
          'https://example.com/recipe',
        );

        expect(result.isSuccess, isFalse);
        // Prove the EXCEPTION path was actually taken — a "strategy not found"
        // miss would also yield isSuccess=false + empty events, so without this
        // the test could pass for the wrong reason (e.g. a strategyName drift
        // that stops the manager from ever invoking import()).
        expect(result.errorMessage, contains('Parse execution error'));
        expect(
          spyLogger.events,
          isEmpty,
          reason:
              'UrlImportStrategy owns its own parse-event logging; the manager '
              'must skip it on the exception path too, to avoid double-counting',
        );
      },
    );
  });
}
