// BUT-900 follow-on: after a NEW recipe is saved from the create/import form,
// the user should land on the new recipe's detail page (so they see what they
// made), not be dropped back on the add-recipe picker. Onboarding is the one
// exception — it must keep driving its own flow, so it opts out and the form
// pops the saved recipe back instead.
//
// This pins that decision in isolation (RecipeSaveNavigation), away from the
// heavy recipe-form ViewModel/validation/celebration machinery, so the contract
// is cheap to assert and won't rot.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/core/constants/routes.dart';
import 'package:butlery/models/recipe_unified.dart';
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

void main() {
  late Recipe recipe;

  setUp(() {
    recipe = RecipeFactory.build(id: 'recipe-nav-1', title: 'Pannkakor');
  });

  testWidgets(
    'navigateToDetail: true replaces the form with the new recipe detail '
    '(carrying the saved id)',
    (tester) async {
      final spy = _NavSpy();
      await tester.pumpWidget(
        MaterialApp(
          navigatorObservers: [spy],
          routes: {
            Routes.recipeDetail: (_) =>
                const Scaffold(body: Text('detail-stub')),
          },
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

      // The recipe-detail route replaced the form, with the saved id as argument.
      expect(spy.replaced, hasLength(1));
      expect(spy.replaced.single.settings.name, Routes.recipeDetail);
      expect(spy.replaced.single.settings.arguments, 'recipe-nav-1');
      // User now sees the detail, not the form button.
      expect(find.text('detail-stub'), findsOneWidget);
      expect(find.text('save'), findsNothing);
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
          routes: {
            Routes.recipeDetail: (_) =>
                const Scaffold(body: Text('detail-stub')),
          },
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
