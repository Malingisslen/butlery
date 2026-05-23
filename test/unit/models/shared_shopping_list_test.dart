/// Unit tests for SharedShoppingList.
library;

import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/models/shared_shopping_list.dart';

SharedShoppingList _build({
  String id = 'sh-1',
  String sharedByUserId = 'alice',
  String sharedByDisplayName = 'Alice',
  DateTime? sharedAt,
  String? shareMessage,
  int viewCount = 0,
  int engagementCount = 0,
  int dismissalCount = 0,
  String listName = 'Veckans',
  String? listDescription,
  int itemCount = 3,
  String originalOwnerId = 'alice',
  String originalOwnerDisplayName = 'Alice',
  String? shoppingListId,
}) {
  return SharedShoppingList(
    id: id,
    sharedByUserId: sharedByUserId,
    sharedByDisplayName: sharedByDisplayName,
    sharedAt: sharedAt ?? DateTime.utc(2026, 1, 1),
    shareMessage: shareMessage,
    viewCount: viewCount,
    engagementCount: engagementCount,
    dismissalCount: dismissalCount,
    listName: listName,
    listDescription: listDescription,
    itemCount: itemCount,
    originalOwnerId: originalOwnerId,
    originalOwnerDisplayName: originalOwnerDisplayName,
    shoppingListId: shoppingListId,
  );
}

void main() {
  group('SharedShoppingList.create factory', () {
    test('generates a UUID id', () {
      final s = SharedShoppingList.create(
        sharedByUserId: 'alice',
        sharedByDisplayName: 'Alice',
        sharedToUserIds: const ['bob'],
        shareMessage: 'hej',
        listName: 'Veckans',
      );
      expect(s.id, isNotEmpty);
      expect(s.id, hasLength(36));
    });

    test('itemCount falls back to 0 when neither listItems nor itemCount given',
        () {
      final s = SharedShoppingList.create(
        sharedByUserId: 'alice',
        sharedByDisplayName: 'Alice',
        sharedToUserIds: const [],
        shareMessage: '',
        listName: 'X',
      );
      expect(s.itemCount, 0);
    });

    test('itemCount honors explicit override', () {
      final s = SharedShoppingList.create(
        sharedByUserId: 'a',
        sharedByDisplayName: 'A',
        sharedToUserIds: const [],
        shareMessage: '',
        listName: 'X',
        itemCount: 17,
      );
      expect(s.itemCount, 17);
    });

    test('original owner mirrors sharer (first-share invariant)', () {
      final s = SharedShoppingList.create(
        sharedByUserId: 'alice',
        sharedByDisplayName: 'Alice',
        sharedToUserIds: const [],
        shareMessage: '',
        listName: 'X',
      );
      expect(s.originalOwnerId, 'alice');
      expect(s.originalOwnerDisplayName, 'Alice');
    });

    test('sharedAt stamps via clock.now()', () {
      withClock(Clock.fixed(DateTime.utc(2026, 5, 23, 12)), () {
        final s = SharedShoppingList.create(
          sharedByUserId: 'a',
          sharedByDisplayName: 'A',
          sharedToUserIds: const [],
          shareMessage: '',
          listName: 'X',
        );
        expect(s.sharedAt, DateTime.utc(2026, 5, 23, 12));
      });
    });
  });

  group('content helpers', () {
    test('contentTypeName is "shopping_list"', () {
      expect(_build().contentTypeName, 'shopping_list');
    });

    test('contentSnapshot is empty (items stored in subcollection)', () {
      expect(_build().contentSnapshot, isEmpty);
    });

    test('getContentTitle returns listName', () {
      expect(
          _build(listName: 'Helgens lista').getContentTitle(), 'Helgens lista');
    });

    test('getContentDescription uses description when present', () {
      expect(_build(listDescription: 'Specifik').getContentDescription(),
          'Specifik');
    });

    test(
        'getContentDescription falls back to "<n> artiklar" when no description',
        () {
      expect(_build(itemCount: 5).getContentDescription(), '5 artiklar');
    });
  });

  group('itemCountText', () {
    test('"1 artikel" for singular', () {
      expect(_build(itemCount: 1).itemCountText, '1 artikel');
    });

    test('"<n> artiklar" for non-singular (including 0)', () {
      expect(_build(itemCount: 0).itemCountText, '0 artiklar');
      expect(_build(itemCount: 5).itemCountText, '5 artiklar');
    });

    test('itemSummary delegates to itemCountText (deprecated alias)', () {
      // ignore: deprecated_member_use_from_same_package
      expect(_build(itemCount: 3).itemSummary, '3 artiklar');
    });
  });

  test('joinCount mirrors engagementCount', () {
    expect(_build(engagementCount: 7).joinCount, 7);
  });

  group('serialization', () {
    test('toFirestore round-trips via fromMap', () {
      final original = _build(
        shareMessage: 'kolla',
        viewCount: 2,
        engagementCount: 3,
        dismissalCount: 1,
        listDescription: 'för fredag',
        shoppingListId: 'list-1',
      );
      final restored =
          SharedShoppingList.fromMap(original.id, original.toFirestore());

      expect(restored.id, original.id);
      expect(restored.listName, original.listName);
      expect(restored.listDescription, original.listDescription);
      expect(restored.itemCount, original.itemCount);
      expect(restored.originalOwnerId, original.originalOwnerId);
      expect(
          restored.originalOwnerDisplayName, original.originalOwnerDisplayName);
      expect(restored.shoppingListId, original.shoppingListId);
      expect(restored.engagementCount, original.engagementCount);
      expect(restored.viewCount, original.viewCount);
      expect(restored.dismissalCount, original.dismissalCount);
    });

    test('toFirestore omits shoppingListId when null', () {
      final payload = _build().toFirestore();
      expect(payload.containsKey('shoppingListId'), isFalse);
    });

    test('toJson round-trips via fromJson', () {
      final original = _build(shoppingListId: 'list-1', engagementCount: 4);
      final restored = SharedShoppingList.fromJson(original.toJson());
      expect(restored.id, original.id);
      expect(restored.engagementCount, original.engagementCount);
      expect(restored.shoppingListId, original.shoppingListId);
    });

    test('fromMap uses sharedByUserId as fallback for missing originalOwnerId',
        () {
      final restored = SharedShoppingList.fromMap('id', {
        'sharedByUserId': 'alice',
        'sharedByDisplayName': 'Alice',
        'sharedAt': DateTime.utc(2026, 1, 1),
        'listName': 'X',
      });
      expect(restored.originalOwnerId, 'alice');
    });
  });

  group('copyWithStatus', () {
    test('updates viewCount + engagementCount + dismissalCount', () {
      final updated = _build().copyWithStatus(
        viewCount: 10,
        engagementCount: 5,
        dismissalCount: 2,
      ) as SharedShoppingList;
      expect(updated.viewCount, 10);
      expect(updated.engagementCount, 5);
      expect(updated.dismissalCount, 2);
    });

    test('preserves untouched fields', () {
      final base = _build(listName: 'X');
      final updated = base.copyWithStatus(viewCount: 1) as SharedShoppingList;
      expect(updated.listName, 'X');
      expect(updated.id, base.id);
    });
  });

  group('copyWith', () {
    test('joinedCount param wins over engagementCount', () {
      final updated = _build(engagementCount: 1)
          .copyWith(joinedCount: 99, engagementCount: 5);
      expect(updated.engagementCount, 99);
    });

    test('replaces just one field', () {
      final updated = _build().copyWith(listName: 'Helgens');
      expect(updated.listName, 'Helgens');
    });
  });

  group('equality + hash', () {
    test('id-only equality (same runtimeType)', () {
      final a = _build(listName: 'A');
      final b = _build(listName: 'B');
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('different id → unequal', () {
      expect(_build(id: 'x'), isNot(_build(id: 'y')));
    });
  });

  test('toString includes id, listName, sharedBy', () {
    final s = _build(listName: 'Helgens', sharedByDisplayName: 'Bob');
    final str = s.toString();
    expect(str, contains('sh-1'));
    expect(str, contains('Helgens'));
    expect(str, contains('Bob'));
  });
}
