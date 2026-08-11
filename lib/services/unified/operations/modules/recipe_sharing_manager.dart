// lib/services/unified/operations/modules/recipe_sharing_manager.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/core/l10n/app_locale.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/utils/notification_helper.dart';
import 'package:butlery/services/notifications/notification_service.dart';
import 'package:butlery/services/notifications/notification_types.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/services/parsing/sanitizers/recipe_sanitizer.dart';
import 'package:butlery/services/user_service.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/repositories/firestore_repository.dart';
import 'package:butlery/core/constants/firestore_collections.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/permissions/resource_permission.dart';
import 'package:butlery/services/unified/operations/modules/recipe_share_grants.dart';
import 'package:butlery/services/social/activity_feed_service.dart';
import 'package:butlery/models/social/activity_event.dart';

typedef CreateCollaborativeRecipeFn =
    Future<String?> Function({
      required String title,
      required List<String> memberIds,
      String description,
      List<String> ingredients,
      List<String> instructions,
      List<String> imageUrls,
      String mealType,
      int? portions,
      int? timeMinutes,
      double? rating,
      List<String>? personalTagIds,
      String? sourceUrl,
      String? descriptionCollaborative,
      bool allowGuestViewing,
      bool allowMemberInvites,
      List<String>? categoryIds,
    });

typedef CreatePersonalRecipeFn =
    Future<String?> Function({
      required String title,
      String description,
      List<String> ingredients,
      List<String> instructions,
      List<String> imageUrls,
      String mealType,
      int? portions,
      int? timeMinutes,
      double? rating,
      List<String>? personalTagIds,
      String? sourceUrl,
    });

/// Focused module for recipe sharing and collaboration setup
/// This module handles ONLY recipe sharing responsibilities:
/// - Converting personal recipes to collaborative format
/// - Converting collaborative recipes back to personal format
/// - Share state management and validation
/// - Basic sharing notifications and member alerts
/// - Share metadata and collaboration settings
/// ❌ DOES NOT CONTAIN: Member management, comments, discovery, ratings, permissions
class RecipeSharingManager {
  final String? Function() _getCurrentUserId;
  final String? Function() _getCurrentUserDisplayName;
  final List<Recipe> Function() _getRecipes;
  final CreateCollaborativeRecipeFn _createCollaborativeRecipe;
  final CreatePersonalRecipeFn _createPersonalRecipe;

  /// BUT-1797: re-sharing an ALREADY-collaborative recipe used to write only the
  /// `shared_recipes` row, so the new people were notified about a recipe they
  /// could not open — `firestore.rules` decides access from `memberPermissions`,
  /// and nothing added them to it. Granting that access needs a write seam; this
  /// is the same one `RecipeMemberManager` uses.
  final Future<bool> Function(Recipe) _updateRecipe;
  final NotificationService? _notificationService;
  final FirestoreRepository _firestoreRepository;

  /// BUT-1056: optional sink for user-facing share errors (e.g. cap reached).
  /// Mirrors the `_setError` pattern in `SocialRecipeSharingService` so the
  /// second share callsite can surface the localized `errorShareCapReached`
  /// instead of returning a bare `null` the UI can't distinguish. Additive —
  /// happy path is unaffected when null.
  final void Function(String)? _onShareError;

  RecipeSharingManager({
    required String? Function() getCurrentUserId,
    required String? Function() getCurrentUserDisplayName,
    required List<Recipe> Function() getRecipes,
    required CreateCollaborativeRecipeFn createCollaborativeRecipe,
    required CreatePersonalRecipeFn createPersonalRecipe,
    required Future<bool> Function(Recipe) updateRecipe,
    required NotificationService? notificationService,
    FirestoreRepository? firestoreRepository,
    void Function(String)? onShareError,
  }) : _getCurrentUserId = getCurrentUserId,
       _getCurrentUserDisplayName = getCurrentUserDisplayName,
       _getRecipes = getRecipes,
       _createCollaborativeRecipe = createCollaborativeRecipe,
       _createPersonalRecipe = createPersonalRecipe,
       _updateRecipe = updateRecipe,
       _notificationService = notificationService,
       _onShareError = onShareError,
       _firestoreRepository =
           firestoreRepository ?? ServiceLocator.get<FirestoreRepository>();

  /// Share a personal recipe with other users (convert to collaborative)
  /// Main entry point for recipe sharing - converts personal recipe to collaborative format
  Future<String?> shareRecipe({
    required String recipeId,
    required List<String> memberIds,
    required Map<String, String> memberDisplayNames,
    String? collaborativeDescription,
    bool allowGuestViewing = false,
    bool allowMemberInvites = true,
    List<String>? categoryIds,
  }) async {
    try {
      AppLogger.info('🔄 Starting recipe share process for recipe: $recipeId');

      // Find the recipe to share (personal OR collaborative)
      dynamic recipeToShare;
      bool isAlreadyCollaborative = false;

      try {
        // Try personal recipe first
        recipeToShare = _getRecipes().firstWhere(
          (r) => r.id == recipeId && r.isPersonal,
        );
        AppLogger.info('📋 Found personal recipe: ${recipeToShare.title}');
      } catch (e) {
        // If not personal, try collaborative
        try {
          recipeToShare = _getRecipes().firstWhere(
            (r) => r.id == recipeId && r.isCollaborative,
          );
          isAlreadyCollaborative = true;
          AppLogger.info(
            '📋 Found collaborative recipe: ${recipeToShare.title}',
          );
        } catch (e2) {
          AppLogger.error('❌ Recipe not found: $recipeId');
          return null;
        }
      }

      // BUT-955: cap-guard. Union of (owner + existing members + new members)
      // must fit under Recipe.maxSharesPerRecipe to keep the doc under 1MB.
      final ownerId = _getCurrentUserId();
      final existingMembers =
          recipeToShare.socialData?.memberPermissions?.keys.toSet() ??
          <String>{};
      final projected = <String>{
        ?ownerId,
        ...existingMembers,
        ...memberIds,
      };
      if (projected.length > Recipe.maxSharesPerRecipe) {
        // BUT-804 polish: user-input validation, not internal error —
        // warning is the right level; error pollutes prod dashboards.
        AppLogger.warning(
          'Share denied: recipe $recipeId would have ${projected.length} '
          'shares (cap: ${Recipe.maxSharesPerRecipe})',
        );
        // BUT-1056: surface the localized cap message to the UI instead of a
        // bare null that reads as a generic "could not save" error.
        _onShareError?.call(
          AppLocale.current.errorShareCapReached(Recipe.maxSharesPerRecipe),
        );
        return null;
      }

      String finalRecipeId;

      if (isAlreadyCollaborative) {
        AppLogger.info('🔄 Re-sharing collaborative recipe to group');

        // BUT-1797: grant the new people access, then record WHY they have it.
        // Previously this branch only wrote the `shared_recipes` row and sent
        // notifications, so the recipients were told about a recipe they could
        // not open. Members already present keep the permission they have — a
        // re-share must never silently demote an editor to viewer — but they do
        // pick up the new grant, so a later revoke of this group reaches them.
        final granted = await _grantAccessOnReshare(
          recipe: recipeToShare,
          memberIds: memberIds,
          categoryIds: categoryIds,
        );
        if (!granted) {
          AppLogger.error('❌ Failed to grant access when re-sharing recipe');
          return null;
        }

        await _syncCollaborativeRecipeToSharedCollection(
          recipe: recipeToShare,
          memberIds: memberIds,
        );
        finalRecipeId = recipeId;
        AppLogger.success('✅ Collaborative recipe synced to shared collection');
      } else {
        // Create collaborative version for personal recipes
        finalRecipeId =
            await _createCollaborativeRecipe(
              title: recipeToShare.title,
              memberIds: memberIds,
              description: recipeToShare.description,
              ingredients: recipeToShare.ingredients,
              instructions: recipeToShare.instructions,
              imageUrls: recipeToShare.imageUrls,
              mealType: recipeToShare.mealType,
              portions: recipeToShare.portions,
              timeMinutes: recipeToShare.timeMinutes,
              rating: recipeToShare.rating,
              personalTagIds: recipeToShare.personalTagIds,
              sourceUrl: recipeToShare.sourceUrl,
              descriptionCollaborative: collaborativeDescription,
              allowGuestViewing: allowGuestViewing,
              allowMemberInvites: allowMemberInvites,
              categoryIds: categoryIds,
            ) ??
            '';

        if (finalRecipeId.isEmpty) {
          AppLogger.error('❌ Failed to create collaborative recipe');
          return null;
        }

        AppLogger.success('✅ Created collaborative recipe: $finalRecipeId');

        // Write to shared_recipes collection for group discoverability
        await _writeToSharedRecipesCollection(
          recipeId: finalRecipeId,
          recipeTitle: recipeToShare.title,
          memberIds: memberIds,
          recipeData: recipeToShare,
        );
      }

      // Send sharing notifications to all members
      await _sendSharingNotifications(
        collaborativeRecipeId: finalRecipeId,
        recipeTitle: recipeToShare.title,
        memberIds: memberIds,
        memberDisplayNames: memberDisplayNames,
      );

      // Emit activity event (fire-and-forget)
      try {
        ServiceLocator.get<ActivityFeedService>().emitEvent(
          ActivityEventType.shared,
          finalRecipeId,
          recipeToShare.title,
          extraData: {'memberCount': memberIds.length},
        );
      } catch (_) {}

      AppLogger.success('✅ Recipe sharing completed successfully');
      return finalRecipeId;
    } catch (e) {
      AppLogger.error('❌ Failed to share recipe', e);
      return null;
    }
  }

  /// Convert collaborative recipe back to personal format
  /// Allows users to take ownership of collaborative recipes as personal copies
  Future<String?> makeRecipePersonal({
    required String collaborativeRecipeId,
    String? newTitle,
  }) async {
    try {
      AppLogger.info(
        '🔄 Converting collaborative recipe to personal: $collaborativeRecipeId',
      );

      // Find the collaborative recipe
      dynamic collaborativeRecipe;
      try {
        collaborativeRecipe = _getRecipes().firstWhere(
          (r) => r.id == collaborativeRecipeId && r.isCollaborative,
        );
      } catch (e) {
        AppLogger.error(
          '❌ Cannot convert recipe: Collaborative recipe not found',
        );
        return null;
      }

      AppLogger.info(
        '📋 Found collaborative recipe: ${collaborativeRecipe.title}',
      );

      // Create personal copy with new title if provided
      final personalRecipeId = await _createPersonalRecipe(
        title: newTitle ?? '${collaborativeRecipe.title} (Min kopia)',
        description: collaborativeRecipe.description,
        ingredients: collaborativeRecipe.ingredients,
        instructions: collaborativeRecipe.instructions,
        imageUrls: collaborativeRecipe.imageUrls,
        mealType: collaborativeRecipe.mealType,
        portions: collaborativeRecipe.portions,
        timeMinutes: collaborativeRecipe.timeMinutes,
        rating: collaborativeRecipe.rating,
        personalTagIds: collaborativeRecipe.personalTagIds,
        sourceUrl: collaborativeRecipe.sourceUrl,
      );

      if (personalRecipeId == null) {
        AppLogger.error('❌ Failed to create personal copy of recipe');
        return null;
      }

      AppLogger.success('✅ Created personal copy: $personalRecipeId');

      // Log the conversion for analytics
      _logRecipeConversion(
        originalId: collaborativeRecipeId,
        newId: personalRecipeId,
        conversionType: 'collaborative_to_personal',
      );

      return personalRecipeId;
    } catch (e) {
      AppLogger.error('❌ Failed to convert recipe to personal', e);
      return null;
    }
  }

  /// Duplicate personal recipe for sharing (creates copy before conversion)
  /// Useful when user wants to keep original personal recipe and share a copy
  Future<String?> duplicateAndShareRecipe({
    required String recipeId,
    required List<String> memberIds,
    required Map<String, String> memberDisplayNames,
    String? newTitle,
    String? collaborativeDescription,
    bool allowGuestViewing = false,
    bool allowMemberInvites = true,
    List<String>? categoryIds,
  }) async {
    try {
      AppLogger.info('🔄 Duplicating and sharing recipe: $recipeId');

      // First, create a duplicate of the personal recipe
      final duplicateId = await _duplicatePersonalRecipe(
        recipeId: recipeId,
        newTitle: newTitle,
      );

      if (duplicateId == null) {
        AppLogger.error('❌ Failed to duplicate recipe for sharing');
        return null;
      }

      // Then share the duplicate
      return await shareRecipe(
        recipeId: duplicateId,
        memberIds: memberIds,
        memberDisplayNames: memberDisplayNames,
        collaborativeDescription: collaborativeDescription,
        allowGuestViewing: allowGuestViewing,
        allowMemberInvites: allowMemberInvites,
        categoryIds: categoryIds,
      );
    } catch (e) {
      AppLogger.error('❌ Failed to duplicate and share recipe', e);
      return null;
    }
  }

  /// Send sharing notifications to all members
  Future<void> _sendSharingNotifications({
    required String collaborativeRecipeId,
    required String recipeTitle,
    required List<String> memberIds,
    required Map<String, String> memberDisplayNames,
  }) async {
    AppLogger.info(
      '📬 Sending sharing notifications to ${memberIds.length} members',
    );

    // Get current user display name for notification
    final currentUserId = _getCurrentUserId();
    final currentUserName = _getCurrentUserDisplayName() ?? '?';

    // Send notifications to all invited members using safe helper
    await NotificationHelper.sendImmediateSafely(
      notificationService: _notificationService,
      operationName: 'Send recipe sharing notifications',
      targetUserIds: memberIds,
      strategy: NotificationStrategy.recipeShared,
      variables: {
        'senderName': currentUserName,
        'recipeName': recipeTitle,
      },
      additionalData: {
        'collaborativeRecipeId': collaborativeRecipeId,
        'action': 'recipe_shared',
        'senderUserId': currentUserId,
      },
      actions: [
        NotificationAction.viewRecipe,
      ],
    );
  }

  /// Send notification when recipe sharing is enabled for existing recipe
  Future<void> sendCollaborationEnabledNotification({
    required String recipeId,
    required String recipeTitle,
    required List<String> memberIds,
  }) async {
    final currentUserName = _getCurrentUserDisplayName() ?? '?';

    await NotificationHelper.sendImmediateSafely(
      notificationService: _notificationService,
      operationName: 'Send collaboration enabled notification',
      targetUserIds: memberIds,
      strategy: NotificationStrategy.collaborationEnabled,
      variables: {
        'enablerName': currentUserName,
        'recipeTitle': recipeTitle,
      },
      additionalData: {
        'recipeId': recipeId,
        'action': 'collaboration_enabled',
      },
    );
  }

  /// Duplicate a personal recipe (used internally)
  Future<String?> _duplicatePersonalRecipe({
    required String recipeId,
    String? newTitle,
  }) async {
    try {
      dynamic originalRecipe;
      try {
        originalRecipe = _getRecipes().firstWhere(
          (r) => r.id == recipeId && r.isPersonal,
        );
      } catch (e) {
        AppLogger.error('❌ Cannot duplicate: Recipe not found');
        return null;
      }

      return await _createPersonalRecipe(
        title: newTitle ?? '${originalRecipe.title} (Kopia)',
        description: originalRecipe.description,
        ingredients: originalRecipe.ingredients,
        instructions: originalRecipe.instructions,
        imageUrls: originalRecipe.imageUrls,
        mealType: originalRecipe.mealType,
        portions: originalRecipe.portions,
        timeMinutes: originalRecipe.timeMinutes,
        rating: originalRecipe.rating,
        personalTagIds: originalRecipe.personalTagIds,
        sourceUrl: originalRecipe.sourceUrl,
      );
    } catch (e) {
      AppLogger.error('❌ Failed to duplicate recipe', e);
      return null;
    }
  }

  /// Validate sharing parameters
  bool validateSharingParams({
    required String recipeId,
    required List<String> memberIds,
    required Map<String, String> memberDisplayNames,
  }) {
    if (recipeId.isEmpty) {
      AppLogger.error('❌ Recipe ID cannot be empty');
      return false;
    }

    if (memberIds.isEmpty) {
      AppLogger.error('❌ Must specify at least one member to share with');
      return false;
    }

    if (memberIds.length != memberDisplayNames.length) {
      AppLogger.error('❌ Member IDs and display names count mismatch');
      return false;
    }

    // Check for duplicate member IDs
    if (memberIds.toSet().length != memberIds.length) {
      AppLogger.error('❌ Duplicate member IDs in sharing list');
      return false;
    }

    return true;
  }

  /// Grants [memberIds] access to an already-collaborative [recipe] and records
  /// the provenance of that access.
  ///
  /// A share carrying [categoryIds] came from picking a group, so each member
  /// gets that group's grant token; a share with no group behind it is direct.
  /// `memberPermissions` stays the sole source of truth for access — the grants
  /// only record why, so this cannot widen what anyone may see beyond the
  /// permission entry written right here.
  Future<bool> _grantAccessOnReshare({
    required Recipe recipe,
    required List<String> memberIds,
    required List<String>? categoryIds,
  }) async {
    final permissions = Map<String, ResourcePermission>.from(
      recipe.socialData?.memberPermissions ?? const {},
    );
    var grants = recipe.socialData?.grants;
    final groupIds = categoryIds ?? const <String>[];

    final currentUserId = _getCurrentUserId();
    // What each member is actually granted here — the input `mergeCategoryIds`
    // derives the panel rows from.
    final grantsWritten = <String, List<String>>{};
    for (final memberId in memberIds) {
      // The sharer is not a sharee. A group's roster always contains its own
      // owner (friend_categories_operations seeds it that way), and the caller
      // passes that roster straight through — so without this skip an owner
      // re-sharing to their own group grants themselves a revocable reason to
      // see their own recipe, and the revoke log then counts them as a member
      // who "kept it (another grant, or ownership)". The create path guards the same
      // way; this one did not.
      if (memberId == currentUserId) continue;
      permissions.putIfAbsent(memberId, () => ResourcePermission.editor);
      if (groupIds.isEmpty) {
        grants = RecipeShareGrants.add(
          grants,
          memberId,
          RecipeSocialData.directGrant,
        );
        continue;
      }
      for (final groupId in groupIds) {
        final token = RecipeSocialData.groupGrant(groupId);
        grants = RecipeShareGrants.add(grants, memberId, token);
        grantsWritten.putIfAbsent(memberId, () => <String>[]).add(token);
      }
    }

    // Derived from the grants actually written, NOT from the raw `categoryIds`
    // argument. A group whose roster is only the sharer writes no grant for
    // anyone, and merging the raw id would put a revoke row in the panel that
    // matches nobody: `removeGroup` would clear its guard, cut no one, and the
    // snackbar would still say the group had lost access. `mergeCategoryIds`
    // makes that row structurally impossible.
    final mergedCategoryIds = RecipeShareGrants.mergeCategoryIds(
      recipe.socialData?.categoryIds,
      grantsWritten,
    );

    final updated = Recipe(
      core: recipe.core,
      type: recipe.type,
      socialData: (recipe.socialData ?? const RecipeSocialData()).copyWith(
        memberPermissions: permissions,
        grants: grants,
        categoryIds: mergedCategoryIds,
      ),
      realtimeData: recipe.realtimeData,
      offlineData: recipe.offlineData,
    );

    return _updateRecipe(updated);
  }

  /// Sync collaborative recipe to shared_recipes collection
  /// Used when re-sharing an already collaborative recipe
  Future<void> _syncCollaborativeRecipeToSharedCollection({
    required Recipe recipe,
    required List<String> memberIds,
  }) async {
    try {
      AppLogger.info('🔄 Syncing collaborative recipe to shared collection');

      // Get existing members from recipe permissions
      final existingMembers =
          recipe.socialData?.memberPermissions?.keys.toList() ?? [];

      // Write to shared_recipes collection with all members included
      await _writeToSharedRecipesCollection(
        recipeId: recipe.id,
        recipeTitle: recipe.title,
        memberIds: [
          ...existingMembers,
          ...memberIds,
        ], // Combine existing + new members
        recipeData: recipe,
      );

      AppLogger.success('✅ Collaborative recipe synced to shared collection');
    } catch (e) {
      AppLogger.error('❌ Failed to sync collaborative recipe', e);
      rethrow;
    }
  }

  /// Log recipe conversion for analytics
  void _logRecipeConversion({
    required String originalId,
    required String newId,
    required String conversionType,
  }) {
    try {
      AppLogger.info('📊 Recipe conversion logged: $conversionType');
      // This could be expanded to send analytics events
      // Analytics.logEvent('recipe_conversion', {
      //   'originalId': originalId,
      //   'newId': newId,
      //   'type': conversionType,
      //   'userId': _getCurrentUserId(),
      // });
    } catch (e) {
      AppLogger.warning('⚠️ Failed to log recipe conversion: $e');
    }
  }

  /// Get sharing statistics for current user
  Map<String, dynamic> getSharingStats() {
    try {
      final userRecipes = _getRecipes()
          .where((r) => r.createdBy == _getCurrentUserId())
          .toList();

      final personalRecipes = userRecipes.where((r) => r.isPersonal).length;
      final collaborativeRecipes = userRecipes
          .where((r) => r.isCollaborative)
          .length;
      final sharedRecipes = userRecipes
          .where(
            (r) =>
                r.isCollaborative &&
                (r.socialData?.memberPermissions?.isNotEmpty ?? false),
          )
          .length;

      return {
        'total_recipes': userRecipes.length,
        'personal_recipes': personalRecipes,
        'collaborative_recipes': collaborativeRecipes,
        'shared_recipes': sharedRecipes,
        'sharing_ratio': userRecipes.isNotEmpty
            ? (sharedRecipes / userRecipes.length * 100).round()
            : 0,
      };
    } catch (e) {
      AppLogger.error('❌ Failed to get sharing stats', e);
      return {'error': 'Failed to calculate stats'};
    }
  }

  /// Write to shared_recipes collection for group discoverability
  /// This allows groups to query and discover shared recipes in their feed
  Future<void> _writeToSharedRecipesCollection({
    required String recipeId,
    required String recipeTitle,
    required List<String> memberIds,
    // Typed, NOT `dynamic`. Dart extension methods are dispatched STATICALLY,
    // so `recipeData.description.orEmpty()` on a dynamic receiver looks for an
    // instance method named `orEmpty` on the runtime String, does not find one,
    // and throws NoSuchMethodError — which the catch at the bottom of this
    // method swallows, so the shared_content row is silently never written.
    // The analyzer cannot see it: every member access on a dynamic is legal.
    //
    // That is exactly what happened on 2026-08-03 when a raw `?? ''` was
    // replaced with `.orEmpty()` to satisfy the BUT-581 arch guard. Typing the
    // parameter is the root-cause fix; both call sites already pass a Recipe.
    required Recipe recipeData,
  }) async {
    try {
      final permissionService = ServiceLocator.get<PermissionService>();

      final currentUserId = permissionService.currentUserId;
      if (currentUserId == null) {
        AppLogger.warning(
          'Cannot write to shared_recipes: No authenticated user',
        );
        return;
      }

      // Ensure owner is included in sharedToUserIds along with members
      final allUserIds = {currentUserId, ...memberIds}.toList();

      final sharedContentRef = _firestoreRepository
          .collection(FirestoreCollections.sharedContent)
          .doc(recipeId);
      // Re-sharing the same recipe is an UPDATE, and `firestore.rules` :733
      // guards it with `cannotModify([... , 'sharedAt'])`. A resolved
      // serverTimestamp NEVER equals the stored one, so stamping it
      // unconditionally put `sharedAt` in `affectedKeys()` and the rules engine
      // refused the WHOLE write — silently, because the catch below only warns.
      // Every share after the first therefore added nobody to
      // `sharedToUserIds`, which is exactly the field the recipient's `allow
      // list` grant and their Art. 15 bundle depend on. Create-only stamping is
      // also the correct semantics: `sharedAt` is when the recipe was first
      // shared, and the create rule's `hasRequiredFields` still gets it.
      //
      // The probe must fail OPEN toward "new". The `allow get` branch in
      // `firestore.rules` (:724) dereferences `resource.data.sharedByUserId`
      // at :725, and on a document that does not exist `resource` is null — so the very FIRST share of a recipe gets
      // PERMISSION_DENIED here, the catch below swallows it, and the row is never
      // created. That is the exact failure create-only stamping exists to prevent,
      // just moved one line up. `fake_cloud_firestore` evaluates no rules, so no
      // unit test can PROVOKE the denial — but the catch is reachable by
      // injecting one through the constructor's `firestoreRepository` seam, and
      // `recipe_sharing_manager_test.dart` does exactly that.
      //
      // Do NOT "fix" this in the rules by adding `resource == null` to `allow get`:
      // today not-found and not-yours are indistinguishable, and separating them
      // would turn shared_content into an existence oracle over recipeIds.
      //
      // A DENIED probe is not always the first-share case, and the other case
      // cannot be rescued here. `allow get` (:724) passes for the sharer, a
      // shared member, or anyone in `sharedToUserIds`; `allow update` (:733)
      // passes only for the sharer or a shared member. So a denied read PROVES
      // both update predicates are false — if the document already exists and
      // belongs to someone else, no payload we send can be written, with or
      // without `sharedAt`. Re-sharing a recipe another user already wrote to
      // `shared_content` therefore does not add our recipients to
      // `sharedToUserIds`, and they get neither the read grant nor the Art. 15
      // row. That is BUT-1812, not something a retry can paper over.
      var isNew = true;
      try {
        isNew = !(await sharedContentRef.get()).exists;
      } on FirebaseException catch (e) {
        if (e.code != 'permission-denied') rethrow;
        AppLogger.debug(
          'shared_content probe denied for $recipeId — treating as new; if the '
          'document exists and is another user\'s, the write below cannot '
          'succeed under any payload (BUT-1812)',
        );
      }

      final cleanText = sanitizeSharedRecipeText(
        recipeTitle,
        recipeData.description,
      );

      final payload = <String, dynamic>{
        'contentType': 'recipe',
        'recipeId': recipeId,
        // BUT-1819: this manager builds its own payload and never touches
        // `FirebaseSharedRecipeRepository.toFirestore`, so the sanitization
        // there does not reach it — a second writer of the same denormalized
        // text into the same collection, found by the security review. Both now
        // call `sanitizeSharedRecipeText`, so the DECISION lives in one place
        // even though the key spellings differ (`title`/`description` here,
        // `recipeTitle`/`recipeDescription` there); those predate this ticket.
        'title': cleanText.title,
        'description': cleanText.description,
        'sharedByUserId': currentUserId,
        // BUT-1775, applying BUT-1705/BUT-1736: `profileDisplayName`, NOT
        // `permissionService.currentUser`. The latter is built straight from
        // the Firebase Auth user, so it stamps the legal name on the
        // requester's Google/Apple account — never chosen for display, not
        // what `on-profile-updated.ts` propagates, and not what account
        // deletion scrubs. This value is persisted on a document every group
        // member reads and lands verbatim in their GDPR export, so an
        // Auth-sourced stamp would be both unconsented and un-erasable.
        //
        // `tryGet` keeps the module working before/without the service
        // graph; an unresolved name stamps the localized unknown-user
        // label, never an Auth-sourced one.
        'sharedByDisplayName':
            ServiceLocator.tryGet<UserService>()?.profileDisplayName ??
            AppLocale.current.displayUnknownUser,
        'sharedByAvatarUrl': permissionService.currentUser?.avatarUrl,
        // The single membership field. `firestore.rules` :722/:727 grants
        // recipient read on this and nothing else, and it is what
        // `BaseSharedContentRepository`, the GDPR export and the deletion
        // cascade all speak. It was briefly written twice, under a second
        // spelling, so rows predating the fix stayed readable — retired
        // 2026-08-03 once it was established the project holds only test data.
        'sharedToUserIds': allUserIds,
        'isActive': true,
        'imageUrl': recipeData.imageUrls.isNotEmpty
            ? recipeData.imageUrls.first
            : null,
        'mealType': recipeData.mealType,
      };
      if (isNew) {
        payload['sharedAt'] = FieldValue.serverTimestamp();
      }

      await sharedContentRef.set(payload, SetOptions(merge: true));

      AppLogger.debug(
        '✅ Recipe written to shared_content collection for group discovery',
      );
    } catch (e) {
      // Deliberately non-fatal — the recipe itself is already shared. Logged at
      // ERROR, not warning: a failure here is invisible to the user and costs
      // the recipient their read grant and their Art. 15 row, so it must not
      // sink below the noise floor the way the sharedAt denial did.
      AppLogger.error('Failed to write to shared_content collection', e);
    }
  }
}
