// test/unit/viewmodels/photo_import_handwritten_pipeline_test.dart
//
// BUT-1460: end-to-end proof that the handwritten photo-import path routes
// through the REAL ImportManager.importSinglePhoto (NOT a mock) so a terminal
// rate-limit denial or LLM-vision failure surfaces the strategy's own message,
// instead of being swallowed by autoImport's multi-strategy fallback loop into
// the generic English "No import strategy could handle" text.
//
// These deliberately do NOT mock ImportManager/importSinglePhoto — the prior
// patch's rate-limit test was vacuous because it stubbed autoImport. Here the
// VM drives a real ImportManager wired to a real ImportRateLimiter (driven to a
// denied state via a seeded FakeFirebaseFirestore) and a real PhotoImportStrategy
// (whose LLM-vision service is a fake we can fail on demand).
library;

import 'dart:typed_data';

import 'package:clock/clock.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:butlery/core/l10n/app_locale.dart';
import 'package:butlery/core/providers/application_provider.dart'
    as app_provider;
import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/repositories/firestore_repository.dart';
import 'package:butlery/services/import/heirloom_bridge.dart';
import 'package:butlery/services/import/import_manager.dart';
import 'package:butlery/services/import/import_rate_limiter.dart';
import 'package:butlery/services/import/models/rate_limit_models.dart';
import 'package:butlery/services/import/photo_import_strategy.dart';
import 'package:butlery/services/import/llm/llm_enhancement_service.dart';
import 'package:butlery/services/import/models/import_result_v2.dart';
import 'package:butlery/viewmodels/photo_import_viewmodel.dart';

import '../../test_support/base_unit_test.dart';
import '../../infrastructure/di/test_service_locator.dart';
import '../../infrastructure/mocks/production_mocks.dart';

/// Handwritten LLM-vision service that always fails with a distinctive message
/// and records how many times it was called (to prove exactly one vision call).
class _FakeLlmFailure extends Fake implements LlmEnhancementService {
  _FakeLlmFailure(this.message);
  final String message;
  int calls = 0;

  @override
  Future<ImportResultV2> extractFromImage(
    Uint8List imageBytes, {
    String? context,
    bool isHandwritten = false,
  }) async {
    calls++;
    return ImportFailure(
      message: message,
      errorCode: ImportErrorCode.ocrFailed,
      pipeline: 'photo',
      tier: 4,
    );
  }
}

Future<void> _seedUsage(
  FakeFirebaseFirestore firestore,
  String uid,
  UsageLimits usage,
) async {
  await firestore
      .collection('users')
      .doc(uid)
      .collection('rate_limits')
      .doc('imports')
      .set(usage.toFirestore());
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Non-null image bytes; content is irrelevant — the handwritten path routes
  // straight to the (faked) vision service, and rate-limit denial precedes any
  // strategy work.
  final imageBytes = Uint8List.fromList(List<int>.filled(32, 9));
  final t0 = DateTime(2026, 7, 2, 12, 0, 0);

  setUpAll(() async {
    await BaseUnitTest.setupUnit();
    SharedPreferences.setMockInitialValues({});
  });

  tearDownAll(() async {
    await BaseUnitTest.teardownUnit();
  });

  late PhotoImportViewModel viewModel;

  setUp(() async {
    await TestServiceLocator.initialize();

    final getIt = GetIt.instance;
    if (getIt.isRegistered<HeirloomBridge>()) {
      getIt.unregister<HeirloomBridge>();
    }
    getIt.registerSingleton<HeirloomBridge>(HeirloomBridge());

    app_provider.ServiceLocator.reset();
    app_provider.ServiceLocator.initialize(DIContainer());
  });

  tearDown(() async {
    viewModel.dispose();
    final getIt = GetIt.instance;
    if (getIt.isRegistered<ImportRateLimiter>()) {
      getIt.unregister<ImportRateLimiter>();
    }
    if (getIt.isRegistered<LlmEnhancementService>()) {
      getIt.unregister<LlmEnhancementService>();
    }
    app_provider.ServiceLocator.reset();
    BaseUnitTest.resetMocks();
    await TestServiceLocator.reset();
  });

  test(
    'BUT-1460: a real rate-limit denial surfaces the structured Swedish retry '
    'message (not the generic English fallback)',
    () async {
      // Real limiter, driven to a per-minute denial via a seeded usage doc.
      final firestore = FakeFirebaseFirestore();
      final auth = FakeAuthRepository()..setAuthState(userId: 'u-hw-1');
      await _seedUsage(
        firestore,
        'u-hw-1',
        UsageLimits(
          importsThisMinute: ImportRateLimits.importsPerMinute,
          minuteWindowStart: t0,
        ),
      );
      final limiter = ImportRateLimiter(
        firestoreRepository: FirestoreRepository(firestore: firestore),
        authRepository: auth,
      );
      final getIt = GetIt.instance;
      if (getIt.isRegistered<ImportRateLimiter>()) {
        getIt.unregister<ImportRateLimiter>();
      }
      getIt.registerSingleton<ImportRateLimiter>(limiter);

      // Real ImportManager + real PhotoImportStrategy — no mocking of the
      // routing under test.
      final manager = ImportManager.withStrategies(
        MockPersonalRecipeOperations(),
        [PhotoImportStrategy()],
      );
      viewModel = PhotoImportViewModel(importManager: manager);
      viewModel.setHandwritten(true);

      // Fix the clock so retryAfter is deterministic: now == minuteWindowStart
      // → the minute window has its full 60s left.
      await withClock(
        Clock.fixed(t0),
        () => viewModel.extractHandwrittenForTesting(imageBytes),
      );

      const expectedDenial = RateLimitDenied(
        message: '',
        retryAfter: Duration(seconds: 60),
        limitType: LimitType.perMinute,
        suggestedAction: FallbackAction.retryLater,
      );
      expect(viewModel.hasError, isTrue);
      expect(
        viewModel.error,
        expectedDenial.swedishMessage,
        reason: 'must be the limiter retry text, not a generic error',
      );
      expect(viewModel.error, isNot(AppLocale.current.errorGeneric));
      expect(viewModel.error, isNot(contains('No import strategy')));
    },
  );

  test(
    'BUT-1460: a handwritten LLM-vision failure surfaces the strategy own '
    'message via importSinglePhoto, with exactly ONE vision call',
    () async {
      final fakeLlm = _FakeLlmFailure('kunde inte tolka handstilen');
      final getIt = GetIt.instance;
      if (getIt.isRegistered<LlmEnhancementService>()) {
        getIt.unregister<LlmEnhancementService>();
      }
      getIt.registerSingleton<LlmEnhancementService>(fakeLlm);
      // No ImportRateLimiter registered → _rateLimiter resolves null → the
      // rate-limit check is skipped and we reach the strategy.
      if (getIt.isRegistered<ImportRateLimiter>()) {
        getIt.unregister<ImportRateLimiter>();
      }

      final manager = ImportManager.withStrategies(
        MockPersonalRecipeOperations(),
        [PhotoImportStrategy()],
      );
      viewModel = PhotoImportViewModel(importManager: manager);
      viewModel.setHandwritten(true);

      await viewModel.extractHandwrittenForTesting(imageBytes);

      expect(viewModel.hasError, isTrue);
      expect(
        viewModel.error,
        'kunde inte tolka handstilen',
        reason: 'the strategy own failure message must reach the VM',
      );
      expect(viewModel.error, isNot(contains('No import strategy')));
      expect(
        fakeLlm.calls,
        1,
        reason: 'exactly one vision call — no printed-prompt char-OCR fallback',
      );
    },
  );
}
