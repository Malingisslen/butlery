// A cookbook's own cover photo goes with the cookbook (BUT-2378): deleting a
// tag, bulk-deleting tags and merging a cookbook into another one remove the
// file from Storage; a merge that hands the cookbook to the target keeps it.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/models/tagging/cookbook_details.dart';
import 'package:butlery/models/tagging/personal_tag.dart';
import 'package:butlery/repositories/firebase/firebase_personal_tag_group_repository.dart';
import 'package:butlery/repositories/firebase/firebase_personal_tag_repository.dart';
import 'package:butlery/repositories/firebase/firebase_recipe_repository.dart';
import 'package:butlery/repositories/interfaces/auth_repository.dart';
import 'package:butlery/services/storage_service.dart';
import 'package:butlery/services/tagging/personal_tag_crud_service.dart';

import '../../../test_support/cookbook_fixtures.dart';

class _MockTagRepository extends Mock
    implements FirebasePersonalTagRepository {}

class _MockGroupRepository extends Mock
    implements FirebasePersonalTagGroupRepository {}

class _MockAuth extends Mock implements AuthRepository {}

class _MockRecipeRepository extends Mock implements FirebaseRecipeRepository {}

class _MockStorage extends Mock implements StorageService {}

// ignore: subtype_of_sealed_class
class _MockWriteBatch extends Mock implements WriteBatch {}

const _photoUrl = 'https://storage.example/users/u1/cover-a.jpg';
const _otherPhotoUrl = 'https://storage.example/users/u1/cover-b.jpg';
const _keptPhotoUrl = 'https://storage.example/users/u1/keep.jpg';

CookbookDetails _book(String? photoUrl) => CookbookDetails(
  cover: photoUrl == null
      ? const CookbookCover(kind: CookbookCoverKind.color, colorKey: 'blue')
      : CookbookCover(kind: CookbookCoverKind.photo, imageUrl: photoUrl),
);

void main() {
  late _MockTagRepository tags;
  late _MockStorage storage;
  late _MockWriteBatch batch;
  late PersonalTagCrudService service;

  setUpAll(() {
    registerFallbackValue(_MockWriteBatch());
  });

  setUp(() async {
    tags = _MockTagRepository();
    storage = _MockStorage();
    batch = _MockWriteBatch();
    final auth = _MockAuth();
    final recipes = _MockRecipeRepository();

    final getIt = GetIt.instance;
    await getIt.reset();
    getIt.registerSingleton<AuthRepository>(auth);
    ServiceLocator.initialize(DIContainer());
    when(() => auth.currentUserId).thenReturn('u1');

    when(() => tags.newWriteBatch()).thenReturn(batch);
    when(() => batch.commit()).thenAnswer((_) async {});
    when(() => tags.addDeleteToBatch(any(), any())).thenReturn(null);
    when(() => tags.updateCookbook(any(), any())).thenAnswer((_) async {});
    when(
      () => recipes.removePersonalTagFromRecipes(any()),
    ).thenAnswer((_) async => 0);
    when(
      () => recipes.addRemovePersonalTagFromRecipesToBatch(any(), any()),
    ).thenAnswer((_) async => 0);
    when(
      () => recipes.replaceTagInRecipes(any(), any(), any()),
    ).thenAnswer((_) async => 1);
    when(() => storage.deleteImage(any())).thenAnswer((_) async => true);

    service = PersonalTagCrudService(
      tagRepository: tags,
      groupRepository: _MockGroupRepository(),
      getRecipeRepository: () => recipes,
      storageService: storage,
    );
  });

  tearDown(() async {
    await service.dispose();
    await GetIt.instance.reset();
  });

  PersonalTag book(String id, String? photoUrl) =>
      cookbookTag(id: id, name: id, cookbook: _book(photoUrl));

  group('deleteTag', () {
    test('deletes the cover photo after the tag is gone', () async {
      final calls = <String>[];
      when(() => tags.read('a')).thenAnswer((_) async => book('a', _photoUrl));
      when(() => batch.commit()).thenAnswer((_) async => calls.add('write'));
      when(() => storage.deleteImage(_photoUrl)).thenAnswer((_) async {
        calls.add('delete-photo');
        return true;
      });

      await service.deleteTag('a');

      expect(calls, ['write', 'delete-photo']);
    });

    test('leaves Storage alone for a cookbook without a photo cover', () async {
      when(() => tags.read('a')).thenAnswer((_) async => book('a', null));

      await service.deleteTag('a');

      verify(() => batch.commit()).called(1);
      verifyNever(() => storage.deleteImage(any()));
    });

    test('leaves Storage alone for a plain tag', () async {
      when(() => tags.read('a')).thenAnswer((_) async => cookbookTag(id: 'a'));

      await service.deleteTag('a');

      verifyNever(() => storage.deleteImage(any()));
    });

    test('keeps the photo when the tag delete fails', () async {
      when(() => tags.read('a')).thenAnswer((_) async => book('a', _photoUrl));
      when(() => batch.commit()).thenThrow(Exception('unavailable'));

      await service.deleteTag('a');

      verifyNever(() => storage.deleteImage(any()));
    });

    test('still deletes the tag when its cookbook cannot be read', () async {
      when(() => tags.read('a')).thenThrow(Exception('unavailable'));

      await service.deleteTag('a');

      verify(() => batch.commit()).called(1);
      verifyNever(() => storage.deleteImage(any()));
    });

    test('a failed photo delete does not undo the tag delete', () async {
      when(() => tags.read('a')).thenAnswer((_) async => book('a', _photoUrl));
      when(() => storage.deleteImage(any())).thenThrow(Exception('offline'));

      await service.deleteTag('a');

      verify(() => batch.commit()).called(1);
    });
  });

  group('bulkDeleteTags', () {
    test('deletes the photos of the cookbooks that went', () async {
      when(() => tags.getAllSorted()).thenAnswer(
        (_) async => [
          book('a', _photoUrl),
          book('b', _otherPhotoUrl),
          book('c', null),
          book('keep', _keptPhotoUrl),
        ],
      );

      final result = await service.bulkDeleteTags(['a', 'b', 'c']);

      expect(result.isComplete, isTrue);
      verify(() => storage.deleteImage(_photoUrl)).called(1);
      verify(() => storage.deleteImage(_otherPhotoUrl)).called(1);
      verifyNever(() => storage.deleteImage(_keptPhotoUrl));
    });

    test('still deletes the tags when the cookbooks cannot be read', () async {
      when(() => tags.getAllSorted()).thenThrow(Exception('unavailable'));

      final result = await service.bulkDeleteTags(['a']);

      expect(result.isComplete, isTrue);
      verifyNever(() => storage.deleteImage(any()));
    });

    test('does not take the cookbooks from the tag cache', () async {
      when(
        () => tags.getAllSorted(),
      ).thenAnswer((_) async => [book('a', _photoUrl)]);

      await service.getAllTags();
      when(
        () => tags.getAllSorted(),
      ).thenAnswer((_) async => [book('a', _otherPhotoUrl)]);
      await service.bulkDeleteTags(['a']);

      verify(() => storage.deleteImage(_otherPhotoUrl)).called(1);
      verifyNever(() => storage.deleteImage(_photoUrl));
    });

    test('keeps the photos of a chunk that failed', () async {
      when(
        () => tags.getAllSorted(),
      ).thenAnswer((_) async => [book('a', _photoUrl)]);
      when(() => batch.commit()).thenThrow(Exception('unavailable'));

      final result = await service.bulkDeleteTags(['a']);

      expect(result.failedIds, ['a']);
      verifyNever(() => storage.deleteImage(any()));
    });
  });

  group('mergeTags', () {
    void stubTags({
      required CookbookDetails? source,
      required CookbookDetails? target,
    }) {
      when(
        () => tags.read('from'),
      ).thenAnswer((_) async => cookbookTag(id: 'from', cookbook: source));
      when(
        () => tags.read('to'),
      ).thenAnswer((_) async => cookbookTag(id: 'to', cookbook: target));
    }

    test('deletes the photo of a cookbook the target did not take', () async {
      stubTags(source: _book(_photoUrl), target: _book(null));

      await service.mergeTags('from', 'to');

      verify(() => storage.deleteImage(_photoUrl)).called(1);
      verifyNever(() => tags.updateCookbook(any(), any()));
    });

    test('keeps the photo of a cookbook that moved to the target', () async {
      stubTags(source: _book(_photoUrl), target: null);

      await service.mergeTags('from', 'to');

      verify(() => tags.updateCookbook('to', any())).called(1);
      verifyNever(() => storage.deleteImage(any()));
    });

    test('keeps the photo when the source delete fails', () async {
      stubTags(source: _book(_photoUrl), target: _book(null));
      when(() => batch.commit()).thenThrow(Exception('unavailable'));

      await service.mergeTags('from', 'to');

      verifyNever(() => storage.deleteImage(any()));
    });
  });
}
