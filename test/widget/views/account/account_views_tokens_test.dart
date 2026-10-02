// BUT-2183 5k: the consent and data-export views leave the old opacity steps.
// Notice boxes (the consent error, the export success) are the mode's surface
// tint with no border and the matching on-colour; neutral info boxes are the
// raised surface (surface.base inside an already raised card); a selected
// consent card is a 1.5 px onSurface border; borders are outlineVariant. Each
// test runs in both modes and asserts text and glyph colours as well as fills.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart' as production;
import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/models/account/user_consent.dart';
import 'package:butlery/services/account/data_export_service.dart';
import 'package:butlery/theme/app_mode_colors.dart';
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/viewmodels/account/consent_viewmodel.dart';
import 'package:butlery/viewmodels/account/data_export_viewmodel.dart';
import 'package:butlery/views/account/consent_management_view.dart';
import 'package:butlery/views/account/data_export_view.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';

import '../../../infrastructure/di/test_service_locator.dart';
import '../../../infrastructure/mocks/production_mocks.dart';
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

Future<ConsentViewModel> _pumpConsent(
  WidgetTester tester,
  ThemeData theme, {
  bool withError = false,
}) async {
  final service = MockConsentService();
  when(service.getUserConsent).thenAnswer(
    (_) async => UserConsent(
      userId: 'u1',
      purposes: const ConsentPurposes(
        essentialServices: true,
        dataProcessing: true,
        analytics: true,
      ),
      grantedAt: DateTime(2026, 1, 1),
      consentVersion: '1.1.0',
      deviceInfo: 'test',
    ),
  );
  when(service.needsConsentRenewal).thenAnswer((_) async => false);
  final viewModel = ConsentViewModel(consentService: service);
  addTearDown(viewModel.dispose);

  await _pumpApp(
    tester,
    theme,
    ChangeNotifierProvider<ConsentViewModel>.value(
      value: viewModel,
      child: const ConsentManagementView(),
    ),
  );
  await tester.pump(const Duration(milliseconds: 50));
  if (withError) {
    // A reload that fails leaves the loaded consent standing and raises the
    // error message above the action button.
    when(service.getUserConsent).thenThrow(Exception('boom'));
    await viewModel.loadConsent();
    await tester.pump();
  }
  return viewModel;
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

BoxDecoration _boxAbove(WidgetTester tester, Finder of) =>
    _above<Container>(
          tester,
          of,
          (c) => c.decoration is BoxDecoration,
        ).decoration!
        as BoxDecoration;

Card _cardAbove(WidgetTester tester, Finder of) =>
    _above<Card>(tester, of, (_) => true);

BorderSide _cardSide(Card card) => (card.shape! as RoundedRectangleBorder).side;

Color? _textColor(WidgetTester tester, Finder text) =>
    tester.widget<Text>(text).style?.color;

Color? _glyphColor(WidgetTester tester, IconData icon) =>
    tester.widget<Icon>(find.byIcon(icon).first).color;

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
    final modeColors = ModeColors.of(theme.brightness);

    group('consent view, $mode', () {
      testWidgets(
        'the last-updated box is surface.base with no border and secondary '
        'text',
        (tester) async {
          await _pumpConsent(tester, theme);

          final label = find.textContaining('${_sv.consentLastUpdated}:');
          expect(label, findsOneWidget);
          final d = _boxAbove(tester, label);
          expect(d.color, cs.surface);
          expect(d.border, isNull);
          expect(_textColor(tester, label), cs.onSurfaceVariant);
        },
      );

      testWidgets(
        'a selected consent card has a 1.5 px onSurface border and a '
        'surface.base glyph tile; an unselected one keeps 1 px outlineVariant',
        (tester) async {
          await _pumpConsent(tester, theme);

          final selected = find.text(_sv.consentAnalytics);
          expect(selected, findsOneWidget);
          final selectedSide = _cardSide(_cardAbove(tester, selected));
          expect(selectedSide.color, cs.onSurface);
          expect(selectedSide.width, 1.5);
          final selectedTile = _above<Container>(
            tester,
            find.byIcon(Icons.analytics_rounded),
            (c) => c.decoration is BoxDecoration,
          );
          expect((selectedTile.decoration! as BoxDecoration).color, cs.surface);
          expect(_glyphColor(tester, Icons.analytics_rounded), cs.onSurface);

          final unselected = find.text(_sv.consentPushNotifications);
          final unselectedSide = _cardSide(_cardAbove(tester, unselected));
          expect(unselectedSide.color, cs.outlineVariant);
          expect(unselectedSide.width, 1);
          final unselectedTile = _above<Container>(
            tester,
            find.byIcon(Icons.notifications_rounded),
            (c) => c.decoration is BoxDecoration,
          );
          expect(
            (unselectedTile.decoration! as BoxDecoration).color,
            cs.surfaceContainerLow,
          );
        },
      );

      testWidgets(
        'the error message is the danger tint with no border; glyph and text '
        'are onErrorContainer',
        (tester) async {
          final viewModel = await _pumpConsent(tester, theme, withError: true);

          final label = find.text(viewModel.errorMessage!);
          expect(label, findsOneWidget);
          final d = _boxAbove(tester, label);
          expect(d.color, modeColors.surfaceTintDanger);
          expect(d.border, isNull);
          expect(_textColor(tester, label), cs.onErrorContainer);
          final glyph = find.descendant(
            of: find.ancestor(
              of: label,
              matching: find.byWidgetPredicate(
                (w) => w is Container && w.decoration == d,
              ),
            ),
            matching: find.byIcon(ButleryIcons.triangleAlert),
          );
          expect(tester.widget<Icon>(glyph).color, cs.onErrorContainer);
        },
      );

      testWidgets('the good-to-know card is the raised surface', (
        tester,
      ) async {
        await _pumpConsent(tester, theme);

        final title = find.text(_sv.consentGoodToKnow);
        await tester.ensureVisible(title);
        expect(
          _cardAbove(tester, title).color,
          cs.surfaceContainerHighest,
        );
      });
    });

    group('data export view, $mode', () {
      testWidgets(
        'the success card is the success tint with no border; glyph is '
        'onSuccessContainer and the secondary lines stay secondary',
        (tester) async {
          await _pumpExport(tester, theme);

          final title = find.text(_sv.dataExportSuccess);
          expect(title, findsOneWidget);
          final card = _cardAbove(tester, title);
          expect(card.color, modeColors.surfaceTintSuccess);
          expect(_cardSide(card), BorderSide.none);
          expect(
            _glyphColor(tester, ButleryIcons.circleCheck),
            modeColors.onSuccessContainer,
          );
          expect(
            _textColor(tester, find.textContaining(_sv.dataExportFileSize)),
            AppModeColors.textSecondaryOnRaised(theme.brightness),
          );
        },
      );

      testWidgets('the what-is-included card is the raised surface', (
        tester,
      ) async {
        await _pumpExport(tester, theme);

        final title = find.text(_sv.dataExportWhatsIncluded);
        await tester.ensureVisible(title);
        expect(
          _cardAbove(tester, title).color,
          cs.surfaceContainerHighest,
        );
      });
    });
  }
}
