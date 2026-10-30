/// Pins behaviours of the text-import view that a move onto shared
/// components must not change: the "does not look like a recipe" confirm
/// only lets the import through on the primary choice, the paste field
/// stops at 10000 characters, and a pasted link imports the way Smart import
/// does.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:butlery/core/constants/routes.dart';
import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/router/shared_import_route.dart';
import 'package:butlery/core/providers/application_provider.dart' as production;
import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/viewmodels/text_import_viewmodel.dart';
import 'package:butlery/views/fran_sociala_medier_view.dart';

import '../../infrastructure/di/test_service_locator.dart';
import '../../test_support/base_unit_test.dart';

class _MockTextImportViewModel extends Mock implements TextImportViewModel {}

const _kTextKey = 'text_import_draft_v1';
const _notARecipe = 'hej';

Widget _wrap(Widget child) => MaterialApp(
  theme: AppTheme.lightTheme,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  locale: const Locale('sv'),
  home: child,
);

void main() {
  late _MockTextImportViewModel mockVm;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await BaseUnitTest.setupUnit();
  });

  setUp(() async {
    await TestServiceLocator.initialize();
    production.ServiceLocator.initialize(DIContainer());
    SharedPreferences.setMockInitialValues(<String, Object>{});
    mockVm = _MockTextImportViewModel();
    when(() => mockVm.canParse).thenReturn(true);
    when(() => mockVm.error).thenReturn(null);
    when(() => mockVm.hasError).thenReturn(false);
    when(() => mockVm.inputText).thenReturn(_notARecipe);
    when(() => mockVm.isParsing).thenReturn(false);
    when(() => mockVm.parsedRecipe).thenReturn(null);
    when(() => mockVm.sourceUrl).thenReturn(null);
    when(() => mockVm.hasMultipleParsedRecipes).thenReturn(false);
    when(() => mockVm.updateInputText(any())).thenReturn(null);
    when(() => mockVm.parseText()).thenAnswer((_) async => false);
    TestServiceLocator.registerMock<TextImportViewModel>(mockVm);
  });

  tearDown(() async {
    await TestServiceLocator.reset();
  });

  tearDownAll(() async {
    await BaseUnitTest.teardownUnit();
  });

  group('Non-recipe confirm', () {
    late AppLocalizations l10n;

    Future<void> openConfirm(WidgetTester tester) async {
      await tester.pumpWidget(_wrap(const FranSocialaMedierView()));
      await tester.pumpAndSettle();
      l10n = AppLocalizations.of(
        tester.element(find.byType(FranSocialaMedierView)),
      );
      await tester.tap(find.text(l10n.importFetchRecipe));
      await tester.pumpAndSettle();
      expect(find.text(l10n.importNotRecipeTitle), findsOneWidget);
    }

    testWidgets('Avbryt backs out without parsing', (tester) async {
      await openConfirm(tester);

      await tester.tap(find.text(l10n.commonCancel));
      await tester.pumpAndSettle();

      expect(find.text(l10n.importNotRecipeTitle), findsNothing);
      verifyNever(() => mockVm.parseText());
    });

    testWidgets('the primary choice imports anyway', (tester) async {
      await openConfirm(tester);

      await tester.tap(find.text(l10n.importNotRecipeConfirm));
      await tester.pumpAndSettle();

      verify(() => mockVm.parseText()).called(1);
    });
  });

  testWidgets('the paste field stops at 10000 characters', (tester) async {
    await tester.pumpWidget(_wrap(const FranSocialaMedierView()));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'a' * 10050);
    await tester.pumpAndSettle();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(_kTextKey)?.length, 10000);
  });

  testWidgets('a pasted social link goes to Smart import, not the text '
      'parser', (tester) async {
    const link = 'https://www.tiktok.com/@kock/video/7300000000000000000';
    when(() => mockVm.inputText).thenReturn(link);
    Object? pushedArgs;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('sv'),
        home: const FranSocialaMedierView(),
        onGenerateRoute: (settings) {
          if (settings.name != Routes.smartImport) return null;
          pushedArgs = settings.arguments;
          return MaterialPageRoute<void>(builder: (_) => const SizedBox());
        },
      ),
    );
    await tester.pumpAndSettle();
    final l10n = AppLocalizations.of(
      tester.element(find.byType(FranSocialaMedierView)),
    );

    await tester.tap(find.text(l10n.importFetchRecipe));
    await tester.pumpAndSettle();

    verifyNever(() => mockVm.parseText());
    expect((pushedArgs as SmartImportRouteArgs?)?.url, link);
  });

  testWidgets(
    'a shared recipe text keeps the link it came with as its source',
    (tester) async {
      const text = 'Pannkakor\n3 dl mjöl\n6 dl mjölk\nVispa och stek.';
      const link = 'https://www.ica.se/recept/pannkakor-1/';
      when(
        () => mockVm.updateTextAndSource(
          any(),
          sourceUrl: any(named: 'sourceUrl'),
        ),
      ).thenReturn(null);

      await tester.pumpWidget(
        _wrap(
          FranSocialaMedierView.fromRouteArguments(
            const SharedTextImportArgs(text, sourceUrl: link),
          ),
        ),
      );
      await tester.pumpAndSettle();

      verify(() => mockVm.updateTextAndSource(text, sourceUrl: link)).called(1);
      verify(() => mockVm.parseText()).called(1);
    },
  );
}
