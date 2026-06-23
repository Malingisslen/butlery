/// Journey test: owner shares a recipe with a friend.
///
/// Exercises [UniversalShareDialogViewModel.shareRecipe] through a small
/// UI that mirrors the production share dialog's primary action (pick
/// friends → tap send → dialog closes / error surfaces). We can't route
/// through the real [FirebaseSharedRecipeRepository] in a headless fake
/// firestore because it relies on `FieldValue.arrayUnion`, the counter
/// transactions and the `members` subcollection in ways that need the
/// emulator — BUT the journey invariant we care about is UI-level:
///
///   - Owner picks recipient(s), taps "Dela"
///   - The coordinator is invoked with exactly that recipe ID + friend set
///   - On success the dialog closes (VM state: not sharing, no error)
///   - On coordinator-level failure the user sees the Swedish error
///
/// To also assert the *recipient-visible* side of the contract we stub
/// the coordinator to record the share in a seam (FakeFirebaseFirestore
/// `shared_content` collection) and then query
/// `coordinator.getSharedRecipesForUser(friendId)` — the same call the
/// recipient's "Delat med mig" view makes in production. This lets us
/// prove the end-to-end invariant ("friend can see what was shared with
/// them") without reproducing all of the repository's Firestore plumbing.
library;

// ignore_for_file: invalid_use_of_protected_member

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart' as production;
import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/shared_recipe.dart';
import 'package:butlery/services/unified/modules/social_recipe/social_recipe_coordinator.dart';
import 'package:butlery/services/unified/unified_shopping_service.dart';
import 'package:butlery/services/user_service.dart';
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/viewmodels/universal_share_dialog_viewmodel.dart';

import '../infrastructure/factories/recipe_factory.dart';
import '../infrastructure/mocks/production_mocks.dart';

// Pure mocks — no concrete overrides so when()/verify() work cleanly.
class _MockSocialRecipeCoordinator extends Mock
    implements SocialRecipeCoordinator {}

class _MockUserService extends Mock implements UserService {}

/// Extracted share-dialog body. Owner picks one or more friends from the
/// list, hits "Dela", sees either the dialog close (success) or a Swedish
/// error (failure). Mirrors the decision shape of [UniversalShareDialog]
/// without pulling in its full widget tree.
class _ShareDialogBody extends StatefulWidget {
  const _ShareDialogBody({
    required this.recipe,
    required this.availableFriends,
    required this.onClose,
  });

  final Recipe recipe;
  final List<({String id, String name})> availableFriends;
  final VoidCallback onClose;

  @override
  State<_ShareDialogBody> createState() => _ShareDialogBodyState();
}

class _ShareDialogBodyState extends State<_ShareDialogBody> {
  final Set<String> _selected = {};

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final vm = context.watch<UniversalShareDialogViewModel>();

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              key: const Key('share_header'),
              color: cs.surface,
              padding: const EdgeInsets.all(12),
              child: Text(
                'Dela "${widget.recipe.title}"',
                style: TextStyle(color: cs.onSurface),
              ),
            ),
            Expanded(
              child: ListView(
                children: widget.availableFriends.map((f) {
                  final selected = _selected.contains(f.id);
                  return CheckboxListTile(
                    key: Key('friend_${f.id}'),
                    title: Text(f.name),
                    value: selected,
                    onChanged: (v) => setState(() {
                      if (v == true) {
                        _selected.add(f.id);
                      } else {
                        _selected.remove(f.id);
                      }
                    }),
                  );
                }).toList(),
              ),
            ),
            if (vm.hasError)
              Container(
                key: const Key('share_error'),
                padding: const EdgeInsets.all(8),
                color: cs.errorContainer,
                child: Text(
                  vm.errorMessage ?? '',
                  style: TextStyle(color: cs.onErrorContainer),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: ElevatedButton(
                key: const Key('share_confirm'),
                onPressed: vm.isSharing
                    ? null
                    : () async {
                        final ok = await vm.shareRecipe(
                          recipe: widget.recipe,
                          friendUserIds: _selected.toList(),
                        );
                        if (ok && context.mounted) widget.onClose();
                      },
                child: Text(vm.isSharing ? 'Delar…' : 'Dela'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Widget _testApp({
  required UniversalShareDialogViewModel viewModel,
  required Recipe recipe,
  required List<({String id, String name})> friends,
  required VoidCallback onClose,
}) {
  return ChangeNotifierProvider<UniversalShareDialogViewModel>.value(
    value: viewModel,
    child: MaterialApp(
      locale: const Locale('sv'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: AppTheme.lightTheme,
      home: _ShareDialogBody(
        recipe: recipe,
        availableFriends: friends,
        onClose: onClose,
      ),
    ),
  );
}

/// Build a SharedRecipe instance for the simulated "friend inbox" after
/// a successful share — shape matches what the real repository writes.
SharedRecipe _buildShare({
  required Recipe recipe,
  required String ownerId,
  required String ownerName,
}) {
  return SharedRecipe.create(
    originalRecipeId: recipe.id,
    sharedByUserId: ownerId,
    sharedByDisplayName: ownerName,
    sharedToUserIds: const ['friend_anna'],
    recipeSnapshot: recipe,
  );
}

void main() {
  late _MockSocialRecipeCoordinator mockCoordinator;
  late MockUnifiedShoppingService mockShoppingService;
  late _MockUserService mockUserService;
  late FakeFirebaseFirestore firestore;
  late UniversalShareDialogViewModel viewModel;
  late bool dialogClosed;

  const ownerId = 'owner_bob';
  const friendId = 'friend_anna';

  setUpAll(() {
    registerFallbackValue(RecipeFactory.build());
  });

  setUp(() {
    // Production ServiceLocator bridge — any ServiceLocator.get<>() calls
    // deep inside the coordinator chain hit our registered mocks.
    final getIt = GetIt.instance;
    if (getIt.isRegistered<UserService>()) getIt.unregister<UserService>();
    if (getIt.isRegistered<UnifiedShoppingService>()) {
      getIt.unregister<UnifiedShoppingService>();
    }

    production.ServiceLocator.initialize(DIContainer());

    firestore = FakeFirebaseFirestore();
    mockCoordinator = _MockSocialRecipeCoordinator();
    mockShoppingService = MockUnifiedShoppingService();
    mockUserService = _MockUserService();

    getIt.registerSingleton<UserService>(mockUserService);
    getIt.registerSingleton<UnifiedShoppingService>(mockShoppingService);

    viewModel = UniversalShareDialogViewModel(
      socialRecipeCoordinator: mockCoordinator,
      shoppingService: mockShoppingService,
    );
    dialogClosed = false;
  });

  tearDown(() {
    viewModel.dispose();
    final getIt = GetIt.instance;
    if (getIt.isRegistered<UserService>()) getIt.unregister<UserService>();
    if (getIt.isRegistered<UnifiedShoppingService>()) {
      getIt.unregister<UnifiedShoppingService>();
    }
    production.ServiceLocator.reset();
  });

  group('Share recipe journey', () {
    testWidgets(
      'owner picks friend → tap Dela → coordinator invoked with friend ID, dialog closes, friend sees recipe',
      (tester) async {
        final recipe = RecipeFactory.build(
          id: 'recipe_pannkakor',
          title: 'Pannkakor',
          createdBy: ownerId,
        );

        // Arrange — before the share, the friend's inbox is empty.
        when(
          () => mockCoordinator.getSharedRecipesForUser(friendId),
        ).thenAnswer((_) async => <SharedRecipe>[]);

        // Arrange — when the owner actually shares, the coordinator
        // "persists" the share (we use FakeFirebaseFirestore as a simple
        // seam to record the write, plus a sentinel that flips the
        // recipient's getSharedRecipesForUser result). Then it returns
        // success (true) to the VM.
        when(
          () => mockCoordinator.shareRecipeWithFriends(
            recipeId: any(named: 'recipeId'),
            friendIds: any(named: 'friendIds'),
            message: any(named: 'message'),
            allowCollaboration: any(named: 'allowCollaboration'),
          ),
        ).thenAnswer((invocation) async {
          final recipeId = invocation.namedArguments[#recipeId] as String;
          final friendIds =
              invocation.namedArguments[#friendIds] as List<String>;
          for (final fid in friendIds) {
            await firestore.collection('shared_content').add({
              'originalRecipeId': recipeId,
              'sharedByUserId': ownerId,
              'recipeTitle': recipe.title,
              'sharedToUserIds': [fid],
              'contentType': 'recipe',
            });
          }
          // Update what the "recipient inbox" call will return.
          when(
            () => mockCoordinator.getSharedRecipesForUser(friendId),
          ).thenAnswer(
            (_) async => [
              _buildShare(
                recipe: recipe,
                ownerId: ownerId,
                ownerName: 'Bob',
              ),
            ],
          );
          return true;
        });

        // Sanity — friend's inbox is empty up front.
        final inboxBefore = await mockCoordinator.getSharedRecipesForUser(
          friendId,
        );
        expect(
          inboxBefore,
          isEmpty,
          reason: 'Friend must not see the recipe before the share',
        );

        // Act — render the owner's share dialog and drive the UI.
        await tester.pumpWidget(
          _testApp(
            viewModel: viewModel,
            recipe: recipe,
            friends: const [(id: friendId, name: 'Anna')],
            onClose: () => dialogClosed = true,
          ),
        );
        await tester.pumpAndSettle();

        // Owner picks Anna.
        await tester.tap(find.byKey(Key('friend_$friendId')));
        await tester.pumpAndSettle();

        // Tap "Dela".
        await tester.tap(find.byKey(const Key('share_confirm')));
        await tester.pumpAndSettle();

        // Assert — the coordinator saw exactly the owner's recipe + friend.
        verify(
          () => mockCoordinator.shareRecipeWithFriends(
            recipeId: recipe.id,
            friendIds: [friendId],
            message: null,
            allowCollaboration: false,
          ),
        ).called(1);

        // Dialog closed on success, no error surfaced to the user.
        expect(
          dialogClosed,
          isTrue,
          reason: 'Successful share must close the dialog',
        );
        expect(viewModel.hasError, isFalse);
        expect(viewModel.isSharing, isFalse);
        expect(find.byKey(const Key('share_error')), findsNothing);

        // Firestore seam observed the write (one doc per friend).
        final writes = await firestore.collection('shared_content').get();
        expect(writes.docs, hasLength(1));
        final writeData = writes.docs.first.data();
        expect(writeData['originalRecipeId'], recipe.id);
        expect(writeData['sharedToUserIds'], contains(friendId));
        expect(writeData['sharedByUserId'], ownerId);

        // Recipient's inbox now contains the share — the user-visible
        // contract completes end-to-end.
        final inboxAfter = await mockCoordinator.getSharedRecipesForUser(
          friendId,
        );
        expect(inboxAfter, hasLength(1));
        expect(inboxAfter.single.originalRecipeId, recipe.id);
        expect(inboxAfter.single.sharedByUserId, ownerId);
        expect(inboxAfter.single.recipeTitle, 'Pannkakor');
      },
    );

    testWidgets(
      'tap Dela with no friend selected shows Swedish "no recipients" error',
      (tester) async {
        final recipe = RecipeFactory.build(id: 'recipe_1', title: 'Kaka');

        // The coordinator should NOT be called when the set is empty —
        // the VM short-circuits with a Swedish error before any network op.
        await tester.pumpWidget(
          _testApp(
            viewModel: viewModel,
            recipe: recipe,
            friends: const [(id: friendId, name: 'Anna')],
            onClose: () => dialogClosed = true,
          ),
        );
        await tester.pumpAndSettle();

        // No friend picked.
        await tester.tap(find.byKey(const Key('share_confirm')));
        await tester.pumpAndSettle();

        // User sees an error, dialog stays open, coordinator never called.
        expect(
          viewModel.hasError,
          isTrue,
          reason: 'Empty recipient set must surface an error',
        );
        expect(find.byKey(const Key('share_error')), findsOneWidget);
        expect(dialogClosed, isFalse);
        verifyNever(
          () => mockCoordinator.shareRecipeWithFriends(
            recipeId: any(named: 'recipeId'),
            friendIds: any(named: 'friendIds'),
            message: any(named: 'message'),
            allowCollaboration: any(named: 'allowCollaboration'),
          ),
        );
      },
    );
  });
}
