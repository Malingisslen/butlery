// lib/services/unified/operations/cooking/cooking_session_module.dart
//
// BUT-408: Orchestrates "Erik lagar just nu" presence broadcasts.
// Mirrors [ShoppingPresenceModule] but scoped to cooking sessions and backed
// by Realtime Database instead of Firestore.
//
// Broadcast model: on cooking mode enter, write one row per FriendCategory
// the user is a member of (owner OR in `friendUserIds`). Max ~5 writes,
// capped by the user's actual group count. Errors are swallowed — a dropped
// broadcast must never block the cook.

import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/models/cooking/cooking_session.dart';
import 'package:butlery/models/friend_category.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/repositories/firebase/firebase_cooking_session_repository.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/services/unified/unified_friends_service.dart';
import 'package:butlery/services/user_service.dart';

/// Public contract for cooking session presence — registered as the
/// interface type so tests can swap in a fake without reaching into RTDB.
abstract class CookingSessionModule {
  /// Announce that the current user has entered cooking mode for [recipe].
  /// Writes one presence row to every FriendCategory the user is a member of.
  Future<void> startSession(Recipe recipe);

  /// Clear the current user's presence from every FriendCategory they belong
  /// to. Safe to call when no session is active (no-op).
  Future<void> endSession();

  /// Stream of active cooking sessions within a single group, for UI cards.
  Stream<List<CookingSession>> watchGroupSessions(String groupId);
}

/// RTDB-backed implementation used in production.
class FirebaseCookingSessionModule implements CookingSessionModule {
  final FirebaseCookingSessionRepository _repository;
  final PermissionService? _permissionServiceOverride;
  final UnifiedFriendsService? _friendsServiceOverride;
  final UserService? _userServiceOverride;

  FirebaseCookingSessionModule({
    required FirebaseCookingSessionRepository repository,
    PermissionService? permissionService,
    UnifiedFriendsService? friendsService,
    UserService? userService,
  })  : _repository = repository,
        _permissionServiceOverride = permissionService,
        _friendsServiceOverride = friendsService,
        _userServiceOverride = userService;

  PermissionService get _permissionService =>
      _permissionServiceOverride ?? ServiceLocator.get<PermissionService>();

  UnifiedFriendsService get _friendsService =>
      _friendsServiceOverride ?? ServiceLocator.get<UnifiedFriendsService>();

  UserService get _userService =>
      _userServiceOverride ?? ServiceLocator.get<UserService>();

  @override
  Future<void> startSession(Recipe recipe) async {
    if (!_permissionService.isAuthenticated) return;
    final currentUser = _permissionService.currentUser;
    if (currentUser == null) return;

    // Prefer the richer UserService profile (displayName may be edited there)
    // and fall back to PermissionService's auth-derived value if unavailable.
    final profile = _userService.currentUserProfile;
    final displayName = profile?.displayName ?? currentUser.displayName;
    final avatarUrl = profile?.avatarUrl ?? currentUser.avatarUrl;

    final groups = _resolveGroups(currentUser.uid);
    if (groups.isEmpty) return; // Solo cook — nothing to broadcast.

    final session = CookingSession(
      recipeId: recipe.id,
      recipeTitle: recipe.title,
      recipeImageUrl: recipe.primaryImageUrl,
      startedAt: DateTime.now(),
      userId: currentUser.uid,
      userName: displayName,
      userAvatar: avatarUrl,
    );

    // Fire all broadcasts concurrently; per-group failures are already
    // swallowed inside the repository, so a single bad group doesn't take
    // down the rest.
    await Future.wait(
      groups.map((g) => _repository.startSession(
            groupId: g.id,
            session: session,
          )),
      eagerError: false,
    );
    AppLogger.info(
      'Cooking session broadcast to ${groups.length} group(s)',
    );
  }

  @override
  Future<void> endSession() async {
    if (!_permissionService.isAuthenticated) return;
    final userId = _permissionService.currentUserId;
    if (userId == null) return;

    final groups = _resolveGroups(userId);
    if (groups.isEmpty) return;

    await Future.wait(
      groups.map((g) => _repository.endSession(
            groupId: g.id,
            userId: userId,
          )),
      eagerError: false,
    );
    AppLogger.info('Cooking session cleared from ${groups.length} group(s)');
  }

  @override
  Stream<List<CookingSession>> watchGroupSessions(String groupId) {
    return _repository.watchSessions(groupId);
  }

  /// Every FriendCategory the user participates in — as owner or member.
  List<FriendCategory> _resolveGroups(String userId) {
    try {
      return _friendsService.categoriesList
          .where((c) => c.ownerId == userId || c.friendUserIds.contains(userId))
          .toList(growable: false);
    } catch (e) {
      // Friends service may not be initialized yet (first-run / offline).
      // Returning empty = "no broadcast" is the safe fallback.
      AppLogger.warning('Failed to resolve friend groups for session: $e');
      return const <FriendCategory>[];
    }
  }
}
