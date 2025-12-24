// ignore_for_file: subtype_of_sealed_class

import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/models/permissions/resource_permission.dart';
import 'helpers/model_test_base.dart';

void main() {
  ModelTestBase.testModelGroup('ResourcePermission', () {
    group('Enum Values', () {
      test('should have all 6 permission levels', () {
        expect(ResourcePermission.values.length, equals(6));
      });

      test('should have correct enum values', () {
        expect(ResourcePermission.values, contains(ResourcePermission.viewer));
        expect(ResourcePermission.values, contains(ResourcePermission.editor));
        expect(ResourcePermission.values, contains(ResourcePermission.owner));
        expect(ResourcePermission.values, contains(ResourcePermission.read));
        expect(ResourcePermission.values, contains(ResourcePermission.write));
        expect(ResourcePermission.values, contains(ResourcePermission.admin));
      });

      test('should have correct enum names', () {
        expect(ResourcePermission.viewer.name, equals('viewer'));
        expect(ResourcePermission.editor.name, equals('editor'));
        expect(ResourcePermission.owner.name, equals('owner'));
        expect(ResourcePermission.read.name, equals('read'));
        expect(ResourcePermission.write.name, equals('write'));
        expect(ResourcePermission.admin.name, equals('admin'));
      });
    });

    group('Capability Checking - canEdit', () {
      test('should allow edit for editor permission', () {
        expect(ResourcePermission.editor.canEdit, isTrue);
      });

      test('should allow edit for owner permission', () {
        expect(ResourcePermission.owner.canEdit, isTrue);
      });

      test('should allow edit for write permission (legacy)', () {
        expect(ResourcePermission.write.canEdit, isTrue);
      });

      test('should allow edit for admin permission (legacy)', () {
        expect(ResourcePermission.admin.canEdit, isTrue);
      });

      test('should not allow edit for viewer permission', () {
        expect(ResourcePermission.viewer.canEdit, isFalse);
      });

      test('should not allow edit for read permission (legacy)', () {
        expect(ResourcePermission.read.canEdit, isFalse);
      });
    });

    group('Capability Checking - canOwn', () {
      test('should allow ownership for owner permission', () {
        expect(ResourcePermission.owner.canOwn, isTrue);
      });

      test('should allow ownership for admin permission', () {
        expect(ResourcePermission.admin.canOwn, isTrue);
      });

      test('should not allow ownership for viewer permission', () {
        expect(ResourcePermission.viewer.canOwn, isFalse);
      });

      test('should not allow ownership for editor permission', () {
        expect(ResourcePermission.editor.canOwn, isFalse);
      });

      test('should not allow ownership for read permission', () {
        expect(ResourcePermission.read.canOwn, isFalse);
      });

      test('should not allow ownership for write permission', () {
        expect(ResourcePermission.write.canOwn, isFalse);
      });
    });

    group('Capability Checking - canView', () {
      test('should allow view for all permission levels', () {
        for (final permission in ResourcePermission.values) {
          expect(permission.canView, isTrue,
              reason: '${permission.name} should allow viewing');
        }
      });
    });

    group('Display Names', () {
      test('should return correct display name for viewer', () {
        expect(ResourcePermission.viewer.displayName, equals('Viewer'));
      });

      test('should return correct display name for editor', () {
        expect(ResourcePermission.editor.displayName, equals('Editor'));
      });

      test('should return correct display name for owner', () {
        expect(ResourcePermission.owner.displayName, equals('Owner'));
      });

      test('should return correct display name for read', () {
        expect(ResourcePermission.read.displayName, equals('Read'));
      });

      test('should return correct display name for write', () {
        expect(ResourcePermission.write.displayName, equals('Write'));
      });

      test('should return correct display name for admin', () {
        expect(ResourcePermission.admin.displayName, equals('Admin'));
      });
    });

    group('ResourcePermissionHelper - fromString', () {
      test('should parse viewer permission', () {
        expect(ResourcePermissionHelper.fromString('viewer'),
            equals(ResourcePermission.viewer));
      });

      test('should parse editor permission', () {
        expect(ResourcePermissionHelper.fromString('editor'),
            equals(ResourcePermission.editor));
      });

      test('should parse owner permission', () {
        expect(ResourcePermissionHelper.fromString('owner'),
            equals(ResourcePermission.owner));
      });

      test('should parse read permission', () {
        expect(ResourcePermissionHelper.fromString('read'),
            equals(ResourcePermission.read));
      });

      test('should parse write permission', () {
        expect(ResourcePermissionHelper.fromString('write'),
            equals(ResourcePermission.write));
      });

      test('should parse admin permission', () {
        expect(ResourcePermissionHelper.fromString('admin'),
            equals(ResourcePermission.admin));
      });

      test('should be case-insensitive', () {
        expect(ResourcePermissionHelper.fromString('VIEWER'),
            equals(ResourcePermission.viewer));
        expect(ResourcePermissionHelper.fromString('Editor'),
            equals(ResourcePermission.editor));
        expect(ResourcePermissionHelper.fromString('ADMIN'),
            equals(ResourcePermission.admin));
      });

      test('should default to viewer for unknown strings', () {
        expect(ResourcePermissionHelper.fromString('unknown'),
            equals(ResourcePermission.viewer));
        expect(ResourcePermissionHelper.fromString(''),
            equals(ResourcePermission.viewer));
        expect(ResourcePermissionHelper.fromString('invalid'),
            equals(ResourcePermission.viewer));
      });
    });

    group('ResourcePermissionHelper - Permission Hierarchy', () {
      test('should correctly identify hierarchy for modern permissions', () {
        expect(
            ResourcePermissionHelper.isHigherThan(
                ResourcePermission.owner, ResourcePermission.editor),
            isTrue);
        expect(
            ResourcePermissionHelper.isHigherThan(
                ResourcePermission.owner, ResourcePermission.viewer),
            isTrue);
        expect(
            ResourcePermissionHelper.isHigherThan(
                ResourcePermission.editor, ResourcePermission.viewer),
            isTrue);
      });

      test('should correctly identify hierarchy for legacy permissions', () {
        expect(
            ResourcePermissionHelper.isHigherThan(
                ResourcePermission.admin, ResourcePermission.write),
            isTrue);
        expect(
            ResourcePermissionHelper.isHigherThan(
                ResourcePermission.admin, ResourcePermission.read),
            isTrue);
        expect(
            ResourcePermissionHelper.isHigherThan(
                ResourcePermission.write, ResourcePermission.read),
            isTrue);
      });

      test('should correctly identify hierarchy between modern and legacy', () {
        expect(
            ResourcePermissionHelper.isHigherThan(
                ResourcePermission.admin, ResourcePermission.owner),
            isTrue);
        expect(
            ResourcePermissionHelper.isHigherThan(
                ResourcePermission.owner, ResourcePermission.write),
            isTrue);
        expect(
            ResourcePermissionHelper.isHigherThan(
                ResourcePermission.editor, ResourcePermission.viewer),
            isTrue);
      });

      test('should return false for equal permissions', () {
        expect(
            ResourcePermissionHelper.isHigherThan(
                ResourcePermission.viewer, ResourcePermission.viewer),
            isFalse);
        expect(
            ResourcePermissionHelper.isHigherThan(
                ResourcePermission.admin, ResourcePermission.admin),
            isFalse);
      });

      test('should return false for lower permissions', () {
        expect(
            ResourcePermissionHelper.isHigherThan(
                ResourcePermission.viewer, ResourcePermission.editor),
            isFalse);
        expect(
            ResourcePermissionHelper.isHigherThan(
                ResourcePermission.read, ResourcePermission.write),
            isFalse);
      });
    });

    group('ResourcePermissionHelper - getHighest', () {
      test('should return highest permission from mixed list', () {
        final permissions = [
          ResourcePermission.viewer,
          ResourcePermission.editor,
          ResourcePermission.owner,
        ];
        expect(ResourcePermissionHelper.getHighest(permissions),
            equals(ResourcePermission.owner));
      });

      test('should return admin as highest when present', () {
        final permissions = [
          ResourcePermission.viewer,
          ResourcePermission.admin,
          ResourcePermission.owner,
        ];
        expect(ResourcePermissionHelper.getHighest(permissions),
            equals(ResourcePermission.admin));
      });

      test('should handle single permission', () {
        expect(ResourcePermissionHelper.getHighest([ResourcePermission.editor]),
            equals(ResourcePermission.editor));
      });

      test('should return viewer for empty list', () {
        expect(ResourcePermissionHelper.getHighest([]),
            equals(ResourcePermission.viewer));
      });

      test('should handle duplicate permissions', () {
        final permissions = [
          ResourcePermission.editor,
          ResourcePermission.editor,
          ResourcePermission.viewer,
        ];
        expect(ResourcePermissionHelper.getHighest(permissions),
            equals(ResourcePermission.editor));
      });
    });

    group('ResourcePermissionHelper - Utility Methods', () {
      test('should create default permissions map', () {
        final userId = 'user_123';
        final permissions = ResourcePermissionHelper.createDefault(userId);

        expect(permissions, isA<Map<String, ResourcePermission>>());
        expect(permissions.length, equals(1));
        expect(permissions[userId], equals(ResourcePermission.admin));
      });

      test('should convert permission to name', () {
        expect(
            ResourcePermissionHelper.permissionToName(
                ResourcePermission.viewer),
            equals('viewer'));
        expect(
            ResourcePermissionHelper.permissionToName(ResourcePermission.admin),
            equals('admin'));
      });

      test('should convert permission to string (legacy method)', () {
        expect(
            ResourcePermissionHelper.permissionToString(
                ResourcePermission.editor),
            equals('editor'));
        expect(
            ResourcePermissionHelper.permissionToString(
                ResourcePermission.owner),
            equals('owner'));
      });

      test('should check if permission can manage permissions', () {
        expect(
            ResourcePermissionHelper.canManagePermissions(
                ResourcePermission.admin),
            isTrue);
        expect(
            ResourcePermissionHelper.canManagePermissions(
                ResourcePermission.owner),
            isTrue);
        expect(
            ResourcePermissionHelper.canManagePermissions(
                ResourcePermission.editor),
            isFalse);
        expect(
            ResourcePermissionHelper.canManagePermissions(
                ResourcePermission.viewer),
            isFalse);
      });

      test('should validate edit content permission', () {
        // User has higher permission than required
        expect(
            ResourcePermissionHelper.canEditContent(
                ResourcePermission.owner, ResourcePermission.editor),
            isTrue);

        // User has equal permission to required
        expect(
            ResourcePermissionHelper.canEditContent(
                ResourcePermission.editor, ResourcePermission.editor),
            isTrue);

        // User has lower permission than required
        expect(
            ResourcePermissionHelper.canEditContent(
                ResourcePermission.viewer, ResourcePermission.editor),
            isFalse);

        // Admin can edit everything
        expect(
            ResourcePermissionHelper.canEditContent(
                ResourcePermission.admin, ResourcePermission.owner),
            isTrue);
      });
    });

    group('Edge Cases', () {
      test('should handle all permissions in loops', () {
        for (final permission in ResourcePermission.values) {
          // Should not throw
          expect(permission.name, isNotEmpty);
          expect(permission.displayName, isNotEmpty);
          expect(permission.canView, isTrue);
          expect(() => permission.canEdit, returnsNormally);
          expect(() => permission.canOwn, returnsNormally);
        }
      });

      test('should maintain consistency between helper methods', () {
        for (final permission in ResourcePermission.values) {
          final name = permission.name;
          final parsed = ResourcePermissionHelper.fromString(name);
          expect(parsed, equals(permission));

          final stringified =
              ResourcePermissionHelper.permissionToName(permission);
          expect(stringified, equals(name));
        }
      });

      test('should handle permission comparison edge cases', () {
        // Compare with same permission
        expect(
            ResourcePermissionHelper.isHigherThan(
                ResourcePermission.viewer, ResourcePermission.read),
            isFalse); // Both are level 1

        expect(
            ResourcePermissionHelper.isHigherThan(
                ResourcePermission.editor, ResourcePermission.write),
            isFalse); // Both are level 2
      });
    });
  });
}
