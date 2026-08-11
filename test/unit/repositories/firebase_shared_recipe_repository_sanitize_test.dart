/// BUT-1819: the shared-recipe write path cleans its denormalized text.
///
/// This path is HYGIENE, not a security hole, and the distinction was worth
/// three review rounds to get right. `SharedRecipe.create` lifts five scalars
/// off the source recipe and `toFirestore` emits `recipeTitle`,
/// `recipeImageUrl`, `recipePortions`, `recipeTimeMinutes` and
/// `recipeDescription` — **no recipe copy and no `sourceUrl`**. So there is no
/// link vector here; an earlier draft of the ticket claimed there was.
///
/// What remains is that the two text fields are copied off the source recipe
/// without cleaning. That matters PRINCIPALLY for recipes created before the
/// repository sanitizer started running — but not only: the text is lifted
/// from an in-memory `Recipe`, and a recipe created offline lives in Drift as
/// raw JSON that never round-tripped through the repository, so sharing one
/// denormalizes raw text today.
///
/// The assertion is on `toFirestore`'s map rather than on a round-trip, because
/// the map is where the fix lives: `SharedRecipe.copyWith` exposes neither
/// field, so the entity cannot be cleaned before serialization.
library;

import 'package:butlery/models/shared_recipe.dart';
import 'package:butlery/repositories/firebase/firebase_shared_recipe_repository.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../infrastructure/di/test_service_locator.dart';
import '../../infrastructure/factories/recipe_factory.dart';
import '../../infrastructure/mocks/production_mocks.dart';
import '../../test_support/base_unit_test.dart';

void main() {
  group('FirebaseSharedRecipeRepository sanitization', () {
    late FirebaseSharedRecipeRepository repository;
    late FakeAuthRepository mockAuthRepo;

    setUpAll(() async {
      await BaseUnitTest.setupUnit();
    });

    setUp(() {
      mockAuthRepo = FakeAuthRepository();
      mockAuthRepo.setAuthState(
        user: FakeUser(),
        userId: 'sharer-1',
        isAuthenticated: true,
      );
      repository = FirebaseSharedRecipeRepository(
        firestore: FakeFirebaseFirestore(),
        authRepository: mockAuthRepo,
      );
    });

    tearDown(() async {
      BaseUnitTest.resetMocks();
      await TestServiceLocator.reset();
    });

    SharedRecipe shareOf({required String title, required String description}) {
      return SharedRecipe.create(
        originalRecipeId: 'r-1',
        sharedByUserId: 'sharer-1',
        sharedByDisplayName: 'Anna',
        sharedToUserIds: const ['friend-1'],
        recipeSnapshot: RecipeFactory.build(
          id: 'r-1',
          title: title,
          description: description,
        ),
      );
    }

    test('strips control characters from the denormalized title', () {
      final data = repository.toFirestore(
        // Explicit escapes, never a pasted invisible character: a literal one
        // is unreviewable in a diff and an earlier draft of this fixture used a
        // plain space by mistake, which made the assertion vacuous.
        shareOf(title: 'Pann\u0000ka\u0007kor', description: 'God'),
      );

      expect(data['recipeTitle'], equals('Pannkakor'));
    });

    test('strips control characters from the denormalized description', () {
      final data = repository.toFirestore(
        shareOf(title: 'Pannkakor', description: 'Med\u0001 sylt'),
      );

      expect(data['recipeDescription'], equals('Med sylt'));
    });

    test('leaves clean text untouched, including Swedish characters', () {
      // The over-reach guard: a sanitizer that mangles å/ä/ö would pass the two
      // tests above and quietly damage every shared Swedish title.
      final data = repository.toFirestore(
        shareOf(title: 'Räksmörgås på rågbröd', description: 'Väldigt god'),
      );

      expect(data['recipeTitle'], equals('Räksmörgås på rågbröd'));
      expect(data['recipeDescription'], equals('Väldigt god'));
    });

    test(
      'writes no recipe copy and no sourceUrl — the premise this rests on',
      () {
        // Pinned because the ticket's first draft claimed the opposite and
        // planned a test against a `recipeSnapshot` field that is never written.
        // If that ever changes, this reddens and the sanitization scope must be
        // revisited rather than silently left behind.
        final data = repository.toFirestore(
          shareOf(title: 'Pannkakor', description: 'God'),
        );

        expect(data.containsKey('recipeSnapshot'), isFalse);
        expect(data.containsKey('sourceUrl'), isFalse);
      },
    );
  });
}
