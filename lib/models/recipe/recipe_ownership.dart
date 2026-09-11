import 'package:butlery/models/recipe_unified.dart';

extension RecipeOwnership on Recipe {
  /// The uid that owns this recipe, or null when it cannot be resolved.
  ///
  /// An EMPTY string counts as missing, in both fields. A plain `??` chain
  /// stops at `''`, which then reads as a real uid: an equality check against
  /// the signed-in user silently fails, and the `recipe_ratings` block gate
  /// (BUT-2057) keys on the field's presence and would evaluate against a
  /// uid that resolves no blocks document.
  String? get ownerUid {
    final social = socialData?.ownerId;
    if (social != null && social.isNotEmpty) return social;
    final creator = core.createdBy;
    if (creator != null && creator.isNotEmpty) return creator;
    return null;
  }
}
