/// BUT-1031: widget tests for [ConflictBanner] — the only user-visible surface
/// of the silent-conflict feature.
///
/// The banner subscribes to [RealtimeSyncService.conflictStream], filters by an
/// optional [ConflictBanner.filterDocId], renders the drawn title and body, exposes a
/// "View" action for the active event (BUT-1163: self-wired to the built-in
/// diff view, with [ConflictBanner.onViewChange] as an optional override), and
/// dismisses on the close button. A broken subscription, a wrong filter, or a
/// missing l10n key would otherwise ship silently — these tests pin that
/// contract.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/providers/application_provider.dart' as prod;
import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/models/realtime/realtime_resource.dart';
import 'package:butlery/services/realtime/realtime_types.dart';
import 'package:butlery/services/realtime_sync_service.dart';
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/widgets/realtime/conflict_banner.dart';

import '../../infrastructure/helpers/widget_test_app.dart';

class _MockRealtimeSyncService extends Mock implements RealtimeSyncService {}

class _FakeResource extends Fake implements RealtimeResource {
  _FakeResource([this.lastEditedByDisplayName = 'Per']);

  @override
  final String lastEditedByDisplayName;
}

ConflictEvent _event({
  String docId = 'doc-1',
  ConflictEntity entity = ConflictEntity.recipeOwn,
  String editor = 'Per',
}) => ConflictEvent(
  collectionPath: 'recipes',
  docId: docId,
  localValue: _FakeResource(),
  remoteValue: _FakeResource(editor),
  chosenStrategy: ConflictResolutionStrategy.localWon,
  entity: entity,
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
  late String weekTitle;
  late String body;
  late String unnamedBody;
  late String dismissTooltip;
  late String viewLabel;

  Widget harness({String? filterDocId, VoidCallback? onViewChange}) {
    return createLocalizedTestApp(
      child: Builder(
        builder: (context) {
          message = context.l10n.conflictBannerTitleRecipe;
          weekTitle = context.l10n.conflictBannerTitleWeek;
          body = context.l10n.conflictBannerBody('Per');
          unnamedBody = context.l10n.conflictBannerBodyUnnamed;
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
    expect(find.byIcon(Icons.warning_amber_rounded), findsNothing);
    expect(find.byType(SizedBox), findsWidgets); // SizedBox.shrink placeholder
  });

  testWidgets('shows the localized banner when a conflict event arrives', (
    tester,
  ) async {
    await tester.pumpWidget(harness());
    await tester.pump();

    conflicts.add(_event());
    await tester.pumpAndSettle();

    expect(find.text(message), findsOneWidget);
    expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
  });

  testWidgets('filterDocId ignores events for other documents', (tester) async {
    await tester.pumpWidget(harness(filterDocId: 'mine'));
    await tester.pump();

    conflicts.add(_event(docId: 'someone-else'));
    await tester.pumpAndSettle();
    expect(
      find.text(message),
      findsNothing,
      reason: 'event for a different doc must be filtered out',
    );

    conflicts.add(_event(docId: 'mine'));
    await tester.pumpAndSettle();
    expect(
      find.text(message),
      findsOneWidget,
      reason: 'event for the matching doc must surface',
    );
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

  testWidgets(
    'View action is always shown for an active event (BUT-1163: built-in '
    'diff view, no callback required)',
    (tester) async {
      await tester.pumpWidget(harness());
      await tester.pump();

      conflicts.add(_event());
      await tester.pumpAndSettle();

      expect(find.text(message), findsOneWidget);
      // The banner now self-wires navigation to ConflictDiffView, so the View
      // action no longer depends on an injected onViewChange callback.
      expect(find.widgetWithText(TextButton, viewLabel), findsOneWidget);
    },
  );

  testWidgets(
    'onViewChange override intercepts the View action when provided',
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
    },
  );

  group('P3-U08: drawn anatomy (Komponentark v1:755-758)', () {
    testWidgets('title names the recipe and the body names the other editor', (
      tester,
    ) async {
      await tester.pumpWidget(harness());
      conflicts.add(_event());
      await tester.pumpAndSettle();

      expect(message, 'Två versioner av receptet');
      expect(find.text(message), findsOneWidget);
      expect(find.text(body), findsOneWidget);
      expect(body, startsWith('Per ändrade samtidigt.'));
    });

    testWidgets('a shared recipe uses the own-recipe wording until PQ-02', (
      tester,
    ) async {
      await tester.pumpWidget(harness());
      conflicts.add(_event(entity: ConflictEntity.recipeShared));
      await tester.pumpAndSettle();

      expect(find.text(message), findsOneWidget);
    });

    testWidgets('a week menu gets the week title', (tester) async {
      await tester.pumpWidget(harness());
      conflicts.add(_event(entity: ConflictEntity.weekMenu));
      await tester.pumpAndSettle();

      expect(weekTitle, 'Två versioner av veckan');
      expect(find.text(weekTitle), findsOneWidget);
      expect(find.text(message), findsNothing);
    });

    testWidgets('an unknown editor name falls back to a nameless body', (
      tester,
    ) async {
      await tester.pumpWidget(harness());
      conflicts.add(_event(editor: '  '));
      await tester.pumpAndSettle();

      expect(find.text(unnamedBody), findsOneWidget);
    });

    testWidgets('the banner is one live region per event', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(harness());
      conflicts.add(_event());
      await tester.pumpAndSettle();

      final liveRegions = find.byWidgetPredicate(
        (w) => w is Semantics && (w.properties.liveRegion ?? false),
      );
      expect(liveRegions, findsOneWidget);
      handle.dispose();
    });

    // Token values from tokens.json: text.danger :96-98, text.primary :54-56,
    // text.body :58-60, surface.base :104-106.
    for (final (mode, danger, primary, bodyText, surface) in [
      (
        ThemeMode.light,
        const Color(0xFF9C3B23),
        const Color(0xFF24382C),
        const Color(0xFF37453A),
        const Color(0xFFF5F4ED),
      ),
      (
        ThemeMode.dark,
        const Color(0xFFDE9078),
        const Color(0xFFF5F4ED),
        const Color(0xFFF5F4ED),
        const Color(0xFF17251D),
      ),
    ]) {
      testWidgets('colours follow the tokens in ${mode.name} mode', (
        tester,
      ) async {
        late String title;
        late String text;
        await tester.pumpWidget(
          MaterialApp(
            locale: const Locale('sv'),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: mode,
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  title = context.l10n.conflictBannerTitleRecipe;
                  text = context.l10n.conflictBannerBody('Per');
                  return const ConflictBanner();
                },
              ),
            ),
          ),
        );
        conflicts.add(_event());
        await tester.pumpAndSettle();

        final material = tester.widget<Material>(
          find
              .ancestor(of: find.text(title), matching: find.byType(Material))
              .first,
        );
        expect(material.color, surface);
        final shape = material.shape! as Border;
        expect(shape.top.color, danger);
        expect(shape.top.width, 1.0);
        expect(
          tester.widget<Icon>(find.byIcon(Icons.warning_amber_rounded)).color,
          danger,
        );
        final titleText = tester.widget<Text>(find.text(title));
        expect(titleText.style!.color, primary);
        expect(titleText.style!.fontWeight, FontWeight.w700);
        expect(tester.widget<Text>(find.text(text)).style!.color, bodyText);
      });
    }
  });
}
