// Rewritten: local pure-Mocks to avoid centralized concrete @override conflicts.

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
import '../../test_support/base_unit_test.dart';

// Local pure-Mocks: no concrete @override, so when() works.
class _MockRealtimeMenuService extends Mock implements RealtimeMenuService {}

class _MockParticipantTracker extends Mock implements ParticipantTracker {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('RealtimeParticipantManager', () {
    late RealtimeParticipantManager manager;
    late _MockRealtimeMenuService mockMenuService;
    late _MockParticipantTracker mockTracker;
    late FakePermissionService mockPermission;

    const testMenuId = 'menu_123';
    const testUserId = 'current_user';
    const testOther = 'other_user';
    const testViewer = 'viewer_user';

    late RealtimeMenu testMenu;

    setUpAll(() async {
      await BaseUnitTest.setupUnit();
      await TestServiceLocator.initialize();
      registerFallbackValue(ResourcePermission.viewer);
      registerFallbackValue(
        RealtimeMenu(
          id: 'fb',
          ownerId: 'fb',
          ownerDisplayName: 'fb',
          participants: {},
          lastEditedBy: 'fb',
          lastEditedByDisplayName: 'fb',
          data: RealtimeMenuData(
            menuTitle: 'fb',
            createdForDate: DateTime.now(),
            menuSnapshot: {},
          ),
        ),
      );
    });

    setUp(() {
      mockMenuService = _MockRealtimeMenuService();
      mockTracker = _MockParticipantTracker();
      mockPermission = FakePermissionService();

      mockPermission.setPermissionState(
        currentUserId: testUserId,
        userDisplayName: 'Current User',
        isAuthenticated: true,
        defaultHasPermission: true,
        permissions: {
          testMenuId: {
            ResourcePermission.editor: true,
            ResourcePermission.admin: true,
            ResourcePermission.owner: false,
          },
        },
      );

      // Tracker stubs
      when(() => mockTracker.activeCount).thenReturn(2);
      when(() => mockTracker.allActivities).thenReturn([]);
      when(() => mockTracker.onlineParticipants).thenReturn([testUserId]);
      when(() => mockTracker.updateDisplayName(any(), any())).thenReturn(null);
      when(() => mockTracker.removeParticipant(any())).thenReturn(null);
      when(() => mockTracker.updateFromMenu(any())).thenReturn(null);
      when(() => mockTracker.dispose()).thenReturn(null);

      // Menu service stubs
      when(
        () => mockMenuService.addParticipant(
          resourceId: any(named: 'resourceId'),
          userId: any(named: 'userId'),
          userDisplayName: any(named: 'userDisplayName'),
          permission: any(named: 'permission'),
        ),
      ).thenAnswer((_) async {});

      when(
        () => mockMenuService.removeParticipant(
          resourceId: any(named: 'resourceId'),
          userId: any(named: 'userId'),
        ),
      ).thenAnswer((_) async {});

      when(
        () => mockMenuService.updateParticipantPermission(
          resourceId: any(named: 'resourceId'),
          userId: any(named: 'userId'),
          newPermission: any(named: 'newPermission'),
        ),
      ).thenAnswer((_) async {});

      testMenu = RealtimeMenu(
        id: testMenuId,
        ownerId: testOther,
        ownerDisplayName: 'Owner',
        participants: {
          testOther: ResourcePermission.owner,
          testUserId: ResourcePermission.editor,
          testViewer: ResourcePermission.viewer,
        },
        lastEditedBy: testUserId,
        lastEditedByDisplayName: 'Current User',
        data: RealtimeMenuData(
          menuTitle: 'Test Menu',
          createdForDate: DateTime.now(),
          menuSnapshot: {},
        ),
      );

      manager = RealtimeParticipantManager(
        menuService: mockMenuService,
        participantTracker: mockTracker,
        permissionService: mockPermission,
      );
    });

    tearDown(() {
      manager.dispose();
    });

    tearDownAll(() async {
      BaseUnitTest.resetMocks();
      await TestServiceLocator.reset();
    });

    group('Permission Getters', () {
      test('should check all permission getters and handle edge cases', () {
        expect(manager.currentUserId, equals(testUserId));
        expect(manager.canEdit(testMenuId), isTrue);
        expect(manager.canManageParticipants(testMenuId), isTrue);
        expect(manager.canDeleteMenu(testMenuId), isTrue);

        // Null user
        mockPermission.setPermissionState(
          currentUserId: null,
          isAuthenticated: false,
        );
        expect(manager.currentUserId, isNull);

        // Insufficient permissions
        mockPermission.setPermissionState(
          currentUserId: testUserId,
          isAuthenticated: true,
          defaultHasPermission: false,
          permissions: {
            testMenuId: {
              ResourcePermission.viewer: true,
              ResourcePermission.editor: false,
              ResourcePermission.admin: false,
              ResourcePermission.owner: false,
            },
          },
        );
        expect(manager.canEdit(testMenuId), isFalse);
        expect(manager.canManageParticipants(testMenuId), isFalse);
        expect(manager.canDeleteMenu(testMenuId), isFalse);
      });
    });

    group('CRUD Operations', () {
      test('should add participant and update tracker', () async {
        await manager.addParticipant(
          menuId: testMenuId,
          userId: 'new_user',
          userDisplayName: 'New User',
          permission: ResourcePermission.viewer,
        );
        verify(
          () => mockMenuService.addParticipant(
            resourceId: testMenuId,
            userId: 'new_user',
            userDisplayName: 'New User',
            permission: ResourcePermission.viewer,
          ),
        ).called(1);
        verify(
          () => mockTracker.updateDisplayName('new_user', 'New User'),
        ).called(1);
      });

      test('should remove participant and update tracker', () async {
        await manager.removeParticipant(menuId: testMenuId, userId: 'x');
        verify(
          () => mockMenuService.removeParticipant(
            resourceId: testMenuId,
            userId: 'x',
          ),
        ).called(1);
        verify(() => mockTracker.removeParticipant('x')).called(1);
      });

      test('should update participant permission', () async {
        await manager.updateParticipantPermission(
          menuId: testMenuId,
          userId: 'x',
          newPermission: ResourcePermission.editor,
        );
        verify(
          () => mockMenuService.updateParticipantPermission(
            resourceId: testMenuId,
            userId: 'x',
            newPermission: ResourcePermission.editor,
          ),
        ).called(1);
      });

      test('should throw without permission for add/remove/update', () {
        mockPermission.setPermissionState(
          currentUserId: testUserId,
          isAuthenticated: true,
          defaultHasPermission: false,
          permissions: {},
        );
        expect(
          () => manager.addParticipant(
            menuId: testMenuId,
            userId: 'x',
            userDisplayName: 'X',
            permission: ResourcePermission.viewer,
          ),
          throwsA(isA<Exception>()),
        );
        expect(
          () => manager.removeParticipant(menuId: testMenuId, userId: 'x'),
          throwsA(isA<Exception>()),
        );
        expect(
          () => manager.updateParticipantPermission(
            menuId: testMenuId,
            userId: 'x',
            newPermission: ResourcePermission.editor,
          ),
          throwsA(isA<Exception>()),
        );
      });

      test('should prevent self-remove and self-permission-change', () {
        expect(
          () =>
              manager.removeParticipant(menuId: testMenuId, userId: testUserId),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'msg',
              contains('ta bort sig själv'),
            ),
          ),
        );
        expect(
          () => manager.updateParticipantPermission(
            menuId: testMenuId,
            userId: testUserId,
            newPermission: ResourcePermission.admin,
          ),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'msg',
              contains('egna behörigheter'),
            ),
          ),
        );
      });

      test('should rethrow service errors', () {
        when(
          () => mockMenuService.addParticipant(
            resourceId: any(named: 'resourceId'),
            userId: any(named: 'userId'),
            userDisplayName: any(named: 'userDisplayName'),
            permission: any(named: 'permission'),
          ),
        ).thenThrow(Exception('fail'));
        expect(
          () => manager.addParticipant(
            menuId: testMenuId,
            userId: 'x',
            userDisplayName: 'X',
            permission: ResourcePermission.viewer,
          ),
          throwsA(isA<Exception>()),
        );
      });
    });

    group('Leave Menu', () {
      test('should leave menu successfully', () async {
        await manager.leaveMenu(menuId: testMenuId);
        verify(
          () => mockMenuService.removeParticipant(
            resourceId: testMenuId,
            userId: testUserId,
          ),
        ).called(1);
      });

      test('should throw when no current user', () {
        mockPermission.setPermissionState(
          currentUserId: null,
          isAuthenticated: false,
        );
        expect(
          () => manager.leaveMenu(menuId: testMenuId),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'msg',
              contains('användar-ID'),
            ),
          ),
        );
      });

      test('should rethrow service error', () {
        when(
          () => mockMenuService.removeParticipant(
            resourceId: any(named: 'resourceId'),
            userId: any(named: 'userId'),
          ),
        ).thenThrow(Exception('fail'));

        expect(
          () => manager.leaveMenu(menuId: testMenuId),
          throwsA(isA<Exception>()),
        );
      });
    });

    group('Tracking & Validation', () {
      test('should delegate tracking reads to tracker', () {
        expect(manager.activeParticipantCount, equals(2));
        expect(manager.participantActivities, isEmpty);
        expect(manager.onlineParticipants, equals([testUserId]));
      });

      test('should delegate tracking writes to tracker', () {
        manager.updateFromMenu(testMenu);
        manager.updateParticipantDisplayName('x', 'Name');
        manager.removeParticipantFromTracker('x');
        verify(() => mockTracker.updateFromMenu(testMenu)).called(1);
        verify(() => mockTracker.updateDisplayName('x', 'Name')).called(1);
        verify(() => mockTracker.removeParticipant('x')).called(1);
      });

      test('should validate inputs', () {
        expect(manager.validateUserId('valid'), isTrue);
        expect(manager.validateUserId(null), isFalse);
        expect(manager.validateUserId(''), isFalse);
        expect(manager.validateDisplayName('Name'), isTrue);
        expect(manager.validateDisplayName(null), isFalse);
        expect(manager.validateDisplayName(''), isFalse);
        expect(manager.validateDisplayName('   '), isFalse);
        expect(manager.validatePermission(ResourcePermission.viewer), isTrue);
        expect(manager.validatePermission(null), isFalse);
      });

      test('should check participation and limits', () {
        expect(manager.isUserParticipant(testOther, testMenu), isTrue);
        expect(manager.isUserParticipant('nobody', testMenu), isFalse);
        expect(manager.canAddMoreParticipants(testMenu), isTrue);
        expect(
          manager.canAddMoreParticipants(testMenu, maxParticipants: 2),
          isFalse,
        );
      });

      test('should analyze permissions on menu', () {
        expect(
          manager.getParticipantPermission(testOther, testMenu),
          equals(ResourcePermission.owner),
        );
        expect(manager.getParticipantPermission('nobody', testMenu), isNull);
        expect(
          manager.getParticipantsWithPermission(
            testMenu,
            ResourcePermission.owner,
          ),
          contains(testOther),
        );
        final grouped = manager.groupParticipantsByPermission(testMenu);
        expect(grouped[ResourcePermission.owner], contains(testOther));
        expect(grouped[ResourcePermission.editor], contains(testUserId));
        expect(grouped[ResourcePermission.viewer], contains(testViewer));
        final counts = manager.countParticipantsByPermission(testMenu);
        expect(counts[ResourcePermission.owner], equals(1));
        expect(counts[ResourcePermission.editor], equals(1));
        expect(counts[ResourcePermission.viewer], equals(1));
        expect(counts[ResourcePermission.admin], isNull);
      });
    });

    group('Statistics', () {
      test('should generate stats and participation summaries', () {
        final stats = manager.getParticipantStats(testMenu);
        expect(stats['totalParticipants'], equals(3));
        expect(stats['owners'], equals(1));
        expect(stats['editors'], equals(1));
        expect(stats['viewers'], equals(1));
        expect(stats['activeParticipants'], equals(2));
        expect(stats['onlineParticipants'], equals(1));

        // Solo menu
        final solo = RealtimeMenu(
          id: testMenuId,
          ownerId: testUserId,
          ownerDisplayName: 'Me',
          participants: {testUserId: ResourcePermission.owner},
          lastEditedBy: testUserId,
          lastEditedByDisplayName: 'Me',
          data: RealtimeMenuData(
            menuTitle: 'Solo',
            createdForDate: DateTime.now(),
            menuSnapshot: {},
          ),
        );
        expect(manager.getParticipationSummary(solo), equals('Bara du'));

        // All online / all offline / mixed
        when(
          () => mockTracker.onlineParticipants,
        ).thenReturn([testOther, testUserId, testViewer]);
        expect(
          manager.getParticipationSummary(testMenu),
          equals('3 deltagare (alla online)'),
        );
        when(() => mockTracker.onlineParticipants).thenReturn([]);
        expect(
          manager.getParticipationSummary(testMenu),
          equals('3 deltagare (alla offline)'),
        );
        when(() => mockTracker.onlineParticipants).thenReturn([testUserId]);
        expect(
          manager.getParticipationSummary(testMenu),
          equals('3 deltagare (1 online)'),
        );
      });
    });

    group('Bulk & Edge Cases', () {
      test('should add multiple participants', () async {
        await manager.addMultipleParticipants(
          menuId: testMenuId,
          participants: [
            {
              'userId': 'u1',
              'displayName': 'U1',
              'permission': ResourcePermission.viewer,
            },
            {
              'userId': 'u2',
              'displayName': 'U2',
              'permission': ResourcePermission.editor,
            },
          ],
        );
        verify(
          () => mockMenuService.addParticipant(
            resourceId: testMenuId,
            userId: 'u1',
            userDisplayName: 'U1',
            permission: ResourcePermission.viewer,
          ),
        ).called(1);
        verify(
          () => mockMenuService.addParticipant(
            resourceId: testMenuId,
            userId: 'u2',
            userDisplayName: 'U2',
            permission: ResourcePermission.editor,
          ),
        ).called(1);
      });

      test('should throw for bulk add without permission', () {
        mockPermission.setPermissionState(
          currentUserId: testUserId,
          isAuthenticated: true,
          defaultHasPermission: false,
          permissions: {},
        );
        expect(
          () => manager.addMultipleParticipants(
            menuId: testMenuId,
            participants: [],
          ),
          throwsA(isA<Exception>()),
        );
      });

      test('should bulk remove filtering out current user', () async {
        await manager.removeMultipleParticipants(
          menuId: testMenuId,
          userIds: [testUserId, 'a', 'b'],
        );
        verifyNever(
          () => mockMenuService.removeParticipant(
            resourceId: testMenuId,
            userId: testUserId,
          ),
        );
        verify(
          () => mockMenuService.removeParticipant(
            resourceId: testMenuId,
            userId: 'a',
          ),
        ).called(1);
        verify(
          () => mockMenuService.removeParticipant(
            resourceId: testMenuId,
            userId: 'b',
          ),
        ).called(1);
      });

      test('should handle timeout, empty menu, concurrent, dispose', () async {
        // Timeout
        when(
          () => mockMenuService.addParticipant(
            resourceId: any(named: 'resourceId'),
            userId: any(named: 'userId'),
            userDisplayName: any(named: 'userDisplayName'),
            permission: any(named: 'permission'),
          ),
        ).thenThrow(TimeoutException('Timeout'));
        expect(
          () => manager.addParticipant(
            menuId: testMenuId,
            userId: 'x',
            userDisplayName: 'X',
            permission: ResourcePermission.viewer,
          ),
          throwsA(isA<TimeoutException>()),
        );

        // Reset stub and clear interaction count for concurrent test
        when(
          () => mockMenuService.addParticipant(
            resourceId: any(named: 'resourceId'),
            userId: any(named: 'userId'),
            userDisplayName: any(named: 'userDisplayName'),
            permission: any(named: 'permission'),
          ),
        ).thenAnswer((_) async {});
        clearInteractions(mockMenuService);

        // Empty menu
        final empty = RealtimeMenu(
          id: testMenuId,
          ownerId: testOther,
          ownerDisplayName: 'Owner',
          participants: {},
          lastEditedBy: testOther,
          lastEditedByDisplayName: 'Owner',
          data: RealtimeMenuData(
            menuTitle: 'E',
            createdForDate: DateTime.now(),
            menuSnapshot: {},
          ),
        );
        expect(manager.isUserParticipant(testUserId, empty), isFalse);
        expect(
          manager.getParticipantStats(empty)['totalParticipants'],
          equals(0),
        );

        // Concurrent
        await Future.wait(
          List.generate(
            3,
            (i) => manager.addParticipant(
              menuId: testMenuId,
              userId: 'user_$i',
              userDisplayName: 'User $i',
              permission: ResourcePermission.viewer,
            ),
          ),
        );
        verify(
          () => mockMenuService.addParticipant(
            resourceId: testMenuId,
            userId: any(named: 'userId'),
            userDisplayName: any(named: 'userDisplayName'),
            permission: ResourcePermission.viewer,
          ),
        ).called(3);

        // Dispose
        manager.dispose();
        verify(() => mockTracker.dispose()).called(1);
      });
    });
  });
}
