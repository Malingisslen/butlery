import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart' as production;
import 'package:butlery/viewmodels/collaborative_shopping/shopping_permission_manager.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/models/permissions/resource_permission.dart';

import '../../../test_support/base_unit_test.dart';
import '../../../infrastructure/di/test_service_locator.dart';
import '../../../infrastructure/mocks/production_mocks.dart';

void main() {
  group('ShoppingPermissionManager', () {
    late ShoppingPermissionManager manager;
    late FakePermissionService mockPermissionService;

    const testListId = 'shopping-list-123';

    setUpAll(() async {
      await BaseUnitTest.setupUnit();
    });

    setUp(() async {
      await TestServiceLocator.initialize();
      production.ServiceLocator.initialize(DIContainer());

      mockPermissionService = FakePermissionService();
      TestServiceLocator.registerMock<PermissionService>(mockPermissionService);

      manager = ShoppingPermissionManager(testListId);
    });

    tearDown(() async {
      manager.dispose();
      await TestServiceLocator.reset();
      BaseUnitTest.resetMocks();
    });

    tearDownAll(() async {
      await BaseUnitTest.teardownUnit();
    });

    // -- canEdit getter --

    group('canEdit', () {
      test('should return true when permission service allows editing', () {
        // Behavior: canEdit delegates to permissionService.canEditShoppingList
        // with the manager's own listId.
        // FakePermissionService has concrete overrides — configure via setPermissionState.
        mockPermissionService.setPermissionState(
          currentUserId: 'test-user',
          permissions: {
            testListId: {ResourcePermission.editor: true},
          },
        );

        expect(manager.canEdit, true);
      });

      test('should return false when permission service denies editing', () {
        // Behavior: denied permission propagates as false
        mockPermissionService.setPermissionState(
          currentUserId: 'test-user',
          permissions: {
            testListId: {ResourcePermission.editor: false},
          },
          defaultHasPermission: false,
        );

        expect(manager.canEdit, false);
      });
    });

    // -- canView getter --

    group('canView', () {
      test('should return true when permission service allows viewing', () {
        // Behavior: canView delegates to permissionService.canViewShoppingList
        // with the manager's own listId.
        mockPermissionService.setPermissionState(
          currentUserId: 'test-user',
          permissions: {
            testListId: {ResourcePermission.viewer: true},
          },
        );

        expect(manager.canView, true);
      });

      test('should return false when permission service denies viewing', () {
        // Behavior: denied permission propagates as false
        mockPermissionService.setPermissionState(
          currentUserId: 'test-user',
          permissions: {
            testListId: {ResourcePermission.viewer: false},
          },
          defaultHasPermission: false,
        );

        expect(manager.canView, false);
      });
    });

    // -- canEditShoppingList(listId) --

    group('canEditShoppingList', () {
      test('should delegate to permission service with given listId', () {
        // Behavior: the method forwards the arbitrary listId (not just the
        // manager's own listId) to the permission service
        const otherListId = 'other-list-456';
        mockPermissionService.setPermissionState(
          currentUserId: 'test-user',
          permissions: {
            otherListId: {ResourcePermission.editor: true},
          },
        );

        expect(manager.canEditShoppingList(otherListId), true);
      });

      test('should return false when permission denied for given listId', () {
        // Behavior: denial for a specific list propagates correctly
        mockPermissionService.setPermissionState(
          currentUserId: 'test-user',
          permissions: {
            'restricted-list': {ResourcePermission.editor: false},
          },
          defaultHasPermission: false,
        );

        expect(manager.canEditShoppingList('restricted-list'), false);
      });
    });

    // -- canViewShoppingList(listId) --

    group('canViewShoppingList', () {
      test('should delegate to permission service with given listId', () {
        // Behavior: the method forwards the arbitrary listId to the
        // permission service for view-level checks
        const otherListId = 'other-list-789';
        mockPermissionService.setPermissionState(
          currentUserId: 'test-user',
          permissions: {
            otherListId: {ResourcePermission.viewer: true},
          },
        );

        expect(manager.canViewShoppingList(otherListId), true);
      });

      test('should return false when view permission denied', () {
        // Behavior: denied view permission propagates as false
        mockPermissionService.setPermissionState(
          currentUserId: 'test-user',
          permissions: {
            'private-list': {ResourcePermission.viewer: false},
          },
          defaultHasPermission: false,
        );

        expect(manager.canViewShoppingList('private-list'), false);
      });
    });

    // -- BUT-238: claim permission gate --
    //
    // Claim (Tar jag / Lämna tillbaka) is gated by the same canEdit check
    // that governs adding/removing/toggling items. View-only members must
    // not be able to claim — even though they can see assignments.

    group('BUT-238: claim / unclaim gating', () {
      test('view-only member cannot claim — canEdit returns false', () {
        // viewer-only permission, explicit default of false.
        mockPermissionService.setPermissionState(
          currentUserId: 'viewer-user',
          permissions: {
            testListId: {ResourcePermission.viewer: true},
          },
          defaultHasPermission: false,
        );

        expect(manager.canEdit, isFalse,
            reason: 'view-only member must not be allowed to claim');
      });

      test('editor member can claim — canEdit returns true', () {
        mockPermissionService.setPermissionState(
          currentUserId: 'editor-user',
          permissions: {
            testListId: {ResourcePermission.editor: true},
          },
        );

        expect(manager.canEdit, isTrue);
      });

      test('admin member can claim — canEdit returns true', () {
        mockPermissionService.setPermissionState(
          currentUserId: 'admin-user',
          permissions: {
            testListId: {ResourcePermission.admin: true},
          },
        );

        expect(manager.canEdit, isTrue);
      });
    });
  });
}
