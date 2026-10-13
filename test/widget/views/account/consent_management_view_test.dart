// Samtycken under Integritet & data: the switches change a draft and "Spara
// mina val" writes one consent record, a failed save shows what is really
// stored, and "Återkalla allt valfritt" confirms before it revokes.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

import 'package:butlery/widgets/common/butlery_top_bar.dart';
import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart' as production;
import 'package:butlery/l10n/app_localizations_sv.dart';
import 'package:butlery/models/account/user_consent.dart';
import 'package:butlery/viewmodels/account/consent_viewmodel.dart';
import 'package:butlery/views/account/consent_management_view.dart';

import '../../../infrastructure/di/test_service_locator.dart';
import '../../../infrastructure/helpers/widget_test_app.dart';
import '../../../infrastructure/mocks/production_mocks.dart';
import '../../../views/helpers/view_test_helpers.dart';

void main() {
  final sv = AppLocalizationsSv();
  late MockConsentService service;
  late ConsentViewModel viewModel;
  late ConsentPurposes stored;

  setUpAll(() {
    registerFallbackValue(
      const ConsentPurposes(essentialServices: true, dataProcessing: true),
    );
  });

  setUp(() async {
    await ViewTestHelpers.setupViewTestEnvironment();
    production.ServiceLocator.initialize(DIContainer());
    stored = const ConsentPurposes(
      essentialServices: true,
      dataProcessing: true,
      analytics: true,
    );
    service = MockConsentService();
    when(service.getUserConsent).thenAnswer(
      (_) async => UserConsent(
        userId: 'u1',
        purposes: stored,
        grantedAt: DateTime(2026, 1, 1),
        consentVersion: '1.1.0',
        deviceInfo: 'test',
      ),
    );
    when(service.needsConsentRenewal).thenAnswer((_) async => false);
    when(() => service.saveConsent(any())).thenAnswer((inv) async {
      stored = inv.positionalArguments.first as ConsentPurposes;
      return true;
    });
    when(service.revokeOptionalConsents).thenAnswer((_) async {
      stored = const ConsentPurposes(
        essentialServices: true,
        dataProcessing: true,
      );
      return true;
    });
    viewModel = ConsentViewModel(consentService: service);
  });

  tearDown(() async {
    viewModel.dispose();
    production.ServiceLocator.reset();
    await TestServiceLocator.reset();
    await ViewTestHelpers.teardownViewTestEnvironment();
  });

  Future<void> pump(WidgetTester tester, {String? backTo}) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      createLocalizedTestApp(
        wrapInScaffold: false,
        child: ChangeNotifierProvider<ConsentViewModel>.value(
          value: viewModel,
          child: ConsentManagementView(backTo: backTo),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder switchOf(String label) => find.descendant(
    of: find.ancestor(of: find.text(label), matching: find.byType(InkWell)),
    matching: find.byType(Switch),
  );

  Future<void> save(WidgetTester tester) async {
    await tester.ensureVisible(find.text(sv.consentSaveMyChoices));
    await tester.tap(find.text(sv.consentSaveMyChoices));
    await tester.pumpAndSettle();
  }

  testWidgets('shows the two locked purposes in a note and the five optional '
      'ones as switches, with Spara mina val', (tester) async {
    await pump(tester);

    expect(find.text(sv.consentEssentialTitle), findsOneWidget);
    expect(find.text(sv.consentDataProcessing), findsOneWidget);
    expect(find.byType(Switch), findsNWidgets(5));
    expect(tester.widget<Switch>(switchOf(sv.consentAnalytics)).value, isTrue);
    expect(
      tester.widget<Switch>(switchOf(sv.consentPushNotifications)).value,
      isFalse,
    );
    expect(find.text(sv.consentSaveMyChoices), findsOneWidget);
    expect(
      find.text(sv.consentSavedVersion('1.1.0', '1 januari', ' · test')),
      findsOneWidget,
    );
    expect(find.byType(Card), findsNothing);
    expect(find.text(sv.settingsBlockedPeople), findsNothing);
    expect(find.text(sv.blockedUsersTitle), findsNothing);
  });

  testWidgets('Back is named after where the caller says it leads, and '
      'names none from the renewal dialog', (tester) async {
    ButleryTopBar bar() => tester.widget(find.byType(ButleryTopBar));
    await pump(tester, backTo: sv.settingsPrivacyAreaTitle);
    expect(bar().backTo, 'Integritet och data');

    await pump(tester);
    expect(bar().backTo, isNull);
  });

  testWidgets('flipping a switch saves nothing until Spara mina val, and '
      'then only that purpose changed', (tester) async {
    await pump(tester);

    await tester.tap(find.text(sv.consentPushNotifications));
    await tester.pumpAndSettle();
    verifyNever(() => service.saveConsent(any()));

    await save(tester);

    final saved =
        verify(() => service.saveConsent(captureAny())).captured.single
            as ConsentPurposes;
    expect(saved.pushNotifications, isTrue);
    expect(saved.analytics, isTrue);
    expect(saved.aiProcessing, isFalse);
    expect(find.text(sv.consentSaved), findsOneWidget);
    expect(
      tester.widget<Switch>(switchOf(sv.consentPushNotifications)).value,
      isTrue,
    );
  });

  testWidgets('a failed save shows the error and the stored state', (
    tester,
  ) async {
    when(() => service.saveConsent(any())).thenAnswer((_) async => false);
    await pump(tester);

    await tester.tap(find.text(sv.consentAiProcessing));
    await tester.pumpAndSettle();
    await save(tester);

    expect(find.text(sv.consentSaved), findsNothing);
    expect(find.textContaining(sv.errorGeneric), findsWidgets);
    expect(
      tester.widget<Switch>(switchOf(sv.consentAiProcessing)).value,
      isFalse,
    );
  });

  testWidgets('Vad vi loggar opens a sheet listing the categories', (
    tester,
  ) async {
    await pump(tester);

    await tester.tap(find.text(sv.consentWhatWeLog));
    await tester.pumpAndSettle();

    expect(find.text(sv.consentWhatWeLogIntro), findsOneWidget);
    expect(find.text(sv.consentLogCategoryRecipes), findsOneWidget);
  });

  testWidgets('Historik lists the saved versions', (tester) async {
    when(service.getConsentHistory).thenAnswer(
      (_) async => [
        UserConsent(
          userId: 'u1',
          purposes: stored,
          grantedAt: DateTime(2026, 1, 1),
          consentVersion: '1.0.0',
          deviceInfo: 'test',
        ),
      ],
    );
    await pump(tester);

    await tester.tap(find.text(sv.consentHistory));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('1.0.0 · ${sv.consentAnalytics}'),
      findsOneWidget,
    );
  });

  testWidgets('Återkalla allt valfritt asks first, then revokes', (
    tester,
  ) async {
    await pump(tester);

    await tester.ensureVisible(find.text(sv.consentRevokeAllOptional));
    await tester.tap(find.text(sv.consentRevokeAllOptional));
    await tester.pumpAndSettle();
    expect(find.text(sv.consentRevokeAllTitle), findsOneWidget);
    verifyNever(service.revokeOptionalConsents);

    await tester.tap(find.text(sv.commonCancel));
    await tester.pumpAndSettle();
    verifyNever(service.revokeOptionalConsents);

    await tester.ensureVisible(find.text(sv.consentRevokeAllOptional));
    await tester.tap(find.text(sv.consentRevokeAllOptional));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(Dialog),
        matching: find.text(sv.consentRevokeAll),
      ),
    );
    await tester.pumpAndSettle();

    verify(service.revokeOptionalConsents).called(1);
    expect(find.text(sv.consentAllRevoked), findsOneWidget);
    expect(tester.widget<Switch>(switchOf(sv.consentAnalytics)).value, isFalse);
  });
}
