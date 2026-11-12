import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/models/friend_category.dart';
import 'package:butlery/models/messaging/poll.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/services/menu_service.dart';
import 'package:butlery/services/messaging_service.dart';
import 'package:butlery/services/unified/unified_recipe_service.dart';
import 'package:butlery/services/user_service.dart';
import 'package:butlery/viewmodels/menu/menu_generator.dart';

/// Suggestions and chat poll for a social group's "Vad ska vi äta?" vote.
class GroupMealVoteManager {
  final UserService _userService;

  GroupMealVoteManager({required UserService userService})
    : _userService = userService;

  /// Biases toward variety by grouping by meal type and round-robining across
  /// types.
  Future<List<Recipe>> pickSuggestions({int maxCount = 4}) async {
    final recipeService = ServiceLocator.get<UnifiedRecipeService>();
    final menuService = ServiceLocator.get<MenuService>();
    final generator = MenuGenerator(
      menuService: menuService,
      recipeService: recipeService,
      userService: _userService,
      filterByAllergens: true,
      filterByDietary: true,
    );

    final pool = await generator.getAvailableRecipesAsync();
    if (pool.isEmpty) return const [];

    // Group by meal type to encourage variety — cheap deterministic
    // bucketing, no LLM involvement. Fall back to title hash when meal type
    // is missing so recipes without one still get distributed.
    final buckets = <String, List<Recipe>>{};
    for (final recipe in pool) {
      final rawMealType = recipe.mealType;
      final key = rawMealType.isNotEmpty
          ? rawMealType
          : (recipe.title.hashCode & 0x3).toString();
      buckets.putIfAbsent(key, () => []).add(recipe);
    }

    final picked = <Recipe>[];
    final bucketIterators = buckets.values
        .map((b) => b.iterator)
        .toList(growable: false);
    while (picked.length < maxCount) {
      var anyAdded = false;
      for (final it in bucketIterators) {
        if (picked.length >= maxCount) break;
        if (it.moveNext()) {
          picked.add(it.current);
          anyAdded = true;
        }
      }
      if (!anyAdded) break;
    }
    return picked;
  }

  /// Creates the group's chat on the first poll and reuses it afterwards.
  Future<String> postPoll({
    required FriendCategory group,
    required String currentUserId,
    required String question,
    required List<Recipe> recipes,
    required bool allowMultipleChoices,
  }) async {
    final messagingService = ServiceLocator.get<MessagingService>();

    final conversationId = await messagingService.ensureCategoryChat(
      ownerId: group.ownerId,
      categoryId: group.id,
    );

    final options = recipes
        .map(
          (r) => PollOption.create(
            text: r.title,
            recipeId: r.id,
            recipeImageUrl: r.primaryImageUrl,
            recipePortions: r.portions,
          ),
        )
        .toList();

    final poll = Poll.fromOptions(
      question: question,
      options: options,
      creatorId: currentUserId,
      allowMultipleChoices: allowMultipleChoices,
    );

    await messagingService.sendPollMessage(
      conversationId: conversationId,
      pollData: poll.toMap(),
    );
    return conversationId;
  }
}
