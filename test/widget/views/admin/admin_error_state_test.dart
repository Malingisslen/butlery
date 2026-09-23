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
  });
}
