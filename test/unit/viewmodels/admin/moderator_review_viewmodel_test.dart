/// Tests for ModeratorReviewViewModel.takeDown — the dispatch boundary
/// between content-type-keyed reports and the right ReportService primitive.
///
/// The dashboard binds a single button to [takeDown]; for profile reports
/// it must route to suspend (reversible hide flag), and for every other
/// content type it must route to delete. A bug here would either
/// hard-delete a profile (dangling auth account) or silently no-op a
/// content takedown — both visible to moderators.
library;

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/models/social/content_report.dart';
import 'package:butlery/models/social/content_type.dart';
import 'package:butlery/services/moderation/report_service.dart';
import 'package:butlery/viewmodels/admin/moderator_review_viewmodel.dart';

import '../../../test_support/base_unit_test.dart';

class _MockReportService extends Mock implements ReportService {}

ContentReport _report({required ContentType contentType}) => ContentReport(
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
      registerFallbackValue(_report(contentType: ContentType.recipe));
    });

    setUp(() {
      mockService = _MockReportService();
      when(
        () => mockService.suspendReportedProfile(any()),
      ).thenAnswer((_) async => true);
      when(
        () => mockService.deleteReportedContent(any()),
      ).thenAnswer((_) async => true);
      vm = ModeratorReviewViewModel(reportService: mockService);
    });

    tearDown(() => vm.dispose());

    test(
      'profile report routes to suspendReportedProfile (NOT delete)',
      () async {
        final report = _report(contentType: ContentType.profile);
        await vm.takeDown(report);
        verify(() => mockService.suspendReportedProfile(report)).called(1);
        verifyNever(() => mockService.deleteReportedContent(any()));
      },
    );

    test(
      'non-profile report routes to deleteReportedContent (NOT suspend)',
      () async {
        final report = _report(contentType: ContentType.cookSnap);
        await vm.takeDown(report);
        verify(() => mockService.deleteReportedContent(report)).called(1);
        verifyNever(() => mockService.suspendReportedProfile(any()));
      },
    );

    test(
      'isMinorOwner surfaces the minor flag for the content owner (BUT-1609)',
      () async {
        // Intention: a report on a minor's content must render the
        // "Minderårigt konto" badge, and only after the server-authoritative
        // lookup confirms it — never for adults, never for ownerless reports.
        final minorReport = ContentReport(
          id: 'r-minor',
          reporterId: 'reporter',
          contentType: ContentType.comment,
          contentId: 'c-minor',
          contentOwnerId: 'minor-owner',
          reason: 'spam',
          createdAt: DateTime(2026, 4, 26),
        );
        final adultReport = _report(contentType: ContentType.recipe);
        final ownerlessReport = ContentReport(
          id: 'r-noowner',
          reporterId: 'reporter',
          contentType: ContentType.message,
          contentId: 'c-noowner',
          reason: 'spam',
          createdAt: DateTime(2026, 4, 26),
        );

        when(() => mockService.watchOpenReports()).thenAnswer(
          (_) => Stream.value([minorReport, adultReport, ownerlessReport]),
        );
        when(
          () => mockService.isMinorAccount('minor-owner'),
        ).thenAnswer((_) async => true);
        when(
          () => mockService.isMinorAccount('owner'),
        ).thenAnswer((_) async => false);

        expect(vm.isMinorOwner(minorReport), isFalse); // fail-closed pre-load

        vm.startListening();
        await pumpEventQueue();

        expect(vm.isMinorOwner(minorReport), isTrue);
        expect(vm.isMinorOwner(adultReport), isFalse);
        expect(vm.isMinorOwner(ownerlessReport), isFalse);
        // Ownerless reports must never trigger a lookup.
        verify(() => mockService.isMinorAccount(any())).called(2);
      },
    );

    test('two reports on the same owner trigger exactly one lookup', () async {
      ContentReport r(String id) => ContentReport(
        id: id,
        reporterId: 'x',
        contentType: ContentType.comment,
        contentId: 'c-$id',
        contentOwnerId: 'same-owner',
        reason: 'spam',
        createdAt: DateTime(2026, 4, 26),
      );
      when(
        () => mockService.watchOpenReports(),
      ).thenAnswer((_) => Stream.value([r('a'), r('b')]));
      when(
        () => mockService.isMinorAccount('same-owner'),
      ).thenAnswer((_) async => true);

      vm.startListening();
      await pumpEventQueue();

      expect(vm.isMinorOwner(r('a')), isTrue);
      verify(() => mockService.isMinorAccount('same-owner')).called(1);
    });

    test('only a resolved minor repaints beyond the list emission', () async {
      // Adult-only batch: the single list emission is the only notification.
      when(() => mockService.watchOpenReports()).thenAnswer(
        (_) => Stream.value([_report(contentType: ContentType.recipe)]),
      );
      when(
        () => mockService.isMinorAccount('owner'),
      ).thenAnswer((_) async => false);
      var adultNotifs = 0;
      vm.addListener(() => adultNotifs++);
      vm.startListening();
      await pumpEventQueue();

      // Minor batch on a second VM: the true resolution adds a repaint.
      final vm2 = ModeratorReviewViewModel(reportService: mockService);
      addTearDown(vm2.dispose);
      final minorReport = ContentReport(
        id: 'rm',
        reporterId: 'x',
        contentType: ContentType.comment,
        contentId: 'cm',
        contentOwnerId: 'minor',
        reason: 'spam',
        createdAt: DateTime(2026, 4, 26),
      );
      when(
        () => mockService.watchOpenReports(),
      ).thenAnswer((_) => Stream.value([minorReport]));
      when(
        () => mockService.isMinorAccount('minor'),
      ).thenAnswer((_) async => true);
      var minorNotifs = 0;
      vm2.addListener(() => minorNotifs++);
      vm2.startListening();
      await pumpEventQueue();

      expect(
        minorNotifs,
        greaterThan(adultNotifs),
        reason:
            'a resolved minor must repaint the badge; an adult-only batch adds '
            'no repaint beyond the list emission',
      );
    });

    test(
      'a failed lookup is retried on the next emission (not locked false)',
      () async {
        final report = ContentReport(
          id: 'rf',
          reporterId: 'x',
          contentType: ContentType.comment,
          contentId: 'cf',
          contentOwnerId: 'flaky',
          reason: 'spam',
          createdAt: DateTime(2026, 4, 26),
        );
        final controller = StreamController<List<ContentReport>>();
        addTearDown(controller.close);
        when(
          () => mockService.watchOpenReports(),
        ).thenAnswer((_) => controller.stream);
        // First lookup fails (null → unresolved), second confirms minor.
        var call = 0;
        when(
          () => mockService.isMinorAccount('flaky'),
        ).thenAnswer((_) async => call++ == 0 ? null : true);

        vm.startListening();
        controller.add([report]);
        await pumpEventQueue();
        expect(
          vm.isMinorOwner(report),
          isFalse,
          reason: 'fail-closed while the first lookup failed',
        );

        controller.add([report]); // re-emission must retry the unresolved owner
        await pumpEventQueue();
        expect(
          vm.isMinorOwner(report),
          isTrue,
          reason: 'the retry resolved the minor — a null was not memoized',
        );
        verify(() => mockService.isMinorAccount('flaky')).called(2);
      },
    );

    test('isReversibleAction is true only for profile reports', () {
      expect(
        vm.isReversibleAction(_report(contentType: ContentType.profile)),
        isTrue,
      );
      expect(
        vm.isReversibleAction(_report(contentType: ContentType.recipe)),
        isFalse,
      );
      expect(
        vm.isReversibleAction(_report(contentType: ContentType.cookSnap)),
        isFalse,
      );
      expect(
        vm.isReversibleAction(_report(contentType: ContentType.group)),
        isFalse,
      );
      expect(
        vm.isReversibleAction(_report(contentType: ContentType.message)),
        isFalse,
      );
    });
  });
}
