/// A failed admin read must look like a failure, not like "nothing to show":
/// the anomaly banner and the import drill-down both used to render empty
/// because their repositories swallowed the error.
library;

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';

import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart' as production;
import 'package:butlery/repositories/anomaly_repository.dart';
import 'package:butlery/repositories/parse_events_repository.dart';
import 'package:butlery/views/admin/widgets/anomaly_banner.dart';
import 'package:butlery/models/admin/metrics/metric_descriptor.dart';
import 'package:butlery/views/admin/widgets/metric_drilldown.dart';
import 'package:butlery/widgets/common/feedback/inline_error.dart';

import '../../infrastructure/helpers/widget_test_app.dart';
import '../../test_support/base_unit_test.dart';
import '../../test_support/failing_firestore.dart';

const _errorText = 'Det gick inte att ladda. Försök igen.';

void _register<T extends Object>(T instance) {
  final getIt = GetIt.instance;
  if (getIt.isRegistered<T>()) getIt.unregister<T>();
  getIt.registerSingleton<T>(instance);
}

void main() {
  setUpAll(() async {
    await BaseUnitTest.setupUnit();
  });

  setUp(() {
    production.ServiceLocator.initialize(DIContainer());
  });

  tearDown(() {
    final getIt = GetIt.instance;
    if (getIt.isRegistered<AnomalyRepository>()) {
      getIt.unregister<AnomalyRepository>();
    }
    if (getIt.isRegistered<ParseEventsRepository>()) {
      getIt.unregister<ParseEventsRepository>();
    }
    production.ServiceLocator.reset();
  });

  group('AnomalyBanner', () {
    testWidgets('shows an error with a retry when the read fails', (
      tester,
    ) async {
      _register(AnomalyRepository(firestore: FailingFirestore()));
      await tester.pumpWidget(
        createLocalizedTestApp(child: const AnomalyBanner()),
      );
      await tester.pumpAndSettle();

      expect(find.byType(InlineError), findsOneWidget);
      expect(find.text(_errorText), findsOneWidget);
      expect(find.text('Försök igen'), findsOneWidget);
    });

    testWidgets('retry clears the error once the read succeeds', (
      tester,
    ) async {
      _register(AnomalyRepository(firestore: FailingFirestore()));
      await tester.pumpWidget(
        createLocalizedTestApp(child: const AnomalyBanner()),
      );
      await tester.pumpAndSettle();
      expect(find.byType(InlineError), findsOneWidget);

      _register(AnomalyRepository(firestore: FakeFirebaseFirestore()));
      await tester.tap(find.text('Försök igen'));
      await tester.pumpAndSettle();

      expect(find.byType(InlineError), findsNothing);
    });

    testWidgets('no anomaly docs shows nothing, not an error', (tester) async {
      _register(AnomalyRepository(firestore: FakeFirebaseFirestore()));
      await tester.pumpWidget(
        createLocalizedTestApp(child: const AnomalyBanner()),
      );
      await tester.pumpAndSettle();

      expect(find.byType(InlineError), findsNothing);
    });
  });

  group('metric drill-down', () {
    Future<void> openSheet(WidgetTester tester) async {
      await tester.pumpWidget(
        createLocalizedTestApp(
          child: Builder(
            builder: (context) => TextButton(
              onPressed: () => handleMetricDrilldown(
                context,
                MetricDrilldownKind.parseEventsByDomain,
                'koket.se',
              ),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }

    testWidgets('a failed read says so instead of "no attempts logged"', (
      tester,
    ) async {
      _register(ParseEventsRepository(firestore: FailingFirestore()));
      await openSheet(tester);

      expect(find.text(_errorText), findsOneWidget);
      expect(find.text('Inga importförsök loggade'), findsNothing);
    });

    testWidgets('retry loads the events after a failed read', (tester) async {
      _register(ParseEventsRepository(firestore: FailingFirestore()));
      await openSheet(tester);

      _register(ParseEventsRepository(firestore: FakeFirebaseFirestore()));
      await tester.tap(find.text('Försök igen'));
      await tester.pumpAndSettle();

      expect(find.text(_errorText), findsNothing);
      expect(find.text('Inga importförsök loggade'), findsOneWidget);
    });
  });
}
