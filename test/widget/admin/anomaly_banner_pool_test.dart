// BUT-1517: the nightly pool entries have their own labels and a "Granska"
// button that hands the pool key on.
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';

import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart' as production;
import 'package:butlery/repositories/anomaly_repository.dart';
import 'package:butlery/views/admin/widgets/anomaly_banner.dart';

import '../../infrastructure/helpers/widget_test_app.dart';
import '../../test_support/base_unit_test.dart';

const _key = 'v1:0123456789abcdef';

Map<String, dynamic> _entry(String metric, {String? poolKey}) => {
  'metric': metric,
  'today': 9,
  'mean': 1,
  'z': 5,
  'direction': 'up',
  'poolKey': ?poolKey,
};

void main() {
  setUpAll(BaseUnitTest.setupUnit);

  setUp(() => production.ServiceLocator.initialize(DIContainer()));

  tearDown(() {
    final getIt = GetIt.instance;
    if (getIt.isRegistered<AnomalyRepository>()) {
      getIt.unregister<AnomalyRepository>();
    }
    production.ServiceLocator.reset();
  });

  Future<void> pump(
    WidgetTester tester,
    List<Map<String, dynamic>> anomalies, {
    ValueChanged<String>? onReviewPool,
  }) async {
    final firestore = FakeFirebaseFirestore();
    await firestore
        .collection('analytics')
        .doc('anomalies')
        .collection('daily')
        .doc('2026-11-12')
        .set({'date': '2026-11-12', 'anomalies': anomalies});
    if (GetIt.instance.isRegistered<AnomalyRepository>()) {
      GetIt.instance.unregister<AnomalyRepository>();
    }
    GetIt.instance.registerSingleton<AnomalyRepository>(
      AnomalyRepository(firestore: firestore),
    );
    await tester.pumpWidget(
      createLocalizedTestApp(
        child: AnomalyBanner(onReviewPool: onReviewPool),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('the three pool metrics have Swedish labels', (tester) async {
    await pump(tester, [
      _entry('pool_velocity', poolKey: _key),
      _entry('pool_rating_skew', poolKey: _key),
      _entry('pool_new_over_floor', poolKey: _key),
    ]);

    expect(find.textContaining('Betygsrusning:'), findsOneWidget);
    expect(find.textContaining('Betyg drar snittet:'), findsOneWidget);
    expect(
      find.textContaining('Ny rätt fick snabbt fem röster:'),
      findsOneWidget,
    );
  });

  testWidgets('Granska hands on the pool key of its own entry', (tester) async {
    String? opened;
    await pump(tester, [
      _entry('recipes_total'),
      _entry('pool_velocity', poolKey: _key),
    ], onReviewPool: (k) => opened = k);

    expect(find.text('Granska'), findsOneWidget);
    await tester.tap(find.text('Granska'));

    expect(opened, _key);
  });

  testWidgets('a capped window read is named, with no Granska', (tester) async {
    await pump(tester, [
      _entry('pool_window_overflow'),
    ], onReviewPool: (_) {});

    expect(
      find.textContaining('Betygslarmet läste inte alla röster:'),
      findsOneWidget,
    );
    expect(find.text('Granska'), findsNothing);
  });

  testWidgets('an entry without a pool key has no Granska', (tester) async {
    await pump(tester, [
      _entry('recipes_total'),
    ], onReviewPool: (_) {});

    expect(find.text('Granska'), findsNothing);
  });
}
