/// REC-08 — behaviour tests for [LaggTillReceptView], the "Lägg till recept"
/// hub. The view is a pure StatelessWidget with no ViewModel: it renders one
/// full-width quick-capture button plus a 2x2 import grid, and each tap pushes
/// a named route. We assert the user-visible Swedish labels are present and
/// that each button pushes the route the product contract promises — captured
/// via a NavigatorObserver so a wrong-route regression fails the test.
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/views/lagg_till_recept_view.dart';
import 'package:butlery/core/constants/routes.dart';
import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/theme/app_theme.dart';

/// Records the names of routes pushed/popped so a test can assert which route a
/// button navigated to without standing up the destination views.
class _RouteSpyObserver extends NavigatorObserver {
  final List<String?> pushedRouteNames = <String?>[];

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pushedRouteNames.add(route.settings.name);
    super.didPush(route, previousRoute);
  }
}

void main() {
  late _RouteSpyObserver routeSpy;

  setUp(() {
    routeSpy = _RouteSpyObserver();
  });

  // The four grid routes plus quickCapture all push named routes whose
  // destinations we don't want to build. onGenerateRoute returns an empty
  // page for any name so the push is observable but inert.
  Widget testApp() {
    return MaterialApp(
      locale: const Locale('sv'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: AppTheme.lightTheme,
      navigatorObservers: [routeSpy],
      home: const LaggTillReceptView(),
      onGenerateRoute: (settings) => MaterialPageRoute<void>(
        settings: settings,
        builder: (_) => const Scaffold(body: SizedBox.shrink()),
      ),
    );
  }

  // The 2x2 grid sizes itself off available height; a too-short surface makes
  // the grid clamp/overflow. Pump on a tall surface so all five buttons lay
  // out and remain tappable.
  Future<void> pumpView(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(testApp());
    await tester.pumpAndSettle();
  }

  // The view's first push after a tap is the only push we assert on — the spy
  // also records the destination's own settings, but the route under test is
  // always the most recent push triggered by the tap.
  String? lastPushed() => routeSpy.pushedRouteNames.last;

  testWidgets('renders all five entry-point labels in Swedish', (tester) async {
    // Proves: every import method the hub offers is visible to the user. If a
    // button were dropped or its label key swapped, one of these fails.
    await pumpView(tester);

    expect(find.text('Snabbspara recept'), findsOneWidget); // quickCaptureTitle
    expect(find.text('Importera länk'), findsOneWidget); // recipeImportLink
    expect(find.text('Skriv manuellt'), findsOneWidget); // recipeWriteManually
    expect(find.text('Från bild'), findsOneWidget); // recipeFromImage
    expect(find.text('Från arkiv'), findsOneWidget); // recipeFromArchive
  });

  testWidgets('quick-capture button pushes the quickCapture route',
      (tester) async {
    // Proves: the top full-width entry point routes to quick capture, the
    // lightweight name+meal-type save path.
    await pumpView(tester);

    await tester.tap(find.byKey(const ValueKey('test-lagg-till-quick-save')));
    await tester.pumpAndSettle();

    expect(lastPushed(), Routes.quickCapture);
  });

  testWidgets('import-link button pushes the smartImport route',
      (tester) async {
    // Proves: "Importera länk" routes to URL import.
    await pumpView(tester);

    await tester.tap(find.byKey(const ValueKey('test-lagg-till-import-url')));
    await tester.pumpAndSettle();

    expect(lastPushed(), Routes.smartImport);
  });

  testWidgets('write-manually button pushes the manualEntry route',
      (tester) async {
    // Proves: "Skriv manuellt" routes to the manual recipe editor.
    await pumpView(tester);

    await tester
        .tap(find.byKey(const ValueKey('test-lagg-till-write-manually')));
    await tester.pumpAndSettle();

    expect(lastPushed(), Routes.manualEntry);
  });

  testWidgets('photo-import button pushes the photoImport route',
      (tester) async {
    // Proves: "Från bild" routes to OCR photo import.
    await pumpView(tester);

    await tester.tap(find.byKey(const ValueKey('test-lagg-till-photo-import')));
    await tester.pumpAndSettle();

    expect(lastPushed(), Routes.photoImport);
  });

  testWidgets('archive-import button pushes the importFromArchive route',
      (tester) async {
    // Proves: "Från arkiv" routes to the archive import flow.
    await pumpView(tester);

    await tester
        .tap(find.byKey(const ValueKey('test-lagg-till-archive-import')));
    await tester.pumpAndSettle();

    expect(lastPushed(), Routes.importFromArchive);
  });
}
