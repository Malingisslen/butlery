/// BUT-1031: widget tests for [ConflictBanner] — the only user-visible surface
/// of the silent-conflict feature.
///
/// The banner subscribes to [RealtimeSyncService.conflictStream], filters by an
/// optional [ConflictBanner.filterDocId], renders a localized message, exposes a
/// "View" action only when [ConflictBanner.onViewChange] is non-null, and
/// dismisses on the close button. A broken subscription, a wrong filter, or a
/// missing l10n key would otherwise ship silently — these tests pin that
/// contract.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/providers/application_provider.dart' as prod;
import 'package:butlery/models/realtime/realtime_resource.dart';
import 'package:butlery/services/realtime/realtime_types.dart';
import 'package:butlery/services/realtime_sync_service.dart';
import 'package:butlery/widgets/realtime/conflict_banner.dart';

import '../../infrastructure/helpers/widget_test_app.dart';

class _MockRealtimeSyncService extends Mock implements RealtimeSyncService {}

class _FakeResource extends Fake implements RealtimeResource {}

ConflictEvent _event({String docId = 'doc-1'}) => ConflictEvent(
      collectionPath: 'recipes',
      docId: docId,
      localValue: _FakeResource(),
      remoteValue: _FakeResource(),
      chosenStrategy: ConflictResolutionStrategy.localWon,
      occurredAt: DateTime(2026, 5, 28),
    );

void main() {
  late _MockRealtimeSyncService service;
  late StreamController<ConflictEvent> conflicts;

  setUp(() async {
    await GetIt.instance.reset();
    conflicts = StreamController<ConflictEvent>.broadcast();
    service = _MockRealtimeSyncService();
    when(() => service.conflictStream).thenAnswer((_) => conflicts.stream);

    GetIt.instance.registerSingleton<RealtimeSyncService>(service);
    // The widget resolves the service via the production ServiceLocator, which
    // shares GetIt.instance with the registration above.
    prod.ServiceLocator.initialize(DIContainer());
  });

  tearDown(() async {
    prod.ServiceLocator.reset();
    await conflicts.close();
    await GetIt.instance.reset();
  });

  // Captures the live l10n strings so assertions never hardcode copy that can
  // drift from the ARB files.
  late String message;
  late String dismissTooltip;
  late String viewLabel;

  Widget harness({String? filterDocId, VoidCallback? onViewChange}) {
    return createLocalizedTestApp(
      child: Builder(
        builder: (context) {
          message = context.l10n.conflictBannerMessage;
          dismissTooltip = context.l10n.a11yConflictBannerDismiss;
          viewLabel = context.l10n.commonView;
          return ConflictBanner(
            filterDocId: filterDocId,
            onViewChange: onViewChange,
          );
        },
      ),
    );
  }

  testWidgets('renders nothing before any conflict event', (tester) async {
    await tester.pumpWidget(harness());
    await tester.pump();

    expect(find.text(message), findsNothing);
    expect(find.byIcon(Icons.sync_problem), findsNothing);
    expect(find.byType(SizedBox), findsWidgets); // SizedBox.shrink placeholder
  });

  testWidgets('shows the localized banner when a conflict event arrives',
      (tester) async {
    await tester.pumpWidget(harness());
    await tester.pump();

    conflicts.add(_event());
    await tester.pumpAndSettle();

    expect(find.text(message), findsOneWidget);
    expect(find.byIcon(Icons.sync_problem), findsOneWidget);
  });

  testWidgets('filterDocId ignores events for other documents', (tester) async {
    await tester.pumpWidget(harness(filterDocId: 'mine'));
    await tester.pump();

    conflicts.add(_event(docId: 'someone-else'));
    await tester.pumpAndSettle();
    expect(find.text(message), findsNothing,
        reason: 'event for a different doc must be filtered out');

    conflicts.add(_event(docId: 'mine'));
    await tester.pumpAndSettle();
    expect(find.text(message), findsOneWidget,
        reason: 'event for the matching doc must surface');
  });

  testWidgets('dismiss button hides the banner', (tester) async {
    await tester.pumpWidget(harness());
    await tester.pump();

    conflicts.add(_event());
    await tester.pumpAndSettle();
    expect(find.text(message), findsOneWidget);

    await tester.tap(find.byTooltip(dismissTooltip));
    await tester.pump();

    expect(find.text(message), findsNothing);
  });

  testWidgets('View action is hidden when onViewChange is null',
      (tester) async {
    await tester.pumpWidget(harness());
    await tester.pump();

    conflicts.add(_event());
    await tester.pumpAndSettle();

    // The banner itself must be visible — otherwise the absent View button
    // would be a false pass.
    expect(find.text(message), findsOneWidget);
    expect(find.widgetWithText(TextButton, viewLabel), findsNothing);
  });

  testWidgets('View action appears and fires when onViewChange is provided',
      (tester) async {
    var tapped = 0;
    await tester.pumpWidget(harness(onViewChange: () => tapped++));
    await tester.pump();

    conflicts.add(_event());
    await tester.pumpAndSettle();

    final viewButton = find.widgetWithText(TextButton, viewLabel);
    expect(viewButton, findsOneWidget);

    await tester.tap(viewButton);
    await tester.pump();
    expect(tapped, 1);
  });
}
