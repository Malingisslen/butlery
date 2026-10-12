// The drawn admin tabs "Driftlogg" and "Parsning" (skiss 65, 66): a table with
// readable event names and a tinted closing note, and a per-domain table whose
// rows open the domain's imports.
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart' as prod;
import 'package:butlery/l10n/app_localizations_sv.dart';
import 'package:butlery/models/admin/ops_event.dart';
import 'package:butlery/repositories/ops_log_repository.dart';
import 'package:butlery/repositories/parsing_correction_repository.dart';
import 'package:butlery/views/admin/ops_log_view.dart';
import 'package:butlery/views/admin/parsing_details_view.dart';
import 'package:butlery/widgets/admin/admin_table.dart';

import '../../../infrastructure/helpers/widget_test_app.dart';

class _MockOps extends Mock implements OpsLogRepository {}

class _MockParsing extends Mock implements ParsingCorrectionRepository {}

void main() {
  final sv = AppLocalizationsSv();

  setUp(() async {
    await GetIt.instance.reset();
  });

  tearDown(() async {
    prod.ServiceLocator.reset();
    await GetIt.instance.reset();
  });

  testWidgets('Driftlogg names each job in words and closes with the note', (
    tester,
  ) async {
    final ops = _MockOps();
    when(() => ops.getRecentEvents(limit: any(named: 'limit'))).thenAnswer(
      (_) async => [
        OpsEvent(
          type: 'notification_cleanup',
          executedAt: DateTime(2026, 9, 28, 3, 5),
          deletedCount: 12,
        ),
        const OpsEvent(type: 'newJobType'),
      ],
    );
    GetIt.instance.registerSingleton<OpsLogRepository>(ops);
    prod.ServiceLocator.initialize(DIContainer());

    await tester.pumpWidget(
      createLocalizedTestApp(wrapInScaffold: false, child: const OpsLogView()),
    );
    await tester.pumpAndSettle();

    expect(find.text(sv.adminOpsSectionTitle.toUpperCase()), findsOneWidget);
    expect(find.text(sv.adminOpsEventNotificationCleanup), findsOneWidget);
    expect(find.text('Newjobtype'), findsNothing);
    expect(find.text('New job type'), findsOneWidget);
    expect(find.text('28/9 03:05'), findsOneWidget);
    expect(find.text('12'), findsOneWidget);
    expect(find.textContaining(sv.adminOpsSparseTitle), findsOneWidget);
    expect(find.text('notification_cleanup'), findsNothing);
  });

  testWidgets('Parsning lists a row per domain, with a tappable row', (
    tester,
  ) async {
    final repo = _MockParsing();
    when(repo.getDomainStats).thenAnswer((_) async => {'arla.se': 4});
    when(
      () => repo.getByDomain(any(), limit: any(named: 'limit')),
    ).thenAnswer((_) async => []);
    GetIt.instance.registerSingleton<ParsingCorrectionRepository>(repo);
    prod.ServiceLocator.initialize(DIContainer());

    await tester.pumpWidget(
      createLocalizedTestApp(
        wrapInScaffold: false,
        child: const ParsingDetailsView(),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text(sv.adminParsingSectionTitle.toUpperCase()),
      findsOneWidget,
    );
    expect(find.text('arla.se'), findsOneWidget);
    expect(find.text(sv.adminParsingTableNote), findsOneWidget);
    final table = tester.widget<AdminTable>(find.byType(AdminTable));
    expect(table.rows.single.onTap, isNotNull);
  });
}
