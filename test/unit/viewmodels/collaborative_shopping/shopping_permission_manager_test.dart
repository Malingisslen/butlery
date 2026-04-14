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
    late MockPermissionService mockPermissionService;

    const testListId = 'shopping-list-123';

    setUpAll(() async {
      await BaseUnitTest.setupUnit();
    });

    setUp(() async {
      await TestServiceLocator.initialize();
      production.ServiceLocator.initialize(DIContainer());

      mockPermissionService = MockPermissionService();
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
        // MockPermissionService has concrete overrides — configure via setPermissionState.
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
  });
}
