/// BUT-2407: the admin channel tab shows small numbers as "<5" and rounds the
/// total, reading the last days of `analytics/acquisition/daily`.
library;

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart'
    as prod_locator;
import 'package:butlery/models/admin/acquisition_tally.dart';
import 'package:butlery/repositories/daily_snapshot_repository.dart';
import 'package:butlery/views/admin/acquisition_view.dart';

import '../../../infrastructure/di/test_service_locator.dart';
import '../../../infrastructure/helpers/widget_test_app.dart';

void main() {
  late FakeFirebaseFirestore firestore;

  setUp(() async {
    await TestServiceLocator.initialize();
    prod_locator.ServiceLocator.initialize(DIContainer());
    firestore = FakeFirebaseFirestore();
    TestServiceLocator.registerMock<DailySnapshotRepository>(
      DailySnapshotRepository(firestore: firestore),
    );
  });

  tearDown(() async {
    await TestServiceLocator.reset();
    prod_locator.ServiceLocator.reset();
  });

  testWidgets('a channel under 5 shows <5 and the total is rounded', (
    tester,
  ) async {
    await firestore
        .collection('analytics')
        .doc('acquisition')
        .collection('daily')
        .doc('2026-11-12')
        .set({
          'scope': AcquisitionTally.scope,
          'total': 13,
          'bySource': {'instagram': 3, 'tiktok': 10},
        });

    await tester.pumpWidget(
      createLocalizedTestApp(child: const AcquisitionView()),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('instagram'), findsOneWidget);
    expect(find.text('<5'), findsOneWidget);
    expect(find.text('3'), findsNothing);
    expect(find.text('10'), findsWidgets);
    expect(find.text('13'), findsNothing);
  });
}
