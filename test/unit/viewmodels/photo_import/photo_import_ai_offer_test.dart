/// Photo import's consent-gated AI offer (consent variant B): the phone reads
/// first, and a photo reaches the vision import only after the person says yes.
library;

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/l10n/app_locale.dart';
import 'package:butlery/core/providers/application_provider.dart' as production;
import 'package:butlery/models/account/user_consent.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/services/account/consent_service.dart';
import 'package:butlery/services/connectivity_monitoring_service.dart';
import 'package:butlery/services/import/import_manager_result.dart';
import 'package:butlery/services/ocr/device_text_recognizer.dart';
import 'package:butlery/services/ocr_extraction_service.dart';
import 'package:butlery/viewmodels/photo_import/photo_import_ai_offer_mixin.dart';
import 'package:butlery/viewmodels/photo_import_viewmodel.dart';

import '../../../fixtures/ocr_test_data.dart';
import '../../../infrastructure/di/test_service_locator.dart';
import '../../../infrastructure/factories/recipe_factory.dart';
import '../../../infrastructure/mocks/production_mocks.dart';
import '../../../test_support/base_unit_test.dart';

/// Answers the n:th recognition with the n:th script entry; null is a page the
/// phone cannot read.
class _ScriptedRecognizer implements DeviceTextRecognizer {
  _ScriptedRecognizer(this.script);

  final List<String?> script;
  int calls = 0;

  @override
  bool get isAvailable => true;

  @override
  Future<RecognitionResult?> recognize(Uint8List imageBytes) async {
    final text = calls < script.length ? script[calls] : null;
    calls++;
    return text == null ? null : RecognitionResult(providerText: text);
  }

  @override
  Future<void> dispose() async {}
}

class _MockConsentService extends Mock implements ConsentService {}

class _SwitchableConnectivity extends Fake
    implements ConnectivityMonitoringService {
  bool online = true;

  @override
  bool get isConnectedToInternet => online;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final phoneText = OCRExpectedResults.swedishRecipeText;

  late MockImportManager manager;
  late _SwitchableConnectivity connectivity;
  late _ScriptedRecognizer recognizer;
  late PhotoImportViewModel vm;
  late bool consented;
  late int grantCalls;
  late List<String> events;
  late bool grantSucceeds;
  late Recipe aiRecipe;

  void stubParse(int recipes) {
    when(
      () => manager.autoParseMulti(
        any(),
        layout: any(named: 'layout'),
        channel: any(named: 'channel'),
        reflow: any(named: 'reflow'),
      ),
    ).thenAnswer(
      (_) async => BatchImportResult(
        results: const [],
        successfulRecipes: [for (var i = 0; i < recipes; i++) aiRecipe],
        errors: const [],
        totalProcessed: recipes,
        successCount: recipes,
        failureCount: 0,
      ),
    );
  }

  setUpAll(() async {
    SharedPreferences.setMockInitialValues(const <String, Object>{});
    await BaseUnitTest.setupUnit();
    registerFallbackValue(RecipeFactory.build());
    registerFallbackValue(ConsentPurposes.defaults());
  });

  tearDownAll(() async {
    await BaseUnitTest.teardownUnit();
  });

  void startPhone(List<String?> script) {
    recognizer = _ScriptedRecognizer(script);
    OCRExtractionService.createForTesting(
      testDeviceRecognizer: recognizer,
      testOnDeviceEnabled: () => true,
      registerAsInstance: true,
    );
  }

  setUp(() {
    consented = false;
    grantCalls = 0;
    grantSucceeds = true;
    events = [];
    aiRecipe = RecipeFactory.build(title: 'AI-läst recept');
    connectivity = _SwitchableConnectivity();
    manager = MockImportManager();

    when(
      () => manager.importSinglePhoto(any(), options: any(named: 'options')),
    ).thenAnswer((_) async {
      events.add('vision');
      return ImportManagerResult.success(aiRecipe);
    });
    // Nothing parses unless a test says so, so "no recipe found" is the default.
    stubParse(0);

    vm =
        PhotoImportViewModel(importManager: manager, connectivity: connectivity)
          ..hasAiConsentOverride = (() async => consented)
          ..grantAiConsentOverride = (() async {
            grantCalls++;
            events.add('grant');
            consented = grantSucceeds;
            return grantSucceeds;
          });
  });

  tearDown(() async {
    vm.dispose();
    OCRExtractionService.resetForTesting();
    BaseUnitTest.resetMocks();
    await TestServiceLocator.reset();
  });

  Uint8List page(int seed) => OCRTestImages.uniqueImage(seed);

  Future<void> offerAfterPhoneMiss({int pages = 1}) async {
    startPhone([for (var i = 0; i < pages; i++) null]);
    for (var i = 0; i < pages; i++) {
      vm.stagePageForTesting(page(i + 1));
    }
    await vm.readPages();
    expect(vm.aiOffer, PhotoAiOfferReason.phoneCouldNotRead);
  }

  List<Uint8List> visionPages() {
    final options = verify(
      () => manager.importSinglePhoto(
        any(),
        options: captureAny(named: 'options'),
      ),
    ).captured;
    return [for (final o in options) (o as Map)['imageBytes'] as Uint8List];
  }

  group('handwritten mode', () {
    test(
      'without consent the photo is not sent: the offer is made instead',
      () async {
        startPhone([phoneText]);
        vm.setHandwritten(true);
        vm.stagePageForTesting(page(1));

        await vm.readPages();

        verifyNever(
          () =>
              manager.importSinglePhoto(any(), options: any(named: 'options')),
        );
        expect(vm.aiOffer, PhotoAiOfferReason.handwriting);
        expect(vm.hasError, isFalse);
        expect(
          recognizer.calls,
          0,
          reason: 'the phone cannot read handwriting',
        );
      },
    );

    test(
      'with consent the vision import runs directly, with no offer',
      () async {
        consented = true;
        startPhone([phoneText]);
        vm.setHandwritten(true);
        vm.stagePageForTesting(page(1));

        await vm.readPages();

        final captured =
            verify(
                  () => manager.importSinglePhoto(
                    any(),
                    options: captureAny(named: 'options'),
                  ),
                ).captured.single
                as Map;
        expect(captured['visionOnly'], isTrue);
        expect(captured['isHandwritten'], isTrue);
        expect(vm.aiOffer, isNull);
        expect(grantCalls, 0);
        expect(vm.parsedRecipe?.title, aiRecipe.title);
      },
    );
  });

  group('printed pages', () {
    for (final alreadyConsented in [true, false]) {
      test(
        'a page the phone cannot read raises an offer, not an error '
        '(consent already given: $alreadyConsented)',
        () async {
          consented = alreadyConsented;

          await offerAfterPhoneMiss();

          expect(vm.hasError, isFalse);
          expect(vm.aiConsentAlreadyGiven, alreadyConsented);
          expect(vm.unreadPageCount, 1);
          verifyNever(
            () => manager.importSinglePhoto(
              any(),
              options: any(named: 'options'),
            ),
          );
        },
      );
    }

    test(
      'pages read but holding no recipe raise the noRecipeFound offer',
      () async {
        startPhone([phoneText]);
        vm.stagePageForTesting(page(1));

        await vm.readPages();

        expect(vm.unreadPageCount, 0);
        expect(vm.aiOffer, PhotoAiOfferReason.noRecipeFound);
        expect(vm.hasError, isFalse);
      },
    );

    test('a recipe found on the phone raises no offer', () async {
      stubParse(1);
      startPhone([phoneText]);
      vm.stagePageForTesting(page(1));

      await vm.readPages();

      expect(vm.aiOffer, isNull);
      expect(vm.parsedRecipes, hasLength(1));
    });

    test(
      'a photo the quality gate refuses shows its advice, not an offer',
      () async {
        startPhone([phoneText]);
        vm.stagePageForTesting(Uint8List(32));

        await vm.readPages();

        expect(vm.hasError, isTrue);
        expect(vm.aiOffer, isNull);
        expect(recognizer.calls, 0);
      },
    );
  });

  group('acceptAiOffer', () {
    test(
      'records the consent before anything is sent, then reads the photo',
      () async {
        await offerAfterPhoneMiss();
        expect(vm.aiConsentAlreadyGiven, isFalse);

        await vm.acceptAiOffer();

        expect(grantCalls, 1);
        expect(events, ['grant', 'vision']);
        expect(vm.aiOffer, isNull);
        expect(vm.hasError, isFalse);
        expect(vm.parsedRecipe?.title, aiRecipe.title);
      },
    );

    test('with consent already given nothing is granted again', () async {
      consented = true;
      await offerAfterPhoneMiss();

      await vm.acceptAiOffer();

      expect(grantCalls, 0);
      expect(events, ['vision']);
    });

    test(
      'a consent that cannot be saved sends nothing, says so and keeps the offer',
      () async {
        await offerAfterPhoneMiss();
        grantSucceeds = false;

        await vm.acceptAiOffer();

        expect(grantCalls, 1);
        expect(events, ['grant']);
        expect(vm.error, AppLocale.current.photoAiConsentSaveFailed);
        expect(vm.aiOffer, PhotoAiOfferReason.phoneCouldNotRead);
      },
    );

    test('offline: no consent is recorded and nothing is sent', () async {
      await offerAfterPhoneMiss();
      connectivity.online = false;

      await vm.acceptAiOffer();

      expect(events, isEmpty);
      expect(vm.error, AppLocale.current.importOfflineMessage);
    });

    test(
      'several pages: only the pages the phone missed go to the AI',
      () async {
        consented = true;
        startPhone([phoneText, null, phoneText]);
        for (var i = 1; i <= 3; i++) {
          vm.stagePageForTesting(page(i));
        }
        await vm.readPages();
        expect(vm.aiOffer, PhotoAiOfferReason.phoneCouldNotRead);
        expect(vm.unreadPageCount, 1);

        await vm.acceptAiOffer();

        expect(visionPages(), [page(2)]);
        expect(vm.unreadPageCount, 0);
        expect(vm.aiOffer, isNull);
      },
    );

    test(
      'several pages with no recipe found: every page goes to the AI',
      () async {
        consented = true;
        startPhone([phoneText, phoneText, phoneText]);
        for (var i = 1; i <= 3; i++) {
          vm.stagePageForTesting(page(i));
        }
        await vm.readPages();
        expect(vm.aiOffer, PhotoAiOfferReason.noRecipeFound);

        await vm.acceptAiOffer();

        expect(visionPages(), [page(1), page(2), page(3)]);
      },
    );
  });

  group('declineAiOffer', () {
    test('keeps the text the phone read from the other pages', () async {
      startPhone([phoneText, null]);
      vm.stagePageForTesting(page(1));
      vm.stagePageForTesting(page(2));
      await vm.readPages();
      expect(vm.aiOffer, PhotoAiOfferReason.phoneCouldNotRead);

      await vm.declineAiOffer();

      expect(vm.ocrText, contains(phoneText.trim()));
      expect(vm.hasOcrResult, isTrue);
    });

    test(
      'sends nothing, clears the offer and leaves no page waiting',
      () async {
        await offerAfterPhoneMiss(pages: 2);
        expect(vm.unreadPageCount, 2);

        await vm.declineAiOffer();

        verifyNever(
          () =>
              manager.importSinglePhoto(any(), options: any(named: 'options')),
        );
        expect(grantCalls, 0);
        expect(vm.aiOffer, isNull);
        expect(vm.unreadPageCount, 0);
      },
    );
  });

  group('after an accepted AI read', () {
    Future<void> acceptedRead() async {
      consented = true;
      await offerAfterPhoneMiss();
      await vm.acceptAiOffer();
      expect(vm.aiOffer, isNull);
    }

    test('a later page with no recipe raises no second offer', () async {
      await acceptedRead();
      startPhone([phoneText]);
      vm.stagePageForTesting(page(2));

      await vm.readPages();

      expect(vm.aiOffer, isNull);
    });

    test('clearing the import brings the no-recipe offer back', () async {
      await acceptedRead();
      vm.clearImportData();
      startPhone([phoneText]);
      vm.stagePageForTesting(page(3));

      await vm.readPages();

      expect(vm.aiOffer, PhotoAiOfferReason.noRecipeFound);
    });
  });

  group('the real consent store', () {
    late _MockConsentService consent;
    final other = const ConsentPurposes(
      essentialServices: true,
      dataProcessing: true,
      analytics: true,
      marketing: true,
      socialFeatures: false,
      pushNotifications: true,
    );

    setUp(() {
      vm
        ..hasAiConsentOverride = null
        ..grantAiConsentOverride = null;
      consent = _MockConsentService();
      // The test locator skips the production ServiceLocator, which is where
      // the view model looks the consent service up.
      production.ServiceLocator.initialize(DIContainer());
    });

    tearDown(() {
      TestServiceLocator.unregister<ConsentService>();
      production.ServiceLocator.reset();
    });

    test('accepting saves aiProcessing and keeps the other choices', () async {
      TestServiceLocator.registerSingleton<ConsentService>(consent);
      when(
        () => consent.hasConsent(ConsentPurpose.aiProcessing),
      ).thenAnswer((_) async => false);
      when(() => consent.getUserConsent()).thenAnswer(
        (_) async => UserConsent(
          userId: 'u',
          purposes: other,
          grantedAt: DateTime(2026),
          consentVersion: '1',
          deviceInfo: 'test',
        ),
      );
      when(() => consent.saveConsent(any())).thenAnswer((_) async {
        events.add('save');
        return true;
      });
      await offerAfterPhoneMiss();
      expect(vm.aiConsentAlreadyGiven, isFalse);

      await vm.acceptAiOffer();

      final saved =
          verify(() => consent.saveConsent(captureAny())).captured.single
              as ConsentPurposes;
      expect(saved.aiProcessing, isTrue);
      expect(saved.analytics, other.analytics);
      expect(saved.marketing, other.marketing);
      expect(saved.socialFeatures, other.socialFeatures);
      expect(saved.pushNotifications, other.pushNotifications);
      expect(events, ['save', 'vision']);
    });

    test('without a consent service nothing is sent and it says so', () async {
      await offerAfterPhoneMiss();
      expect(vm.aiConsentAlreadyGiven, isFalse);

      await vm.acceptAiOffer();

      verifyNever(
        () => manager.importSinglePhoto(any(), options: any(named: 'options')),
      );
      expect(vm.error, AppLocale.current.photoAiConsentSaveFailed);
    });
  });

  test('clearImportData withdraws a pending offer', () async {
    await offerAfterPhoneMiss();

    vm.clearImportData();

    expect(vm.aiOffer, isNull);
  });

  group('a pending offer is withdrawn when the pages change', () {
    test('adding a page clears it, and accepting then sends nothing', () async {
      consented = true;
      await offerAfterPhoneMiss();

      vm.stagePageForTesting(page(2));

      expect(vm.aiOffer, isNull);
      await vm.acceptAiOffer();
      verifyNever(
        () => manager.importSinglePhoto(any(), options: any(named: 'options')),
      );
      expect(events, isEmpty);
    });

    test('removing a page clears it', () async {
      await offerAfterPhoneMiss(pages: 2);

      await vm.removePage(0);

      expect(vm.aiOffer, isNull);
    });

    test('reordering pages clears it', () async {
      await offerAfterPhoneMiss(pages: 2);

      await vm.reorderPage(0, 2);

      expect(vm.aiOffer, isNull);
    });
  });
}
