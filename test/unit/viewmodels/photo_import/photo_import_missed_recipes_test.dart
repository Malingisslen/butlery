/// The ways to let AI read a photo the phone already read: the person's own
/// "Saknas något?" and the offer made when the page seems to hold more recipes
/// than the phone found. Neither sends anything until the person says yes.
library;

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:butlery/core/l10n/app_locale.dart';
import 'package:butlery/models/account/user_consent.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/services/connectivity_monitoring_service.dart';
import 'package:butlery/services/import/import_manager.dart';
import 'package:butlery/services/import/models/rate_limit_models.dart';
import 'package:butlery/services/ocr/device_text_recognizer.dart';
import 'package:butlery/services/ocr_extraction_service.dart';
import 'package:butlery/viewmodels/photo_import/photo_import_ai_offer_mixin.dart';
import 'package:butlery/viewmodels/photo_import_viewmodel.dart';

import '../../../fixtures/ocr_test_data.dart';
import '../../../infrastructure/di/test_service_locator.dart';
import '../../../infrastructure/factories/recipe_factory.dart';
import '../../../infrastructure/mocks/production_mocks.dart';
import '../../../test_support/base_unit_test.dart';

const _twoRecipes = '''
Citronkaka

Ingredienser
3 dl vetemjöl
2 dl socker
100 g smör

Gör så här
Sätt ugnen på 175 grader. Blanda mjöl och socker.
Grädda kakan i 35 minuter.

Havrekex

Ingredienser
2 dl havregryn
1 dl mjöl
50 g smör

Gör så här
Rör ihop smeten. Grädda kexen i 12 minuter.
''';

class _Recognizer implements DeviceTextRecognizer {
  _Recognizer(this.text);

  final String text;

  @override
  bool get isAvailable => true;

  @override
  Future<RecognitionResult?> recognize(Uint8List imageBytes) async =>
      RecognitionResult(providerText: text);

  @override
  Future<void> dispose() async {}
}

bool _online = true;

class _Connectivity extends Fake implements ConnectivityMonitoringService {
  @override
  bool get isConnectedToInternet => _online;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockImportManager manager;
  late PhotoImportViewModel vm;
  late bool consented;
  late bool grantSucceeds;
  late int grantCalls;
  late int parsedRecipes;
  late Recipe aiRecipe;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues(const <String, Object>{});
    await BaseUnitTest.setupUnit();
    registerFallbackValue(RecipeFactory.build());
    registerFallbackValue(ConsentPurposes.defaults());
  });

  tearDownAll(() async {
    await BaseUnitTest.teardownUnit();
  });

  void phoneReads(String text) {
    OCRExtractionService.createForTesting(
      testDeviceRecognizer: _Recognizer(text),
      testOnDeviceEnabled: () => true,
      registerAsInstance: true,
    );
  }

  void stubParse({int? blocksTried}) {
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
        successfulRecipes: [
          for (var i = 0; i < parsedRecipes; i++)
            RecipeFactory.build(title: 'Från telefonen $i'),
        ],
        errors: const [],
        totalProcessed: blocksTried ?? parsedRecipes,
        successCount: parsedRecipes,
        failureCount: (blocksTried ?? parsedRecipes) - parsedRecipes,
      ),
    );
  }

  setUp(() {
    _online = true;
    consented = false;
    grantSucceeds = true;
    grantCalls = 0;
    parsedRecipes = 1;
    aiRecipe = RecipeFactory.build(title: 'AI-läst');
    manager = MockImportManager();
    when(
      () => manager.importSinglePhoto(any(), options: any(named: 'options')),
    ).thenAnswer((_) async => ImportManagerResult.success(aiRecipe));
    stubParse();
    vm =
        PhotoImportViewModel(
            importManager: manager,
            connectivity: _Connectivity(),
          )
          ..hasAiConsentOverride = (() async => consented)
          ..grantAiConsentOverride = (() async {
            grantCalls++;
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

  Future<void> readPhoto({int pages = 1}) async {
    for (var i = 0; i < pages; i++) {
      vm.stagePageForTesting(OCRTestImages.uniqueImage(i + 1));
    }
    await vm.readPages();
  }

  void expectNothingSent() => verifyNever(
    () => manager.importSinglePhoto(any(), options: any(named: 'options')),
  );

  group('the person asks', () {
    test(
      'the link is available after a phone read and offers nothing by itself',
      () async {
        phoneReads(OCRExpectedResults.swedishRecipeText);
        await readPhoto();

        expect(vm.canAskAiToRead, isTrue);
        expect(vm.aiOffer, isNull);
        expectNothingSent();
      },
    );

    test('no link before the phone has found a recipe', () async {
      parsedRecipes = 0;
      stubParse();
      phoneReads(OCRExpectedResults.swedishRecipeText);
      await readPhoto();

      expect(vm.canAskAiToRead, isFalse);
    });

    test('asking raises the userAsked offer and still sends nothing', () async {
      phoneReads(OCRExpectedResults.swedishRecipeText);
      await readPhoto();

      await vm.askAiToRead();

      expect(vm.aiOffer, PhotoAiOfferReason.userAsked);
      expect(vm.canAskAiToRead, isFalse);
      expect(grantCalls, 0);
      expectNothingSent();
    });

    test('declining keeps the phone recipe and sends nothing', () async {
      phoneReads(OCRExpectedResults.swedishRecipeText);
      await readPhoto();
      await vm.askAiToRead();

      await vm.declineAiOffer();

      expect(vm.aiOffer, isNull);
      expect(vm.parsedRecipes.single.title, 'Från telefonen 0');
      expect(grantCalls, 0);
      expectNothingSent();
    });

    test(
      'yes without consent records it first, then the AI replaces the list',
      () async {
        phoneReads(OCRExpectedResults.swedishRecipeText);
        await readPhoto();
        await vm.askAiToRead();

        await vm.acceptAiOffer();

        expect(grantCalls, 1);
        expect(vm.parsedRecipe?.title, 'AI-läst');
        expect(vm.canAskAiToRead, isFalse, reason: 'AI has read the photo');
      },
    );

    test('a consent that cannot be saved sends nothing', () async {
      phoneReads(OCRExpectedResults.swedishRecipeText);
      await readPhoto();
      await vm.askAiToRead();
      grantSucceeds = false;

      await vm.acceptAiOffer();

      expectNothingSent();
      expect(vm.error, AppLocale.current.photoAiConsentSaveFailed);
    });

    test(
      'with several pages every page is sent, the phone-read ones too',
      () async {
        phoneReads(OCRExpectedResults.swedishRecipeText);
        await readPhoto(pages: 2);
        await vm.askAiToRead();
        consented = true;

        await vm.acceptAiOffer();

        verify(
          () =>
              manager.importSinglePhoto(any(), options: any(named: 'options')),
        ).called(2);
      },
    );

    test(
      'asking while offline shows the offline message and offers nothing',
      () async {
        phoneReads(OCRExpectedResults.swedishRecipeText);
        await readPhoto();
        _online = false;

        await vm.askAiToRead();

        expect(vm.aiOffer, isNull);
        expect(vm.error, AppLocale.current.importOfflineMessage);
        expectNothingSent();
      },
    );

    test(
      'at the daily cap the limiter message is shown with the hand-written way on',
      () async {
        when(
          () =>
              manager.importSinglePhoto(any(), options: any(named: 'options')),
        ).thenAnswer(
          (_) async => ImportManagerResult.rateLimit(
            const RateLimitDenied(
              message: '',
              retryAfter: Duration(hours: 5),
              limitType: LimitType.llmDaily,
              suggestedAction: FallbackAction.retryLater,
            ),
          ),
        );
        phoneReads(OCRExpectedResults.swedishRecipeText);
        await readPhoto();
        await vm.askAiToRead();
        consented = true;

        await vm.acceptAiOffer();

        expect(vm.error, contains(AppLocale.current.photoAiCapWriteByHand));
        expect(vm.parsedRecipes.single.title, 'Från telefonen 0');
      },
    );
  });

  group('the page seems to hold more recipes', () {
    test('offers once, with no AI call, when the phone found fewer', () async {
      phoneReads(_twoRecipes);
      await readPhoto();

      expect(vm.aiOffer, PhotoAiOfferReason.mayHaveMissedRecipes);
      expect(vm.parsedRecipes, hasLength(1));
      expectNothingSent();
      expect(grantCalls, 0);
    });

    test('is not made again after the person declined', () async {
      phoneReads(_twoRecipes);
      await readPhoto();
      await vm.declineAiOffer();
      expect(vm.aiOffer, isNull);

      await vm.retryOcr();
      vm.stagePageForTesting(OCRTestImages.uniqueImage(9));
      await vm.readPages();

      expect(vm.aiOffer, isNull);
      expect(vm.parsedRecipes.single.title, 'Från telefonen 0');
    });

    test('is not made when the phone found every recipe', () async {
      parsedRecipes = 2;
      stubParse();
      phoneReads(_twoRecipes);
      await readPhoto();

      expect(vm.aiOffer, isNull);
    });

    test(
      'is made when a block the phone tried did not become a recipe',
      () async {
        stubParse(blocksTried: 2);
        phoneReads(OCRExpectedResults.swedishRecipeText);
        await readPhoto();

        expect(vm.parsedRecipes, hasLength(1));
        expect(vm.aiOffer, PhotoAiOfferReason.mayHaveMissedRecipes);
      },
    );

    test('is not made for a page with a single recipe', () async {
      phoneReads(OCRExpectedResults.swedishRecipeText);
      await readPhoto();

      expect(vm.aiOffer, isNull);
    });

    test(
      'is not made on text the AI answered with for a single page',
      () async {
        parsedRecipes = 0;
        stubParse();
        phoneReads(OCRExpectedResults.swedishRecipeText);
        await readPhoto();
        expect(vm.aiOffer, PhotoAiOfferReason.noRecipeFound);
        consented = true;
        when(
          () =>
              manager.importSinglePhoto(any(), options: any(named: 'options')),
        ).thenAnswer(
          (_) async =>
              ImportManagerResult.assistance(extractedText: _twoRecipes),
        );
        parsedRecipes = 1;
        stubParse();

        await vm.acceptAiOffer();

        expect(vm.parsedRecipes, hasLength(1));
        expect(vm.aiOffer, isNull);
      },
    );

    test(
      'declining either offer leaves the phone recipe without a second parse',
      () async {
        phoneReads(_twoRecipes);
        await readPhoto();
        expect(vm.aiOffer, PhotoAiOfferReason.mayHaveMissedRecipes);
        await vm.declineAiOffer();
        await vm.askAiToRead();
        expect(vm.aiOffer, PhotoAiOfferReason.userAsked);

        await vm.declineAiOffer();

        verify(
          () => manager.autoParseMulti(
            any(),
            layout: any(named: 'layout'),
            channel: any(named: 'channel'),
            reflow: any(named: 'reflow'),
          ),
        ).called(1);
        expect(vm.parsedRecipes.single.title, 'Från telefonen 0');
        expectNothingSent();
      },
    );

    test(
      'accepting sends every page, the ones the phone read too',
      () async {
        phoneReads(_twoRecipes);
        await readPhoto(pages: 3);
        expect(vm.aiOffer, PhotoAiOfferReason.mayHaveMissedRecipes);
        expect(vm.confidence, isNotNull);
        consented = true;

        await vm.acceptAiOffer();

        expect(vm.confidence, isNull);

        verify(
          () =>
              manager.importSinglePhoto(any(), options: any(named: 'options')),
        ).called(3);
      },
    );

    test(
      'text the AI answered with raises no new offer on the text route',
      () async {
        parsedRecipes = 0;
        stubParse();
        phoneReads(OCRExpectedResults.swedishRecipeText);
        await readPhoto(pages: 2);
        expect(vm.aiOffer, PhotoAiOfferReason.noRecipeFound);
        consented = true;
        when(
          () =>
              manager.importSinglePhoto(any(), options: any(named: 'options')),
        ).thenAnswer(
          (_) async =>
              ImportManagerResult.assistance(extractedText: _twoRecipes),
        );
        parsedRecipes = 1;
        stubParse();

        await vm.acceptAiOffer();

        expect(vm.parsedRecipes, hasLength(1));
        expect(vm.aiOffer, isNull);
      },
    );

    test('a new photo session may offer again after a decline', () async {
      phoneReads(_twoRecipes);
      await readPhoto();
      await vm.declineAiOffer();
      expect(vm.aiOffer, isNull);

      vm.clearPhoto();
      await readPhoto();

      expect(vm.aiOffer, PhotoAiOfferReason.mayHaveMissedRecipes);
    });
  });
}
