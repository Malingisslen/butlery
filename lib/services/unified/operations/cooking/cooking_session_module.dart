// Mirrors [ShoppingPresenceModule] but scoped to cooking sessions and backed
// by RTDB. On enter, writes one presence row per FriendCategory the user
// belongs to. Errors are swallowed — a dropped broadcast must never block
// the cook itself.

import 'package:clock/clock.dart';
import 'dart:async';

import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/models/cooking/cooking_session.dart';
import 'package:butlery/models/friend_category.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/repositories/firebase/firebase_cooking_session_repository.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/services/unified/unified_friends_service.dart';
import 'package:butlery/services/user_service.dart';

abstract class CookingSessionModule {
  Future<void> startSession(Recipe recipe);
  Future<void> endSession();

  // Patches only the step fields on each active presence row. Debounced —
  // the returned Future completes when the write is *scheduled*; the write
  // fires after [stepDebounce] of quiet. Calls with the same pair as the
  // last-flushed values are suppressed.
  Future<void> updateStep({
    required int currentStep,
    required int totalSteps,
  });

  Stream<List<CookingSession>> watchGroupSessions(String groupId);

  // Cancel the pending debounce + clear in-memory state. Called on user-scope
  // teardown (logout) so a mid-cook timer doesn't outlive the DI container.
  void dispose();
}

/// Window used to coalesce rapid [updateStep] calls into a single RTDB
/// write. Public to tests so they can `fakeAsync.elapse` past it precisely.
const Duration stepDebounce = Duration(milliseconds: 500);

/// RTDB-backed implementation used in production.
class FirebaseCookingSessionModule implements CookingSessionModule {
  final FirebaseCookingSessionRepository _repository;
  final PermissionService? _permissionServiceOverride;
  final UnifiedFriendsService? _friendsServiceOverride;
  final UserService? _userServiceOverride;

  /// Group IDs where the current user currently has an active session row,
  /// captured at [startSession] time. Used by [updateStep] to target the
  /// exact nodes without re-resolving friend categories (which may have
  /// shifted mid-cook due to a concurrent invite accept, etc.).
  final Set<String> _activeGroupIds = <String>{};

  Timer? _pendingStepTimer;
  int? _pendingCurrentStep;
  int? _pendingTotalSteps;

  // Last pair actually flushed to RTDB — used to suppress redundant writes
  // when the user toggles back to an already-broadcast step.
  int? _lastFlushedCurrentStep;
  int? _lastFlushedTotalSteps;

  FirebaseCookingSessionModule({
    required FirebaseCookingSessionRepository repository,
    PermissionService? permissionService,
    UnifiedFriendsService? friendsService,
    UserService? userService,
  }) : _repository = repository,
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
      startedAt: clock.now(),
      userId: currentUser.uid,
      userName: displayName,
      userAvatar: avatarUrl,
    );

    // Fire all broadcasts concurrently; per-group failures are already
    // swallowed inside the repository, so a single bad group doesn't take
    // down the rest.
    await Future.wait(
      groups.map(
        (g) => _repository.startSession(
          groupId: g.id,
          session: session,
        ),
      ),
      eagerError: false,
    );
    _activeGroupIds
      ..clear()
      ..addAll(groups.map((g) => g.id));
    AppLogger.info(
      'Cooking session broadcast to ${groups.length} group(s)',
    );
  }

  @override
  Future<void> endSession() async {
    // Cancel any pending step broadcast — otherwise the timer would fire
    // AFTER we've removed the RTDB node and resurrect an orphan with only
    // currentStep/totalSteps set (recipe fields would be missing).
    _cancelPendingStep();

    if (!_permissionService.isAuthenticated) return;
    final userId = _permissionService.currentUserId;
    if (userId == null) return;

    // Clear by the set we actually wrote — not by re-resolving groups, which
    // could have drifted mid-cook and leave stray rows behind.
    final targetGroupIds = _activeGroupIds.isNotEmpty
        ? List<String>.from(_activeGroupIds)
        : _resolveGroups(userId).map((g) => g.id).toList(growable: false);
    if (targetGroupIds.isEmpty) {
      _activeGroupIds.clear();
      return;
    }

    await Future.wait(
      targetGroupIds.map(
        (id) => _repository.endSession(
          groupId: id,
          userId: userId,
        ),
      ),
      eagerError: false,
    );
    _activeGroupIds.clear();
    AppLogger.info(
      'Cooking session cleared from ${targetGroupIds.length} group(s)',
    );
  }

  @override
  Future<void> updateStep({
    required int currentStep,
    required int totalSteps,
  }) async {
    // Do NOT schedule for an inactive session — a later startSession would
    // resurrect the pending write with stale step data.
    if (_activeGroupIds.isEmpty) return;

    // Skip work when the caller is re-broadcasting the same pair we already
    // flushed. Guards against rebuild-triggered updateStep storms.
    if (currentStep == _lastFlushedCurrentStep &&
        totalSteps == _lastFlushedTotalSteps) {
      return;
    }

    _pendingCurrentStep = currentStep;
    _pendingTotalSteps = totalSteps;

    _pendingStepTimer?.cancel();
    _pendingStepTimer = Timer(stepDebounce, _flushPendingStep);
  }

  Future<void> _flushPendingStep() async {
    _pendingStepTimer = null;
    final current = _pendingCurrentStep;
    final total = _pendingTotalSteps;
    _pendingCurrentStep = null;
    _pendingTotalSteps = null;

    if (current == null || total == null) return;
    if (_activeGroupIds.isEmpty) return;
    if (!_permissionService.isAuthenticated) return;
    final userId = _permissionService.currentUserId;
    if (userId == null) return;

    try {
      await Future.wait(
        _activeGroupIds.map(
          (groupId) => _repository.updateStep(
            groupId: groupId,
            userId: userId,
            currentStep: current,
            totalSteps: total,
          ),
        ),
        eagerError: false,
      );
      _lastFlushedCurrentStep = current;
      _lastFlushedTotalSteps = total;
    } catch (e) {
      // Per-group failures already swallowed in the repo; this catches the
      // rare case where Future.wait itself throws.
      AppLogger.warning('Cooking session step flush failed: $e');
    }
  }

  void _cancelPendingStep() {
    _pendingStepTimer?.cancel();
    _pendingStepTimer = null;
    _pendingCurrentStep = null;
    _pendingTotalSteps = null;
    _lastFlushedCurrentStep = null;
    _lastFlushedTotalSteps = null;
  }

  @override
  Stream<List<CookingSession>> watchGroupSessions(String groupId) {
    return _repository.watchSessions(groupId);
  }

  @override
  void dispose() {
    _cancelPendingStep();
    _activeGroupIds.clear();
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
