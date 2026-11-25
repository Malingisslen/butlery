import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:butlery/models/menu/menu_wish.dart';
import 'package:butlery/models/menu/weekly_menu_plan.dart';
import 'package:butlery/services/menu/lunchbox_days_store.dart';
import 'package:butlery/viewmodels/menu_wishes_viewmodel.dart';

import '../../helpers/fake_menu_wish_profile.dart';

const _a = MenuWish(id: 'a', name: 'A', text: 'text a');
const _b = MenuWish(id: 'b', name: 'B', text: 'text b');
const _c = MenuWish(id: 'c', name: 'C', text: 'text c');

void main() {
  late FakeMenuWishProfile profile;
  late MenuWishesViewModel vm;
  var nextId = 0;

  MenuWishesViewModel build() => MenuWishesViewModel(
    reader: profile,
    editor: profile,
    newId: () => 'new${nextId++}',
  );

  setUp(() => nextId = 0);

  tearDown(() => vm.dispose());

  group('save', () {
    test('puts a new wish first and writes the list once', () async {
      profile = FakeMenuWishProfile(wishes: const [_a]);
      vm = build();

      expect(await vm.save('en ny text'), isTrue);

      expect(profile.savedWrites, hasLength(1));
      expect(vm.wishes.map((w) => w.id), ['new0', 'a']);
      expect(vm.wishes.first.text, 'en ny text');
    });

    test('is refused when the list is full, with the limit message', () async {
      profile = FakeMenuWishProfile(
        wishes: [
          for (var i = 0; i < MenuWishes.maxWishes; i++)
            MenuWish(id: 'w$i', name: 'n$i', text: 'text $i'),
        ],
      );
      vm = build();

      expect(vm.isFull, isTrue);
      expect(await vm.save('en ny text'), isFalse);

      expect(vm.error, contains('${MenuWishes.maxWishes}'));
      expect(vm.error, contains('Ta bort'));
      expect(profile.savedWrites, isEmpty);
    });

    test('a wish that is already saved returns true without a write', () async {
      profile = FakeMenuWishProfile(wishes: const [_a]);
      vm = build();

      expect(await vm.save('  TEXT   a '), isTrue);

      expect(profile.savedWrites, isEmpty);
      expect(vm.error, isNull);
    });

    test('a refused write returns false and says it was not saved', () async {
      profile = FakeMenuWishProfile()..failWrites = true;
      vm = build();

      expect(await vm.save('en ny text'), isFalse);

      expect(vm.error, 'Önskemålet kunde inte sparas');
      expect(vm.wishes, isEmpty);
    });
  });

  group('rename', () {
    test('changes the name only', () async {
      profile = FakeMenuWishProfile(wishes: const [_a, _b]);
      vm = build();

      expect(await vm.rename(_b, '  Nytt  '), isTrue);

      expect(vm.wishes.map((w) => w.name), ['A', 'Nytt']);
      expect(vm.wishes.last.text, 'text b');
    });

    test('an empty name is refused without a write', () async {
      profile = FakeMenuWishProfile(wishes: const [_a]);
      vm = build();

      expect(await vm.rename(_a, '   '), isFalse);

      expect(profile.savedWrites, isEmpty);
    });
  });

  group('remove', () {
    test('hides the wish at once, then writes', () async {
      profile = FakeMenuWishProfile(wishes: const [_a, _b]);
      final release = Completer<void>();
      profile.gate = release.future;
      vm = build();

      final removal = vm.remove(_a);
      await Future<void>.delayed(Duration.zero);

      expect(vm.wishes.map((w) => w.id), ['b']);
      expect(profile.profile.savedMenuWishes, hasLength(2));
      expect(profile.savedWrites.single.map((w) => w.id), ['b']);

      release.complete();
      expect(await removal, isTrue);
      expect(profile.profile.savedMenuWishes.map((w) => w.id), ['b']);
      expect(vm.wishes.map((w) => w.id), ['b']);
    });

    test('a refused write brings the wish back', () async {
      profile = FakeMenuWishProfile(wishes: const [_a])..failWrites = true;
      vm = build();

      expect(await vm.remove(_a), isFalse);

      expect(vm.wishes, [_a]);
      expect(vm.error, isNotNull);
    });

    test('undoRemove puts the wish back where it was', () async {
      profile = FakeMenuWishProfile(wishes: const [_a, _b, _c]);
      vm = build();
      await vm.remove(_b);

      expect(await vm.undoRemove(_b, 1), isTrue);

      expect(vm.wishes.map((w) => w.id), ['a', 'b', 'c']);
    });

    test('undoRemove clamps an index past the end', () async {
      profile = FakeMenuWishProfile(wishes: const [_a, _b]);
      vm = build();
      await vm.remove(_b);

      await vm.undoRemove(_b, 9);

      expect(vm.wishes.map((w) => w.id), ['a', 'b']);
    });
  });

  group('rememberLast', () {
    test('writes a wish that differs from the stored one', () async {
      profile = FakeMenuWishProfile(
        lastWish: const LastMenuWish(text: 'gammal'),
      );
      vm = build();

      await vm.rememberLast('ny', pantryFocus: false, unchangedBuiltIn: false);

      expect(profile.lastWrites.single, const LastMenuWish(text: 'ny'));
      expect(vm.lastWish?.text, 'ny');
    });

    test('writes when only the pantry flag differs', () async {
      profile = FakeMenuWishProfile(lastWish: const LastMenuWish(text: 'x'));
      vm = build();

      await vm.rememberLast('x', pantryFocus: true, unchangedBuiltIn: false);

      expect(
        profile.lastWrites.single,
        const LastMenuWish(text: 'x', pantryFocus: true),
      );
    });

    test('skips the wish that is already stored', () async {
      profile = FakeMenuWishProfile(
        lastWish: const LastMenuWish(text: 'x', pantryFocus: true),
      );
      vm = build();

      await vm.rememberLast(' x ', pantryFocus: true, unchangedBuiltIn: false);

      expect(profile.lastWrites, isEmpty);
    });

    test('skips an unedited built-in', () async {
      profile = FakeMenuWishProfile();
      vm = build();

      await vm.rememberLast(
        '7 middagar snabba',
        pantryFocus: false,
        unchangedBuiltIn: true,
      );

      expect(profile.lastWrites, isEmpty);
    });

    test('skips empty text', () async {
      profile = FakeMenuWishProfile();
      vm = build();

      await vm.rememberLast('  ', pantryFocus: false, unchangedBuiltIn: false);

      expect(profile.lastWrites, isEmpty);
    });
  });

  group('lunchbox days', () {
    const store = LunchboxDaysStore();
    var uid = 'u-1';

    MenuWishesViewModel buildDays({bool on = true, String? Function()? user}) =>
        MenuWishesViewModel(
          reader: profile,
          editor: profile,
          currentUserId: user ?? () => uid,
          mealBoxesOn: () => on,
        );

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      uid = 'u-1';
      profile = FakeMenuWishProfile();
    });

    test('the choice kept on this device from last week is loaded and '
        'announced', () async {
      await store.write('u-1', {DayOfWeek.tue, DayOfWeek.thu});
      vm = buildDays();
      var notifications = 0;
      vm.addListener(() => notifications++);

      expect(vm.offersLunchboxDays, isTrue);
      expect(vm.lunchboxDays, isEmpty, reason: 'the read has not answered yet');
      await pumpEventQueue();

      expect(vm.lunchboxDays, {DayOfWeek.tue, DayOfWeek.thu});
      expect(notifications, greaterThanOrEqualTo(1));
    });

    test('toggling adds then removes a day and persists each step for this '
        'account only', () async {
      vm = buildDays();
      await pumpEventQueue();

      vm.toggleLunchboxDay(DayOfWeek.mon);
      vm.toggleLunchboxDay(DayOfWeek.fri);
      await pumpEventQueue();
      expect(vm.lunchboxDays, {DayOfWeek.mon, DayOfWeek.fri});
      expect(await store.read('u-1'), {DayOfWeek.mon, DayOfWeek.fri});
      expect(await store.read('u-2'), isEmpty);

      vm.toggleLunchboxDay(DayOfWeek.mon);
      await pumpEventQueue();
      expect(vm.lunchboxDays, {DayOfWeek.fri});
      expect(await store.read('u-1'), {DayOfWeek.fri});
    });

    test('a tap made while the stored choice is still being read wins over '
        'it', () async {
      await store.write('u-1', {DayOfWeek.tue});
      vm = buildDays();

      vm.toggleLunchboxDay(DayOfWeek.sun);
      await pumpEventQueue();

      expect(vm.lunchboxDays, {DayOfWeek.sun});
      expect(await store.read('u-1'), {DayOfWeek.sun});
    });

    test('a day tapped on and off again while the stored choice is being read '
        'stays cleared', () async {
      await store.write('u-1', {DayOfWeek.tue});
      vm = buildDays();

      vm.toggleLunchboxDay(DayOfWeek.sun);
      vm.toggleLunchboxDay(DayOfWeek.sun);
      await pumpEventQueue();

      expect(vm.lunchboxDays, isEmpty);
      expect(await store.read('u-1'), isEmpty);
    });

    test('the switch off offers nothing and reads nothing', () async {
      await store.write('u-1', {DayOfWeek.tue});
      vm = buildDays(on: false);
      await pumpEventQueue();

      expect(vm.offersLunchboxDays, isFalse);
      expect(vm.lunchboxDays, isEmpty);
    });

    test(
      'signed out, a toggle shows on screen but is written nowhere',
      () async {
        vm = buildDays(user: () => null);
        await pumpEventQueue();

        vm.toggleLunchboxDay(DayOfWeek.wed);
        await pumpEventQueue();

        expect(vm.lunchboxDays, {DayOfWeek.wed});
        final prefs = await SharedPreferences.getInstance();
        expect(
          prefs.getKeys().where(
            (k) => k.startsWith(LunchboxDaysStore.keyPrefix),
          ),
          isEmpty,
        );
      },
    );
  });
}
