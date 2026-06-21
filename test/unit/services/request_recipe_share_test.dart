/// Intent-driven unit tests for the recipe-share *request* flow, now targeting
/// [RecipeShareRequestModule] directly (BUT read-friend-recipe plan Task 7;
/// extracted from SocialRecipeService in the Task-7 refactor).
///
/// Behaviours pinned:
/// 1. `requestRecipeShare` writes exactly ONE social_requests doc (type
///    recipeShareRequest, pending) AND sends exactly ONE notification to the
///    owner. This is the "ask a friend for a recipe" primitive.
/// 2. A second identical call (same from/owner/recipe) while a request is
///    pending is idempotent: NO second doc write, NO second notification.
///    Without this, a double-tap or re-open spams the owner.
/// 3. `acceptRecipeShareRequest` shares the recipe with the *requester* (by
///    uid) by adding them to the ORIGINAL recipe's memberPermissions (via
///    [SocialRecipeCoordinator.shareRecipeWithUsers]) and flips the request
///    status to accepted. This is the "accept → share" primitive the owner
///    runs. Sharing in place (not creating a new collaborative copy) is what
///    makes the recipe readable to the requester — the read path keys off the
///    original doc.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/core/providers/application_provider.dart' as production;
import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/models/social_request.dart';
import 'package:butlery/models/permissions/resource_permission.dart';
import 'package:butlery/services/social/modules/recipe_share_request_module.dart';
import 'package:butlery/services/user_service.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/services/unified/modules/social_recipe/social_recipe_coordinator.dart';
import 'package:butlery/services/notifications/notification_service.dart';
import 'package:butlery/services/notifications/notification_types.dart';
import 'package:butlery/repositories/firebase/firebase_social_request_repository.dart';

// -------------------- Fakes --------------------------------------------------

class _FakePermissionService extends Fake implements PermissionService {
  String? _uid;
  void setUserId(String? uid) => _uid = uid;

  @override
  String? get currentUserId => _uid;

  @override
  bool get isAuthenticated => _uid != null;
}

class _FakeUserService extends Fake implements UserService {
  String? displayName = 'Malin';

  @override
  String? get currentDisplayName => displayName;
}

/// Records `createRequest` writes and `updateRequestStatus` calls, and lets a
/// test pre-seed a pending request so the idempotency query short-circuits.
class _FakeSocialRequestRepository extends Fake
    implements FirebaseSocialRequestRepository {
  final List<SocialRequest> created = [];
  final List<(String, Map<String, dynamic>)> statusUpdates = [];

  // When true, `recipeShareRequestExists` reports a pending duplicate.
  bool existingPending = false;

  @override
  Future<bool> recipeShareRequestExists(
    String fromUserId,
    String toUserId,
    String recipeId,
  ) async =>
      existingPending;

  @override
  Future<void> createRequest(SocialRequest request) async {
    created.add(request);
  }

  @override
  Future<void> updateRequestStatus(
      String requestId, Map<String, dynamic> data) async {
    statusUpdates.add((requestId, data));
  }
}

/// Mocktail mock of the coordinator that owns the in-place share. The accept
/// flow now goes through [SocialRecipeCoordinator.shareRecipeWithUsers], which
/// adds the requester to the ORIGINAL recipe's memberPermissions.
class _MockSocialRecipeCoordinator extends Mock
    implements SocialRecipeCoordinator {}

/// Spy notification service: counts `sendImmediateNotification` invocations and
/// records the strategy + additionalData so we can assert deterministic content.
class _SpyNotificationService extends Fake implements NotificationService {
  int sendCount = 0;
  final List<List<String>> targets = [];
  final List<NotificationStrategy> strategies = [];
  final List<Map<String, String>> variables = [];
  final List<Map<String, dynamic>?> additionalData = [];

  @override
  Future<void> sendImmediateNotification({
    required List<String> targetUserIds,
    required NotificationStrategy strategy,
    required Map<String, String> variables,
    Map<String, dynamic>? additionalData,
    String? imageUrl,
    List<NotificationAction>? actions,
  }) async {
    sendCount++;
    targets.add(targetUserIds);
    strategies.add(strategy);
    this.variables.add(variables);
    this.additionalData.add(additionalData);
  }
}

/// Always throws when `sendImmediateNotification` is called — used to verify
/// that a notification failure does not fail the overall request operation.
class _ThrowingNotificationService extends Fake implements NotificationService {
  @override
  Future<void> sendImmediateNotification({
    required List<String> targetUserIds,
    required NotificationStrategy strategy,
    required Map<String, String> variables,
    Map<String, dynamic>? additionalData,
    String? imageUrl,
    List<NotificationAction>? actions,
  }) async {
    throw Exception('Simulated notification failure');
  }
}

void main() {
  late _FakePermissionService permission;
  late _FakeUserService userService;
  late _FakeSocialRequestRepository requestRepo;
  late _MockSocialRecipeCoordinator coordinator;
  late _SpyNotificationService notifier;
  late RecipeShareRequestModule module;

  setUpAll(() {
    production.ServiceLocator.initialize(DIContainer());
    registerFallbackValue(<String>[]);
    registerFallbackValue(ResourcePermission.viewer);
  });

  setUp(() {
    permission = _FakePermissionService()..setUserId('me-uid');
    userService = _FakeUserService();
    requestRepo = _FakeSocialRequestRepository();
    coordinator = _MockSocialRecipeCoordinator();
    notifier = _SpyNotificationService();

    // Default: the in-place share succeeds. Individual tests override.
    when(() => coordinator.shareRecipeWithUsers(any(), any(), any()))
        .thenAnswer((_) async => true);

    if (GetIt.instance.isRegistered<NotificationService>()) {
      GetIt.instance.unregister<NotificationService>();
    }
    GetIt.instance.registerSingleton<NotificationService>(notifier);

    if (GetIt.instance.isRegistered<SocialRecipeCoordinator>()) {
      GetIt.instance.unregister<SocialRecipeCoordinator>();
    }
    GetIt.instance.registerSingleton<SocialRecipeCoordinator>(coordinator);

    module = RecipeShareRequestModule(
      socialRequestRepository: requestRepo,
      permissionService: permission,
      userService: userService,
    );
  });

  tearDown(() {
    if (GetIt.instance.isRegistered<NotificationService>()) {
      GetIt.instance.unregister<NotificationService>();
    }
    if (GetIt.instance.isRegistered<SocialRecipeCoordinator>()) {
      GetIt.instance.unregister<SocialRecipeCoordinator>();
    }
  });

  group('requestRecipeShare', () {
    test('writes one pending request and sends one notification', () async {
      final ok = await module.requestRecipeShare(
        ownerId: 'owner-uid',
        recipeId: 'recipe-1',
        recipeTitle: 'Pannkakor',
      );

      expect(ok, isTrue);

      // One request written, of the right type/status/triple.
      expect(requestRepo.created, hasLength(1));
      final req = requestRepo.created.single;
      expect(req.type, SocialRequestType.recipeShareRequest);
      expect(req.status, SocialRequestStatus.pending);
      expect(req.fromUserId, 'me-uid');
      expect(req.toUserId, 'owner-uid');
      expect(req.recipeId, 'recipe-1');
      expect(req.recipeTitle, 'Pannkakor');
      // Requester display name is stamped so the owner sees who asked.
      expect(req.fromUserName, 'Malin');

      // Exactly one notification, to the owner.
      expect(notifier.sendCount, 1);
      expect(notifier.targets.single, ['owner-uid']);

      // Deep-link payload carries both recipeId and fromUserId so the owner
      // can be routed to the recipe and back to the requester.
      final data = notifier.additionalData.single!;
      expect(data['recipeId'], 'recipe-1');
      expect(data['fromUserId'], 'me-uid');
      // Payload type must be recipeShareRequest, not friendRequest.
      expect(data['type'], NotificationPayloadType.recipeShareRequest);
    });

    test('null current user → false, no write, no notification', () async {
      permission.setUserId(null);

      final ok = await module.requestRecipeShare(
        ownerId: 'owner-uid',
        recipeId: 'recipe-1',
        recipeTitle: 'Pannkakor',
      );

      expect(ok, isFalse);
      expect(requestRepo.created, isEmpty);
      expect(notifier.sendCount, 0);
    });

    test(
        'idempotent: second identical call while pending → no 2nd write, no 2nd notification',
        () async {
      // First call lands.
      final first = await module.requestRecipeShare(
        ownerId: 'owner-uid',
        recipeId: 'recipe-1',
        recipeTitle: 'Pannkakor',
      );
      expect(first, isTrue);
      expect(requestRepo.created, hasLength(1));
      expect(notifier.sendCount, 1);

      // Simulate the now-pending request being visible to the dedup query.
      requestRepo.existingPending = true;

      final second = await module.requestRecipeShare(
        ownerId: 'owner-uid',
        recipeId: 'recipe-1',
        recipeTitle: 'Pannkakor',
      );

      // Still "succeeds" (returns true — the request exists), but is a no-op.
      expect(second, isTrue);
      expect(requestRepo.created, hasLength(1),
          reason: 'no duplicate request doc');
      expect(notifier.sendCount, 1, reason: 'no duplicate notification');
    });

    test(
        'notification failure is non-fatal: returns true and request is persisted',
        () async {
      // Replace the spy with one that throws on send.
      GetIt.instance.unregister<NotificationService>();
      GetIt.instance.registerSingleton<NotificationService>(
        _ThrowingNotificationService(),
      );

      final ok = await module.requestRecipeShare(
        ownerId: 'owner-uid',
        recipeId: 'recipe-1',
        recipeTitle: 'Pannkakor',
      );

      // The request doc is written even though the notification threw.
      expect(ok, isTrue,
          reason: 'notification failure must not flip the result');
      expect(requestRepo.created, hasLength(1),
          reason: 'request persisted before the notification attempt');
    });
  });

  group('acceptRecipeShareRequest', () {
    SocialRequest makeRequest() => SocialRequest.recipeShareRequest(
          fromUserId: 'requester-uid',
          toUserId: 'me-uid',
          recipeId: 'recipe-1',
          recipeTitle: 'Pannkakor',
          fromUserName: 'Alex',
        );

    test(
        'adds requester to the ORIGINAL recipe in place and flips status to accepted',
        () async {
      final req = makeRequest();

      final ok = await module.acceptRecipeShareRequest(req);

      expect(ok, isTrue);

      // In-place share: requester added to the ORIGINAL recipe id as viewer.
      // This is what makes the recipe readable to the requester.
      verify(() => coordinator.shareRecipeWithUsers(
            'recipe-1',
            ['requester-uid'],
            ResourcePermission.viewer,
          )).called(1);

      // Status flipped to accepted for this request id.
      expect(requestRepo.statusUpdates, hasLength(1));
      final update = requestRepo.statusUpdates.single;
      expect(update.$1, req.id);
      expect(update.$2['status'], SocialRequestStatus.accepted.name);
    });

    test('null recipeId → false, no share, no status update', () async {
      final req = SocialRequest(
        id: 'rq-1',
        type: SocialRequestType.recipeShareRequest,
        fromUserId: 'requester-uid',
        toUserId: 'me-uid',
        // recipeId intentionally omitted (null)
      );

      final ok = await module.acceptRecipeShareRequest(req);

      expect(ok, isFalse);
      verifyNever(() => coordinator.shareRecipeWithUsers(any(), any(), any()));
      expect(requestRepo.statusUpdates, isEmpty);
    });

    test('share fails (returns false) → false, status NOT flipped', () async {
      when(() => coordinator.shareRecipeWithUsers(any(), any(), any()))
          .thenAnswer((_) async => false);
      final req = makeRequest();

      final ok = await module.acceptRecipeShareRequest(req);

      expect(ok, isFalse);
      expect(requestRepo.statusUpdates, isEmpty,
          reason: 'must not mark accepted when the share itself failed');
    });

    test('owner guard: non-owner currentUserId → false, no share', () async {
      // Current user is someone other than the request's toUserId ('me-uid').
      permission.setUserId('intruder-uid');
      final req = makeRequest(); // toUserId == 'me-uid'

      final ok = await module.acceptRecipeShareRequest(req);

      expect(ok, isFalse,
          reason: 'only the recipe owner (toUserId) may accept');
      verifyNever(() => coordinator.shareRecipeWithUsers(any(), any(), any()));
      expect(requestRepo.statusUpdates, isEmpty,
          reason: 'status must not be flipped for a non-owner');
    });
  });
}
