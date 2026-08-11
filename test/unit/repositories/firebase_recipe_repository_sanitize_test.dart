/// BUT-1819: the sanitizer on the recipe write paths.
///
/// There was no test of this anywhere before — which is why a line added on
/// 2026-03-15 sat dead for five months. `create` sanitized into a local and
/// then rebuilt that local from the UNSANITIZED entity, throwing the work away.
///
/// **Why the fixtures below all leave `ingredientsNormalized` null:** that is its
/// default, nothing on a LIVE create path populates it, and `needsNormalization`
/// returns true whenever it is null. So the branch that discarded the
/// sanitization ran on every create that actually happens. A fixture that
/// pre-populated the field would take the other branch and prove nothing.
/// (Two copy factories DO carry the field forward. `recipe_factory.dart:340`
/// has no PRODUCTION caller at all — its own test suite pins it, including a
/// case written for that exact line. `realtime_recipe.dart:527` HAS callers —
/// `recipe_content_operations.dart:427` ← `realtime_recipe_service.dart:405` —
/// on a chain that is dead at the top. Neither reaches a live create. An
/// earlier version of this parenthetical said "both are uncalled" and claimed
/// the production comment agreed; the production comment says the opposite and
/// warns against exactly that reading. Keep the two in step.)
///
/// Most assertions read the stored DOCUMENT, because that is what the next
/// reader sees. The one exception is deliberate and named as such: `create
/// returns an object matching what was stored` reads the RETURNED object, and
/// it is the only test here that can kill the create-branch mutant — the
/// chokepoint keeps the document clean either way.
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/repositories/firebase/firebase_recipe_repository.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../infrastructure/di/test_service_locator.dart';
import '../../infrastructure/factories/recipe_factory.dart';
import '../../infrastructure/mocks/production_mocks.dart';
import '../../test_support/base_unit_test.dart';

void main() {
  group('FirebaseRecipeRepository sanitization', () {
    late FirebaseRecipeRepository repository;
    late FakeFirebaseFirestore fakeFirestore;
    late FakeAuthRepository mockAuthRepo;

    const uid = 'test-user-123';

    setUpAll(() async {
      await BaseUnitTest.setupUnit();
    });

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      mockAuthRepo = FakeAuthRepository();
      mockAuthRepo.setAuthState(
        user: FakeUser(),
        userId: uid,
        isAuthenticated: true,
      );
      repository = FirebaseRecipeRepository(
        firestore: fakeFirestore,
        authRepository: mockAuthRepo,
      );
    });

    tearDown(() async {
      BaseUnitTest.resetMocks();
      await TestServiceLocator.reset();
    });

    Future<Map<String, dynamic>> storedCore(String id) async {
      final doc = await fakeFirestore
          .collection('users')
          .doc(uid)
          .collection('recipes')
          .doc(id)
          .get();
      return (doc.data()!['core'] as Map<String, dynamic>);
    }

    test('create blanks a javascript: sourceUrl', () async {
      // Which mutant does this kill? NEITHER of the two structural ones — it
      // kills deletion of `sanitizeRecipeText`'s own `sourceUrl` arm. Reverting
      // the `toFirestore` chokepoint leaves this green, because by then
      // `create` has already sanitized into `recipeToSave`, which is exactly
      // what `super.create` hands the override. Reverting `create`'s branch
      // leaves it green too, because the chokepoint catches it. Those two are
      // killed by `createBatch sanitizes` and by `create returns a SANITIZED
      // object` respectively.
      //
      // This sentence has now been wrong twice, in opposite directions. If you
      // are about to restate it, run the three mutants rather than reason.
      final recipe = RecipeFactory.build(
        id: 'r-js',
        createdBy: uid,
        sourceUrl: 'javascript:alert(1)',
      );

      await repository.create(recipe);

      expect((await storedCore('r-js'))['sourceUrl'], isEmpty);
    });

    test(
      'create returns a SANITIZED object, not just a sanitized document',
      () async {
        // The chokepoint in `toFirestore` would make the stored document clean
        // even with the bug present. This pins the other half: the object handed
        // back to the caller is sanitized too, so a view that renders the result
        // of `create` without re-reading cannot show the raw value.
        final recipe = RecipeFactory.build(
          id: 'r-mem',
          createdBy: uid,
          sourceUrl: 'javascript:alert(1)',
        );

        final created = await repository.create(recipe);

        expect(created.core.sourceUrl, isEmpty);
      },
    );

    test('create strips control characters from the title', () async {
      final recipe = RecipeFactory.build(
        id: 'r-ctrl',
        createdBy: uid,
        title: 'Pann\u0000kakor\u0007',
      );

      await repository.create(recipe);

      expect((await storedCore('r-ctrl'))['title'], equals('Pannkakor'));
    });

    test('create strips control characters from the description', () async {
      // `sanitizeRecipeText` cleans THREE fields on this path. `title` and
      // `sourceUrl` were pinned; `description` was not, by any test anywhere —
      // delete its line and nothing reddened. That is this ticket's own failure
      // mode (a sanitize line nothing exercises) reproduced one field over,
      // which is why it is fixed rather than recorded.
      //
      // BEL, not NUL: `sanitizeText` strips NUL twice, so a NUL fixture
      // survives deletion of the control-character class. The å/ä/ö carry the
      // over-reach guard in the same fixture.
      final recipe = RecipeFactory.build(
        id: 'r-desc',
        createdBy: uid,
        description: 'Räksmörgås\u0007 på rågbröd',
      );

      await repository.create(recipe);

      expect(
        (await storedCore('r-desc'))['description'],
        equals('Räksmörgås på rågbröd'),
      );
    });

    test('create leaves a real https URL untouched', () async {
      // The over-reach guard, half one. A fix that blanks everything would
      // pass every test above and destroy real provenance.
      final recipe = RecipeFactory.build(
        id: 'r-ok',
        createdBy: uid,
        sourceUrl: 'https://ica.se/recept/pannkakor',
      );

      await repository.create(recipe);

      expect(
        (await storedCore('r-ok'))['sourceUrl'],
        equals('https://ica.se/recept/pannkakor'),
      );
    });

    test('create leaves a provenance sentence untouched', () async {
      // Half two, and the case the ticket's first draft got wrong: `sourceUrl`
      // is a free-text provenance field for a dozen writers. Blanking these
      // would erase where a recipe came from.
      final recipe = RecipeFactory.build(
        id: 'r-prov',
        createdBy: uid,
        // The ENGLISH seed string, which this same commit renames in production.
        // Kept deliberately: it is still stored on every account seeded before
        // the rename, and nothing backfills it. Any non-URL sentence proves the
        // same thing, so do not read it as stale.
        sourceUrl: 'Butlery recipe collection',
      );

      await repository.create(recipe);

      expect(
        (await storedCore('r-prov'))['sourceUrl'],
        equals('Butlery recipe collection'),
      );
    });

    test(
      'a sentence CONTAINING data: is blanked — accepted, not a surprise',
      () async {
        // `HtmlSanitizer._suspiciousUrlPatterns` matches as an UNANCHORED
        // substring, so this loses the whole field. Pinned deliberately: it is a
        // real consequence of turning the sanitizer on, it is recorded in the
        // BUT-1819 plan as accepted, and anchoring the pattern is a separate
        // judgement about how aggressive URL blocking should be.
        final recipe = RecipeFactory.build(
          id: 'r-over',
          createdBy: uid,
          sourceUrl: 'Kopierat fran Tarta med data 3 agg',
        );

        await repository.create(recipe);
        expect(
          (await storedCore('r-over'))['sourceUrl'],
          equals('Kopierat fran Tarta med data 3 agg'),
          reason: 'no colon, so no match — this one survives',
        );

        final withColon = RecipeFactory.build(
          id: 'r-over2',
          createdBy: uid,
          sourceUrl: 'Kopierat fran: Tarta med data: 3 agg',
        );

        await repository.create(withColon);
        expect(
          (await storedCore('r-over2'))['sourceUrl'],
          isEmpty,
          reason: 'contains "data:" anywhere -> whole field blanked',
        );

        // The discriminator. The two fixtures above differ on BOTH colons at
        // once, so together they cannot tell "contains `data:`" from "contains
        // any colon" — a sanitizer that blanked every colon would pass them
        // both. This one has the colon `recipeCopiedFrom` really produces and no
        // `data:`, so it must survive. It is also the only create-path fixture
        // carrying å/ä/ö through the homoglyph fold.
        final colonNoData = RecipeFactory.build(
          id: 'r-over3',
          createdBy: uid,
          sourceUrl: 'Kopierat från: Tårta med data 3 ägg',
        );

        await repository.create(colonNoData);
        expect(
          (await storedCore('r-over3'))['sourceUrl'],
          equals('Kopierat från: Tårta med data 3 ägg'),
          reason:
              'a colon alone is harmless — only the literal "data:" matches',
        );
      },
    );

    test('sanitizing does not restamp updatedAt', () async {
      // `Recipe.copyWith` defaults `updatedAt` to `clock.now()`, so cleaning a
      // recipe looked like editing it until `sanitizeRecipeText` passed the
      // field through explicitly. `watchRecipes` and `loadMoreRecipes` order on
      // that field, so a restamp jumps the recipe to the top of the user's list
      // for no reason the user can see. (An earlier version of this comment
      // blamed a last-write-wins reconciliation; a reviewer grepped for one and
      // there is none.)
      //
      // Asserted through `addRecipes`, because that path's only transform is
      // the `toFirestore` chokepoint. NOT through `create`: its normalization
      // branch runs a second `copyWith` without the field, which restamps to
      // now — pre-existing, correct there (a create's edit time IS now), and
      // caught by an earlier draft of this test that pointed at the wrong path.
      final edited = DateTime.utc(2026, 1, 2, 3, 4, 5);
      final recipe = RecipeFactory.build(
        id: 'r-stamp',
        createdBy: uid,
        sourceUrl: 'https://ica.se/a',
      ).copyWith(updatedAt: edited);

      await repository.addRecipes([recipe]);

      final stored = (await storedCore('r-stamp'))['updatedAt'];
      expect(stored, isNotNull, reason: 'premise: the field is written at all');
      final storedTime = stored is Timestamp
          ? stored.toDate().toUtc()
          : DateTime.parse(stored as String).toUtc();
      expect(storedTime, equals(edited));
    });

    test('update keeps sanitizing — the path that was never broken', () async {
      final recipe = RecipeFactory.build(
        id: 'r-upd',
        createdBy: uid,
        sourceUrl: 'https://ica.se/a',
      );
      await repository.create(recipe);

      await repository.update(
        recipe.copyWith(sourceUrl: 'javascript:alert(1)'),
      );

      expect((await storedCore('r-upd'))['sourceUrl'], isEmpty);
    });

    test('createBatch sanitizes — the path no test touched', () async {
      // `addRecipes` has no production caller today, but it is on the
      // `RecipeRepository` interface and bypassed `create` entirely. The
      // chokepoint in `toFirestore` is what covers it.
      await repository.addRecipes([
        RecipeFactory.build(
          id: 'r-b1',
          createdBy: uid,
          sourceUrl: 'javascript:alert(1)',
        ),
      ]);

      expect((await storedCore('r-b1'))['sourceUrl'], isEmpty);
    });
  });
}
