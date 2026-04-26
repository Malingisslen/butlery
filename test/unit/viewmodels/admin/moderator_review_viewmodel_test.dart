/// Tests for ModeratorReviewViewModel.takeDown — the dispatch boundary
/// between content-type-keyed reports and the right ReportService primitive.
///
/// The dashboard binds a single button to [takeDown]; for `'profile'`
/// reports it must route to suspend (reversible hide flag), and for every
/// other content type it must route to delete. A bug here would either
/// hard-delete a profile (dangling auth account) or silently no-op a
/// content takedown — both visible to moderators.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/models/social/content_report.dart';
import 'package:butlery/services/moderation/report_service.dart';
import 'package:butlery/viewmodels/admin/moderator_review_viewmodel.dart';

import '../../../test_support/base_unit_test.dart';

class _MockReportService extends Mock implements ReportService {}

ContentReport _report({required String contentType}) => ContentReport(
      id: 'r1',
      reporterId: 'reporter',
      contentType: contentType,
      contentId: 'c1',
      contentOwnerId: 'owner',
      reason: 'spam',
      createdAt: DateTime(2026, 4, 26),
    );

void main() {
  group('ModeratorReviewViewModel.takeDown dispatch', () {
    late _MockReportService mockService;
    late ModeratorReviewViewModel vm;

    setUpAll(() async {
      await BaseUnitTest.setupUnit();
      registerFallbackValue(_report(contentType: 'recipe'));
    });

    setUp(() {
      mockService = _MockReportService();
      when(() => mockService.suspendReportedProfile(any()))
          .thenAnswer((_) async => true);
      when(() => mockService.deleteReportedContent(any()))
          .thenAnswer((_) async => true);
      vm = ModeratorReviewViewModel(reportService: mockService);
    });

    tearDown(() => vm.dispose());

    test('profile report routes to suspendReportedProfile (NOT delete)',
        () async {
      final report = _report(contentType: 'profile');
      await vm.takeDown(report);
      verify(() => mockService.suspendReportedProfile(report)).called(1);
      verifyNever(() => mockService.deleteReportedContent(any()));
    });

    test('non-profile report routes to deleteReportedContent (NOT suspend)',
        () async {
      final report = _report(contentType: 'cook_snap');
      await vm.takeDown(report);
      verify(() => mockService.deleteReportedContent(report)).called(1);
      verifyNever(() => mockService.suspendReportedProfile(any()));
    });

    test('isReversibleAction is true only for profile reports', () {
      expect(vm.isReversibleAction(_report(contentType: 'profile')), isTrue);
      expect(vm.isReversibleAction(_report(contentType: 'recipe')), isFalse);
      expect(vm.isReversibleAction(_report(contentType: 'cook_snap')), isFalse);
      expect(vm.isReversibleAction(_report(contentType: 'group')), isFalse);
      expect(vm.isReversibleAction(_report(contentType: 'message')), isFalse);
    });
  });
}
