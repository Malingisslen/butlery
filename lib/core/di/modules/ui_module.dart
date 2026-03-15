/// UI module for ViewModel registration and UI-related services.
/// This module handles all UI-related services including ViewModels,
/// navigation, and UI state management. It registers all ViewModels
/// comprehensively to avoid runtime registration errors.
library;

import 'package:get_it/get_it.dart';

// Core interfaces
import 'package:butlery/core/di/interfaces/di_module.dart';

// All ViewModels
import 'package:butlery/viewmodels/auth_viewmodel.dart';
import 'package:butlery/viewmodels/menu_viewmodel.dart';
import 'package:butlery/viewmodels/unified_shopping_viewmodel.dart';
import 'package:butlery/viewmodels/unified_recipe_viewmodel.dart';
import 'package:butlery/viewmodels/user_profile_viewmodel.dart';
import 'package:butlery/viewmodels/profile/profile_viewmodel.dart';
import 'package:butlery/viewmodels/conversations_viewmodel.dart';
import 'package:butlery/viewmodels/create_group_viewmodel.dart';
import 'package:butlery/viewmodels/group_invitations_viewmodel.dart';
import 'package:butlery/viewmodels/recipe_form_viewmodel.dart';
import 'package:butlery/viewmodels/text_import_viewmodel.dart';
import 'package:butlery/viewmodels/url_import_viewmodel.dart';
import 'package:butlery/viewmodels/photo_import_viewmodel.dart';
import 'package:butlery/viewmodels/archive_import_viewmodel.dart';
import 'package:butlery/viewmodels/friends_viewmodel.dart';
import 'package:butlery/viewmodels/shared_content/shared_content_coordinator_viewmodel.dart';
import 'package:butlery/viewmodels/shared_content/shared_menu_viewmodel.dart';
import 'package:butlery/viewmodels/recipe_list_viewmodel.dart';
import 'package:butlery/viewmodels/social_recipe_viewmodel.dart';
import 'package:butlery/viewmodels/collaborative_status_viewmodel.dart';
import 'package:butlery/viewmodels/create_shared_list_viewmodel.dart';
import 'package:butlery/viewmodels/realtime_menu_viewmodel.dart';
import 'package:butlery/viewmodels/shopping_share_viewmodel.dart';
import 'package:butlery/viewmodels/universal_share_dialog_viewmodel.dart';
import 'package:butlery/viewmodels/personal_tag_viewmodel.dart';
import 'package:butlery/viewmodels/onboarding_viewmodel.dart';
import 'package:butlery/viewmodels/shared_shopping_lists_viewmodel.dart';

// Services dependencies
import 'package:butlery/services/unified/unified_friends_service.dart';
import 'package:butlery/services/unified/unified_shopping_service.dart';
import 'package:butlery/services/unified/unified_recipe_service.dart';
import 'package:butlery/services/unified/modules/social_recipe/social_recipe_coordinator.dart';
import 'package:butlery/services/user_service.dart';
import 'package:butlery/services/messaging_service.dart';
import 'package:butlery/services/image_picker_service.dart';
import 'package:butlery/services/import/import_manager.dart';
import 'package:butlery/services/realtime_sync_service.dart';
import 'package:butlery/services/auth_service.dart';
import 'package:butlery/services/account/account_deletion_service.dart';
import 'package:butlery/services/realtime/realtime_menu_service.dart';

// Dependencies from other modules
import 'package:butlery/core/di/modules/core_module.dart';
import 'package:butlery/core/di/modules/content_module.dart';
import 'package:butlery/core/di/modules/social_module.dart';
import 'package:butlery/core/di/modules/collaboration_module.dart';
import 'package:butlery/core/di/modules/messaging_module.dart';

/// UI module providing ViewModels and UI services.
/// This module registers all ViewModels that can be registered in DI.
/// ViewModels requiring instance-specific data (like RecipeDetailViewModel)
/// must be created manually in views.
class UIModule implements DIModule {
  @override
  String get name => 'UI';

  @override
  List<Type> get dependencies => [
        CoreModule,
        ContentModule,
        SocialModule,
        CollaborationModule,
        MessagingModule,
      ];

  @override
  List<Type> get provides => [
        // Core ViewModels
        AuthViewModel,
        UserProfileViewModel,
        ProfileViewModel,

        // Recipe ViewModels
        RecipeListViewModel,
        UnifiedRecipeViewModel,
        SocialRecipeViewModel,
        RecipeFormViewModel,

        // Menu ViewModels
        MenuViewModel,
        RealtimeMenuViewModel,

        // Shopping ViewModels
        UnifiedShoppingViewModel,
        CreateSharedListViewModel,
        ShoppingShareViewModel,
        SharedShoppingListsViewModel,

        // Social ViewModels
        FriendsViewModel,
        SharedContentCoordinatorViewModel,
        SharedMenuViewModel,
        CreateGroupViewModel,
        GroupInvitationsViewModel,
        // Import ViewModels
        TextImportViewModel,
        UrlImportViewModel,
        PhotoImportViewModel,
        ArchiveImportViewModel,

        // Communication ViewModels
        ConversationsViewModel,

        // Other ViewModels
        CollaborativeStatusViewModel,
        UniversalShareDialogViewModel,

        // Tagging ViewModels (singleton - maintains Firestore stream)
        PersonalTagViewModel,

        // Onboarding ViewModel
        OnboardingViewModel,
      ];

  @override
  int get priority =>
      100; // UI has lowest priority, runs after all other modules

  @override
  Future<void> configure(GetIt container) async {
    try {
      // Auth ViewModel - Auth service dependency
      container.registerFactory<AuthViewModel>(
        () => AuthViewModel(
          authService: container<AuthService>(),
        ),
      );

      // User Profile ViewModel - Multiple services
      container.registerFactory<UserProfileViewModel>(
        () => UserProfileViewModel(
          container<UserService>(),
          container<ImagePickerService>(),
        ),
      );

      // Profile ViewModel - Auth, User, and Account Deletion services
      container.registerFactory<ProfileViewModel>(
        () => ProfileViewModel(
          authService: container<AuthService>(),
          userService: container<UserService>(),
          accountDeletionService: container<AccountDeletionService>(),
        ),
      );
      // Recipe List ViewModel
      container.registerFactory<RecipeListViewModel>(
        () => RecipeListViewModel(
          recipeService: container<UnifiedRecipeService>(),
        ),
      );

      // Unified Recipe ViewModel - Zero dependencies (creates internal ViewModels)
      container.registerFactory<UnifiedRecipeViewModel>(
        () => UnifiedRecipeViewModel(),
      );

      // Social Recipe ViewModel - requires UnifiedFriendsService, UnifiedRecipeService, and UserService
      container.registerFactory<SocialRecipeViewModel>(
        () => SocialRecipeViewModel(
          friendsService: container<UnifiedFriendsService>(),
          recipeService: container<UnifiedRecipeService>(),
          userService: container<UserService>(),
        ),
      );

      // Recipe Form ViewModel - Optional services
      container.registerFactory<RecipeFormViewModel>(
        () => RecipeFormViewModel(),
      );
      // Menu ViewModel - Factory for proper lifecycle management
      container.registerFactory<MenuViewModel>(
        () => MenuViewModel(),
      );

      // Realtime Menu ViewModel - requires specific services
      container.registerFactory<RealtimeMenuViewModel>(
        () => RealtimeMenuViewModel(
          menuService: container<RealtimeMenuService>(),
          syncService: container<RealtimeSyncService>(),
          authService: container<AuthService>(),
        ),
      );
      // Unified Shopping ViewModel - Zero dependencies
      container.registerFactory<UnifiedShoppingViewModel>(
        () => UnifiedShoppingViewModel(),
      );

      // Create Shared List ViewModel
      container.registerFactory<CreateSharedListViewModel>(
        () => CreateSharedListViewModel(),
      );

      // Shopping Share ViewModel - only requires shopping and friends services
      container.registerFactory<ShoppingShareViewModel>(
        () => ShoppingShareViewModel(
          shoppingService: container<UnifiedShoppingService>(),
          friendsService: container<UnifiedFriendsService>(),
        ),
      );
      // Shared Shopping Lists ViewModel
      container.registerFactory<SharedShoppingListsViewModel>(
        () => SharedShoppingListsViewModel(
          shoppingService: container<UnifiedShoppingService>(),
        ),
      );

      // Friends ViewModel
      container.registerFactory<FriendsViewModel>(
        () => FriendsViewModel(
          friendsService: container<UnifiedFriendsService>(),
          userService: container<UserService>(),
        ),
      );

      // Shared Content Coordinator ViewModel - modular architecture
      container.registerFactory<SharedContentCoordinatorViewModel>(
        () => SharedContentCoordinatorViewModel(
            // ViewModels created internally if not provided
            ),
      );

      // Shared Menu ViewModel - Week 2 Task 1 Completion
      container.registerFactory<SharedMenuViewModel>(
        () => SharedMenuViewModel(),
      );

      // Create Group ViewModel
      container.registerFactory<CreateGroupViewModel>(
        () => CreateGroupViewModel(),
      );

      // Group Invitations ViewModel
      container.registerFactory<GroupInvitationsViewModel>(
        () => GroupInvitationsViewModel(
          friendsService: container<UnifiedFriendsService>(),
        ),
      );

      // Text Import ViewModel
      container.registerFactory<TextImportViewModel>(
        () => TextImportViewModel(
          importManager: container<ImportManager>(),
        ),
      );

      // URL Import ViewModel
      container.registerFactory<UrlImportViewModel>(
        () => UrlImportViewModel(
          importManager: container<ImportManager>(),
        ),
      );

      // Photo Import ViewModel
      container.registerFactory<PhotoImportViewModel>(
        () => PhotoImportViewModel(
          importManager: container<ImportManager>(),
        ),
      );

      // Archive Import ViewModel
      container.registerFactory<ArchiveImportViewModel>(
        () => ArchiveImportViewModel(),
      );
      // Conversations ViewModel
      container.registerFactory<ConversationsViewModel>(
        () => ConversationsViewModel(
          messagingService: container<MessagingService>(),
        ),
      );
      // Collaborative Status ViewModel
      container.registerFactory<CollaborativeStatusViewModel>(
        () => CollaborativeStatusViewModel(),
      );

      // Universal Share Dialog ViewModel - requires social coordinator and shopping services
      container.registerFactory<UniversalShareDialogViewModel>(
        () => UniversalShareDialogViewModel(
          socialRecipeCoordinator: container<SocialRecipeCoordinator>(),
          shoppingService: container<UnifiedShoppingService>(),
        ),
      );

      // Personal Tag ViewModel - Singleton (holds Firestore stream)
      container.registerLazySingleton<PersonalTagViewModel>(
        () => PersonalTagViewModel(),
      );

      // Onboarding ViewModel
      container.registerFactory<OnboardingViewModel>(
        () => OnboardingViewModel(),
      );
    } catch (e) {
      throw DIModuleException(
        name,
        'configuration',
        'Failed to configure ViewModels: $e',
        e,
      );
    }
  }

  @override
  Future<void> initialize() async {
    // PersonalTagViewModel initializes lazily after user login (not during bootstrap).
    // Views call initialize() in their initState when auth context is available.
  }

  @override
  Future<bool> healthCheck() async {
    try {
      final container = GetIt.instance;

      // Verify that all ViewModels are registered
      final viewModelTypes = provides;

      for (final type in viewModelTypes) {
        if (!container.isRegistered(type: type)) {
          return false;
        }
      }

      return true;
    } catch (e) {
      return false;
    }
  }
}

/// UI module factory for easy instantiation.
class UIModuleFactory {
  /// Create a new UIModule instance.
  static UIModule create() => UIModule();
}

/// Note: ViewModels requiring instance-specific data cannot be registered in DI:
/// - RecipeDetailViewModel (needs Recipe instance)
/// - ChatViewModel (needs conversationId)
/// - CollaborativeShoppingViewModel (needs listId)
/// - AddMembersToGroupViewModel (needs groupId)
/// - RecipeSelectionViewModel (needs targetFriend)
/// These must be created manually in views with required data.
