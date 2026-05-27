/// Unit tests for ShoppingRepositoryRoutingModule.
///
/// The module routes collaborative-list CRUD to the shared collection
/// (/unified_shared_shopping_lists). It depends on a firestore handle,
/// an auth repository, a shared-collection ref, and four injected
/// callables. We pin the contract by driving each public method against
/// FakeFirebaseFirestore and capturing every callback invocation.
library;

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/core/exceptions/permission_exceptions.dart';
import 'package:butlery/models/unified/unified_shopping_list.dart';
import 'package:butlery/repositories/firebase/modules/shopping_repository_routing_module.dart';

import '../../../../infrastructure/mocks/production_mocks.dart';

const _userId = 'alice';
const _sharedPath = 'unified_shared_shopping_lists';

class _PermissionCall {
  final String userId;
  final String resource;
  final String operation;
  final bool granted;
  final String? details;
  _PermissionCall(
      this.userId, this.resource, this.operation, this.granted, this.details);
}

class _RequiredFieldsCall {
  final Map<String, dynamic> data;
  final List<String> requiredFields;
  final String resourceType;
  _RequiredFieldsCall(this.data, this.requiredFields, this.resourceType);
}

ShoppingRepositoryRoutingModule _routing(
  FakeFirebaseFirestore firestore, {
  List<_PermissionCall>? permissionCalls,
  List<_RequiredFieldsCall>? validationCalls,
  bool requiredFieldsThrows = false,
  String? currentUid,
}) {
  return ShoppingRepositoryRoutingModule(
    firestore: firestore,
    authRepository: FakeAuthRepository(),
    sharedListsRef: firestore.collection(_sharedPath),
    requireCurrentUserId: () => currentUid ?? _userId,
    validateRequiredFields: ({
      required Map<String, dynamic> data,
      required List<String> requiredFields,
      required String resourceType,
    }) {
      validationCalls
          ?.add(_RequiredFieldsCall(data, requiredFields, resourceType));
      if (requiredFieldsThrows) {
        throw SecurityViolationException('missing required field');
      }
    },
    logPermissionCheck: ({
      required String userId,
      required String resource,
      required String operation,
      required bool granted,
      String? details,
    }) {
      permissionCalls
          ?.add(_PermissionCall(userId, resource, operation, granted, details));
    },
    fromFirestore: (doc) => throw UnimplementedError('not used in tests'),
  );
}

UnifiedShoppingList _collabList({String name = 'Veckans handla'}) {
  return UnifiedShoppingList.collaborative(
    name: name,
    ownerId: _userId,
    ownerDisplayName: 'Alice',
    memberPermissions: const {'bob': SharedListPermission.edit},
  );
}

void main() {
  group('createCollaborativeList', () {
    test('writes to shared collection with generated id', () async {
      final firestore = FakeFirebaseFirestore();
      final permissionCalls = <_PermissionCall>[];
      final validationCalls = <_RequiredFieldsCall>[];
      final module = _routing(firestore,
          permissionCalls: permissionCalls, validationCalls: validationCalls);

      final input = _collabList(name: 'Helgens handla');
      final saved = await module.createCollaborativeList(input);

      // Saved list has a fresh id from the docRef, not the entity input id.
      expect(saved.id, isNotEmpty);
      expect(saved.name, 'Helgens handla');

      final snap = await firestore.collection(_sharedPath).doc(saved.id).get();
      expect(snap.exists, isTrue);
      expect(snap.data()!['name'], 'Helgens handla');
      expect(snap.data()!['ownerId'], _userId);
    });

    test('validates required fields before writing', () async {
      final firestore = FakeFirebaseFirestore();
      final validationCalls = <_RequiredFieldsCall>[];
      final module = _routing(firestore, validationCalls: validationCalls);

      await module.createCollaborativeList(_collabList());

      final call = validationCalls.single;
      expect(call.requiredFields, ['name', 'ownerId', 'memberPermissions']);
      expect(call.resourceType, 'collaborative_shopping_list');
      expect(call.data['name'], isNotNull);
    });

    test('logs successful permission check on create', () async {
      final firestore = FakeFirebaseFirestore();
      final permissionCalls = <_PermissionCall>[];
      final module = _routing(firestore, permissionCalls: permissionCalls);

      await module.createCollaborativeList(_collabList(name: 'X'));

      expect(permissionCalls, hasLength(1));
      final call = permissionCalls.single;
      expect(call.userId, _userId);
      expect(call.resource, 'collaborative_shopping_list');
      expect(call.operation, 'create');
      expect(call.granted, isTrue);
      expect(call.details, contains('List: X'));
    });

    test('propagates required-fields violations — no write, no perm log',
        () async {
      final firestore = FakeFirebaseFirestore();
      final permissionCalls = <_PermissionCall>[];
      final module = _routing(firestore,
          permissionCalls: permissionCalls, requiredFieldsThrows: true);

      await expectLater(
        () => module.createCollaborativeList(_collabList()),
        throwsA(isA<SecurityViolationException>()),
      );

      final col = await firestore.collection(_sharedPath).get();
      expect(col.docs, isEmpty);
      expect(permissionCalls, isEmpty);
    });
  });

  group('updateCollaborativeList', () {
    test('throws ResourceNotFoundException when doc does not exist', () async {
      final firestore = FakeFirebaseFirestore();
      final module = _routing(firestore);
      final entity = _collabList();

      await expectLater(
        () => module.updateCollaborativeList(entity),
        throwsA(isA<ResourceNotFoundException>()),
      );
    });

    test('merges update into existing shared doc', () async {
      final firestore = FakeFirebaseFirestore();
      final existing = _collabList(name: 'Original');
      // Seed via createCollaborativeList so the doc is well-formed.
      final module = _routing(firestore);
      final saved = await module.createCollaborativeList(existing);

      // Build a same-id entity with a new name.
      final renamed = UnifiedShoppingList(
        id: saved.id,
        name: 'Renamed',
        ownerId: saved.ownerId,
        ownerDisplayName: saved.ownerDisplayName,
        items: saved.items,
        type: saved.type,
        memberPermissions: saved.memberPermissions,
      );

      final returned = await module.updateCollaborativeList(renamed);
      expect(returned.name, 'Renamed');

      final snap = await firestore.collection(_sharedPath).doc(saved.id).get();
      expect(snap.data()!['name'], 'Renamed');
    });

    test('logs successful update permission check', () async {
      final firestore = FakeFirebaseFirestore();
      final permissionCalls = <_PermissionCall>[];
      final module = _routing(firestore, permissionCalls: permissionCalls);
      final saved = await module.createCollaborativeList(_collabList());
      permissionCalls.clear();

      await module.updateCollaborativeList(saved);

      expect(permissionCalls, hasLength(1));
      final call = permissionCalls.single;
      expect(call.resource, 'collaborative_shopping_list');
      expect(call.operation, 'update');
      expect(call.granted, isTrue);
    });
  });
}
