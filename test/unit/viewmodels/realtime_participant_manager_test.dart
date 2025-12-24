// test/unit/viewmodels/realtime_participant_manager_test.dart

import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:butlery/viewmodels/realtime_menu/realtime_participant_manager.dart';
import 'package:butlery/services/realtime/realtime_menu_service.dart';
import 'package:butlery/viewmodels/realtime/participant_tracker.dart';
import 'package:butlery/models/permissions/resource_permission.dart';
import 'package:butlery/models/realtime/realtime_menu.dart';
import 'package:butlery/models/realtime/realtime_menu_data.dart';

import '../../infrastructure/di/test_service_locator.dart';
import '../../infrastructure/mocks/production_mocks.dart';
import '../../infrastructure/factories/mock_factory.dart';
import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart'
    as prod_locator;

// ULTRATHINK CONVERSION: Local mock classes removed - using centralized mocks

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('RealtimeParticipantManager - Ultrathink Enhanced Tests', () {
    late RealtimeParticipantManager participantManager;
    late RealtimeMenuService
        mockMenuService; // Using interface type for centralized mock
    late MockParticipantTracker mockParticipantTracker;
    late MockPermissionService mockPermissionService;

    // Test data
    const testMenuId = 'menu_123';
    const testCurrentUserId = 'current_user_123';
    const testParticipantUserId = 'participant_456';
    const testParticipantDisplayName = 'Test Participant';
    const testOwnerUserId = 'owner_789';
    const testViewerUserId = 'viewer_101';

    late RealtimeMenu testMenu;

    setUpAll(() async {
      await TestServiceLocator.initialize();
      registerFallbackValue(ResourcePermission.viewer);

      // Register fallback for RealtimeMenu
      registerFallbackValue(RealtimeMenu(
        id: 'fallback_menu',
        ownerId: 'fallback_owner',
        ownerDisplayName: 'Fallback Owner',
        participants: {},
        lastEditedBy: 'fallback_owner',
        lastEditedByDisplayName: 'Fallback Owner',
        data: RealtimeMenuData(
          menuTitle: 'Fallback Menu',
          createdForDate: DateTime.now(),
          menuSnapshot: {},
        ),
      ));
    });

    setUp(() {
      // ULTRATHINK FIX: Bridge production ServiceLocator to test mocks
      // This solves "ServiceLocator not initialized" errors when production code
      // calls ServiceLocator.get() but only TestServiceLocator was initialized
      final productionContainer = DIContainer();
      prod_locator.ServiceLocator.initialize(productionContainer);

      // Create mocks using centralized versions
      mockMenuService = MockFactory.createRealtimeMenuService();
      mockParticipantTracker = MockFactory.createParticipantTracker(
        activeCount: 2,
        onlineParticipants: [testCurrentUserId],
      );
      mockPermissionService = MockPermissionService();

      // Configure permission service using ultrathink state configuration
      mockPermissionService.setPermissionState(
        currentUserId: testCurrentUserId,
        userDisplayName: 'Current User',
        isAuthenticated: true,
        defaultHasPermission: true,
        permissions: {
          testMenuId: {
            ResourcePermission.editor: true,
            ResourcePermission.admin: true,
            ResourcePermission.owner: false,
          }
        },
      );

      // Note: Basic participant tracker properties configured by MockFactory.createParticipantTracker()
      // Configure method stubs for participant tracker
      when(() => mockParticipantTracker.updateDisplayName(any(), any()))
          .thenReturn(null);
      when(() => mockParticipantTracker.removeParticipant(any()))
          .thenReturn(null);
      when(() => mockParticipantTracker.updateFromMenu(any())).thenReturn(null);
      when(() => mockParticipantTracker.dispose()).thenReturn(null);

      // Configure default menu service behavior - success
      when(() => mockMenuService.addParticipant(
            resourceId: any(named: 'resourceId'),
            userId: any(named: 'userId'),
            userDisplayName: any(named: 'userDisplayName'),
            permission: any(named: 'permission'),
          )).thenAnswer((_) async {});

      when(() => mockMenuService.removeParticipant(
            resourceId: any(named: 'resourceId'),
            userId: any(named: 'userId'),
          )).thenAnswer((_) async {});

      when(() => mockMenuService.updateParticipantPermission(
            resourceId: any(named: 'resourceId'),
            userId: any(named: 'userId'),
            newPermission: any(named: 'newPermission'),
          )).thenAnswer((_) async {});

      // Create test menu
      final menuData = RealtimeMenuData(
        menuTitle: 'Test Menu',
        createdForDate: DateTime.now(),
        menuSnapshot: {},
      );

      testMenu = RealtimeMenu(
        id: testMenuId,
        ownerId: testOwnerUserId,
        ownerDisplayName: 'Owner User',
        participants: {
          testOwnerUserId: ResourcePermission.owner,
          testCurrentUserId: ResourcePermission.editor,
          testViewerUserId: ResourcePermission.viewer,
        },
        lastEditedBy: testCurrentUserId,
        lastEditedByDisplayName: 'Current User',
        data: menuData,
      );

      participantManager = RealtimeParticipantManager(
        menuService: mockMenuService,
        participantTracker: mockParticipantTracker,
        permissionService: mockPermissionService,
      );
    });

    tearDown(() async {
      participantManager.dispose();
      await TestServiceLocator.reset();
    });

    tearDownAll(() async {
      await TestServiceLocator.reset();
    });

    group('Initialization and Permission Getters', () {
      test('should initialize with correct dependencies', () {
        // Assert
        expect(participantManager, isNotNull);
        expect(participantManager.currentUserId, equals(testCurrentUserId));
      });

      test('should check edit permissions correctly', () {
        // Act
        final canEdit = participantManager.canEdit(testMenuId);

        // Assert
        expect(canEdit, isTrue);
      });

      test('should check manage participants permissions correctly', () {
        // Act
        final canManage = participantManager.canManageParticipants(testMenuId);

        // Assert
        expect(canManage, isTrue);
      });

      test('should check delete menu permissions correctly', () {
        // Act
        final canDelete = participantManager.canDeleteMenu(testMenuId);

        // Assert
        expect(canDelete, isTrue);
      });

      test('should handle null current user ID', () {
        // Arrange - reconfigure with null user
        mockPermissionService.setPermissionState(
          currentUserId: null,
          isAuthenticated: false,
        );

        // Act
        final userId = participantManager.currentUserId;

        // Assert
        expect(userId, isNull);
      });

      test('should handle insufficient permissions', () {
        // Arrange - reconfigure with no permissions
        mockPermissionService.setPermissionState(
          currentUserId: testCurrentUserId,
          isAuthenticated: true,
          defaultHasPermission: false,
          permissions: {
            testMenuId: {
              ResourcePermission.viewer: true,
              ResourcePermission.editor: false,
              ResourcePermission.admin: false,
              ResourcePermission.owner: false,
            }
          },
        );

        // Act
        final canEdit = participantManager.canEdit(testMenuId);
        final canManage = participantManager.canManageParticipants(testMenuId);
        final canDelete = participantManager.canDeleteMenu(testMenuId);

        // Assert
        expect(canEdit, isFalse);
        expect(canManage, isFalse);
        expect(canDelete, isFalse);
      });
    });

    group('Add Participant Operations', () {
      test('should add participant successfully', () async {
        // Act
        await participantManager.addParticipant(
          menuId: testMenuId,
          userId: testParticipantUserId,
          userDisplayName: testParticipantDisplayName,
          permission: ResourcePermission.viewer,
        );

        // Assert
        verify(() => mockMenuService.addParticipant(
              resourceId: testMenuId,
              userId: testParticipantUserId,
              userDisplayName: testParticipantDisplayName,
              permission: ResourcePermission.viewer,
            )).called(1);

        verify(() => mockParticipantTracker.updateDisplayName(
              testParticipantUserId,
              testParticipantDisplayName,
            )).called(1);
      });

      test('should throw error when lacking permission to add participant',
          () async {
        // Arrange - reconfigure with no invitation permissions
        mockPermissionService.setPermissionState(
          currentUserId: testCurrentUserId,
          isAuthenticated: true,
          defaultHasPermission: false,
          permissions: {
            testMenuId: {
              ResourcePermission.viewer: true,
              ResourcePermission.editor: false,
              ResourcePermission.admin: false,
            }
          },
        );

        // Act & Assert
        expect(
          () => participantManager.addParticipant(
            menuId: testMenuId,
            userId: testParticipantUserId,
            userDisplayName: testParticipantDisplayName,
            permission: ResourcePermission.viewer,
          ),
          throwsA(isA<Exception>().having(
              (e) => e.toString(), 'message', contains('Ingen behörighet'))),
        );

        verifyNever(() => mockMenuService.addParticipant(
              resourceId: any(named: 'resourceId'),
              userId: any(named: 'userId'),
              userDisplayName: any(named: 'userDisplayName'),
              permission: any(named: 'permission'),
            ));
      });

      test('should rethrow service error when adding participant fails',
          () async {
        // Arrange
        final serviceError = Exception('Service error');
        when(() => mockMenuService.addParticipant(
              resourceId: any(named: 'resourceId'),
              userId: any(named: 'userId'),
              userDisplayName: any(named: 'userDisplayName'),
              permission: any(named: 'permission'),
            )).thenThrow(serviceError);

        // Act & Assert
        expect(
          () => participantManager.addParticipant(
            menuId: testMenuId,
            userId: testParticipantUserId,
            userDisplayName: testParticipantDisplayName,
            permission: ResourcePermission.viewer,
          ),
          throwsA(equals(serviceError)),
        );
      });

      test('should handle adding different permission levels', () async {
        final permissions = [
          ResourcePermission.viewer,
          ResourcePermission.editor,
          ResourcePermission.admin,
        ];

        for (final permission in permissions) {
          await participantManager.addParticipant(
            menuId: testMenuId,
            userId: 'user_$permission',
            userDisplayName: 'User $permission',
            permission: permission,
          );

          verify(() => mockMenuService.addParticipant(
                resourceId: testMenuId,
                userId: 'user_$permission',
                userDisplayName: 'User $permission',
                permission: permission,
              )).called(1);
        }
      });
    });

    group('Remove Participant Operations', () {
      test('should remove participant successfully', () async {
        // Act
        await participantManager.removeParticipant(
          menuId: testMenuId,
          userId: testParticipantUserId,
        );

        // Assert
        verify(() => mockMenuService.removeParticipant(
              resourceId: testMenuId,
              userId: testParticipantUserId,
            )).called(1);

        verify(() => mockParticipantTracker.removeParticipant(
              testParticipantUserId,
            )).called(1);
      });

      test('should throw error when lacking permission to remove participant',
          () async {
        // Arrange - reconfigure with no invitation permissions
        mockPermissionService.setPermissionState(
          currentUserId: testCurrentUserId,
          isAuthenticated: true,
          defaultHasPermission: false,
          permissions: {
            testMenuId: {
              ResourcePermission.viewer: true,
              ResourcePermission.editor: false,
              ResourcePermission.admin: false,
            }
          },
        );

        // Act & Assert
        expect(
          () => participantManager.removeParticipant(
            menuId: testMenuId,
            userId: testParticipantUserId,
          ),
          throwsA(isA<Exception>().having(
              (e) => e.toString(), 'message', contains('Ingen behörighet'))),
        );

        verifyNever(() => mockMenuService.removeParticipant(
              resourceId: any(named: 'resourceId'),
              userId: any(named: 'userId'),
            ));
      });

      test('should throw error when trying to remove self', () async {
        // Act & Assert
        expect(
          () => participantManager.removeParticipant(
            menuId: testMenuId,
            userId: testCurrentUserId, // Current user ID
          ),
          throwsA(isA<Exception>().having((e) => e.toString(), 'message',
              contains('Kan inte ta bort sig själv'))),
        );

        verifyNever(() => mockMenuService.removeParticipant(
              resourceId: any(named: 'resourceId'),
              userId: any(named: 'userId'),
            ));
      });

      test('should rethrow service error when removing participant fails',
          () async {
        // Arrange
        final serviceError = Exception('Service error');
        when(() => mockMenuService.removeParticipant(
              resourceId: any(named: 'resourceId'),
              userId: any(named: 'userId'),
            )).thenThrow(serviceError);

        // Act & Assert
        expect(
          () => participantManager.removeParticipant(
            menuId: testMenuId,
            userId: testParticipantUserId,
          ),
          throwsA(equals(serviceError)),
        );
      });
    });

    group('Update Participant Permission Operations', () {
      test('should update participant permission successfully', () async {
        // Act
        await participantManager.updateParticipantPermission(
          menuId: testMenuId,
          userId: testParticipantUserId,
          newPermission: ResourcePermission.editor,
        );

        // Assert
        verify(() => mockMenuService.updateParticipantPermission(
              resourceId: testMenuId,
              userId: testParticipantUserId,
              newPermission: ResourcePermission.editor,
            )).called(1);
      });

      test('should throw error when lacking permission to update permissions',
          () async {
        // Arrange - reconfigure with no invitation permissions
        mockPermissionService.setPermissionState(
          currentUserId: testCurrentUserId,
          isAuthenticated: true,
          defaultHasPermission: false,
          permissions: {
            testMenuId: {
              ResourcePermission.viewer: true,
              ResourcePermission.editor: false,
              ResourcePermission.admin: false,
            }
          },
        );

        // Act & Assert
        expect(
          () => participantManager.updateParticipantPermission(
            menuId: testMenuId,
            userId: testParticipantUserId,
            newPermission: ResourcePermission.editor,
          ),
          throwsA(isA<Exception>().having(
              (e) => e.toString(), 'message', contains('Ingen behörighet'))),
        );

        verifyNever(() => mockMenuService.updateParticipantPermission(
              resourceId: any(named: 'resourceId'),
              userId: any(named: 'userId'),
              newPermission: any(named: 'newPermission'),
            ));
      });

      test('should throw error when trying to update own permissions',
          () async {
        // Act & Assert
        expect(
          () => participantManager.updateParticipantPermission(
            menuId: testMenuId,
            userId: testCurrentUserId, // Current user ID
            newPermission: ResourcePermission.admin,
          ),
          throwsA(isA<Exception>().having((e) => e.toString(), 'message',
              contains('Kan inte ändra sina egna behörigheter'))),
        );

        verifyNever(() => mockMenuService.updateParticipantPermission(
              resourceId: any(named: 'resourceId'),
              userId: any(named: 'userId'),
              newPermission: any(named: 'newPermission'),
            ));
      });

      test('should handle updating to different permission levels', () async {
        final permissions = [
          ResourcePermission.viewer,
          ResourcePermission.editor,
          ResourcePermission.admin,
        ];

        for (final permission in permissions) {
          await participantManager.updateParticipantPermission(
            menuId: testMenuId,
            userId: testParticipantUserId,
            newPermission: permission,
          );

          verify(() => mockMenuService.updateParticipantPermission(
                resourceId: testMenuId,
                userId: testParticipantUserId,
                newPermission: permission,
              )).called(1);
        }
      });
    });

    group('Leave Menu Operations', () {
      test('should leave menu successfully', () async {
        // Act
        await participantManager.leaveMenu(menuId: testMenuId);

        // Assert
        verify(() => mockMenuService.removeParticipant(
              resourceId: testMenuId,
              userId: testCurrentUserId,
            )).called(1);
      });

      test('should throw error when no current user ID available', () async {
        // Arrange - reconfigure with null user
        mockPermissionService.setPermissionState(
          currentUserId: null,
          isAuthenticated: false,
        );

        // Act & Assert
        expect(
          () => participantManager.leaveMenu(menuId: testMenuId),
          throwsA(isA<Exception>().having(
              (e) => e.toString(), 'message', contains('Ingen användar-ID'))),
        );

        verifyNever(() => mockMenuService.removeParticipant(
              resourceId: any(named: 'resourceId'),
              userId: any(named: 'userId'),
            ));
      });

      test('should rethrow service error when leaving menu fails', () async {
        // Arrange
        final serviceError = Exception('Service error');
        when(() => mockMenuService.removeParticipant(
              resourceId: any(named: 'resourceId'),
              userId: any(named: 'userId'),
            )).thenThrow(serviceError);

        // Act & Assert
        expect(
          () => participantManager.leaveMenu(menuId: testMenuId),
          throwsA(equals(serviceError)),
        );
      });
    });

    group('Participant Tracking', () {
      test('should get active participant count from tracker', () {
        // Arrange
        when(() => mockParticipantTracker.activeCount).thenReturn(5);

        // Act
        final count = participantManager.activeParticipantCount;

        // Assert
        expect(count, equals(5));
        verify(() => mockParticipantTracker.activeCount).called(1);
      });

      test('should get participant activities from tracker', () {
        // Arrange
        final activities = <ParticipantActivity>[];
        when(() => mockParticipantTracker.allActivities).thenReturn(activities);

        // Act
        final result = participantManager.participantActivities;

        // Assert
        expect(result, equals(activities));
        verify(() => mockParticipantTracker.allActivities).called(1);
      });

      test('should get online participants from tracker', () {
        // Arrange
        final onlineUsers = ['user1', 'user2'];
        when(() => mockParticipantTracker.onlineParticipants)
            .thenReturn(onlineUsers);

        // Act
        final result = participantManager.onlineParticipants;

        // Assert
        expect(result, equals(onlineUsers));
        verify(() => mockParticipantTracker.onlineParticipants).called(1);
      });

      test('should update tracker from menu', () {
        // Act
        participantManager.updateFromMenu(testMenu);

        // Assert
        verify(() => mockParticipantTracker.updateFromMenu(testMenu)).called(1);
      });

      test('should update participant display name in tracker', () {
        // Act
        participantManager.updateParticipantDisplayName(
            testParticipantUserId, testParticipantDisplayName);

        // Assert
        verify(() => mockParticipantTracker.updateDisplayName(
              testParticipantUserId,
              testParticipantDisplayName,
            )).called(1);
      });

      test('should remove participant from tracker', () {
        // Act
        participantManager.removeParticipantFromTracker(testParticipantUserId);

        // Assert
        verify(() =>
                mockParticipantTracker.removeParticipant(testParticipantUserId))
            .called(1);
      });
    });

    group('Participant Validation', () {
      test('should validate user ID correctly', () {
        // Test valid user ID
        expect(participantManager.validateUserId('valid_user_123'), isTrue);

        // Test null user ID
        expect(participantManager.validateUserId(null), isFalse);

        // Test empty user ID
        expect(participantManager.validateUserId(''), isFalse);
      });

      test('should validate display name correctly', () {
        // Test valid display name
        expect(participantManager.validateDisplayName('Valid Name'), isTrue);

        // Test null display name
        expect(participantManager.validateDisplayName(null), isFalse);

        // Test empty display name
        expect(participantManager.validateDisplayName(''), isFalse);

        // Test whitespace only display name
        expect(participantManager.validateDisplayName('   '), isFalse);
      });

      test('should validate permission correctly', () {
        // Test valid permissions
        expect(participantManager.validatePermission(ResourcePermission.viewer),
            isTrue);
        expect(participantManager.validatePermission(ResourcePermission.editor),
            isTrue);
        expect(participantManager.validatePermission(ResourcePermission.admin),
            isTrue);
        expect(participantManager.validatePermission(ResourcePermission.owner),
            isTrue);

        // Test null permission
        expect(participantManager.validatePermission(null), isFalse);
      });

      test('should check if user is already a participant', () {
        // Test existing participant
        final isParticipant =
            participantManager.isUserParticipant(testOwnerUserId, testMenu);
        expect(isParticipant, isTrue);

        // Test non-participant
        final isNotParticipant =
            participantManager.isUserParticipant('non_participant', testMenu);
        expect(isNotParticipant, isFalse);
      });

      test('should check if more participants can be added', () {
        // Test with default limit (50)
        final canAdd = participantManager.canAddMoreParticipants(testMenu);
        expect(canAdd, isTrue); // Current menu has 3 participants

        // Test with custom limit
        final canAddWithLimit = participantManager
            .canAddMoreParticipants(testMenu, maxParticipants: 2);
        expect(canAddWithLimit,
            isFalse); // Current menu has 3 participants, limit is 2
      });
    });

    group('Permission Analysis', () {
      test('should get participant permission level', () {
        // Test existing participant
        final permission = participantManager.getParticipantPermission(
            testOwnerUserId, testMenu);
        expect(permission, equals(ResourcePermission.owner));

        // Test non-existent participant
        final noPermission = participantManager.getParticipantPermission(
            'non_existent', testMenu);
        expect(noPermission, isNull);
      });

      test('should get participants with specific permission', () {
        // Act
        final owners = participantManager.getParticipantsWithPermission(
            testMenu, ResourcePermission.owner);
        final editors = participantManager.getParticipantsWithPermission(
            testMenu, ResourcePermission.editor);
        final viewers = participantManager.getParticipantsWithPermission(
            testMenu, ResourcePermission.viewer);

        // Assert
        expect(owners, contains(testOwnerUserId));
        expect(editors, contains(testCurrentUserId));
        expect(viewers, contains(testViewerUserId));
      });

      test('should group participants by permission level', () {
        // Act
        final grouped =
            participantManager.groupParticipantsByPermission(testMenu);

        // Assert
        expect(grouped[ResourcePermission.owner], contains(testOwnerUserId));
        expect(grouped[ResourcePermission.editor], contains(testCurrentUserId));
        expect(grouped[ResourcePermission.viewer], contains(testViewerUserId));
      });

      test('should count participants by permission', () {
        // Act
        final counts =
            participantManager.countParticipantsByPermission(testMenu);

        // Assert
        expect(counts[ResourcePermission.owner], equals(1));
        expect(counts[ResourcePermission.editor], equals(1));
        expect(counts[ResourcePermission.viewer], equals(1));
        expect(counts[ResourcePermission.admin], isNull);
      });
    });

    group('Participant Statistics', () {
      test('should generate participant statistics', () {
        // Arrange
        when(() => mockParticipantTracker.activeCount).thenReturn(2);
        when(() => mockParticipantTracker.onlineParticipants)
            .thenReturn(['user1']);

        // Act
        final stats = participantManager.getParticipantStats(testMenu);

        // Assert
        expect(stats['totalParticipants'], equals(3));
        expect(stats['owners'], equals(1));
        expect(stats['admins'], equals(0));
        expect(stats['editors'], equals(1));
        expect(stats['viewers'], equals(1));
        expect(stats['activeParticipants'], equals(2));
        expect(stats['onlineParticipants'], equals(1));
      });

      test('should generate participation summary for single user', () {
        // Arrange - menu with only one participant
        final singleUserMenu = RealtimeMenu(
          id: testMenuId,
          ownerId: testCurrentUserId,
          ownerDisplayName: 'Current User',
          participants: {testCurrentUserId: ResourcePermission.owner},
          lastEditedBy: testCurrentUserId,
          lastEditedByDisplayName: 'Current User',
          data: RealtimeMenuData(
            menuTitle: 'Single User Menu',
            createdForDate: DateTime.now(),
            menuSnapshot: {},
          ),
        );

        // Act
        final summary =
            participantManager.getParticipationSummary(singleUserMenu);

        // Assert
        expect(summary, equals('Bara du'));
      });

      test(
          'should generate participation summary for multiple users all online',
          () {
        // Arrange
        when(() => mockParticipantTracker.onlineParticipants)
            .thenReturn([testOwnerUserId, testCurrentUserId, testViewerUserId]);

        // Act
        final summary = participantManager.getParticipationSummary(testMenu);

        // Assert
        expect(summary, equals('3 deltagare (alla online)'));
      });

      test(
          'should generate participation summary for multiple users all offline',
          () {
        // Arrange
        when(() => mockParticipantTracker.onlineParticipants).thenReturn([]);

        // Act
        final summary = participantManager.getParticipationSummary(testMenu);

        // Assert
        expect(summary, equals('3 deltagare (alla offline)'));
      });

      test('should generate participation summary for mixed online/offline',
          () {
        // Arrange
        when(() => mockParticipantTracker.onlineParticipants)
            .thenReturn([testCurrentUserId]);

        // Act
        final summary = participantManager.getParticipationSummary(testMenu);

        // Assert
        expect(summary, equals('3 deltagare (1 online)'));
      });
    });

    group('Bulk Operations', () {
      test('should add multiple participants successfully', () async {
        // Arrange
        final participants = [
          {
            'userId': 'user1',
            'displayName': 'User One',
            'permission': ResourcePermission.viewer,
          },
          {
            'userId': 'user2',
            'displayName': 'User Two',
            'permission': ResourcePermission.editor,
          },
        ];

        // Act
        await participantManager.addMultipleParticipants(
          menuId: testMenuId,
          participants: participants,
        );

        // Assert
        verify(() => mockMenuService.addParticipant(
              resourceId: testMenuId,
              userId: 'user1',
              userDisplayName: 'User One',
              permission: ResourcePermission.viewer,
            )).called(1);

        verify(() => mockMenuService.addParticipant(
              resourceId: testMenuId,
              userId: 'user2',
              userDisplayName: 'User Two',
              permission: ResourcePermission.editor,
            )).called(1);
      });

      test('should throw error when lacking permission for bulk add', () async {
        // Arrange - reconfigure with no invitation permissions
        mockPermissionService.setPermissionState(
          currentUserId: testCurrentUserId,
          isAuthenticated: true,
          defaultHasPermission: false,
          permissions: {
            testMenuId: {
              ResourcePermission.viewer: true,
              ResourcePermission.editor: false,
              ResourcePermission.admin: false,
            }
          },
        );

        // Act & Assert
        expect(
          () => participantManager.addMultipleParticipants(
            menuId: testMenuId,
            participants: [],
          ),
          throwsA(isA<Exception>().having(
              (e) => e.toString(), 'message', contains('Ingen behörighet'))),
        );
      });

      test('should remove multiple participants successfully', () async {
        // Arrange
        final userIds = [testParticipantUserId, 'another_user'];

        // Act
        await participantManager.removeMultipleParticipants(
          menuId: testMenuId,
          userIds: userIds,
        );

        // Assert
        verify(() => mockMenuService.removeParticipant(
              resourceId: testMenuId,
              userId: testParticipantUserId,
            )).called(1);

        verify(() => mockMenuService.removeParticipant(
              resourceId: testMenuId,
              userId: 'another_user',
            )).called(1);
      });

      test('should filter out current user when removing multiple participants',
          () async {
        // Arrange
        final userIds = [
          testCurrentUserId,
          testParticipantUserId
        ]; // Include current user

        // Act
        await participantManager.removeMultipleParticipants(
          menuId: testMenuId,
          userIds: userIds,
        );

        // Assert - current user should be filtered out
        verifyNever(() => mockMenuService.removeParticipant(
              resourceId: testMenuId,
              userId: testCurrentUserId,
            ));

        verify(() => mockMenuService.removeParticipant(
              resourceId: testMenuId,
              userId: testParticipantUserId,
            )).called(1);
      });

      test('should handle empty list when removing multiple participants',
          () async {
        // Act
        await participantManager.removeMultipleParticipants(
          menuId: testMenuId,
          userIds: [
            testCurrentUserId
          ], // Only current user, should be filtered out
        );

        // Assert - no service calls should be made
        verifyNever(() => mockMenuService.removeParticipant(
              resourceId: any(named: 'resourceId'),
              userId: any(named: 'userId'),
            ));
      });
    });

    group('Error Handling and Edge Cases', () {
      test('should handle service timeouts gracefully', () async {
        // Arrange
        when(() => mockMenuService.addParticipant(
              resourceId: any(named: 'resourceId'),
              userId: any(named: 'userId'),
              userDisplayName: any(named: 'userDisplayName'),
              permission: any(named: 'permission'),
            )).thenThrow(TimeoutException('Timeout', Duration(seconds: 30)));

        // Act & Assert
        expect(
          () => participantManager.addParticipant(
            menuId: testMenuId,
            userId: testParticipantUserId,
            userDisplayName: testParticipantDisplayName,
            permission: ResourcePermission.viewer,
          ),
          throwsA(isA<TimeoutException>()),
        );
      });

      test('should handle empty menu participants', () {
        // Arrange - menu with no participants
        final emptyMenu = RealtimeMenu(
          id: testMenuId,
          ownerId: testOwnerUserId,
          ownerDisplayName: 'Owner User',
          participants: {},
          lastEditedBy: testOwnerUserId,
          lastEditedByDisplayName: 'Owner User',
          data: RealtimeMenuData(
            menuTitle: 'Empty Menu',
            createdForDate: DateTime.now(),
            menuSnapshot: {},
          ),
        );

        // Act & Assert
        expect(
            participantManager.isUserParticipant(testCurrentUserId, emptyMenu),
            isFalse);
        expect(participantManager.canAddMoreParticipants(emptyMenu), isTrue);

        final stats = participantManager.getParticipantStats(emptyMenu);
        expect(stats['totalParticipants'], equals(0));
      });

      test('should handle concurrent operations without conflicts', () async {
        // Act - simulate concurrent operations
        final futures = <Future>[];

        for (int i = 0; i < 3; i++) {
          futures.add(participantManager.addParticipant(
            menuId: testMenuId,
            userId: 'user_$i',
            userDisplayName: 'User $i',
            permission: ResourcePermission.viewer,
          ));
        }

        await Future.wait(futures);

        // Assert - all operations should complete
        verify(() => mockMenuService.addParticipant(
              resourceId: testMenuId,
              userId: any(named: 'userId'),
              userDisplayName: any(named: 'userDisplayName'),
              permission: ResourcePermission.viewer,
            )).called(3);
      });

      test('should handle disposal correctly', () {
        // Act
        participantManager.dispose();

        // Assert
        verify(() => mockParticipantTracker.dispose()).called(1);
      });
    });

    group('Integration Scenarios', () {
      test('should handle complete participant management workflow', () async {
        // Act & Assert - Complete workflow

        // 1. Add participant
        await participantManager.addParticipant(
          menuId: testMenuId,
          userId: testParticipantUserId,
          userDisplayName: testParticipantDisplayName,
          permission: ResourcePermission.viewer,
        );

        // 2. Update participant display name
        participantManager.updateParticipantDisplayName(
            testParticipantUserId, 'Updated Name');

        // 3. Update participant permission
        await participantManager.updateParticipantPermission(
          menuId: testMenuId,
          userId: testParticipantUserId,
          newPermission: ResourcePermission.editor,
        );

        // 4. Update from menu
        participantManager.updateFromMenu(testMenu);

        // 5. Remove participant
        await participantManager.removeParticipant(
          menuId: testMenuId,
          userId: testParticipantUserId,
        );

        // Verify all operations were called
        verify(() => mockMenuService.addParticipant(
              resourceId: testMenuId,
              userId: testParticipantUserId,
              userDisplayName: testParticipantDisplayName,
              permission: ResourcePermission.viewer,
            )).called(1);

        verify(() => mockMenuService.updateParticipantPermission(
              resourceId: testMenuId,
              userId: testParticipantUserId,
              newPermission: ResourcePermission.editor,
            )).called(1);

        verify(() => mockMenuService.removeParticipant(
              resourceId: testMenuId,
              userId: testParticipantUserId,
            )).called(1);
      });

      test('should handle participant validation workflow', () {
        // Act & Assert - Validation workflow

        // Valid data
        expect(participantManager.validateUserId('valid_user'), isTrue);
        expect(participantManager.validateDisplayName('Valid Name'), isTrue);
        expect(participantManager.validatePermission(ResourcePermission.editor),
            isTrue);

        // Invalid data
        expect(participantManager.validateUserId(null), isFalse);
        expect(participantManager.validateDisplayName(''), isFalse);
        expect(participantManager.validatePermission(null), isFalse);

        // Menu validation
        expect(participantManager.isUserParticipant(testOwnerUserId, testMenu),
            isTrue);
        expect(participantManager.canAddMoreParticipants(testMenu), isTrue);

        // Statistics
        final stats = participantManager.getParticipantStats(testMenu);
        expect(stats, isA<Map<String, dynamic>>());
        expect(stats['totalParticipants'], greaterThan(0));
      });
    });
  });
}
