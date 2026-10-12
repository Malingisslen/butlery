/// Hosts for the settings views the register had not compared.
library;

import 'package:mocktail/mocktail.dart';

import 'package:butlery/models/social/content_report.dart';
import 'package:butlery/models/social/content_type.dart';
import 'package:butlery/models/social/decision_detail_args.dart';
import 'package:butlery/models/social/moderation_outcome.dart';
import 'package:butlery/models/user_allergen_preferences.dart';
import 'package:butlery/services/auth/auth_mfa_service.dart';
import 'package:butlery/services/auth_service.dart';
import 'package:butlery/services/moderation/moderation_appeals_service.dart';
import 'package:butlery/services/moderation/report_outcomes_service.dart';
import 'package:butlery/services/moderation/report_service.dart';
import 'package:butlery/services/user_service.dart';
import 'package:butlery/viewmodels/settings/my_content_decisions_viewmodel.dart';
import 'package:butlery/views/more/account_email_view.dart';
import 'package:butlery/views/more/account_password_view.dart';
import 'package:butlery/views/settings/allergen_preferences_view.dart';
import 'package:butlery/views/settings/appeal_form_view.dart';
import 'package:butlery/views/settings/decision_detail_view.dart';
import 'package:butlery/views/settings/my_content_decisions_view.dart';

import '../../../infrastructure/di/test_service_locator.dart';
import '../../../infrastructure/factories/mock_factory.dart';
import '../../../infrastructure/mocks/production_mocks.dart';
import '../state_host.dart';

class _MockReports extends Mock implements ReportService {}

class _MockOutcomes extends Mock implements ReportOutcomesService {}

class _MockAppeals extends Mock implements ModerationAppealsService {}

class _MockMfa extends Mock implements AuthMfaService {}

ModerationOutcome _outcome({
  String id = 'r1',
  ContentType type = ContentType.recipe,
  String reason = 'copyright',
  ModerationAppeal? appeal,
}) => ModerationOutcome(
  reportId: id,
  decision: ModeratorDecision.contentRemoved,
  motivationKey: 'removed_copyright',
  decidedAt: DateTime.utc(2026, 9, 26, 12),
  appealDeadline: DateTime.utc(2026, 12, 25),
  appeal: appeal,
  contentType: type,
  reason: reason,
);

void _decisionServices(List<ModerationOutcome> decisions) {
  registerFallbackValue(AppealRole.owner);
  final reports = _MockReports();
  final outcomes = _MockOutcomes();
  final appeals = _MockAppeals();
  when(outcomes.getMyContentDecisions).thenAnswer((_) async => decisions);
  TestServiceLocator.registerMock<ReportService>(reports);
  TestServiceLocator.registerMock<ReportOutcomesService>(outcomes);
  TestServiceLocator.registerMock<ModerationAppealsService>(appeals);
  TestServiceLocator.registerFactory<MyContentDecisionsViewModel>(
    () => MyContentDecisionsViewModel(reportOutcomesService: outcomes),
  );
}

void _security() {
  final auth = MockAuthService()
    ..setAuthState(
      currentUser: MockFactory.createMockUser(
        uid: 'u1',
        email: 'malin@exempel.se',
      ),
      isAuthenticated: true,
    );
  TestServiceLocator.registerMock<AuthService>(auth);
  final mfa = _MockMfa();
  when(mfa.getEnrolledFactors).thenAnswer((_) async => []);
  when(mfa.hasMfaEnabled).thenAnswer((_) async => false);
  TestServiceLocator.registerMock<AuthMfaService>(mfa);
}

final reviewSettingsHosts = <String, StateHost>{
  'AllergenPreferencesView': StateHost(
    build: (ctx) async {
      registerFallbackValue(UserAllergenPreferences.defaults);
      final user = MockUserService();
      when(() => user.allergenPreferences).thenReturn(
        const UserAllergenPreferences(
          trackedAllergens: {'gluten', 'mjölk'},
          trackedDietary: {'vegansk'},
          showOnCards: true,
          showOnDetail: true,
          showCoverage: true,
        ),
      );
      when(
        () => user.updateAllergenPreferences(any()),
      ).thenAnswer((_) async => true);
      TestServiceLocator.registerMock<UserService>(user);
      return const AllergenPreferencesView(backTo: 'Mer');
    },
  ),
  'AppealFormView': StateHost(
    build: (ctx) async {
      _decisionServices(const []);
      return AppealFormView(
        args: AppealFormArgs(role: AppealRole.owner, outcome: _outcome()),
      );
    },
  ),
  'DecisionDetailView': StateHost(
    build: (ctx) async {
      _decisionServices(const []);
      return DecisionDetailView(
        args: DecisionDetailArgs(
          role: AppealRole.owner,
          reportId: 'r1',
          outcome: _outcome(),
        ),
      );
    },
  ),
  'MyContentDecisionsView': StateHost(
    build: (ctx) async {
      _decisionServices([
        _outcome(),
        _outcome(
          id: 'r2',
          type: ContentType.comment,
          reason: 'spam',
          appeal: ModerationAppeal(
            status: AppealStatus.open,
            text: 'Kommentaren var inte spam',
            submittedAt: DateTime.utc(2026, 9, 28),
          ),
        ),
      ]);
      return const MyContentDecisionsView();
    },
  ),
  'AccountEmailView': StateHost(
    build: (ctx) async {
      _security();
      return const AccountEmailView();
    },
  ),
  'AccountPasswordView': StateHost(
    build: (ctx) async {
      _security();
      return const AccountPasswordView();
    },
  ),
};
