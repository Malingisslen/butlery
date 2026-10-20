// ignore_for_file: subtype_of_sealed_class
// BUT-2294: the comment the upload queue creates once its photos are in
// Storage.

import 'package:butlery/core/exceptions/permission_exceptions.dart';
import 'package:butlery/core/utils/timestamp_provider.dart';
import 'package:butlery/repositories/firebase/firebase_comments_repository.dart';
import 'package:butlery/repositories/interfaces/comments_repository.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../infrastructure/di/test_service_locator.dart';
import '../../infrastructure/mocks/production_mocks.dart';
import '../../test_support/base_unit_test.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  late FakeAuthRepository auth;

  setUpAll(() async {
    await BaseUnitTest.setupUnit();
  });

  setUp(() {
    firestore = FakeFirebaseFirestore();
    auth = FakeAuthRepository()
      ..setAuthState(
        user: FakeUser(uid: 'user-123', displayName: 'Test User'),
        userId: 'user-123',
        isAuthenticated: true,
      );
  });

  tearDown(() async {
    BaseUnitTest.resetMocks();
    await TestServiceLocator.reset();
  });

  FirebaseCommentsRepository repo({
    RecipeOwnershipResolver? ownership,
    RecipeAccessValidator? access,
  }) => FirebaseCommentsRepository(
    firestore: firestore,
    authRepository: auth,
    timestampProvider: const TestTimestampProvider(),
    recipeOwnershipResolver: ownership,
    recipeAccessValidator: access,
  );

  Future<RecipeOwnershipSnapshot?> owner(String recipeId) async =>
      const RecipeOwnershipSnapshot(
        recipeOwnerId: 'owner-1',
        sharedWithUserIds: ['friend-1'],
      );

  group('createQueuedComment', () {
    test('writes the comment under the id the queue fixed, with the burst '
        'stamp naming it and the recipe ownership denormalized', () async {
      final created = await repo(ownership: owner).createQueuedComment(
        commentId: 'queued-1',
        recipeId: 'recipe-1',
        userId: 'user-123',
        content: 'Så gott!',
        imageUrls: const ['https://img/1.jpg'],
      );

      expect(created.id, 'queued-1');
      final doc = await firestore
          .collection('recipe_comments')
          .doc('queued-1')
          .get();
      expect(doc.data()!['imageUrls'], ['https://img/1.jpg']);
      expect(doc.data()!['recipeOwnerId'], 'owner-1');
      expect(doc.data()!['sharedWithUserIds'], ['friend-1']);
      final stamp = await firestore
          .collection('users')
          .doc('user-123')
          .collection('rate_limits')
          .doc('comments')
          .get();
      expect(stamp.data()!['lastDocId'], 'queued-1');
    });

    test('a reply increments the parent\'s replyCount', () async {
      await firestore.collection('recipe_comments').doc('parent-1').set({
        'recipeId': 'recipe-1',
        'authorId': 'someone',
        'replyCount': 0,
      });

      await repo(ownership: owner).createQueuedComment(
        commentId: 'queued-2',
        recipeId: 'recipe-1',
        userId: 'user-123',
        content: 'Samma här',
        parentCommentId: 'parent-1',
      );

      final parent = await firestore
          .collection('recipe_comments')
          .doc('parent-1')
          .get();
      expect(parent.data()!['replyCount'], 1);
    });

    test(
      'an unknown recipe ownership is a retry, not a comment readable by its '
      'author alone: nothing is written',
      () async {
        for (final resolver in <RecipeOwnershipResolver>[
          (id) async => null,
          (id) async => throw StateError('offline'),
        ]) {
          await expectLater(
            repo(ownership: resolver).createQueuedComment(
              commentId: 'queued-3',
              recipeId: 'recipe-1',
              userId: 'user-123',
              content: 'Hej',
            ),
            throwsStateError,
          );
        }

        final written = await firestore.collection('recipe_comments').get();
        expect(written.docs, isEmpty);
      },
    );

    test('the same checks as an online comment: no access, empty text and '
        'too many photos write nothing', () async {
      final denied = repo(access: (recipeId, userId) async => false);
      await expectLater(
        denied.createQueuedComment(
          commentId: 'q',
          recipeId: 'recipe-1',
          userId: 'user-123',
          content: 'Hej',
        ),
        throwsA(isA<PermissionDeniedException>()),
      );
      await expectLater(
        repo().createQueuedComment(
          commentId: 'q',
          recipeId: 'recipe-1',
          userId: 'user-123',
          content: '   ',
        ),
        throwsA(isA<SecurityViolationException>()),
      );
      await expectLater(
        repo().createQueuedComment(
          commentId: 'q',
          recipeId: 'recipe-1',
          userId: 'user-123',
          content: 'Hej',
          imageUrls: const ['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i'],
        ),
        throwsA(isA<SecurityViolationException>()),
      );

      expect(
        (await firestore.collection('recipe_comments').get()).docs,
        isEmpty,
      );
    });
  });

  group('ownCommentExists', () {
    test('is true for the signed-in user\'s comment, false for another '
        'author\'s comment with that id and for a missing one', () async {
      await firestore.collection('recipe_comments').doc('mine').set({
        'authorId': 'user-123',
        'recipeId': 'r',
      });
      await firestore.collection('recipe_comments').doc('theirs').set({
        'authorId': 'someone',
        'recipeId': 'r',
      });

      final repository = repo();

      expect(await repository.ownCommentExists('mine'), isTrue);
      expect(await repository.ownCommentExists('theirs'), isFalse);
      expect(await repository.ownCommentExists('missing'), isFalse);
    });

    test('asks the server, never the cache: a cached answer cannot say the '
        'comment is there', () async {
      final mockFirestore = _MockFirestore();
      final collection = _MockCollection();
      final query = _MockQuery();
      GetOptions? asked;
      when(() => mockFirestore.collection(any())).thenReturn(collection);
      when(
        () => collection.where(any(), isEqualTo: any(named: 'isEqualTo')),
      ).thenReturn(query);
      when(
        () => query.where(any(), isEqualTo: any(named: 'isEqualTo')),
      ).thenReturn(query);
      when(() => query.limit(any())).thenReturn(query);
      when(() => query.get(any())).thenAnswer((invocation) async {
        asked = invocation.positionalArguments.single as GetOptions?;
        return _MockSnapshot();
      });

      await FirebaseCommentsRepository(
        firestore: mockFirestore,
        authRepository: auth,
        timestampProvider: const TestTimestampProvider(),
      ).ownCommentExists('c-1');

      expect(asked?.source, Source.server);
    });
  });
}

class _MockFirestore extends Mock implements FirebaseFirestore {}

class _MockCollection extends Mock
    implements CollectionReference<Map<String, dynamic>> {}

class _MockQuery extends Mock implements Query<Map<String, dynamic>> {}

class _MockSnapshot extends Mock
    implements QuerySnapshot<Map<String, dynamic>> {
  @override
  List<QueryDocumentSnapshot<Map<String, dynamic>>> get docs => const [];
}
