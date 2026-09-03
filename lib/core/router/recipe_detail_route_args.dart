import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/social_request.dart';

/// The decoded `settings.arguments` for `Routes.recipeDetail`.
///
/// Extracted from `AppRouter.generateRoute` so the decision can be exercised
/// without it. `generateRoute` reaches `FirebaseAuth.instance` before the
/// recipe-detail branch and error-routes everything in a `flutter test` host,
/// which is why two suites had hand-copied this decode; a copy cannot redden
/// when the real one changes (BUT-1779, BUT-1804).
///
/// This file imports two models and nothing else on purpose. Importing
/// `app_router.dart` from a widget test pulls in the view and DI graph the
/// suites deliberately do not build.
class RecipeDetailRouteArgs {
  const RecipeDetailRouteArgs({
    this.recipe,
    this.scrollToComments = false,
    this.readOnly = false,
    this.shareRequest,
    this.presentServings,
  });

  final Recipe? recipe;
  final bool scrollToComments;
  final bool readOnly;
  final SocialRequest? shareRequest;

  /// Present count from the weekly-menu calendar, forwarded to cooking mode so
  /// it opens pre-scaled to who's home (BUT-1613).
  final int? presentServings;
}

/// A bare id String decodes to a null [RecipeDetailRouteArgs.recipe], which is
/// the caller's signal to error-route. That case is the BUT-1779 regression:
/// four save paths pushed an id where the route wanted the object.
RecipeDetailRouteArgs decodeRecipeDetailRouteArgs(Object? arguments) {
  if (arguments is Recipe) {
    return RecipeDetailRouteArgs(recipe: arguments);
  }
  if (arguments is Map<String, dynamic>) {
    return RecipeDetailRouteArgs(
      recipe: arguments['recipe'] as Recipe?,
      scrollToComments: arguments['scrollToComments'] as bool? ?? false,
      readOnly: arguments['readOnly'] as bool? ?? false,
      shareRequest: arguments['shareRequest'] as SocialRequest?,
      presentServings: arguments['presentServings'] as int?,
    );
  }
  return const RecipeDetailRouteArgs();
}
