/// BUT-2154: a report stores its reason as an id; the two screens that list
/// reports show the Swedish label for it, and a report saved before ids
/// existed shows its text as saved.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart' as prod;
import 'package:butlery/l10n/app_localizations_sv.dart';
import 'package:butlery/models/social/content_report.dart';
import 'package:butlery/models/social/content_type.dart';
import 'package:butlery/services/moderation/report_service.dart';
import 'package:butlery/viewmodels/settings/my_reports_viewmodel.dart';
import 'package:butlery/views/admin/moderator_review_view.dart';
import 'package:butlery/views/settings/my_reports_view.dart';

import '../../infrastructure/helpers/widget_test_app.dart';

class _MockReportService extends Mock implements ReportService {}

ContentReport _report(String id, String reason) => ContentReport(
  id: id,
  reporterId: 'reporter',
  contentType: ContentType.recipe,
  contentId: 'c-$id',
  contentOwnerId: 'owner',
  reason: reason,
  createdAt: DateTime(2026, 10, 9, 8),
);

void main() {
  final sv = AppLocalizationsSv();
  late _MockReportService reports;

  setUp(() async {
    await GetIt.instance.reset();
    reports = _MockReportService();
    GetIt.instance.registerSingleton<ReportService>(reports);
  });

  tearDown(() async {
    prod.ServiceLocator.reset();
    await GetIt.instance.reset();
  });

  testWidgets(
    'Mina anmälningar shows the label for an id and old text as saved',
    (
      tester,
    ) async {
      when(() => reports.getMyReports()).thenAnswer(
        (_) async => [_report('r1', 'abuse'), _report('r2', 'Gammalt skäl')],
      );
      GetIt.instance.registerFactory<MyReportsViewModel>(
        () => MyReportsViewModel(reportService: reports),
      );
      prod.ServiceLocator.initialize(DIContainer());

      await tester.pumpWidget(
        createLocalizedTestApp(
          wrapInScaffold: false,
          child: const MyReportsView(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(sv.reportReasonInappropriate), findsOneWidget);
      expect(find.text('Gammalt skäl'), findsOneWidget);
      expect(find.text('abuse'), findsNothing);
    },
  );

  testWidgets(
    'the moderator queue shows the label for an id and old text as saved',
    (
      tester,
    ) async {
      when(() => reports.watchIsAdmin()).thenAnswer((_) => Stream.value(true));
      when(() => reports.watchOpenReports()).thenAnswer(
        (_) => Stream.value([
          _report('r1', 'abuse'),
          _report('r2', 'Gammalt skäl'),
        ]),
      );
      when(() => reports.isMinorAccount(any())).thenAnswer((_) async => false);
      when(
        () => reports.getReportEvidence(any()),
      ).thenAnswer((_) async => (evidence: null));
      prod.ServiceLocator.initialize(DIContainer());

      await tester.pumpWidget(
        createLocalizedTestApp(
          wrapInScaffold: false,
          child: const ModeratorReviewView(),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text(
          '${sv.moderatorReasonLabel}: ${sv.reportReasonInappropriate}',
        ),
        findsOneWidget,
      );
      expect(
        find.text('${sv.moderatorReasonLabel}: Gammalt skäl'),
        findsOneWidget,
      );
      expect(find.textContaining(': abuse'), findsNothing);
    },
  );
}
