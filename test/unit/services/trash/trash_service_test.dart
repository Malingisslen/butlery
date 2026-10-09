/// BUT-907: restoring from the trash, and what the trash service reports.
///
/// The repository is the real one over a fake Firestore, so a restore really
/// moves the documents; the user counter, the tagger and the device side
/// (cache and list) are recorded at their seams.
library;

import 'package:clock/clock.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/core/constants/firestore_collections.dart';
import 'package:butlery/core/providers/application_provider.dart' as prod;
import 'package:butlery/models/recipe/recipe_serialization.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/tagging/tag_result.dart';
import 'package:butlery/models/trash_item.dart';
import 'package:butlery/repositories/firebase/firebase_trash_repository.dart';
import 'package:butlery/repositories/interfaces/auth_repository.dart';
import 'package:butlery/repositories/interfaces/trash_repository.dart';
import 'package:butlery/services/tagging/tagging_service.dart';
import 'package:butlery/services/trash/trash_restore.dart';
import 'package:butlery/services/trash/trash_service.dart';

import '../../../infrastructure/di/test_service_locator.dart';
import '../../../infrastructure/factories/recipe_factory.dart';
import '../../../infrastructure/mocks/production_mocks.dart';
import '../../../test_support/base_unit_test.dart';

class _MockTagging extends Mock implements TaggingService {}

class _MockRestore extends Mock implements TrashRestore {}

const _me = 'user-me';

void main() {
  late FakeFirebaseFirestore firestore;
  late FirebaseTrashRepository repository;
  late MockUserRepository users;
  late _MockTagging tagging;
  late List<Recipe> adopted;
  late Set<String> unsent;
  late bool online;
  late TrashService service;

  CollectionReference<Map<String, dynamic>> col(String name) => firestore
      .collection(FirestoreCollections.users)
      .doc(_me)
      .collection(name);

  setUpAll(() => registerFallbackValue(RecipeFactory.build()));

  setUp(() async {
    await BaseUnitTest.setupUnitWithProductionLocator();
    final auth = prod.ServiceLocator.get<AuthRepository>() as FakeAuthRepository
      ..setAuthState(
        user: FakeUser(uid: _me),
        userId: _me,
        isAuthenticated: true,
      );
    firestore = FakeFirebaseFirestore();
    repository = FirebaseTrashRepository(
      firestore: firestore,
      authRepository: auth,
    );
    users = MockUserRepository();
    when(
      () => users.incrementPublicRecipeCount(any()),
    ).thenAnswer((_) async {});
    tagging = _MockTagging();
    when(() => tagging.needsRetagging(any())).thenReturn(false);
    adopted = [];
    unsent = {};
    online = true;
    service = TrashService(
      repository: repository,
      restorer: TrashRestore(
        repository: repository,
        userRepository: () => users,
        taggingService: () => tagging,
        hasUnsentWrite: (id, _) async => unsent.contains(id),
        adoptRecipe: (r) async => adopted.add(r),
      ),
      isOnline: () => online,
      currentUserId: () => _me,
    );
  });

  tearDown(() async {
    await TestServiceLocator.reset();
  });

  Future<TrashItem> trashed(String id, {int rev = 2}) async {
    final recipe = RecipeFactory.buildPersonal(
      id: id,
      title: 'Gryta $id',
      createdBy: _me,
    ).copyWith(rev: rev);
    await col(
      FirestoreCollections.recipes,
    ).doc(id).set(RecipeSerialization.toFirestore(recipe));
    await repository.moveRecipeToTrash(recipe);
    return (await repository.listTrash()).singleWhere((i) => i.id == id);
  }

  group('restore', () {
    test('a device-side failure after the server restore still counts as '
        'restored', () async {
      final item = await trashed('r1');
      final failing = TrashService(
        repository: repository,
        restorer: TrashRestore(
          repository: repository,
          userRepository: () => users,
          taggingService: () => tagging,
          hasUnsentWrite: (id, _) async => false,
          adoptRecipe: (_) async => throw StateError('device store closed'),
        ),
        isOnline: () => online,
        currentUserId: () => _me,
      );

      final outcome = await failing.restore([item]);

      expect(outcome.doneIds, ['r1']);
      expect(outcome.failures, isEmpty);
    });

    test('puts the recipe back on the server, the device and the count, '
        'once', () async {
      final item = await trashed('r1');

      final outcome = await service.restore([item]);

      expect(outcome.isComplete, isTrue);
      expect(outcome.doneIds, ['r1']);
      expect(
        (await col(FirestoreCollections.recipes).doc('r1').get()).exists,
        isTrue,
      );
      expect(
        (await col(FirestoreCollections.userTrash).doc('r1').get()).exists,
        isFalse,
      );
      expect(adopted.single.id, 'r1');
      expect(
        adopted.single.rev,
        3,
        reason:
            'the device copy carries the '
            'revision the server now holds, so its next edit compares right',
      );
      verify(() => users.incrementPublicRecipeCount(_me)).called(1);
    });

    test(
      'a second restore of the same item is refused and counts nothing',
      () async {
        final item = await trashed('r1');
        await service.restore([item]);
        clearInteractions(users);

        final again = await service.restore([item]);

        expect(again.failures, {'r1': TrashFailure.gone});
        verifyNever(() => users.incrementPublicRecipeCount(any()));
        expect(adopted, hasLength(1));
      },
    );

    test('an item past its 30 days is refused and nothing moves', () async {
      final item = await trashed('r1');

      final outcome = await withClock(
        Clock.fixed(item.expireAt),
        () => service.restore([item]),
      );

      expect(outcome.failures, {'r1': TrashFailure.expired});
      expect(
        (await col(FirestoreCollections.recipes).doc('r1').get()).exists,
        isFalse,
      );
      expect(adopted, isEmpty);
      verifyNever(() => users.incrementPublicRecipeCount(any()));
    });

    test('offline, nothing is attempted and the outcome says so', () async {
      final item = await trashed('r1');
      online = false;

      final outcome = await service.restore([item]);

      expect(outcome.wasOffline, isTrue);
      expect(outcome.failures, {'r1': TrashFailure.offline});
      expect(
        (await col(FirestoreCollections.userTrash).doc('r1').get()).exists,
        isTrue,
      );
      verifyNever(() => users.incrementPublicRecipeCount(any()));
    });

    test('stale tags are made again, as a save makes them', () async {
      final item = await trashed('r1');
      final fresh = TagResult.failed(reason: 'stand-in for fresh tags');
      when(() => tagging.needsRetagging(any())).thenReturn(true);
      when(() => tagging.generateTags(any())).thenAnswer((_) async => fresh);

      await service.restore([item]);

      verify(() => tagging.generateTags(any())).called(1);
      expect(adopted.single.tagResult?.errorReason, 'stand-in for fresh tags');
    });

    test('a tagging failure is stored as a failed result, and the recipe '
        'still comes back', () async {
      final item = await trashed('r1');
      when(() => tagging.needsRetagging(any())).thenReturn(true);
      when(() => tagging.generateTags(any())).thenAnswer((_) async => null);

      final outcome = await service.restore([item]);

      expect(outcome.isComplete, isTrue);
      expect(
        adopted.single.tagResult?.errorReason,
        'Tagging failed on restore',
      );
    });

    test('in a batch, an item already restored fails as gone and the good '
        'one still comes back', () async {
      final restoredBefore = await trashed('r1');
      await service.restore([restoredBefore]);
      final good = await trashed('r2');

      final outcome = await service.restore([restoredBefore, good]);

      expect(outcome.doneIds, ['r2']);
      expect(outcome.failures, {'r1': TrashFailure.gone});
    });

    test('in a batch, a restore that throws marks only that item and its '
        'neighbours come back', () async {
      final first = await trashed('r1');
      final broken = await trashed('r2');
      final lapsed = await trashed('r3');
      final last = await trashed('r4');
      final real = TrashRestore(
        repository: repository,
        userRepository: () => users,
        taggingService: () => tagging,
        hasUnsentWrite: (_, _) async => false,
        adoptRecipe: (_) async {},
      );
      registerFallbackValue(first);
      final restorer = _MockRestore();
      when(() => restorer.restore(any(), any())).thenAnswer((call) {
        final item = call.positionalArguments[0] as TrashItem;
        if (item.id == 'r2') throw Exception('server refused');
        if (item.id == 'r3') throw const TrashItemExpiredException('r3');
        return real.restore(item, call.positionalArguments[1] as String);
      });
      final batch = TrashService(
        repository: repository,
        restorer: restorer,
        isOnline: () => online,
        currentUserId: () => _me,
      );

      final outcome = await batch.restore([first, broken, lapsed, last]);

      expect(outcome.doneIds, ['r1', 'r4']);
      expect(outcome.failures, {
        'r2': TrashFailure.failed,
        'r3': TrashFailure.expired,
      });
      final live = await col(FirestoreCollections.recipes).get();
      expect(live.docs.map((d) => d.id).toSet(), {'r1', 'r4'});
    });

    test('current tags are kept', () async {
      final item = await trashed('r1');

      await service.restore([item]);

      verifyNever(() => tagging.generateTags(any()));
    });

    test('a device copy with an unsent write is left to the queue', () async {
      final item = await trashed('r1');
      unsent.add('r1');

      final outcome = await service.restore([item]);

      expect(outcome.isComplete, isTrue);
      expect(adopted, isEmpty);
    });

    test('a counter failure does not undo the restore', () async {
      final item = await trashed('r1');
      when(
        () => users.incrementPublicRecipeCount(any()),
      ).thenThrow(Exception('counter down'));

      final outcome = await service.restore([item]);

      expect(outcome.isComplete, isTrue);
      expect(adopted.single.id, 'r1');
    });
  });

  group('the list', () {
    test('drops an item the moment its 30 days pass', () async {
      final item = await trashed('r1');

      final shown = await withClock(
        Clock.fixed(item.expireAt),
        () => service.watchTrash().first,
      );
      final before = await withClock(
        Clock.fixed(item.expireAt.subtract(const Duration(seconds: 1))),
        () => service.watchTrash().first,
      );

      expect(shown, isEmpty);
      expect(before.single.id, 'r1');
    });
  });

  group('delete for good', () {
    test('deleteForever removes only the rows it is given', () async {
      await trashed('r1');
      await trashed('r2');
      await trashed('r3');

      final outcome = await service.deleteForever(['r1']);

      expect(outcome.doneIds, ['r1']);
      final left = (await col(FirestoreCollections.userTrash).get()).docs;
      expect(left.map((d) => d.id), unorderedEquals(['r2', 'r3']));
    });

    test('emptyTrash leaves the trash empty', () async {
      await trashed('r1');
      await trashed('r2');

      final outcome = await service.emptyTrash();

      expect(outcome.isComplete, isTrue);
      expect((await col(FirestoreCollections.userTrash).get()).docs, isEmpty);
    });

    test('offline, nothing is deleted', () async {
      await trashed('r1');
      online = false;

      expect((await service.emptyTrash()).wasOffline, isTrue);
      expect((await service.deleteForever(['r1'])).wasOffline, isTrue);
      expect(
        (await col(FirestoreCollections.userTrash).get()).docs,
        hasLength(1),
      );
    });
  });
}
