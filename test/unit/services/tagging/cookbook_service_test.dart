import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/tagging/cookbook_details.dart';
import 'package:butlery/repositories/interfaces/auth_repository.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/services/storage_service.dart';
import 'package:butlery/services/tagging/cookbook_service.dart';
import 'package:butlery/services/tagging/personal_tag_service.dart';
import 'package:butlery/services/unified/unified_recipe_service.dart';
import 'package:butlery/services/upload/image_upload_service.dart';
import 'package:butlery/services/upload/upload_models.dart';

import '../../../infrastructure/mocks/production_mocks.dart';
import '../../../test_support/base_unit_test.dart';
import '../../../test_support/cookbook_fixtures.dart';

class _MockTagService extends Mock implements PersonalTagService {}

class _MockRecipeService extends Mock implements UnifiedRecipeService {}

class _MockStorage extends Mock implements StorageService {}

class _MockPermissions extends Mock implements PermissionService {}

class _MockUploads extends Mock implements ImageUploadService {}

void main() {
  late _MockTagService tags;
  late _MockRecipeService recipes;
  late _MockStorage storage;
  late _MockPermissions permissions;
  late _MockUploads uploads;
  late CookbookService service;

  setUpAll(() {
    registerFallbackValue(cookbookRecipe('fallback', 'Fallback'));
    registerFallbackValue(Uint8List(0));
  });

  setUp(() async {
    // executeServiceOperation reads AuthRepository from the production
    // locator; without a signed-in user the closures never run.
    await BaseUnitTest.setupUnitWithProductionLocator();
    (ServiceLocator.get<AuthRepository>() as FakeAuthRepository).setAuthState(
      userId: 'u1',
    );
    tags = _MockTagService();
    recipes = _MockRecipeService();
    storage = _MockStorage();
    permissions = _MockPermissions();
    uploads = _MockUploads();
    when(() => tags.updateCookbook(any(), any())).thenAnswer((_) async => true);
    when(() => recipes.updateRecipe(any())).thenAnswer((_) async => true);
    when(() => storage.deleteImage(any())).thenAnswer((_) async => true);
    service = CookbookService(
      tagService: tags,
      recipeService: recipes,
      storageService: storage,
      uploadService: uploads,
      permissionService: permissions,
    );
  });

  tearDown(() async {
    BaseUnitTest.resetMocks();
    await BaseUnitTest.teardownUnit();
  });

  List<Recipe> writtenRecipes() =>
      verify(() => recipes.updateRecipe(captureAny())).captured.cast<Recipe>();

  group('addRecipes', () {
    test(
      'skips recipes that already carry the tag and tags the others',
      () async {
        final tag = cookbookTag(cookbook: const CookbookDetails());
        final already = cookbookRecipe('r1', 'Redan', tagIds: ['book']);
        final fresh = cookbookRecipe('r2', 'Ny');

        final added = await service.addRecipes(tag, [already, fresh]);

        expect(added, 1);
        expect(writtenRecipes().map((r) => r.id), ['r2']);
      },
    );

    test(
      'writes both the id and a manual rich entry, keeping the recipe\'s other tags',
      () async {
        final tag = cookbookTag(
          name: 'Mormors favoriter',
          cookbook: const CookbookDetails(),
        );
        final recipe = cookbookRecipe('r2', 'Ny', tagIds: ['other']);

        await service.addRecipes(tag, [recipe]);

        final written = writtenRecipes().single;
        expect(written.core.personalTagIds, ['other', 'book']);
        final rich = written.core.personalTags!;
        expect(rich.map((t) => t.tagId), ['other', 'book']);
        final added = rich.last;
        expect(added.name, 'Mormors favoriter');
        expect(added.sources, ['manual']);
      },
    );

    test('a book with its own order gets only the recipes that were actually '
        'tagged appended, last', () async {
      final tag = cookbookTag(
        cookbook: const CookbookDetails(recipeOrder: ['r9']),
      );
      final ok = cookbookRecipe('r2', 'Ny');
      final refused = cookbookRecipe('r3', 'Nekad');
      final ok2 = cookbookRecipe('r4', 'Ny två');
      when(() => recipes.updateRecipe(any())).thenAnswer(
        (inv) async => (inv.positionalArguments.first as Recipe).id != 'r3',
      );

      final added = await service.addRecipes(tag, [ok, refused, ok2]);

      expect(added, 2);
      final saved =
          verify(
                () => tags.updateCookbook('book', captureAny()),
              ).captured.single
              as CookbookDetails;
      expect(saved.recipeOrder, ['r9', 'r2', 'r4']);
    });

    test('an A–Ö book is not given an order by adding recipes', () async {
      final tag = cookbookTag(cookbook: const CookbookDetails());

      final added = await service.addRecipes(tag, [
        cookbookRecipe('r2', 'Ny'),
      ]);

      expect(added, 1);
      verify(() => recipes.updateRecipe(any())).called(1);
      verifyNever(() => tags.updateCookbook(any(), any()));
    });

    test(
      'nothing tagged means no order write even with an own order',
      () async {
        final tag = cookbookTag(
          cookbook: const CookbookDetails(recipeOrder: ['r1']),
        );

        final added = await service.addRecipes(tag, [
          cookbookRecipe('r1', 'Redan', tagIds: ['book']),
        ]);

        expect(added, 0);
        verifyNever(() => tags.updateCookbook(any(), any()));
      },
    );

    test('returns null when the order cannot be saved, '
        'but the recipes were tagged', () async {
      final tag = cookbookTag(
        cookbook: const CookbookDetails(recipeOrder: ['r9']),
      );
      when(
        () => tags.updateCookbook(any(), any()),
      ).thenAnswer((_) async => false);

      final added = await service.addRecipes(tag, [
        cookbookRecipe('r2', 'Ny'),
      ]);

      expect(added, isNull);
      expect(writtenRecipes().single.id, 'r2');
    });

    test('a tag that is not a cookbook is left alone', () async {
      final added = await service.addRecipes(cookbookTag(), [
        cookbookRecipe('r2', 'Ny'),
      ]);

      expect(added, isNull);
      verifyNever(() => recipes.updateRecipe(any()));
    });
  });

  group('save', () {
    test('refuses a 301-character description without writing', () async {
      final tag = cookbookTag(cookbook: const CookbookDetails());

      final saved = await service.save(
        tag,
        CookbookDetails(description: 'x' * 301),
      );

      expect(saved, isFalse);
      verifyNever(() => tags.updateCookbook(any(), any()));
    });

    test('writes a 300-character description', () async {
      final tag = cookbookTag(cookbook: const CookbookDetails());
      final details = CookbookDetails(description: 'x' * 300);

      final saved = await service.save(tag, details);

      expect(saved, isTrue);
      verify(() => tags.updateCookbook('book', details)).called(1);
    });
  });

  group('save bounds', () {
    Future<bool> saveDetails(CookbookDetails details) =>
        service.save(cookbookTag(cookbook: const CookbookDetails()), details);

    List<String> ids(int n) => [for (var i = 0; i < n; i++) 'r$i'];

    test('a book may have its own order of 1000 recipes, not 1001', () async {
      expect(
        await saveDetails(CookbookDetails(recipeOrder: ids(1000))),
        isTrue,
      );
      verify(() => tags.updateCookbook('book', any())).called(1);

      expect(
        await saveDetails(CookbookDetails(recipeOrder: ids(1001))),
        isFalse,
      );
      verifyNever(() => tags.updateCookbook('book', any()));
    });

    test('a note may be 300 characters, not 301, and the book is not '
        'written when one is too long', () async {
      expect(
        await saveDetails(CookbookDetails(recipeNotes: {'r1': 'x' * 300})),
        isTrue,
      );
      clearInteractions(tags);

      expect(
        await saveDetails(
          CookbookDetails(
            recipeNotes: {'r1': 'kort', 'r2': 'x' * 301},
          ),
        ),
        isFalse,
      );
      verifyNever(() => tags.updateCookbook(any(), any()));
    });

    test('a book may carry 1000 notes, not 1001', () async {
      Map<String, String> notes(int n) => {
        for (var i = 0; i < n; i++) 'r$i': 'anteckning',
      };

      expect(
        await saveDetails(CookbookDetails(recipeNotes: notes(1000))),
        isTrue,
      );
      clearInteractions(tags);

      expect(
        await saveDetails(CookbookDetails(recipeNotes: notes(1001))),
        isFalse,
      );
      verifyNever(() => tags.updateCookbook(any(), any()));
    });
  });

  group('uploadCoverPhoto', () {
    final bytes = Uint8List.fromList([1, 2, 3]);

    test('with nobody signed in, returns null and uploads nothing', () async {
      when(() => permissions.currentUserId).thenReturn(null);

      final url = await service.uploadCoverPhoto(bytes, 'cover.jpg');

      expect(url, isNull);
      verifyNever(
        () => uploads.uploadImageFromBytes(
          bytes: any(named: 'bytes'),
          userId: any(named: 'userId'),
          fileName: any(named: 'fileName'),
          prefix: any(named: 'prefix'),
        ),
      );
    });

    test('a failed upload gives null, not an error', () async {
      when(() => permissions.currentUserId).thenReturn('u1');
      when(
        () => uploads.uploadImageFromBytes(
          bytes: any(named: 'bytes'),
          userId: any(named: 'userId'),
          fileName: any(named: 'fileName'),
          prefix: any(named: 'prefix'),
        ),
      ).thenAnswer(
        (_) async =>
            UploadResult.failure('offline', ImageUploadErrorType.network),
      );

      expect(await service.uploadCoverPhoto(bytes, 'cover.jpg'), isNull);
    });

    test('returns the URL and uploads under the signed-in user', () async {
      when(() => permissions.currentUserId).thenReturn('u1');
      when(
        () => uploads.uploadImageFromBytes(
          bytes: any(named: 'bytes'),
          userId: any(named: 'userId'),
          fileName: any(named: 'fileName'),
          prefix: any(named: 'prefix'),
        ),
      ).thenAnswer((_) async => UploadResult.success('https://img/cover.jpg'));

      final url = await service.uploadCoverPhoto(bytes, 'cover.jpg');

      expect(url, 'https://img/cover.jpg');
      verify(
        () => uploads.uploadImageFromBytes(
          bytes: bytes,
          userId: 'u1',
          fileName: 'cover.jpg',
          prefix: any(named: 'prefix'),
        ),
      ).called(1);
    });
  });

  group('own-photo cover cleanup', () {
    const oldPhoto = CookbookCover(
      kind: CookbookCoverKind.photo,
      imageUrl: 'https://img/old.jpg',
    );

    test('replacing the own photo deletes the old file', () async {
      final tag = cookbookTag(cookbook: const CookbookDetails(cover: oldPhoto));

      await service.save(
        tag,
        const CookbookDetails(
          cover: CookbookCover(
            kind: CookbookCoverKind.photo,
            imageUrl: 'https://img/new.jpg',
          ),
        ),
      );

      verify(() => storage.deleteImage('https://img/old.jpg')).called(1);
      verifyNever(() => storage.deleteImage('https://img/new.jpg'));
    });

    test('switching the cover away from the photo deletes it', () async {
      final tag = cookbookTag(cookbook: const CookbookDetails(cover: oldPhoto));

      await service.save(tag, const CookbookDetails());

      verify(() => storage.deleteImage('https://img/old.jpg')).called(1);
    });

    test(
      'keeping the same photo while editing the text deletes nothing',
      () async {
        final tag = cookbookTag(
          cookbook: const CookbookDetails(cover: oldPhoto),
        );

        final saved = await service.save(
          tag,
          const CookbookDetails(description: 'Ny text', cover: oldPhoto),
        );

        expect(saved, isTrue);
        verifyNever(() => storage.deleteImage(any()));
      },
    );

    test('switching from a colour cover deletes nothing', () async {
      final tag = cookbookTag(cookbook: const CookbookDetails());

      await service.save(
        tag,
        const CookbookDetails(
          cover: CookbookCover(
            kind: CookbookCoverKind.photo,
            imageUrl: 'https://img/new.jpg',
          ),
        ),
      );

      verifyNever(() => storage.deleteImage(any()));
    });

    test('a failed save keeps the old file', () async {
      final tag = cookbookTag(cookbook: const CookbookDetails(cover: oldPhoto));
      when(
        () => tags.updateCookbook(any(), any()),
      ).thenAnswer((_) async => false);

      final saved = await service.save(tag, const CookbookDetails());

      expect(saved, isFalse);
      verifyNever(() => storage.deleteImage(any()));
    });
  });

  group('remove', () {
    test('writes null so the tag stops being a cookbook', () async {
      final tag = cookbookTag(cookbook: const CookbookDetails());

      final removed = await service.remove(tag);

      expect(removed, isTrue);
      verify(() => tags.updateCookbook('book', null)).called(1);
      verifyNever(() => storage.deleteImage(any()));
    });

    test('also deletes an own cover photo', () async {
      final tag = cookbookTag(
        cookbook: const CookbookDetails(
          cover: CookbookCover(
            kind: CookbookCoverKind.photo,
            imageUrl: 'https://img/old.jpg',
          ),
        ),
      );

      await service.remove(tag);

      verify(() => storage.deleteImage('https://img/old.jpg')).called(1);
    });
  });
}
