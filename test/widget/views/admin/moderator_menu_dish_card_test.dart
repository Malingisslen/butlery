// BUT-2339: a menu_dish report on the moderator card names the dish, says the
// sharer did not necessarily write it, and removes only that dish.
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart' as prod;
import 'package:butlery/l10n/app_localizations_sv.dart';
import 'package:butlery/models/social/content_report.dart';
import 'package:butlery/models/social/content_type.dart';
import 'package:butlery/models/social/report_evidence.dart';
import 'package:butlery/services/moderation/report_service.dart';
import 'package:butlery/views/admin/moderator_review_view.dart';

import '../../../infrastructure/helpers/widget_test_app.dart';

class _MockReportService extends Mock implements ReportService {}

class _FakeContentReport extends Fake implements ContentReport {}

void main() {
  final sv = AppLocalizationsSv();
  late _MockReportService reports;
  late StreamController<List<ContentReport>> stream;

  ContentReport report(ContentType type) => ContentReport(
    id: 'r1',
    reporterId: 'reporter',
    contentType: type,
    contentId: 'menu-1',
    contentOwnerId: 'sharer',
    reason: 'misattribution',
    createdAt: DateTime(2026, 10, 10),
    dishId: type == ContentType.menuDish ? 'dish-1' : null,
  );

  setUpAll(() => registerFallbackValue(_FakeContentReport()));

  setUp(() async {
    await GetIt.instance.reset();
    reports = _MockReportService();
    stream = StreamController<List<ContentReport>>.broadcast();
    when(() => reports.watchIsAdmin()).thenAnswer((_) => Stream.value(true));
    when(() => reports.watchOpenReports()).thenAnswer((_) => stream.stream);
    when(() => reports.isMinorAccount(any())).thenAnswer((_) async => false);
    GetIt.instance.registerSingleton<ReportService>(reports);
    prod.ServiceLocator.initialize(DIContainer());
  });

  tearDown(() async {
    await stream.close();
    prod.ServiceLocator.reset();
    await GetIt.instance.reset();
  });

  Future<void> pump(
    WidgetTester tester,
    ContentReport r, {
    bool? claimed,
  }) async {
    when(() => reports.getReportEvidence('r1')).thenAnswer(
      (_) async => (
        evidence: ReportEvidence(
          reportId: 'r1',
          outcome: EvidenceOutcome.captured,
          claimedCreatorIsReporter: claimed,
        ),
      ),
    );
    await tester.pumpWidget(
      createLocalizedTestApp(
        wrapInScaffold: false,
        child: const ModeratorReviewView(),
      ),
    );
    await tester.pump();
    stream.add([r]);
    await tester.pump();
    await tester.pump();
  }

  testWidgets('a menu dish report shows its label, the sharer note and the '
      'dish takedown button', (tester) async {
    await pump(tester, report(ContentType.menuDish));

    expect(
      find.textContaining(sv.moderatorContentTypeMenuDish),
      findsOneWidget,
    );
    expect(find.text('Rätt i delad meny · menu-1'), findsOneWidget);
    expect(find.text(sv.moderatorMenuDishSharerNote), findsOneWidget);
    expect(find.text('Ta bort rätten ur menyn'), findsOneWidget);
    expect(find.text(sv.moderatorActionDelete), findsNothing);
    expect(find.text(sv.moderatorMenuDishClaimedReporter), findsNothing);
    expect(find.text(sv.moderatorMenuDishNotClaimedReporter), findsNothing);
  });

  for (final (claimed, text) in [
    (true, 'Rätten angav anmälaren som skapare när anmälan kom in.'),
    (false, 'Rätten angav inte anmälaren som skapare när anmälan kom in.'),
  ]) {
    testWidgets('evidence claimedCreatorIsReporter=$claimed is stated', (
      tester,
    ) async {
      await pump(tester, report(ContentType.menuDish), claimed: claimed);

      expect(find.text(text), findsOneWidget);
    });
  }

  testWidgets('confirming removes the dish and the dialog says only that dish '
      'goes', (tester) async {
    when(
      () => reports.deleteReportedContent(any()),
    ).thenAnswer((_) async => true);
    await pump(tester, report(ContentType.menuDish));

    await tester.tap(find.text('Ta bort rätten ur menyn'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining(
        sv.moderatorRemoveDishConfirmBody,
        findRichText: true,
      ),
      findsOneWidget,
    );
    expect(
      find.textContaining(sv.moderatorDeleteConfirmBody, findRichText: true),
      findsNothing,
    );
    expect(find.text('Ta bort rätten ur menyn?'), findsOneWidget);

    await tester.tap(find.text('Ta bort rätten ur menyn').last);
    await tester.pumpAndSettle();

    final sent =
        verify(
              () => reports.deleteReportedContent(captureAny()),
            ).captured.single
            as ContentReport;
    expect(sent.contentType, ContentType.menuDish);
    expect(sent.dishId, 'dish-1');
  });

  testWidgets('another content type gets neither the dish note nor the dish '
      'button', (tester) async {
    await pump(tester, report(ContentType.comment));

    expect(find.text(sv.moderatorMenuDishSharerNote), findsNothing);
    expect(find.text('Ta bort rätten ur menyn'), findsNothing);
    expect(find.text(sv.moderatorActionDelete), findsOneWidget);
  });
}
