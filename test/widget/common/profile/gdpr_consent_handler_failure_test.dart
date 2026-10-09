// P7-B2: a GDPR link that cannot open says what did not open, as the
// failure snackbar (alert role, Stäng), never the exception's own text
// (content-style-guide.md:87-97, :95; tillganglighetshandoff.dc.html:172).

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/core/constants/routes.dart';
import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/l10n/app_localizations_sv.dart';
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/widgets/common/profile/handlers/gdpr_consent_handler.dart';

/// A home page that opens a sheet (the profile menu), and a privacy route
/// whose page throws while it is built, so the navigation itself fails.
Future<BuildContext> _pumpHome(WidgetTester tester) async {
  late BuildContext homeContext;
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.lightTheme,
      locale: const Locale('sv'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      onGenerateRoute: (settings) {
        if (settings.name == Routes.privacyPolicy) {
          throw StateError('Exception: route table broken');
        }
        return MaterialPageRoute<void>(
          builder: (context) {
            homeContext = context;
            return const Scaffold(body: Text('hem'));
          },
        );
      },
    ),
  );
  await tester.pumpAndSettle();
  // The profile menu the handler closes first.
  showModalBottomSheet<void>(
    context: homeContext,
    builder: (_) => const SizedBox(height: 100, child: Text('meny')),
  );
  await tester.pumpAndSettle();
  return homeContext;
}

void main() {
  final sv = AppLocalizationsSv();

  testWidgets('the privacy policy that cannot open: what, Stäng, alert, '
      'no exception text', (tester) async {
    final context = await _pumpHome(tester);

    await GdprConsentHandler.handlePrivacyPolicy(context);
    await tester.pumpAndSettle();

    expect(find.text(sv.profilePrivacyPolicyOpenFailed), findsOneWidget);
    expect(find.text(sv.commonClose), findsOneWidget);
    expect(find.textContaining('Exception'), findsNothing);
    expect(find.textContaining('route table'), findsNothing);
    expect(
      find.byWidgetPredicate(
        (w) => w is Semantics && w.properties.role == SemanticsRole.alert,
      ),
      findsOneWidget,
    );
  });

  testWidgets('consent management and data export say what did not open '
      '(their services are not registered here, so opening throws)', (
    tester,
  ) async {
    final context = await _pumpHome(tester);
    await GdprConsentHandler.handleManageConsent(context);
    await tester.pumpAndSettle();
    expect(find.text(sv.profileConsentManagementOpenFailed), findsOneWidget);
    expect(find.textContaining('Exception'), findsNothing);
    expect(find.textContaining('ConsentService'), findsNothing);

    await tester.tap(find.text(sv.commonClose));
    await tester.pumpAndSettle();

    showModalBottomSheet<void>(
      context: context,
      builder: (_) => const SizedBox(height: 100, child: Text('meny')),
    );
    await tester.pumpAndSettle();
    await GdprConsentHandler.handleExportData(context);
    await tester.pumpAndSettle();
    expect(find.text(sv.profileDataExportOpenFailed), findsOneWidget);
    expect(find.textContaining('Exception'), findsNothing);
    expect(find.textContaining('DataExportService'), findsNothing);
  });

  testWidgets('from a plain page (Inställningar) the export does not pop '
      'the page it was opened from (BUT-2302)', (tester) async {
    final context = await _pumpHome(tester);
    // Close the sheet _pumpHome opened: Inställningar has none.
    Navigator.pop(context);
    await tester.pumpAndSettle();

    await GdprConsentHandler.handleExportData(context, closeModal: false);
    await tester.pumpAndSettle();

    expect(find.text('hem'), findsOneWidget);
    expect(find.text(sv.profileDataExportOpenFailed), findsOneWidget);
  });
}
