/// P5-COPY-DRAWN: the report dialog says "anmälan" throughout, as drawn in
/// Skarmar v12 etapp 9 #fbanmal (title "Anmäl det här receptet" at :507,
/// "Skicka anmälan" at :523). It confirms with "Anmälan har skickats"; a
/// failure is the three-part failure snackbar (content-style-guide.md:87-97)
/// that says what did not happen and offers Försök igen, which sends the
/// same report again.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart' as prod;
import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/l10n/app_localizations_sv.dart';
import 'package:butlery/models/social/content_type.dart';
import 'package:butlery/services/moderation/report_service.dart';
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/widgets/social/report_content_dialog.dart';

class _MockReportService extends Mock implements ReportService {}

void main() {
  final l10n = AppLocalizationsSv();
  late _MockReportService reports;

  setUpAll(() => registerFallbackValue(ContentType.recipe));

  setUp(() async {
    await GetIt.instance.reset();
    reports = _MockReportService();
    GetIt.instance.registerSingleton<ReportService>(reports);
    prod.ServiceLocator.initialize(DIContainer());
  });

  tearDown(() async {
    prod.ServiceLocator.reset();
    await GetIt.instance.reset();
  });

  void answer(Future<bool> Function() result) {
    when(
      () => reports.submitReport(
        contentType: any(named: 'contentType'),
        contentId: any(named: 'contentId'),
        reason: any(named: 'reason'),
        contentOwnerId: any(named: 'contentOwnerId'),
        description: any(named: 'description'),
      ),
    ).thenAnswer((_) => result());
  }

  int submitted() => verify(
    () => reports.submitReport(
      contentType: any(named: 'contentType'),
      contentId: any(named: 'contentId'),
      reason: any(named: 'reason'),
      contentOwnerId: any(named: 'contentOwnerId'),
      description: any(named: 'description'),
    ),
  ).callCount;

  Future<void> open(WidgetTester tester, ContentType type) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        locale: const Locale('sv'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => ReportContentDialog.show(
                context: context,
                contentType: type,
                contentId: 'c-1',
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  Future<void> send(WidgetTester tester) async {
    await tester.tap(find.text(l10n.reportReasonSpam));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('reportContent.submit')));
    await tester.pumpAndSettle();
  }

  testWidgets('a recipe is reported with the drawn title', (tester) async {
    await open(tester, ContentType.recipe);

    expect(find.text('Anmäl det här receptet'), findsOneWidget);
    expect(find.text('Skicka anmälan'), findsOneWidget);
    expect(find.textContaining('rapport'), findsNothing);
    expect(find.textContaining('Rapport'), findsNothing);
  });

  testWidgets('the intro and the guidelines note read as drawn', (
    tester,
  ) async {
    await open(tester, ContentType.recipe);

    // #fbanmal:508 and :518.
    expect(
      find.text(
        'Berätta vad som är fel. En människa i teamet läser din anmälan.',
      ),
      findsOneWidget,
    );
    expect(
      find.textContaining('Vi bedömer mot', findRichText: true),
      findsOneWidget,
    );
    expect(
      find.textContaining(
        '— den version du ser nu är den vi dömer efter.',
        findRichText: true,
      ),
      findsOneWidget,
    );
    expect(find.text('våra riktlinjer'), findsOneWidget);
    expect(find.textContaining('bekräftar', findRichText: true), findsNothing);
  });

  testWidgets('Annat says the description is required', (tester) async {
    await open(tester, ContentType.recipe);
    expect(find.text('Krävs när du väljer Annat.'), findsNothing);

    await tester.tap(find.text(l10n.reportReasonOther));
    await tester.pumpAndSettle();

    // #fbanmal:516, produktregler.md:938.
    expect(find.text('Krävs när du väljer Annat.'), findsOneWidget);
    expect(find.text('0/500'), findsOneWidget);
  });

  testWidgets('other content says Anmäl innehåll', (tester) async {
    await open(tester, ContentType.comment);

    expect(find.text('Anmäl innehåll'), findsOneWidget);
    expect(find.text('Anmäl det här receptet'), findsNothing);
  });

  testWidgets('a sent report is confirmed as Anmälan har skickats', (
    tester,
  ) async {
    answer(() async => true);
    await open(tester, ContentType.recipe);
    await send(tester);

    expect(find.text('Anmälan har skickats'), findsOneWidget);
    expect(submitted(), 1);
  });

  for (final (name, result) in <(String, Future<bool> Function())>[
    ('the service says no', () async => false),
    ('the service throws', () async => throw Exception('offline')),
  ]) {
    testWidgets('a failed report says what happened and retries ($name)', (
      tester,
    ) async {
      answer(result);
      await open(tester, ContentType.recipe);
      await send(tester);

      expect(find.text('Anmälan kunde inte skickas'), findsOneWidget);
      expect(find.text('OK'), findsNothing);
      expect(submitted(), 1);

      // Försök igen sends the same report again.
      answer(() async => true);
      await tester.tap(find.text(l10n.commonRetry));
      await tester.pumpAndSettle();

      expect(submitted(), 1);
      expect(find.text('Anmälan har skickats'), findsOneWidget);
    });
  }
}
