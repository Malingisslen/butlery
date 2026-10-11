// BUT-2353: closing carries the chosen motivation, and a misattribution close
// has nothing to choose.
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/models/social/content_report.dart';
import 'package:butlery/models/social/content_type.dart';
import 'package:butlery/models/social/moderation_motivation.dart';
import 'package:butlery/services/moderation/report_service.dart';
import 'package:butlery/viewmodels/admin/moderator_review_viewmodel.dart';

import '../../../test_support/base_unit_test.dart';

class _MockReportService extends Mock implements ReportService {}

ContentReport _report({
  String reason = 'copyright',
  ModeratorDecision? action,
}) => ContentReport(
  id: 'r1',
  reporterId: 'reporter',
  contentType: ContentType.recipe,
  contentId: 'c1',
  contentOwnerId: 'owner',
  reason: reason,
  createdAt: DateTime(2026, 10, 1),
  moderatorAction: action,
);

void main() {
  late _MockReportService service;
  late ModeratorReviewViewModel vm;

  setUpAll(() async {
    await BaseUnitTest.setupUnit();
    registerFallbackValue(_report());
  });

  setUp(() {
    service = _MockReportService();
    vm = ModeratorReviewViewModel(reportService: service);
  });

  test('close passes the motivation to the service', () async {
    when(
      () => service.closeReport(any(), motivation: any(named: 'motivation')),
    ).thenAnswer((_) async => true);
    final report = _report();

    final ok = await vm.close(
      report,
      motivation: ModerationMotivation.removedCopyright,
    );

    expect(ok, isTrue);
    verify(
      () => service.closeReport(
        report,
        motivation: ModerationMotivation.removedCopyright,
      ),
    ).called(1);
  });

  test('the decision is the takedown already made, else no action', () {
    expect(
      vm.decisionFor(_report(action: ModeratorDecision.contentRemoved)),
      ModeratorDecision.contentRemoved,
    );
    expect(
      vm.decisionFor(_report(action: ModeratorDecision.profileHidden)),
      ModeratorDecision.profileHidden,
    );
    expect(vm.decisionFor(_report()), ModeratorDecision.noAction);
  });

  test('misattribution reports skip the motivation choice', () {
    expect(vm.needsMotivation(_report(reason: 'misattribution')), isFalse);
    expect(vm.needsMotivation(_report()), isTrue);
  });
}
