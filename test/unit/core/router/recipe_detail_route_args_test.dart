import 'package:butlery/core/router/recipe_detail_route_args.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/social_request.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pins the decode `AppRouter.generateRoute` uses for `Routes.recipeDetail`.
///
/// It lives in its own file rather than inside the router's argument-passing
/// so two widget suites can exercise the same decode without building the
/// view/DI graph. That reuse is why the contract needs a direct test: before
/// BUT-1804 each suite carried a hand-written copy, and a copy cannot redden
/// when the original changes.
///
/// Both live shapes are covered. `fcm_service` pushes a bare `Recipe` normally
/// and a Map when a notification asks to scroll to comments, so neither branch
/// is hypothetical.
void main() {
  Recipe recipe(String id) => Recipe(
    core: RecipeCore(
      id: id,
      title: 'Pannkakor',
      description: '',
      ingredients: const ['ägg'],
      instructions: const [],
      mealType: 'Middag',
    ),
    type: RecipeType.personal,
  );

  group('decodeRecipeDetailRouteArgs', () {
    test('a bare Recipe decodes to that recipe and the defaults', () {
      final args = decodeRecipeDetailRouteArgs(recipe('r1'));

      expect(args.recipe?.id, 'r1');
      expect(args.scrollToComments, isFalse);
      expect(args.readOnly, isFalse);
      expect(args.shareRequest, isNull);
      expect(args.presentServings, isNull);
    });

    test('a Map carries the recipe and every optional field', () {
      final share = SocialRequest(
        id: 's1',
        fromUserId: 'u1',
        toUserId: 'u2',
        type: SocialRequestType.recipeShareRequest,
      );

      final args = decodeRecipeDetailRouteArgs(<String, dynamic>{
        'recipe': recipe('r2'),
        // Deliberately OPPOSITE values: with both true, a decoder that read
        // 'readOnly' into scrollToComments and vice versa would pass every case
        // in this file. Both flags are live and independent — feed_tab sends
        // only readOnly, fcm_service only scrollToComments.
        'scrollToComments': true,
        'readOnly': false,
        'shareRequest': share,
        'presentServings': 3,
      });

      expect(args.recipe?.id, 'r2');
      expect(args.scrollToComments, isTrue);
      expect(args.readOnly, isFalse);
      expect(args.shareRequest?.id, 's1');
      expect(args.presentServings, 3);
    });

    test('a Map may omit every optional field', () {
      final args = decodeRecipeDetailRouteArgs(<String, dynamic>{
        'recipe': recipe('r3'),
      });

      expect(args.recipe?.id, 'r3');
      expect(args.scrollToComments, isFalse);
      expect(args.readOnly, isFalse);
      expect(args.shareRequest, isNull);
      expect(args.presentServings, isNull);
    });

    // BUT-1779: four save paths pushed the id instead of the object, and the
    // route showed an error screen. A null recipe is the caller's signal to
    // error-route, so this is the case the whole decode exists to make legible.
    test('a bare id String decodes to a null recipe', () {
      expect(decodeRecipeDetailRouteArgs('r4').recipe, isNull);
    });

    test('null and an unrelated type decode to a null recipe', () {
      expect(decodeRecipeDetailRouteArgs(null).recipe, isNull);
      expect(decodeRecipeDetailRouteArgs(42).recipe, isNull);
    });

    test('a Map with no recipe key decodes to a null recipe', () {
      expect(decodeRecipeDetailRouteArgs(<String, dynamic>{}).recipe, isNull);
    });

    // The two bad shapes are NOT equivalent, and this pins which is which.
    // A missing key decodes to null; a wrongly-typed value THROWS on the cast.
    // Both are caught by `AppRouter.generateRoute`'s try/catch and error-route,
    // so the throw does not reach the user — but the two screens read
    // differently, and the cast one puts a raw Dart type error on it. The
    // extraction under BUT-1804 preserved this rather than making the cast
    // total; changing it is a behaviour change and belongs to its own ticket.
    //
    // The catch lives in `generateRoute`, not in the decoder, so a caller
    // outside the router — these tests, and any future one — sees the throw.
    test('a Map whose recipe is the wrong type throws on the cast', () {
      expect(
        () => decodeRecipeDetailRouteArgs(<String, dynamic>{'recipe': 'r5'}),
        throwsA(isA<TypeError>()),
      );
    });
  });
}
