/// BUT-2082: the title lookup behind the comments and ratings sections.
// The recording doubles stand in for sealed Firestore types.
// ignore_for_file: subtype_of_sealed_class
library;

import 'package:butlery/core/constants/firestore_collections.dart';
import 'package:butlery/repositories/firebase/firebase_data_export_repository.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../infrastructure/di/test_service_locator.dart';
import '../../../infrastructure/mocks/production_mocks.dart';
import '../../../test_support/base_unit_test.dart';

/// Throws [error] for every recipe read, standing in for the rules and the
/// network, which the fake Firestore does not have.
class _RefusingRepository extends FirebaseDataExportRepository {
  _RefusingRepository(
    this.error, {
    required super.firestore,
    required super.authRepository,
  });
  final Object error;

  @override
  Future<Map<String, dynamic>?> readRecipeForTitle(
    String ownerId,
    String recipeId,
  ) async => throw error;
}

/// Records the options of every document read, which the fake Firestore
/// accepts and ignores.
class _RecordingFirestore extends Fake implements FirebaseFirestore {
  final reads = <GetOptions?>[];

  @override
  CollectionReference<Map<String, dynamic>> collection(String path) =>
      _RecordingCollection(this);
}

class _RecordingCollection extends Fake
    implements CollectionReference<Map<String, dynamic>> {
  _RecordingCollection(this.db);
  final _RecordingFirestore db;

  @override
  DocumentReference<Map<String, dynamic>> doc([String? path]) =>
      _RecordingDocument(db);
}

class _RecordingDocument extends Fake
    implements DocumentReference<Map<String, dynamic>> {
  _RecordingDocument(this.db);
  final _RecordingFirestore db;

  @override
  CollectionReference<Map<String, dynamic>> collection(String path) =>
      _RecordingCollection(db);

  @override
  Future<DocumentSnapshot<Map<String, dynamic>>> get([
    GetOptions? options,
  ]) async {
    db.reads.add(options);
    return _Snapshot();
  }
}

class _Snapshot extends Fake implements DocumentSnapshot<Map<String, dynamic>> {
  @override
  Map<String, dynamic>? data() => {
    'core': {'title': 'Kladdkaka'},
  };
}

/// Counts recipe reads, to show a refused caller reads nothing.
class _CountingRepository extends FirebaseDataExportRepository {
  _CountingRepository({
    required super.firestore,
    required super.authRepository,
  });
  int reads = 0;

  @override
  Future<Map<String, dynamic>?> readRecipeForTitle(
    String ownerId,
    String recipeId,
  ) async {
    reads++;
    return null;
  }
}

void main() {
  group('FirebaseDataExportRepository.exportRecipeTitles (BUT-2082)', () {
    late FirebaseDataExportRepository repository;
    late FakeFirebaseFirestore firestore;

    const userId = 'user-abc';

    setUpAll(() async {
      await BaseUnitTest.setupUnit();
    });

    setUp(() {
      firestore = FakeFirebaseFirestore();
      final auth = FakeAuthRepository();
      auth.setAuthState(
        user: FakeUser(uid: userId),
        userId: userId,
        isAuthenticated: true,
      );
      repository = FirebaseDataExportRepository(
        firestore: firestore,
        authRepository: auth,
      );
    });

    tearDown(() async {
      BaseUnitTest.resetMocks();
      await TestServiceLocator.reset();
    });

    Future<void> seedRecipe(
      String ownerId,
      String recipeId,
      Map<String, dynamic> data,
    ) => firestore
        .collection(FirestoreCollections.users)
        .doc(ownerId)
        .collection(FirestoreCollections.userRecipes)
        .doc(recipeId)
        .set(data);

    test(
      'reads the nested title, and the flat one on older documents',
      () async {
        await seedRecipe('owner-1', 'r-nested', {
          'core': {'title': 'Kladdkaka'},
        });
        await seedRecipe('owner-2', 'r-flat', {'title': 'Pannkakor'});

        final result = await repository.exportRecipeTitles(userId, const [
          (ownerId: 'owner-1', recipeId: 'r-nested'),
          (ownerId: 'owner-2', recipeId: 'r-flat'),
        ]);

        expect(result.titles, {
          'owner-1/r-nested': 'Kladdkaka',
          'owner-2/r-flat': 'Pannkakor',
        });
        expect(result.failed, isFalse);
      },
    );

    test('a missing recipe gives no title and is not a failure', () async {
      final result = await repository.exportRecipeTitles(userId, const [
        (ownerId: 'owner-1', recipeId: 'gone'),
      ]);

      expect(result.titles, isEmpty);
      expect(result.failed, isFalse);
    });

    test('an id that is not one path segment is never read', () async {
      // A forged `recipeId` with a slash would otherwise address a document
      // below the recipe and export one of its fields as a title.
      final auth = FakeAuthRepository();
      auth.setAuthState(
        user: FakeUser(uid: userId),
        userId: userId,
        isAuthenticated: true,
      );
      final repo = _CountingRepository(
        firestore: firestore,
        authRepository: auth,
      );

      await repo.exportRecipeTitles(userId, const [
        (ownerId: 'owner-1', recipeId: 'r1/notes/n1'),
        (ownerId: '', recipeId: 'r1'),
        (ownerId: 'owner-1', recipeId: '.'),
        (ownerId: 'owner-1', recipeId: '..'),
        (ownerId: 'owner-1', recipeId: '__name__'),
      ]);
      expect(repo.reads, 0);

      // Control: the counter does see a valid id.
      await repo.exportRecipeTitles(userId, const [
        (ownerId: 'owner-1', recipeId: 'r1'),
      ]);
      expect(repo.reads, 1);
    });

    test('the read goes to the server, never the cache', () async {
      // A cached copy could hold a recipe the owner has since unshared, and
      // then the rules would not decide.
      final db = _RecordingFirestore();
      final auth = FakeAuthRepository();
      auth.setAuthState(
        user: FakeUser(uid: userId),
        userId: userId,
        isAuthenticated: true,
      );
      final result =
          await FirebaseDataExportRepository(
            firestore: db,
            authRepository: auth,
          ).exportRecipeTitles(userId, const [
            (ownerId: 'owner-1', recipeId: 'r1'),
          ]);

      expect(result.titles, {'owner-1/r1': 'Kladdkaka'});
      expect(db.reads.single?.source, Source.server);
    });

    test('another person\'s export is refused before any read', () async {
      final auth = FakeAuthRepository();
      auth.setAuthState(
        user: FakeUser(uid: userId),
        userId: userId,
        isAuthenticated: true,
      );
      final repo = _CountingRepository(
        firestore: firestore,
        authRepository: auth,
      );

      await expectLater(
        repo.exportRecipeTitles('someone-else', const [
          (ownerId: 'owner-1', recipeId: 'r1'),
        ]),
        throwsA(anything),
      );
      expect(repo.reads, 0);
    });

    group('a refused or failed read', () {
      Future<({Map<String, String> titles, bool failed})> lookUp(Object error) {
        final auth = FakeAuthRepository();
        auth.setAuthState(
          user: FakeUser(uid: userId),
          userId: userId,
          isAuthenticated: true,
        );
        return _RefusingRepository(
          error,
          firestore: firestore,
          authRepository: auth,
        ).exportRecipeTitles(userId, const [
          (ownerId: 'owner-1', recipeId: 'r1'),
        ]);
      }

      // A refusal is a fact about the recipe's owner (unshared, blocked,
      // deleted), so it must look exactly like a recipe with no title.
      for (final code in ['permission-denied', 'not-found']) {
        test('$code gives no title and no failure', () async {
          final result = await lookUp(
            FirebaseException(plugin: 'cloud_firestore', code: code),
          );
          expect(result.titles, isEmpty);
          expect(result.failed, isFalse);
        });
      }

      test('any other Firestore error is our failure', () async {
        final result = await lookUp(
          FirebaseException(plugin: 'cloud_firestore', code: 'unavailable'),
        );
        expect(result.titles, isEmpty);
        expect(result.failed, isTrue);
      });

      test('a non-Firestore error is our failure too', () async {
        final result = await lookUp(StateError('boom'));
        expect(result.failed, isTrue);
      });
    });
  });
}
