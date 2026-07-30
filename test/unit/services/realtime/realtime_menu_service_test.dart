/// Unit tests for RealtimeMenuService
///
/// Tests real-time menu management including creation, watching, content operations,
/// participant management, and error handling.
// ignore_for_file: close_sinks
library;

import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:butlery/services/realtime/realtime_menu_service.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/services/user_service.dart';
import 'package:butlery/core/l10n/app_locale.dart';
import 'package:butlery/models/realtime/realtime_menu.dart';
import 'package:butlery/models/realtime/realtime_resource.dart';
import 'package:butlery/models/realtime/realtime_menu_data.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/permissions/resource_permission.dart';
import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart' as production;
import '../../../test_support/base_unit_test.dart';
import '../../../infrastructure/di/test_service_locator.dart';
import '../../../infrastructure/mocks/production_mocks.dart';
import '../../../infrastructure/factories/recipe_factory.dart';
import '../../../infrastructure/factories/mock_factory.dart';
import 'package:butlery/services/realtime/modules/menu_operations.dart';
import 'package:get_it/get_it.dart';

class TestRealtimeMenu extends RealtimeMenu {
  TestRealtimeMenu({
    required super.id,
    required String menuTitle,
    required super.ownerId,
    String? ownerDisplayName,
    Map<String, List<Recipe>>? menuSnapshot,
    Map<String, ResourcePermission>? participants,
    DateTime? createdAt,
    DateTime? lastEditedAt,
    super.editCount = 0,
  }) : super(
         ownerDisplayName: ownerDisplayName ?? 'Test Owner',
         participants: participants ?? {ownerId: ResourcePermission.owner},
         createdAt: createdAt ?? DateTime.now(),
         lastEditedAt: lastEditedAt ?? DateTime.now(),
         lastEditedBy: ownerId,
         lastEditedByDisplayName: ownerDisplayName ?? 'Test Owner',
         data: RealtimeMenuData(
           menuTitle: menuTitle,
           menuSnapshot: menuSnapshot ?? {},
           createdForDate: DateTime.now(),
         ),
       );
}

/// BUT-1736: keeps the two name sources apart so a test can prove WHICH one
/// gets persisted. `profileName` is the name the user chose and the profile
/// document stores; the Firebase Auth handle is modelled by
/// `FakePermissionService.currentUser.displayName` (`'Auth Handle'` below),
/// since production's `PermissionService.currentUser` is synthesized from
/// `FirebaseAuth.currentUser`.
class _FakeUserService extends Fake implements UserService {
  String? profileName = 'Profil Malin';

  @override
  String? get profileDisplayName => profileName;
}

void main() {
  late RealtimeMenuService service;
  late MockRealtimeSyncService mockSyncService;
  late MockAuthService mockAuthService;
  late FakePermissionService mockPermissionService;
  late _FakeUserService fakeUserService;

  setUpAll(() async {
    await BaseUnitTest.setupUnit();
    await TestServiceLocator.initialize();
    registerFallbackValue(RealtimeResourceType.menu);
    registerFallbackValue(ResourcePermission.viewer);
    registerFallbackValue(
      TestRealtimeMenu(
        id: 'fallback',
        menuTitle: 'Fallback Menu',
        ownerId: 'test_user',
      ),
    );
  });

  setUp(() async {
    // Bridge production ServiceLocator for internal ServiceLocator.get<PermissionService>()
    production.ServiceLocator.initialize(DIContainer());

    mockSyncService = MockRealtimeSyncService();
    mockAuthService = MockAuthService();
    mockPermissionService = FakePermissionService();

    mockAuthService.setAuthState(
      isAuthenticated: true,
      currentUser: MockFactory.createMockUser(uid: 'test_user_123'),
    );
    // 'Auth Handle' stands in for the Firebase Auth display name: this fake's
    // `currentUser` is what production synthesizes from `FirebaseAuth`. A menu
    // stamped with it would be the BUT-1736 regression.
    mockPermissionService.setPermissionState(
      currentUserId: 'test_user_123',
      defaultHasPermission: true,
      userDisplayName: 'Auth Handle',
    );
    mockSyncService.setConnectionState(true);
    mockSyncService.setInitialized(true);

    // Stub fetchLatestResource to return null (falls through to cache)
    when(
      () => mockSyncService.fetchLatestResource<RealtimeMenu>(any()),
    ).thenAnswer((_) async => null);

    // Register PermissionService so ServiceLocator.get<PermissionService>() works
    if (GetIt.instance.isRegistered<PermissionService>()) {
      GetIt.instance.unregister<PermissionService>();
    }
    GetIt.instance.registerSingleton<PermissionService>(mockPermissionService);

    // BUT-1736: the persisted display name now resolves through UserService.
    fakeUserService = _FakeUserService();
    if (GetIt.instance.isRegistered<UserService>()) {
      GetIt.instance.unregister<UserService>();
    }
    GetIt.instance.registerSingleton<UserService>(fakeUserService);

    service = RealtimeMenuService(
      syncService: mockSyncService,
      authService: mockAuthService,
    );
  });

  tearDown(() async {
    mockSyncService.disposeStreams();
    service.dispose();
    await TestServiceLocator.reset();
    BaseUnitTest.resetMocks();
  });

  tearDownAll(() async {
    await BaseUnitTest.teardownUnit();
  });

  group('State Management', () {
    test('should initialize with default state', () {
      expect(service.isProcessing, isFalse);
      expect(service.lastError, isNull);
      expect(service.categoryNames, isEmpty);
    });

    test('should track processing state during operations', () async {
      when(
        () => mockSyncService.updateResource<RealtimeMenu>(any()),
      ).thenAnswer((_) async {});

      expect(service.isProcessing, isFalse);
      final future = service.createRealtimeMenu(
        menuTitle: 'Test Menu',
        menuSnapshot: {'Monday': []},
      );
      expect(service.isProcessing, isTrue);
      await future;
      expect(service.isProcessing, isFalse);
    });

    test('should handle error state management', () async {
      when(
        () => mockSyncService.updateResource<RealtimeMenu>(any()),
      ).thenAnswer((_) async => throw Exception('Sync failed'));

      try {
        await service.createRealtimeMenu(
          menuTitle: 'Test',
          menuSnapshot: {'Monday': []},
        );
      } catch (_) {}

      expect(service.lastError, isNotNull);
      service.clearError();
      expect(service.lastError, isNull);
    });
  });

  group('Menu Creation', () {
    test('should create realtime menu from categories', () async {
      final recipes = [
        RecipeFactory.build(id: 'recipe_1', title: 'Kottbullar'),
        RecipeFactory.build(id: 'recipe_2', title: 'Pasta'),
      ];
      final menuSnapshot = {
        'Monday': [recipes[0]],
        'Tuesday': [recipes[1]],
      };

      when(
        () => mockSyncService.updateResource<RealtimeMenu>(any()),
      ).thenAnswer((_) async {});

      final result = await service.createRealtimeMenu(
        menuTitle: 'Veckomeny',
        menuSnapshot: menuSnapshot,
        editorUserIds: ['editor_1'],
        viewerUserIds: ['viewer_1'],
      );

      expect(result, isA<RealtimeMenu>());
      expect(result.menuTitle, equals('Veckomeny'));
      expect(result.ownerId, equals('test_user_123'));
      verify(
        () => mockSyncService.updateResource<RealtimeMenu>(any()),
      ).called(1);
    });

    test('should throw when user not authenticated', () async {
      mockAuthService.setAuthState(isAuthenticated: false, currentUser: null);

      expect(
        () => service.createRealtimeMenu(
          menuTitle: 'Test',
          menuSnapshot: {},
        ),
        throwsA(isA<MenuOperationError>()),
      );
    });

    test('should cache menu after creation', () async {
      when(
        () => mockSyncService.updateResource<RealtimeMenu>(any()),
      ).thenAnswer((_) async {});

      await service.createRealtimeMenu(
        menuTitle: 'Cached Menu',
        menuSnapshot: {'Monday': []},
      );

      expect(service.categoryNames, equals(['Monday']));
    });
  });

  group('Real-time Watching', () {
    test('should watch menu with stream updates', () async {
      final testMenu = TestRealtimeMenu(
        id: 'menu_123',
        menuTitle: 'Streaming Menu',
        ownerId: 'test_user_123',
      );

      final streamController = StreamController<RealtimeMenu>.broadcast();
      when(
        () => mockSyncService.watchResource<RealtimeMenu>('menu_123'),
      ).thenAnswer((_) => streamController.stream);

      final stream = service.watchRealtimeMenu('menu_123');

      // Start listening first, then add item
      final future = expectLater(
        stream,
        emits(
          isA<RealtimeMenu>()
              .having((m) => m.id, 'id', 'menu_123')
              .having((m) => m.menuTitle, 'title', 'Streaming Menu'),
        ),
      );
      streamController.add(testMenu);
      await future;
    });
  });

  group('Menu Content Operations', () {
    final testMenuId = 'menu_123';
    late TestRealtimeMenu testMenu;

    setUp(() {
      testMenu = TestRealtimeMenu(
        id: testMenuId,
        menuTitle: 'Test Menu',
        ownerId: 'test_user_123',
        menuSnapshot: {
          'Monday': [RecipeFactory.build(id: 'r1', title: 'Recipe 1')],
          'Tuesday': [RecipeFactory.build(id: 'r2', title: 'Recipe 2')],
        },
      );
      mockSyncService.setCachedResource(testMenuId, testMenu);
    });

    test('should update basic menu information', () async {
      when(
        () => mockSyncService.updateResource<RealtimeMenu>(any()),
      ).thenAnswer((_) async {});

      await service.updateBasicInfo(
        resourceId: testMenuId,
        menuTitle: 'Updated Menu',
      );

      verify(
        () => mockSyncService.updateResource<RealtimeMenu>(any()),
      ).called(1);
    });

    test('should add recipe to category', () async {
      final newRecipe = RecipeFactory.build(id: 'r3', title: 'New');
      when(
        () => mockSyncService.updateResource<RealtimeMenu>(any()),
      ).thenAnswer((_) async {});

      await service.addRecipeToCategory(
        resourceId: testMenuId,
        categoryName: 'Monday',
        recipe: newRecipe,
      );

      verify(
        () => mockSyncService.updateResource<RealtimeMenu>(any()),
      ).called(1);
    });

    test('should validate permissions for edits', () async {
      // Replace with a menu owned by someone else where test_user_123 is only a viewer
      final restrictedMenu = TestRealtimeMenu(
        id: testMenuId,
        menuTitle: 'Restricted Menu',
        ownerId: 'other_owner',
        participants: {
          'other_owner': ResourcePermission.owner,
          'test_user_123': ResourcePermission.viewer,
        },
      );
      mockSyncService.setCachedResource(testMenuId, restrictedMenu);

      await expectLater(
        () => service.updateBasicInfo(
          resourceId: testMenuId,
          menuTitle: 'Fail',
        ),
        throwsA(isA<MenuOperationError>()),
      );
    });

    test('should handle missing menu error', () async {
      expect(
        () => service.updateBasicInfo(
          resourceId: 'nonexistent',
          menuTitle: 'Fail',
        ),
        throwsA(isA<MenuOperationError>()),
      );
    });
  });

  group('Participant Management', () {
    final testMenuId = 'menu_123';

    setUp(() {
      // Include an existing participant so remove tests work
      final testMenu = TestRealtimeMenu(
        id: testMenuId,
        menuTitle: 'Test Menu',
        ownerId: 'test_user_123',
        participants: {
          'test_user_123': ResourcePermission.owner,
          'user_to_remove': ResourcePermission.editor,
        },
      );
      mockSyncService.setCachedResource(testMenuId, testMenu);
    });

    test('should add participant', () async {
      when(
        () => mockSyncService.updateResource<RealtimeMenu>(any()),
      ).thenAnswer((_) async {});

      await service.addParticipant(
        resourceId: testMenuId,
        userId: 'new_user',
        userDisplayName: 'New User',
        permission: ResourcePermission.editor,
      );

      verify(
        () => mockSyncService.updateResource<RealtimeMenu>(any()),
      ).called(1);
    });

    test('should remove participant', () async {
      when(
        () => mockSyncService.updateResource<RealtimeMenu>(any()),
      ).thenAnswer((_) async {});

      await service.removeParticipant(
        resourceId: testMenuId,
        userId: 'user_to_remove',
      );

      verify(
        () => mockSyncService.updateResource<RealtimeMenu>(any()),
      ).called(1);
    });

    test('should require edit permission for management', () async {
      // Use a menu owned by someone else where test_user_123 is only a viewer
      final restrictedMenu = TestRealtimeMenu(
        id: testMenuId,
        menuTitle: 'Restricted Menu',
        ownerId: 'other_owner',
        participants: {
          'other_owner': ResourcePermission.owner,
          'test_user_123': ResourcePermission.viewer,
        },
      );
      mockSyncService.setCachedResource(testMenuId, restrictedMenu);

      await expectLater(
        () => service.addParticipant(
          resourceId: testMenuId,
          userId: 'new_user',
          userDisplayName: 'New',
          permission: ResourcePermission.viewer,
        ),
        throwsA(isA<MenuOperationError>()),
      );
    });
  });

  group('Delete Operation', () {
    test('should delete realtime menu', () async {
      when(
        () => mockSyncService.deleteResource(
          'menu_123',
          RealtimeResourceType.menu,
        ),
      ).thenAnswer((_) async {});

      await service.deleteRealtimeMenu('menu_123');

      verify(
        () => mockSyncService.deleteResource(
          'menu_123',
          RealtimeResourceType.menu,
        ),
      ).called(1);
    });

    test('should require authentication for delete', () async {
      mockAuthService.setAuthState(isAuthenticated: false, currentUser: null);

      expect(
        () => service.deleteRealtimeMenu('menu_123'),
        throwsA(isA<MenuOperationError>()),
      );
    });
  });

  group('Utility Operations', () {
    test('should create personal copy of menu', () {
      final testMenu = TestRealtimeMenu(
        id: 'menu_123',
        menuTitle: 'Test Menu',
        ownerId: 'test_user_123',
        menuSnapshot: {
          'Monday': [RecipeFactory.build(id: 'r1', title: 'Recipe 1')],
        },
      );

      final copy = service.createPersonalCopy(testMenu);
      expect(copy, isA<Map<String, List<Recipe>>>());
      expect(copy.containsKey('Monday'), isTrue);
      expect(copy['Monday']!.length, equals(1));
    });

    test('should check if menu changed since timestamp', () {
      final testMenu = TestRealtimeMenu(
        id: 'menu_123',
        menuTitle: 'Test',
        ownerId: 'test_user_123',
        lastEditedAt: DateTime(2024, 1, 15, 10, 30),
      );

      expect(
        service.hasMenuChangedSince(testMenu, DateTime(2024, 1, 15, 9, 0)),
        isTrue,
      );
      expect(
        service.hasMenuChangedSince(testMenu, DateTime(2024, 1, 15, 11, 0)),
        isFalse,
      );
    });
  });

  group('Persisted display name comes from the profile (BUT-1736)', () {
    const testMenuId = 'menu_123';

    test(
      'createRealtimeMenu stamps the profile name, not the Auth handle',
      () async {
        RealtimeMenu? captured;
        when(
          () => mockSyncService.updateResource<RealtimeMenu>(any()),
        ).thenAnswer((invocation) async {
          captured = invocation.positionalArguments[0] as RealtimeMenu;
        });

        await service.createRealtimeMenu(
          menuTitle: 'Veckomeny',
          menuSnapshot: {'Monday': []},
        );

        expect(captured, isNotNull);
        expect(captured!.ownerDisplayName, equals('Profil Malin'));
        expect(captured!.lastEditedByDisplayName, equals('Profil Malin'));
      },
    );

    test(
      'an edit stamps the profile name as lastEditedByDisplayName',
      () async {
        mockSyncService.setCachedResource(
          testMenuId,
          TestRealtimeMenu(
            id: testMenuId,
            menuTitle: 'Test Menu',
            ownerId: 'test_user_123',
          ),
        );

        RealtimeMenu? captured;
        when(
          () => mockSyncService.updateResource<RealtimeMenu>(any()),
        ).thenAnswer((invocation) async {
          captured = invocation.positionalArguments[0] as RealtimeMenu;
        });

        await service.updateBasicInfo(
          resourceId: testMenuId,
          menuTitle: 'Uppdaterad',
        );

        expect(captured, isNotNull);
        expect(captured!.lastEditedByDisplayName, equals('Profil Malin'));
      },
    );

    test(
      'an unloaded profile stamps the unknown-user label, never the Auth handle',
      () async {
        // Cold start: the profile document has not arrived yet, while the Auth
        // handle IS available. Before BUT-1736 that stamped 'Auth Handle'.
        fakeUserService.profileName = null;

        RealtimeMenu? captured;
        when(
          () => mockSyncService.updateResource<RealtimeMenu>(any()),
        ).thenAnswer((invocation) async {
          captured = invocation.positionalArguments[0] as RealtimeMenu;
        });

        await service.createRealtimeMenu(
          menuTitle: 'Veckomeny',
          menuSnapshot: {'Monday': []},
        );

        expect(captured, isNotNull);
        expect(captured!.ownerDisplayName, isNot(equals('Auth Handle')));
        expect(
          captured!.ownerDisplayName,
          equals(AppLocale.current.displayUnknownUser),
        );
      },
    );
  });

  group('Error Scenarios', () {
    test('should handle unauthenticated user errors', () async {
      mockAuthService.setAuthState(isAuthenticated: false, currentUser: null);

      expect(
        () => service.createRealtimeMenu(menuTitle: 'Test', menuSnapshot: {}),
        throwsA(isA<MenuOperationError>()),
      );
    });

    test('should handle permission denied errors', () async {
      final testMenu = TestRealtimeMenu(
        id: 'menu_123',
        menuTitle: 'Test',
        ownerId: 'other_user',
      );
      mockSyncService.setCachedResource('menu_123', testMenu);
      mockPermissionService.setPermissionState(
        currentUserId: 'test_user_123',
        defaultHasPermission: false,
        permissions: {
          'menu_123': {ResourcePermission.editor: false},
        },
      );

      expect(
        () => service.addRecipeToCategory(
          resourceId: 'menu_123',
          categoryName: 'Monday',
          recipe: RecipeFactory.build(),
        ),
        throwsA(isA<MenuOperationError>()),
      );
    });

    test('should handle sync failures', () async {
      final testMenu = TestRealtimeMenu(
        id: 'menu_123',
        menuTitle: 'Test',
        ownerId: 'test_user_123',
      );
      mockSyncService.setCachedResource('menu_123', testMenu);

      when(
        () => mockSyncService.updateResource<RealtimeMenu>(any()),
      ).thenAnswer((_) async => throw Exception('Network error'));

      await expectLater(
        () => service.updateBasicInfo(
          resourceId: 'menu_123',
          menuTitle: 'Fail',
        ),
        throwsA(isA<Exception>()),
      );
      expect(service.lastError, isNotNull);
    });
  });
}
