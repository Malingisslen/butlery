/// BUT-1214 write-chain pin for the cook-snap visibility override.
///
/// The read side is fully covered (model `fromWire`, repository onlyMe
/// exclusion, Firestore rules) — but rules and read-queries can only act on
/// what the client STORED. The write path is three pass-throughs (dialog →
/// VM → service → `CookSnap.create`), each defaulting to `sameAsRecipe`:
/// dropping any `visibility:` forward compiles clean and every read-side test
/// stays green while "Bara jag" photos get silently shared with the recipe's
/// audience. This suite pins the service-layer link — the real
/// `CookSnapService.addCookSnap` runs end to end (connectivity gate, pick,
/// upload, build, save) over a capturing fake repository, and the assertion
/// is on the persisted snap's visibility.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/models/cook_snap.dart';
import 'package:butlery/repositories/interfaces/auth_repository.dart';
import 'package:butlery/repositories/interfaces/cook_snap_repository.dart';
import 'package:butlery/repositories/interfaces/friends_repository.dart';
import 'package:butlery/services/connectivity_monitoring_service.dart';
import 'package:butlery/services/cook_snap_service.dart';
import 'package:butlery/services/image_picker_service.dart';
import 'package:butlery/services/upload/image_upload_service.dart';
import 'package:butlery/services/user_service.dart';

import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart' as production;

import '../../infrastructure/di/test_service_locator.dart';
import '../../infrastructure/factories/mock_factory.dart';
import '../../infrastructure/mocks/production_mocks.dart';
import '../../test_support/base_unit_test.dart';

/// Records every snap the service asks to persist — the assertion surface.
class _CapturingCookSnapRepository extends Fake implements CookSnapRepository {
  final List<CookSnap> saved = [];

  @override
  Future<CookSnap> addCookSnap(CookSnap snap) async {
    saved.add(snap);
    return snap;
  }
}

/// Never reached by addCookSnap (only the read paths resolve friends).
class _FakeFriendsRepository extends Fake implements FriendsRepository {}

class _MockImageUploadService extends Mock implements ImageUploadService {}

const _testUserId = 'test-user-123';

void main() {
  late _CapturingCookSnapRepository repository;
  late CookSnapService service;

  setUpAll(() {
    production.ServiceLocator.initialize(DIContainer());
    registerFallbackValue(ImageSource.gallery);
  });

  setUp(() async {
    await BaseUnitTest.setupUnit();
    await TestServiceLocator.initialize();

    // executeServiceOperation's auth pre-flight reads AuthRepository
    // directly; the default registration is unauthenticated.
    TestServiceLocator.registerMock<AuthRepository>(
      MockFactory.createAuthRepository(
          isAuthenticated: true, userId: _testUserId),
    );

    final connectivity = MockConnectivityMonitoringService();
    when(() => connectivity.isConnectedToInternet).thenReturn(true);
    TestServiceLocator.registerMock<ConnectivityMonitoringService>(
        connectivity);

    // Non-null file so the flow proceeds past the user-cancelled branch.
    final imagePicker = MockImagePickerService();
    when(() => imagePicker.pickImage(any()))
        .thenAnswer((_) async => File('snap.jpg'));
    TestServiceLocator.registerMock<ImagePickerService>(imagePicker);

    // Successful upload so the flow reaches CookSnap.create + repo save.
    final uploadService = _MockImageUploadService();
    when(() => uploadService.uploadImage(
              file: any(named: 'file'),
              userId: any(named: 'userId'),
            ))
        .thenAnswer(
            (_) async => UploadResult.success('https://example.com/snap.jpg'));
    TestServiceLocator.registerMock<ImageUploadService>(uploadService);

    // Profile lookup for displayName/avatar — null profile is a valid path
    // (falls back to '?'); pin it explicitly rather than rely on mock luck.
    final userService = MockUserService();
    when(() => userService.currentUserProfile).thenReturn(null);
    TestServiceLocator.registerMock<UserService>(userService);

    repository = _CapturingCookSnapRepository();
    service = CookSnapService(
      repository: repository,
      friendsRepository: _FakeFriendsRepository(),
    );
  });

  tearDown(() async {
    BaseUnitTest.resetMocks();
    await TestServiceLocator.reset();
  });

  // recipeAuthorId == current user → the author-notification branch (and its
  // NotificationService resolution) stays out of the flow under test.
  Future<CookSnap?> addSnap({CookSnapVisibility? visibility}) {
    return service.addCookSnap(
      recipeId: 'recipe-1',
      recipeAuthorId: _testUserId,
      recipeName: 'Köttbullar',
      source: ImageSource.gallery,
      caption: null,
      visibility: visibility ?? CookSnapVisibility.sameAsRecipe,
    );
  }

  group('CookSnapService — visibility write-chain (BUT-1214)', () {
    test('addCookSnap(visibility: onlyMe) persists onlyMe on the saved snap',
        () async {
      // Proves: the user's "Bara jag" choice survives the service layer into
      // the persisted document — the link that, if dropped, silently shares
      // a private photo with the recipe's audience.
      final snap = await addSnap(visibility: CookSnapVisibility.onlyMe);

      expect(snap, isNotNull,
          reason: 'sanity: the full add flow must reach the repo save');
      expect(repository.saved, hasLength(1));
      expect(
        repository.saved.single.visibility,
        CookSnapVisibility.onlyMe,
        reason: 'the persisted snap must carry the author-only override',
      );
    });

    test('addCookSnap without an explicit visibility persists sameAsRecipe',
        () async {
      // Proves: the default direction — an ordinary snap inherits the
      // recipe's audience (BUT-901) and is NOT accidentally locked to
      // author-only, which would hide every photo from friends.
      final snap = await service.addCookSnap(
        recipeId: 'recipe-1',
        recipeAuthorId: _testUserId,
        recipeName: 'Köttbullar',
        source: ImageSource.gallery,
      );

      expect(snap, isNotNull);
      expect(repository.saved, hasLength(1));
      expect(
        repository.saved.single.visibility,
        CookSnapVisibility.sameAsRecipe,
        reason: 'omitting the override must keep the inherited audience',
      );
    });
  });
}
