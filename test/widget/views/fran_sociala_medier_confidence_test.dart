/// BUT-928: the OCR confidence badge survives the photo→text-import handoff.
///
/// The photo-import preview step shows a green/orange/red ConfidenceIndicator;
/// before this change the signal was dropped the moment the user continued to
/// FranSocialaMedierView. These gates pin the re-surfaced badge: shown when
/// the route delivers an `ocrConfidence`, absent for plain text entry.
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
import 'package:butlery/widgets/import/confidence_indicator.dart';

import '../../infrastructure/di/test_service_locator.dart';
import '../../test_support/base_unit_test.dart';

class _MockTextImportViewModel extends Mock implements TextImportViewModel {}

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
    await TestServiceLocator.initialize();
    production.ServiceLocator.initialize(DIContainer());
    SharedPreferences.setMockInitialValues(<String, Object>{});

    final mockVm = _MockTextImportViewModel();
    when(() => mockVm.canParse).thenReturn(false);
    when(() => mockVm.error).thenReturn(null);
    when(() => mockVm.hasError).thenReturn(false);
    when(() => mockVm.inputText).thenReturn('');
    when(() => mockVm.isParsing).thenReturn(false);
    when(() => mockVm.parsedRecipe).thenReturn(null);
    when(() => mockVm.sourceUrl).thenReturn(null);
    when(() => mockVm.updateInputText(any())).thenReturn(null);
    when(() => mockVm.setSourceUrl(any())).thenReturn(null);
    when(() => mockVm.parseText()).thenAnswer((_) async => false);
    TestServiceLocator.registerMock<TextImportViewModel>(mockVm);
  });

  tearDown(() async {
    await TestServiceLocator.reset();
  });

  tearDownAll(() async {
    await BaseUnitTest.teardownUnit();
  });

  testWidgets('shows the OCR confidence badge when handed off from photo OCR', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        const FranSocialaMedierView(
          initialText: '2 dl mjölk\n1 msk smör',
          ocrConfidence: 0.85,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byType(ConfidenceIndicator),
      findsOneWidget,
      reason:
          'The badge the user saw on the OCR preview step must '
          're-surface here — losing it was the BUT-928 finding.',
    );
    expect(
      find.text('85%'),
      findsOneWidget,
      reason: 'Same overall confidence value as the preview step.',
    );
  });

  testWidgets('shows no badge for plain text entry (no OCR source)', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(const FranSocialaMedierView()));
    await tester.pumpAndSettle();

    expect(
      find.byType(ConfidenceIndicator),
      findsNothing,
      reason:
          'Confidence describes an OCR pass — pasted text has none, '
          'so showing a badge would be fabricated signal.',
    );
  });

  // P4-T6: the tips heading is text.primary (onSurface), paper on the dark
  // page; cs.primary is ink in both schemes (tokens.json:54-57, :112-115).
  testWidgets('dark mode: the tips heading and its glyph are paper', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('sv'),
        home: const FranSocialaMedierView(),
      ),
    );
    await tester.pumpAndSettle();

    final paper = AppTheme.darkTheme.colorScheme.onSurface;
    final heading = tester.widget<Text>(find.text('Tips för bästa resultat'));
    expect(heading.style?.color, paper);
    final glyph = tester.widget<Icon>(
      find
          .descendant(
            of: find.ancestor(
              of: find.text('Tips för bästa resultat'),
              matching: find.byType(Row),
            ),
            matching: find.byIcon(Icons.info_outline),
          )
          .first,
    );
    expect(glyph.color, paper);
  });
}
