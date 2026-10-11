/// Hosts for the admin views the register had not compared.
library;

import 'package:mocktail/mocktail.dart';

import 'package:butlery/l10n/app_localizations_sv.dart';
import 'package:butlery/models/admin/metrics/metric_key.dart';
import 'package:butlery/models/admin/metrics/metric_value.dart';
import 'package:butlery/models/admin/ops_event.dart';
import 'package:butlery/models/social/content_report.dart';
import 'package:butlery/models/social/content_type.dart';
import 'package:butlery/repositories/ops_log_repository.dart';
import 'package:butlery/repositories/parsing_correction_repository.dart';
import 'package:butlery/services/admin/metrics_assembler.dart';
import 'package:butlery/services/moderation/moderation_appeals_service.dart';
import 'package:butlery/services/moderation/report_service.dart';
import 'package:butlery/views/admin/metric_tab_view.dart';
import 'package:butlery/views/admin/moderator_review_view.dart';
import 'package:butlery/views/admin/ops_log_view.dart';
import 'package:butlery/views/admin/parsing_details_view.dart';

import '../../../infrastructure/di/test_service_locator.dart';
import '../state_host.dart';

class _MockAssembler extends Mock implements MetricsAssembler {}

class _MockOps extends Mock implements OpsLogRepository {}

class _MockParsing extends Mock implements ParsingCorrectionRepository {}

class _MockReports extends Mock implements ReportService {}

class _MockAppeals extends Mock implements ModerationAppealsService {}

ContentReport _report(String id, String reason, ContentType type) =>
    ContentReport(
      id: id,
      reporterId: 'reporter',
      contentType: type,
      contentId: 'c$id',
      contentOwnerId: 'owner',
      reason: reason,
      status: ReportStatus.newReport,
      createdAt: DateTime(2026, 9, 27),
    );

final reviewAdminHosts = <String, StateHost>{
  'MetricTabView': StateHost(
    build: (ctx) async {
      registerFallbackValue(<MetricKey>{});
      registerFallbackValue(AppLocalizationsSv());
      final assembler = _MockAssembler();
      when(
        () => assembler.resolve(
          any(),
          any(),
          force: any(named: 'force'),
        ),
      ).thenAnswer(
        (_) async => {
          MetricKey.importDomains: const ScalarMetric(42, previous: 38),
          MetricKey.importSuccess: const ScalarMetric(318, previous: 290),
          MetricKey.importFailure: const ScalarMetric(37, previous: 21),
          MetricKey.importSuccessRate: const ScalarMetric(89.6, previous: 93.2),
          MetricKey.importDomainTable: const MatrixMetric(
            ['ica.se', 'koket.se', 'arla.se'],
            ['Lyckade', 'Misslyckade', 'Andel'],
            [
              [120, 4, 96.8],
              [88, 11, 88.9],
              [54, 15, 78.3],
            ],
          ),
        },
      );
      TestServiceLocator.registerMock<MetricsAssembler>(assembler);
      return MetricTabView(
        title: (l) => l.adminImportTitle,
        keys: const [
          MetricKey.importDomains,
          MetricKey.importSuccess,
          MetricKey.importFailure,
          MetricKey.importSuccessRate,
          MetricKey.importDomainTable,
        ],
      );
    },
  ),
  'OpsLogView': StateHost(
    build: (ctx) async {
      final repo = _MockOps();
      when(() => repo.getRecentEvents(limit: any(named: 'limit'))).thenAnswer(
        (_) async => [
          OpsEvent(
            type: 'cleanupExpiredTrash',
            executedAt: DateTime(2026, 9, 28, 3),
            deletedCount: 12,
          ),
          OpsEvent(
            type: 'cleanupOldAuditLogs',
            executedAt: DateTime(2026, 9, 27, 3),
            deletedCount: 340,
          ),
          OpsEvent(
            type: 'cleanupGuestAccounts',
            executedAt: DateTime(2026, 9, 26, 3),
          ),
        ],
      );
      TestServiceLocator.registerMock<OpsLogRepository>(repo);
      return const OpsLogView();
    },
  ),
  'ParsingDetailsView': StateHost(
    build: (ctx) async {
      final repo = _MockParsing();
      when(repo.getDomainStats).thenAnswer(
        (_) async => {'ica.se': 14, 'koket.se': 9, 'arla.se': 4},
      );
      when(
        () => repo.getByDomain(any(), limit: any(named: 'limit')),
      ).thenAnswer((_) async => []);
      TestServiceLocator.registerMock<ParsingCorrectionRepository>(repo);
      return const ParsingDetailsView();
    },
  ),
  'ModeratorReviewView': StateHost(
    build: (ctx) async {
      final reports = _MockReports();
      final appeals = _MockAppeals();
      when(reports.watchIsAdmin).thenAnswer((_) => Stream.value(true));
      when(reports.watchOpenReports).thenAnswer(
        (_) => Stream.value([
          _report('1', 'copyright', ContentType.recipe),
          _report('2', 'spam', ContentType.comment),
        ]),
      );
      when(() => reports.isMinorAccount(any())).thenAnswer((_) async => false);
      when(
        () => reports.getReportEvidence(any()),
      ).thenAnswer((_) async => (evidence: null));
      when(appeals.listOpenAppeals).thenAnswer((_) async => []);
      TestServiceLocator.registerMock<ReportService>(reports);
      TestServiceLocator.registerMock<ModerationAppealsService>(appeals);
      return const ModeratorReviewView();
    },
  ),
};
