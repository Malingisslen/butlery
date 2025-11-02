# Permission Validation Patterns

Comprehensive guide to implementing permission validation in Firebase repositories for security, authorization, and GDPR compliance.

## Permission Validation Philosophy

Every repository operation must validate permissions before execution:
- **Authentication**: Is the user signed in?
- **Authorization**: Does the user have permission to perform this action?
- **Ownership**: Does the user own this resource?
- **Sharing**: Is the resource shared with the user?
- **Role-based**: Does the user have the required role?

**Security Principle**: Trust nothing from the client. Validate everything server-side (or in repository layer for client apps with security rules).

## BaseFirebaseRepository Permission Methods

BaseFirebaseRepository provides four validation hooks:

```dart
abstract class BaseFirebaseRepository<T> {
  /// Called before creating entity
  Future<void> validateCreatePermission(T entity);

  /// Called before reading entity
  Future<void> validateReadPermission(String id);

  /// Called before updating entity
  Future<void> validateUpdatePermission(T entity);

  /// Called before deleting entity
  Future<void> validateDeletePermission(String id);
}
```

## Basic Permission Validation

### Create Permission

```dart
@override
Future<void> validateCreatePermission(Recipe recipe) async {
  await super.validateCreatePermission(recipe);

  // 1. Check authentication
  final currentUserId = authRepository.currentUserId;
  if (currentUserId == null) {
    throw UnauthorizedException('Must be signed in to create recipe');
  }

  // 2. Verify user owns the resource
  if (recipe.userId != currentUserId) {
    throw UnauthorizedException('Cannot create recipe for another user');
  }

  // 3. Check business rules
  if (recipe.title.isEmpty) {
    throw ValidationException('Recipe title is required');
  }

  // 4. Check quotas
  final userRecipes = await getUserRecipes(userId: currentUserId);
  if (userRecipes.length >= 500) {
    throw QuotaExceededException('Maximum 500 recipes per user');
  }
}
```

### Read Permission

```dart
@override
Future<void> validateReadPermission(String id) async {
  await super.validateReadPermission(id);

  final currentUserId = authRepository.currentUserId;
  if (currentUserId == null) {
    throw UnauthorizedException('Must be signed in');
  }

  // Get recipe to check ownership
  final recipe = await _getRecipeUnsafe(id);
  if (recipe == null) {
    throw NotFoundException('Recipe not found');
  }

  // Allow if user owns the recipe
  if (recipe.userId == currentUserId) {
    return;
  }

  // Allow if recipe is public
  if (recipe.visibility == RecipeVisibility.public) {
    return;
  }

  // Allow if recipe is shared with user
  if (recipe.sharedWith?.contains(currentUserId) == true) {
    return;
  }

  throw UnauthorizedException('Not authorized to view this recipe');
}

/// Internal method that bypasses permission checks (use carefully!)
Future<Recipe?> _getRecipeUnsafe(String id) async {
  final doc = await firestore
      .collection(_getCollectionPath())
      .doc(id)
      .get();

  return doc.exists ? fromFirestore(doc) : null;
}
```

### Update Permission

```dart
@override
Future<void> validateUpdatePermission(Recipe recipe) async {
  await super.validateUpdatePermission(recipe);

  final currentUserId = authRepository.currentUserId;
  if (currentUserId == null) {
    throw UnauthorizedException('Must be signed in');
  }

  // Get existing recipe
  final existing = await _getRecipeUnsafe(recipe.id);
  if (existing == null) {
    throw NotFoundException('Recipe not found');
  }

  // Owner can always edit
  if (existing.userId == currentUserId) {
    return;
  }

  // Check if user has edit permission (for shared recipes)
  if (existing.editors?.contains(currentUserId) == true) {
    return;
  }

  throw UnauthorizedException('Not authorized to edit this recipe');
}
```

### Delete Permission

```dart
@override
Future<void> validateDeletePermission(String id) async {
  await super.validateDeletePermission(id);

  final currentUserId = authRepository.currentUserId;
  if (currentUserId == null) {
    throw UnauthorizedException('Must be signed in');
  }

  final recipe = await _getRecipeUnsafe(id);
  if (recipe == null) {
    throw NotFoundException('Recipe not found');
  }

  // Only owner can delete
  if (recipe.userId != currentUserId) {
    throw UnauthorizedException('Only owner can delete recipe');
  }
}
```

## Shared Resource Permissions

### Recipe Shared with Friends

```dart
class SocialRecipeRepository extends BaseFirebaseRepository<SharedRecipe> {
  @override
  Future<void> validateReadPermission(String id) async {
    await super.validateReadPermission(id);

    final currentUserId = authRepository.currentUserId;
    if (currentUserId == null) {
      throw UnauthorizedException('Must be signed in');
    }

    final recipe = await _getRecipeUnsafe(id);
    if (recipe == null) {
      throw NotFoundException('Recipe not found');
    }

    // Owner can read
    if (recipe.ownerId == currentUserId) {
      return;
    }

    // Users in sharedWith list can read
    if (recipe.sharedWith.contains(currentUserId)) {
      return;
    }

    // Friends of owner can read if recipe is friend-visible
    if (recipe.visibility == RecipeVisibility.friends) {
      final isFriend = await _friendsRepository.areFriends(
        recipe.ownerId,
        currentUserId,
      );
      if (isFriend) {
        return;
      }
    }

    throw UnauthorizedException('Not authorized to view this recipe');
  }

  @override
  Future<void> validateUpdatePermission(SharedRecipe recipe) async {
    await super.validateUpdatePermission(recipe);

    final currentUserId = authRepository.currentUserId!;

    // Owner can edit
    if (recipe.ownerId == currentUserId) {
      return;
    }

    // Users with explicit edit permission can edit
    if (recipe.editors?.contains(currentUserId) == true) {
      return;
    }

    // Collaborators can edit if collaboration enabled
    if (recipe.allowCollaboration == true &&
        recipe.collaborators?.contains(currentUserId) == true) {
      return;
    }

    throw UnauthorizedException('Not authorized to edit this recipe');
  }
}
```

### Group-Based Permissions

```dart
class GroupRecipeRepository extends BaseFirebaseRepository<GroupRecipe> {
  final GroupMembershipRepository _membershipRepository;

  @override
  Future<void> validateReadPermission(String id) async {
    await super.validateReadPermission(id);

    final currentUserId = authRepository.currentUserId!;
    final recipe = await _getRecipeUnsafe(id);

    if (recipe == null) {
      throw NotFoundException('Recipe not found');
    }

    // Check if user is group member
    final isMember = await _membershipRepository.isMember(
      groupId: recipe.groupId,
      userId: currentUserId,
    );

    if (!isMember) {
      throw UnauthorizedException('Must be group member to view');
    }
  }

  @override
  Future<void> validateUpdatePermission(GroupRecipe recipe) async {
    await super.validateUpdatePermission(recipe);

    final currentUserId = authRepository.currentUserId!;

    // Check user's role in group
    final membership = await _membershipRepository.getMembership(
      groupId: recipe.groupId,
      userId: currentUserId,
    );

    if (membership == null) {
      throw UnauthorizedException('Not a group member');
    }

    // Admin and moderator can edit
    if (membership.role == GroupRole.admin ||
        membership.role == GroupRole.moderator) {
      return;
    }

    // Recipe owner can edit
    if (recipe.ownerId == currentUserId) {
      return;
    }

    // Member can edit if group allows member edits
    if (membership.role == GroupRole.member &&
        recipe.allowMemberEdits == true) {
      return;
    }

    throw UnauthorizedException('Insufficient permissions to edit');
  }

  @override
  Future<void> validateDeletePermission(String id) async {
    await super.validateDeletePermission(id);

    final currentUserId = authRepository.currentUserId!;
    final recipe = await _getRecipeUnsafe(id);

    if (recipe == null) {
      throw NotFoundException('Recipe not found');
    }

    final membership = await _membershipRepository.getMembership(
      groupId: recipe.groupId,
      userId: currentUserId,
    );

    // Only admin or recipe owner can delete
    if (membership?.role == GroupRole.admin ||
        recipe.ownerId == currentUserId) {
      return;
    }

    throw UnauthorizedException('Only admin or owner can delete');
  }
}
```

## Role-Based Access Control (RBAC)

```dart
enum UserRole {
  admin,
  moderator,
  premiumUser,
  freeUser,
}

class RecipeRepository extends BaseFirebaseRepository<Recipe> {
  final UserRepository _userRepository;

  @override
  Future<void> validateCreatePermission(Recipe recipe) async {
    await super.validateCreatePermission(recipe);

    final currentUserId = authRepository.currentUserId!;
    final user = await _userRepository.getById(currentUserId);

    if (user == null) {
      throw UnauthorizedException('User not found');
    }

    // Free users have recipe limit
    if (user.role == UserRole.freeUser) {
      final userRecipes = await getUserRecipes(userId: currentUserId);
      if (userRecipes.length >= 50) {
        throw QuotaExceededException(
          'Free users limited to 50 recipes. Upgrade to Premium for unlimited.',
        );
      }
    }

    // Premium features
    if (recipe.hasPremiumFeatures && user.role != UserRole.premiumUser) {
      throw UnauthorizedException('Premium features require premium account');
    }
  }
}
```

## Audit Logging for Security

Track all security-sensitive operations for GDPR compliance (Article 30):

```dart
class RecipeRepository extends BaseFirebaseRepository<Recipe> {
  @override
  Future<Recipe> create(Recipe recipe) async {
    await validateCreatePermission(recipe);

    final created = await super.create(recipe);

    // Log creation
    await logAuditEvent(
      action: 'recipe_created',
      resourceId: created.id,
      userId: authRepository.currentUserId!,
      metadata: {
        'title': recipe.title,
        'visibility': recipe.visibility.toString(),
      },
    );

    return created;
  }

  @override
  Future<Recipe> update(Recipe recipe) async {
    await validateUpdatePermission(recipe);

    final existing = await getById(recipe.id);
    final updated = await super.update(recipe);

    // Log update with changes
    await logAuditEvent(
      action: 'recipe_updated',
      resourceId: recipe.id,
      userId: authRepository.currentUserId!,
      metadata: {
        'changes': _detectChanges(existing, updated),
      },
    );

    return updated;
  }

  @override
  Future<void> delete(String id) async {
    await validateDeletePermission(id);

    final recipe = await getById(id);

    await super.delete(id);

    // Log deletion
    await logAuditEvent(
      action: 'recipe_deleted',
      resourceId: id,
      userId: authRepository.currentUserId!,
      metadata: {
        'title': recipe?.title,
        'had_shared_access': recipe?.sharedWith?.isNotEmpty == true,
      },
    );
  }

  Map<String, dynamic> _detectChanges(Recipe? old, Recipe new_) {
    if (old == null) return {};

    final changes = <String, dynamic>{};
    if (old.title != new_.title) {
      changes['title'] = {'from': old.title, 'to': new_.title};
    }
    if (old.visibility != new_.visibility) {
      changes['visibility'] = {
        'from': old.visibility.toString(),
        'to': new_.visibility.toString(),
      };
    }
    return changes;
  }
}
```

## Friend-Based Permissions

```dart
class SocialRecipeRepository extends BaseFirebaseRepository<SharedRecipe> {
  final FriendsRepository _friendsRepository;

  /// Share recipe with friends
  Future<void> shareWithFriends(
    String recipeId,
    List<String> friendIds,
  ) async {
    final currentUserId = authRepository.currentUserId!;

    // Validate all recipients are friends
    for (final friendId in friendIds) {
      final areFriends = await _friendsRepository.areFriends(
        currentUserId,
        friendId,
      );
      if (!areFriends) {
        throw UnauthorizedException('Can only share with friends');
      }
    }

    // Update recipe with shared access
    final recipe = await getById(recipeId);
    if (recipe == null) {
      throw NotFoundException('Recipe not found');
    }

    if (recipe.ownerId != currentUserId) {
      throw UnauthorizedException('Only owner can share recipe');
    }

    final updatedSharedWith = [
      ...recipe.sharedWith,
      ...friendIds,
    ].toSet().toList();

    await update(recipe.copyWith(sharedWith: updatedSharedWith));

    await logAuditEvent(
      action: 'recipe_shared',
      resourceId: recipeId,
      userId: currentUserId,
      metadata: {
        'shared_with': friendIds,
        'friend_count': friendIds.length,
      },
    );
  }

  /// Remove shared access
  Future<void> unshareRecipe(String recipeId, String userId) async {
    final currentUserId = authRepository.currentUserId!;
    final recipe = await getById(recipeId);

    if (recipe == null) {
      throw NotFoundException('Recipe not found');
    }

    // Owner can unshare
    // Or user can remove their own access
    if (recipe.ownerId != currentUserId && userId != currentUserId) {
      throw UnauthorizedException('Cannot remove access');
    }

    final updatedSharedWith = recipe.sharedWith
        .where((id) => id != userId)
        .toList();

    await update(recipe.copyWith(sharedWith: updatedSharedWith));

    await logAuditEvent(
      action: 'recipe_unshared',
      resourceId: recipeId,
      userId: currentUserId,
      metadata: {
        'removed_user': userId,
      },
    );
  }
}
```

## Permission Caching

Cache permission checks to avoid redundant queries:

```dart
class RecipeRepository extends BaseFirebaseRepository<Recipe> {
  final Map<String, bool> _permissionCache = {};

  @override
  Future<void> validateReadPermission(String id) async {
    final currentUserId = authRepository.currentUserId!;
    final cacheKey = 'read_${id}_$currentUserId';

    // Check cache
    if (_permissionCache[cacheKey] == true) {
      return;
    }

    // Perform actual validation
    await super.validateReadPermission(id);

    // Cache result (with TTL in production)
    _permissionCache[cacheKey] = true;
  }

  /// Clear permission cache (call when permissions change)
  void clearPermissionCache() {
    _permissionCache.clear();
  }
}
```

## Testing Permission Validation

```dart
void main() {
  late FakeFirebaseFirestore firestore;
  late MockAuthRepository mockAuth;
  late RecipeRepository repository;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    mockAuth = MockAuthRepository();
    repository = RecipeRepository(
      firestore: firestore,
      authRepository: mockAuth,
    );
  });

  group('Permission Validation', () {
    test('prevents unauthenticated create', () async {
      when(() => mockAuth.currentUserId).thenReturn(null);

      final recipe = Recipe(
        id: '1',
        userId: 'user_1',
        title: 'Recipe',
        portions: 4,
      );

      expect(
        () => repository.create(recipe),
        throwsA(isA<UnauthorizedException>()),
      );
    });

    test('prevents creating recipe for another user', () async {
      when(() => mockAuth.currentUserId).thenReturn('user_1');

      final recipe = Recipe(
        id: '1',
        userId: 'user_2', // Different user!
        title: 'Recipe',
        portions: 4,
      );

      expect(
        () => repository.create(recipe),
        throwsA(isA<UnauthorizedException>()),
      );
    });

    test('allows owner to read their recipe', () async {
      when(() => mockAuth.currentUserId).thenReturn('user_1');

      await firestore
          .collection('users')
          .doc('user_1')
          .collection('recipes')
          .doc('recipe_1')
          .set({
        'userId': 'user_1',
        'title': 'My Recipe',
        'portions': 4,
        'visibility': 'private',
      });

      final recipe = await repository.getById('recipe_1');

      expect(recipe, isNotNull);
      expect(recipe!.title, 'My Recipe');
    });

    test('prevents reading another user\'s private recipe', () async {
      when(() => mockAuth.currentUserId).thenReturn('user_2');

      await firestore
          .collection('users')
          .doc('user_1')
          .collection('recipes')
          .doc('recipe_1')
          .set({
        'userId': 'user_1',
        'title': 'Private Recipe',
        'portions': 4,
        'visibility': 'private',
        'sharedWith': [],
      });

      expect(
        () => repository.getById('recipe_1'),
        throwsA(isA<UnauthorizedException>()),
      );
    });

    test('allows reading shared recipe', () async {
      when(() => mockAuth.currentUserId).thenReturn('user_2');

      await firestore.collection('sharedRecipes').doc('recipe_1').set({
        'ownerId': 'user_1',
        'title': 'Shared Recipe',
        'portions': 4,
        'sharedWith': ['user_2', 'user_3'],
      });

      final recipe = await repository.getById('recipe_1');

      expect(recipe, isNotNull);
      expect(recipe!.title, 'Shared Recipe');
    });

    test('allows owner to update', () async {
      when(() => mockAuth.currentUserId).thenReturn('user_1');

      await firestore
          .collection('users')
          .doc('user_1')
          .collection('recipes')
          .doc('recipe_1')
          .set({
        'userId': 'user_1',
        'title': 'Original',
        'portions': 4,
      });

      final updated = Recipe(
        id: 'recipe_1',
        userId: 'user_1',
        title: 'Updated',
        portions: 6,
      );

      await repository.update(updated);

      final doc = await firestore
          .collection('users')
          .doc('user_1')
          .collection('recipes')
          .doc('recipe_1')
          .get();

      expect(doc['title'], 'Updated');
    });

    test('prevents non-owner from updating', () async {
      when(() => mockAuth.currentUserId).thenReturn('user_2');

      await firestore
          .collection('users')
          .doc('user_1')
          .collection('recipes')
          .doc('recipe_1')
          .set({
        'userId': 'user_1',
        'title': 'Recipe',
        'portions': 4,
        'editors': [], // user_2 not in editors list
      });

      final updated = Recipe(
        id: 'recipe_1',
        userId: 'user_1',
        title: 'Hacked',
        portions: 999,
      );

      expect(
        () => repository.update(updated),
        throwsA(isA<UnauthorizedException>()),
      );
    });

    test('only owner can delete', () async {
      when(() => mockAuth.currentUserId).thenReturn('user_2');

      await firestore
          .collection('users')
          .doc('user_1')
          .collection('recipes')
          .doc('recipe_1')
          .set({
        'userId': 'user_1',
        'title': 'Recipe',
        'portions': 4,
      });

      expect(
        () => repository.delete('recipe_1'),
        throwsA(isA<UnauthorizedException>()),
      );
    });
  });
}
```

## Best Practices

1. **Validate Early**: Check permissions before expensive operations
2. **Fail Secure**: Deny by default, allow only explicitly permitted actions
3. **Audit Everything**: Log all security-sensitive operations
4. **Use Specific Exceptions**: UnauthorizedException, NotFoundException, QuotaExceededException
5. **Test Negative Cases**: Test that unauthorized actions are blocked
6. **Cache Wisely**: Cache permission results but invalidate when permissions change
7. **Defense in Depth**: Combine client-side validation with Firestore security rules

## Related Resources

- [Base Repository Usage](base-repository-usage.md) - Repository fundamentals
- [Firestore Operations](firestore-operations.md) - Advanced queries and operations
