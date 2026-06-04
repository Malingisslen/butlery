/// BUT-1204 widget gates for the URL-import and text-import draft persistence —
/// the view-glue the BUT-904 AutoSaveManager migration left untested. The
/// manager + its codec are unit-proven; these prove the wiring: restore the
/// persisted draft into the field on mount, and persist on keystroke under the
/// byte-identical key. Same family as BUT-1207 (group dialog).
///
/// Asserts data/persistence behaviour (field text + prefs values), not visual
/// appearance, so it needs no human visual verification.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart' as production;
import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/viewmodels/text_import_viewmodel.dart';
import 'package:butlery/views/fran_sociala_medier_view.dart';
import 'package:butlery/views/import_via_url_view.dart';

import '../../infrastructure/di/test_service_locator.dart';
import '../../test_support/base_unit_test.dart';

class _MockTextImportViewModel extends Mock implements TextImportViewModel {}

const _kUrlKey = 'url_import_draft_v1';
const _kTextKey = 'text_import_draft_v1';

Widget _wrap(Widget child) => MaterialApp(
      theme: AppTheme.lightTheme,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('sv'),
      home: child,
    );

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await BaseUnitTest.setupUnit();
  });

  setUp(() async {
    // TestServiceLocator already registers a mock UrlImportViewModel via
    // MockFactory; the text VM is registered per-test below.
    await TestServiceLocator.initialize();
    production.ServiceLocator.initialize(DIContainer());
  });

  tearDown(() async {
    await TestServiceLocator.reset();
  });

  tearDownAll(() async {
    await BaseUnitTest.teardownUnit();
  });

  group('URL import draft', () {
    testWidgets('restores the persisted URL into the field on mount',
        (tester) async {
      SharedPreferences.setMockInitialValues(
          {_kUrlKey: 'https://example.com/recipe'});

      await tester.pumpWidget(_wrap(const ImportViaUrlView()));
      await tester.pumpAndSettle();

      expect(find.text('https://example.com/recipe'), findsOneWidget,
          reason: 'a persisted url_import_draft_v1 must repopulate the field');
    });

    testWidgets('persists the URL under the byte-identical key on keystroke',
        (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});

      await tester.pumpWidget(_wrap(const ImportViaUrlView()));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, 'https://x.com/r');
      await tester.pumpAndSettle();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(_kUrlKey), 'https://x.com/r');
    });
  });

  group('Text import draft', () {
    late _MockTextImportViewModel mockVm;

    setUp(() {
      mockVm = _MockTextImportViewModel();
      when(() => mockVm.canParse).thenReturn(false);
      when(() => mockVm.error).thenReturn(null);
      when(() => mockVm.hasError).thenReturn(false);
      when(() => mockVm.inputText).thenReturn('');
      when(() => mockVm.isParsing).thenReturn(false);
      when(() => mockVm.parsedRecipe).thenReturn(null);
      when(() => mockVm.sourceUrl).thenReturn(null);
      when(() => mockVm.updateInputText(any())).thenReturn(null);
      when(() => mockVm.setSourceUrl(any())).thenReturn(null);
      TestServiceLocator.registerMock<TextImportViewModel>(mockVm);
    });

    testWidgets('restores the persisted text into the field on mount',
        (tester) async {
      SharedPreferences.setMockInitialValues(
          {_kTextKey: 'Pannkakor\n3 ägg, 3 dl mjölk'});

      await tester.pumpWidget(_wrap(const FranSocialaMedierView()));
      await tester.pumpAndSettle();

      expect(find.text('Pannkakor\n3 ägg, 3 dl mjölk'), findsOneWidget,
          reason: 'a persisted text_import_draft_v1 must repopulate the field');
      verify(() => mockVm.updateInputText('Pannkakor\n3 ägg, 3 dl mjölk'))
          .called(1);
    });

    testWidgets('persists the text under the byte-identical key on keystroke',
        (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});

      await tester.pumpWidget(_wrap(const FranSocialaMedierView()));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, 'Smarriga bullar');
      await tester.pumpAndSettle();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(_kTextKey), 'Smarriga bullar');
    });
  });
}
