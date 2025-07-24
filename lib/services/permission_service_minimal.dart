/// Minimal PermissionService for debugging DI issues
import 'package:flutter/foundation.dart';
import '../models/user_profile.dart';
import '../services/auth_service.dart';
import '../services/user_service.dart';
import '../services/unified/unified_recipe_service.dart';
import '../services/unified/unified_shopping_service.dart';
import '../services/unified/unified_friends_service.dart';

/// Minimal version of PermissionService for debugging
class PermissionServiceMinimal {
  final AuthService _authService;
  final UserService _userService;
  // Keep references to prevent unused warnings in constructor
  final UnifiedRecipeService _recipeService;
  final UnifiedShoppingService _shoppingService;
  final UnifiedFriendsService _friendsService;

  PermissionServiceMinimal(
    this._authService,
    this._userService,
    this._recipeService,
    this._shoppingService,
    this._friendsService,
  ) {
    // Minimal constructor - no complex module initialization
    debugPrint('PermissionServiceMinimal constructor completed successfully');
  }

  // Core methods only
  bool get isAuthenticated => _authService.isAuthenticated;
  String? get currentUserId => _authService.currentUserId;
  UserProfile? get currentUser => _userService.currentUserProfile;
  
  // Simple methods to use the services and prevent unused field warnings
  bool get hasRecipeService => _recipeService.toString().isNotEmpty;
  bool get hasShoppingService => _shoppingService.toString().isNotEmpty;
  bool get hasFriendsService => _friendsService.toString().isNotEmpty;
}