// BUT-2294: a profile picture chosen without a connection is kept until the
// form is saved, then queued on the device in place of any earlier one.

import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart' as production;
import 'package:butlery/core/l10n/app_locale.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/services/offline/offline_user_storage.dart';
import 'package:butlery/services/offline_service.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/services/upload/image_upload_service.dart';
import 'package:butlery/services/upload/upload_models.dart';
import 'package:butlery/services/user_service.dart';
import 'package:butlery/viewmodels/user_profile_viewmodel.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mocktail/mocktail.dart';

import '../../infrastructure/di/test_service_locator.dart';
import '../../infrastructure/mocks/production_mocks.dart';
import '../../test_support/base_unit_test.dart';

class _UserService extends MockUserService {
  final List<VoidCallback> _listeners = [];

  @override
  UserProfile? get currentUserProfile => currentUser;

  @override
  void addListener(VoidCallback listener) => _listeners.add(listener);

  @override
  void removeListener(VoidCallback listener) => _listeners.remove(listener);
}

class _UploadService extends Mock implements ImageUploadService {}

typedef _Queued = ({
  List<String> imagePaths,
  String entityType,
  String entityId,
  String userId,
  String targetPath,
  Map<String, Object?> metadata,
  bool replaceWaiting,
});

class _Storage extends Fake implements OfflineUserStorage {
  final List<_Queued> queued = [];
  bool fails = false;

  @override
  Future<List<String>> queueImageGroupForUser({
    required List<String> imagePaths,
    required String entityType,
    required String entityId,
    required String userId,
    required String targetPath,
    required Map<String, Object?> metadata,
    bool replaceWaiting = false,
  }) async {
    if (fails) throw StateError('disk full');
    queued.add((
      imagePaths: imagePaths,
      entityType: entityType,
      entityId: entityId,
      userId: userId,
      targetPath: targetPath,
      metadata: metadata,
      replaceWaiting: replaceWaiting,
    ));
    return const ['row-1'];
  }
}

class _Offline extends Fake implements OfflineService {
  _Offline(this.userStorage);

  @override
  final _Storage userStorage;

  /// Answers to successive reads of [isOnline]; the last one repeats.
  List<bool> online = [false];
  var _reads = 0;
  @override
  bool get isOnline =>
      online[_reads++ < online.length ? _reads - 1 : online.length - 1];

  @override
  bool isQueueReady = true;

  int refreshed = 0;

  @override
  Future<void> refreshSyncState() async => refreshed++;
}

void main() {
  const uid = 'u1';

  late _UserService users;
  late MockImagePickerService picker;
  late _UploadService upload;
  late FakePermissionService permission;
  late _Storage storage;
  late _Offline offline;
  late UserProfileViewModel viewModel;
  late List<Object?> avatarArguments;
  String? storedAvatar;

  UserProfile profile() => UserProfile(
    uid: uid,
    displayName: 'Malin',
    email: 'm@example.com',
    avatarUrl: storedAvatar,
    joinedAt: DateTime(2026),
    lastActiveAt: DateTime(2026),
  );

  setUpAll(() async {
    await BaseUnitTest.setupUnit();
    registerFallbackValue(ImageSource.gallery);
    registerFallbackValue(Uint8List(0));
    production.ServiceLocator.initialize(DIContainer());
  });

  setUp(() async {
    await TestServiceLocator.initialize();
    storedAvatar = 'https://img/old.jpg';
    users = _UserService();
    picker = MockImagePickerService();
    upload = _UploadService();
    permission = FakePermissionService()
      ..setPermissionState(currentUserId: uid, isAuthenticated: true);
    storage = _Storage();
    offline = _Offline(storage);
    avatarArguments = [];
    users.setUserState(currentUser: profile());
    when(
      () => users.createOrUpdateProfile(
        displayName: any(named: 'displayName'),
        avatarUrl: any(named: 'avatarUrl'),
        isSearchable: any(named: 'isSearchable'),
        allowEmailSearch: any(named: 'allowEmailSearch'),
        cookingSkillLevel: any(named: 'cookingSkillLevel'),
        cuisineAffinities: any(named: 'cuisineAffinities'),
        bio: any(named: 'bio'),
        showOnlineStatus: any(named: 'showOnlineStatus'),
        shareActivityToFeed: any(named: 'shareActivityToFeed'),
        activityFeedEventTypes: any(named: 'activityFeedEventTypes'),
        householdSize: any(named: 'householdSize'),
      ),
    ).thenAnswer((inv) async {
      avatarArguments.add(inv.namedArguments[#avatarUrl]);
      return profile();
    });
    when(
      () => users.isDisplayNameAvailable(any()),
    ).thenAnswer((_) async => true);
    TestServiceLocator.registerMock<UserService>(users);
    TestServiceLocator.registerMock<PermissionService>(permission);
    TestServiceLocator.registerMock<ImageUploadService>(upload);
    viewModel = UserProfileViewModel(
      users,
      picker,
      uploadService: upload,
      offlineService: () => offline,
    );
  });

  tearDown(() async {
    viewModel.dispose();
    BaseUnitTest.resetMocks();
    await TestServiceLocator.reset();
  });

  void pickerReturns(String path) {
    final file = MockFile();
    when(() => file.path).thenReturn(path);
    when(() => file.readAsBytes()).thenAnswer((_) async => Uint8List(3));
    when(
      () => picker.pickImage(
        any(),
        maxWidth: any(named: 'maxWidth'),
        maxHeight: any(named: 'maxHeight'),
        imageQuality: any(named: 'imageQuality'),
      ),
    ).thenAnswer((_) async => file);
  }

  void uploadReturns(UploadResult result) {
    when(
      () => upload.uploadImageFromBytes(
        bytes: any(named: 'bytes'),
        userId: any(named: 'userId'),
        fileName: any(named: 'fileName'),
        prefix: any(named: 'prefix'),
      ),
    ).thenAnswer((_) async => result);
  }

  test('a picture chosen without a connection is kept, not uploaded, and the '
      'stored picture is unchanged', () async {
    pickerReturns('/tmp/new.jpg');

    expect(await viewModel.uploadAvatar(), isTrue);

    expect(viewModel.pendingAvatarPath, '/tmp/new.jpg');
    expect(viewModel.avatarUrl, 'https://img/old.jpg');
    expect(viewModel.hasUnsavedChanges, isTrue);
    verifyNever(
      () => upload.uploadImageFromBytes(
        bytes: any(named: 'bytes'),
        userId: any(named: 'userId'),
        fileName: any(named: 'fileName'),
        prefix: any(named: 'prefix'),
      ),
    );
  });

  test(
    'saving queues the picture against the one the user saw, in place of '
    'an earlier one, and leaves the stored picture out of the save',
    () async {
      pickerReturns('/tmp/new.jpg');
      await viewModel.uploadAvatar();

      expect(await viewModel.saveProfile(), isTrue);

      expect(
        identical(avatarArguments.single, UserService.avatarUntouched),
        isTrue,
      );
      final queued = storage.queued.single;
      expect(queued.imagePaths, ['/tmp/new.jpg']);
      expect(queued.entityType, 'avatar');
      expect(queued.entityId, uid);
      expect(queued.userId, uid);
      expect(queued.targetPath, 'users/$uid/avatars');
      expect(queued.metadata, {'baseAvatarUrl': 'https://img/old.jpg'});
      expect(queued.replaceWaiting, isTrue);
      expect(offline.refreshed, 1);
      expect(viewModel.pendingAvatarPath, isNull);
      expect(viewModel.avatarWaitsForConnection, isTrue);
    },
  );

  test('a profile that had no picture is queued against none', () async {
    storedAvatar = null;
    users.setUserState(currentUser: profile());
    viewModel.dispose();
    viewModel = UserProfileViewModel(
      users,
      picker,
      uploadService: upload,
      offlineService: () => offline,
    );
    pickerReturns('/tmp/new.jpg');
    await viewModel.uploadAvatar();

    await viewModel.saveProfile();

    expect(storage.queued.single.metadata, {'baseAvatarUrl': null});
  });

  test('a picture that could not be kept for later is reported, the rest of '
      'the profile is saved, and the next save tries again', () async {
    pickerReturns('/tmp/new.jpg');
    await viewModel.uploadAvatar();
    storage.fails = true;

    expect(await viewModel.saveProfile(), isFalse);

    expect(avatarArguments, hasLength(1));
    expect(viewModel.error, AppLocale.current.profileAvatarQueueFailed);
    expect(viewModel.pendingAvatarPath, '/tmp/new.jpg');
    expect(viewModel.avatarWaitsForConnection, isFalse);

    storage.fails = false;
    expect(await viewModel.saveProfile(), isTrue);

    expect(storage.queued, hasLength(1));
    expect(viewModel.pendingAvatarPath, isNull);
  });

  test('a save with no picture waiting queues nothing', () async {
    expect(await viewModel.saveProfile(), isTrue);

    expect(storage.queued, isEmpty);
    expect(viewModel.avatarWaitsForConnection, isFalse);
  });

  test('with a connection the picture is uploaded at once as before', () async {
    offline.online = [true];
    pickerReturns('/tmp/new.jpg');
    uploadReturns(UploadResult.success('https://img/new.jpg'));

    expect(await viewModel.uploadAvatar(), isTrue);

    expect(viewModel.pendingAvatarPath, isNull);
    expect(viewModel.avatarUrl, 'https://img/new.jpg');
  });

  test('a queue that is not ready never keeps a picture for later', () async {
    offline.isQueueReady = false;
    pickerReturns('/tmp/new.jpg');
    uploadReturns(
      UploadResult.failure('no connection', ImageUploadErrorType.network),
    );

    expect(await viewModel.uploadAvatar(), isFalse);

    expect(viewModel.pendingAvatarPath, isNull);
  });

  test('a connection that drops during the upload keeps the picture for '
      'later', () async {
    offline.online = [true, false];
    pickerReturns('/tmp/new.jpg');
    uploadReturns(
      UploadResult.failure('network', ImageUploadErrorType.network),
    );

    expect(await viewModel.uploadAvatar(), isTrue);

    expect(viewModel.pendingAvatarPath, '/tmp/new.jpg');
    expect(viewModel.avatarUrl, 'https://img/old.jpg');
  });

  test(
    'a picture uploaded after one was kept for later takes its place',
    () async {
      pickerReturns('/tmp/kept.jpg');
      await viewModel.uploadAvatar();
      offline.online = [true];
      pickerReturns('/tmp/new.jpg');
      uploadReturns(UploadResult.success('https://img/new.jpg'));

      await viewModel.uploadAvatar();
      await viewModel.saveProfile();

      expect(viewModel.pendingAvatarPath, isNull);
      expect(storage.queued, isEmpty);
      expect(avatarArguments.single, 'https://img/new.jpg');
    },
  );

  test('a picture kept for later takes the place of one uploaded before it, '
      'which the save no longer writes', () async {
    offline.online = [true];
    pickerReturns('/tmp/first.jpg');
    uploadReturns(UploadResult.success('https://img/first.jpg'));
    await viewModel.uploadAvatar();
    offline.online = [false];
    pickerReturns('/tmp/second.jpg');

    await viewModel.uploadAvatar();
    await viewModel.saveProfile();

    expect(viewModel.avatarWaitsForConnection, isTrue);
    expect(
      identical(avatarArguments.single, UserService.avatarUntouched),
      isTrue,
    );
  });

  test('a form reset forgets the picture kept for later', () async {
    pickerReturns('/tmp/new.jpg');
    await viewModel.uploadAvatar();

    viewModel.resetForm();

    expect(viewModel.pendingAvatarPath, isNull);
    expect(viewModel.hasUnsavedChanges, isFalse);
  });

  test('removing the picture also forgets one kept for later', () async {
    pickerReturns('/tmp/new.jpg');
    await viewModel.uploadAvatar();

    viewModel.removeAvatar();
    await viewModel.saveProfile();

    expect(viewModel.pendingAvatarPath, isNull);
    expect(storage.queued, isEmpty);
    expect(avatarArguments.single, isNull);
  });
}
