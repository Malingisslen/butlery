/// BUT-2238: a photo import writes ONE parse event and uses the import quota
/// once, however many times the screen re-parses the same pages.
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart'
    as app_provider;
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/services/import/heirloom_bridge.dart';
import 'package:butlery/services/import/import_event.dart';
import 'package:butlery/services/import/import_manager.dart';
import 'package:butlery/services/import/import_rate_limiter.dart';
import 'package:butlery/services/import/import_strategy.dart';
import 'package:butlery/services/import/models/rate_limit_models.dart';
import 'package:butlery/services/import/photo_import_strategy.dart';
import 'package:butlery/services/parsing/parse_event_logger.dart';
import 'package:butlery/viewmodels/photo_import_viewmodel.dart';
import 'package:butlery/viewmodels/photo_import/draft_image_store_io.dart'
    as image_store;

import '../../test_support/base_unit_test.dart';
import '../../infrastructure/di/test_service_locator.dart';
import '../../infrastructure/factories/recipe_factory.dart';
import '../../infrastructure/mocks/production_mocks.dart';

class _SpyParseEventLogger extends ParseEventLogger {
  final List<ImportEvent> events = [];

  @override
  void log(ImportEvent event) => events.add(event);
}

class _RecordingRateLimiter extends Fake implements ImportRateLimiter {
  final List<ImportOperation> recorded = [];
  bool deny = false;

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

/// A handwriting read that could only hand back text for the user to check.
class _AssistingPhotoStrategy extends PhotoImportStrategy {
  @override
  Future<ImportResult> import(
    String input, {
    Map<String, dynamic>? options,
  }) async => ImportResult.assistance(extractedText: 'Pannkakor\n\n3 ägg');
}

class _TextStrategy extends ImportStrategy {
  _TextStrategy(this.recipe);
  final Recipe recipe;

  @override
  String get strategyName => 'Text Import';
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
  }) async => ImportResult.success(recipe);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final imageBytes = Uint8List.fromList(List<int>.filled(32, 9));
  late _SpyParseEventLogger spy;
  late _RecordingRateLimiter limiter;
  late ImportManager manager;
  late PhotoImportViewModel viewModel;
  late Directory draftDir;

  setUpAll(() async {
    await BaseUnitTest.setupUnit();
    SharedPreferences.setMockInitialValues({});
  });

  tearDownAll(() async {
    await BaseUnitTest.teardownUnit();
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues(const <String, Object>{});
    draftDir = Directory.systemTemp.createTempSync('butlery_one_event_test');
    image_store.debugDraftImageDirOverride = draftDir;
    await TestServiceLocator.initialize();
    final getIt = GetIt.instance;
    if (getIt.isRegistered<HeirloomBridge>()) {
      getIt.unregister<HeirloomBridge>();
    }
    getIt.registerSingleton<HeirloomBridge>(HeirloomBridge());
    limiter = _RecordingRateLimiter();
    if (getIt.isRegistered<ImportRateLimiter>()) {
      getIt.unregister<ImportRateLimiter>();
    }
    getIt.registerSingleton<ImportRateLimiter>(limiter);
    app_provider.ServiceLocator.reset();
    app_provider.ServiceLocator.initialize(DIContainer());

    spy = _SpyParseEventLogger();
    manager = ImportManager.withStrategies(
      MockPersonalRecipeOperations(),
      [
        _AssistingPhotoStrategy(),
        _TextStrategy(RecipeFactory.build(id: 'r1', title: 'Pannkakor')),
      ],
      eventLogger: spy,
    );
    viewModel = PhotoImportViewModel(importManager: manager);
  });

  tearDown(() async {
    viewModel.dispose();
    image_store.debugDraftImageDirOverride = null;
    if (draftDir.existsSync()) draftDir.deleteSync(recursive: true);
    final getIt = GetIt.instance;
    if (getIt.isRegistered<ImportRateLimiter>()) {
      getIt.unregister<ImportRateLimiter>();
    }
    app_provider.ServiceLocator.reset();
    BaseUnitTest.resetMocks();
    await TestServiceLocator.reset();
  });

  test('a handwritten photo that needs a check is one import, though its '
      'text is parsed a second time', () async {
    viewModel.setHandwritten(true);

    await viewModel.extractHandwrittenForTesting(imageBytes);

    expect(
      viewModel.parsedRecipe,
      isNotNull,
      reason: 'the premise: the text behind the photo was parsed too',
    );
    expect(spy.events, hasLength(1));
    expect(spy.events.single.channel, ImportChannel.photo);
    expect(spy.events.single.outcome, 'assistance');
    expect(limiter.recorded, hasLength(1));
  });

  test('adding and reordering pages re-parses the same import', () async {
    await viewModel.addPageForTesting(imageBytes, 'Pannkakor\n\n3 ägg');
    await viewModel.addPageForTesting(imageBytes, '6 dl mjölk');
    await viewModel.reorderPage(1, 0);

    expect(spy.events, hasLength(1));
    expect(limiter.recorded, hasLength(1));
  });

  test('a new photo after clearing is a new import', () async {
    await viewModel.addPageForTesting(imageBytes, 'Pannkakor\n\n3 ägg');
    viewModel.clearPhoto();
    await viewModel.addPageForTesting(imageBytes, 'Våfflor\n\n2 ägg');

    expect(spy.events, hasLength(2));
  });

  test(
    'a refused handwritten read leaves the next read to be measured',
    () async {
      viewModel.setHandwritten(true);
      limiter.deny = true;
      await viewModel.extractHandwrittenForTesting(imageBytes);
      expect(spy.events, isEmpty, reason: 'a refusal is not measured');

      viewModel.setHandwritten(false);
      limiter.deny = false;
      await viewModel.addPageForTesting(imageBytes, 'Pannkakor\n\n3 ägg');

      expect(spy.events, hasLength(1));
      expect(limiter.recorded, hasLength(1));
    },
  );

  test('a restored draft was measured when it was first read', () async {
    await viewModel.persistPhotoDraft(
      imageBytes: imageBytes,
      ocrText: 'Pannkakor\n\n3 ägg',
    );
    final restored = PhotoImportViewModel(importManager: manager);
    addTearDown(restored.dispose);

    expect(await restored.restoreDraft(), isTrue);

    expect(
      restored.parsedRecipe,
      isNotNull,
      reason: 'the premise: the draft was parsed again',
    );
    expect(spy.events, isEmpty);
    expect(limiter.recorded, isEmpty);
  });
}
