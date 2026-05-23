/// Unit tests for ShoppingTemplateOperationsModule.
///
/// The module owns shopping-list templating: saveAsTemplate
/// (snapshot list → template doc), updateTemplate (partial metadata
/// edits), deleteTemplate, getUserTemplates / getPublicTemplates
/// (paginated reads with client-side search/tag filtering), and
/// createListFromTemplate (instantiate a new list from a template,
/// gated on public/owner access). Tests cover the happy paths, the
/// ResourceNotFoundException raises on missing docs, the
/// PermissionDeniedException on private templates, and the client-side
/// filter logic on getPublicTemplates.
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/core/exceptions/permission_exceptions.dart';
import 'package:butlery/core/utils/timestamp_provider.dart';
import 'package:butlery/models/unified/unified_shopping_item.dart';
import 'package:butlery/models/unified/unified_shopping_list.dart';
import 'package:butlery/repositories/firebase/modules/shopping_template_operations_module.dart';
import 'package:butlery/repositories/interfaces/auth_repository.dart';

import '../../../../infrastructure/mocks/production_mocks.dart';

const _userId = 'alice';
const _templatesPath = 'shopping_templates';

class _OwnershipCall {
  final String currentUserId;
  final String resourceOwnerId;
  final String resourceType;
  final String resourceId;
  _OwnershipCall(this.currentUserId, this.resourceOwnerId, this.resourceType,
      this.resourceId);
}

class _CreateListCall {
  final UnifiedShoppingList entity;
  _CreateListCall(this.entity);
}

class _MockAuthRepo extends Mock implements AuthRepository {}

UnifiedShoppingList _list({
  String? id,
  String name = 'Veckans',
  List<UnifiedShoppingItem> items = const [],
  String ownerId = _userId,
}) {
  return UnifiedShoppingList(
    id: id ?? 'list-1',
    name: name,
    ownerId: ownerId,
    ownerDisplayName: 'Alice',
    items: items,
  );
}

UnifiedShoppingItem _item(String name) {
  return UnifiedShoppingItem(
    name: name,
    amount: 1.0,
    addedAt: DateTime.utc(2026, 1, 1),
    addedByUserId: _userId,
    addedByDisplayName: 'Alice',
  );
}

ShoppingTemplateOperationsModule _module(
  FakeFirebaseFirestore firestore, {
  Future<UnifiedShoppingList?> Function(String)? readList,
  Future<UnifiedShoppingList> Function(UnifiedShoppingList)? createList,
  List<_OwnershipCall>? ownershipCalls,
  List<_CreateListCall>? createListCalls,
  bool ownershipThrows = false,
  AuthRepository? authRepo,
}) {
  final auth = authRepo ?? _MockAuthRepo();
  if (authRepo == null) {
    when(() => auth.currentUser).thenReturn(FakeUser(displayName: 'Alice'));
  }
  return ShoppingTemplateOperationsModule(
    firestore: firestore,
    authRepository: auth,
    templatesRef: firestore.collection(_templatesPath),
    requireCurrentUserId: () => _userId,
    readList: readList ?? ((_) async => null),
    createList: createList ??
        ((entity) async {
          createListCalls?.add(_CreateListCall(entity));
          return entity;
        }),
    validateOwnership: ({
      required String currentUserId,
      required String resourceOwnerId,
      required String resourceType,
      required String resourceId,
    }) async {
      ownershipCalls?.add(_OwnershipCall(
          currentUserId, resourceOwnerId, resourceType, resourceId));
      if (ownershipThrows) {
        throw PermissionDeniedException('denied');
      }
    },
    timestampProvider: const TestTimestampProvider(),
  );
}

void main() {
  setUpAll(() {
    registerFallbackValue(FakeUser());
  });

  group('saveAsTemplate', () {
    test('throws ResourceNotFoundException when source list missing', () async {
      final firestore = FakeFirebaseFirestore();
      await expectLater(
        () => _module(firestore)
            .saveAsTemplate(listId: 'missing', templateName: 'T'),
        throwsA(isA<ResourceNotFoundException>()),
      );
    });

    test('writes template doc with items from the source list', () async {
      final firestore = FakeFirebaseFirestore();
      final source = _list(items: [_item('Mjölk'), _item('Bröd')]);
      final templateId = await _module(firestore, readList: (_) async => source)
          .saveAsTemplate(listId: source.id, templateName: '  Veckomall  ');

      final doc =
          await firestore.collection(_templatesPath).doc(templateId).get();
      expect(doc.exists, isTrue);
      final data = doc.data()!;
      expect(data['name'], 'Veckomall'); // trimmed
      expect(data['ownerId'], _userId);
      expect(data['originalListId'], source.id);
      expect((data['items'] as List), hasLength(2));
      expect((data['metadata'] as Map)['itemCount'], 2);
    });

    test('validates ownership of source list before writing', () async {
      final firestore = FakeFirebaseFirestore();
      final source = _list(ownerId: 'bob');
      final calls = <_OwnershipCall>[];

      await _module(firestore,
              readList: (_) async => source, ownershipCalls: calls)
          .saveAsTemplate(listId: source.id, templateName: 'T');

      expect(calls.single.currentUserId, _userId);
      expect(calls.single.resourceOwnerId, 'bob');
      expect(calls.single.resourceType, 'shopping_list');
    });

    test('rejects when ownership validation throws — no write', () async {
      final firestore = FakeFirebaseFirestore();
      final source = _list();
      await expectLater(
        () => _module(firestore,
                readList: (_) async => source, ownershipThrows: true)
            .saveAsTemplate(listId: source.id, templateName: 'T'),
        throwsA(isA<PermissionDeniedException>()),
      );
      expect((await firestore.collection(_templatesPath).get()).docs, isEmpty);
    });
  });

  group('updateTemplate', () {
    test('throws ResourceNotFoundException when template missing', () async {
      final firestore = FakeFirebaseFirestore();
      await expectLater(
        () => _module(firestore).updateTemplate(templateId: 'missing'),
        throwsA(isA<ResourceNotFoundException>()),
      );
    });

    test('partial update: only changes fields explicitly passed', () async {
      final firestore = FakeFirebaseFirestore();
      await firestore.collection(_templatesPath).doc('t1').set({
        'ownerId': _userId,
        'name': 'Old',
        'description': 'old-desc',
        'tags': ['x'],
        'isPublic': false,
      });

      await _module(firestore).updateTemplate(
        templateId: 't1',
        name: '  New  ',
        isPublic: true,
      );

      final doc = await firestore.collection(_templatesPath).doc('t1').get();
      final data = doc.data()!;
      expect(data['name'], 'New'); // trimmed
      expect(data['isPublic'], isTrue);
      expect(data['description'], 'old-desc'); // unchanged
      expect(data['tags'], ['x']); // unchanged
    });
  });

  group('deleteTemplate', () {
    test('throws ResourceNotFoundException when template missing', () async {
      final firestore = FakeFirebaseFirestore();
      await expectLater(
        () => _module(firestore).deleteTemplate('missing'),
        throwsA(isA<ResourceNotFoundException>()),
      );
    });

    test('removes the template doc after ownership validation', () async {
      final firestore = FakeFirebaseFirestore();
      await firestore.collection(_templatesPath).doc('t1').set({
        'ownerId': _userId,
        'name': 'X',
      });

      final calls = <_OwnershipCall>[];
      await _module(firestore, ownershipCalls: calls).deleteTemplate('t1');

      final doc = await firestore.collection(_templatesPath).doc('t1').get();
      expect(doc.exists, isFalse);
      expect(calls.single.resourceType, 'template');
    });
  });

  group('getUserTemplates', () {
    test('returns only templates owned by the current user', () async {
      final firestore = FakeFirebaseFirestore();
      await firestore.collection(_templatesPath).doc('mine').set({
        'ownerId': _userId,
        'name': 'Mine',
        'createdAt': Timestamp.fromDate(DateTime.utc(2026, 1, 2)),
      });
      await firestore.collection(_templatesPath).doc('theirs').set({
        'ownerId': 'bob',
        'name': 'Bob',
        'createdAt': Timestamp.fromDate(DateTime.utc(2026, 1, 1)),
      });

      final templates = await _module(firestore).getUserTemplates();
      expect(templates, hasLength(1));
      expect(templates.single['id'], 'mine');
    });
  });

  group('getPublicTemplates', () {
    test('returns only isPublic=true templates', () async {
      final firestore = FakeFirebaseFirestore();
      await firestore.collection(_templatesPath).doc('pub').set({
        'ownerId': _userId,
        'name': 'Public template',
        'isPublic': true,
        'createdAt': Timestamp.fromDate(DateTime.utc(2026, 1, 1)),
      });
      await firestore.collection(_templatesPath).doc('priv').set({
        'ownerId': _userId,
        'name': 'Private',
        'isPublic': false,
        'createdAt': Timestamp.fromDate(DateTime.utc(2026, 1, 1)),
      });

      final templates = await _module(firestore).getPublicTemplates();
      expect(templates.map((t) => t['id']).toSet(), {'pub'});
    });

    test('filters by case-insensitive search on name OR description', () async {
      final firestore = FakeFirebaseFirestore();
      await firestore.collection(_templatesPath).doc('t1').set({
        'ownerId': _userId,
        'name': 'Veckans handla',
        'description': '',
        'isPublic': true,
        'createdAt': Timestamp.fromDate(DateTime.utc(2026, 1, 1)),
      });
      await firestore.collection(_templatesPath).doc('t2').set({
        'ownerId': _userId,
        'name': 'Helg',
        'description': 'för en lugn HANDLA-runda',
        'isPublic': true,
        'createdAt': Timestamp.fromDate(DateTime.utc(2026, 1, 2)),
      });
      await firestore.collection(_templatesPath).doc('t3').set({
        'ownerId': _userId,
        'name': 'Pasta',
        'description': 'middag',
        'isPublic': true,
        'createdAt': Timestamp.fromDate(DateTime.utc(2026, 1, 3)),
      });

      final hits =
          await _module(firestore).getPublicTemplates(searchQuery: 'HANDLA');
      expect(hits.map((t) => t['id']).toSet(), {'t1', 't2'});
    });

    test('filters by tag membership (any-of)', () async {
      final firestore = FakeFirebaseFirestore();
      await firestore.collection(_templatesPath).doc('t1').set({
        'ownerId': _userId,
        'name': 'A',
        'isPublic': true,
        'tags': ['vegan', 'snabb'],
        'createdAt': Timestamp.fromDate(DateTime.utc(2026, 1, 1)),
      });
      await firestore.collection(_templatesPath).doc('t2').set({
        'ownerId': _userId,
        'name': 'B',
        'isPublic': true,
        'tags': ['kött'],
        'createdAt': Timestamp.fromDate(DateTime.utc(2026, 1, 1)),
      });

      final hits = await _module(firestore).getPublicTemplates(tags: ['vegan']);
      expect(hits.map((t) => t['id']).toSet(), {'t1'});
    });
  });

  group('createListFromTemplate', () {
    test('throws ResourceNotFoundException when template missing', () async {
      final firestore = FakeFirebaseFirestore();
      await expectLater(
        () => _module(firestore)
            .createListFromTemplate(templateId: 'missing', listName: 'X'),
        throwsA(isA<ResourceNotFoundException>()),
      );
    });

    test('throws PermissionDeniedException for private template owned by other',
        () async {
      final firestore = FakeFirebaseFirestore();
      await firestore.collection(_templatesPath).doc('t1').set({
        'ownerId': 'bob',
        'isPublic': false,
        'items': <Map<String, dynamic>>[],
      });

      await expectLater(
        () => _module(firestore)
            .createListFromTemplate(templateId: 't1', listName: 'Mine'),
        throwsA(isA<PermissionDeniedException>()),
      );
    });

    test('creates a new list via createList callback for public template',
        () async {
      final firestore = FakeFirebaseFirestore();
      await firestore.collection(_templatesPath).doc('t1').set({
        'ownerId': 'bob',
        'isPublic': true,
        'items': [
          _item('Mjölk').toFirestore(),
          _item('Bröd').toFirestore(),
        ],
      });

      final calls = <_CreateListCall>[];
      final newId = await _module(firestore, createListCalls: calls)
          .createListFromTemplate(
        templateId: 't1',
        listName: '  Min nya lista  ',
      );

      expect(newId, isNotEmpty);
      expect(calls.single.entity.name, 'Min nya lista'); // trimmed
      expect(calls.single.entity.ownerId, _userId);
      expect(calls.single.entity.items.map((i) => i.name).toSet(),
          {'Mjölk', 'Bröd'});
    });

    test(
        'private template owned by current user is allowed (no public flag needed)',
        () async {
      final firestore = FakeFirebaseFirestore();
      await firestore.collection(_templatesPath).doc('t1').set({
        'ownerId': _userId,
        'isPublic': false,
        'items': <Map<String, dynamic>>[],
      });

      final calls = <_CreateListCall>[];
      await _module(firestore, createListCalls: calls)
          .createListFromTemplate(templateId: 't1', listName: 'Lista');
      expect(calls, hasLength(1));
    });
  });
}
