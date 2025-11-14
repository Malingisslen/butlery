# Phase 6: Circular Dependency Check

**Analysis Date:** November 13, 2025
**Codebase:** Butlery Flutter Application
**Scope:** 761 Dart files (698 with dependencies)

PHASE 6: CIRCULAR DEPENDENCY CHECK - RAW RESULTS
================================================================================

SUMMARY
--------------------------------------------------------------------------------
Total files analyzed: 761
Files with dependencies: 698
Direct circular dependencies: 23
Layer violations: 114

DIRECT CIRCULAR DEPENDENCIES
--------------------------------------------------------------------------------

1. lib/core/bootstrap/application_bootstrap.dart
   <-> lib/core/providers/application_provider.dart
   Layers: CORE <-> CORE

2. lib/models/recipe/recipe_operations.dart
   <-> lib/models/recipe_unified.dart
   Layers: MODEL <-> MODEL

3. lib/models/recipe/recipe_factory.dart
   <-> lib/models/recipe_unified.dart
   Layers: MODEL <-> MODEL

4. lib/models/recipe/recipe_serialization.dart
   <-> lib/models/recipe_unified.dart
   Layers: MODEL <-> MODEL

5. lib/services/permission_service.dart
   <-> lib/services/unified/unified_shopping_service.dart
   Layers: SERVICE <-> SERVICE

6. lib/services/extraction/extraction_manager.dart
   <-> lib/services/social_media_extractor.dart
   Layers: SERVICE <-> SERVICE

7. lib/services/unified/operations/friends_management_operations.dart
   <-> lib/services/unified/unified_friends_service.dart
   Layers: SERVICE <-> SERVICE

8. lib/services/unified/operations/friend_categories_operations.dart
   <-> lib/services/unified/unified_friends_service.dart
   Layers: SERVICE <-> SERVICE

9. lib/services/unified/operations/friends_invitations_operations.dart
   <-> lib/services/unified/unified_friends_service.dart
   Layers: SERVICE <-> SERVICE

10. lib/services/unified/operations/social_group_sharing_operations.dart
   <-> lib/services/unified/unified_friends_service.dart
   Layers: SERVICE <-> SERVICE

11. lib/services/unified/operations/collaborative_menu_operations.dart
   <-> lib/services/unified/unified_menu_service.dart
   Layers: SERVICE <-> SERVICE

12. lib/services/unified/operations/personal_recipe_operations.dart
   <-> lib/services/unified/unified_recipe_service.dart
   Layers: SERVICE <-> SERVICE

13. lib/services/unified/operations/social_recipe_operations.dart
   <-> lib/services/unified/unified_recipe_service.dart
   Layers: SERVICE <-> SERVICE

14. lib/services/unified/operations/realtime_recipe_operations.dart
   <-> lib/services/unified/unified_recipe_service.dart
   Layers: SERVICE <-> SERVICE

15. lib/services/unified/operations/modules/recipe_discovery_service.dart
   <-> lib/services/unified/unified_recipe_service.dart
   Layers: SERVICE <-> SERVICE

16. lib/services/unified/operations/personal_shopping_operations.dart
   <-> lib/services/unified/unified_shopping_service.dart
   Layers: SERVICE <-> SERVICE

17. lib/services/unified/operations/collaborative_shopping_operations.dart
   <-> lib/services/unified/unified_shopping_service.dart
   Layers: SERVICE <-> SERVICE

18. lib/viewmodels/universal_share_dialog_viewmodel.dart
   <-> lib/widgets/common/universal_share_dialog.dart
   Layers: VIEWMODEL <-> VIEW

19. lib/widgets/common/share_dialog/share_dialog_header.dart
   <-> lib/widgets/common/universal_share_dialog.dart
   Layers: VIEW <-> VIEW

20. lib/widgets/common/share_dialog/share_mode_selection.dart
   <-> lib/widgets/common/universal_share_dialog.dart
   Layers: VIEW <-> VIEW

21. lib/widgets/common/share_dialog/share_dialog_states.dart
   <-> lib/widgets/common/universal_share_dialog.dart
   Layers: VIEW <-> VIEW

22. lib/widgets/common/share_dialog/share_dialog_actions.dart
   <-> lib/widgets/common/universal_share_dialog.dart
   Layers: VIEW <-> VIEW

23. lib/widgets/common/share_dialog/share_dialog_helpers.dart
   <-> lib/widgets/common/universal_share_dialog.dart
   Layers: VIEW <-> VIEW


ARCHITECTURAL LAYER VIOLATIONS
--------------------------------------------------------------------------------

VIEW -> SERVICE violations (96):
  - lib/views/edit_recipe_view.dart
    -> lib/services/auth_service.dart
  - lib/views/file_import_view.dart
    -> lib/services/import/file_import_strategy.dart
  - lib/views/file_import_view.dart
    -> lib/services/unified/unified_recipe_service.dart
  - lib/views/mina_recept_view.dart
    -> lib/services/search_service.dart
  - lib/views/mina_recept_view.dart
    -> lib/services/offline_service.dart
  - lib/views/mina_recept_view.dart
    -> lib/services/user_service.dart
  - lib/views/mina_recept_view.dart
    -> lib/services/unified/unified_friends_service.dart
  - lib/views/receive_share_view.dart
    -> lib/services/content_detector_service.dart
  - lib/views/receive_share_view.dart
    -> lib/services/social_media_extractor.dart
  - lib/views/receive_share_view.dart
    -> lib/services/analytics_service.dart
  ... and 86 more

VIEW -> REPOSITORY violations (9):
  - lib/views/messaging/conversations_list_view.dart
    -> lib/repositories/interfaces/auth_repository.dart
  - lib/views/messaging/chat_view/chat_view_facade.dart
    -> lib/repositories/interfaces/auth_repository.dart
  - lib/views/recipe_detail/recipe_detail_comments.dart
    -> lib/repositories/firebase/firebase_auth_repository.dart
  - lib/views/recipe_detail/handlers/recipe_social_handler.dart
    -> lib/repositories/firebase/firebase_auth_repository.dart
  - lib/widgets/common/profile/profile_actions.dart
    -> lib/repositories/interfaces/auth_repository.dart
  - lib/widgets/common/profile/profile_actions.dart
    -> lib/repositories/firestore_repository.dart
  - lib/widgets/common/profile/profile_menu.dart
    -> lib/repositories/interfaces/auth_repository.dart
  - lib/widgets/recipe/comment_debug_panel.dart
    -> lib/repositories/firebase/firebase_auth_repository.dart
  - lib/widgets/social/groups/group_shared_content_section.dart
    -> lib/repositories/firebase/firebase_shared_menu_repository.dart

VIEWMODEL -> REPOSITORY violations (9):
  - lib/viewmodels/chat_viewmodel.dart
    -> lib/repositories/interfaces/auth_repository.dart
  - lib/viewmodels/conversations_viewmodel.dart
    -> lib/repositories/interfaces/auth_repository.dart
  - lib/viewmodels/group_content_viewmodel.dart
    -> lib/repositories/interfaces/social_sharing_repository.dart
  - lib/viewmodels/group_detail_viewmodel.dart
    -> lib/repositories/interfaces/auth_repository.dart
  - lib/viewmodels/menu/menu_storage.dart
    -> lib/repositories/firestore_repository.dart
  - lib/viewmodels/recipe_form/recipe_collaborative_manager.dart
    -> lib/repositories/collaborative_recipe_repository.dart
  - lib/viewmodels/shared_content/shared_menu_viewmodel.dart
    -> lib/repositories/firebase/firebase_shared_menu_repository.dart
  - lib/viewmodels/shared_content/shared_recipe_viewmodel.dart
    -> lib/repositories/firebase/firebase_shared_recipe_repository.dart
  - lib/viewmodels/shared_content/shared_shopping_viewmodel.dart
    -> lib/repositories/firebase/firebase_shared_shopping_repository.dart


LAYER STATISTICS
--------------------------------------------------------------------------------
VIEW: 287 files
VIEWMODEL: 88 files
SERVICE: 188 files
REPOSITORY: 62 files
MODEL: 48 files
CORE: 57 files
OTHER: 31 files
