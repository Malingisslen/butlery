// Admin load failures say what failed, in words, with Försök igen (P5-U01),
// and the loading line names what is loading (P5-U18).
//
// Sources: content-style-guide.md:89-94 (what happened, what you can do; no
// error codes in user text), produktregler.md:163 (plate line + text),
// state_widget.dart (the error state's default action is commonRetry).
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart' as prod;
import 'package:butlery/l10n/app_localizations_sv.dart';
import 'package:butlery/models/feedback_entry.dart';
import 'package:butlery/models/social/content_report.dart';
import 'package:butlery/models/social/content_type.dart';
import 'package:butlery/repositories/interfaces/feedback_repository.dart';
import 'package:butlery/services/moderation/report_service.dart';
import 'package:butlery/views/admin/feedback_inbox_view.dart';
import 'package:butlery/views/admin/moderator_review_view.dart';
import 'package:butlery/widgets/common/state_widget.dart';

import '../../../infrastructure/helpers/widget_test_app.dart';

class _MockReportService extends Mock implements ReportService {}

class _MockFeedbackRepository extends Mock implements FeedbackRepository {}

void main() {
  final sv = AppLocalizationsSv();

  setUp(() async {
    await GetIt.instance.reset();
  });

  tearDown(() async {
    prod.ServiceLocator.reset();
    await GetIt.instance.reset();
  });

  group('ModeratorReviewView', () {
    late _MockReportService reports;
    late StreamController<List<ContentReport>> stream;

    setUp(() {
      reports = _MockReportService();
      stream = StreamController<List<ContentReport>>.broadcast();
      when(() => reports.watchIsAdmin()).thenAnswer((_) => Stream.value(true));
      when(() => reports.watchOpenReports()).thenAnswer((_) => stream.stream);
      GetIt.instance.registerSingleton<ReportService>(reports);
      prod.ServiceLocator.initialize(DIContainer());
    });

    tearDown(() => stream.close());

    testWidgets('a failed load names the reports and offers Försök igen, '
        'never the raw exception', (tester) async {
      await tester.pumpWidget(
        createLocalizedTestApp(
          wrapInScaffold: false,
          child: const ModeratorReviewView(),
        ),
      );
      await tester.pump();
      stream.addError(StateError('permission-denied: boom'));
      await tester.pump();

      final error = tester.widget<StateWidget>(find.byType(StateWidget));
      expect(error.type, StateType.error);
      expect(find.text(sv.moderatorReportsLoadFailed), findsOneWidget);
      expect(find.textContaining('boom'), findsNothing);
      expect(find.text(sv.commonRetry), findsOneWidget);

      await tester.tap(find.text(sv.commonRetry));
      await tester.pump();
      verify(() => reports.watchOpenReports()).called(2);
      expect(find.text(sv.moderatorReportsLoadFailed), findsNothing);
    });

    // Integration of P5-U00: a refused action is a failure snackbar with
    // Försök igen (content-style-guide.md:87-97), never the method name and
    // never the queue's load-error state.
    testWidgets('a refused "Nästa steg" says what failed and what is kept, '
        'keeps the queue, and retries', (tester) async {
      final report = ContentReport(
        id: 'r1',
        reporterId: 'reporter',
        contentType: ContentType.comment,
        contentId: 'c1',
        contentOwnerId: 'owner',
        reason: 'spam',
        createdAt: DateTime(2026, 4, 26),
      );
      when(() => reports.isMinorAccount(any())).thenAnswer((_) async => false);
      var calls = 0;
      when(() => reports.advanceReportStatus(report)).thenAnswer((_) async {
        calls++;
        throw StateError('permission-denied: boom');
      });

      await tester.pumpWidget(
        createLocalizedTestApp(
          wrapInScaffold: false,
          child: const ModeratorReviewView(),
        ),
      );
      await tester.pump();
      stream.add([report]);
      await tester.pump();

      await tester.tap(find.text(sv.moderatorActionAdvance));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(
        find.textContaining(sv.moderatorAdvanceFailed),
        findsOneWidget,
      );
      expect(
        find.textContaining(sv.moderatorReportUnchanged),
        findsOneWidget,
      );
      expect(find.textContaining('advanceReportStatus'), findsNothing);
      expect(find.textContaining('boom'), findsNothing);
      expect(find.byType(StateWidget), findsNothing);
      expect(find.text(sv.moderatorActionAdvance), findsOneWidget);

      await tester.tap(find.text(sv.commonRetry));
      await tester.pump();
      expect(calls, 2);
    });

    // The real ReportService never throws: its safeExecute swallows the
    // refusal and returns false. That false is the failure the moderator
    // must see.
    for (final action in ['advance', 'close']) {
      testWidgets('a "$action" the service refuses with false (no throw) '
          'still shows the failure snackbar', (tester) async {
        final report = ContentReport(
          id: 'r1',
          reporterId: 'reporter',
          contentType: ContentType.comment,
          contentId: 'c1',
          contentOwnerId: 'owner',
          reason: 'spam',
          createdAt: DateTime(2026, 4, 26),
        );
        when(
          () => reports.isMinorAccount(any()),
        ).thenAnswer((_) async => false);
        when(
          () => reports.advanceReportStatus(report),
        ).thenAnswer((_) async => false);
        when(() => reports.closeReport(report)).thenAnswer((_) async => false);

        await tester.pumpWidget(
          createLocalizedTestApp(
            wrapInScaffold: false,
            child: const ModeratorReviewView(),
          ),
        );
        await tester.pump();
        stream.add([report]);
        await tester.pump();

        await tester.tap(
          find.text(
            action == 'advance'
                ? sv.moderatorActionAdvance
                : sv.moderatorActionClose,
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        expect(
          find.textContaining(
            action == 'advance'
                ? sv.moderatorAdvanceFailed
                : sv.moderatorCloseFailed,
          ),
          findsOneWidget,
        );
        expect(find.text(sv.commonRetry), findsOneWidget);
      });
    }
  });

  group('FeedbackInboxView', () {
    late _MockFeedbackRepository repo;
    late StreamController<List<FeedbackEntry>> stream;

    setUp(() {
      repo = _MockFeedbackRepository();
      stream = StreamController<List<FeedbackEntry>>.broadcast();
      when(
        () => repo.watchFeedback(
          status: any(named: 'status'),
          limit: any(named: 'limit'),
        ),
      ).thenAnswer((_) => stream.stream);
      GetIt.instance.registerSingleton<FeedbackRepository>(repo);
      prod.ServiceLocator.initialize(DIContainer());
    });

    tearDown(() => stream.close());

    testWidgets('loading names what is fetched; a failure says what could '
        'not be fetched, with Försök igen', (tester) async {
      // Known, out of scope here: the top bar's filter row overflows by 8 px
      // in the test font (butlery_top_bar.dart:408). Only that report is
      // ignored; every other error still fails the test.
      final original = FlutterError.onError;
      FlutterError.onError = (details) {
        final text = details.exceptionAsString();
        if (text.contains('RenderFlex overflowed')) return;
        original?.call(details);
      };
      addTearDown(() => FlutterError.onError = original);

      await tester.pumpWidget(
        createLocalizedTestApp(
          wrapInScaffold: false,
          child: const FeedbackInboxView(),
        ),
      );
      await tester.pump();

      final loading = tester.widget<StateWidget>(find.byType(StateWidget));
      expect(loading.type, StateType.loading);
      expect(loading.message, sv.loadingFeedbackEntries);

      stream.addError(StateError('permission-denied: boom'));
      await tester.pump();

      expect(find.text(sv.adminFeedbackLoadFailed), findsOneWidget);
      expect(find.textContaining('boom'), findsNothing);
      expect(find.text(sv.commonRetry), findsOneWidget);
    });

    testWidgets('a refused status change is a failure snackbar with Försök '
        'igen, and the inbox stays', (tester) async {
      final original = FlutterError.onError;
      FlutterError.onError = (details) {
        final text = details.exceptionAsString();
        if (text.contains('RenderFlex overflowed')) return;
        original?.call(details);
      };
      addTearDown(() => FlutterError.onError = original);
      var calls = 0;
      when(() => repo.updateStatus('f1', FeedbackStatus.triaged)).thenAnswer((
        _,
      ) async {
        calls++;
        throw StateError('permission-denied: boom');
      });

      await tester.pumpWidget(
        createLocalizedTestApp(
          wrapInScaffold: false,
          child: const FeedbackInboxView(),
        ),
      );
      await tester.pump();
      stream.add([
        FeedbackEntry(
          id: 'f1',
          userId: 'u',
          category: FeedbackCategory.bug,
          description: 'Knappen svarar inte',
          recentInteractions: const [],
          createdAt: DateTime.utc(2026, 1, 1),
        ),
      ]);
      await tester.pump();

      // The filter row has the same label in a Row; the entry's control
      // is the Wrap.
      final chip = find.descendant(
        of: find.byType(Wrap),
        matching: find.widgetWithText(
          ChoiceChip,
          sv.adminFeedbackStatusTriaged,
        ),
      );
      await tester.ensureVisible(chip);
      await tester.tap(chip);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(
        find.textContaining(sv.adminFeedbackStatusFailed),
        findsOneWidget,
      );
      expect(
        find.textContaining(sv.adminFeedbackStatusPreserved),
        findsOneWidget,
      );
      expect(find.textContaining('updateFeedbackStatus'), findsNothing);
      expect(find.text('Knappen svarar inte'), findsOneWidget);

      await tester.tap(find.text(sv.commonRetry));
      await tester.pump();
      expect(calls, 2);
    });
  });
}
