// The saved text copy (BUT-1842) on a moderation report card says, in
// Swedish, what was kept or why nothing was.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:intl/intl.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart' as prod;
import 'package:butlery/core/utils/contextual_time_formatter.dart';
import 'package:butlery/l10n/app_localizations_sv.dart';
import 'package:butlery/models/social/content_report.dart';
import 'package:butlery/models/social/content_type.dart';
import 'package:butlery/models/social/report_evidence.dart';
import 'package:butlery/services/moderation/moderation_appeals_service.dart';
import 'package:butlery/services/moderation/report_service.dart';
import 'package:butlery/viewmodels/admin/moderator_review_viewmodel.dart';
import 'package:butlery/views/admin/moderator_evidence_section.dart';
import 'package:butlery/views/admin/moderator_review_view.dart';

import '../../../infrastructure/helpers/widget_test_app.dart';

class _MockReportService extends Mock implements ReportService {}

class _MockAppealsService extends Mock implements ModerationAppealsService {}

void main() {
  final sv = AppLocalizationsSv();
  late _MockReportService reports;
  late _MockAppealsService appeals;
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

  setUpAll(() => registerFallbackValue(FreezeAction.freeze));

  setUp(() async {
    await GetIt.instance.reset();
    reports = _MockReportService();
    stream = StreamController<List<ContentReport>>.broadcast();
    when(() => reports.watchIsAdmin()).thenAnswer((_) => Stream.value(true));
    when(() => reports.watchOpenReports()).thenAnswer((_) => stream.stream);
    when(
      () => reports.watchFrozenEvidence(),
    ).thenAnswer((_) => const Stream<List<ReportEvidence>>.empty());
    when(() => reports.isMinorAccount(any())).thenAnswer((_) async => false);
    GetIt.instance.registerSingleton<ReportService>(reports);
    appeals = _MockAppealsService();
    when(
      () => reports.forgetReportEvidence(any(), round: any(named: 'round')),
    ).thenReturn(null);
    when(() => appeals.listOpenAppeals()).thenAnswer((_) async => []);
    GetIt.instance.registerSingleton<ModerationAppealsService>(appeals);
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
      () => reports.getReportEvidence('r1', round: any(named: 'round')),
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

  group('reopened case', () {
    Future<void> pumpSection(WidgetTester tester, ReportEvidence e) =>
        tester.pumpWidget(
          createLocalizedTestApp(
            child: ModeratorEvidenceSection(
              state: ReportEvidenceLoaded(e),
              reopened: true,
            ),
          ),
        );

    testWidgets('an unkept copy is headed as the content now', (tester) async {
      await pumpSection(
        tester,
        const ReportEvidence(reportId: 'r1', outcome: EvidenceOutcome.captured),
      );
      expect(find.text(sv.moderatorEvidenceNowHeading), findsOneWidget);
    });

    testWidgets('a kept copy keeps the saved-copy heading', (tester) async {
      await pumpSection(
        tester,
        ReportEvidence(
          reportId: 'r1',
          outcome: EvidenceOutcome.captured,
          frozen: FrozenEvidence(
            reason: FreezeReason.police,
            until: DateTime.utc(2027, 11, 12),
          ),
        ),
      );
      expect(find.text(sv.moderatorEvidenceHeading), findsOneWidget);
      expect(find.text(sv.moderatorEvidenceNowHeading), findsNothing);
    });
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

  group('kept longer (BUT-2329)', () {
    final until = DateTime(2027, 10, 9);

    ({ReportEvidence? evidence}) copy({FrozenEvidence? frozen}) => (
      evidence: ReportEvidence(
        reportId: 'r1',
        outcome: EvidenceOutcome.captured,
        text: const [('title', 'Pannkakor')],
        capturedAt: DateTime(2026, 10, 9, 14, 30),
        frozen: frozen,
      ),
    );

    testWidgets('a captured copy that is not kept offers the button', (
      tester,
    ) async {
      await pumpWith(tester, copy());

      expect(find.text(sv.moderatorKeepLonger), findsOneWidget);
      expect(find.byKey(const ValueKey('evidence-frozen-line')), findsNothing);
    });

    testWidgets('a copy that is not captured offers nothing to keep', (
      tester,
    ) async {
      await pumpWith(tester, outcome(EvidenceOutcome.missing));

      expect(find.text(sv.moderatorKeepLonger), findsNothing);
    });

    testWidgets('a kept copy shows the date and reason instead', (
      tester,
    ) async {
      await pumpWith(
        tester,
        copy(
          frozen: FrozenEvidence(reason: FreezeReason.threat, until: until),
        ),
      );

      final date = DateFormat.yMMMd(sv.localeName).format(until);
      expect(
        find.text(
          sv.moderatorFrozenUntilLine(date, sv.moderatorFreezeReasonThreat),
        ),
        findsOneWidget,
      );
      expect(find.text(sv.moderatorKeepLonger), findsNothing);
    });

    testWidgets('the button opens the sheet and freezes with the reason', (
      tester,
    ) async {
      when(
        () => appeals.freezeEvidence(
          'r1',
          action: FreezeAction.freeze,
          reason: FreezeReason.police,
        ),
      ).thenAnswer((_) async => FreezeOutcome(until: until));
      await pumpWith(tester, copy());

      await tester.tap(find.text(sv.moderatorKeepLonger));
      await tester.pumpAndSettle();
      expect(find.text(sv.moderatorFreezeSheetHelp), findsOneWidget);

      await tester.tap(find.text(sv.moderatorFreezeReasonPolice));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('freeze-confirm')));
      await tester.pumpAndSettle();

      verify(
        () => appeals.freezeEvidence(
          'r1',
          action: FreezeAction.freeze,
          reason: FreezeReason.police,
        ),
      ).called(1);
      verify(
        () => reports.forgetReportEvidence('r1', round: any(named: 'round')),
      ).called(1);
    });
  });
}
