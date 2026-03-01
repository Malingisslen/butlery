import 'package:butlery/core/base/base_service.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/models/shared_personal_tag.dart';
import 'package:butlery/models/tagging/personal_tag.dart';
import 'package:butlery/models/tagging/personal_tag_rule.dart';
import 'package:butlery/repositories/firebase/firebase_personal_tag_repository.dart';
import 'package:butlery/repositories/firebase/firebase_shared_personal_tag_repository.dart';
import 'package:butlery/repositories/interfaces/auth_repository.dart' as auth;
import 'package:butlery/repositories/interfaces/recipe_repository.dart';
import 'package:butlery/services/user_service.dart' as user;
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/l10n/app_locale.dart';

/// Handles sharing and importing of personal tags between users.
///
/// Extracted from PersonalTagService. Manages:
/// - Creating shared tag snapshots for other users
/// - Retrieving pending shared tags
/// - Importing shared tags as local copies
class PersonalTagSharingService extends BaseService {
  final FirebasePersonalTagRepository _tagRepository;

  /// Cache key shared with PersonalTagCrudService for invalidation
  static const String tagsCacheKey = 'personal_tags';

  PersonalTagSharingService({
    required FirebasePersonalTagRepository tagRepository,
  }) : _tagRepository = tagRepository;

  @override
  String get serviceName => 'PersonalTagSharingService';

  /// Shares a personal tag by creating a snapshot in the shared collection.
  ///
  /// Returns the share ID that can be sent to other users for import.
  Future<String?> shareTag(
    String tagId, {
    List<String> recipientUserIds = const [],
  }) async {
    return await executeServiceOperation(
      () async {
        final tag = await _tagRepository.read(tagId);
        if (tag == null) {
          throw ArgumentError(AppLocale.current.errorTagDoesNotExist);
        }

        final userId = _getCurrentUserId();
        if (userId == null) {
          throw StateError(AppLocale.current.errorNoUserLoggedIn);
        }

        final userService = ServiceLocator.get<user.UserService>();
        final displayName =
            userService.currentUserProfile?.displayName ?? 'Unknown';

        // Snapshot matching recipe IDs at share time
        final recipeRepo = _getRecipeRepository();
        final matchingRecipeIds = <String>[];
        if (recipeRepo != null) {
          final recipes = await recipeRepo.fetchAllUserRecipes(userId);
          for (final recipe in recipes) {
            final tagIds = recipe.personalTagIds ?? [];
            if (tagIds.contains(tagId)) {
              matchingRecipeIds.add(recipe.id);
            }
          }
        }

        final serializedRules =
            tag.rules.map((r) => r.toEmbeddedMap()).toList();

        final sharedTag = SharedPersonalTag.create(
          tagName: tag.name,
          sharedByUserId: userId,
          sharedByDisplayName: displayName,
          matchingRecipeIds: matchingRecipeIds,
          tagRules: serializedRules,
          recipientUserIds: recipientUserIds,
        );

        final repo = ServiceLocator.get<FirebaseSharedPersonalTagRepository>();
        await repo.create(sharedTag);

        AppLogger.info(
          'Shared personal tag "${tag.name}" with ${matchingRecipeIds.length} recipes',
        );

        return sharedTag.id;
      },
      operationName: 'Share personal tag',
      requiresAuth: true,
    );
  }

  /// Gets pending shared tags for a user.
  Future<List<SharedPersonalTag>> getPendingSharedTags(String userId) async {
    final repo = ServiceLocator.get<FirebaseSharedPersonalTagRepository>();
    return await repo.getPendingForUser(userId);
  }

  /// Imports a shared tag by creating a local copy for the current user.
  ///
  /// Handles duplicate names by appending "(importerad)" suffix.
  /// Invalidates the parent service's tag cache via the returned callback.
  Future<PersonalTag?> importSharedTag(
    String shareId, {
    required void Function() onCacheInvalidated,
  }) async {
    return await executeServiceOperation(
      () async {
        final repo = ServiceLocator.get<FirebaseSharedPersonalTagRepository>();
        final sharedTag = await repo.read(shareId);
        if (sharedTag == null) {
          throw ArgumentError(AppLocale.current.errorSharedTagNotFound);
        }

        // Check for duplicate name and make unique if needed
        var tagName = sharedTag.tagName;
        if (await _tagRepository.nameExists(tagName)) {
          tagName = '$tagName (importerad)';
          var counter = 2;
          while (await _tagRepository.nameExists(tagName)) {
            tagName = '${sharedTag.tagName} (importerad $counter)';
            counter++;
          }
        }

        final rules = sharedTag.tagRules
            .map((data) => PersonalTagRule.fromEmbeddedMap(data))
            .toList();

        final nextOrder = await _tagRepository.getNextSortOrder();
        final localTag = PersonalTag.create(
          name: tagName,
          sortOrder: nextOrder,
          rules: rules,
        );

        await _tagRepository.create(localTag);
        onCacheInvalidated();

        AppLogger.info(
          'Imported shared tag "${sharedTag.tagName}" as "$tagName" from ${sharedTag.sharedByDisplayName}',
        );

        return localTag;
      },
      operationName: 'Import shared tag',
      requiresAuth: true,
    );
  }

  String? _getCurrentUserId() {
    try {
      final authRepository = ServiceLocator.get<auth.AuthRepository>();
      return authRepository.currentUserId;
    } catch (e) {
      AppLogger.error('Failed to get current user ID: $e');
      return null;
    }
  }

  RecipeRepository? _getRecipeRepository() {
    try {
      return ServiceLocator.get<RecipeRepository>();
    } catch (e) {
      AppLogger.error('Failed to get recipe repository for tag sharing: $e');
      return null;
    }
  }
}
