/// BUT-2240: file import goes through [ImportManager] like every other
/// channel: one parse event, one use of the quota, the same analytics, and a
/// cancelled picker is not an import.
library;

import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart'
    as app_provider;
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/services/analytics_service.dart';
import 'package:butlery/services/import/file_import_strategy.dart';
import 'package:butlery/services/import/import_event.dart';
import 'package:butlery/services/import/import_manager.dart';
import 'package:butlery/services/import/import_rate_limiter.dart';
import 'package:butlery/services/import/models/rate_limit_models.dart';
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

class _RecordingAnalytics extends Fake implements AnalyticsService {
  final List<String> logged = [];

  @override
  Future<void> logImportStarted({
    required String source,
    String? platform,
    String? sessionId,
    String imageFormat = 'unknown',
  }) async => logged.add('started:$source');

  @override
  Future<void> logImportSuccess({
    required String source,
    String? platform,
    int? recipeLength,
    String? sessionId,
    String imageFormat = 'unknown',
    String imageFormatSent = 'unknown',
  }) async => logged.add('success:$source');
}

/// A file strategy answering from canned picks, without a platform picker.
class _CannedFileStrategy extends FileImportStrategy {
  _CannedFileStrategy({this.picked, this.recipes = const []});
  final PlatformFile? picked;
  final List<Recipe> recipes;
  int parses = 0;

  @override
  Future<PlatformFile?> pickFile() async => picked;

  @override
  Future<List<Recipe>> importPicked(
    PlatformFile file, {
    Map<String, dynamic>? options,
  }) async {
    parses++;
    return recipes;
  }
}

final _csv = PlatformFile(
  name: 'recept.csv',
  size: 3,
  bytes: Uint8List.fromList([1, 2, 3]),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockPersonalRecipeOperations ops;
  late _SpyParseEventLogger spy;

  setUpAll(() async {
    await BaseUnitTest.setupUnit();
    SharedPreferences.setMockInitialValues({});
  });

  setUp(() {
    ops = MockPersonalRecipeOperations();
    spy = _SpyParseEventLogger();
  });

  tearDown(() async {
    BaseUnitTest.resetMocks();
    await TestServiceLocator.reset();
  });

  tearDownAll(() async {
    await BaseUnitTest.teardownUnit();
  });

  ImportManager managerWith(_CannedFileStrategy strategy) =>
      ImportManager.withStrategies(ops, [strategy], eventLogger: spy);

  ({_RecordingRateLimiter limiter, _RecordingAnalytics analytics}) install({
    bool deny = false,
  }) {
    final limiter = _RecordingRateLimiter(deny: deny);
    final analytics = _RecordingAnalytics();
    final getIt = GetIt.instance;
    void clear() {
      if (getIt.isRegistered<ImportRateLimiter>()) {
        getIt.unregister<ImportRateLimiter>();
      }
      if (getIt.isRegistered<AnalyticsService>()) {
        getIt.unregister<AnalyticsService>();
      }
    }

    clear();
    getIt.registerSingleton<ImportRateLimiter>(limiter);
    getIt.registerSingleton<AnalyticsService>(analytics);
    app_provider.ServiceLocator.reset();
    app_provider.ServiceLocator.initialize(DIContainer());
    addTearDown(() {
      clear();
      app_provider.ServiceLocator.reset();
    });
    return (limiter: limiter, analytics: analytics);
  }

  test('a file with recipes is one measured, counted import', () async {
    final seams = install();
    final strategy = _CannedFileStrategy(
      picked: _csv,
      recipes: [
        RecipeFactory.build(id: '1'),
        RecipeFactory.build(id: '2'),
      ],
    );

    final result = await managerWith(strategy).importFile();
    await pumpEventQueue();

    expect(result.recipes, hasLength(2));
    expect(spy.events, hasLength(1));
    final event = spy.events.single;
    expect(event.channel, ImportChannel.file);
    expect(event.strategy, 'file');
    expect(event.outcome, 'recipe');
    expect(event.errorCode, isNull);
    expect(seams.limiter.recorded.map((o) => o.sourceType), ['file']);
    expect(seams.analytics.logged, ['started:file', 'success:file']);
  });

  test(
    'a file with no recipes is measured as a failure with its cause',
    () async {
      final seams = install();

      final result = await managerWith(
        _CannedFileStrategy(picked: _csv),
      ).importFile();
      await pumpEventQueue();

      expect(result.recipes, isEmpty);
      expect(result.cancelled, isFalse);
      final event = spy.events.single;
      expect(event.outcome, 'failure');
      expect(event.errorCode, 'parsingFailed');
      expect(seams.analytics.logged, ['started:file']);
    },
  );

  test('a cancelled picker is not an import', () async {
    final seams = install();
    final strategy = _CannedFileStrategy();

    final result = await managerWith(strategy).importFile();
    await pumpEventQueue();

    expect(result.cancelled, isTrue);
    expect(strategy.parses, 0);
    expect(spy.events, isEmpty);
    expect(seams.limiter.recorded, isEmpty);
    expect(seams.analytics.logged, isEmpty);
  });

  test(
    'a refused file import is neither parsed, measured nor counted',
    () async {
      final seams = install(deny: true);
      final strategy = _CannedFileStrategy(
        picked: _csv,
        recipes: [RecipeFactory.build(id: '1')],
      );

      final result = await managerWith(strategy).importFile();
      await pumpEventQueue();

      expect(result.rateLimitDenied, isNotNull);
      expect(strategy.parses, 0);
      expect(spy.events, isEmpty);
      expect(seams.limiter.recorded, isEmpty);
    },
  );

  test('the file strategy has its own id', () {
    expect(ImportEvent.strategyId(FileImportStrategy().strategyName), 'file');
  });
}
