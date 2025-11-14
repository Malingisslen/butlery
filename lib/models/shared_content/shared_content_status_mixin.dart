/// Mixin providing status management functionality for shared content models.
///
/// **DEPRECATED (Issue #014)**: Status tracking methods removed.
///
/// **Migration Complete:**
/// Status tracking has been migrated from local model arrays to Firestore subcollections
/// to eliminate the 100-element array limit and enable unlimited sharing.
///
/// **Old Approach (Deprecated):**
/// ```dart
/// // ❌ NO LONGER WORKS - Arrays removed
/// final viewed = recipe.markViewedBy(userId);
/// final isViewed = recipe.isViewedBy(userId);
/// ```
///
/// **New Approach (Phase 1-3 Complete):**
/// ```dart
/// // ✅ Use repository methods for status operations
/// await repository.addView(recipeId, userId);
/// final isViewed = await repository.hasViewed(recipeId, userId);
///
/// // ✅ Use ViewModel caching for synchronous UI access
/// final recipeViewModel = ServiceLocator.get<SharedRecipeViewModel>();
/// final isViewed = recipeViewModel.isRecipeViewed(recipe);
/// ```
///
/// **Status Tracking Architecture:**
/// - **Phase 1 (Repository)**: Status stored in Firestore subcollections
/// - **Phase 2 (Models)**: Arrays removed, counts added
/// - **Phase 3 (ViewModels)**: Status caching for synchronous access
///
/// **Available Methods:**
/// - Repository: `hasViewed()`, `hasEngaged()`, `hasDismissed()`, `getMembers()`
/// - ViewModel: `isRecipeViewed()`, `isRecipeImported()`, `isRecipeDismissed()`
///
/// **Benefits of New Approach:**
/// - ✅ Unlimited members (no 100-element limit)
/// - ✅ Better query performance (indexed subcollections)
/// - ✅ Atomic status updates (no array conflicts)
/// - ✅ Scalable for production use

// lib/models/shared_content/shared_content_status_mixin.dart

import 'package:butlery/models/shared_content/base_shared_content_model.dart';

/// Mixin providing common status management operations for shared content.
///
/// **DEPRECATED (Issue #014)**: All status tracking methods have been removed.
/// Status is now tracked in Firestore subcollections via repository layer.
///
/// This mixin is kept for backward compatibility but contains no functional code.
/// Use repository methods or ViewModel caching instead.
mixin SharedContentStatusMixin<TContent> on BaseSharedContentModel<TContent> {
  // ===== ALL METHODS REMOVED (ISSUE #014) =====
  //
  // Status tracking methods removed:
  //   - markViewedBy(userId) → Use repository.addView(contentId, userId)
  //   - markEngagedBy(userId) → Use repository.addEngagement(contentId, userId)
  //   - markDismissedBy(userId) → Use repository.addDismissal(contentId, userId)
  //   - undismissBy(userId) → Use repository.removeDismissal(contentId, userId)
  //   - isViewedBy(userId) → Use repository.hasViewed(contentId, userId) or ViewModel cache
  //   - isEngagedBy(userId) → Use repository.hasEngaged(contentId, userId) or ViewModel cache
  //   - isDismissedBy(userId) → Use repository.hasDismissed(contentId, userId) or ViewModel cache
  //   - markImportedBy(userId) → Use repository.addEngagement(contentId, userId)
  //   - markJoinedBy(userId) → Use repository.addEngagement(contentId, userId)
  //   - isImportedBy(userId) → Use repository.hasEngaged(contentId, userId) or ViewModel cache
  //   - isJoinedBy(userId) → Use repository.hasEngaged(contentId, userId) or ViewModel cache
  //   - getEngagementAnalytics() → Use ViewModel.getEngagementStats()
  //   - hasAnyEngagement → Use viewCount/engagementCount/dismissalCount fields
  //   - dominantInteractionType → Calculate from count fields
  //
  // For synchronous UI access, use ViewModel caching (Phase 3):
  //   - SharedRecipeViewModel.isRecipeViewed(recipe)
  //   - SharedRecipeViewModel.isRecipeImported(recipe)
  //   - SharedRecipeViewModel.isRecipeDismissed(recipe)
  //
  // For async operations, use repository methods (Phase 1):
  //   - repository.hasViewed(contentId, userId)
  //   - repository.hasEngaged(contentId, userId)
  //   - repository.hasDismissed(contentId, userId)
  //   - repository.getMembers(contentId)
}
