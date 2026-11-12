// BUT-2329: the Sparade tab.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:intl/intl.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart' as prod;
import 'package:butlery/l10n/app_localizations_sv.dart';
import 'package:butlery/models/social/content_report.dart';
import 'package:butlery/models/social/report_evidence.dart';
import 'package:butlery/services/moderation/moderation_appeals_service.dart';
import 'package:butlery/services/moderation/report_service.dart';
import 'package:butlery/views/admin/moderator_review_view.dart';

import '../../../infrastructure/helpers/widget_test_app.dart';

class _MockReports extends Mock implements ReportService {}

class _MockAppeals extends Mock implements ModerationAppealsService {}

final _sv = AppLocalizationsSv();
final _until = DateTime(2027, 10, 9);

ReportEvidence _kept(String id) => ReportEvidence(
  reportId: id,
  outcome: EvidenceOutcome.captured,
  contentType: 'recipe',
  text: const [('title', 'Pannkakor')],
  frozen: FrozenEvidence(reason: FreezeReason.police, until: _until),
);

void main() {
  late _MockReports reports;
  late _MockAppeals appeals;
  late StreamController<List<ReportEvidence>> frozen;

  setUpAll(() => registerFallbackValue(FreezeAction.freeze));

  setUp(() async {
    await GetIt.instance.reset();
    reports = _MockReports();
    appeals = _MockAppeals();
    frozen = StreamController<List<ReportEvidence>>.broadcast();
    when(() => reports.watchIsAdmin()).thenAnswer((_) => Stream.value(true));
    when(
      () => reports.watchOpenReports(),
    ).thenAnswer((_) => Stream<List<ContentReport>>.value(const []));
    when(() => reports.watchFrozenEvidence()).thenAnswer((_) => frozen.stream);
    when(
      () => reports.forgetReportEvidence(any(), round: any(named: 'round')),
    ).thenReturn(null);
    when(() => appeals.listOpenAppeals()).thenAnswer((_) async => []);
    GetIt.instance.registerSingleton<ReportService>(reports);
    GetIt.instance.registerSingleton<ModerationAppealsService>(appeals);
    prod.ServiceLocator.initialize(DIContainer());
  });

  tearDown(() async {
    await frozen.close();
    prod.ServiceLocator.reset();
    await GetIt.instance.reset();
  });

  Future<void> openTab(
    WidgetTester tester,
    List<ReportEvidence> items,
  ) async {
    tester.view.physicalSize = const Size(800, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      createLocalizedTestApp(
        wrapInScaffold: false,
        child: const ModeratorReviewView(),
      ),
    );
    await tester.pump();
    frozen.add(items);
    await tester.pumpAndSettle();
    await tester.tap(find.text(_sv.moderatorTabFrozen(items.length)));
    await tester.pumpAndSettle();
  }

  testWidgets('shows the empty state', (tester) async {
    await openTab(tester, const []);

    expect(find.text(_sv.moderatorFrozenEmpty), findsOneWidget);
  });

  testWidgets('a row shows type, date, reason and the text', (tester) async {
    await openTab(tester, [_kept('r1')]);

    expect(
      find.text(_sv.moderatorContentTypeRecipe.toUpperCase()),
      findsOneWidget,
    );
    expect(find.text('Pannkakor'), findsOneWidget);
    final date = DateFormat.yMMMd(_sv.localeName).format(_until);
    expect(
      find.text(
        _sv.moderatorFrozenUntilLine(date, _sv.moderatorFreezeReasonPolice),
      ),
      findsOneWidget,
    );
    expect(find.text(_sv.moderatorFrozenExtend), findsOneWidget);
    expect(find.text(_sv.moderatorFrozenRelease), findsOneWidget);
  });

  testWidgets('extend asks for a reason and calls the service', (tester) async {
    when(
      () => appeals.freezeEvidence(
        'r1',
        action: FreezeAction.extend,
        reason: FreezeReason.legalClaim,
      ),
    ).thenAnswer((_) async => FreezeOutcome(until: DateTime(2028, 10, 9)));
    await openTab(tester, [_kept('r1')]);

    await tester.tap(find.byKey(const ValueKey('frozen-extend')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(_sv.moderatorFreezeReasonLegalClaim));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('freeze-confirm')));
    await tester.pumpAndSettle();

    verify(
      () => appeals.freezeEvidence(
        'r1',
        action: FreezeAction.extend,
        reason: FreezeReason.legalClaim,
      ),
    ).called(1);
  });

  testWidgets('extend at the cap says three years is the limit', (
    tester,
  ) async {
    when(
      () => appeals.freezeEvidence(
        any(),
        action: any(named: 'action'),
        reason: any(named: 'reason'),
      ),
    ).thenThrow(const FreezeEvidenceException(FreezeBlock.atCap));
    await openTab(tester, [_kept('r1')]);

    await tester.tap(find.byKey(const ValueKey('frozen-extend')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('freeze-reason-police')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('freeze-confirm')));
    await tester.pumpAndSettle();

    expect(find.text(_sv.moderatorFreezeBlockAtCap), findsOneWidget);
  });

  testWidgets('release confirms, calls the service and says it is deleted', (
    tester,
  ) async {
    when(
      () => appeals.freezeEvidence('r1', action: FreezeAction.release),
    ).thenAnswer((_) async => const FreezeOutcome(deleted: true));
    await openTab(tester, [_kept('r1')]);

    await tester.tap(find.byKey(const ValueKey('frozen-release')));
    await tester.pumpAndSettle();
    expect(find.text(_sv.moderatorFrozenReleaseTitle), findsOneWidget);
    await tester.tap(find.text(_sv.moderatorFrozenRelease).last);
    await tester.pumpAndSettle();

    verify(
      () => appeals.freezeEvidence('r1', action: FreezeAction.release),
    ).called(1);
    expect(find.text(_sv.moderatorFrozenReleasedDeleted), findsOneWidget);
  });

  testWidgets('cancelling the release dialog calls nothing', (tester) async {
    await openTab(tester, [_kept('r1')]);

    await tester.tap(find.byKey(const ValueKey('frozen-release')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(_sv.commonCancel));
    await tester.pumpAndSettle();

    verifyNever(
      () => appeals.freezeEvidence(
        any(),
        action: any(named: 'action'),
        reason: any(named: 'reason'),
      ),
    );
  });
}
