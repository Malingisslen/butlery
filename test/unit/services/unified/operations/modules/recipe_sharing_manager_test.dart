// test/unit/services/unified/operations/modules/recipe_sharing_manager_test.dart

// BUT-1812 mocks two sealed cloud_firestore types so the payload of the
// auto-id `shared_content` create can be captured off the DocumentReference
// itself. `fake_cloud_firestore` evaluates no rules, so nothing about
// `allow create` can be provoked here — the payload is what a unit test can
// see, and what the rule's required set is checked against. Same convention
// and the same reason as shopping_repository_routing_module_test.dart.
// ignore_for_file: subtype_of_sealed_class

import 'package:cloud_firestore/cloud_firestore.dart'
    show CollectionReference, DocumentReference, Timestamp;
import 'package:butlery/repositories/firestore_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:butlery/services/unified/operations/modules/recipe_sharing_manager.dart';
import 'package:butlery/core/l10n/app_locale.dart';
import 'package:butlery/services/notifications/notification_types.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/permissions/resource_permission.dart';
import 'package:butlery/services/user_service.dart';
import 'package:butlery/core/providers/application_provider.dart'
    as app_provider;
import '../../../../../test_support/base_unit_test.dart';
import '../../../../../test_support/fake_field_value_platform.dart';
import '../../../../../infrastructure/di/test_service_locator.dart';
import '../../../../../infrastructure/mocks/production_mocks.dart';

void main() {
  group('RecipeSharingManager', () {
    late MockUnifiedRecipeService mockParentService;
    late MockNotificationService mockNotificationService;
    late RecipeSharingManager sharingManager;
    late List<Recipe> savedRecipes;
    late Recipe testPersonalRecipe;
    late Recipe testDirtyTitleRecipe;
    late Recipe testCollaborativeRecipe;

    setUpAll(() async {
      // Register fallback values for mocktail
      registerFallbackValue(NotificationStrategy.recipeShared);
      registerFallbackValue(NotificationAction.viewRecipe);
      registerFallbackValue(<NotificationAction>[]);
      registerFallbackValue(
        Recipe(
          core: RecipeCore(
            id: 'test',
            title: 'Test',
            description: 'Test',
            ingredients: [],
            instructions: [],
            mealType: 'Test',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
          type: RecipeType.personal,
        ),
      );
    });

    setUp(() async {
      // BEFORE the bootstrap: cloud_firestore's FieldValue factory is a
      // process-wide singleton and whoever touches it first wins. Without this
      // every `shared_content` write throws a cast error inside the fake and is
      // swallowed by the writer's own catch, landing zero documents — which is
      // what the shared_content assertion below used to be skipped for.
      installFakeFieldValuePlatform();
      await BaseUnitTest.setupUnit();
      await TestServiceLocator.initialize();

      // Bridge production ServiceLocator to TestServiceLocator
      app_provider.ServiceLocator.reset();
      app_provider.ServiceLocator.initialize(MockDIContainer());

      savedRecipes = [];

      // Create mocks
      mockParentService = MockUnifiedRecipeService();
      mockNotificationService = MockNotificationService();

      // Create sharing manager instance
      sharingManager = RecipeSharingManager(
        getCurrentUserId: () => mockParentService.currentUserId,
        getCurrentUserDisplayName: () =>
            mockParentService.currentUserDisplayName,
        getRecipes: () => mockParentService.recipes,
        createCollaborativeRecipe: mockParentService.createCollaborativeRecipe,
        createPersonalRecipe: mockParentService.createPersonalRecipe,
        updateRecipe: (recipe) async {
          savedRecipes.add(recipe);
          return true;
        },
        notificationService: mockNotificationService,
      );

      // Create test data
      testPersonalRecipe = Recipe(
        core: RecipeCore(
          id: 'personal_1',
          title: 'My Great Recipe',
          description: 'A wonderful personal recipe',
          ingredients: ['ingredient 1', 'ingredient 2'],
          instructions: ['step 1', 'step 2'],
          mealType: 'Middag',
          portions: 4,
          timeMinutes: 30,
          rating: 4.5,
          personalTagIds: ['swedish', 'traditional'],
          sourceUrl: 'https://example.com',
          imageUrls: ['image1.jpg', 'image2.jpg'],
          createdBy: 'user_123',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        type: RecipeType.personal,
      );

      testCollaborativeRecipe = Recipe(
        core: RecipeCore(
          id: 'collab_1',
          title: 'Shared Team Recipe',
          description: 'A collaborative recipe',
          ingredients: ['shared ingredient'],
          instructions: ['shared step'],
          mealType: 'Lunch',
          createdBy: 'user_123',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        type: RecipeType.collaborative,
        socialData: RecipeSocialData(
          ownerId: 'user_123',
          ownerDisplayName: 'Recipe Owner',
          memberPermissions: {
            'user_456': ResourcePermission.editor,
            'user_789': ResourcePermission.viewer,
          },
          allowGuestViewing: false,
          allowMemberInvites: true,
          descriptionCollaborative: 'Team collaboration recipe',
        ),
      );

      // BUT-1819: its own recipe, so the shared fixture's title stays clean —
      // 'should share personal recipe successfully' below asserts on the RAW
      // title reaching the parent service. That is the seam ABOVE that path's
      // own chokepoint — the recipe it creates is sanitized later, by
      // `FirebaseRecipeRepository.toFirestore`, which this same ticket adds —
      // so the raw value there is correct and must not move. (No count in this
      // comment on purpose: three earlier versions got the number wrong, which
      // is what a count in a comment does.)
      // Built out rather than copied because `RecipeCore.copyWith` exposes no
      // `id`. Explicit escape, never a pasted invisible byte.
      testDirtyTitleRecipe = Recipe(
        core: RecipeCore(
          id: 'personal_dirty',
          // \u0007, not \u0000: `sanitizeText` strips NUL twice (an explicit
          // replaceAll AND the control-character class), so a NUL fixture
          // survives deletion of the class and pins nothing. BEL is only in
          // the class. Explicit escapes, never pasted invisible bytes.
          title: 'Räksmörgås\u0007 på rågbröd',
          description: 'En helt vanlig\u0007 beskrivning',
          ingredients: ['ingredient 1'],
          instructions: ['step 1'],
          mealType: 'Middag',
          portions: 4,
          timeMinutes: 30,
          createdBy: 'user_123',
          createdAt: DateTime(2026, 1, 1),
          updatedAt: DateTime(2026, 1, 1),
        ),
        type: RecipeType.personal,
      );

      // Configure mocks using setRecipeState method
      mockParentService.setRecipeState(
        currentUserId: 'user_123',
        currentUserDisplayName: 'Current User',
        recipes: [
          testPersonalRecipe,
          testCollaborativeRecipe,
          testDirtyTitleRecipe,
        ],
        isInitialized: true,
      );
      // No need to stub recipes - it's a concrete getter that returns the configured value
    });

    tearDown(() async {
      await TestServiceLocator.reset();
      BaseUnitTest.resetMocks();
    });

    tearDownAll(() async {
      // Cleanup if needed
    });

    group('Recipe Sharing (Personal to Collaborative)', () {
      test('should share personal recipe successfully', () async {
        // Arrange
        final memberIds = ['user_456', 'user_789'];
        final memberDisplayNames = {
          'user_456': 'Member One',
          'user_789': 'Member Two',
        };

        // createCollaborativeRecipe has a concrete spy override on
        // MockUnifiedRecipeService; configure success and inspect the
        // captured call list instead of mocktail verify().
        mockParentService.setCollaborativeState(shouldSucceed: true);

        when(
          () => mockNotificationService.sendImmediateNotification(
            targetUserIds: any(named: 'targetUserIds'),
            strategy: any(named: 'strategy'),
            variables: any(named: 'variables'),
            additionalData: any(named: 'additionalData'),
            imageUrl: any(named: 'imageUrl'),
            actions: any(named: 'actions'),
          ),
        ).thenAnswer((_) async {});

        // Act
        final newId = await sharingManager.shareRecipe(
          recipeId: 'personal_1',
          memberIds: memberIds,
          memberDisplayNames: memberDisplayNames,
          collaborativeDescription: 'Sharing my recipe with the team',
          allowGuestViewing: true,
          allowMemberInvites: false,
          categoryIds: ['category_1'],
        );

        // Assert — mock returns 'collab-<title>' on success.
        expect(newId, equals('collab-My Great Recipe'));

        expect(mockParentService.createCollaborativeRecipeCalls, hasLength(1));
        final call = mockParentService.createCollaborativeRecipeCalls.first;
        expect(call['title'], equals('My Great Recipe'));
        expect(call['memberIds'], equals(memberIds));
        expect(call['description'], equals('A wonderful personal recipe'));
        expect(call['ingredients'], equals(['ingredient 1', 'ingredient 2']));
        expect(call['instructions'], equals(['step 1', 'step 2']));
        expect(call['mealType'], equals('Middag'));
        expect(
          call['descriptionCollaborative'],
          equals('Sharing my recipe with the team'),
        );
        expect(call['allowGuestViewing'], isTrue);
        expect(call['allowMemberInvites'], isFalse);
        expect(call['categoryIds'], equals(['category_1']));

        verify(
          () => mockNotificationService.sendImmediateNotification(
            targetUserIds: memberIds,
            strategy: NotificationStrategy.recipeShared,
            variables: any(named: 'variables'),
            additionalData: any(named: 'additionalData'),
            imageUrl: any(named: 'imageUrl'),
            actions: any(named: 'actions'),
          ),
        ).called(1);
      });

      /// BUT-1775, the BUT-1705/BUT-1736 class. The name written here lands on
      /// a `shared_content` document every group member reads AND verbatim in
      /// their Article-15 export, so it must be the PROFILE name — the one
      /// `on-profile-updated.ts` renames and account deletion scrubs — not the
      /// Firebase Auth handle that `PermissionService.currentUser` synthesizes
      /// from the user's Google/Apple account. The fake permission service
      /// stamps 'Test User', so a revert to the Auth source reddens this.
      ///
      /// This was SKIPPED on the measured-but-wrong conclusion that no unit test
      /// in this harness could observe the document: a probe writing
      /// `FieldValue.serverTimestamp()` through this repository threw
      /// `MethodChannelFieldValue is not a subtype of MockFieldValuePlatform`
      /// and `_writeToSharedRecipesCollection` swallowed it, landing zero docs.
      /// The symptom was real; the conclusion was not. The factory is a
      /// process-wide singleton, and claiming it before the bootstrap
      /// (`installFakeFieldValuePlatform()` in `setUp`) makes the write land —
      /// the assertion below is unchanged from when it was skipped, and fails
      /// on `expect(docs.docs, isNotEmpty)` without that line.
      test(
        'stamps the PROFILE display name on shared_content, never the Auth '
        'handle (BUT-1775)',
        () async {
          final userService =
              app_provider.ServiceLocator.get<UserService>() as MockUserService;
          when(
            () => userService.profileDisplayName,
          ).thenReturn('Malin i appen');

          mockParentService.setCollaborativeState(shouldSucceed: true);
          when(
            () => mockNotificationService.sendImmediateNotification(
              targetUserIds: any(named: 'targetUserIds'),
              strategy: any(named: 'strategy'),
              variables: any(named: 'variables'),
              additionalData: any(named: 'additionalData'),
              imageUrl: any(named: 'imageUrl'),
              actions: any(named: 'actions'),
            ),
          ).thenAnswer((_) async {});

          await sharingManager.shareRecipe(
            recipeId: 'personal_1',
            memberIds: ['user_456'],
            memberDisplayNames: {'user_456': 'Member One'},
          );

          // Read through the SAME repository instance the manager wrote through:
          // `FirestoreSingleton.instance` force-recreates itself periodically, so
          // reading the singleton can land on a fresh, empty database.
          final repository =
              app_provider.ServiceLocator.get<FirestoreRepository>()
                  as FakeFirestoreRepository;
          final docs = await repository.collection('shared_content').get();
          expect(
            docs.docs,
            isNotEmpty,
            reason: 'the shared_content write is the subject of this test',
          );
          expect(
            docs.docs.first.data()['sharedByDisplayName'],
            'Malin i appen',
            reason:
                'the Auth handle is the legal name on the user s Google/Apple '
                'account, never chosen for display, and it lands verbatim in '
                'every recipient s Article-15 bundle',
          );
          // `sharedToUserIds` is the membership field `firestore.rules`'
          // recipient branch (:722/:727) and the GDPR export both read, and
          // since 2026-08-03 the only one written. Writing the row under the
          // RETIRED spelling `sharedWithUserIds` instead made it
          // permission-denied for the very people it was shared with, and kept
          // it out of their Art. 15 bundle — a wrong-field query throws nothing
          // and reads as "no shares".
          // Mirrors the menu-side assertion in
          // `social_menu_operations_test.dart`; without it a dropped field is
          // invisible to every suite, because no fake ever denies.
          expect(
            docs.docs.first.data()['sharedToUserIds'],
            contains('user_456'),
            reason:
                'the recipient must be listed under the rules-sanctioned '
                'membership field, the one the rules and the export both read',
          );
        },
      );

      test(
        'BUT-1819: sanitizes its OWN shared_content payload, and does not '
        'mangle Swedish doing it',
        () async {
          // This manager builds its payload by hand and never touches
          // `FirebaseSharedRecipeRepository.toFirestore`, so the sanitization
          // there does not reach it. Both now call `sanitizeSharedRecipeText`
          // — this pins the manager half. Without it, deleting that call left
          // every suite green while the repository half had four tests, which
          // is exactly the drift the shared helper exists to prevent.
          mockParentService.setCollaborativeState(shouldSucceed: true);
          when(
            () => mockNotificationService.sendImmediateNotification(
              targetUserIds: any(named: 'targetUserIds'),
              strategy: any(named: 'strategy'),
              variables: any(named: 'variables'),
              additionalData: any(named: 'additionalData'),
              imageUrl: any(named: 'imageUrl'),
              actions: any(named: 'actions'),
            ),
          ).thenAnswer((_) async {});

          await sharingManager.shareRecipe(
            recipeId: 'personal_dirty',
            memberIds: ['user_456'],
            memberDisplayNames: {'user_456': 'Member One'},
          );

          final repository =
              app_provider.ServiceLocator.get<FirestoreRepository>()
                  as FakeFirestoreRepository;
          final docs = await repository.collection('shared_content').get();
          expect(
            docs.docs,
            isNotEmpty,
            reason: 'premise: the shared_content write must have landed',
          );
          expect(
            docs.docs.first.data()['title'],
            'Räksmörgås på rågbröd',
            reason:
                'the control character is stripped AND å/ä/ö survive — a '
                'sanitizer that mangled Swedish would pass a stripping-only '
                'assertion and quietly damage every shared title',
          );
          expect(
            docs.docs.first.data()['description'],
            'En helt vanlig beskrivning',
            reason:
                'the OTHER arm. Asserting only the title let the description '
                'line be deleted with every suite green, and a compound '
                'mutation of both lines could not tell the two apart',
          );
        },
      );

      /// BUT-1812. The write is a single unconditional create, and it stamps
      /// `sharedAt`.
      ///
      /// There is nothing to read before writing any more: the row is keyed on
      /// an auto-id, so it is this share's own document and always a create.
      /// The predecessor of this test pinned an existence probe that decided
      /// create-vs-update; that probe is gone with the recipeId key, and this
      /// is the assertion that outlives it — `allow create` refuses a row
      /// without `sharedAt`, the catch around the whole method swallows the
      /// denial, and the recipient silently loses both their read grant and
      /// their Art. 15 row.
      ///
      /// The capture is on a mocked `DocumentReference` rather than the fake
      /// Firestore because it also pins that the write goes through
      /// `collection(...).doc()` with NO id argument — re-deriving the id from
      /// the recipe is exactly what BUT-1812 had to undo.
      test(
        'the shared_content create is unconditional and stamps sharedAt',
        () async {
          final docRef = _MockSharedContentDoc();
          final captured = <Map<String, dynamic>>[];
          final repository = _CapturingRepository(docRef);

          when(() => docRef.set(any(), any())).thenAnswer((invocation) async {
            captured.add(
              invocation.positionalArguments[0] as Map<String, dynamic>,
            );
          });

          final manager = RecipeSharingManager(
            getCurrentUserId: () => mockParentService.currentUserId,
            getCurrentUserDisplayName: () =>
                mockParentService.currentUserDisplayName,
            getRecipes: () => mockParentService.recipes,
            createCollaborativeRecipe:
                mockParentService.createCollaborativeRecipe,
            createPersonalRecipe: mockParentService.createPersonalRecipe,
            updateRecipe: (_) async => true,
            notificationService: mockNotificationService,
            firestoreRepository: repository,
          );

          await manager.shareRecipe(
            recipeId: testCollaborativeRecipe.id,
            memberIds: const ['user_456'],
            memberDisplayNames: const {'user_456': 'Member One'},
          );

          expect(
            captured,
            isNotEmpty,
            reason:
                'the row is written on every share, with nothing read first — '
                'the whole method sits inside a catch, so a skipped write is '
                'invisible everywhere except here',
          );
          expect(
            captured.first.containsKey('sharedAt'),
            isTrue,
            reason:
                'the create rule requires sharedAt via hasRequiredFields, and '
                'this row IS this share, so there is no earlier value to '
                'preserve and no reason to stamp it conditionally',
          );
          expect(
            repository.requestedDocIds,
            [null],
            reason:
                'exactly one auto-id create. An id passed here would be the '
                'recipeId key BUT-1812 removed, which made a re-share an '
                'update of whatever row already sat at that slot',
          );
        },
      );

      /// BUT-1812. A re-share writes its OWN `shared_content` row.
      ///
      /// This used to key the row on the recipeId and `set(merge: true)` into
      /// it, so the first share was a create and every re-share an update —
      /// which `firestore.rules` guards with `cannotModify(['sharedByUserId',
      /// 'contentType', 'sharedAt'])`. Two failures came of that. A resolved
      /// `serverTimestamp` never equals the stored one, so an unconditional
      /// `sharedAt` put it in `affectedKeys()` and the engine refused the whole
      /// write (BUT-1775, fixed by stamping create-only). And if the row at
      /// that id belonged to ANOTHER user, `allow get` and `allow update` are
      /// both false for us by design, so no payload could ever add our
      /// recipients — not fixable from the client at all (BUT-1812). Malin's
      /// call was one row per share, matching the menu and shopping-list
      /// writers, over widening `allow update` to let recipients extend the
      /// recipient list.
      ///
      /// No fake evaluates rules, so the assertion is on the shape the denial
      /// was caused by: a pre-existing row is left untouched, and the new
      /// recipient reaches `sharedToUserIds` on a row of this share's own.
      test(
        're-sharing writes a NEW row and never touches the existing one '
        '(BUT-1812)',
        () async {
          final userService =
              app_provider.ServiceLocator.get<UserService>() as MockUserService;
          when(
            () => userService.profileDisplayName,
          ).thenReturn('Malin i appen');

          final repository =
              app_provider.ServiceLocator.get<FirestoreRepository>()
                  as FakeFirestoreRepository;
          // The row a FIRST share left behind, still keyed on the recipeId the
          // way pre-BUT-1812 shares were. `collab_1` is collaborative, so
          // shareRecipe takes the re-share branch.
          final firstSharedAt = Timestamp.fromDate(DateTime.utc(2026, 1, 2, 3));
          await repository.collection('shared_content').doc('collab_1').set({
            'contentType': 'recipe',
            'recipeId': 'collab_1',
            'sharedByUserId': 'user_123',
            'sharedAt': firstSharedAt,
            'sharedToUserIds': ['user_123', 'user_456', 'user_789'],
            'isActive': true,
          });

          when(
            () => mockNotificationService.sendImmediateNotification(
              targetUserIds: any(named: 'targetUserIds'),
              strategy: any(named: 'strategy'),
              variables: any(named: 'variables'),
              additionalData: any(named: 'additionalData'),
              imageUrl: any(named: 'imageUrl'),
              actions: any(named: 'actions'),
            ),
          ).thenAnswer((_) async {});

          await sharingManager.shareRecipe(
            recipeId: 'collab_1',
            memberIds: ['new_member'],
            memberDisplayNames: {'new_member': 'New Member'},
          );

          final rows = await repository.collection('shared_content').get();
          final fresh = rows.docs.where((d) => d.id != 'collab_1').toList();

          expect(
            fresh,
            hasLength(1),
            reason:
                'each share is its own document — writing into the recipeId '
                'slot is what made a re-share collide with a stranger row no '
                'payload of ours could ever update',
          );
          expect(
            fresh.single.data()['sharedToUserIds'],
            contains('new_member'),
            reason:
                'the whole point of the write: the new recipient must reach '
                'the field their allow-list grant and their Art. 15 rows '
                'depend on',
          );
          expect(
            fresh.single.data()['sharedAt'],
            isNotNull,
            reason:
                'always stamped now — this row IS this share, so there is no '
                'earlier value to preserve, and `allow create` requires it',
          );

          final old =
              (await repository
                      .collection('shared_content')
                      .doc('collab_1')
                      .get())
                  .data()!;
          expect(
            old['sharedAt'],
            firstSharedAt,
            reason: 'the pre-existing row is not written at all any more',
          );
          expect(old['sharedToUserIds'], isNot(contains('new_member')));
        },
      );

      test(
        'rejects share when projected size would exceed cap (BUT-955)',
        () async {
          // Stage a collaborative recipe already at cap: 200 distinct members.
          // Adding the owner (user_123) via the set union puts the projected
          // size at 201, then the new member pushes it to 202 — over the
          // Recipe.maxSharesPerRecipe ceiling. Cap-guard must short-circuit
          // before any createCollaborativeRecipe call.
          final atCapMembers = <String, ResourcePermission>{
            for (var i = 0; i < 200; i++)
              'member_$i': ResourcePermission.viewer,
          };
          final atCapRecipe = Recipe(
            core: testCollaborativeRecipe.core,
            type: RecipeType.collaborative,
            socialData: RecipeSocialData(
              ownerId: 'user_123',
              ownerDisplayName: 'Recipe Owner',
              memberPermissions: atCapMembers,
              allowGuestViewing: false,
              allowMemberInvites: true,
            ),
          );
          mockParentService.setRecipeState(
            currentUserId: 'user_123',
            currentUserDisplayName: 'Current User',
            recipes: [atCapRecipe],
            isInitialized: true,
          );

          final newId = await sharingManager.shareRecipe(
            recipeId: 'collab_1',
            memberIds: ['new-member-1'],
            memberDisplayNames: {'new-member-1': 'New Member'},
          );

          expect(newId, isNull, reason: 'cap-guard must reject');
          expect(mockParentService.createCollaborativeRecipeCalls, isEmpty);
        },
      );

      test(
        'BUT-1056: cap-rejection routes the localized message to onShareError',
        () async {
          // Same at-cap staging as above, but this manager wires an onShareError
          // sink — proving the UI gets the dedicated cap message instead of a
          // bare null it can't distinguish from "not found" / "save failed".
          String? surfacedError;
          final manager = RecipeSharingManager(
            getCurrentUserId: () => mockParentService.currentUserId,
            getCurrentUserDisplayName: () =>
                mockParentService.currentUserDisplayName,
            getRecipes: () => mockParentService.recipes,
            createCollaborativeRecipe:
                mockParentService.createCollaborativeRecipe,
            createPersonalRecipe: mockParentService.createPersonalRecipe,
            updateRecipe: (_) async => true,
            notificationService: mockNotificationService,
            onShareError: (msg) => surfacedError = msg,
          );

          final atCapMembers = <String, ResourcePermission>{
            for (var i = 0; i < 200; i++)
              'member_$i': ResourcePermission.viewer,
          };
          final atCapRecipe = Recipe(
            core: testCollaborativeRecipe.core,
            type: RecipeType.collaborative,
            socialData: RecipeSocialData(
              ownerId: 'user_123',
              ownerDisplayName: 'Recipe Owner',
              memberPermissions: atCapMembers,
              allowGuestViewing: false,
              allowMemberInvites: true,
            ),
          );
          mockParentService.setRecipeState(
            currentUserId: 'user_123',
            currentUserDisplayName: 'Current User',
            recipes: [atCapRecipe],
            isInitialized: true,
          );

          final newId = await manager.shareRecipe(
            recipeId: 'collab_1',
            memberIds: ['new-member-1'],
            memberDisplayNames: {'new-member-1': 'New Member'},
          );

          expect(newId, isNull, reason: 'cap-guard still rejects');
          expect(
            surfacedError,
            equals(
              AppLocale.current.errorShareCapReached(Recipe.maxSharesPerRecipe),
            ),
            reason: 'cap message must reach the UI error sink',
          );
        },
      );

      test('should fail when recipe not found', () async {
        // Act
        final newId = await sharingManager.shareRecipe(
          recipeId: 'nonexistent',
          memberIds: ['user_456'],
          memberDisplayNames: {'user_456': 'Member'},
        );

        // Assert
        expect(newId, isNull);
        // createCollaborativeRecipe is a concrete spy on the mock — assert
        // no call was recorded instead of using mocktail verifyNever().
        expect(mockParentService.createCollaborativeRecipeCalls, isEmpty);
      });

      // BUT-1797. The tests immediately below assert on `savedRecipes`,
      // which the `updateRecipe` seam fills — not everything in the rest of this
      // file. Until they existed the seam was installed and never read: a
      // recorder with no assertion, which reads as coverage to a reviewer and to
      // grep while proving nothing. `_grantAccessOnReshare` could
      // have been deleted whole with every suite green.
      test(
        'a re-share GRANTS the new people access, not just a notification',
        () async {
          final newId = await sharingManager.shareRecipe(
            recipeId: 'collab_1',
            memberIds: ['user_999'],
            memberDisplayNames: {'user_999': 'New Member'},
          );

          // Carries the return-value pin from the test this replaced: the id
          // flows through unchanged AND `_grantAccessOnReshare` returned true —
          // a false return makes the whole call yield null.
          expect(newId, equals('collab_1'));

          final saved = savedRecipes.single;
          expect(
            saved.socialData?.memberPermissions?.containsKey('user_999'),
            isTrue,
            reason:
                'before this, a re-share wrote only the shared_recipes row — the '
                'recipient was told about a recipe they could not open',
          );
          expect(saved.socialData?.grants?['user_999'], [
            RecipeSocialData.directGrant,
          ]);
        },
      );

      test('a re-share from a GROUP records that group as the reason', () async {
        await sharingManager.shareRecipe(
          recipeId: 'collab_1',
          memberIds: ['user_999'],
          memberDisplayNames: {'user_999': 'New Member'},
          categoryIds: ['group_a'],
        );

        final saved = savedRecipes.single;
        expect(saved.socialData?.grants?['user_999'], ['group:group_a']);
        // The group must also reach `categoryIds`: `removeGroup` refuses outright
        // when the group is not listed there, so dropping this merge would leave
        // members holding `group:group_a` on a recipe whose panel cannot revoke
        // it — provenance recorded and unusable.
        expect(saved.socialData?.categoryIds, contains('group_a'));
      });

      test('re-sharing to a group that contains the sharer grants the '
          'sharer nothing', () async {
        // A friend category always contains its own owner, and the caller hands
        // that roster straight to shareRecipe — so without the skip in
        // `_grantAccessOnReshare` the owner grants THEMSELVES a revocable reason
        // to see their own recipe. Two things then go wrong, and both are
        // asserted here because either one alone can be produced by a different
        // mutant: the owner picks up an `editor` permission entry they never
        // had, and `revokeGroup` later counts them among the members who "kept
        // access via another grant".
        //
        // `user_123` is the owner and is deliberately ABSENT from the fixture's
        // memberPermissions, so `putIfAbsent` really does write on the mutant.
        await sharingManager.shareRecipe(
          recipeId: 'collab_1',
          memberIds: ['user_123', 'user_999'],
          memberDisplayNames: const {
            'user_123': 'Current User',
            'user_999': 'New Member',
          },
          categoryIds: ['group_a'],
        );

        final saved = savedRecipes.single;
        expect(
          saved.socialData?.grants?.containsKey('user_123'),
          isFalse,
          reason: 'the sharer is not a sharee — ownership needs no grant',
        );
        expect(
          saved.socialData?.memberPermissions?.containsKey('user_123'),
          isFalse,
          reason: 'and they must not be written in as an ordinary editor',
        );
        // CONTROL PAIR, and it is what makes the two negatives above load-
        // bearing rather than vacuous: the same loop body demonstrably writes
        // BOTH a grant and a permission for an id it does not skip. So the only
        // thing that can explain user_123 having neither is the skip itself.
        expect(saved.socialData?.grants?['user_999'], ['group:group_a']);
        expect(
          saved.socialData?.memberPermissions?['user_999'],
          ResourcePermission.editor,
        );
      });

      test('a group containing only the sharer adds no revocable row', () async {
        // Every friend category seeds its own owner, so a group you created and
        // have not populated has exactly this roster. The sharer is skipped, so
        // NOBODY is granted — and merging the raw group id into `categoryIds`
        // would put a revoke row in the panel that matches no member's grant.
        //
        // Pressing that row: `removeGroup` clears its `categoryIds.contains`
        // guard, `revokeGroup` takes the empty-grants branch, returns true having
        // cut nobody, and the snackbar says "Gruppen X har inte längre åtkomst
        // till receptet." That is BUT-1785 through a different door, and worse —
        // the copy this ticket replaced at least admitted the members kept access.
        await sharingManager.shareRecipe(
          recipeId: 'collab_1',
          memberIds: ['user_123'],
          memberDisplayNames: const {'user_123': 'Me'},
          categoryIds: ['group_solo'],
        );

        final saved = savedRecipes.single.socialData!;
        expect(
          saved.categoryIds ?? const <String>[],
          isNot(contains('group_solo')),
          reason:
              'no grant was written for anyone, so there is nothing to revoke',
        );
        expect(saved.grants?.containsKey('user_123'), isNot(isTrue));
      });

      test('a re-share never overwrites an existing permission', () async {
        // `user_789` is a VIEWER in the fixture, and the re-share default is
        // editor — so this fixture discriminates in the direction that matters.
        // Using `user_456` (already an editor) would be vacuous: `putIfAbsent`
        // and a plain overwrite are byte-identical when the value equals the
        // default.
        await sharingManager.shareRecipe(
          recipeId: 'collab_1',
          memberIds: ['user_456', 'user_789'],
          memberDisplayNames: const {
            'user_456': 'Member One',
            'user_789': 'Member Two',
          },
        );

        final perms = savedRecipes.single.socialData!.memberPermissions!;
        expect(
          perms['user_789'],
          ResourcePermission.viewer,
          reason: 'a re-share must not silently promote or demote anyone',
        );
        expect(perms['user_456'], ResourcePermission.editor);
      });

      test('should handle creation failure', () async {
        // Arrange — concrete spy returns null when shouldSucceed=false
        // (the default), so no stub is needed for the failure path.
        mockParentService.setCollaborativeState(shouldSucceed: false);

        // Act
        final newId = await sharingManager.shareRecipe(
          recipeId: 'personal_1',
          memberIds: ['user_456'],
          memberDisplayNames: {'user_456': 'Member'},
        );

        // Assert
        expect(newId, isNull);
      });
    });

    group('Recipe Personal Copy (Collaborative to Personal)', () {
      test('should make personal copy of collaborative recipe', () async {
        // Arrange
        when(
          () => mockParentService.createPersonalRecipe(
            title: any(named: 'title'),
            description: any(named: 'description'),
            ingredients: any(named: 'ingredients'),
            instructions: any(named: 'instructions'),
            mealType: any(named: 'mealType'),
            portions: any(named: 'portions'),
            timeMinutes: any(named: 'timeMinutes'),
            rating: any(named: 'rating'),
            personalTagIds: any(named: 'personalTagIds'),
            sourceUrl: any(named: 'sourceUrl'),
            imageUrls: any(named: 'imageUrls'),
          ),
        ).thenAnswer((_) async => 'new_personal_id');

        // Act
        final newId = await sharingManager.makeRecipePersonal(
          collaborativeRecipeId: 'collab_1',
          newTitle: 'My Copy',
        );

        // Assert
        expect(newId, equals('new_personal_id'));

        verify(
          () => mockParentService.createPersonalRecipe(
            title: 'My Copy',
            description: 'A collaborative recipe',
            ingredients: ['shared ingredient'],
            instructions: ['shared step'],
            mealType: 'Lunch',
            portions: any(named: 'portions'),
            timeMinutes: any(named: 'timeMinutes'),
            rating: any(named: 'rating'),
            personalTagIds: any(named: 'personalTagIds'),
            sourceUrl: any(named: 'sourceUrl'),
            imageUrls: any(named: 'imageUrls'),
          ),
        ).called(1);
      });

      test('should use default title when not specified', () async {
        // Arrange
        when(
          () => mockParentService.createPersonalRecipe(
            title: any(named: 'title'),
            description: any(named: 'description'),
            ingredients: any(named: 'ingredients'),
            instructions: any(named: 'instructions'),
            mealType: any(named: 'mealType'),
            portions: any(named: 'portions'),
            timeMinutes: any(named: 'timeMinutes'),
            rating: any(named: 'rating'),
            personalTagIds: any(named: 'personalTagIds'),
            sourceUrl: any(named: 'sourceUrl'),
            imageUrls: any(named: 'imageUrls'),
          ),
        ).thenAnswer((_) async => 'new_personal_id');

        // Act
        final newId = await sharingManager.makeRecipePersonal(
          collaborativeRecipeId: 'collab_1',
        );

        // Assert
        expect(newId, equals('new_personal_id'));
        verify(
          () => mockParentService.createPersonalRecipe(
            title: 'Shared Team Recipe (Min kopia)',
            description: any(named: 'description'),
            ingredients: any(named: 'ingredients'),
            instructions: any(named: 'instructions'),
            mealType: any(named: 'mealType'),
            portions: any(named: 'portions'),
            timeMinutes: any(named: 'timeMinutes'),
            rating: any(named: 'rating'),
            personalTagIds: any(named: 'personalTagIds'),
            sourceUrl: any(named: 'sourceUrl'),
            imageUrls: any(named: 'imageUrls'),
          ),
        ).called(1);
      });

      test('should fail when recipe not collaborative', () async {
        // Act
        final newId = await sharingManager.makeRecipePersonal(
          collaborativeRecipeId: 'personal_1',
        );

        // Assert
        expect(newId, isNull);
      });
    });

    // Share state management and bulk operations are not implemented in the actual RecipeSharingManager class
  });
}

/// BUT-1812. `_writeToSharedRecipesCollection` builds its own `shared_content`
/// payload and writes it to an AUTO id — `collection(...).doc()` with no
/// argument, then a plain `set`. Nothing is read first.
///
/// These mocks exist to capture that payload and that id. `fake_cloud_firestore`
/// evaluates no rules, so a unit test can never see `allow create` refuse a row;
/// what it CAN see is whether the payload carries the fields the rule requires,
/// and whether the write still asks for a document id of its own choosing. Both
/// failures are silent in production — the method sits inside a catch, and the
/// cost lands on the recipient, who loses their read grant and their Art. 15 row.
class _MockSharedContentCollection extends Mock
    implements CollectionReference<Map<String, dynamic>> {}

class _MockSharedContentDoc extends Mock
    implements DocumentReference<Map<String, dynamic>> {}

class _CapturingRepository extends Fake implements FirestoreRepository {
  _CapturingRepository(this.docRef);
  final DocumentReference<Map<String, dynamic>> docRef;

  /// The id each `.doc(...)` call asked for. `null` is the auto-id case; a
  /// non-null entry means a writer re-derived the document id from the content,
  /// which is the collision BUT-1812 removed.
  final List<String?> requestedDocIds = <String?>[];

  @override
  CollectionReference<Map<String, dynamic>> collection(String path) {
    final col = _MockSharedContentCollection();
    when(() => col.doc(any())).thenAnswer((invocation) {
      final args = invocation.positionalArguments;
      requestedDocIds.add(args.isEmpty ? null : args.first as String?);
      return docRef;
    });
    return col;
  }
}
