// BUT-2183 5k: the data-export view leaves the old opacity steps. The success
// card is the mode's surface tint with no border and the matching on-colour;
// neutral info cards are the raised surface; borders are outlineVariant. Each
// test runs in both modes and asserts text and glyph colours as well as fills.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart' as production;
import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/services/account/data_export_service.dart';
import 'package:butlery/theme/app_mode_colors.dart';
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/viewmodels/account/data_export_viewmodel.dart';
import 'package:butlery/views/account/data_export_view.dart';

import '../../../infrastructure/di/test_service_locator.dart';
import '../../../views/helpers/view_test_helpers.dart';

class _MockExportService extends Mock implements DataExportService {}

late AppLocalizations _sv;

Future<void> _pumpApp(WidgetTester tester, ThemeData theme, Widget home) async {
  tester.view.physicalSize = const Size(420, 4000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  // The test font is wider than the production one, so rows of icon and text
  // overflow the viewport; these tests read colours, not layout.
  final originalHandler = FlutterError.onError;
  FlutterError.onError = (details) {
    if (details.exceptionAsString().contains('overflowed')) return;
    originalHandler?.call(details);
  };
  addTearDown(() => FlutterError.onError = originalHandler);
  await tester.pumpWidget(
    MaterialApp(
      theme: theme,
      locale: const Locale('sv', 'SE'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: home,
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

Future<void> _pumpExport(WidgetTester tester, ThemeData theme) async {
  final service = _MockExportService();
  when(service.exportUserData).thenAnswer((_) async => '{"a":1}');
  // The view hands the model to its own provider, which disposes it.
  final viewModel = DataExportViewModel(exportService: service);
  await viewModel.exportData();

  await _pumpApp(
    tester,
    theme,
    ChangeNotifierProvider<DataExportViewModel>.value(
      value: viewModel,
      child: const DataExportView(),
    ),
  );
}

T _above<T extends Widget>(
  WidgetTester tester,
  Finder of,
  bool Function(T) test,
) => tester.widget<T>(
  find
      .ancestor(
        of: of,
        matching: find.byWidgetPredicate((w) => w is T && test(w)),
      )
      .first,
);

Card _cardAbove(WidgetTester tester, Finder of) =>
    _above<Card>(tester, of, (_) => true);

Color? _textColor(WidgetTester tester, Finder text) =>
    tester.widget<Text>(text).style?.color;

void main() {
  setUpAll(() async {
    production.ServiceLocator.initialize(DIContainer());
    _sv = await AppLocalizations.delegate.load(const Locale('sv', 'SE'));
  });

  setUp(() async {
    await ViewTestHelpers.setupViewTestEnvironment();
  });

  tearDown(() async {
    await TestServiceLocator.reset();
    await ViewTestHelpers.teardownViewTestEnvironment();
  });

  for (final (mode, theme) in [
    ('light', AppTheme.lightTheme),
    ('dark', AppTheme.darkTheme),
  ]) {
    final cs = theme.colorScheme;

    group('data export view, $mode', () {
      testWidgets(
        'the finished file is on the page card with its edge, the warning '
        'line is warning text, and the size line stays secondary',
        (tester) async {
          await _pumpExport(tester, theme);

          final title = find.text(_sv.dataExportFileTitle);
          expect(title, findsOneWidget);
          final card = _cardAbove(tester, title);
          expect(
            card.color,
            isNull,
            reason: 'the surface comes from the theme',
          );
          expect(
            _textColor(tester, find.text(_sv.dataExportMemoryNotice)),
            AppModeColors.textWarning(theme.brightness),
          );
          expect(
            _textColor(tester, find.textContaining(' · ')),
            cs.onSurfaceVariant,
          );
        },
      );

      testWidgets('what comes with the file is plain rows, not a card', (
        tester,
      ) async {
        await _pumpExport(tester, theme);

        final title = find.text(_sv.dataExportWhatsIncluded.toUpperCase());
        await tester.ensureVisible(title);
        expect(title, findsOneWidget);
        expect(find.text(_sv.dataExportIncludesProfile), findsOneWidget);
        expect(
          find.ancestor(of: title, matching: find.byType(Card)),
          findsNothing,
        );
      });
    });
  }
}
