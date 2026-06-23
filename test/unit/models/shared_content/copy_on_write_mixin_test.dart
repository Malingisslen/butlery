/// Unit tests for CopyOnWriteSupport mixin (static parsers + accessor logic).
///
/// The mixin's per-content state-machine bits (triggerCopyOnWrite,
/// addActiveCollaborator) are exercised in shared_recipe_test.dart and
/// shared_menu_test.dart. Here we cover the abstract-side helpers via a
/// minimal _Stub plus the two static parse methods.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/models/shared_content/base_shared_content_model.dart';
import 'package:butlery/models/shared_content/copy_on_write_mixin.dart';

class _Stub extends BaseSharedContentModel<String> with CopyOnWriteSupport {
  @override
  final bool isOriginalReference;
  @override
  final bool copyOnWriteTriggered;
  @override
  final String? originalOwnerStaticCopyId;
  @override
  final int activeCollaboratorCount;

  _Stub({
    required super.id,
    required super.sharedByUserId,
    required super.sharedByDisplayName,
    required super.sharedAt,
    this.isOriginalReference = true,
    this.copyOnWriteTriggered = false,
    this.originalOwnerStaticCopyId,
    this.activeCollaboratorCount = 0,
  });

  @override
  String get contentTypeName => 'stub';
  @override
  String get contentSnapshot => 'snap';
  @override
  String getContentTitle() => 'T';
  @override
  String getContentDescription() => 'D';

  @override
  _Stub copyWithStatus({
    int? viewCount,
    int? engagementCount,
    int? dismissalCount,
  }) => this;

  @override
  _Stub triggerCopyOnWrite({
    required String editingUserId,
    required String staticCopyId,
  }) {
    return _Stub(
      id: id,
      sharedByUserId: sharedByUserId,
      sharedByDisplayName: sharedByDisplayName,
      sharedAt: sharedAt,
      isOriginalReference: false,
      copyOnWriteTriggered: true,
      originalOwnerStaticCopyId: staticCopyId,
      activeCollaboratorCount: 1,
    );
  }

  @override
  _Stub addActiveCollaborator(String userId) {
    return _Stub(
      id: id,
      sharedByUserId: sharedByUserId,
      sharedByDisplayName: sharedByDisplayName,
      sharedAt: sharedAt,
      isOriginalReference: isOriginalReference,
      copyOnWriteTriggered: copyOnWriteTriggered,
      originalOwnerStaticCopyId: originalOwnerStaticCopyId,
      activeCollaboratorCount: activeCollaboratorCount + 1,
    );
  }
}

_Stub _stub({
  bool cow = false,
  int collaborators = 0,
}) {
  return _Stub(
    id: 'x',
    sharedByUserId: 'alice',
    sharedByDisplayName: 'Alice',
    sharedAt: DateTime.utc(2026, 1, 1),
    isOriginalReference: !cow,
    copyOnWriteTriggered: cow,
    activeCollaboratorCount: collaborators,
  );
}

void main() {
  group('editingMode', () {
    test('"collaborative" once CoW is triggered', () {
      expect(_stub(cow: true).editingMode, 'collaborative');
    });

    test('"original_reference" when not yet triggered', () {
      expect(_stub().editingMode, 'original_reference');
    });
  });

  group('isCollaborative + hasActiveCollaborators', () {
    test('isCollaborative mirrors copyOnWriteTriggered', () {
      expect(_stub().isCollaborative, isFalse);
      expect(_stub(cow: true).isCollaborative, isTrue);
    });

    test('hasActiveCollaborators true iff count > 0', () {
      expect(
        _stub(cow: true, collaborators: 0).hasActiveCollaborators,
        isFalse,
      );
      expect(_stub(cow: true, collaborators: 1).hasActiveCollaborators, isTrue);
      expect(_stub(cow: true, collaborators: 5).hasActiveCollaborators, isTrue);
    });
  });

  // Note: canTriggerCopyOnWrite / getCollaborationAnalytics /
  // getNextCollaborationAction call a library-private
  // `_allowsCollaboration()` declared abstract on the mixin. Because
  // private members cannot be overridden across libraries, those code
  // paths throw NoSuchMethodError in production for ANY concrete
  // subclass — covered as a known-issue at copy_on_write_mixin.dart:116.
  // Tests below avoid those broken paths.

  group('getCopyOnWriteFirestoreFields + getCopyOnWriteJsonFields', () {
    test('both emit the same four CoW keys', () {
      final fields = _stub(
        cow: true,
        collaborators: 3,
      ).getCopyOnWriteFirestoreFields();
      expect(fields, {
        'isOriginalReference': false,
        'copyOnWriteTriggered': true,
        'originalOwnerStaticCopyId': null,
        'activeCollaboratorCount': 3,
      });

      final jsonFields = _stub(cow: true).getCopyOnWriteJsonFields();
      expect(jsonFields.keys.toSet(), fields.keys.toSet());
    });
  });

  group('parseCopyOnWriteFieldsFromFirestore', () {
    test('parses all four fields with safe defaults', () {
      final parsed = CopyOnWriteSupport.parseCopyOnWriteFieldsFromFirestore({
        'isOriginalReference': false,
        'copyOnWriteTriggered': true,
        'originalOwnerStaticCopyId': 'snap-1',
        'activeCollaboratorCount': 2,
      });
      expect(parsed['isOriginalReference'], isFalse);
      expect(parsed['copyOnWriteTriggered'], isTrue);
      expect(parsed['originalOwnerStaticCopyId'], 'snap-1');
      expect(parsed['activeCollaboratorCount'], 2);
    });

    test('safe defaults: isOriginalReference=true; others false/null/0', () {
      final parsed = CopyOnWriteSupport.parseCopyOnWriteFieldsFromFirestore({});
      expect(parsed['isOriginalReference'], isTrue);
      expect(parsed['copyOnWriteTriggered'], isFalse);
      expect(parsed['originalOwnerStaticCopyId'], isNull);
      expect(parsed['activeCollaboratorCount'], 0);
    });
  });

  group('parseCopyOnWriteFieldsFromJson', () {
    test('same shape as the Firestore variant', () {
      final parsed = CopyOnWriteSupport.parseCopyOnWriteFieldsFromJson({
        'isOriginalReference': false,
        'copyOnWriteTriggered': true,
        'originalOwnerStaticCopyId': 'snap-1',
        'activeCollaboratorCount': 5,
      });
      expect(parsed['isOriginalReference'], isFalse);
      expect(parsed['activeCollaboratorCount'], 5);
    });
  });
}
