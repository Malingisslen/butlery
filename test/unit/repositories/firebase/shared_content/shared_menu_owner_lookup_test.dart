/// BUT-1504: the owner's saved menus are marked from ONE query on their own
/// menu rows; rows without a usable key, inactive rows and the owner's own uid
/// never count.
library;

import 'package:butlery/repositories/firebase/shared_content/shared_menu_owner_lookup.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late FakeFirebaseFirestore db;
  late SharedMenuOwnerLookup lookup;

  Future<void> row(
    String id, {
    String contentType = 'menu',
    String sharedBy = 'me',
    Object? menuId,
    Object? sharedTo = const ['a'],
    bool? isActive,
  }) => db.collection('shared_content').doc(id).set({
    'contentType': contentType,
    'sharedByUserId': sharedBy,
    'sharedToUserIds': sharedTo,
    'originalMenuId': ?menuId,
    'isActive': ?isActive,
  });

  setUp(() {
    db = FakeFirebaseFirestore();
    lookup = SharedMenuOwnerLookup(db.collection('shared_content'), () => 'me');
  });

  test('unions the recipients of several shares of one menu', () async {
    await row('1', menuId: 'm1', sharedTo: ['a', 'b']);
    await row('2', menuId: 'm1', sharedTo: ['b', 'c']);
    await row('3', menuId: 'm2');

    final result = await lookup.recipientsByMenu();

    expect(result['m1'], {'a', 'b', 'c'});
    expect(result['m2'], {'a'});
  });

  test('ignores other users, other content types and unusable rows', () async {
    await row('1', menuId: 'm1', sharedBy: 'other');
    await row('2', menuId: 'm1', contentType: 'recipe');
    await row('3');
    await row('4', menuId: 5);
    await row('5', menuId: '');
    await row('6', menuId: 'm1', sharedTo: 'not-a-list');
    await row('7', menuId: 'm1', isActive: false);
    await row('8', menuId: 'm3', sharedTo: ['me']);

    expect(await lookup.recipientsByMenu(), isEmpty);
  });

  test(
    'reads at most the cap, so a heavy sharer pays a bounded cost',
    () async {
      for (var i = 0; i <= ownMenuShareReadCap; i++) {
        await row('r$i', menuId: 'm$i');
      }

      expect(
        (await lookup.recipientsByMenu()).length,
        equals(ownMenuShareReadCap),
      );
    },
  );
}
