/// Widget tests for LoadingStateBuilder + LoadingStateBuilderUtils factories.
///
/// Verifies the state-priority contract (error > loading > empty > data),
/// custom builder overrides, generic-empty fallback, predefined empty-state
/// variants, the isDataEmpty hook, and that the convenience factories wire
/// EmptyStateVariant correctly.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/widgets/common/loading_state_builder.dart';
import 'package:butlery/widgets/common/state_widget.dart';

Widget _wrap(Widget child) => MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('sv'),
      home: Scaffold(body: child),
    );

void main() {
  // ---------------------------------------------------------------------------
  // ERROR STATE (highest priority)
  // ---------------------------------------------------------------------------
  group('error state', () {
    testWidgets(
        'error wins over loading + data → renders StateWidget with error type',
        (tester) async {
      await tester.pumpWidget(_wrap(
        LoadingStateBuilder<List<String>>(
          isLoading: true, // even when loading
          error: 'Något gick fel',
          data: const ['hej'], // and data present
          builder: (_, __) => const Text('should-not-render'),
          onErrorRetry: () {}, // wire onAction so retry button renders
        ),
      ));
      // CircularProgressIndicator never settles → use pump.
      await tester.pump();

      expect(find.text('Något gick fel'), findsOneWidget);
      expect(find.byType(StateWidget), findsOneWidget);
      expect(find.text('should-not-render'), findsNothing);
      // Default Swedish retry label from l10n (commonRetry = "Försök igen")
      expect(find.text('Försök igen'), findsOneWidget);
    });

    testWidgets('custom errorActionLabel overrides default retry label',
        (tester) async {
      await tester.pumpWidget(_wrap(
        LoadingStateBuilder<String>(
          isLoading: false,
          error: 'boom',
          builder: (_, __) => const SizedBox.shrink(),
          errorActionLabel: 'Försök en gång till',
          onErrorRetry: () {}, // wire onAction so retry button renders
        ),
      ));
      await tester.pump();
      expect(find.text('Försök en gång till'), findsOneWidget);
      expect(find.text('Försök igen'), findsNothing);
    });

    testWidgets('onErrorRetry callback fires when action tapped',
        (tester) async {
      int taps = 0;
      await tester.pumpWidget(_wrap(
        LoadingStateBuilder<String>(
          isLoading: false,
          error: 'boom',
          builder: (_, __) => const SizedBox.shrink(),
          onErrorRetry: () => taps++,
        ),
      ));
      await tester.pump();
      await tester.tap(find.text('Försök igen'));
      await tester.pump();
      expect(taps, 1);
    });

    testWidgets('custom errorBuilder fully replaces default StateWidget',
        (tester) async {
      await tester.pumpWidget(_wrap(
        LoadingStateBuilder<String>(
          isLoading: false,
          error: 'X',
          builder: (_, __) => const SizedBox.shrink(),
          errorBuilder: (ctx, e) => Text('custom-error:$e'),
        ),
      ));
      expect(find.text('custom-error:X'), findsOneWidget);
      expect(find.byType(StateWidget), findsNothing);
    });
  });

  // ---------------------------------------------------------------------------
  // LOADING STATE
  // ---------------------------------------------------------------------------
  group('loading state', () {
    testWidgets('isLoading=true with no error → renders default loading widget',
        (tester) async {
      await tester.pumpWidget(_wrap(
        LoadingStateBuilder<List<String>>(
          isLoading: true,
          builder: (_, __) => const Text('data-view'),
        ),
      ));
      // Pea animation/spinner — don't pumpAndSettle.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(StateWidget), findsOneWidget);
      expect(find.text('data-view'), findsNothing);
    });

    testWidgets('loadingMessage renders inside StateWidget', (tester) async {
      await tester.pumpWidget(_wrap(
        LoadingStateBuilder<String>(
          isLoading: true,
          loadingMessage: 'Genererar meny...',
          loadingVariant: LoadingVariant.spinner,
          builder: (_, __) => const SizedBox.shrink(),
        ),
      ));
      await tester.pump();
      expect(find.text('Genererar meny...'), findsOneWidget);
    });

    testWidgets('skeletonRecipeList variant uses ListView skeleton',
        (tester) async {
      await tester.pumpWidget(_wrap(
        LoadingStateBuilder<List<String>>(
          isLoading: true,
          loadingVariant: LoadingVariant.skeletonRecipeList,
          skeletonItemCount: 3,
          builder: (_, __) => const SizedBox.shrink(),
        ),
      ));
      await tester.pump();
      // Skeleton list builds N Card placeholders.
      expect(find.byType(Card), findsNWidgets(3));
    });

    testWidgets('custom loadingBuilder fully replaces default', (tester) async {
      await tester.pumpWidget(_wrap(
        LoadingStateBuilder<String>(
          isLoading: true,
          builder: (_, __) => const SizedBox.shrink(),
          loadingBuilder: (_) => const Text('custom-loader'),
        ),
      ));
      expect(find.text('custom-loader'), findsOneWidget);
      expect(find.byType(StateWidget), findsNothing);
    });
  });

  // ---------------------------------------------------------------------------
  // EMPTY STATE
  // ---------------------------------------------------------------------------
  group('empty state — generic fallback', () {
    testWidgets('null data → generic empty state with default title',
        (tester) async {
      await tester.pumpWidget(_wrap(
        LoadingStateBuilder<List<String>>(
          isLoading: false,
          data: null,
          builder: (_, __) => const Text('builder-should-not-render'),
        ),
      ));
      await tester.pump();
      // Default Swedish title = loadingNoContent = "Inget innehåll"
      expect(find.text('Inget innehåll'), findsOneWidget);
      expect(find.text('builder-should-not-render'), findsNothing);
    });

    testWidgets('empty List → generic empty state', (tester) async {
      await tester.pumpWidget(_wrap(
        LoadingStateBuilder<List<String>>(
          isLoading: false,
          data: const <String>[],
          builder: (_, __) => const Text('hidden'),
        ),
      ));
      await tester.pump();
      expect(find.text('Inget innehåll'), findsOneWidget);
      expect(find.text('hidden'), findsNothing);
    });

    testWidgets('empty Map → generic empty state', (tester) async {
      await tester.pumpWidget(_wrap(
        LoadingStateBuilder<Map<String, int>>(
          isLoading: false,
          data: const <String, int>{},
          builder: (_, __) => const Text('hidden'),
        ),
      ));
      await tester.pump();
      expect(find.text('Inget innehåll'), findsOneWidget);
    });

    testWidgets('empty String → generic empty state', (tester) async {
      await tester.pumpWidget(_wrap(
        LoadingStateBuilder<String>(
          isLoading: false,
          data: '',
          builder: (_, __) => const Text('hidden'),
        ),
      ));
      await tester.pump();
      expect(find.text('Inget innehåll'), findsOneWidget);
    });

    testWidgets('custom emptyTitle/Subtitle/Icon/ActionLabel render',
        (tester) async {
      int taps = 0;
      await tester.pumpWidget(_wrap(
        LoadingStateBuilder<List<String>>(
          isLoading: false,
          data: const [],
          builder: (_, __) => const SizedBox.shrink(),
          emptyTitle: 'Tomt här',
          emptySubtitle: 'Lägg till något',
          emptyIcon: Icons.search_off,
          emptyActionLabel: 'Lägg till',
          onEmptyAction: () => taps++,
        ),
      ));
      await tester.pump();

      expect(find.text('Tomt här'), findsOneWidget);
      expect(find.text('Lägg till något'), findsOneWidget);
      expect(find.byIcon(Icons.search_off), findsOneWidget);

      await tester.tap(find.text('Lägg till'));
      await tester.pump();
      expect(taps, 1);
    });

    testWidgets('custom emptyBuilder fully replaces default', (tester) async {
      await tester.pumpWidget(_wrap(
        LoadingStateBuilder<List<String>>(
          isLoading: false,
          data: const [],
          builder: (_, __) => const SizedBox.shrink(),
          emptyBuilder: (_) => const Text('custom-empty'),
        ),
      ));
      expect(find.text('custom-empty'), findsOneWidget);
    });

    testWidgets(
        'showEmptyWhenNull=false + null data → falls through to '
        'fallback empty (data branch never reached)', (tester) async {
      // When data is null and showEmptyWhenNull is false, the build path
      // skips the empty branch, then `data != null` is false → falls through
      // to the bottom fallback (which is also an empty state).
      await tester.pumpWidget(_wrap(
        LoadingStateBuilder<List<String>>(
          isLoading: false,
          data: null,
          showEmptyWhenNull: false,
          builder: (_, __) => const Text('hidden'),
        ),
      ));
      await tester.pump();
      expect(find.text('hidden'), findsNothing);
      // Fallback also defaults to "Inget innehåll"
      expect(find.text('Inget innehåll'), findsOneWidget);
    });

    testWidgets(
        'showEmptyWhenNull=false + non-null empty list → renders builder '
        '(empty check skipped)', (tester) async {
      await tester.pumpWidget(_wrap(
        LoadingStateBuilder<List<String>>(
          isLoading: false,
          data: const <String>[],
          showEmptyWhenNull: false,
          builder: (_, list) => Text('rendered ${list.length}'),
        ),
      ));
      await tester.pump();
      expect(find.text('rendered 0'), findsOneWidget);
    });

    testWidgets('custom isDataEmpty predicate forces empty branch',
        (tester) async {
      await tester.pumpWidget(_wrap(
        LoadingStateBuilder<int>(
          isLoading: false,
          data: 0, // not null, not a List/Map/String — would normally render
          isDataEmpty: (v) => v == 0,
          builder: (_, v) => Text('value:$v'),
        ),
      ));
      await tester.pump();
      expect(find.text('value:0'), findsNothing);
      expect(find.text('Inget innehåll'), findsOneWidget);
    });

    testWidgets('non-empty data renders builder (success path)',
        (tester) async {
      await tester.pumpWidget(_wrap(
        LoadingStateBuilder<List<String>>(
          isLoading: false,
          data: const ['a', 'b'],
          builder: (_, list) => Text('items:${list.length}'),
        ),
      ));
      await tester.pump();
      expect(find.text('items:2'), findsOneWidget);
    });
  });

  // ---------------------------------------------------------------------------
  // PREDEFINED EMPTY VARIANTS — exercise the switch in _buildPredefinedEmptyState
  // ---------------------------------------------------------------------------
  group('predefined empty state variants', () {
    Future<void> pumpWithVariant(
      WidgetTester tester,
      EmptyStateVariant variant,
    ) async {
      await tester.pumpWidget(_wrap(
        LoadingStateBuilder<List<String>>(
          isLoading: false,
          data: const [],
          emptyState: variant,
          builder: (_, __) => const SizedBox.shrink(),
        ),
      ));
      await tester.pump();
    }

    testWidgets('noRecipes → StateWidget rendered', (tester) async {
      await pumpWithVariant(tester, EmptyStateVariant.noRecipes);
      expect(find.byType(StateWidget), findsOneWidget);
    });

    testWidgets('noSearchResults → StateWidget rendered', (tester) async {
      await pumpWithVariant(tester, EmptyStateVariant.noSearchResults);
      expect(find.byType(StateWidget), findsOneWidget);
    });

    testWidgets('noFriendsSearchResults → StateWidget rendered',
        (tester) async {
      await pumpWithVariant(tester, EmptyStateVariant.noFriendsSearchResults);
      expect(find.byType(StateWidget), findsOneWidget);
    });

    testWidgets('noGroupsSearchResults → StateWidget rendered', (tester) async {
      await pumpWithVariant(tester, EmptyStateVariant.noGroupsSearchResults);
      expect(find.byType(StateWidget), findsOneWidget);
    });

    testWidgets('noMenu → StateWidget rendered', (tester) async {
      await pumpWithVariant(tester, EmptyStateVariant.noMenu);
      expect(find.byType(StateWidget), findsOneWidget);
    });

    testWidgets('noShoppingList → StateWidget rendered', (tester) async {
      await pumpWithVariant(tester, EmptyStateVariant.noShoppingList);
      expect(find.byType(StateWidget), findsOneWidget);
    });

    testWidgets('noFriends → StateWidget rendered', (tester) async {
      await pumpWithVariant(tester, EmptyStateVariant.noFriends);
      expect(find.byType(StateWidget), findsOneWidget);
    });

    testWidgets(
        'every EmptyStateVariant renders a StateWidget without crashing',
        (tester) async {
      // Several of these variants (noGroups, noConversations, noNotifications,
      // noComments) gained branded titles via BUT-979/BUT-986 and no longer
      // fall through to the generic title. We assert structural presence —
      // each variant must produce a StateWidget — not title text, which is
      // brittle to l10n / branding changes.
      for (final v in [
        EmptyStateVariant.noCategories,
        EmptyStateVariant.noImages,
        EmptyStateVariant.noTargets,
        EmptyStateVariant.noSavedMenus,
        EmptyStateVariant.noSharedShoppingLists,
        EmptyStateVariant.noTags,
        EmptyStateVariant.noGroups,
        EmptyStateVariant.noConversations,
        EmptyStateVariant.generic,
      ]) {
        await pumpWithVariant(tester, v);
        expect(find.byType(StateWidget), findsOneWidget,
            reason: 'variant=$v should produce one StateWidget');
      }
    });

    testWidgets('predefined variant + emptyActionLabel/onAction wires button',
        (tester) async {
      int taps = 0;
      await tester.pumpWidget(_wrap(
        LoadingStateBuilder<List<String>>(
          isLoading: false,
          data: const [],
          emptyState: EmptyStateVariant.noRecipes,
          emptyActionLabel: 'Lägg till recept',
          onEmptyAction: () => taps++,
          builder: (_, __) => const SizedBox.shrink(),
        ),
      ));
      await tester.pump();
      await tester.tap(find.text('Lägg till recept'));
      await tester.pump();
      expect(taps, 1);
    });
  });

  // ---------------------------------------------------------------------------
  // EXTENSION: withLoadingState
  // ---------------------------------------------------------------------------
  group('LoadingStateBuilderExtensions.withLoadingState', () {
    testWidgets('renders the wrapped widget when data present', (tester) async {
      final wrapped = const Text('extension-content').withLoadingState<String>(
        isLoading: false,
        data: 'value',
      );
      await tester.pumpWidget(_wrap(wrapped));
      await tester.pump();
      expect(find.text('extension-content'), findsOneWidget);
    });

    testWidgets('routes through to error state when error supplied',
        (tester) async {
      final wrapped = const Text('extension-content').withLoadingState<String>(
        isLoading: false,
        error: 'oops',
        data: 'value',
      );
      await tester.pumpWidget(_wrap(wrapped));
      await tester.pump();
      expect(find.text('oops'), findsOneWidget);
      expect(find.text('extension-content'), findsNothing);
    });
  });

  // ---------------------------------------------------------------------------
  // UTILS — convenience factories
  // ---------------------------------------------------------------------------
  group('LoadingStateBuilderUtils.forList', () {
    testWidgets('renders builder when items non-empty', (tester) async {
      final b = LoadingStateBuilderUtils.forList<String>(
        isLoading: false,
        items: const ['a'],
        builder: (_, items) => Text('count:${items.length}'),
      );
      await tester.pumpWidget(_wrap(b));
      await tester.pump();
      expect(find.text('count:1'), findsOneWidget);
    });

    testWidgets('renders generic empty when items empty + no variant',
        (tester) async {
      final b = LoadingStateBuilderUtils.forList<String>(
        isLoading: false,
        items: const [],
        builder: (_, items) => const Text('hidden'),
      );
      await tester.pumpWidget(_wrap(b));
      await tester.pump();
      expect(find.text('Inget innehåll'), findsOneWidget);
    });
  });

  group('LoadingStateBuilderUtils.forRecipeList', () {
    testWidgets('wires EmptyStateVariant.noRecipes when items empty',
        (tester) async {
      final b = LoadingStateBuilderUtils.forRecipeList<String>(
        isLoading: false,
        recipes: const [],
        builder: (_, __) => const Text('hidden'),
      );
      // Inspect the constructed widget directly — no need to pump to assert
      // the wiring contract.
      expect(b, isA<LoadingStateBuilder<List<String>>>());
      expect(b.emptyState, EmptyStateVariant.noRecipes);
      expect(b.loadingVariant, LoadingVariant.skeletonRecipeList);
    });

    testWidgets('renders builder when recipes provided', (tester) async {
      final b = LoadingStateBuilderUtils.forRecipeList<String>(
        isLoading: false,
        recipes: const ['r1', 'r2'],
        builder: (_, recipes) => Text('recipes:${recipes.length}'),
      );
      await tester.pumpWidget(_wrap(b));
      await tester.pump();
      expect(find.text('recipes:2'), findsOneWidget);
    });
  });

  group('LoadingStateBuilderUtils.forFriendList', () {
    testWidgets('wires EmptyStateVariant.noFriends', (tester) async {
      final b = LoadingStateBuilderUtils.forFriendList<String>(
        isLoading: false,
        friends: const [],
        builder: (_, __) => const Text('hidden'),
      );
      expect(b.emptyState, EmptyStateVariant.noFriends);
      expect(b.loadingVariant, LoadingVariant.spinner);
    });
  });

  group('LoadingStateBuilderUtils.forMenu', () {
    testWidgets('wires EmptyStateVariant.noMenu and renders builder',
        (tester) async {
      final b = LoadingStateBuilderUtils.forMenu<String>(
        isLoading: false,
        menuData: 'data',
        builder: (_, d) => Text('menu:$d'),
      );
      expect(b.emptyState, EmptyStateVariant.noMenu);
      await tester.pumpWidget(_wrap(b));
      await tester.pump();
      expect(find.text('menu:data'), findsOneWidget);
    });
  });

  group('LoadingStateBuilderUtils.forShoppingList', () {
    testWidgets('wires EmptyStateVariant.noShoppingList', (tester) async {
      final b = LoadingStateBuilderUtils.forShoppingList<String>(
        isLoading: false,
        items: const [],
        builder: (_, __) => const Text('hidden'),
      );
      expect(b.emptyState, EmptyStateVariant.noShoppingList);
    });
  });

  group('LoadingStateBuilderUtils.dispose', () {
    test('dispose() is a safe no-op (smoke)', () {
      // The dispose method on LoadingStateBuilderUtils is a vestigial no-op
      // (it has no instance state). Just confirm it doesn't throw.
      expect(() => LoadingStateBuilderUtils().dispose(), returnsNormally);
    });
  });
}
