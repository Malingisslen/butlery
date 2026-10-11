// Shared fixtures for the cookbook (BUT-1325) service, view model and view
// suites.
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/tagging/cookbook_details.dart';
import 'package:butlery/models/tagging/personal_tag.dart';
import 'package:butlery/models/tagging/recipe_personal_tag.dart';

/// A recipe carrying [tagIds]. [ruleTagIds] are added to the recipe's rich
/// tag entries with a rule source instead of a manual one.
Recipe cookbookRecipe(
  String id,
  String title, {
  List<String> tagIds = const [],
  List<String> ruleTagIds = const [],
  String? thumbnailUrl,
  List<String> imageUrls = const [],
}) {
  return Recipe(
    core: RecipeCore(
      id: id,
      title: title,
      description: '',
      ingredients: const [],
      instructions: const [],
      mealType: 'Middag',
      createdBy: 'u1',
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
      personalTagIds: [...tagIds, ...ruleTagIds],
      personalTags: [
        for (final t in tagIds) RecipePersonalTag.manual(tagId: t, name: t),
        for (final t in ruleTagIds)
          RecipePersonalTag(tagId: t, name: t, sources: const ['rule-x']),
      ],
      thumbnailUrl: thumbnailUrl,
      imageUrls: imageUrls,
    ),
    type: RecipeType.personal,
  );
}

PersonalTag cookbookTag({
  String id = 'book',
  String name = 'Mormors favoriter',
  CookbookDetails? cookbook,
  int sortOrder = 0,
}) {
  return PersonalTag(
    id: id,
    name: name,
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
    sortOrder: sortOrder,
    cookbook: cookbook,
  );
}
