// Settings → About Butlery → Licences, walked through the real AppRouter so the
// route constants, both router cases and the views are proven to meet. Neither
// route is auth-gated, which is what lets `generateRoute` run in a test host
// without Firebase.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/core/constants/routes.dart';
import 'package:butlery/core/router/app_router.dart';
import 'package:butlery/l10n/app_localizations_sv.dart';
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
}
