// The moderator card names what was reported and where the report stands, and
// offers the actions that fit: every content type and status has its own
// Swedish word, a profile is hidden rather than deleted, and a closed report
// has nothing left to advance or close.
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
import 'package:butlery/services/moderation/moderation_appeals_service.dart';
import 'package:butlery/services/moderation/report_service.dart';
import 'package:butlery/views/admin/moderator_review_view.dart';
import 'package:butlery/widgets/common/indicators/status_pill.dart';

import '../../../infrastructure/helpers/widget_test_app.dart';

class _MockReportService extends Mock implements ReportService {}

class _MockAppealsService extends Mock implements ModerationAppealsService {}

class _FakeContentReport extends Fake implements ContentReport {}

void main() {
  final sv = AppLocalizationsSv();
  late _MockReportService reports;
  late StreamController<List<ContentReport>> stream;

  ContentReport report(
    ContentType type, {
    ReportStatus status = ReportStatus.newReport,
  }) => ContentReport(
    id: 'r1',
    reporterId: 'reporter',
    contentType: type,
    contentId: 'menu-1',
    contentOwnerId: 'owner',
    reason: 'spam',
    createdAt: DateTime(2026, 10, 10),
    status: status,
  );

  String contentTypeLabel(ContentType type) => switch (type) {
    ContentType.recipe => sv.moderatorContentTypeRecipe,
    ContentType.comment => sv.moderatorContentTypeComment,
    ContentType.message => sv.moderatorContentTypeMessage,
    ContentType.profile => sv.moderatorContentTypeProfile,
    ContentType.cookSnap => sv.moderatorContentTypeCookSnap,
    ContentType.group => sv.moderatorContentTypeGroup,
    ContentType.menuDish => sv.moderatorContentTypeMenuDish,
  };

  String statusLabel(ReportStatus status) => switch (status) {
    ReportStatus.newReport => sv.moderatorStatusNew,
    ReportStatus.inReview => sv.moderatorStatusInReview,
    ReportStatus.actioned => sv.moderatorStatusActioned,
    ReportStatus.closed => sv.moderatorStatusClosed,
  };

  setUpAll(() => registerFallbackValue(_FakeContentReport()));

  setUp(() async {
    await GetIt.instance.reset();
    reports = _MockReportService();
    stream = StreamController<List<ContentReport>>.broadcast();
    when(() => reports.watchIsAdmin()).thenAnswer((_) => Stream.value(true));
    when(() => reports.watchOpenReports()).thenAnswer((_) => stream.stream);
    when(() => reports.isMinorAccount(any())).thenAnswer((_) async => false);
    when(
      () => reports.getReportEvidence(any(), round: any(named: 'round')),
    ).thenAnswer(
      (_) async => (
        evidence: ReportEvidence(
          reportId: 'r1',
          outcome: EvidenceOutcome.captured,
        ),
      ),
    );
    GetIt.instance.registerSingleton<ReportService>(reports);
    final appeals = _MockAppealsService();
    when(() => appeals.listOpenAppeals()).thenAnswer((_) async => []);
    GetIt.instance.registerSingleton<ModerationAppealsService>(appeals);
    prod.ServiceLocator.initialize(DIContainer());
  });

  tearDown(() async {
    await stream.close();
    prod.ServiceLocator.reset();
    await GetIt.instance.reset();
  });

  Future<void> pump(WidgetTester tester, ContentReport r) async {
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

  for (final type in ContentType.values) {
    testWidgets('a ${type.name} report is headed by its own Swedish label', (
      tester,
    ) async {
      await pump(tester, report(type));

      expect(
        find.text('${contentTypeLabel(type).toUpperCase()} · menu-1'),
        findsOneWidget,
      );
    });
  }

  for (final status in ReportStatus.values) {
    testWidgets('a ${status.name} report shows its own status pill', (
      tester,
    ) async {
      await pump(tester, report(ContentType.recipe, status: status));

      expect(
        find.descendant(
          of: find.byType(StatusPill),
          matching: find.text(statusLabel(status).toUpperCase()),
        ),
        findsOneWidget,
      );
    });
  }

  testWidgets('an open report offers advance, take-down and close', (
    tester,
  ) async {
    await pump(tester, report(ContentType.comment));

    expect(find.text(sv.moderatorActionAdvance), findsOneWidget);
    expect(find.text(sv.moderatorActionDelete), findsOneWidget);
    expect(find.byTooltip(sv.moderatorCloseTooltip), findsOneWidget);
  });

  testWidgets('a closed report can be taken down but not advanced or closed', (
    tester,
  ) async {
    await pump(
      tester,
      report(ContentType.comment, status: ReportStatus.closed),
    );

    expect(find.text(sv.moderatorActionAdvance), findsNothing);
    expect(find.byTooltip(sv.moderatorCloseTooltip), findsNothing);
    expect(find.text(sv.moderatorActionDelete), findsOneWidget);
  });

  testWidgets('a profile report is hidden, never deleted', (tester) async {
    await pump(tester, report(ContentType.profile));

    expect(find.text(sv.moderatorActionHide), findsOneWidget);
    expect(find.text(sv.moderatorActionDelete), findsNothing);
  });
}
