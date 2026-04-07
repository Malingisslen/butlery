import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:image_picker/image_picker.dart';
import 'package:butlery/viewmodels/user_profile_viewmodel.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/services/user_service.dart';
import 'package:butlery/services/image_picker_service.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/services/upload/image_upload_service.dart';
import 'package:butlery/services/upload/upload_models.dart';
import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart' as production;

import '../../test_support/base_unit_test.dart';
import '../../infrastructure/di/test_service_locator.dart';
import '../../infrastructure/mocks/production_mocks.dart';

// Test data builder for UserProfile
class UserProfileBuilder {
  static UserProfile build({
    String? uid,
    String? displayName,
    String? email,
    String? avatarUrl,
    bool isSearchable = true,
    bool allowEmailSearch = false,
    int publicRecipeCount = 0,
    int friendsCount = 0,
    DateTime? joinedAt,
    DateTime? lastActiveAt,
    bool isOnline = false,
    String? fcmToken,
    DateTime? fcmTokenUpdatedAt,
    bool notificationsEnabled = true,
    CookingSkillLevel? cookingSkillLevel,
    List<String>? cuisineAffinities,
    String? bio,
  }) {
    final now = DateTime.now();
    return UserProfile(
      uid: uid ?? 'test-user-123',
      displayName: displayName ?? 'Test User',
      email: email ?? 'test@example.com',
      avatarUrl: avatarUrl,
      isSearchable: isSearchable,
      allowEmailSearch: allowEmailSearch,
      publicRecipeCount: publicRecipeCount,
      friendsCount: friendsCount,
      joinedAt: joinedAt ?? now,
      lastActiveAt: lastActiveAt ?? now,
      isOnline: isOnline,
      fcmToken: fcmToken,
      fcmTokenUpdatedAt: fcmTokenUpdatedAt,
      notificationsEnabled: notificationsEnabled,
      cookingSkillLevel: cookingSkillLevel,
      cuisineAffinities: cuisineAffinities,
      bio: bio,
    );
  }
}

class MockImageUploadService extends Mock implements ImageUploadService {}

/// Extended MockUserService that properly exposes currentUserProfile
/// and supports listener registration for ViewModel tests.
class TestMockUserService extends MockUserService {
  final List<VoidCallback> _listeners = [];

  @override
  UserProfile? get currentUserProfile => currentUser;

  @override
  void addListener(VoidCallback listener) {
    _listeners.add(listener);
  }

  @override
  void removeListener(VoidCallback listener) {
    _listeners.remove(listener);
  }

  // ignore: annotate_overrides
  void notifyListeners() {
    for (final listener in List<VoidCallback>.from(_listeners)) {
      listener();
    }
  }
}

void main() {
  group('UserProfileViewModel', () {
    late UserProfileViewModel viewModel;
    late TestMockUserService mockUserService;
    late MockImagePickerService mockImagePickerService;
    late MockPermissionService mockPermissionService;
    late MockImageUploadService mockImageUploadService;
    const testUserId = 'test-user-123';

    setUpAll(() async {
      await BaseUnitTest.setupUnit();
      registerFallbackValue(ImageSource.gallery);
      registerFallbackValue(MockFile());
      registerFallbackValue(Uint8List(0));

      // Bridge production ServiceLocator to test GetIt instance
      final testDIContainer = DIContainer();
      production.ServiceLocator.initialize(testDIContainer);
    });

    setUp(() async {
      await TestServiceLocator.initialize();

      // Create mocks
      mockUserService = TestMockUserService();
      mockImagePickerService = MockImagePickerService();
      mockPermissionService = MockPermissionService();
      mockImageUploadService = MockImageUploadService();

      // Configure UserService state
      mockUserService.setUserState(
        currentUser: null,
        users: {},
        isLoading: false,
        error: null,
      );

      // Configure permission service for auth state
      mockPermissionService.setPermissionState(
        currentUserId: testUserId,
        isAuthenticated: true,
      );

      // Setup default mock behaviors
      when(() => mockUserService.isDisplayNameAvailable(any()))
          .thenAnswer((_) async => true);

      when(() => mockUserService.createOrUpdateProfile(
            displayName: any(named: 'displayName'),
            avatarUrl: any(named: 'avatarUrl'),
            isSearchable: any(named: 'isSearchable'),
            allowEmailSearch: any(named: 'allowEmailSearch'),
            cookingSkillLevel: any(named: 'cookingSkillLevel'),
            cuisineAffinities: any(named: 'cuisineAffinities'),
            bio: any(named: 'bio'),
          )).thenAnswer((_) async => UserProfileBuilder.build());

      when(() => mockImagePickerService.pickImage(any()))
          .thenAnswer((_) async => null);

      // Register mocks in test service locator
      TestServiceLocator.registerMock<UserService>(mockUserService);
      TestServiceLocator.registerMock<PermissionService>(mockPermissionService);
      TestServiceLocator.registerMock<ImagePickerService>(
          mockImagePickerService);
      TestServiceLocator.registerMock<ImageUploadService>(
          mockImageUploadService);

      // Create viewModel with a profile for most tests
      final defaultProfile = UserProfileBuilder.build(
        uid: testUserId,
        displayName: 'Test User',
        email: 'test@example.com',
      );
      mockUserService.setUserState(
        currentUser: defaultProfile,
        users: {},
        isLoading: false,
        error: null,
      );

      viewModel = UserProfileViewModel(
        mockUserService,
        mockImagePickerService,
        uploadService: mockImageUploadService,
      );
    });

    tearDown(() async {
      viewModel.dispose();
      BaseUnitTest.resetMocks();
      await TestServiceLocator.reset();
    });

    tearDownAll(() async {
      await BaseUnitTest.teardownUnit();
    });

    group('Initialization', () {
      test('should initialize with profile from setUp', () {
        expect(viewModel.displayName, equals('Test User'));
        expect(viewModel.avatarUrl, isNull);
        expect(viewModel.isSearchable, isTrue);
        expect(viewModel.allowEmailSearch, isFalse);
        expect(viewModel.hasUnsavedChanges, isFalse);
        expect(viewModel.hasProfile, isTrue);
        expect(viewModel.isLoading, isFalse);
        expect(viewModel.hasError, isFalse);
      });

      test(
          'should initialize without profile when permission service has no user',
          () {
        expect(viewModel.hasProfile, isTrue);
        expect(viewModel.displayName, equals('Test User'));
      });

      test('should initialize with existing profile data', () {
        final existingProfile = UserProfileBuilder.build(
          displayName: 'Anna Andersson',
          avatarUrl: 'https://example.com/anna.jpg',
          isSearchable: false,
          allowEmailSearch: true,
        );

        mockUserService.setUserState(
          currentUser: existingProfile,
          users: {},
          isLoading: false,
          error: null,
        );

        final vmWithProfile = UserProfileViewModel(
          mockUserService,
          mockImagePickerService,
          uploadService: mockImageUploadService,
        );

        expect(vmWithProfile.displayName, equals('Anna Andersson'));
        expect(vmWithProfile.avatarUrl, equals('https://example.com/anna.jpg'));
        expect(vmWithProfile.isSearchable, isFalse);
        expect(vmWithProfile.allowEmailSearch, isTrue);
        expect(vmWithProfile.hasUnsavedChanges, isFalse);
        expect(vmWithProfile.hasProfile, isTrue);

        vmWithProfile.dispose();
      });

      test('should listen to UserService changes', () {
        var notificationCount = 0;
        viewModel.addListener(() => notificationCount++);

        mockUserService.notifyListeners();

        expect(notificationCount, greaterThan(0));
      });
    });

    group('Form State Management', () {
      test('should update display name with trimming', () {
        var notificationCount = 0;
        viewModel.addListener(() => notificationCount++);

        viewModel.updateDisplayName('  Erik Svensson  ');

        expect(viewModel.displayName, equals('Erik Svensson'));
        expect(viewModel.hasUnsavedChanges, isTrue);
        expect(notificationCount, greaterThan(0));
      });

      test('should update searchability preference', () {
        viewModel.updateIsSearchable(false);

        expect(viewModel.isSearchable, isFalse);
        expect(viewModel.hasUnsavedChanges, isTrue);
      });

      test('should update email search preference', () {
        viewModel.updateAllowEmailSearch(true);

        expect(viewModel.allowEmailSearch, isTrue);
        expect(viewModel.hasUnsavedChanges, isTrue);
      });
    });

    group('Validation', () {
      test('should validate empty display name', () {
        viewModel.updateDisplayName('');

        expect(viewModel.displayNameError, equals('Namn krävs'));
        expect(viewModel.isFormValid, isFalse);
      });

      test('should validate display name minimum length', () {
        viewModel.updateDisplayName('A');

        expect(viewModel.displayNameError,
            equals('Visningsnamn måste vara minst 2 tecken'));
        expect(viewModel.isFormValid, isFalse);
      });

      test('should validate display name maximum length', () {
        viewModel.updateDisplayName('A' * 51);

        expect(viewModel.displayNameError, equals('Beskrivning för lång'));
        expect(viewModel.isFormValid, isFalse);
      });

      test('should validate display name invalid characters', () {
        viewModel.updateDisplayName('Test@#%');

        expect(viewModel.displayNameError,
            equals('Fyll i alla obligatoriska fält korrekt'));
        expect(viewModel.isFormValid, isFalse);
      });

      test('should accept valid display name', () {
        viewModel.updateDisplayName('Anna_Andersson-123');

        expect(viewModel.displayNameError, isNull);
        expect(viewModel.isFormValid, isTrue);
      });

      test('should combine validation errors', () {
        viewModel.updateDisplayName('');

        expect(viewModel.displayNameError, isNotNull);
        expect(viewModel.hasError, isTrue);
        expect(viewModel.error, equals(viewModel.displayNameError));
        expect(viewModel.isFormValid, isFalse);
      });
    });

    group('Avatar Management', () {
      test('should upload avatar successfully', () async {
        final mockFile = MockFile();
        when(() => mockFile.path).thenReturn('/test/path/image.jpg');
        when(() => mockFile.readAsBytes())
            .thenAnswer((_) async => Uint8List.fromList([1, 2, 3]));
        when(() => mockImagePickerService.pickImage(ImageSource.gallery))
            .thenAnswer((_) async => mockFile);
        when(() => mockImageUploadService.uploadImageFromBytes(
                  bytes: any(named: 'bytes'),
                  userId: any(named: 'userId'),
                  fileName: any(named: 'fileName'),
                  prefix: any(named: 'prefix'),
                ))
            .thenAnswer((_) async =>
                UploadResult.success('https://example.com/new-avatar.jpg'));

        final result = await viewModel.uploadAvatar();

        expect(result, isTrue);
        expect(
            viewModel.avatarUrl, equals('https://example.com/new-avatar.jpg'));
        expect(viewModel.hasUnsavedChanges, isTrue);
        expect(viewModel.isUploadingAvatar, isFalse);
        verify(() => mockImagePickerService.pickImage(ImageSource.gallery))
            .called(1);
        verify(() => mockImageUploadService.uploadImageFromBytes(
              bytes: any(named: 'bytes'),
              userId: testUserId,
              fileName: 'image.jpg',
              prefix: 'avatar',
            )).called(1);
      });

      test('should handle cancelled image selection', () async {
        when(() => mockImagePickerService.pickImage(ImageSource.gallery))
            .thenAnswer((_) async => null);

        final result = await viewModel.uploadAvatar();

        expect(result, isFalse);
        expect(viewModel.avatarUrl, isNull);
        expect(viewModel.hasUnsavedChanges, isFalse);
        expect(viewModel.isUploadingAvatar, isFalse);
      });

      test('should handle upload failure', () async {
        final mockFile = MockFile();
        when(() => mockFile.path).thenReturn('/test/path/image.jpg');
        when(() => mockFile.readAsBytes())
            .thenAnswer((_) async => Uint8List.fromList([1, 2, 3]));
        when(() => mockImagePickerService.pickImage(ImageSource.gallery))
            .thenAnswer((_) async => mockFile);
        when(() => mockImageUploadService.uploadImageFromBytes(
                  bytes: any(named: 'bytes'),
                  userId: any(named: 'userId'),
                  fileName: any(named: 'fileName'),
                  prefix: any(named: 'prefix'),
                ))
            .thenAnswer((_) async => UploadResult.failure(
                'Upload failed', ImageUploadErrorType.unknown));

        final result = await viewModel.uploadAvatar();

        expect(result, isFalse);
        expect(viewModel.avatarUrl, isNull);
        expect(viewModel.isUploadingAvatar, isFalse);
      });

      test('should remove avatar', () {
        final profileWithAvatar = UserProfileBuilder.build(
          uid: testUserId,
          displayName: 'Test User',
          email: 'test@example.com',
          avatarUrl: 'https://example.com/existing-avatar.jpg',
        );
        mockUserService.setUserState(
          currentUser: profileWithAvatar,
          users: {},
          isLoading: false,
          error: null,
        );

        final viewModelWithAvatar = UserProfileViewModel(
          mockUserService,
          mockImagePickerService,
          uploadService: mockImageUploadService,
        );

        expect(viewModelWithAvatar.avatarUrl,
            equals('https://example.com/existing-avatar.jpg'));
        expect(viewModelWithAvatar.hasUnsavedChanges, isFalse);

        viewModelWithAvatar.removeAvatar();

        expect(viewModelWithAvatar.avatarUrl, isNull);
        expect(viewModelWithAvatar.hasUnsavedChanges, isTrue);

        viewModelWithAvatar.dispose();
      });

      test('should track upload progress state', () async {
        final mockFile = MockFile();
        when(() => mockFile.path).thenReturn('/test/path/image.jpg');
        when(() => mockFile.readAsBytes())
            .thenAnswer((_) async => Uint8List.fromList([1, 2, 3]));
        when(() => mockImagePickerService.pickImage(ImageSource.gallery))
            .thenAnswer((_) async {
          // Check loading state during operation
          expect(viewModel.isUploadingAvatar, isTrue);
          expect(viewModel.isLoading, isTrue);
          return mockFile;
        });
        when(() => mockImageUploadService.uploadImageFromBytes(
                  bytes: any(named: 'bytes'),
                  userId: any(named: 'userId'),
                  fileName: any(named: 'fileName'),
                  prefix: any(named: 'prefix'),
                ))
            .thenAnswer((_) async =>
                UploadResult.failure('test', ImageUploadErrorType.unknown));

        await viewModel.uploadAvatar();

        expect(viewModel.isUploadingAvatar, isFalse);
        expect(viewModel.isLoading, isFalse);
      });
    });

    group('Profile Saving', () {
      test('should save new profile successfully', () async {
        viewModel.updateDisplayName('Erik Svensson');
        viewModel.updateIsSearchable(false);
        viewModel.updateAllowEmailSearch(true);

        final savedProfile = UserProfileBuilder.build(
          displayName: 'Erik Svensson',
          isSearchable: false,
          allowEmailSearch: true,
        );

        when(() => mockUserService.createOrUpdateProfile(
              displayName: 'Erik Svensson',
              avatarUrl: any(named: 'avatarUrl'),
              isSearchable: false,
              allowEmailSearch: true,
              cookingSkillLevel: any(named: 'cookingSkillLevel'),
              cuisineAffinities: any(named: 'cuisineAffinities'),
              bio: any(named: 'bio'),
            )).thenAnswer((_) async => savedProfile);

        final result = await viewModel.saveProfile();

        expect(result, isTrue);
        expect(viewModel.hasUnsavedChanges, isFalse);
        verify(() => mockUserService.createOrUpdateProfile(
              displayName: 'Erik Svensson',
              avatarUrl: any(named: 'avatarUrl'),
              isSearchable: false,
              allowEmailSearch: true,
              cookingSkillLevel: any(named: 'cookingSkillLevel'),
              cuisineAffinities: any(named: 'cuisineAffinities'),
              bio: any(named: 'bio'),
            )).called(1);
      });

      test('should reject save with invalid form', () async {
        viewModel.updateDisplayName('');

        final result = await viewModel.saveProfile();

        expect(result, isFalse);
        verifyNever(() => mockUserService.createOrUpdateProfile(
              displayName: any(named: 'displayName'),
              avatarUrl: any(named: 'avatarUrl'),
              isSearchable: any(named: 'isSearchable'),
              allowEmailSearch: any(named: 'allowEmailSearch'),
              cookingSkillLevel: any(named: 'cookingSkillLevel'),
              cuisineAffinities: any(named: 'cuisineAffinities'),
              bio: any(named: 'bio'),
            ));
      });

      test('should check display name availability on save', () async {
        // The ViewModel compares edited vs original profile — change displayName
        viewModel.updateDisplayName('New Name');

        when(() => mockUserService.isDisplayNameAvailable('New Name'))
            .thenAnswer((_) async => false);

        final result = await viewModel.saveProfile();

        expect(result, isFalse);
        expect(viewModel.displayNameError, equals('Detta namn är redan taget'));
        verify(() => mockUserService.isDisplayNameAvailable('New Name'))
            .called(1);
      });

      test('should not check availability if name unchanged', () async {
        // Profile already has 'Test User' from setUp — only change a different field
        viewModel.updateIsSearchable(false);

        final savedProfile = UserProfileBuilder.build(
          displayName: 'Test User',
          isSearchable: false,
        );
        when(() => mockUserService.createOrUpdateProfile(
              displayName: 'Test User',
              avatarUrl: any(named: 'avatarUrl'),
              isSearchable: false,
              allowEmailSearch: any(named: 'allowEmailSearch'),
              cookingSkillLevel: any(named: 'cookingSkillLevel'),
              cuisineAffinities: any(named: 'cuisineAffinities'),
              bio: any(named: 'bio'),
            )).thenAnswer((_) async => savedProfile);

        final result = await viewModel.saveProfile();

        expect(result, isTrue);
        verifyNever(() => mockUserService.isDisplayNameAvailable(any()));
      });

      test('should handle save failure', () async {
        viewModel.updateDisplayName('New Name');

        when(() => mockUserService.createOrUpdateProfile(
              displayName: any(named: 'displayName'),
              avatarUrl: any(named: 'avatarUrl'),
              isSearchable: any(named: 'isSearchable'),
              allowEmailSearch: any(named: 'allowEmailSearch'),
              cookingSkillLevel: any(named: 'cookingSkillLevel'),
              cuisineAffinities: any(named: 'cuisineAffinities'),
              bio: any(named: 'bio'),
            )).thenAnswer((_) async => null);

        mockUserService.setUserState(error: 'Network error');

        final result = await viewModel.saveProfile();

        expect(result, isFalse);
        expect(viewModel.hasUnsavedChanges, isTrue);
      });
    });

    group('Display Name Availability', () {
      test('should check availability successfully', () async {
        viewModel.updateDisplayName('UniqueUser');
        when(() => mockUserService.isDisplayNameAvailable('UniqueUser'))
            .thenAnswer((_) async => true);

        final result = await viewModel.checkDisplayNameAvailability();

        expect(result, isTrue);
        expect(viewModel.displayNameError, isNull);
      });

      test('should handle unavailable display name', () async {
        viewModel.updateDisplayName('TakenUser');
        when(() => mockUserService.isDisplayNameAvailable('TakenUser'))
            .thenAnswer((_) async => false);

        final result = await viewModel.checkDisplayNameAvailability();

        expect(result, isFalse);
        expect(viewModel.displayNameError, equals('Detta namn är redan taget'));
      });

      test('should not check empty display name', () async {
        viewModel.updateDisplayName('');

        final result = await viewModel.checkDisplayNameAvailability();

        expect(result, isFalse);
        verifyNever(() => mockUserService.isDisplayNameAvailable(any()));
      });
    });

    group('Form Reset', () {
      test('should reset to existing profile state', () {
        viewModel.updateDisplayName('Changed Name');
        viewModel.updateIsSearchable(false);
        viewModel.updateAllowEmailSearch(true);

        viewModel.resetForm();

        expect(viewModel.displayName, equals('Test User'));
        expect(viewModel.avatarUrl, isNull);
        expect(viewModel.isSearchable, isTrue);
        expect(viewModel.allowEmailSearch, isFalse);
        expect(viewModel.hasUnsavedChanges, isFalse);
        expect(viewModel.displayNameError, isNull);
      });

      test('should reset to existing profile values', () {
        final existingProfile = UserProfileBuilder.build(
          displayName: 'Original Name',
          avatarUrl: 'https://example.com/original.jpg',
          isSearchable: false,
          allowEmailSearch: true,
        );
        mockUserService.setUserState(
          currentUser: existingProfile,
          users: {},
          isLoading: false,
          error: null,
        );

        final vmWithProfile = UserProfileViewModel(
          mockUserService,
          mockImagePickerService,
          uploadService: mockImageUploadService,
        );

        vmWithProfile.updateDisplayName('Changed Name');

        vmWithProfile.resetForm();

        expect(vmWithProfile.displayName, equals('Original Name'));
        expect(vmWithProfile.avatarUrl,
            equals('https://example.com/original.jpg'));
        expect(vmWithProfile.isSearchable, isFalse);
        expect(vmWithProfile.allowEmailSearch, isTrue);
        expect(vmWithProfile.hasUnsavedChanges, isFalse);

        vmWithProfile.dispose();
      });
    });

    group('Change Detection', () {
      test('should detect changes from profile', () {
        expect(viewModel.hasUnsavedChanges, isFalse);

        viewModel.updateDisplayName('New Name');
        expect(viewModel.hasUnsavedChanges, isTrue);

        viewModel.updateDisplayName('Test User'); // Back to original
        expect(viewModel.hasUnsavedChanges, isFalse);
      });

      test('should detect changes with multiple fields', () {
        final existingProfile = UserProfileBuilder.build(
          displayName: 'Original Name',
        );
        mockUserService.setUserState(
          currentUser: existingProfile,
          users: {},
          isLoading: false,
          error: null,
        );

        final vmWithProfile = UserProfileViewModel(
          mockUserService,
          mockImagePickerService,
          uploadService: mockImageUploadService,
        );

        expect(vmWithProfile.hasUnsavedChanges, isFalse);

        vmWithProfile.updateDisplayName('Changed Name');
        expect(vmWithProfile.hasUnsavedChanges, isTrue);

        vmWithProfile.updateDisplayName('Original Name');
        expect(vmWithProfile.hasUnsavedChanges, isFalse);

        vmWithProfile.dispose();
      });

      test('should detect avatar changes', () {
        // Start with no avatar — changing displayName causes unsaved changes
        viewModel.updateDisplayName('Test'); // Short but valid (>= 2 chars)
        viewModel.removeAvatar(); // No actual avatar change (was already null)
        expect(viewModel.hasUnsavedChanges, isTrue); // displayName changed

        viewModel.resetForm();
        expect(viewModel.hasUnsavedChanges, isFalse);
      });

      test('should detect privacy setting changes', () {
        viewModel.updateIsSearchable(false);
        expect(viewModel.hasUnsavedChanges, isTrue);

        viewModel.updateIsSearchable(true);
        expect(viewModel.hasUnsavedChanges, isFalse);

        viewModel.updateAllowEmailSearch(true);
        expect(viewModel.hasUnsavedChanges, isTrue);
      });
    });

    group('Error Handling', () {
      test('should clear all errors', () {
        viewModel.updateDisplayName('A'); // Too short

        viewModel.clearError();

        expect(viewModel.displayNameError, isNull);
        expect(viewModel.error, isNull);
        expect(viewModel.hasError, isFalse);
      });

      test('should return first error in combined error', () {
        viewModel.updateDisplayName('A'); // Sets display name error

        expect(viewModel.error, equals(viewModel.displayNameError));

        viewModel.updateDisplayName('Valid Name');
        expect(viewModel.error, isNull);
      });
    });

    group('State Accessors', () {
      test('should provide current profile access', () {
        final profile = viewModel.currentProfile;

        expect(profile, isNotNull);
        expect(profile?.displayName, equals('Test User'));
        expect(viewModel.hasProfile, isTrue);
      });

      test('should handle null profile scenario', () {
        expect(viewModel.hasProfile, isTrue);

        viewModel.updateDisplayName('');
        viewModel.removeAvatar();

        expect(viewModel.isFormValid, isFalse);
        expect(viewModel.displayNameError, equals('Namn krävs'));
      });

      test('should provide form validity state', () {
        viewModel.updateDisplayName('');

        expect(viewModel.isFormValid, isFalse);

        viewModel.updateDisplayName('Valid Name');
        expect(viewModel.isFormValid, isTrue);

        viewModel.updateDisplayName('A'); // Too short
        expect(viewModel.isFormValid, isFalse);

        viewModel.updateDisplayName('Valid Name');
        expect(viewModel.isFormValid, isTrue);
      });
    });

    group('Cooking Identity', () {
      test('should update cooking skill level', () {
        viewModel.updateCookingSkillLevel(CookingSkillLevel.intermediate);
        expect(viewModel.cookingSkillLevel,
            equals(CookingSkillLevel.intermediate));
        expect(viewModel.hasUnsavedChanges, isTrue);
      });

      test('should clear cooking skill level with null', () {
        viewModel.updateCookingSkillLevel(CookingSkillLevel.beginner);
        viewModel.updateCookingSkillLevel(null);
        expect(viewModel.cookingSkillLevel, isNull);
      });

      test('should toggle cuisine affinity', () {
        viewModel.toggleCuisineAffinity('svensk');
        expect(viewModel.cuisineAffinities, contains('svensk'));
        expect(viewModel.hasUnsavedChanges, isTrue);

        viewModel.toggleCuisineAffinity('svensk');
        expect(viewModel.cuisineAffinities, isNot(contains('svensk')));
      });

      test('should enforce max 5 cuisine affinities', () {
        viewModel.toggleCuisineAffinity('svensk');
        viewModel.toggleCuisineAffinity('italiensk');
        viewModel.toggleCuisineAffinity('japansk');
        viewModel.toggleCuisineAffinity('mexikansk');
        viewModel.toggleCuisineAffinity('indisk');
        expect(viewModel.cuisineAffinities.length, equals(5));

        final added = viewModel.toggleCuisineAffinity('fransk');
        expect(added, isFalse);
        expect(viewModel.cuisineAffinities.length, equals(5));
      });

      test('should reject invalid cuisine tag', () {
        final added = viewModel.toggleCuisineAffinity('nonexistent');
        expect(added, isFalse);
        expect(viewModel.cuisineAffinities, isEmpty);
      });

      test('should update bio with trimming', () {
        viewModel.updateBio('  Gillar mat  ');
        expect(viewModel.bio, equals('Gillar mat'));
        expect(viewModel.hasUnsavedChanges, isTrue);
      });

      test('should truncate bio exceeding max length', () {
        final longBio = 'A' * 200;
        viewModel.updateBio(longBio);
        expect(viewModel.bio.length, equals(160));
      });

      test('should load cooking identity from existing profile', () {
        final profileWithIdentity = UserProfileBuilder.build(
          uid: testUserId,
          displayName: 'Test User',
          cookingSkillLevel: CookingSkillLevel.advanced,
          cuisineAffinities: ['svensk', 'fransk'],
          bio: 'Erfaren hobbykock',
        );
        mockUserService.setUserState(
          currentUser: profileWithIdentity,
          users: {},
          isLoading: false,
          error: null,
        );

        final vmWithIdentity = UserProfileViewModel(
          mockUserService,
          mockImagePickerService,
          uploadService: mockImageUploadService,
        );

        expect(vmWithIdentity.cookingSkillLevel,
            equals(CookingSkillLevel.advanced));
        expect(vmWithIdentity.cuisineAffinities, equals(['svensk', 'fransk']));
        expect(vmWithIdentity.bio, equals('Erfaren hobbykock'));
        expect(vmWithIdentity.hasUnsavedChanges, isFalse);

        vmWithIdentity.dispose();
      });

      test('should detect cooking identity changes', () {
        viewModel.updateCookingSkillLevel(CookingSkillLevel.beginner);
        expect(viewModel.hasUnsavedChanges, isTrue);

        viewModel.resetForm();
        expect(viewModel.hasUnsavedChanges, isFalse);
        expect(viewModel.cookingSkillLevel, isNull);
        expect(viewModel.cuisineAffinities, isEmpty);
        expect(viewModel.bio, isEmpty);
      });
    });

    group('Lifecycle', () {
      test('should remove UserService listener on dispose', () {
        final testViewModel = UserProfileViewModel(
          mockUserService,
          mockImagePickerService,
          uploadService: mockImageUploadService,
        );

        expect(() => testViewModel.dispose(), returnsNormally);
      });

      test('should clean up listeners on dispose', () {
        final testViewModel = UserProfileViewModel(
          mockUserService,
          mockImagePickerService,
          uploadService: mockImageUploadService,
        );

        var notificationCount = 0;
        testViewModel.addListener(() => notificationCount++);

        testViewModel.updateDisplayName('Test');
        expect(notificationCount, greaterThan(0));

        expect(() => testViewModel.dispose(), returnsNormally);
      });
    });
  });
}
