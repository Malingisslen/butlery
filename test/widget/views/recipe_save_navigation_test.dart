// BUT-900 follow-on: after a NEW recipe is saved from the create/import form,
// the user should land on the new recipe's detail page (so they see what they
// made), not be dropped back on the add-recipe picker. Onboarding is the one
// exception — it must keep driving its own flow, so it opts out and the form
// pops the saved recipe back instead.
//
// BUT-1779: the earlier version of this file pinned the BUG. It asserted the
// pushed argument was the bare id `'recipe-nav-1'`, and used a MaterialApp
// `routes:` map — which never looks at `arguments` at all, so the stub rendered
// happily while the real app rendered "Sidan kunde inte hittas". These tests now
// push through an `onGenerateRoute` that decodes the argument the way
// `AppRouter.generateRoute` does for `Routes.recipeDetail`, so a bare id lands
// on the error screen exactly as it does in production.
//
// Why `AppRouter.generateRoute` itself cannot be called here:
// `Routes.recipeDetail` is in `Routes.authenticatedRoutes`, so `generateRoute`
// hits `FirebaseAuthRepository()` → `FirebaseAuth.instance` before it ever
// reaches the recipe-detail branch. With no Firebase app in a `flutter test`
// host that throws, and `generateRoute`'s own try/catch converts it into the
// generic error route. Verified by probe: the real router returns an error route
// for a perfectly valid Recipe argument, so it cannot tell the fix from the bug.
// The decode below therefore calls `decodeRecipeDetailRouteArgs`, the same
// function `generateRoute` calls, instead of copying it.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/core/constants/routes.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/core/router/recipe_detail_route_args.dart';
import 'package:butlery/views/recipe_detail/recipe_save_navigation.dart';

import '../../infrastructure/factories/recipe_factory.dart';

class _NavSpy extends NavigatorObserver {
  final List<Route<dynamic>> replaced = [];
  final List<Route<dynamic>> popped = [];

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    if (newRoute != null) replaced.add(newRoute);
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    popped.add(route);
    super.didPop(route, previousRoute);
  }
}

const _detailMarker = 'detail-for';
const _errorMarker = 'route-error';

/// Routes `Routes.recipeDetail` through the production decoder: anything that
/// is neither a Recipe nor a Map carrying one under 'recipe' — notably a bare
/// id String — decodes to a null recipe and falls through to the error route.
Route<dynamic>? _routerLikeOnGenerateRoute(RouteSettings settings) {
  if (settings.name != Routes.recipeDetail) return null;

  // The decode is the production function, not a copy, so this cannot drift
  // from it. Its own contract is pinned in
  // test/unit/core/router/recipe_detail_route_args_test.dart; what this suite
  // adds is the callers. Only the two markers below are local, so a route can
  // be asserted on without building RecipeDetailView and its DI graph.
  final recipe = decodeRecipeDetailRouteArgs(settings.arguments).recipe;
  if (recipe == null) {
    return MaterialPageRoute<void>(
      settings: settings,
      builder: (_) => const Scaffold(body: Text(_errorMarker)),
    );
  }
  final resolved = recipe;
  return MaterialPageRoute<void>(
    settings: settings,
    builder: (_) => Scaffold(body: Text('$_detailMarker:${resolved.title}')),
  );
}

void main() {
  late Recipe recipe;

  setUp(() {
    recipe = RecipeFactory.build(id: 'recipe-nav-1', title: 'Pannkakor');
  });

  testWidgets(
    'navigateToDetail: true replaces the form with the recipe detail the '
    'router can actually build',
    (tester) async {
      final spy = _NavSpy();
      await tester.pumpWidget(
        MaterialApp(
          navigatorObservers: [spy],
          onGenerateRoute: _routerLikeOnGenerateRoute,
          home: Builder(
            builder: (ctx) => Scaffold(
              body: ElevatedButton(
                onPressed: () => RecipeSaveNavigation.afterSuccessfulSave(
                  ctx,
                  recipe,
                  navigateToDetail: true,
                ),
                child: const Text('save'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('save'));
      await tester.pumpAndSettle();

      expect(spy.replaced, hasLength(1));
      expect(spy.replaced.single.settings.name, Routes.recipeDetail);
      // BUT-1779: the Recipe itself, not its id — the router decodes anything
      // else to null.
      expect(spy.replaced.single.settings.arguments, same(recipe));
      // And the route the router built is the detail, not the error screen.
      expect(find.text('$_detailMarker:Pannkakor'), findsOneWidget);
      expect(find.text(_errorMarker), findsNothing);
      expect(find.text('save'), findsNothing);
    },
  );

  testWidgets(
    'the bare id this used to pass would land on the error route (guards the '
    'decode actually discriminates)',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          onGenerateRoute: _routerLikeOnGenerateRoute,
          home: Builder(
            builder: (ctx) => Scaffold(
              body: ElevatedButton(
                onPressed: () => Navigator.of(ctx).pushReplacementNamed(
                  Routes.recipeDetail,
                  arguments: recipe.id,
                ),
                child: const Text('save'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('save'));
      await tester.pumpAndSettle();

      expect(find.text(_errorMarker), findsOneWidget);
      expect(find.textContaining(_detailMarker), findsNothing);
    },
  );

  testWidgets(
    'navigateToDetail: false pops back with the saved recipe (onboarding keeps '
    'driving its own flow)',
    (tester) async {
      final spy = _NavSpy();
      Recipe? popped;
      await tester.pumpWidget(
        MaterialApp(
          navigatorObservers: [spy],
          onGenerateRoute: _routerLikeOnGenerateRoute,
          home: Builder(
            builder: (ctx) => Scaffold(
              body: ElevatedButton(
                onPressed: () async {
                  popped = await Navigator.of(ctx).push<Recipe>(
                    MaterialPageRoute(
                      builder: (formCtx) => Scaffold(
                        body: ElevatedButton(
                          onPressed: () =>
                              RecipeSaveNavigation.afterSuccessfulSave(
                                formCtx,
                                recipe,
                                navigateToDetail: false,
                              ),
                          child: const Text('save'),
                        ),
                      ),
                    ),
                  );
                },
                child: const Text('open form'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open form'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('save'));
      await tester.pumpAndSettle();

      // The form popped, handing the saved recipe back to its opener.
      expect(popped, recipe);
      expect(spy.popped, isNotEmpty);
      // No detail route was pushed in this branch.
      expect(
        spy.replaced.where((r) => r.settings.name == Routes.recipeDetail),
        isEmpty,
      );
    },
  );
}
