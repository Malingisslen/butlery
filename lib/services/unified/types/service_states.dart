/// Sealed state classes for unified service streams.
/// Each service exposes a `BehaviorSubject` with Loading / Data / Error.
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/models/friend_request.dart';
import 'package:butlery/models/friend_category.dart';
import 'package:butlery/models/group_invitation.dart';
import 'package:butlery/models/shared_menu.dart';
import 'package:butlery/models/unified/unified_shopping_list.dart';

// --- Recipe ---

sealed class RecipeServiceState {
  const RecipeServiceState();
}

class RecipeStateLoading extends RecipeServiceState {
  const RecipeStateLoading();
}

class RecipeStateData extends RecipeServiceState {
  final List<Recipe> recipes;
  final bool isSyncing;
  final String? error;
  const RecipeStateData({
    required this.recipes,
    this.isSyncing = false,
    this.error,
  });
}

class RecipeStateError extends RecipeServiceState {
  final String message;
  final List<Recipe> lastKnownRecipes;
  const RecipeStateError({
    required this.message,
    this.lastKnownRecipes = const [],
  });
}

// --- Friends ---

sealed class FriendsServiceState {
  const FriendsServiceState();
}

class FriendsStateLoading extends FriendsServiceState {
  const FriendsStateLoading();
}

class FriendsStateData extends FriendsServiceState {
  final List<UserProfile> friends;
  final List<FriendRequest> incomingRequests;
  final List<FriendRequest> outgoingRequests;
  final List<FriendCategory> categories;
  final List<GroupInvitation> receivedInvitations;
  final Set<String> blockedUsers;
  final String? error;
  const FriendsStateData({
    required this.friends,
    this.incomingRequests = const [],
    this.outgoingRequests = const [],
    this.categories = const [],
    this.receivedInvitations = const [],
    this.blockedUsers = const {},
    this.error,
  });
}

class FriendsStateError extends FriendsServiceState {
  final String message;
  const FriendsStateError({required this.message});
}

// --- Menu ---

sealed class MenuServiceState {
  const MenuServiceState();
}

class MenuStateLoading extends MenuServiceState {
  const MenuStateLoading();
}

class MenuStateData extends MenuServiceState {
  final List<SharedMenu> menus;
  final String? error;
  const MenuStateData({
    required this.menus,
    this.error,
  });
}

class MenuStateError extends MenuServiceState {
  final String message;
  const MenuStateError({required this.message});
}

// --- Shopping ---

sealed class ShoppingServiceState {
  const ShoppingServiceState();
}

class ShoppingStateLoading extends ShoppingServiceState {
  const ShoppingStateLoading();
}

class ShoppingStateData extends ShoppingServiceState {
  final List<UnifiedShoppingList> lists;
  final String? activeListId;
  final String? error;
  const ShoppingStateData({
    required this.lists,
    this.activeListId,
    this.error,
  });
}

class ShoppingStateError extends ShoppingServiceState {
  final String message;
  const ShoppingStateError({required this.message});
}
