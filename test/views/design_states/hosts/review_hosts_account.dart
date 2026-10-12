/// Hosts for the account and settings views the register had not compared.
library;

import 'dart:async';

import 'package:clock/clock.dart';

import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

import 'package:butlery/models/account/user_consent.dart';
import 'package:butlery/models/auth/mfa_types.dart';
import 'package:butlery/models/social/content_report.dart';
import 'package:butlery/models/social/content_type.dart';
import 'package:butlery/models/social/moderation_outcome.dart';
import 'package:butlery/services/account/account_deletion_service.dart';
import 'package:butlery/services/account/data_export_service.dart';
import 'package:butlery/services/account/pending_retention_notice_store.dart';
import 'package:butlery/services/auth/auth_mfa_service.dart';
import 'package:butlery/services/auth_service.dart';
import 'package:butlery/services/moderation/report_outcomes_service.dart';
import 'package:butlery/services/moderation/report_service.dart';
import 'package:butlery/services/trash/trash_service.dart';
import 'package:butlery/viewmodels/account/consent_viewmodel.dart';
import 'package:butlery/viewmodels/account/data_export_viewmodel.dart';
import 'package:butlery/viewmodels/account/pending_deletion_viewmodel.dart';
import 'package:butlery/viewmodels/profile/profile_viewmodel.dart';
import 'package:butlery/viewmodels/settings/my_reports_viewmodel.dart';
import 'package:butlery/views/account/consent_management_view.dart';
import 'package:butlery/views/account/data_export_view.dart';
import 'package:butlery/views/account/pending_deletion_view.dart';
import 'package:butlery/views/settings/mfa_settings_view.dart';
import 'package:butlery/views/settings/my_reports_view.dart';
import 'package:butlery/views/settings/trash_view.dart';

import '../../../infrastructure/di/test_service_locator.dart';
import '../../../infrastructure/fakes/scripted_trash_service.dart';
import '../../../infrastructure/mocks/production_mocks.dart';
import '../state_host.dart';

class _MockAccountDeletion extends Mock implements AccountDeletionService {}

class _MockProfile extends Mock implements ProfileViewModel {}

class _MockMfa extends Mock implements AuthMfaService {}

class _MockReportService extends Mock implements ReportService {}

class _MockOutcomes extends Mock implements ReportOutcomesService {}

class _FakeExport extends Fake implements DataExportService {}

ContentReport _report(String id, ReportStatus status, String reason) =>
    ContentReport(
      id: id,
      reporterId: 'u1',
      contentType: ContentType.comment,
      contentId: 'c$id',
      reason: reason,
      status: status,
      createdAt: DateTime.utc(2026, 10, 1),
      moderatorAction: status == ReportStatus.closed
          ? ModeratorDecision.contentRemoved
          : null,
    );

final reviewAccountHosts = <String, StateHost>{
  'ConsentManagementView': StateHost(
    build: (ctx) async {
      registerFallbackValue(
        const ConsentPurposes(essentialServices: true, dataProcessing: true),
      );
      final service = MockConsentService();
      when(service.getUserConsent).thenAnswer(
        (_) async => UserConsent(
          userId: 'u1',
          purposes: const ConsentPurposes(
            essentialServices: true,
            dataProcessing: true,
            analytics: true,
          ),
          grantedAt: DateTime(2026, 1, 1),
          consentVersion: '1.1.0',
          deviceInfo: 'test',
        ),
      );
      when(service.needsConsentRenewal).thenAnswer((_) async => false);
      final vm = ConsentViewModel(consentService: service);
      ctx.disposers.add(vm.dispose);
      return ChangeNotifierProvider<ConsentViewModel>.value(
        value: vm,
        child: const ConsentManagementView(backTo: 'Integritet & data'),
      );
    },
  ),
  'DataExportView': StateHost(
    build: (ctx) async {
      final vm = DataExportViewModel(exportService: _FakeExport());
      return ChangeNotifierProvider<DataExportViewModel>.value(
        value: vm,
        child: const DataExportView(),
      );
    },
  ),
  'PendingDeletionView': StateHost(
    build: (ctx) async {
      final vm = PendingDeletionViewModel(
        accountDeletionService: _MockAccountDeletion(),
        profileViewModel: _MockProfile(),
        noticeStore: PendingRetentionNoticeStore(),
      );
      TestServiceLocator.registerFactory<PendingDeletionViewModel>(() => vm);
      TestServiceLocator.registerMock<AuthService>(MockAuthService());
      return PendingDeletionView(
        scheduledFor: DateTime(2026, 10, 17),
        onUndone: () {},
      );
    },
  ),
  'MfaSettingsView': StateHost(
    build: (ctx) async {
      final mfa = _MockMfa();
      when(mfa.hasMfaEnabled).thenAnswer((_) async => true);
      when(mfa.getEnrolledFactors).thenAnswer(
        (_) async => [
          MfaFactorInfo(
            factor: 'f1',
            displayName: 'Min telefon',
            enrollmentTimestamp:
                DateTime(2026, 8, 3).millisecondsSinceEpoch / 1000,
          ),
        ],
      );
      TestServiceLocator.registerMock<AuthMfaService>(mfa);
      TestServiceLocator.registerMock<AuthService>(MockAuthService());
      return const MfaSettingsView();
    },
  ),
  'MyReportsView': StateHost(
    build: (ctx) async {
      final service = _MockReportService();
      final outcomes = _MockOutcomes();
      when(service.getMyReports).thenAnswer(
        (_) async => [
          _report('1', ReportStatus.newReport, 'spam'),
          _report('2', ReportStatus.inReview, 'inappropriate'),
          _report('3', ReportStatus.closed, 'spam'),
        ],
      );
      when(outcomes.getMyReportOutcomeDetails).thenAnswer(
        (_) async => {
          '3': const ModerationOutcome(
            reportId: '3',
            decision: ModeratorDecision.contentRemoved,
          ),
        },
      );
      TestServiceLocator.registerFactory<MyReportsViewModel>(
        () => MyReportsViewModel(
          reportService: service,
          reportOutcomesService: outcomes,
        ),
      );
      return const MyReportsView();
    },
  ),
  'TrashView': StateHost(
    build: (ctx) async {
      final service = ScriptedTrashService();
      TestServiceLocator.registerMock<TrashService>(service);
      final now = clock.now();
      ctx.disposers.add(service.list.close);
      Timer.run(
        () => service.list.add([
          trashItemFor('a', title: 'Pannkakor med lingon', now: now),
          trashItemFor(
            'b',
            title: 'Kålsoppa',
            now: now,
            age: const Duration(days: 12),
          ),
          trashItemFor(
            'c',
            title: 'Äppelkaka',
            now: now,
            age: const Duration(days: 28),
          ),
        ]),
      );
      return const TrashView();
    },
  ),
};
