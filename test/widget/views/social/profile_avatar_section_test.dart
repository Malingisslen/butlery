// BUT-2294: the profile picture chosen without a connection is previewed on
// the form with the line that says it is saved when the user is online.

import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart' as production;
import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/services/offline/offline_user_storage.dart';
import 'package:butlery/services/offline_service.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/services/upload/image_upload_service.dart';
import 'package:butlery/services/user_service.dart';
import 'package:butlery/viewmodels/user_profile_viewmodel.dart';
import 'package:butlery/views/social/user_profile_edit/identity_sections.dart';
import 'package:butlery/widgets/common/avatar_circle.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mocktail/mocktail.dart';

import '../../../infrastructure/di/test_service_locator.dart';
import '../../../infrastructure/mocks/production_mocks.dart';
import '../../../test_support/base_unit_test.dart';

class _UserService extends MockUserService {
  @override
  UserProfile? get currentUserProfile => currentUser;

  @override
  void addListener(VoidCallback listener) {}

  @override
  void removeListener(VoidCallback listener) {}
}

class _Upload extends Mock implements ImageUploadService {}

class _Offline extends Fake implements OfflineService {
  @override
  bool get isOnline => false;

  @override
  bool get isQueueReady => true;

  @override
  OfflineUserStorage get userStorage => throw UnimplementedError();
}

void main() {
  late UserProfileViewModel viewModel;
  late MockImagePickerService picker;

  setUpAll(() async {
    await BaseUnitTest.setupUnit();
    registerFallbackValue(ImageSource.gallery);
    production.ServiceLocator.initialize(DIContainer());
  });

  Future<void> build({required String? storedAvatar}) async {
    await TestServiceLocator.initialize();
    final users = _UserService()
      ..setUserState(
        currentUser: UserProfile(
          uid: 'u1',
          displayName: 'Malin',
          email: 'm@example.com',
          avatarUrl: storedAvatar,
          joinedAt: DateTime(2026),
          lastActiveAt: DateTime(2026),
        ),
      );
    picker = MockImagePickerService();
    TestServiceLocator.registerMock<UserService>(users);
    TestServiceLocator.registerMock<PermissionService>(
      FakePermissionService()
        ..setPermissionState(currentUserId: 'u1', isAuthenticated: true),
    );
    viewModel = UserProfileViewModel(
      users,
      picker,
      uploadService: _Upload(),
      offlineService: _Offline.new,
    );
  }

  tearDown(() async {
    viewModel.dispose();
    BaseUnitTest.resetMocks();
    await TestServiceLocator.reset();
  });

  Future<void> pump(WidgetTester tester) => tester.pumpWidget(
    MaterialApp(
      locale: const Locale('sv'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: ListenableBuilder(
          listenable: viewModel,
          builder: (_, _) =>
              ProfileAvatarSection(viewModel: viewModel, onUploadAvatar: () {}),
        ),
      ),
    ),
  );

  testWidgets('without a waiting picture the stored one shows and no line '
      'about waiting', (tester) async {
    await build(storedAvatar: 'https://img/old.jpg');
    await pump(tester);

    expect(find.text('Sparas när du är online'), findsNothing);
    expect(find.byType(AvatarCircle), findsOneWidget);
    expect(find.text('Ta bort'), findsOneWidget);
  });

  testWidgets('a picture kept for later is previewed with the line that says '
      'when it is saved, and can still be removed even with no stored '
      'picture', (tester) async {
    await build(storedAvatar: null);
    final file = MockFile();
    when(() => file.path).thenReturn('/tmp/missing.jpg');
    when(
      () => picker.pickImage(
        any(),
        maxWidth: any(named: 'maxWidth'),
        maxHeight: any(named: 'maxHeight'),
        imageQuality: any(named: 'imageQuality'),
      ),
    ).thenAnswer((_) async => file);
    await viewModel.uploadAvatar();
    await pump(tester);

    expect(find.text('Sparas när du är online'), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
    expect(find.text('Ta bort'), findsOneWidget);

    await tester.tap(find.text('Ta bort'));
    await tester.pump();

    expect(find.text('Sparas när du är online'), findsNothing);
  });
}
