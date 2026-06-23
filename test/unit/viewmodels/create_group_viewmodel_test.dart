import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:butlery/viewmodels/create_group_viewmodel.dart';
import 'package:butlery/models/friend_category.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/services/unified/unified_friends_service.dart';
import 'package:butlery/services/unified/operations/friend_categories_operations.dart';
import 'package:butlery/services/unified/operations/friends_management_operations.dart';
import 'package:butlery/services/unified/operations/friends_invitations_operations.dart';

import '../../test_support/base_unit_test.dart';
import '../../infrastructure/di/test_service_locator.dart';
import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart' as production;

// Local pure-Mock classes — the centralized mocks have concrete @override
// methods (getCategoryByName, createCategory, getFriendById) that prevent
// mocktail stubbing with when().
class _MockFriendsService extends Mock implements UnifiedFriendsService {}

class _MockCategoriesOps extends Mock implements FriendsCategoriesOperations {}

class _MockManagementOps extends Mock implements FriendsManagementOperations {}

class _MockInvitationsOps extends Mock
    implements FriendsInvitationsOperations {}

FriendCategory _cat({
  String? id,
  String? name,
  String? description,
  String? emoji,
}) {
  final now = DateTime.now();
  return FriendCategory(
    id: id ?? 'cat_${now.millisecondsSinceEpoch}',
    name: name ?? 'Test Grupp',
    description: description,
    emoji: emoji ?? '\u{1F465}',
    ownerId: 'test_user_123',
    friendUserIds: [],
    createdAt: now,
    updatedAt: now,
  );
}

UserProfile _profile({String? uid, String? displayName, String? email}) {
  final now = DateTime.now();
  return UserProfile(
    uid: uid ?? 'user_${now.millisecondsSinceEpoch}',
    displayName: displayName ?? 'Test User',
    email: email ?? 'test@example.com',
    joinedAt: now,
    lastActiveAt: now,
    isOnline: false,
  );
}

void main() {
  group('CreateGroupViewModel', () {
    late CreateGroupViewModel viewModel;
    late _MockFriendsService mockFriendsService;
    late _MockCategoriesOps mockCategoriesOps;
    late _MockManagementOps mockManagementOps;
    late _MockInvitationsOps mockInvitationsOps;

    final testFriend1 = _profile(
      uid: 'friend_123',
      displayName: 'Anna Andersson',
      email: 'anna@example.com',
    );

    final testFriend2 = _profile(
      uid: 'friend_456',
      displayName: 'Erik Svensson',
      email: 'erik@example.com',
    );

    final testFriend3 = _profile(
      uid: 'friend_789',
      displayName: 'Maria Oberg',
      email: '',
    );

    final existingCategory = _cat(
      id: 'existing_category',
      name: 'Existerande Grupp',
      description: 'En grupp som redan finns',
    );

    setUpAll(() async {
      await BaseUnitTest.setupUnit();
      await TestServiceLocator.initialize();
      production.ServiceLocator.initialize(DIContainer());
      registerFallbackValue(_cat());
      registerFallbackValue(_profile());
    });

    setUp(() {
      mockFriendsService = _MockFriendsService();
      mockCategoriesOps = _MockCategoriesOps();
      mockManagementOps = _MockManagementOps();
      mockInvitationsOps = _MockInvitationsOps();

      when(() => mockFriendsService.categories).thenReturn(mockCategoriesOps);
      when(() => mockFriendsService.management).thenReturn(mockManagementOps);
      when(() => mockFriendsService.invitations).thenReturn(mockInvitationsOps);
      when(() => mockFriendsService.error).thenReturn(null);
      when(() => mockCategoriesOps.getCategoryByName(any())).thenReturn(null);
      when(
        () => mockCategoriesOps.getAllCategories(),
      ).thenReturn([existingCategory]);
      when(
        () => mockCategoriesOps.createCategory(
          name: any(named: 'name'),
          description: any(named: 'description'),
          icon: any(named: 'icon'),
          initialMemberIds: any(named: 'initialMemberIds'),
        ),
      ).thenAnswer((_) async => 'new_category_123');
      when(() => mockManagementOps.getFriendById(any())).thenReturn(null);
      when(
        () => mockInvitationsOps.sendEmailInvitation(
          email: any(named: 'email'),
          customMessage: any(named: 'customMessage'),
        ),
      ).thenAnswer((_) async => true);

      viewModel = CreateGroupViewModel(
        friendsService: mockFriendsService,
      );
    });

    tearDown(() {
      viewModel.dispose();
      BaseUnitTest.resetMocks();
    });

    tearDownAll(() async {
      await TestServiceLocator.reset();
      await BaseUnitTest.teardownUnit();
    });

    group('Initialization', () {
      test('should initialize with default values', () {
        expect(viewModel.name, isEmpty);
        expect(viewModel.description, isEmpty);
        expect(viewModel.emoji, equals('\u{1F465}'));
        expect(viewModel.selectedFriendIds, isEmpty);
        expect(viewModel.selectedFriendsCount, equals(0));
        expect(viewModel.isLoading, isFalse);
        expect(viewModel.error, isNull);
        expect(viewModel.nameError, isNull);
        expect(viewModel.isValid, isFalse);
      });
    });

    group('Form Input Management', () {
      test('should update name and validate', () {
        viewModel.updateName('Receptgruppen');

        expect(viewModel.name, equals('Receptgruppen'));
        expect(viewModel.nameError, isNull);
        expect(viewModel.isValid, isTrue);
      });

      test('should update description', () {
        viewModel.updateDescription('En grupp');

        expect(viewModel.description, equals('En grupp'));
      });

      test('should update emoji', () {
        viewModel.updateEmoji('\u{1F957}');

        expect(viewModel.emoji, equals('\u{1F957}'));
      });

      test('should toggle friend selection', () {
        viewModel.toggleFriend('friend_123');

        expect(viewModel.selectedFriendIds.contains('friend_123'), isTrue);
        expect(viewModel.selectedFriendsCount, equals(1));

        viewModel.toggleFriend('friend_123');

        expect(viewModel.selectedFriendIds.contains('friend_123'), isFalse);
        expect(viewModel.selectedFriendsCount, equals(0));
      });

      test('should handle multiple friend selections', () {
        viewModel.toggleFriend('friend_123');
        viewModel.toggleFriend('friend_456');
        viewModel.toggleFriend('friend_789');

        expect(viewModel.selectedFriendsCount, equals(3));
        expect(
          viewModel.selectedFriendIds,
          containsAll(['friend_123', 'friend_456', 'friend_789']),
        );
      });

      test('should notify listeners on input changes', () {
        int notificationCount = 0;
        viewModel.addListener(() => notificationCount++);

        viewModel.updateName('Test');
        viewModel.updateDescription('Description');
        viewModel.updateEmoji('\u{1F389}');
        viewModel.toggleFriend('friend_123');

        expect(notificationCount, equals(4));
      });
    });

    group('Name Validation', () {
      test('should require non-empty name', () {
        viewModel.updateName('');

        expect(viewModel.nameError, equals('Gruppnamn kr\u00e4vs'));
        expect(viewModel.isValid, isFalse);
      });

      test('should reject whitespace-only name', () {
        viewModel.updateName('   ');

        expect(viewModel.nameError, equals('Gruppnamn kr\u00e4vs'));
        expect(viewModel.isValid, isFalse);
      });

      test('should detect duplicate group names', () {
        when(
          () => mockCategoriesOps.getCategoryByName('Existerande Grupp'),
        ).thenReturn(existingCategory);

        viewModel.updateName('Existerande Grupp');

        expect(
          viewModel.nameError,
          equals('Det h\u00e4r gruppnamnet finns redan'),
        );
        expect(viewModel.isValid, isFalse);
      });

      test('should trim name for validation', () {
        viewModel.updateName('  Ny Grupp  ');

        expect(viewModel.name, equals('  Ny Grupp  '));
        expect(viewModel.nameError, isNull);
        expect(viewModel.isValid, isTrue);
      });

      test('should handle Swedish characters in name', () {
        viewModel.updateName('\u00c5sa \u00c4ngstr\u00f6ms \u00d6rter');

        expect(
          viewModel.name,
          equals('\u00c5sa \u00c4ngstr\u00f6ms \u00d6rter'),
        );
        expect(viewModel.nameError, isNull);
        expect(viewModel.isValid, isTrue);
      });

      test('should clear error when valid name entered', () {
        viewModel.updateName('');
        expect(viewModel.nameError, isNotNull);

        viewModel.updateName('Valid Name');

        expect(viewModel.nameError, isNull);
        expect(viewModel.isValid, isTrue);
      });
    });

    group('Group Creation', () {
      setUp(() {
        viewModel.updateName('Receptgruppen');
        viewModel.updateDescription('En grupp');
        viewModel.updateEmoji('\u{1F373}');
      });

      test('should create group successfully', () async {
        final newCategory = _cat(
          id: 'new_category_123',
          name: 'Receptgruppen',
          description: 'En grupp',
          emoji: '\u{1F373}',
        );

        when(
          () => mockCategoriesOps.getAllCategories(),
        ).thenReturn([existingCategory, newCategory]);

        final result = await viewModel.createGroup();

        expect(result, isTrue);
        expect(viewModel.error, isNull);
        expect(viewModel.isLoading, isFalse);

        verify(
          () => mockCategoriesOps.createCategory(
            name: 'Receptgruppen',
            description: 'En grupp',
            icon: '\u{1F373}',
            initialMemberIds: null,
          ),
        ).called(1);
      });

      test('should not create group with invalid form', () async {
        viewModel.updateName('');

        final result = await viewModel.createGroup();

        expect(result, isFalse);
        expect(viewModel.error, isNull);

        verifyNever(
          () => mockCategoriesOps.createCategory(
            name: any(named: 'name'),
            description: any(named: 'description'),
            icon: any(named: 'icon'),
            initialMemberIds: any(named: 'initialMemberIds'),
          ),
        );
      });

      test('should handle group creation failure', () async {
        when(
          () => mockCategoriesOps.createCategory(
            name: any(named: 'name'),
            description: any(named: 'description'),
            icon: any(named: 'icon'),
            initialMemberIds: any(named: 'initialMemberIds'),
          ),
        ).thenAnswer((_) async => null);

        when(() => mockFriendsService.error).thenReturn('Network error');

        final result = await viewModel.createGroup();

        expect(result, isFalse);
        expect(viewModel.error, equals('Kunde inte skapa grupp'));
        expect(viewModel.isLoading, isFalse);
      });

      test('should handle missing created group', () async {
        when(
          () => mockCategoriesOps.getAllCategories(),
        ).thenReturn([existingCategory]);

        final result = await viewModel.createGroup();

        expect(result, isFalse);
        expect(viewModel.error, equals('Kunde inte skapa grupp'));
      });

      test('should set loading state during creation', () async {
        bool wasCreating = false;
        viewModel.addListener(() {
          if (viewModel.isLoading) wasCreating = true;
        });

        final newCategory = _cat(
          id: 'new_category_123',
          name: 'Receptgruppen',
        );

        when(
          () => mockCategoriesOps.getAllCategories(),
        ).thenReturn([existingCategory, newCategory]);

        await viewModel.createGroup();

        expect(wasCreating, isTrue);
        expect(viewModel.isLoading, isFalse);
      });

      test('should handle exception during creation', () async {
        when(
          () => mockCategoriesOps.createCategory(
            name: any(named: 'name'),
            description: any(named: 'description'),
            icon: any(named: 'icon'),
            initialMemberIds: any(named: 'initialMemberIds'),
          ),
        ).thenThrow(Exception('Database error'));

        final result = await viewModel.createGroup();

        expect(result, isFalse);
        expect(viewModel.error, contains('Kunde inte skapa grupp'));
        expect(viewModel.isLoading, isFalse);
      });
    });

    group('Invitation Sending', () {
      late FriendCategory createdCategory;

      setUp(() {
        viewModel.updateName('Receptgruppen');
        viewModel.toggleFriend('friend_123');
        viewModel.toggleFriend('friend_456');
        viewModel.toggleFriend('friend_789');
        when(
          () => mockManagementOps.getFriendById('friend_123'),
        ).thenReturn(testFriend1);
        when(
          () => mockManagementOps.getFriendById('friend_456'),
        ).thenReturn(testFriend2);
        when(
          () => mockManagementOps.getFriendById('friend_789'),
        ).thenReturn(testFriend3);
        createdCategory = _cat(id: 'new_category_123', name: 'Receptgruppen');
        when(
          () => mockCategoriesOps.getAllCategories(),
        ).thenReturn([existingCategory, createdCategory]);
      });

      test('should send invitations to friends with emails', () async {
        final result = await viewModel.createGroup();
        expect(result, isTrue);
        verify(
          () => mockInvitationsOps.sendEmailInvitation(
            email: 'anna@example.com',
            customMessage: any(named: 'customMessage'),
          ),
        ).called(1);
        verify(
          () => mockInvitationsOps.sendEmailInvitation(
            email: 'erik@example.com',
            customMessage: any(named: 'customMessage'),
          ),
        ).called(1);
        verifyNever(
          () => mockInvitationsOps.sendEmailInvitation(
            email: '',
            customMessage: any(named: 'customMessage'),
          ),
        );
      });

      test('should handle invitation sending failures', () async {
        when(
          () => mockInvitationsOps.sendEmailInvitation(
            email: any(named: 'email'),
            customMessage: any(named: 'customMessage'),
          ),
        ).thenAnswer((_) async => false);
        final result = await viewModel.createGroup();
        expect(result, isTrue);
        expect(viewModel.error, isNull);
      });

      test('should handle friends not found', () async {
        when(() => mockManagementOps.getFriendById(any())).thenReturn(null);
        final result = await viewModel.createGroup();
        expect(result, isTrue);
        verifyNever(
          () => mockInvitationsOps.sendEmailInvitation(
            email: any(named: 'email'),
            customMessage: any(named: 'customMessage'),
          ),
        );
      });

      test('should skip invitations when no friends selected', () async {
        viewModel.toggleFriend('friend_123');
        viewModel.toggleFriend('friend_456');
        viewModel.toggleFriend('friend_789');
        expect(viewModel.selectedFriendsCount, equals(0));
        final result = await viewModel.createGroup();
        expect(result, isTrue);
        verifyNever(
          () => mockInvitationsOps.sendEmailInvitation(
            email: any(named: 'email'),
            customMessage: any(named: 'customMessage'),
          ),
        );
      });
    });

    group('Edge Cases', () {
      test('should handle very long group name', () {
        final longName = 'A' * 200;
        viewModel.updateName(longName);

        expect(viewModel.name, equals(longName));
        expect(viewModel.nameError, isNull);
        expect(viewModel.isValid, isTrue);
      });

      test('should handle very long description', () {
        final longDescription = 'B' * 500;
        viewModel.updateDescription(longDescription);

        expect(viewModel.description, equals(longDescription));
      });

      test('should handle rapid friend selection toggles', () {
        for (int i = 0; i < 10; i++) {
          viewModel.toggleFriend('friend_123');
        }

        expect(viewModel.selectedFriendIds.contains('friend_123'), isFalse);
      });
    });

    group('Lifecycle', () {
      test('should dispose without errors', () {
        final testViewModel = CreateGroupViewModel(
          friendsService: mockFriendsService,
        );

        expect(() => testViewModel.dispose(), returnsNormally);
      });

      test('should handle operations after dispose', () async {
        final testViewModel = CreateGroupViewModel(
          friendsService: mockFriendsService,
        );

        testViewModel.dispose();

        expect(() => testViewModel.updateName('Test'), throwsFlutterError);
        expect(
          () => testViewModel.updateDescription('Test'),
          throwsFlutterError,
        );
        expect(
          () => testViewModel.updateEmoji('\u{1F389}'),
          throwsFlutterError,
        );
        expect(
          () => testViewModel.toggleFriend('friend_123'),
          throwsFlutterError,
        );

        expect(testViewModel.createGroup(), completion(isFalse));
      });
    });
  });
}
