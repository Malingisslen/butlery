/// BUT-2455: "Fortsätt" on the photo import hands the recipe the reading
/// already produced to the recipe form. Parsing the OCR text a second time
/// lost the line joining and counted the import twice.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/core/constants/routes.dart';
import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart' as production;
import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/user_allergen_preferences.dart';
import 'package:butlery/services/import/heirloom_bridge.dart';
import 'package:butlery/services/user_service.dart';
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/viewmodels/photo_import/photo_import_draft.dart';
import 'package:butlery/viewmodels/photo_import/photo_import_ai_offer_mixin.dart';
import 'package:butlery/viewmodels/photo_import_viewmodel.dart';
import 'package:butlery/viewmodels/text_import_viewmodel.dart';
import 'package:butlery/views/photo_import_view.dart';

import '../../../infrastructure/di/test_service_locator.dart';
import '../../../infrastructure/helpers/offline_banner_support.dart';
import '../../../test_support/base_unit_test.dart';

class _MockTextImportViewModel extends Mock implements TextImportViewModel {}

class _MockUserService extends Mock implements UserService {}

class _MockHeirloomBridge extends Mock implements HeirloomBridge {}

// Answers only what the view reads once a reading has finished; anything else
// reaches noSuchMethod and fails the test loudly.
class _ReadFakeViewModel extends ChangeNotifier
    implements PhotoImportViewModel {
  _ReadFakeViewModel(this.recipes);

  final List<Recipe> recipes;

  @override
  PhotoPermissionResolver? permissionResolver;

  @override
  String get ocrText => '1. Blanda allt.\nGrädda i ugnen.';

  @override
  double? get confidence => 0.9;

  @override
  List<Recipe> get parsedRecipes => recipes;

  @override
  bool get hasMultipleRecipes => recipes.length > 1;

  @override
  bool get hasOcrResult => true;

  @override
  bool get hasImage => false;

  @override
  PhotoAiOfferReason? get aiOffer => null;

  @override
  bool get aiConsentAlreadyGiven => false;

  @override
  bool get hasError => false;

  @override
  String? get error => null;

  @override
  bool get isProcessing => false;

  @override
  bool get isHeirloom => false;

  @override
  bool get isHandwritten => false;

  @override
  bool get canToggleHandwritten => true;

  @override
  bool get canRetryOcr => false;

  @override
  bool get canReadPages => false;

  @override
  int get unreadPageCount => 0;

  @override
  int get pageCount => 0;

  @override
  double? get qualityScore => null;

  @override
  PhotoPermissionNotice? get permissionNotice => null;

  @override
  Future<PhotoImportDraft?> loadPersistedDraft() async => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Recipe _recipe(String id) => Recipe(
  core: RecipeCore(
    id: id,
    title: 'Kycklinggryta',
    description: '',
    ingredients: const ['2 dl grädde'],
    instructions: const ['Blanda allt.', 'Grädda i ugnen.'],
    mealType: 'Middag',
  ),
  type: RecipeType.personal,
);

void main() {
  late _MockTextImportViewModel textVm;
  late _MockHeirloomBridge bridge;
  late List<RouteSettings> pushed;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await BaseUnitTest.setupUnit();
  });

  setUp(() async {
    await TestServiceLocator.initialize();
    production.ServiceLocator.initialize(DIContainer());
    ensureOfflineService();

    textVm = _MockTextImportViewModel();
    when(() => textVm.parseText()).thenAnswer((_) async => true);
    TestServiceLocator.registerMock<TextImportViewModel>(textVm);

    final userService = _MockUserService();
    when(
      () => userService.allergenPreferences,
    ).thenReturn(UserAllergenPreferences.defaults);
    TestServiceLocator.registerMock<UserService>(userService);

    bridge = _MockHeirloomBridge();
    TestServiceLocator.registerMock<HeirloomBridge>(bridge);
    pushed = [];
  });

  tearDown(() async {
    await TestServiceLocator.reset();
    production.ServiceLocator.reset();
  });

  tearDownAll(() async {
    await BaseUnitTest.teardownUnit();
  });

  Future<void> pressProceed(
    WidgetTester tester,
    List<Recipe> recipes,
  ) async {
    TestServiceLocator.registerMock<PhotoImportViewModel>(
      _ReadFakeViewModel(recipes),
    );
    tester.view.physicalSize = const Size(900, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('sv'),
        home: const PhotoImportView(),
        onGenerateRoute: (settings) {
          pushed.add(settings);
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => const Scaffold(body: Text('next')),
          );
        },
      ),
    );
    await tester.pumpAndSettle();

    final sv = await AppLocalizations.delegate.load(const Locale('sv'));
    final button = find.text(sv.importProceedToEdit);
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();
  }

  testWidgets('one parsed recipe opens the form with exactly that recipe', (
    tester,
  ) async {
    final recipe = _recipe('r1');
    await pressProceed(tester, [recipe]);

    expect(pushed, hasLength(1));
    expect(pushed.single.name, Routes.manualEntry);
    final args = pushed.single.arguments! as Map<String, Object?>;
    expect(args['initialRecipe'], same(recipe));
    expect(args['isTemplate'], isTrue);
    verify(() => bridge.bindToAll(['r1'])).called(1);
    verifyNever(() => textVm.parseText());
    // Pushed, not replaced: back from the form returns to the reading.
    expect(
      find.byType(PhotoImportView, skipOffstage: false),
      findsOneWidget,
    );
  });

  testWidgets('no parsed recipe falls back to the text screen with the text', (
    tester,
  ) async {
    await pressProceed(tester, const []);

    expect(pushed, hasLength(1));
    expect(pushed.single.name, Routes.fromSocialMedia);
    final args = pushed.single.arguments! as Map<String, Object?>;
    expect(args['text'], '1. Blanda allt.\nGrädda i ugnen.');
    verifyNever(() => bridge.bindToAll(any()));
    verifyNever(() => textVm.parseText());
  });
}
