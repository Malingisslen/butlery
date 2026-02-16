// lib/models/social/activity_type.dart

import 'package:butlery/core/l10n/app_locale.dart';

/// Enumeration of activity types for social feeds (creation, sharing, interactions, achievements).
enum ActivityType {
  // Content creation activities
  recipeCreated('recipe_created', '👨‍🍳 Recept skapat'),
  menuCreated('menu_created', '📋 Meny skapad'),
  shoppingListCreated('shopping_list_created', '🛒 Inköpslista skapad'),

  // Sharing activities
  recipeShared('recipe_shared', '📤 Recept delat'),
  menuShared('menu_shared', '📤 Meny delad'),
  shoppingListShared('shopping_list_shared', '📤 Inköpslista delad'),

  // Social interaction activities
  commentAdded('comment_added', '💬 Kommentar'),
  reactionAdded('reaction_added', '❤️ Reaktion'),
  recipeRated('recipe_rated', '⭐ Betyg'),

  // Collaborative activities
  groupJoined('group_joined', '👥 Gick med i grupp'),
  invitationSent('invitation_sent', '📩 Inbjudan skickad'),
  invitationAccepted('invitation_accepted', '✅ Inbjudan accepterad'),

  // Achievement activities
  achievementUnlocked('achievement_unlocked', '🏆 Bedrift'),
  milestoneReached('milestone_reached', '🎯 Milstolpe'),

  // Unknown/fallback
  unknown('unknown', '❓ Okänd aktivitet');

  const ActivityType(this.key, this.displayName);

  /// Database key for storage
  final String key;

  /// Swedish display name for UI
  final String displayName;

  /// Localized display name resolved at runtime via l10n
  String get localizedDisplayName {
    switch (this) {
      case ActivityType.recipeCreated:
        return AppLocale.current.activityRecipeCreated;
      case ActivityType.menuCreated:
        return AppLocale.current.activityMenuCreated;
      case ActivityType.shoppingListCreated:
        return AppLocale.current.activityShoppingListCreated;
      case ActivityType.recipeShared:
        return AppLocale.current.activityRecipeShared;
      case ActivityType.menuShared:
        return AppLocale.current.activityMenuShared;
      case ActivityType.shoppingListShared:
        return AppLocale.current.activityShoppingListShared;
      case ActivityType.commentAdded:
        return AppLocale.current.activityCommentAdded;
      case ActivityType.reactionAdded:
        return AppLocale.current.activityReactionAdded;
      case ActivityType.recipeRated:
        return AppLocale.current.activityRecipeRated;
      case ActivityType.groupJoined:
        return AppLocale.current.activityGroupJoined;
      case ActivityType.invitationSent:
        return AppLocale.current.activityInvitationSent;
      case ActivityType.invitationAccepted:
        return AppLocale.current.activityInvitationAccepted;
      case ActivityType.achievementUnlocked:
        return AppLocale.current.activityAchievementUnlocked;
      case ActivityType.milestoneReached:
        return AppLocale.current.activityMilestoneReached;
      case ActivityType.unknown:
        return AppLocale.current.activityUnknown;
    }
  }

  /// Get ActivityType from database key
  static ActivityType fromKey(String key) {
    return ActivityType.values.firstWhere(
      (type) => type.key == key,
      orElse: () => ActivityType.unknown,
    );
  }

  /// Get content creation activity types
  static List<ActivityType> get contentTypes => [
        ActivityType.recipeCreated,
        ActivityType.menuCreated,
        ActivityType.shoppingListCreated,
      ];

  /// Get social interaction activity types
  static List<ActivityType> get socialTypes => [
        ActivityType.commentAdded,
        ActivityType.reactionAdded,
        ActivityType.recipeRated,
      ];

  /// Get sharing activity types
  static List<ActivityType> get sharingTypes => [
        ActivityType.recipeShared,
        ActivityType.menuShared,
        ActivityType.shoppingListShared,
      ];

  @override
  String toString() => key;
}
