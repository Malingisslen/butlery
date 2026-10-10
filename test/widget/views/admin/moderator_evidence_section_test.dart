// The saved text copy (BUT-1842) on a moderation report card says, in
// Swedish, what was kept or why nothing was.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart' as prod;
import 'package:butlery/core/utils/contextual_time_formatter.dart';
import 'package:butlery/l10n/app_localizations_sv.dart';
import 'package:butlery/models/social/content_report.dart';
import 'package:butlery/models/social/content_type.dart';
import 'package:butlery/models/social/report_evidence.dart';
import 'package:butlery/services/moderation/report_service.dart';
import 'package:butlery/views/admin/moderator_review_view.dart';

import '../../../infrastructure/helpers/widget_test_app.dart';

class _MockReportService extends Mock implements ReportService {}

void main() {
  final sv = AppLocalizationsSv();
  late _MockReportService reports;
  late StreamController<List<ContentReport>> stream;

  final report = ContentReport(
    id: 'r1',
    reporterId: 'reporter',
    contentType: ContentType.recipe,
    contentId: 'c1',
    contentOwnerId: 'owner',
    reason: 'spam',
    createdAt: DateTime(2026, 4, 26),
  );

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

  Future<void> pumpWith(
    WidgetTester tester,
    ({ReportEvidence? evidence})? result,
  ) async {
    when(
      () => reports.getReportEvidence('r1'),
    ).thenAnswer((_) async => result);
    await tester.pumpWidget(
      createLocalizedTestApp(
        wrapInScaffold: false,
        child: const ModeratorReviewView(),
      ),
    );
    await tester.pump();
    stream.add([report]);
    await tester.pump();
    await tester.pump();
  }

  ({ReportEvidence? evidence}) outcome(
    EvidenceOutcome o, {
    bool truncated = false,
    List<(String, String)> text = const [],
  }) => (
    evidence: ReportEvidence(
      reportId: 'r1',
      outcome: o,
      truncated: truncated,
      text: text,
    ),
  );

  testWidgets('captured shows the saved fields and the text-only note', (
    tester,
  ) async {
    await pumpWith(
      tester,
      outcome(
        EvidenceOutcome.captured,
        text: [('title', 'Pannkakor'), ('description', 'Goda')],
      ),
    );

    expect(find.text(sv.moderatorEvidenceHeading), findsOneWidget);
    expect(find.byKey(const ValueKey('evidence-title')), findsOneWidget);
    expect(find.text('Pannkakor'), findsOneWidget);
    expect(find.text('Goda'), findsOneWidget);
    expect(find.text(sv.moderatorEvidenceTextOnly), findsOneWidget);
    expect(find.text(sv.moderatorEvidenceTruncated), findsNothing);
    expect(find.text(sv.moderatorEvidenceNone), findsNothing);
  });

  testWidgets('a capture time puts the date in the heading', (tester) async {
    final capturedAt = DateTime(2026, 10, 9, 14, 30);
    await pumpWith(tester, (
      evidence: ReportEvidence(
        reportId: 'r1',
        outcome: EvidenceOutcome.captured,
        truncated: false,
        text: const [('title', 'Pannkakor')],
        capturedAt: capturedAt,
      ),
    ));

    final stamp = ContextualTimeFormatter.dateTime(
      capturedAt,
      localeName: sv.localeName,
    );
    expect(find.text(sv.moderatorEvidenceHeadingAt(stamp)), findsOneWidget);
    expect(find.text(sv.moderatorEvidenceHeading), findsNothing);
  });

  testWidgets('truncated says the text is shortened', (tester) async {
    await pumpWith(
      tester,
      outcome(
        EvidenceOutcome.captured,
        truncated: true,
        text: [('title', 'Lång')],
      ),
    );

    expect(find.text('Texten är förkortad'), findsOneWidget);
    expect(find.text(sv.moderatorEvidenceTruncated), findsOneWidget);
    expect(find.text('Bara text sparas, inte bilder'), findsOneWidget);
  });

  testWidgets('none says no copy was saved', (tester) async {
    await pumpWith(tester, (evidence: null));

    expect(find.text('Ingen kopia sparad'), findsOneWidget);
    expect(find.text(sv.moderatorEvidenceHeading), findsNothing);
  });

  final reasons = <String, (EvidenceOutcome, String)>{
    'missing': (EvidenceOutcome.missing, sv.moderatorEvidenceMissing),
    'not_visible_to_reporter': (
      EvidenceOutcome.notVisibleToReporter,
      sv.moderatorEvidenceNotVisible,
    ),
    'owner_mismatch': (
      EvidenceOutcome.ownerMismatch,
      sv.moderatorEvidenceOwnerMismatch,
    ),
    'unsupported_type': (
      EvidenceOutcome.unsupportedType,
      sv.moderatorEvidenceUnsupported,
    ),
    'capture_failed': (
      EvidenceOutcome.captureFailed,
      sv.moderatorEvidenceFailed,
    ),
    'an unknown wire outcome': (
      EvidenceOutcome.unknown,
      'Kopian kunde inte sparas',
    ),
  };
  for (final entry in reasons.entries) {
    testWidgets('${entry.key} shows its reason and no captured text', (
      tester,
    ) async {
      await pumpWith(
        tester,
        outcome(entry.value.$1, text: [('title', 'Dold')]),
      );

      expect(find.text(entry.value.$2), findsOneWidget);
      expect(find.text(sv.moderatorEvidenceTextOnly), findsNothing);
      expect(find.byKey(const ValueKey('evidence-title')), findsNothing);
    });
  }
}
