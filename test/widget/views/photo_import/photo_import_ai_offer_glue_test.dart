/// The photo import view shows the AI offer card when the viewmodel holds an
/// offer and wires its buttons to accept/decline.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart' as production;
import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/user_allergen_preferences.dart';
import 'package:butlery/services/user_service.dart';
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/viewmodels/photo_import/photo_import_ai_offer_mixin.dart';
import 'package:butlery/viewmodels/photo_import/photo_import_draft.dart';
import 'package:butlery/viewmodels/photo_import_viewmodel.dart';
import 'package:butlery/views/photo_import/photo_ai_offer_card.dart';
import 'package:butlery/views/photo_import_view.dart';

import '../../../infrastructure/di/test_service_locator.dart';
import '../../../infrastructure/helpers/offline_banner_support.dart';
import '../../../test_support/base_unit_test.dart';

class _MockUserService extends Mock implements UserService {}

// Answers only what the view reads; anything else fails loudly.
class _OfferFakeViewModel extends ChangeNotifier
    implements PhotoImportViewModel {
  _OfferFakeViewModel({this.offer, this.consented = false});

  final PhotoAiOfferReason? offer;
  final bool consented;
  int accepts = 0;
  int declines = 0;

  @override
  PhotoPermissionResolver? permissionResolver;

  @override
  String get ocrText => '1. Blanda allt.\nGrädda i ugnen.';

  @override
  double? get confidence => 0.9;

  @override
  List<Recipe> get parsedRecipes => const [];

  @override
  bool get hasMultipleRecipes => false;

  @override
  bool get hasOcrResult => true;

  @override
  bool get hasImage => false;

  @override
  PhotoAiOfferReason? get aiOffer => offer;

  @override
  bool get aiConsentAlreadyGiven => consented;

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
  Future<void> acceptAiOffer() async => accepts++;

  @override
  Future<void> declineAiOffer() async => declines++;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late AppLocalizations sv;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await BaseUnitTest.setupUnit();
    sv = await AppLocalizations.delegate.load(const Locale('sv'));
  });

  setUp(() async {
    await TestServiceLocator.initialize();
    production.ServiceLocator.initialize(DIContainer());
    ensureOfflineService();

    final userService = _MockUserService();
    when(
      () => userService.allergenPreferences,
    ).thenReturn(UserAllergenPreferences.defaults);
    TestServiceLocator.registerMock<UserService>(userService);
  });

  tearDown(() async {
    await TestServiceLocator.reset();
    production.ServiceLocator.reset();
  });

  tearDownAll(() async {
    await BaseUnitTest.teardownUnit();
  });

  Future<void> pumpView(WidgetTester tester, _OfferFakeViewModel vm) async {
    TestServiceLocator.registerMock<PhotoImportViewModel>(vm);
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
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('an offer shows the card and accept reaches the viewmodel', (
    tester,
  ) async {
    final vm = _OfferFakeViewModel(offer: PhotoAiOfferReason.phoneCouldNotRead);
    await pumpView(tester, vm);

    expect(find.byType(PhotoAiOfferCard), findsOneWidget);
    await tester.tap(find.text(sv.photoAiOfferAccept));
    await tester.pump();

    expect(vm.accepts, 1);
    expect(vm.declines, 0);
  });

  testWidgets('decline reaches the viewmodel', (tester) async {
    final vm = _OfferFakeViewModel(offer: PhotoAiOfferReason.phoneCouldNotRead);
    await pumpView(tester, vm);

    await tester.tap(find.text(sv.photoAiOfferDecline));
    await tester.pump();

    expect(vm.declines, 1);
    expect(vm.accepts, 0);
  });

  testWidgets('without prior consent the consent question is shown', (
    tester,
  ) async {
    await pumpView(
      tester,
      _OfferFakeViewModel(offer: PhotoAiOfferReason.phoneCouldNotRead),
    );

    expect(find.text(sv.photoAiOfferQuestion), findsOneWidget);
    expect(find.text(sv.photoAiOfferQuestionConsented), findsNothing);
  });

  testWidgets('with prior consent the consented question replaces it', (
    tester,
  ) async {
    await pumpView(
      tester,
      _OfferFakeViewModel(
        offer: PhotoAiOfferReason.phoneCouldNotRead,
        consented: true,
      ),
    );

    expect(find.text(sv.photoAiOfferQuestionConsented), findsOneWidget);
    expect(find.text(sv.photoAiOfferQuestion), findsNothing);
  });

  testWidgets('no offer means no card', (tester) async {
    await pumpView(tester, _OfferFakeViewModel());

    expect(find.byType(PhotoAiOfferCard), findsNothing);
  });
}
