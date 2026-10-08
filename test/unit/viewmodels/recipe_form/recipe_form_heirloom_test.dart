/// BUT-2280: the heirloom scan from a photo import is saved on the recipe
/// parsed from it, through the recipe form that saves that recipe.
library;

import 'dart:typed_data';

import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart'
    as prod_locator;
import 'package:butlery/models/recipe/heirloom_draft.dart';
import 'package:butlery/models/recipe/heirloom_metadata.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/services/analytics_service.dart';
import 'package:butlery/services/connectivity_monitoring_service.dart';
import 'package:butlery/services/image_picker_service.dart';
import 'package:butlery/services/import/heirloom_bridge.dart';
import 'package:butlery/services/import/heirloom_uploader.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/services/storage_service.dart';
import 'package:butlery/services/unified/types/recipe_types.dart';
import 'package:butlery/services/unified/unified_recipe_service.dart';
import 'package:butlery/services/upload/image_upload_service.dart';
import 'package:butlery/viewmodels/recipe_form_viewmodel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../infrastructure/builders/recipe_builder.dart';
import '../../../infrastructure/di/test_service_locator.dart';
import '../../../infrastructure/factories/mock_factory.dart';
import '../../../infrastructure/mocks/production_mocks.dart';
import '../../../infrastructure/mocks/service_mocks.dart';
import '../../../test_support/base_unit_test.dart';

class _MockImageUploadService extends Mock implements ImageUploadService {}

class _MockHeirloomUploader extends Mock implements HeirloomUploader {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockUnifiedRecipeService recipeService;
  late MockPersonalRecipeOperations personalOps;
  late _MockHeirloomUploader uploader;
  late HeirloomBridge bridge;
  RecipeFormViewModel? viewModel;

  final draft = HeirloomDraft(
    imageBytes: Uint8List.fromList([1, 2, 3]),
    writerName: 'Farmor Elsa',
    year: 1972,
  );
  final heirloom = HeirloomMetadata(
    sourceImageUrl: 'https://storage/heirloom/abc.jpg',
    writerName: 'Farmor Elsa',
    year: 1972,
    addedAt: DateTime(2026, 10, 7),
    addedByUserId: 'test-user-123',
  );
  final parsed = RecipeBuilder()
      .withId('parsed-1')
      .withTitle('Farmors bullar')
      .withIngredients(['2 dl mjölk'])
      .withInstructions(['Baka.'])
      .build();

  setUpAll(() async {
    await BaseUnitTest.setupUnit();
    registerFallbackValue(RecipeBuilder().build());
    registerFallbackValue(draft);
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await TestServiceLocator.reset();
    await TestServiceLocator.initialize();
    prod_locator.ServiceLocator.initialize(DIContainer());

    recipeService = MockFactory.createUnifiedRecipeService();
    personalOps = MockPersonalRecipeOperations();
    recipeService.setRecipeState(
      recipes: const [],
      currentUserId: 'test-user-123',
      personalOperations: personalOps,
    );
    when(() => personalOps.addUnifiedRecipe(any())).thenAnswer(
      (_) async => RecipeOperationResult.success('Recipe created'),
    );
    when(() => personalOps.updateUnifiedRecipe(any())).thenAnswer(
      (_) async => RecipeOperationResult.success('Recipe updated'),
    );

    TestServiceLocator.registerMock<UnifiedRecipeService>(recipeService);
    TestServiceLocator.registerMock<AnalyticsService>(
      MockFactory.createAnalyticsService(),
    );
    TestServiceLocator.registerMock<StorageService>(MockStorageService());
    TestServiceLocator.registerMock<ImagePickerService>(
      MockImagePickerService(),
    );
    TestServiceLocator.registerMock<ImageUploadService>(
      _MockImageUploadService(),
    );
    final connectivity = MockConnectivityMonitoringService();
    when(() => connectivity.isConnectedToInternet).thenReturn(true);
    when(() => connectivity.isConnectedToFirebase).thenReturn(true);
    when(() => connectivity.isFullyConnected).thenReturn(true);
    when(() => connectivity.connectionStatusText).thenReturn('Ansluten');
    TestServiceLocator.registerMock<ConnectivityMonitoringService>(
      connectivity,
    );
    TestServiceLocator.registerMock<PermissionService>(
      FakePermissionService()..setPermissionState(
        currentUserId: 'test-user-123',
        isAuthenticated: true,
        defaultHasPermission: true,
      ),
    );

    uploader = _MockHeirloomUploader();
    TestServiceLocator.registerMock<HeirloomUploader>(uploader);
    bridge = HeirloomBridge();
    TestServiceLocator.registerMock<HeirloomBridge>(bridge);
  });

  tearDown(() async {
    viewModel?.dispose();
    viewModel = null;
    await TestServiceLocator.reset();
    BaseUnitTest.resetMocks();
  });

  tearDownAll(() async => BaseUnitTest.teardownUnit());

  RecipeFormViewModel openTemplateOf(Recipe recipe) =>
      viewModel = RecipeFormViewModel(
        recipeService: recipeService,
        initialRecipe: recipe,
        isTemplate: true,
      );

  Recipe written() =>
      verify(() => personalOps.addUnifiedRecipe(captureAny())).captured.single
          as Recipe;

  group('BUT-2280: heirloom scan on the imported recipe', () {
    test('the form of the parsed recipe uploads the scan under the saved '
        'id and saves its details', () async {
      when(
        () => uploader.upload(any(), any()),
      ).thenAnswer((_) async => heirloom);
      bridge
        ..setDraft(draft)
        ..bindTo('parsed-1');

      final form = openTemplateOf(parsed);
      expect(bridge.hasPending, isFalse, reason: 'the form took the draft');

      final saved = await form.saveRecipe();

      expect(saved, isNotNull);
      final recipe = written();
      expect(recipe.heirloom, same(heirloom));
      final uploadedFor = verify(
        () => uploader.upload(captureAny(), captureAny()),
      ).captured;
      expect(uploadedFor[0], same(draft));
      expect(uploadedFor[1], recipe.id);
    });

    test('the scan is uploaded once, not again on a later save', () async {
      when(
        () => uploader.upload(any(), any()),
      ).thenAnswer((_) async => heirloom);
      bridge
        ..setDraft(draft)
        ..bindTo('parsed-1');

      final form = openTemplateOf(parsed);
      expect(await form.saveRecipe(), isNotNull);
      expect(await form.saveRecipe(), isNotNull);

      verify(() => uploader.upload(any(), any())).called(1);
    });

    test('a form for another recipe saves no scan', () async {
      bridge
        ..setDraft(draft)
        ..bindTo('parsed-1');

      final form = openTemplateOf(
        RecipeBuilder()
            .withId('other-1')
            .withTitle('Kopia')
            .withIngredients(['1 ägg'])
            .withInstructions(['Stek.'])
            .build(),
      );
      final saved = await form.saveRecipe();

      expect(saved, isNotNull);
      expect(written().heirloom, isNull);
      verifyNever(() => uploader.upload(any(), any()));
      expect(bridge.hasPending, isTrue);
    });

    test(
      'a failed upload fails the save and keeps the scan for a retry',
      () async {
        when(() => uploader.upload(any(), any())).thenAnswer((_) async => null);
        bridge
          ..setDraft(draft)
          ..bindTo('parsed-1');

        final form = openTemplateOf(parsed);
        expect(await form.saveRecipe(), isNull);
        verifyNever(() => personalOps.addUnifiedRecipe(any()));

        when(
          () => uploader.upload(any(), any()),
        ).thenAnswer((_) async => heirloom);
        expect(await form.saveRecipe(), isNotNull);
        expect(written().heirloom, same(heirloom));
      },
    );

    test('a failed recipe write keeps the scan for a retry', () async {
      when(
        () => uploader.upload(any(), any()),
      ).thenAnswer((_) async => heirloom);
      when(() => personalOps.addUnifiedRecipe(any())).thenAnswer(
        (_) async => RecipeOperationResult.failure('offline'),
      );
      bridge
        ..setDraft(draft)
        ..bindTo('parsed-1');

      final form = openTemplateOf(parsed);
      expect(await form.saveRecipe(), isNull);

      when(() => personalOps.addUnifiedRecipe(any())).thenAnswer(
        (_) async => RecipeOperationResult.success('Recipe created'),
      );
      expect(await form.saveRecipe(), isNotNull);

      verify(() => uploader.upload(any(), any())).called(2);
      final writes = verify(
        () => personalOps.addUnifiedRecipe(captureAny()),
      ).captured;
      expect((writes.last as Recipe).heirloom, same(heirloom));
    });

    test('editing a recipe keeps its heirloom', () async {
      final stored = RecipeBuilder()
          .withId('recipe-test-user-123-001')
          .withCreatedBy('test-user-123')
          .withTitle('Farmors bullar')
          .withIngredients(['2 dl mjölk'])
          .withInstructions(['Baka.'])
          .build()
          .copyWith(heirloom: heirloom);
      viewModel = RecipeFormViewModel(
        recipeService: recipeService,
        initialRecipe: stored,
      );

      final saved = await viewModel!.saveRecipe();

      expect(saved, isNotNull);
      final updated =
          verify(
                () => personalOps.updateUnifiedRecipe(captureAny()),
              ).captured.single
              as Recipe;
      expect(updated.heirloom, same(heirloom));
      verifyNever(() => uploader.upload(any(), any()));
    });
  });
}
