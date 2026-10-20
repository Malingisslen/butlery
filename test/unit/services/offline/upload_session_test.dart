// BUT-2294: a queued upload is sent on a fresh sign-in, for the account that
// queued it. These tests drive the processor with a session check of their
// own, then the real check with a fake sign-in.

import 'dart:io';

import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/exceptions/permission_exceptions.dart';
import 'package:butlery/core/providers/application_provider.dart' as production;
import 'package:butlery/core/storage/drift/app_database.dart';
import 'package:butlery/repositories/interfaces/auth_repository.dart';
import 'package:butlery/services/offline/offline_purge_store.dart';
import 'package:butlery/services/offline/offline_user_storage.dart';
import 'package:butlery/services/offline/upload_completion.dart';
import 'package:butlery/services/offline/upload_queue_processor.dart';
import 'package:butlery/services/offline/upload_queue_wiring.dart';
import 'package:clock/clock.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../infrastructure/di/test_service_locator.dart';
import '../../../test_support/base_unit_test.dart';
import 'queue_harness.dart' show MidRandom;

class _MockAuth extends Mock implements AuthRepository {}

class _MockUser extends Mock implements User {}

class _Boom implements UploadCompletion {
  @override
  Future<CompletionOutcome> complete(UploadQueueEntry row, String userId) =>
      throw StateError('network');
}

class _StorageThatCannotClear extends Fake implements OfflineUserStorage {
  @override
  Future<void> clearUserData(String userId) async =>
      throw const FileSystemException('disk');
}

void main() {
  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    production.ServiceLocator.initialize(DIContainer());
  });

  const uid = 'u1';
  final t0 = DateTime(2026, 10, 20, 12);

  late AppDatabase db;
  late Directory root;
  late OfflineUserStorage storage;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    root = await Directory.systemTemp.createTemp('upload_session');
    storage = OfflineUserStorage(database: db, uploadsRoot: () async => root);
  });

  tearDown(() async {
    await db.close();
    await root.delete(recursive: true);
  });

  Future<void> queue(String id) => db.uploadQueueDao.queueUpload(
    id: id,
    userId: uid,
    localPath: '/device/$id.jpg',
    targetPath: 'users/$uid/recipes/$id.jpg',
    fileSizeBytes: 10,
  );

  group('the processor', () {
    late List<String> events;
    late Object? uploadFails;

    UploadQueueProcessor build({
      Future<void> Function(String userId)? ensureSession,
      Map<String, UploadCompletion> completions = const {},
    }) {
      return UploadQueueProcessor(
        database: db,
        storage: storage,
        upload: (String localPath, String userId, String objectId) async {
          events.add('upload:$objectId');
          final failure = uploadFails;
          if (failure != null) throw failure;
          return (url: 'https://img/$objectId.jpg', thumbnailUrl: null);
        },
        ensureSession: ensureSession,
        completions: completions,
        random: MidRandom(),
      );
    }

    Future<int> pass(
      UploadQueueProcessor processor, {
      bool Function()? isCurrentUser,
    }) => withClock(
      Clock.fixed(t0),
      () => processor.runPass(
        uid,
        now: t0,
        isCurrentUser: isCurrentUser ?? () => true,
        force: true,
      ),
    );

    setUp(() {
      events = [];
      uploadFails = null;
    });

    test('refreshes the session before each row goes up', () async {
      await queue('a');
      await queue('b');

      await pass(
        build(
          ensureSession: (userId) async {
            events.add('session:$userId');
          },
        ),
      );

      expect(events, ['session:u1', 'upload:a', 'session:u1', 'upload:b']);
    });

    test('an account that can no longer write stops the pass before any '
        'upload', () async {
      await queue('a');
      await queue('b');

      var checks = 0;
      final sent = await pass(
        build(
          ensureSession: (_) async {
            checks++;
            throw const SessionEnded();
          },
        ),
      );

      expect(sent, 0);
      expect(events, isEmpty);
      expect(checks, 1, reason: 'the pass stops; it does not ask per row');
      expect((await db.uploadQueueDao.getUpload('a'))!.status, 'pending');
    });

    test(
      'nothing goes up when the account changed during the refresh',
      () async {
        await queue('a');
        var current = true;

        await pass(
          build(ensureSession: (_) async => current = false),
          isCurrentUser: () => current,
        );

        expect(events, isEmpty);
      },
    );

    test('a failed use of the image after the account changed does not count '
        'against the row', () async {
      await db.uploadQueueDao.queueUpload(
        id: 'a',
        userId: uid,
        localPath: '/device/a.jpg',
        targetPath: 'users/$uid/recipes/a.jpg',
        fileSizeBytes: 10,
        entityId: 'snap-1',
        entityType: 'cook_snap',
      );

      await pass(
        build(completions: {'cook_snap': _Boom()}),
        isCurrentUser: () => !events.contains('upload:a'),
      );

      final row = (await db.uploadQueueDao.getUpload('a'))!;
      expect(row.status, 'uploaded');
      expect(row.retryCount, 0);
    });

    test('a refusal that comes after the account changed does not count '
        'against the row', () async {
      await queue('a');
      uploadFails = PermissionDeniedException('no');

      await pass(
        build(),
        // The account is the queue's until the upload has been tried.
        isCurrentUser: () => !events.contains('upload:a'),
      );

      final row = (await db.uploadQueueDao.getUpload('a'))!;
      expect(row.permanentlyFailed, isFalse);
      expect(row.retryCount, 0);
    });
  });

  group('refreshUploadSession', () {
    late _MockAuth auth;
    late _MockUser user;

    setUp(() async {
      await BaseUnitTest.setupUnit();
      await TestServiceLocator.initialize();
      SharedPreferences.setMockInitialValues({});
      auth = _MockAuth();
      user = _MockUser();
      when(() => user.uid).thenReturn(uid);
      when(() => auth.currentUser).thenReturn(user);
      TestServiceLocator.registerMock<AuthRepository>(auth);
    });

    tearDown(() async {
      BaseUnitTest.resetMocks();
      await TestServiceLocator.reset();
    });

    test('forces a new token for the signed-in account', () async {
      when(() => user.getIdToken(true)).thenAnswer((_) async => 'token');

      await refreshUploadSession(uid, storage);

      verify(() => user.getIdToken(true)).called(1);
    });

    test('leaves another signed-in account alone', () async {
      when(() => user.uid).thenReturn('someone-else');

      await refreshUploadSession(uid, storage);

      verifyNever(() => user.getIdToken(any()));
    });

    test('an erased account ends the pass and drops its queue', () async {
      await queue('a');
      when(
        () => user.getIdToken(true),
      ).thenThrow(FirebaseAuthException(code: 'user-not-found'));

      await expectLater(
        refreshUploadSession(uid, storage),
        throwsA(isA<SessionEnded>()),
      );

      expect(await db.uploadQueueDao.getUpload('a'), isNull);
    });

    test('an expired sign-in ends the pass but keeps the queue for the next '
        'sign-in', () async {
      await queue('a');
      when(
        () => user.getIdToken(true),
      ).thenThrow(FirebaseAuthException(code: 'user-token-expired'));

      await expectLater(
        refreshUploadSession(uid, storage),
        throwsA(isA<SessionEnded>()),
      );

      expect(await db.uploadQueueDao.getUpload('a'), isNotNull);
    });

    test('a revoked sign-in ends the pass but keeps the queue', () async {
      await queue('a');
      when(
        () => user.getIdToken(true),
      ).thenThrow(FirebaseAuthException(code: 'invalid-user-token'));

      await expectLater(
        refreshUploadSession(uid, storage),
        throwsA(isA<SessionEnded>()),
      );

      expect(await db.uploadQueueDao.getUpload('a'), isNotNull);
    });

    test(
      'an erased account is not left owed once its queue is dropped',
      () async {
        when(
          () => user.getIdToken(true),
        ).thenThrow(FirebaseAuthException(code: 'user-not-found'));

        await expectLater(
          refreshUploadSession(uid, storage),
          throwsA(isA<SessionEnded>()),
        );

        expect(await OfflinePurgeStore().pending(), isEmpty);
      },
    );

    test('a purge that fails is owed to the next start', () async {
      when(
        () => user.getIdToken(true),
      ).thenThrow(FirebaseAuthException(code: 'user-not-found'));

      await expectLater(
        refreshUploadSession(uid, _StorageThatCannotClear()),
        throwsA(isA<FileSystemException>()),
      );

      expect(await OfflinePurgeStore().pending(), {uid});
    });

    test(
      'the queue as the app builds it checks the session before it sends',
      () async {
        await queue('a');
        when(
          () => user.getIdToken(true),
        ).thenThrow(FirebaseAuthException(code: 'user-disabled'));
        final processor = buildUploadQueueProcessor(
          database: db,
          storage: storage,
        );

        final sent = await withClock(
          Clock.fixed(t0),
          () => processor.runPass(
            uid,
            now: t0,
            isCurrentUser: () => true,
            force: true,
          ),
        );

        expect(sent, 0);
        verify(() => user.getIdToken(true)).called(1);
        expect((await db.uploadQueueDao.getUpload('a'))!.status, 'pending');
      },
    );

    test('a disabled account ends the pass but keeps the queue, since it can '
        'be enabled again', () async {
      await queue('a');
      when(
        () => user.getIdToken(true),
      ).thenThrow(FirebaseAuthException(code: 'user-disabled'));

      await expectLater(
        refreshUploadSession(uid, storage),
        throwsA(isA<SessionEnded>()),
      );

      expect(await db.uploadQueueDao.getUpload('a'), isNotNull);
    });

    test(
      'a failure that is not a sign-in answer does not stop the queue',
      () async {
        await queue('a');
        when(() => user.getIdToken(true)).thenThrow(StateError('no channel'));

        await refreshUploadSession(uid, storage);

        expect(await db.uploadQueueDao.getUpload('a'), isNotNull);
      },
    );

    test(
      'an unreachable server is not an answer: the upload reports it',
      () async {
        await queue('a');
        when(
          () => user.getIdToken(true),
        ).thenThrow(FirebaseAuthException(code: 'network-request-failed'));

        await refreshUploadSession(uid, storage);

        expect(await db.uploadQueueDao.getUpload('a'), isNotNull);
      },
    );
  });
}
