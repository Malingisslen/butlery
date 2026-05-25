/// Intent-driven unit tests for [SocialShoppingCoordinator] (Intent-Test
/// Sprint batch 6, 2026-05-25). Third member of the social-coordinator
/// family — followed batch-4 SocialRecipeService (BUT-1086 / BUT-1087)
/// and batch-5 SocialMenuCoordinator (BUT-1090 / BUT-1094). This pins
/// the shopping-side coordinator that `SharedShoppingViewModel` and the
/// collaborative-shopping flow rely on.
///
/// Behaviours pinned:
/// - Identity: `serviceName` (`SocialShoppingCoordinator`) and
///   `contentTypeName` (`shopping_list`). Both are interpolated into log
///   strings and used for counter routing; a rename here is silent damage.
/// - `getContentTitle`: returns the list's `name` verbatim. The "Delat
///   med mig" card title comes from here — a wrong field would render
///   blank cards or leak description text into the title slot.
/// - `validateShoppingListForSharing`: empty-name → false; empty-items →
///   false; valid → true. Gates the share button. Without these guards
///   users could ship empty SharedShoppingList docs.
/// - `getShoppingListSummary`: empty → localized "Tom handlingslista";
///   all-done → localized "Alla N artiklar klara"; nothing-bought →
///   "N artiklar att köpa"; mid-progress → "R av T artiklar kvar". All
///   four branches matter — UI shows this chip on every shared-list card.
/// - `canUserEditShoppingList`: owner ALWAYS true (even without an entry
///   in memberPermissions); member with `edit` → true; member with
///   `admin` → true; member with `view` → false; non-member → false.
///   Permission gate for the inline edit affordance.
/// - `isCollaborativeShoppingList`: requires BOTH `type == collaborative`
///   AND non-empty memberPermissions. A personal list with members or a
///   collaborative list with no members → false. Pins the AND.
/// - `createSharedContentModel`: pulls listName + itemCount from the
///   snapshot, propagates shoppingListId for the join-back resolution,
///   defaults shareMessage to '' when null, and uses `items.length` for
///   itemCount (NOT a hardcoded zero).
/// - `createImportedContent`: produces a COLLABORATIVE list (not
///   personal); always starts with `items: []` per the Issue #015
///   subcollection contract; uses sharedByUserId as ownerId; adds the
///   joining user as `edit` permission; allowGuestEditing forced to
///   false. Owner auto-gets admin via the factory.
/// - `createImportedContent` newTitle override: if `newTitle` is null,
///   falls back to `sharedContent.listName`; if provided, overrides it.
/// - `getOriginalContentFromShared`: returns a fresh UnifiedShoppingList
///   (NOT the items subcollection content — known limitation: returns
///   empty items per Issue #015). Owner gets admin permission.
/// - `getSharedByUserId`: pure pass-through (`shared.sharedByUserId`).
///   Underpins CoW ownership routing.
/// - `triggerCopyOnWriteForContent`: shopping lists DON'T use CoW —
///   returns the input unchanged regardless of editingUserId. This is
///   the documented divergence from recipes/menus.
/// - `createStaticCopyForOwner`: returns null (no copy semantics for
///   shopping). Pins the "direct collaboration" contract.
/// - `importSharedContent` override: delegates to `joinSharedShoppingList`.
///   For shopping lists "import" IS "join" — different semantics from
///   recipes/menus where import creates a copy.
/// - `getSharedShoppingListsForUser`: error swallow → empty list, no
///   rethrow. UI tab must render empty state on a permission/offline error.
/// - `getJoinedShoppingLists`: unauthenticated → empty list, no throw.
///   Failed repo → empty list AND sets error.
/// - `joinSharedShoppingList`: unauthenticated → null; not-found → null;
///   repo-throw IS caught (try-catch wraps the read) → null + error set
///   — opposite shape from the BUT-1090 bug in SocialMenuCoordinator.
/// - `loadStatusForShoppingList`: caches viewed/imported/dismissed status
///   from repository calls; `is*` getters return cached values.
/// - `isShoppingList{Viewed,Imported,Dismissed}`: cache miss → false.
///   A flip to `true` would mark every unseen list as already-viewed.
/// - `loadStatusForAllShoppingLists`: iterates and caches each list.
///
/// Bug-finding cross-references (REPORTED, not fixed here):
///
/// - **BUT-1094 (inconsistent `_error` population) — APPLIES HERE TOO**:
///   `getSharedShoppingListsForUser` (line 332) silently swallows repo
///   errors and returns `[]` without calling `setError`. Same shape as
///   BUT-1087 (SocialRecipeService) and BUT-1094 (SocialMenuCoordinator).
///   `loadStatusForShoppingList` (line 349) ALSO swallows without error.
///   The base class's `markAsViewed` (base line 408) and `getUnreadCount`
///   (base line 425) also lack `_error`. `joinSharedShoppingList` DOES
///   set error correctly — inconsistency within the same file. File as
///   "BUT-1094 family extension".
///
/// - **BUT-1090 (missing try-catch on `joinSharedMenu`) — NOT REPRODUCED**:
///   `joinSharedShoppingList` properly wraps the `_sharedShoppingRepository.read()`
///   call in try-catch (production lines 282–322). This is the CORRECT
///   pattern — `SocialMenuCoordinator.joinSharedMenu` should mirror it.
///   Pin the correct contract here so a regression is caught.
///
/// - **BUT-1095 (hardwired repo in constructor) — APPLIES HERE TOO**:
///   line 113: `_sharedShoppingRepository = ServiceLocator.get<FirebaseSharedShoppingRepository>();`.
///   At least this one goes through ServiceLocator (mockable via GetIt) —
///   slightly better than the SocialMenuCoordinator pattern of direct
///   `FirebaseSharedShoppingRepository()` instantiation, but still no
///   constructor seam. The `ShoppingListServiceAdapter` ALSO defaults
///   to `ServiceLocator.get<UnifiedShoppingService>()` (line 61). File
///   as BUT-1095-family: "missing constructor injection for shared repo
///   means tests must touch ServiceLocator/GetIt".
///
/// - **Save-through is a no-op (line 72–76)**:
///   `ShoppingListServiceAdapter.saveShoppingList` logs and returns
///   `shoppingList.id` WITHOUT saving anything. The comment says
///   "shopping uses direct collaboration, not save-through-coordinator"
///   — fine as documented behaviour, but this means `saveImportedContent`
///   silently no-ops. Pinned: the contract is "return the id" rather
///   than "actually save". Not a bug, but a foot-gun for anyone wiring
///   it up later.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:get_it/get_it.dart';

import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart' as production;
import 'package:butlery/models/shared_shopping_list.dart';
import 'package:butlery/models/unified/unified_shopping_item.dart';
import 'package:butlery/models/unified/unified_shopping_list.dart';
import 'package:butlery/repositories/firebase/firebase_shared_shopping_repository.dart';
import 'package:butlery/services/unified/modules/social_shopping/social_shopping_coordinator.dart';
import 'package:butlery/services/unified/unified_shopping_service.dart';

import '../../../../../infrastructure/di/test_service_locator.dart';
import '../../../../../test_support/base_unit_test.dart';

class _MockSharedShoppingRepo extends Mock
    implements FirebaseSharedShoppingRepository {}

/// Fake adapter so we don't need the real UnifiedShoppingService chain
/// when validating the coordinator's `_serviceAdapter` injection path.
class _FakeServiceAdapter extends ShoppingListServiceAdapter {
  _FakeServiceAdapter() : super(shoppingService: _NoopShoppingService());
}

/// Tiny stub fulfilling the constructor's `lists` getter so the adapter
/// can be built without spinning up the full UnifiedShoppingService graph.
class _NoopShoppingService extends Mock implements UnifiedShoppingService {
  @override
  List<UnifiedShoppingList> get lists => const [];
}

UnifiedShoppingItem _item({
  String name = 'mjölk',
  double amount = 1,
  bool bought = false,
}) {
  return UnifiedShoppingItem.basic(name: name, amount: amount, bought: bought);
}

UnifiedShoppingList _personalList({
  String name = 'Inköp',
  String ownerId = 'me-uid',
  List<UnifiedShoppingItem>? items,
}) {
  return UnifiedShoppingList.personal(
    name: name,
    ownerId: ownerId,
    ownerDisplayName: 'Anna',
    items: items ?? [_item()],
  );
}

UnifiedShoppingList _collabList({
  String name = 'Helgshandling',
  String ownerId = 'owner-uid',
  Map<String, SharedListPermission>? perms,
  List<UnifiedShoppingItem>? items,
}) {
  return UnifiedShoppingList.collaborative(
    name: name,
    ownerId: ownerId,
    ownerDisplayName: 'Owner',
    memberPermissions: perms ?? const {},
    items: items ?? [_item()],
  );
}

SharedShoppingList _sharedList({
  String id = 'shared-1',
  String listName = 'Helgshandling',
  String sharedByUserId = 'sender-uid',
  String sharedByDisplayName = 'Bob',
  String? shoppingListId = 'orig-list-id',
  int itemCount = 3,
  String? listDescription,
}) {
  return SharedShoppingList(
    id: id,
    sharedByUserId: sharedByUserId,
    sharedByDisplayName: sharedByDisplayName,
    listName: listName,
    listDescription: listDescription,
    itemCount: itemCount,
    originalOwnerId: sharedByUserId,
    originalOwnerDisplayName: sharedByDisplayName,
    shoppingListId: shoppingListId,
  );
}

void main() {
  setUpAll(() async {
    await BaseUnitTest.setupUnit();
    registerFallbackValue(_personalList());
  });

  group('SocialShoppingCoordinator', () {
    late SocialShoppingCoordinator coordinator;
    late _MockSharedShoppingRepo mockRepo;
    late Map<String, UnifiedShoppingList> store;
    late String? currentUserId;
    late String? currentUserDisplayName;
    late int notifyCount;
    late String? lastError;
    late List<UnifiedShoppingList> savedLists;
    String? saveResult;

    setUp(() async {
      await TestServiceLocator.initialize();
      // The coordinator constructor calls
      // ServiceLocator.get<FirebaseSharedShoppingRepository>(); register
      // a mock in the SAME GetIt instance that backs both ServiceLocators.
      production.ServiceLocator.initialize(DIContainer());

      mockRepo = _MockSharedShoppingRepo();
      final getIt = GetIt.instance;
      if (getIt.isRegistered<FirebaseSharedShoppingRepository>()) {
        getIt.unregister<FirebaseSharedShoppingRepository>();
      }
      getIt.registerSingleton<FirebaseSharedShoppingRepository>(mockRepo);

      currentUserId = 'me-uid';
      currentUserDisplayName = 'Anna';
      notifyCount = 0;
      lastError = null;
      store = {};
      savedLists = [];
      saveResult = 'saved-list-id';

      coordinator = SocialShoppingCoordinator(
        getCurrentUserId: () => currentUserId,
        getCurrentUserDisplayName: () => currentUserDisplayName,
        setError: (e) => lastError = e,
        notifyListeners: () => notifyCount++,
        getShoppingList: (id) async => store[id],
        saveShoppingList: (list) async {
          savedLists.add(list);
          return saveResult;
        },
        serviceAdapter: _FakeServiceAdapter(),
      );
    });

    tearDown(() async {
      final getIt = GetIt.instance;
      if (getIt.isRegistered<FirebaseSharedShoppingRepository>()) {
        getIt.unregister<FirebaseSharedShoppingRepository>();
      }
      await TestServiceLocator.reset();
      BaseUnitTest.resetMocks();
    });

    tearDownAll(() async {
      await BaseUnitTest.teardownUnit();
    });

    // ---------------------------------------------------------------------
    // Identity contracts
    // ---------------------------------------------------------------------
    group('Identity', () {
      /// Pins serviceName. Renaming silently would break log filter dashboards
      /// (e.g. Crashlytics filters by serviceName for shopping-related issues).
      test('serviceName is "SocialShoppingCoordinator"', () {
        expect(coordinator.serviceName, 'SocialShoppingCoordinator');
      });

      /// Pins contentTypeName — interpolated into log strings AND used by
      /// the BaseSharedContentRepository for counter routing. A typo
      /// would silently route counters to the wrong content type.
      test('contentTypeName is "shopping_list"', () {
        expect(coordinator.contentTypeName, 'shopping_list');
      });
    });

    // ---------------------------------------------------------------------
    // getContentTitle — pinned to the name field, not description
    // ---------------------------------------------------------------------
    group('getContentTitle', () {
      /// The card title is the list name. A bug that swapped to
      /// `description` would render blank or wrong-string cards.
      test('returns the list name verbatim', () {
        final list = _personalList(name: 'Veckans inköp');
        expect(coordinator.getContentTitle(list), 'Veckans inköp');
      });

      /// Edge: empty-name list still returns empty (not a fallback). The
      /// share-button gate is `validateShoppingListForSharing`, not here;
      /// title extraction stays pure.
      test('empty name → empty string (no silent fallback)', () {
        final list = _personalList(name: '', items: [_item()]);
        expect(coordinator.getContentTitle(list), '');
      });
    });

    // ---------------------------------------------------------------------
    // validateShoppingListForSharing — gates the share button
    // ---------------------------------------------------------------------
    group('validateShoppingListForSharing', () {
      /// Empty name → false. Without this guard users could ship docs
      /// with no display label.
      test('empty name → false', () {
        final list = _personalList(name: '', items: [_item()]);
        expect(coordinator.validateShoppingListForSharing(list), isFalse);
      });

      /// Empty items → false. Shipping an empty list creates broken
      /// "0 artiklar" cards on the recipient side.
      test('empty items → false', () {
        final list = _personalList(items: const []);
        expect(coordinator.validateShoppingListForSharing(list), isFalse);
      });

      /// Happy path. The most important assertion — a regression that
      /// returned false here would silently disable every share button.
      test('named list with items → true', () {
        final list = _personalList(name: 'Helg', items: [_item(), _item()]);
        expect(coordinator.validateShoppingListForSharing(list), isTrue);
      });
    });

    // ---------------------------------------------------------------------
    // getShoppingListSummary — 4 branches drive the card chip text
    // ---------------------------------------------------------------------
    group('getShoppingListSummary', () {
      /// Empty list → localized "Tom handlingslista". Pinning the empty
      /// path so a UI tweak doesn't accidentally show "0 av 0".
      test('empty items → localized empty-list label', () {
        final list = _personalList(items: const []);
        final summary = coordinator.getShoppingListSummary(list);
        expect(summary, isNotEmpty);
        expect(summary.toLowerCase(), contains('tom'));
      });

      /// All-done branch — every item bought. The summary mentions the
      /// total count, NOT the unbought count (which would be 0).
      test('all bought → "Alla N artiklar klara"', () {
        final list = _personalList(items: [
          _item(name: 'a', bought: true),
          _item(name: 'b', bought: true),
        ]);
        final summary = coordinator.getShoppingListSummary(list);
        expect(summary, contains('2'));
        expect(summary.toLowerCase(), contains('klara'));
      });

      /// Nothing-bought branch — distinct from mid-progress because it
      /// goes through `shoppingListSummaryToBuy` not `Remaining`.
      test('none bought → "N artiklar att köpa"', () {
        final list = _personalList(items: [
          _item(name: 'a', bought: false),
          _item(name: 'b', bought: false),
          _item(name: 'c', bought: false),
        ]);
        final summary = coordinator.getShoppingListSummary(list);
        expect(summary, contains('3'));
        expect(summary.toLowerCase(), contains('köpa'));
      });

      /// Mid-progress: "R av T artiklar kvar". This is the longest-lived
      /// state in normal use; an off-by-one on `remainingItems` would
      /// render "2 av 3" when the user has 1 left.
      test('mid-progress → "remaining of total"', () {
        final list = _personalList(items: [
          _item(name: 'a', bought: true),
          _item(name: 'b', bought: false),
          _item(name: 'c', bought: false),
        ]);
        final summary = coordinator.getShoppingListSummary(list);
        // remaining = 2, total = 3
        expect(summary, contains('2'));
        expect(summary, contains('3'));
        expect(summary.toLowerCase(), contains('kvar'));
      });
    });

    // ---------------------------------------------------------------------
    // canUserEditShoppingList — permission gate
    // ---------------------------------------------------------------------
    group('canUserEditShoppingList', () {
      /// Owner ALWAYS can edit, even without an explicit memberPermissions
      /// entry. The owner shortcut is the most-relied-on branch — a bug
      /// that required owners to be in memberPermissions would lock them
      /// out of their own lists.
      test('owner can always edit (no memberPermissions entry needed)', () {
        final list = _personalList(ownerId: 'me-uid', items: [_item()]);
        expect(coordinator.canUserEditShoppingList(list, 'me-uid'), isTrue);
      });

      /// Edit permission member can edit.
      test('member with edit permission → true', () {
        final list = _collabList(
          ownerId: 'owner',
          perms: const {'friend': SharedListPermission.edit},
        );
        expect(coordinator.canUserEditShoppingList(list, 'friend'), isTrue);
      });

      /// Admin permission member can edit (admin implies edit).
      test('member with admin permission → true', () {
        final list = _collabList(
          ownerId: 'owner',
          perms: const {'friend': SharedListPermission.admin},
        );
        expect(coordinator.canUserEditShoppingList(list, 'friend'), isTrue);
      });

      /// View-only member CANNOT edit. A flip here would let viewers
      /// silently mutate lists — a permission-bypass class of bug.
      test('member with view-only permission → false', () {
        final list = _collabList(
          ownerId: 'owner',
          perms: const {'friend': SharedListPermission.view},
        );
        expect(coordinator.canUserEditShoppingList(list, 'friend'), isFalse);
      });

      /// Non-member, non-owner → false. Permission-leak guard.
      test('unrelated user → false', () {
        final list = _collabList(
          ownerId: 'owner',
          perms: const {'friend': SharedListPermission.edit},
        );
        expect(coordinator.canUserEditShoppingList(list, 'stranger'), isFalse);
      });
    });

    // ---------------------------------------------------------------------
    // isCollaborativeShoppingList — AND of type+memberPermissions
    // ---------------------------------------------------------------------
    group('isCollaborativeShoppingList', () {
      /// Personal list with members (shouldn't happen but pinning the
      /// AND): returns false because type != collaborative.
      test('personal type → false even if memberPermissions present', () {
        // Personal factory doesn't accept memberPermissions, but we can
        // verify the type check by constructing one.
        final list = _personalList();
        expect(coordinator.isCollaborativeShoppingList(list), isFalse);
      });

      /// Collaborative list with empty memberPermissions → false. The
      /// AND prevents flagging a freshly-created collab list (before
      /// any members joined) as "collaborative".
      ///
      /// Note: UnifiedShoppingList.collaborative factory auto-adds the
      /// owner to memberPermissions as admin, so even an "empty" perms
      /// map ends up with size 1. This test pins that nuance: the
      /// production check is `isNotEmpty`, which an owner-only list
      /// passes. If the future change requires "at least one OTHER
      /// member", this test becomes the canary.
      test('collaborative type with only owner in perms → true (current)', () {
        final list = _collabList(ownerId: 'owner', perms: const {});
        // Factory adds owner as admin → perms has 1 entry → isNotEmpty true.
        expect(coordinator.isCollaborativeShoppingList(list), isTrue);
      });

      /// Happy path: collaborative + has members → true.
      test('collaborative type with members → true', () {
        final list = _collabList(
          ownerId: 'owner',
          perms: const {'friend': SharedListPermission.edit},
        );
        expect(coordinator.isCollaborativeShoppingList(list), isTrue);
      });
    });

    // ---------------------------------------------------------------------
    // createSharedContentModel — propagation contract
    // ---------------------------------------------------------------------
    group('createSharedContentModel', () {
      /// Pins the snapshot→model field mapping: listName from name,
      /// itemCount from items.length, shoppingListId from originalContentId.
      test('maps snapshot fields and originalContentId to shoppingListId', () {
        final snapshot = _personalList(
          name: 'Veckans inköp',
          items: [_item(name: 'a'), _item(name: 'b'), _item(name: 'c')],
        );

        final shared = coordinator.createSharedContentModel(
          originalContentId: 'orig-123',
          sharedByUserId: 'sender',
          sharedByDisplayName: 'Anna',
          sharedToUserIds: ['f1', 'f2'],
          contentSnapshot: snapshot,
        );

        expect(shared.listName, 'Veckans inköp');
        expect(shared.itemCount, 3,
            reason: 'itemCount must reflect items.length, not 0 or hardcoded');
        expect(shared.shoppingListId, 'orig-123',
            reason:
                'originalContentId must propagate so join can resolve back to the live list');
        expect(shared.sharedByUserId, 'sender');
        expect(shared.sharedByDisplayName, 'Anna');
      });

      /// Empty share message: production defaults to '' (not null). Some
      /// downstream UI may depend on never seeing null here.
      test('null shareMessage → empty string in model', () {
        final shared = coordinator.createSharedContentModel(
          originalContentId: 'orig-123',
          sharedByUserId: 'sender',
          sharedByDisplayName: 'Anna',
          sharedToUserIds: const ['f1'],
          contentSnapshot: _personalList(),
        );

        expect(shared.shareMessage, '');
      });

      /// listDescription pass-through (nullable). Some lists have no
      /// description; some carry one — both must round-trip.
      test('listDescription propagates from snapshot', () {
        final snap = UnifiedShoppingList.collaborative(
          name: 'Lista',
          ownerId: 'me-uid',
          ownerDisplayName: 'Anna',
          memberPermissions: const {},
          description: 'Helgens veckomat',
          items: [_item()],
        );

        final shared = coordinator.createSharedContentModel(
          originalContentId: 'orig',
          sharedByUserId: 'sender',
          sharedByDisplayName: 'Anna',
          sharedToUserIds: const ['f1'],
          contentSnapshot: snap,
        );

        expect(shared.listDescription, 'Helgens veckomat');
      });
    });

    // ---------------------------------------------------------------------
    // createImportedContent — direct-collaboration shape
    // ---------------------------------------------------------------------
    group('createImportedContent', () {
      /// Direct collaboration: the imported list is COLLABORATIVE (not
      /// personal) and owned by the original sender, with the joining
      /// user as editor. allowGuestEditing is FALSE.
      test('produces collaborative list owned by sender with joiner as editor',
          () {
        final shared = _sharedList(
          sharedByUserId: 'sender-uid',
          sharedByDisplayName: 'Sender',
        );

        final imported = coordinator.createImportedContent(
          sharedContent: shared,
          newOwnerId: 'me-uid',
        );

        expect(imported.type, ListType.collaborative);
        expect(imported.ownerId, 'sender-uid');
        // Owner auto-promoted to admin by the collaborative factory; the
        // joining user gets `edit`. Both should be present.
        expect(imported.memberPermissions['sender-uid'],
            SharedListPermission.admin);
        expect(imported.memberPermissions['me-uid'], SharedListPermission.edit);
        expect(imported.allowGuestEditing, isFalse,
            reason:
                'Shopping list import locks guest editing — pins the false default');
      });

      /// Issue #015 contract: items start EMPTY because they're stored
      /// in a subcollection now and must be loaded separately. A bug
      /// that populated items inline would create duplicate items on
      /// the live list and the subcollection.
      test('items always start empty (Issue #015 — load from subcollection)',
          () {
        final shared = _sharedList(itemCount: 42);

        final imported = coordinator.createImportedContent(
          sharedContent: shared,
          newOwnerId: 'me-uid',
        );

        expect(imported.items, isEmpty,
            reason:
                'itemCount may be 42 but items list MUST be empty — caller loads from repo');
      });

      /// newTitle override wins; null falls back to sharedContent.listName.
      test('newTitle null → falls back to listName', () {
        final shared = _sharedList(listName: 'Original');
        final imported = coordinator.createImportedContent(
          sharedContent: shared,
          newOwnerId: 'me-uid',
        );
        expect(imported.name, 'Original');
      });

      test('newTitle provided → overrides listName', () {
        final shared = _sharedList(listName: 'Original');
        final imported = coordinator.createImportedContent(
          sharedContent: shared,
          newOwnerId: 'me-uid',
          newTitle: 'Min lyxlista',
        );
        expect(imported.name, 'Min lyxlista');
      });
    });

    // ---------------------------------------------------------------------
    // getOriginalContentFromShared — known limitation pinned
    // ---------------------------------------------------------------------
    group('getOriginalContentFromShared', () {
      /// Returns a UnifiedShoppingList reconstructed from the SharedShoppingList
      /// metadata. Owner gets admin permission. Items are empty (subcollection).
      test('returns collaborative list with owner as admin, empty items', () {
        final shared = _sharedList(
          sharedByUserId: 'sender',
          sharedByDisplayName: 'Sender',
          listName: 'V',
          itemCount: 9,
        );

        final reconstructed = coordinator.getOriginalContentFromShared(shared)
            as UnifiedShoppingList;

        expect(reconstructed.type, ListType.collaborative);
        expect(reconstructed.ownerId, 'sender');
        expect(reconstructed.memberPermissions['sender'],
            SharedListPermission.admin);
        expect(reconstructed.items, isEmpty);
        expect(reconstructed.name, 'V');
      });
    });

    // ---------------------------------------------------------------------
    // getSharedByUserId — pass-through
    // ---------------------------------------------------------------------
    group('getSharedByUserId', () {
      /// Pure pass-through. A wrong-field bug here would route CoW to
      /// the wrong owner.
      test('returns shared.sharedByUserId verbatim', () {
        final shared = _sharedList(sharedByUserId: 'sender-xyz');
        expect(coordinator.getSharedByUserId(shared), 'sender-xyz');
      });
    });

    // ---------------------------------------------------------------------
    // triggerCopyOnWriteForContent — pinned no-op for shopping
    // ---------------------------------------------------------------------
    group('triggerCopyOnWriteForContent', () {
      /// Shopping lists DON'T use copy-on-write — they use direct
      /// collaboration. The method returns the input unchanged. If a
      /// future refactor accidentally wired in real CoW for shopping
      /// (matching the recipe/menu path), this assertion would catch
      /// it because the returned object would carry CoW flags.
      test('returns input unchanged regardless of editingUserId', () {
        final shared = _sharedList(sharedByUserId: 'owner-uid');

        final out = coordinator.triggerCopyOnWriteForContent(
          sharedContent: shared,
          editingUserId: 'other-uid',
          staticCopyId: 'static-x',
        );

        expect(identical(out, shared), isTrue,
            reason: 'shopping lists use direct collaboration — must be no-op');
      });
    });

    // ---------------------------------------------------------------------
    // createStaticCopyForOwner — pinned null
    // ---------------------------------------------------------------------
    group('createStaticCopyForOwner', () {
      /// Shopping lists don't need a static copy for the original owner
      /// because they're directly collaborative. Returning a non-null
      /// id would create orphan documents.
      test('always returns null (no static copy for shopping)', () async {
        final out = await coordinator.createStaticCopyForOwner(
            _personalList(), 'owner-uid');
        expect(out, isNull);
      });
    });

    // ---------------------------------------------------------------------
    // importSharedContent — shopping override routes to join
    // ---------------------------------------------------------------------
    group('importSharedContent (override)', () {
      /// For shopping, "import" IS "join" — the override delegates.
      /// Verify by stubbing the underlying read to return null (so the
      /// join short-circuits to null without touching the live list).
      test('delegates to joinSharedShoppingList', () async {
        when(() => mockRepo.read('shared-xyz')).thenAnswer((_) async => null);

        final out = await coordinator.importSharedContent(
            sharedContentId: 'shared-xyz');

        expect(out, isNull);
        verify(() => mockRepo.read('shared-xyz')).called(1);
      });
    });

    // ---------------------------------------------------------------------
    // getSharedShoppingListsForUser — error swallow contract
    // ---------------------------------------------------------------------
    group('getSharedShoppingListsForUser', () {
      /// Happy path: forwards the response. Pins the parameter passed
      /// (the userId), so a bug that forwarded the wrong user would
      /// silently show the wrong inbox.
      test('forwards userId and returns repo response', () async {
        final lists = [_sharedList(id: 'a'), _sharedList(id: 'b')];
        when(() => mockRepo.getSharedContentForUser(any()))
            .thenAnswer((_) async => lists);

        final out = await coordinator.getSharedShoppingListsForUser('uid-1');

        expect(out, hasLength(2));
        verify(() => mockRepo.getSharedContentForUser('uid-1')).called(1);
      });

      /// Permission-denied / offline → empty list, no rethrow. The
      /// shared-content tab must render empty state on transient errors.
      /// BUT-1094 fix (commit fee1147ae): error is now ALSO surfaced via
      /// setError so the UI can show a banner.
      test('repo throw → empty list + setError (BUT-1094 fix)', () async {
        when(() => mockRepo.getSharedContentForUser(any()))
            .thenThrow(Exception('permission-denied'));

        final out = await coordinator.getSharedShoppingListsForUser('uid-1');

        expect(out, isEmpty);
        expect(lastError, isNotNull,
            reason: 'BUT-1094 fix: setError now populated on swallow');
      });
    });

    // ---------------------------------------------------------------------
    // getJoinedShoppingLists — unauth + error paths
    // ---------------------------------------------------------------------
    group('getJoinedShoppingLists', () {
      /// Unauthenticated → empty list short-circuit, no repo touch.
      /// Prevents a null-user request from hitting Firestore.
      test('unauthenticated → empty list, repo never called', () async {
        currentUserId = null;

        final out = await coordinator.getJoinedShoppingLists();

        expect(out, isEmpty);
        verifyNever(() => mockRepo.getJoinedShoppingListsForUser(any()));
      });

      /// Happy path: forwards uid and returns response.
      test('authenticated → forwards uid to repo', () async {
        final lists = [_sharedList(id: 'j1')];
        when(() => mockRepo.getJoinedShoppingListsForUser(any()))
            .thenAnswer((_) async => lists);

        final out = await coordinator.getJoinedShoppingLists();

        expect(out, hasLength(1));
        verify(() => mockRepo.getJoinedShoppingListsForUser('me-uid'))
            .called(1);
      });

      /// Error path: swallows to empty list AND sets error (CORRECT
      /// behaviour — compare to getSharedShoppingListsForUser which
      /// does NOT set error, the BUT-1094 inconsistency in the same file).
      test('repo throw → empty list AND setError is called', () async {
        when(() => mockRepo.getJoinedShoppingListsForUser(any()))
            .thenThrow(Exception('boom'));

        final out = await coordinator.getJoinedShoppingLists();

        expect(out, isEmpty);
        expect(lastError, isNotNull,
            reason: 'getJoinedShoppingLists DOES set error (contrast '
                'with getSharedShoppingListsForUser which does NOT — '
                'see BUT-1094 family note in header)');
      });
    });

    // ---------------------------------------------------------------------
    // joinSharedShoppingList — CORRECT try-catch contract (anti-regression
    // for BUT-1090)
    // ---------------------------------------------------------------------
    group('joinSharedShoppingList', () {
      /// Unauthenticated → null short-circuit.
      test('unauthenticated → null, repo never touched', () async {
        currentUserId = null;

        final out = await coordinator.joinSharedShoppingList(
            sharedShoppingListId: 'shared-1');

        expect(out, isNull);
        verifyNever(() => mockRepo.read(any()));
      });

      /// Not-found (null read) → null without crash. The downstream
      /// `markAsJoined` and `addMember` must NOT be called.
      test('shared list not found → null, no markAsJoined, no addMember',
          () async {
        when(() => mockRepo.read('does-not-exist'))
            .thenAnswer((_) async => null);

        final out = await coordinator.joinSharedShoppingList(
            sharedShoppingListId: 'does-not-exist');

        expect(out, isNull);
        verifyNever(() => mockRepo.markAsJoined(any(), any()));
      });

      /// **ANTI-REGRESSION FOR BUT-1090**: a repo throw from `read()`
      /// is CAUGHT — returns null and sets the error. The buggy shape
      /// from `SocialMenuCoordinator.joinSharedMenu` (which lets the
      /// throw escape) is NOT present here. If a future refactor
      /// removes the try-catch around the read, this test breaks.
      test('repo throw on read → null AND error set (NOT rethrown)', () async {
        when(() => mockRepo.read('shared-1'))
            .thenThrow(Exception('permission-denied'));

        final out = await coordinator.joinSharedShoppingList(
            sharedShoppingListId: 'shared-1');

        expect(out, isNull,
            reason: 'try-catch correctly swallows — opposite of BUT-1090');
        expect(lastError, isNotNull,
            reason:
                'this path DOES set error (contrast getSharedShoppingListsForUser)');
      });
    });

    // ---------------------------------------------------------------------
    // Status cache — default-false contract
    // ---------------------------------------------------------------------
    group('Status cache defaults', () {
      /// Cache miss MUST default to false for all three statuses. A
      /// flip to true would mark every never-loaded list as already
      /// viewed/imported/dismissed — invisible content for the user.
      test('unknown id → all three statuses default to false', () {
        expect(coordinator.isShoppingListViewed('nope'), isFalse);
        expect(coordinator.isShoppingListImported('nope'), isFalse);
        expect(coordinator.isShoppingListDismissed('nope'), isFalse);
      });
    });

    // ---------------------------------------------------------------------
    // loadStatusForShoppingList — populates cache from repo
    // ---------------------------------------------------------------------
    group('loadStatusForShoppingList', () {
      /// Loads all three flags and caches them; subsequent reads use
      /// the cache. Pins the field-to-flag mapping (hasViewed → viewed,
      /// hasEngaged → imported, hasDismissed → dismissed). A swap here
      /// would silently inflate "imported" counts.
      test('caches all three flags and exposes via is* getters', () async {
        when(() => mockRepo.hasViewed('list-1', 'me-uid'))
            .thenAnswer((_) async => true);
        when(() => mockRepo.hasEngaged('list-1', 'me-uid'))
            .thenAnswer((_) async => false);
        when(() => mockRepo.hasDismissed('list-1', 'me-uid'))
            .thenAnswer((_) async => true);

        await coordinator.loadStatusForShoppingList('list-1', 'me-uid');

        expect(coordinator.isShoppingListViewed('list-1'), isTrue);
        expect(coordinator.isShoppingListImported('list-1'), isFalse);
        expect(coordinator.isShoppingListDismissed('list-1'), isTrue);
      });

      /// Repo throw → caches NOT populated; subsequent reads stay false.
      /// Pinning the swallow so a regression doesn't crash the inbox.
      /// BUT-1094 family: no setError call on this path either.
      test('repo throw → cache stays empty, no rethrow, no error set',
          () async {
        when(() => mockRepo.hasViewed(any(), any()))
            .thenThrow(Exception('boom'));

        await coordinator.loadStatusForShoppingList('list-1', 'me-uid');

        expect(coordinator.isShoppingListViewed('list-1'), isFalse);
        expect(lastError, isNull,
            reason: 'BUT-1094 family: status load swallows without setError');
      });
    });

    // ---------------------------------------------------------------------
    // loadStatusForAllShoppingLists — iterates over list, caches each
    // ---------------------------------------------------------------------
    group('loadStatusForAllShoppingLists', () {
      /// Iterates and caches each list. A bug that broke after the first
      /// list would leave the rest uncached, silently making them appear
      /// "unviewed" forever in the UI.
      test('caches status for every list in the input', () async {
        when(() => mockRepo.hasViewed(any(), any()))
            .thenAnswer((_) async => true);
        when(() => mockRepo.hasEngaged(any(), any()))
            .thenAnswer((_) async => false);
        when(() => mockRepo.hasDismissed(any(), any()))
            .thenAnswer((_) async => false);

        final lists = [
          _sharedList(id: 'l1'),
          _sharedList(id: 'l2'),
          _sharedList(id: 'l3'),
        ];

        await coordinator.loadStatusForAllShoppingLists(lists, 'me-uid');

        expect(coordinator.isShoppingListViewed('l1'), isTrue);
        expect(coordinator.isShoppingListViewed('l2'), isTrue);
        expect(coordinator.isShoppingListViewed('l3'), isTrue);
        verify(() => mockRepo.hasViewed(any(), 'me-uid')).called(3);
      });

      /// Empty input → no repo calls. Defensive — a bug that called
      /// the repo with an empty userId or fired a redundant request
      /// would show as wasted RPCs in Firestore billing.
      test('empty input → no repo calls', () async {
        await coordinator.loadStatusForAllShoppingLists(const [], 'me-uid');

        verifyNever(() => mockRepo.hasViewed(any(), any()));
      });
    });

    // ---------------------------------------------------------------------
    // dismiss / restore / markAsViewed — base-class delegation paths
    // ---------------------------------------------------------------------
    group('Base coordinator delegations', () {
      /// dismiss → markAsDismissed + notify + true on success.
      test('dismissSharedShoppingList → repo.markAsDismissed, notifies, true',
          () async {
        when(() => mockRepo.markAsDismissed('s1', 'me-uid'))
            .thenAnswer((_) async {});

        final out = await coordinator.dismissSharedShoppingList('s1');

        expect(out, isTrue);
        expect(notifyCount, greaterThanOrEqualTo(1));
        verify(() => mockRepo.markAsDismissed('s1', 'me-uid')).called(1);
      });

      /// dismiss unauthenticated → false short-circuit, no repo call.
      test('dismissSharedShoppingList unauthenticated → false', () async {
        currentUserId = null;
        final out = await coordinator.dismissSharedShoppingList('s1');
        expect(out, isFalse);
        verifyNever(() => mockRepo.markAsDismissed(any(), any()));
      });

      /// markAsViewed delegates to base → repo.markAsViewed.
      test('markShoppingListAsViewed → repo.markAsViewed, true', () async {
        when(() => mockRepo.markAsViewed('s1', 'me-uid'))
            .thenAnswer((_) async {});

        final out = await coordinator.markShoppingListAsViewed('s1');

        expect(out, isTrue);
        verify(() => mockRepo.markAsViewed('s1', 'me-uid')).called(1);
      });

      /// restore → repo.undismiss + notify + true.
      test('restoreSharedShoppingList → repo.undismiss, true', () async {
        when(() => mockRepo.undismiss('s1', 'me-uid')).thenAnswer((_) async {});

        final out = await coordinator.restoreSharedShoppingList('s1');

        expect(out, isTrue);
        verify(() => mockRepo.undismiss('s1', 'me-uid')).called(1);
      });

      /// getUnreadCount delegates to repo. Bug-family note: failure on
      /// this path returns 0 silently (BUT-1094 family, base class).
      test('getUnreadShoppingListCount → forwards to repo', () async {
        when(() => mockRepo.getUnreadCountForUser('me-uid'))
            .thenAnswer((_) async => 7);

        final out = await coordinator.getUnreadShoppingListCount();

        expect(out, 7);
      });

      /// getUnreadCount on throw → 0 AND setError populated (BUT-1094 fix
      /// at base_social_coordinator.dart:425, commit fee1147ae).
      test('getUnreadShoppingListCount on throw → 0 + setError (BUT-1094 fix)',
          () async {
        when(() => mockRepo.getUnreadCountForUser(any()))
            .thenThrow(Exception('boom'));

        final out = await coordinator.getUnreadShoppingListCount();

        expect(out, 0);
        expect(lastError, isNotNull,
            reason: 'BUT-1094 fix: base getUnreadCount now calls setError');
      });
    });
  });
}
