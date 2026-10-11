// BUT-920: "Från sociala medier" reaches the AI structuring when a link is
// pasted, so a guest's import there is counted like any other. When the photo
// import hands its OCR text over, the photo's import carries on rather than a
// second one starting.

import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart' as production;
import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/l10n/app_localizations_sv.dart';
import 'package:butlery/services/guest/guest_import_session.dart';
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/viewmodels/text_import_viewmodel.dart';
import 'package:butlery/views/fran_sociala_medier_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../infrastructure/di/test_service_locator.dart';
import '../../test_support/base_unit_test.dart';

final _sv = AppLocalizationsSv();

class _MockTextImportViewModel extends Mock implements TextImportViewModel {}

void main() {
  late GuestImportSession session;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await BaseUnitTest.setupUnit();
  });

  setUp(() async {
    await TestServiceLocator.initialize();
    production.ServiceLocator.initialize(DIContainer());
    SharedPreferences.setMockInitialValues(<String, Object>{});

    final vm = _MockTextImportViewModel();
    when(() => vm.canParse).thenReturn(false);
    when(() => vm.error).thenReturn(null);
    when(() => vm.hasError).thenReturn(false);
    when(() => vm.inputText).thenReturn('');
    when(() => vm.isParsing).thenReturn(false);
    when(() => vm.parsedRecipe).thenReturn(null);
    when(() => vm.sourceUrl).thenReturn(null);
    when(() => vm.updateInputText(any())).thenReturn(null);
    when(() => vm.setSourceUrl(any())).thenReturn(null);
    when(() => vm.parseText()).thenAnswer((_) async => false);
    TestServiceLocator.registerMock<TextImportViewModel>(vm);

    session = GuestImportSession(uid: () => 'uid-1');
    TestServiceLocator.registerMock<GuestImportSession>(session);
  });

  tearDown(() async {
    await TestServiceLocator.reset();
  });

  tearDownAll(() async {
    await BaseUnitTest.teardownUnit();
  });

  /// Builds the screen from route arguments, as the router does for the
  /// share handler and the photo import.
  Future<void> open(WidgetTester tester, Object? arguments) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('sv'),
        home: FranSocialaMedierView.fromRouteArguments(arguments),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shared text starts a new import', (tester) async {
    final before = session.currentId;

    await open(tester, 'https://exempel.se/recept/kladdkaka');

    expect(session.currentId, isNot(before));
  });

  testWidgets('the photo import handing over its text keeps its import', (
    tester,
  ) async {
    final photoImport = session.begin();

    await open(tester, {'text': '2 dl mjölk', 'ocrConfidence': 0.9});

    expect(session.currentId, photoImport);
  });

  testWidgets('the server limit opens the account sheet on it', (
    tester,
  ) async {
    await open(tester, null);

    await session.recordLimitReached();
    await tester.pumpAndSettle();

    expect(find.text(_sv.guestSheetImportLimitTitle), findsOneWidget);
  });
}
