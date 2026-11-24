import 'package:butlery/models/menu/menu_wish.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _row(String id, String text, {String? name}) => {
  'id': id,
  'text': text,
  'name': ?name,
};

void main() {
  group('MenuWishes.fromFirestoreList reads untrusted input', () {
    test('a stored list round-trips', () {
      final wishes = [
        const MenuWish(id: 'a', name: 'Barnvänligt', text: 'Barnvänliga'),
        const MenuWish(id: 'b', name: 'Fisk', text: 'Fisk två dagar'),
      ];
      expect(
        MenuWishes.fromFirestoreList(MenuWishes.toFirestoreList(wishes)),
        wishes,
      );
    });

    test('rows that do not parse are skipped, the rest kept', () {
      final read = MenuWishes.fromFirestoreList([
        'not a map',
        {'id': 1, 'text': 'id is a number'},
        _row('', 'empty id'),
        _row('x' * (MenuWishes.maxIdLength + 1), 'id too long'),
        {'id': 'no-text'},
        _row('blank', '   '),
        _row('ok', 'Barnvänliga middagar', name: 'Barn'),
      ]);
      expect(read.map((w) => w.id), ['ok']);
    });

    test('a repeated id keeps its first row', () {
      final read = MenuWishes.fromFirestoreList([
        _row('a', 'first'),
        _row('a', 'second'),
      ]);
      expect(read.single.text, 'first');
    });

    test('the list is cut at maxWishes', () {
      final read = MenuWishes.fromFirestoreList([
        for (var i = 0; i < MenuWishes.maxWishes + 3; i++) _row('w$i', 't$i'),
      ]);
      expect(read, hasLength(MenuWishes.maxWishes));
      expect(read.last.id, 'w${MenuWishes.maxWishes - 1}');
    });

    test('text and name are cut to their lengths', () {
      final read = MenuWishes.fromFirestoreList([
        _row('a', 'x' * 400, name: 'n' * 60),
      ]).single;
      expect(read.text, hasLength(MenuWishes.maxTextLength));
      expect(read.name, hasLength(MenuWishes.maxNameLength));
    });

    test('a missing name falls back to one made from the text', () {
      final read = MenuWishes.fromFirestoreList([_row('a', 'Fisk')]).single;
      expect(read.name, 'Fisk');
    });

    test('not a list reads as empty', () {
      expect(MenuWishes.fromFirestoreList({'a': 1}), isEmpty);
      expect(MenuWishes.fromFirestoreList(null), isEmpty);
    });
  });

  group('MenuWishes edits', () {
    const a = MenuWish(id: 'a', name: 'A', text: 'Barnvänliga middagar');

    test('add puts the new wish first with a name from its text', () {
      final next = MenuWishes.add([a], '  Fisk på måndag ', id: 'b')!;
      expect(next.map((w) => w.id), ['b', 'a']);
      expect(next.first.text, 'Fisk på måndag');
      expect(next.first.name, 'Fisk på måndag');
    });

    test('add refuses a text already saved, ignoring case and spacing', () {
      expect(MenuWishes.add([a], 'barnvänliga   MIDDAGAR', id: 'b'), isNull);
    });

    test('add refuses an empty text and a full list', () {
      expect(MenuWishes.add([a], '   ', id: 'b'), isNull);
      final full = [
        for (var i = 0; i < MenuWishes.maxWishes; i++)
          MenuWish(id: 'w$i', name: 'n', text: 't$i'),
      ];
      expect(MenuWishes.add(full, 'ny', id: 'b'), isNull);
    });

    test('rename changes only the name; empty or unknown is refused', () {
      final next = MenuWishes.rename([a], 'a', ' Barn ')!;
      expect(next.single.name, 'Barn');
      expect(next.single.text, a.text);
      expect(MenuWishes.rename([a], 'a', '  '), isNull);
      expect(MenuWishes.rename([a], 'zz', 'x'), isNull);
    });

    test('remove then restore puts the wish back where it was', () {
      const b = MenuWish(id: 'b', name: 'B', text: 'b');
      const c = MenuWish(id: 'c', name: 'C', text: 'c');
      final removed = MenuWishes.remove([a, b, c], 'b');
      expect(removed.map((w) => w.id), ['a', 'c']);
      expect(MenuWishes.restore(removed, b, 1).map((w) => w.id), [
        'a',
        'b',
        'c',
      ]);
      expect(MenuWishes.restore([a, b], b, 0).map((w) => w.id), ['a', 'b']);
    });

    test('nameFor cuts a long text at a word break with an ellipsis', () {
      final name = MenuWishes.nameFor(
        'Barnvänliga middagar utan starka kryddor och gärna med pasta',
      );
      expect(name.length, lessThanOrEqualTo(MenuWishes.maxNameLength));
      expect(name, endsWith('…'));
      expect(name, startsWith('Barnvänliga middagar utan starka'));
    });
  });

  group('LastMenuWish', () {
    test('round-trips text and pantry flag', () {
      const wish = LastMenuWish(text: '7 middagar', pantryFocus: true);
      expect(LastMenuWish.fromFirestore(wish.toFirestore()), wish);
    });

    test('a broken map reads as none', () {
      expect(LastMenuWish.fromFirestore(null), isNull);
      expect(LastMenuWish.fromFirestore({'text': 3}), isNull);
      expect(LastMenuWish.fromFirestore({'text': '  '}), isNull);
    });

    test('pantryFocus is only true for a stored true', () {
      expect(
        LastMenuWish.fromFirestore({
          'text': 'a',
          'pantryFocus': 'yes',
        })!.pantryFocus,
        isFalse,
      );
    });

    test('sameAs compares the trimmed text and the flag', () {
      const wish = LastMenuWish(text: '7 middagar');
      expect(wish.sameAs(' 7 middagar ', pantryFocus: false), isTrue);
      expect(wish.sameAs('7 middagar', pantryFocus: true), isFalse);
      expect(wish.sameAs('6 middagar', pantryFocus: false), isFalse);
    });
  });
}
