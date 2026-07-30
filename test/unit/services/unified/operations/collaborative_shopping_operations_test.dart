// test/unit/services/unified/operations/collaborative_shopping_operations_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:butlery/services/unified/operations/collaborative_shopping_operations.dart';
import 'package:butlery/services/unified/operations/collaborative_shopping/list_lifecycle_operations.dart';
import 'package:butlery/services/unified/operations/collaborative_shopping/list_member_operations.dart';
import 'package:butlery/services/unified/operations/collaborative_shopping/list_item_operations.dart';
import 'package:butlery/services/unified/operations/collaborative_shopping/list_activity_operations.dart';
import 'package:butlery/models/unified/unified_shopping_list.dart';
import 'package:butlery/models/unified/unified_shopping_item.dart';
import 'package:butlery/models/permissions/resource_permission.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart' as production;
import 'package:get_it/get_it.dart';
import '../../../../test_support/base_unit_test.dart';
import '../../../../infrastructure/di/test_service_locator.dart';
import '../../../../infrastructure/mocks/production_mocks.dart';

/// BUT-1665: mocktail fallback for the transactional mutator argument.
UnifiedShoppingList _identityMutator(UnifiedShoppingList live) => live;

void main() {
  group('CollaborativeShoppingOperations', () {
    late MockUnifiedShoppingService mockParentService;
    late FakePermissionService mockPermissionService;
    late CollaborativeShoppingOperations operations;
    late UnifiedShoppingList testCollaborativeList;
    late UnifiedShoppingList testSharedList;
    late UnifiedShoppingList testPersonalList;
    late UnifiedShoppingItem testItem1;
    late UnifiedShoppingItem testItem2;

    /// BUT-1723: what the server-confirmed read-back reports for a freshly
    /// created copy. Null models "could not be confirmed" (offline).
    late int? confirmedItemCount;

    /// Counts the clear-on-entry hook. BUT-1726 review: every member operation
    /// has early `return false` branches that never reach the service, and the
    /// dialog reads `consumeMutationError()` on exactly those branches — so an
    /// unrelated earlier failure's sentence was shown as the cause. The clear
    /// has to happen HERE, at the entry point, not inside the service.
    late int beginMutationCalls;

    setUpAll(() async {
      // Register fallback values for mocktail
      registerFallbackValue(SharedListPermission.view);
      registerFallbackValue(<String>[]);
      registerFallbackValue(<String, String>{});
      registerFallbackValue(<UnifiedShoppingItem>[]);
      // BUT-1665: item ops now hand a mutator to the transactional seam.
      const UnifiedShoppingList Function(UnifiedShoppingList) identityMutator =
          _identityMutator;
      registerFallbackValue(identityMutator);
      registerFallbackValue(
        UnifiedShoppingList(
          id: 'test',
          name: 'Test',
          ownerId: 'test',
          ownerDisplayName: 'Test',
          items: [],
          type: ListType.collaborative,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
    });

    setUp(() async {
      await BaseUnitTest.setupUnit();
      await TestServiceLocator.initialize();

      // Bridge production ServiceLocator to GetIt so ServiceLocator.get<T>() works
      production.ServiceLocator.initialize(DIContainer());

      // Create mocks
      mockParentService = MockUnifiedShoppingService();
      mockPermissionService = FakePermissionService();

      // Register permission service
      if (GetIt.instance.isRegistered<PermissionService>()) {
        GetIt.instance.unregister<PermissionService>();
      }
      GetIt.instance.registerSingleton<PermissionService>(
        mockPermissionService,
      );

      // Create test items
      testItem1 = UnifiedShoppingItem(
        id: 'item_1',
        name: 'Mjölk',
        amount: 2.0,
        unit: 'l',
        category: 'Mejeri',
        bought: false,
        addedByUserId: 'user_123',
        addedByDisplayName: 'Test User',
        addedAt: DateTime.now(),
      );

      testItem2 = UnifiedShoppingItem(
        id: 'item_2',
        name: 'Bröd',
        amount: 1.0,
        unit: 'st',
        category: 'Bageri',
        bought: true,
        addedByUserId: 'user_456',
        addedByDisplayName: 'Other User',
        addedAt: DateTime.now(),
      );

      // Create test lists
      testCollaborativeList = UnifiedShoppingList(
        id: 'collab_list_1',
        name: 'Familjehandling',
        description: 'Veckans mat',
        ownerId: 'user_123',
        ownerDisplayName: 'Test User',
        memberPermissions: {
          'user_123': SharedListPermission.admin,
          'user_456': SharedListPermission.edit,
          'user_789': SharedListPermission.view,
        },
        items: [testItem1],
        type: ListType.collaborative,
        allowGuestEditing: true,
        autoRemoveCompleted: false,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        lastActivityByUserId: 'user_123',
        lastActivityByDisplayName: 'Test User',
      );

      testSharedList = UnifiedShoppingList(
        id: 'shared_list_2',
        name: 'Shared List',
        description: 'Shared shopping',
        ownerId: 'user_456',
        ownerDisplayName: 'Other User',
        memberPermissions: {
          'user_456': SharedListPermission.admin,
          'user_123': SharedListPermission.view,
        },
        items: [testItem2],
        type: ListType.collaborative,
        allowGuestEditing: false,
        autoRemoveCompleted: false,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      testPersonalList = UnifiedShoppingList(
        id: 'personal_list_1',
        name: 'Min lista',
        ownerId: 'user_123',
        ownerDisplayName: 'Test User',
        items: [],
        type: ListType.personal,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Set up mock parent service state
      mockParentService.setShoppingState(
        collaborativeLists: [testCollaborativeList, testSharedList],
        personalLists: [testPersonalList],
        currentUserId: 'user_123',
        currentUserDisplayName: 'Test User',
      );

      // Set up permission service using configuration
      // The mock now has concrete implementations that use this configuration
      mockPermissionService.setPermissionState(
        isAuthenticated: true,
        currentUserId: 'user_123',
        defaultHasPermission:
            false, // Default to false for more controlled testing
        permissions: {
          'collab_list_1': {
            ResourcePermission.owner: true,
            ResourcePermission.admin: true,
            ResourcePermission.write: true,
            ResourcePermission.editor: true,
            ResourcePermission.read: true,
            ResourcePermission.viewer: true,
          },
          'shared_list_2': {
            ResourcePermission.owner: false,
            ResourcePermission.admin: false,
            ResourcePermission.write: false,
            ResourcePermission.editor: false,
            ResourcePermission.read: true,
            ResourcePermission.viewer: true,
          },
          'personal_list_1': {
            ResourcePermission.owner: true,
            ResourcePermission.admin: true,
            ResourcePermission.write: true,
            ResourcePermission.editor: true,
            ResourcePermission.read: true,
            ResourcePermission.viewer: true,
          },
        },
      );

      // No need to stub these methods anymore - they have concrete implementations
      // that use the configuration above

      // Default stub behaviors for parent service methods
      when(
        () => mockParentService.createCollaborativeList(
          name: any(named: 'name'),
          description: any(named: 'description'),
          memberIds: any(named: 'memberIds'),
          memberDisplayNames: any(named: 'memberDisplayNames'),
          items: any(named: 'items'),
          categoryIds: any(named: 'categoryIds'),
          allowGuestEditing: any(named: 'allowGuestEditing'),
          autoRemoveCompleted: any(named: 'autoRemoveCompleted'),
        ),
      ).thenAnswer((_) async => 'new_list_id');

      when(
        () => mockParentService.createPersonalList(
          any(),
          items: any(named: 'items'),
        ),
      ).thenAnswer((_) async => 'new_personal_list_id');

      when(
        () => mockParentService.updateList(any()),
      ).thenAnswer((_) async => true);
      // BUT-1726: membership no longer rides on updateList. It has its own
      // seam that also carries the BASE the change was computed from, so the
      // repository can refuse a change computed against a list the server has
      // already moved past instead of silently writing nothing.
      when(
        () => mockParentService.updateSharedListMembership(any(), any()),
      ).thenAnswer((_) async => true);
      when(
        () => mockParentService.deleteList(any()),
      ).thenAnswer((_) async => true);
      // BUT-1665: the transactional seam applies the mutator to whatever the
      // server currently holds. Default stub applies it to the cached list.
      when(() => mockParentService.mutateSharedList(any(), any())).thenAnswer((
        invocation,
      ) async {
        final listId = invocation.positionalArguments[0] as String;
        final mutate =
            invocation.positionalArguments[1]
                as UnifiedShoppingList Function(UnifiedShoppingList);
        final live = mockParentService.collaborativeLists.firstWhere(
          (l) => l.id == listId,
        );
        mutate(live);
        return true;
      });

      // Build operations with typed deps (no _parent back-reference)
      // BUT-1723: a conversion deletes the source only once the copy reads
      // back from the SERVER. Default to a count no copy can fall short of, so
      // the pre-existing happy-path tests still exercise the delete; the tests
      // that care set it explicitly.
      confirmedItemCount = 99;
      beginMutationCalls = 0;
      final lifecycleOps = ListLifecycleOperations(
        getCollaborativeLists: () => mockParentService.collaborativeLists,
        getPersonalLists: () => mockParentService.personalLists,
        createCollaborativeList: mockParentService.createCollaborativeList,
        deleteList: mockParentService.deleteList,
        createPersonalList: mockParentService.createPersonalList,
        confirmPersistedItemCount: (_) async => confirmedItemCount,
      );

      final memberOps = ListMemberOperations(
        getCurrentUserId: () => mockParentService.currentUserId,
        updateMembership: mockParentService.updateSharedListMembership,
        beginMutation: () => beginMutationCalls++,
        lifecycleOps: lifecycleOps,
      );

      final itemOps = ListItemOperations(
        getCurrentUserId: () => mockParentService.currentUserId,
        getCurrentUserDisplayName: () =>
            mockParentService.currentUserDisplayName,
        mutateSharedList: mockParentService.mutateSharedList,
        lifecycleOps: lifecycleOps,
      );

      final activityOps = ListActivityOperations(lifecycleOps);

      // Create operations under test
      operations = CollaborativeShoppingOperations(
        lifecycleOps: lifecycleOps,
        memberOps: memberOps,
        itemOps: itemOps,
        activityOps: activityOps,
      );
    });

    tearDown(() async {
      if (GetIt.instance.isRegistered<PermissionService>()) {
        GetIt.instance.unregister<PermissionService>();
      }
      await TestServiceLocator.reset();
      BaseUnitTest.resetMocks();
    });

    tearDownAll(() async {
      await BaseUnitTest.teardownUnit();
    });

    group('List Management', () {
      test('should create collaborative list', () async {
        // Act
        final listId = await operations.createList(
          name: 'Ny lista',
          description: 'Test beskrivning',
          memberIds: ['user_456', 'user_789'],
          memberDisplayNames: {
            'user_456': 'Anna',
            'user_789': 'Erik',
          },
          allowGuestEditing: true,
        );

        // Assert
        expect(listId, equals('new_list_id'));
        verify(
          () => mockParentService.createCollaborativeList(
            name: 'Ny lista',
            description: 'Test beskrivning',
            memberIds: ['user_456', 'user_789'],
            memberDisplayNames: {
              'user_456': 'Anna',
              'user_789': 'Erik',
            },
            items: null,
            categoryIds: null,
            allowGuestEditing: true,
            autoRemoveCompleted: false,
          ),
        ).called(1);
      });

      test('should get all collaborative lists', () {
        // Act
        final lists = operations.getAllLists();

        // Assert
        expect(lists, hasLength(2));
        expect(lists[0].name, equals('Familjehandling'));
        expect(lists[1].name, equals('Shared List'));
      });

      test('should get list by ID', () {
        // Act
        final list = operations.getListById('collab_list_1');

        // Assert
        expect(list, isNotNull);
        expect(list!.name, equals('Familjehandling'));
      });

      test('should return null for non-existent list', () {
        // Act
        final list = operations.getListById('non_existent');

        // Assert
        expect(list, isNull);
      });

      test('should get owned lists', () {
        // Act
        final lists = operations.getOwnedLists();

        // Assert
        expect(lists, hasLength(1));
        expect(lists[0].id, equals('collab_list_1'));
      });

      test('should get lists shared with current user', () {
        // Act
        final lists = operations.getSharedWithMe();

        // Assert
        expect(lists, hasLength(1));
        expect(lists[0].id, equals('shared_list_2'));
      });

      test('should convert personal list to collaborative', () async {
        // Act
        final collaborativeId = await operations.convertPersonalToCollaborative(
          personalListId: 'personal_list_1',
          memberIds: ['user_456'],
          memberDisplayNames: {'user_456': 'Anna'},
          description: 'Now collaborative',
        );

        // Assert
        expect(collaborativeId.newListId, equals('new_list_id'));
        expect(collaborativeId.originalKept, isFalse);
        verify(
          () => mockParentService.createCollaborativeList(
            name: 'Min lista',
            description: 'Now collaborative',
            memberIds: ['user_456'],
            memberDisplayNames: {'user_456': 'Anna'},
            items: [],
            categoryIds: null,
            allowGuestEditing: true,
            autoRemoveCompleted: false,
          ),
        ).called(1);
        verify(() => mockParentService.deleteList('personal_list_1')).called(1);
      });

      test('should convert collaborative list to personal', () async {
        // Act
        final personalId = await operations.convertCollaborativeToPersonal(
          'collab_list_1',
        );

        // Assert
        expect(personalId.newListId, equals('new_personal_list_id'));
        expect(personalId.originalKept, isFalse);
        verify(
          () => mockParentService.createPersonalList(
            'Familjehandling',
            items: [testItem1],
          ),
        ).called(1);
        verify(() => mockParentService.deleteList('collab_list_1')).called(1);
      });

      // BUT-1723: the delete is irreversible and the create call returning an
      // id proves nothing — Firestore answers from the local cache while
      // offline, and the personal copy used to persist zero items even when it
      // succeeded. Unconfirmed must mean "keep both lists".
      test('keeps the shared list when the copy cannot be confirmed', () async {
        confirmedItemCount = null;

        final personalId = await operations.convertCollaborativeToPersonal(
          'collab_list_1',
        );

        expect(personalId.newListId, equals('new_personal_list_id'));
        // The caller-visible signal: the copy exists, the ORIGINAL is still
        // there. Without this the UI reports a clean "converted" while every
        // collaborator still has access.
        expect(personalId.originalKept, isTrue);
        verifyNever(() => mockParentService.deleteList('collab_list_1'));
      });

      test('keeps the shared list when the copy landed short', () async {
        // The source has one item; a copy the server says is empty is exactly
        // the data-loss shape this gate exists to catch.
        confirmedItemCount = 0;

        final personalId = await operations.convertCollaborativeToPersonal(
          'collab_list_1',
        );

        expect(personalId.originalKept, isTrue);
        verifyNever(() => mockParentService.deleteList('collab_list_1'));
      });

      // The gate's exact flip point. Every other fixture here is 0, null or a
      // generous 99 against a ONE-item source, so none of them can tell
      // `persisted >= expected` from `persisted > expected` — and tightening it
      // by one character would strand every correctly-copied list as a
      // permanent duplicate the user has to clean up by hand.
      test('deletes the source when the copy matches EXACTLY', () async {
        confirmedItemCount = 1; // collab_list_1 holds exactly one item

        final personalId = await operations.convertCollaborativeToPersonal(
          'collab_list_1',
        );

        expect(personalId.newListId, equals('new_personal_list_id'));
        expect(personalId.originalKept, isFalse);
        verify(() => mockParentService.deleteList('collab_list_1')).called(1);
      });

      // The personal copy lands in `users/{me}/unified_shopping_lists` — a tree
      // no OTHER user's account-deletion cascade can query. A collaborator's
      // uid or display name copied in there would survive their own erasure
      // indefinitely, so the conversion keeps what happened and drops who did
      // it. The owner's own attribution is their own data and stays.
      test('strips other members identities from the personal copy', () async {
        final foreignItem = UnifiedShoppingItem(
          id: 'item_foreign',
          name: 'Bröd',
          amount: 1.0,
          unit: 'st',
          category: 'Bageri',
          bought: true,
          addedByUserId: 'user_456',
          addedByDisplayName: 'Anna Andersson',
          addedAt: DateTime(2026, 7, 1),
          purchasedByUserId: 'user_456',
          purchasedByDisplayName: 'Anna Andersson',
          purchasedAt: DateTime(2026, 7, 2),
          lastModifiedByUserId: 'user_456',
          lastModifiedByDisplayName: 'Anna Andersson',
          lastModifiedAt: DateTime(2026, 7, 2),
          assignedToUserId: 'user_789',
          assignedToDisplayName: 'Erik Eriksson',
          assignedAt: DateTime(2026, 7, 3),
        );
        mockParentService.setShoppingState(
          collaborativeLists: [
            testCollaborativeList.copyWith(items: [testItem1, foreignItem]),
            testSharedList,
          ],
          personalLists: [testPersonalList],
          currentUserId: 'user_123',
          currentUserDisplayName: 'Test User',
        );

        await operations.convertCollaborativeToPersonal('collab_list_1');

        final copied =
            verify(
                  () => mockParentService.createPersonalList(
                    any(),
                    items: captureAny(named: 'items'),
                  ),
                ).captured.single
                as List<UnifiedShoppingItem>;

        final theirs = copied.firstWhere((i) => i.id == 'item_foreign');
        expect(theirs.addedByUserId, isNull);
        expect(theirs.addedByDisplayName, isNull);
        expect(theirs.purchasedByUserId, isNull);
        expect(theirs.purchasedByDisplayName, isNull);
        expect(theirs.lastModifiedByUserId, isNull);
        expect(theirs.lastModifiedByDisplayName, isNull);
        expect(theirs.assignedToUserId, isNull);
        expect(theirs.assignedToDisplayName, isNull);
        expect(
          theirs.isCollaborative,
          isFalse,
          reason: 'a row in a personal list must not read as collaborative',
        );
        // The purchase is a fact about the list, not about a person.
        expect(theirs.name, equals('Bröd'));
        expect(theirs.bought, isTrue);
        expect(theirs.purchasedAt, equals(DateTime(2026, 7, 2)));

        final mine = copied.firstWhere((i) => i.id == 'item_1');
        expect(mine.addedByUserId, equals('user_123'));
        expect(mine.addedByDisplayName, equals('Test User'));
      });

      test(
        'keeps the personal list when the copy cannot be confirmed',
        () async {
          confirmedItemCount = null;

          final collaborativeId = await operations
              .convertPersonalToCollaborative(
                personalListId: 'personal_list_1',
                memberIds: ['user_456'],
                memberDisplayNames: {'user_456': 'Anna'},
              );

          expect(collaborativeId.newListId, equals('new_list_id'));
          expect(collaborativeId.originalKept, isTrue);
          verifyNever(() => mockParentService.deleteList('personal_list_1'));
        },
      );
    });

    group('Member Management', () {
      /// BUT-1726 review: the dialog reads `consumeMutationError()` after every
      /// member operation, but the clear used to live inside the service —
      /// BELOW the early `return false` branches here, which never reach it.
      /// A parked sentence from an unrelated earlier failure ("du saknar
      /// behörighet att redigera denna delade inköpslista", from a failed row
      /// edit) was then shown as the reason a member could not be added. The
      /// early-return path is precisely the one that must clear, so pin it
      /// there rather than on the happy path.
      test(
        'an early refusal still clears any parked failure reason',
        () async {
          // "already a member" — returns false without touching the service.
          final result = await operations.addMember(
            listId: 'collab_list_1',
            userId: 'user_456',
            userDisplayName: 'Existing User',
            permission: SharedListPermission.edit,
          );

          expect(result, isFalse);
          verifyNever(
            () => mockParentService.updateSharedListMembership(any(), any()),
          );
          expect(
            beginMutationCalls,
            1,
            reason:
                'the clear must run on the branch that never reaches the '
                'service, or the dialog reports a stale, unrelated cause',
          );
        },
      );

      test('should add member to list', () async {
        // Act
        final result = await operations.addMember(
          listId: 'collab_list_1',
          userId: 'user_999',
          userDisplayName: 'New User',
          permission: SharedListPermission.edit,
        );

        // Assert
        expect(result, isTrue);
        verify(
          () => mockParentService.updateSharedListMembership(any(), any()),
        ).called(1);
      });

      test('should not add existing member', () async {
        // Act
        final result = await operations.addMember(
          listId: 'collab_list_1',
          userId: 'user_456',
          userDisplayName: 'Existing User',
          permission: SharedListPermission.edit,
        );

        // Assert
        expect(result, isFalse);
        verifyNever(
          () => mockParentService.updateSharedListMembership(any(), any()),
        );
      });

      test('should not add member without permission', () async {
        // Act
        final result = await operations.addMember(
          listId: 'shared_list_2',
          userId: 'user_999',
          userDisplayName: 'New User',
          permission: SharedListPermission.edit,
        );

        // Assert
        expect(result, isFalse);
        verifyNever(
          () => mockParentService.updateSharedListMembership(any(), any()),
        );
      });

      test('should remove member from list', () async {
        // Act
        final result = await operations.removeMember(
          listId: 'collab_list_1',
          userId: 'user_456',
        );

        // Assert
        expect(result, isTrue);
        verify(
          () => mockParentService.updateSharedListMembership(any(), any()),
        ).called(1);
      });

      test('should update member permission', () async {
        // Act
        final result = await operations.updateMemberPermission(
          listId: 'collab_list_1',
          userId: 'user_456',
          permission: SharedListPermission.admin,
        );

        // Assert
        expect(result, isTrue);
        verify(
          () => mockParentService.updateSharedListMembership(any(), any()),
        ).called(1);
      });

      // BUT-1726 regression. The access-control guard shipped as an OPT-IN
      // argument on the whole-list update, and nothing opted in: every add,
      // remove and permission change wrote only `updatedAt` while these
      // operations returned true and the dialog reported success. A removed
      // member kept read+edit rights on the server.
      //
      // These tests are at the PRODUCTION call shape — no test-only argument —
      // and assert on the payload the seam is handed, not merely that it was
      // called, so widening the strip again cannot leave them green.
      group('BUT-1726 the membership write states its intent', () {
        late List<List<UnifiedShoppingList>> membershipCalls;

        setUp(() {
          membershipCalls = [];
          when(
            () => mockParentService.updateSharedListMembership(any(), any()),
          ).thenAnswer((invocation) async {
            membershipCalls.add([
              invocation.positionalArguments[0] as UnifiedShoppingList,
              invocation.positionalArguments[1] as UnifiedShoppingList,
            ]);
            return true;
          });
        });

        test('removing a member actually drops the key it is asked to '
            'drop', () async {
          await operations.removeMember(
            listId: 'collab_list_1',
            userId: 'user_456',
          );

          final [updated, base] = membershipCalls.single;
          expect(
            updated.memberPermissions.keys,
            isNot(contains('user_456')),
            reason: 'the entity handed down must express the removal',
          );
          expect(
            base.memberPermissions.keys,
            contains('user_456'),
            reason:
                'the base is the copy the change was computed FROM, so the '
                'repository can tell staleness from intent',
          );
          expect(base.id, updated.id);
        });

        test('adding a member carries the new key and the pre-change '
            'base', () async {
          await operations.addMember(
            listId: 'collab_list_1',
            userId: 'user_999',
            userDisplayName: 'New User',
            permission: SharedListPermission.view,
          );

          final [updated, base] = membershipCalls.single;
          expect(
            updated.memberPermissions['user_999'],
            SharedListPermission.view,
          );
          expect(base.memberPermissions.keys, isNot(contains('user_999')));
        });

        test('a permission change carries the new value', () async {
          await operations.updateMemberPermission(
            listId: 'collab_list_1',
            userId: 'user_456',
            permission: SharedListPermission.admin,
          );

          final [updated, base] = membershipCalls.single;
          expect(
            updated.memberPermissions['user_456'],
            SharedListPermission.admin,
          );
          expect(
            base.memberPermissions['user_456'],
            SharedListPermission.edit,
          );
        });

        test('a refused write is reported as failure, not success', () async {
          // The write's own verdict has to reach the dialog. Returning true
          // over a refused write is what let an owner believe a member had
          // been removed while the server still had them.
          when(
            () => mockParentService.updateSharedListMembership(any(), any()),
          ).thenAnswer((_) async => false);

          expect(
            await operations.removeMember(
              listId: 'collab_list_1',
              userId: 'user_456',
            ),
            isFalse,
          );
          expect(
            await operations.addMember(
              listId: 'collab_list_1',
              userId: 'user_999',
              userDisplayName: 'New User',
            ),
            isFalse,
          );
          expect(
            await operations.updateMemberPermission(
              listId: 'collab_list_1',
              userId: 'user_456',
              permission: SharedListPermission.admin,
            ),
            isFalse,
          );
        });

        test('membership never goes through the content-edit path', () async {
          // updateList declares no access-control base, so anything it carries
          // in memberPermissions is dropped before the write. A membership
          // operation routed there is a silent no-op by construction.
          await operations.removeMember(
            listId: 'collab_list_1',
            userId: 'user_456',
          );
          verifyNever(() => mockParentService.updateList(any()));
        });
      });

      test('should get list members', () {
        // Act
        final members = operations.getListMembers('collab_list_1');

        // Assert
        expect(members, hasLength(3));
        expect(members['user_123'], equals(SharedListPermission.admin));
        expect(members['user_456'], equals(SharedListPermission.edit));
        expect(members['user_789'], equals(SharedListPermission.view));
      });

      test('should allow non-owner to leave list', () async {
        // Arrange
        mockParentService.setShoppingState(
          collaborativeLists: [testCollaborativeList, testSharedList],
          personalLists: [testPersonalList],
          currentUserId: 'user_456',
          currentUserDisplayName: 'Other User',
        );
        mockPermissionService.setPermissionState(
          isAuthenticated: true,
          currentUserId: 'user_456',
          permissions: {
            'collab_list_1': {
              ResourcePermission.owner: false, // user_456 is not owner
              ResourcePermission.admin: false, // and not admin
              ResourcePermission.write: true, // but can edit
              ResourcePermission.editor: true,
              ResourcePermission.read: true,
              ResourcePermission.viewer: true,
            },
          },
        );

        // Act
        final result = await operations.leaveList('collab_list_1');

        // Assert
        // FIXED: Users can now leave collaborative lists regardless of permission level
        // (as long as they're not the owner)
        expect(result, isTrue);
        verify(
          () => mockParentService.updateSharedListMembership(any(), any()),
        ).called(1);
      });

      test('should not allow owner to leave list', () async {
        // Act
        final result = await operations.leaveList('collab_list_1');

        // Assert
        expect(result, isFalse);
        verifyNever(
          () => mockParentService.updateSharedListMembership(any(), any()),
        );
      });
    });

    group('Item Management', () {
      test('should add item to collaborative list', () async {
        // Arrange
        final originalList = testCollaborativeList;
        UnifiedShoppingList? mutated;
        when(() => mockParentService.mutateSharedList(any(), any())).thenAnswer(
          (invocation) async {
            final mutate =
                invocation.positionalArguments[1]
                    as UnifiedShoppingList Function(UnifiedShoppingList);
            mutated = mutate(originalList);
            return true;
          },
        );

        // Act
        final result = await operations.addItem(
          listId: 'collab_list_1',
          name: 'Ost',
          amount: 500,
          unit: 'g',
          category: 'Mejeri',
          note: 'Gärna lagrad',
          estimatedPrice: 89.90,
        );

        // Assert
        expect(result, isTrue);
        expect(
          mutated!.items.length,
          greaterThan(originalList.items.length),
        );
        verify(
          () => mockParentService.mutateSharedList(any(), any()),
        ).called(1);
      });

      test('should not add item without edit permission', () async {
        // Act
        final result = await operations.addItem(
          listId: 'shared_list_2',
          name: 'Ost',
          amount: 500,
          unit: 'g',
          category: 'Mejeri',
        );

        // Assert
        expect(result, isFalse);
        verifyNever(() => mockParentService.mutateSharedList(any(), any()));
      });

      test('should toggle item bought status', () async {
        // Act
        final result = await operations.toggleItemBought(
          listId: 'collab_list_1',
          itemId: 'item_1',
        );

        // Assert
        expect(result, isTrue);
        verify(
          () => mockParentService.mutateSharedList(any(), any()),
        ).called(1);
      });

      test('should remove item from list', () async {
        // Act
        final result = await operations.removeItem(
          listId: 'collab_list_1',
          itemId: 'item_1',
        );

        // Assert
        expect(result, isTrue);
        verify(
          () => mockParentService.mutateSharedList(any(), any()),
        ).called(1);
      });

      // BUT-1665: the regression this fix exists for — a household member's
      // tick that landed after this client's cache was filled must survive.
      test(
        'toggling one item applies to the LIVE list, keeping a concurrent '
        'tick on another item',
        () async {
          // Arrange: the server copy already has item_2 ticked by someone else.
          final serverList = testCollaborativeList.copyWith(
            items: [
              testItem1,
              testItem2.copyWith(bought: true),
            ],
          );
          UnifiedShoppingList? merged;
          when(
            () => mockParentService.mutateSharedList(any(), any()),
          ).thenAnswer((invocation) async {
            final mutate =
                invocation.positionalArguments[1]
                    as UnifiedShoppingList Function(UnifiedShoppingList);
            merged = mutate(serverList);
            return true;
          });

          // Act: this client ticks item_1 from its own (stale) view.
          final result = await operations.toggleItemBought(
            listId: 'collab_list_1',
            itemId: 'item_1',
          );

          // Assert: both ticks are present after the merge.
          expect(result, isTrue);
          expect(
            merged!.items.firstWhere((i) => i.id == 'item_1').bought,
            isTrue,
          );
          expect(
            merged!.items.firstWhere((i) => i.id == 'item_2').bought,
            isTrue,
            reason: 'the other member\'s tick must not be overwritten',
          );
        },
      );

      test('toggling an item another member deleted is a no-op, not an '
          'error', () async {
        // Arrange: the item is gone from the live list.
        final serverList = testCollaborativeList.copyWith(items: [testItem2]);
        UnifiedShoppingList? merged;
        when(() => mockParentService.mutateSharedList(any(), any())).thenAnswer(
          (invocation) async {
            final mutate =
                invocation.positionalArguments[1]
                    as UnifiedShoppingList Function(UnifiedShoppingList);
            merged = mutate(serverList);
            return true;
          },
        );

        // Act
        final result = await operations.toggleItemBought(
          listId: 'collab_list_1',
          itemId: 'item_1',
        );

        // Assert
        expect(result, isTrue);
        expect(merged!.items.map((i) => i.id), ['item_2']);
      });
    });

    group('Activity and Statistics', () {
      test('should get recent activity', () {
        // Act
        final activity = operations.getRecentActivity('collab_list_1');

        // Assert
        expect(activity, isNotEmpty);
        expect(activity[0]['type'], equals('list_updated'));
        expect(activity[0]['userId'], equals('user_123'));
        expect(activity[0]['userName'], equals('Test User'));
      });

      test('should get list statistics', () {
        // Act
        final stats = operations.getListStats('collab_list_1');

        // Assert
        expect(stats['listName'], equals('Familjehandling'));
        expect(stats['totalItems'], equals(1));
        expect(stats['boughtItems'], equals(0));
        expect(stats['remainingItems'], equals(1));
        expect(stats['memberCount'], equals(3));
        expect(stats['allowGuestEditing'], isTrue);
        expect(stats['autoRemoveCompleted'], isFalse);
      });

      test('should calculate completion percentage', () {
        // Arrange - Add a bought item
        final listWithBoughtItem = testCollaborativeList.copyWith(
          items: [testItem1, testItem2], // testItem2 is bought
        );
        mockParentService.setShoppingState(
          collaborativeLists: [listWithBoughtItem, testSharedList],
          personalLists: [testPersonalList],
          currentUserId: 'user_123',
          currentUserDisplayName: 'Test User',
        );

        // Act
        final stats = operations.getListStats('collab_list_1');

        // Assert
        expect(stats['totalItems'], equals(2));
        expect(stats['boughtItems'], equals(1));
        expect(stats['completionPercentage'], equals(50));
      });
    });

    group('Permission Helpers', () {
      test('should check edit permission', () {
        // Act & Assert
        expect(operations.canEdit('collab_list_1'), isTrue);
        expect(operations.canEdit('shared_list_2'), isFalse);
      });

      test('should check view permission', () {
        // Act & Assert
        expect(operations.canView('collab_list_1'), isTrue);
        expect(operations.canView('shared_list_2'), isTrue);
      });

      test('should check member management permission', () {
        // Act & Assert
        expect(operations.canManageMembers('collab_list_1'), isTrue);
        expect(operations.canManageMembers('shared_list_2'), isFalse);
      });

      test('should check delete permission', () {
        // Act & Assert
        expect(operations.canDelete('collab_list_1'), isTrue);
        expect(operations.canDelete('shared_list_2'), isFalse);
      });

      test('should get user permission level', () {
        // Arrange - permissions are already configured in setUp
        // collab_list_1 has owner permissions for user_123
        // shared_list_2 has only view permissions for user_123

        // Act
        final permission1 = operations.getUserPermission('collab_list_1');
        final permission2 = operations.getUserPermission('shared_list_2');

        // Assert
        expect(permission1, equals(SharedListPermission.admin));
        expect(permission2, equals(SharedListPermission.view));
      });
    });

    group('Notifications', () {
      test('should get notification count', () {
        // Act
        final count = operations.getNotificationCount();

        // Assert
        expect(count, greaterThanOrEqualTo(0));
      });

      test('should mark list as seen', () async {
        // Act
        final result = await operations.markListAsSeen('collab_list_1');

        // Assert
        expect(result, isTrue);
      });
    });
  });
}
