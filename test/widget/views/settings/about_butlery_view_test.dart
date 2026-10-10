// Settings → About Butlery → Licences, walked through the real AppRouter so the
// route constants, both router cases and the views are proven to meet. Neither
// route is auth-gated, which is what lets `generateRoute` run in a test host
// without Firebase.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/core/constants/routes.dart';
import 'package:butlery/core/router/app_router.dart';
import 'package:butlery/l10n/app_localizations_sv.dart';
import 'package:butlery/services/whats_new/whats_new_catalog.dart';
import 'package:butlery/views/settings/about_butlery_view.dart';
import 'package:butlery/views/settings/licenses_view.dart';

import '../../../infrastructure/helpers/widget_test_app.dart';

void main() {
  testWidgets('the about route opens AboutButleryView, whose Licences row '
      'opens LicensesView', (tester) async {
    final sv = AppLocalizationsSv();
    await tester.pumpWidget(
      createLocalizedTestApp(
        child: const SizedBox(),
        onGenerateRoute: AppRouter.generateRoute,
      ),
    );

    tester
        .state<NavigatorState>(find.byType(Navigator))
        .pushNamed(Routes.settingsAbout);
    await tester.pumpAndSettle();

    expect(find.byType(AboutButleryView), findsOneWidget);

    await tester.tap(find.text(sv.settingsLicensesTitle));
    await tester.pumpAndSettle();

    expect(find.byType(LicensesView), findsOneWidget);
    expect(find.text(sv.licensesOflHeading), findsOneWidget);
  });

  group('Nyheter row', () {
    final sv = AppLocalizationsSv();
    final catalog = [
      WhatsNewRelease(
        version: '1.2.0',
        items: [WhatsNewItem(title: (_) => 'Titel', body: (_) => 'Text')],
      ),
    ];

    Future<void> pumpAbout(WidgetTester tester, AboutButleryView view) => tester
        .pumpWidget(createLocalizedTestApp(child: view, wrapInScaffold: false));

    testWidgets('is hidden when the catalog is empty', (tester) async {
      await pumpAbout(
        tester,
        const AboutButleryView(currentVersion: '1.2.0', catalog: []),
      );

      expect(find.text(sv.whatsNewAboutTitle), findsNothing);
    });

    testWidgets('shows the latest release and opens the sheet', (tester) async {
      await pumpAbout(
        tester,
        AboutButleryView(catalog: catalog, currentVersion: '1.3.0'),
      );

      expect(find.text(sv.whatsNewAboutTitle), findsOneWidget);
      expect(find.text(sv.settingsAboutVersion('1.2.0')), findsOneWidget);

      await tester.tap(find.text(sv.whatsNewAboutTitle));
      await tester.pumpAndSettle();

      expect(find.text(sv.whatsNewTitle), findsOneWidget);
      expect(find.text('Titel'), findsOneWidget);
    });

    testWidgets('is hidden when every release is newer than the app', (
      tester,
    ) async {
      await pumpAbout(
        tester,
        AboutButleryView(catalog: catalog, currentVersion: '1.1.0'),
      );

      expect(find.text(sv.whatsNewAboutTitle), findsNothing);
    });
  });
}
