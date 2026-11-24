/// BUT-2529 step 2: saved wishes and "Som förra veckan" on the week menu's
/// chip row, the "Mina önskemål" sheet, and what a generation from the
/// prompt field does with the wish (remember it, offer to save it).
library;

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:butlery/models/menu/menu_wish.dart';
import 'package:butlery/viewmodels/menu_viewmodel.dart';
import 'package:butlery/views/veckomeny_view/veckomeny_body.dart';
import 'package:butlery/widgets/common/buttons/hero_button.dart';
import 'package:butlery/widgets/common/chips/butlery_filter_chip.dart';
import 'package:butlery/widgets/menu/menu_wishes_sheet.dart';

import 'veckomeny_flow_harness.dart';

const _kids = MenuWish(id: 'a', name: 'Barnvänligt', text: '5 barnvänliga');
const _fish = MenuWish(id: 'b', name: 'Fisk', text: '3 middagar med fisk');
const _veg = MenuWish(id: 'c', name: 'Veg', text: '4 vegetariska middagar');

void main() {
  late VeckomenyFlowHarness h;

  setUp(() async {
    h = VeckomenyFlowHarness();
    await h.setUp();
    h.menu.next = {
      'Middag': [flowDinner(1)],
    };
  });

  tearDown(() => h.tearDown());

  Future<void> open(WidgetTester tester) =>
      withClock(Clock.fixed(flowMonday), () async {
        await h.pump(tester);
        await tester.pumpAndSettle();
      });

  MenuViewModel menuVm(WidgetTester tester) => Provider.of<MenuViewModel>(
    tester.element(find.byType(VeckomenyBody)),
    listen: false,
  );

  String fieldText(WidgetTester tester) =>
      tester.widget<TextField>(find.byType(TextField).first).controller!.text;

  Future<void> tapGenerate(WidgetTester tester) async {
    await tester.tap(
      find.descendant(
        of: find.byKey(const ValueKey('test-veckomeny-generate')),
        matching: find.byType(FormButton),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> openSheet(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('wish-chip-all')));
    await tester.pumpAndSettle();
  }

  List<MenuWish> stored() => h.wishProfile.profile.savedMenuWishes;

  const savePrompt = 'Spara önskemålet till nästa vecka?';

  group('chip row', () {
    testWidgets('no "Som förra veckan" chip without a last wish', (
      tester,
    ) async {
      await open(tester);

      expect(find.text('Som förra veckan'), findsNothing);
      expect(find.text('Alla …'), findsOneWidget);
    });

    testWidgets('"Som förra veckan" sits after the built-ins and fills text '
        'and pantry flag', (tester) async {
      h.wishProfile.seed(
        wishes: const [_kids],
        lastWish: const LastMenuWish(
          text: '4 middagar vegetariskt',
          pantryFocus: true,
        ),
      );
      await open(tester);

      final labels = [
        for (final chip in tester.widgetList<ButleryFilterChip>(
          find.byType(ButleryFilterChip),
        ))
          chip.label,
      ];
      expect(labels, [
        'Snabb vecka',
        'Använd det jag har hemma',
        'Som förra veckan',
        'Barnvänligt',
        'Alla …',
      ]);

      expect(find.text('Som förra veckan'), findsOneWidget);

      await tester.tap(find.text('Som förra veckan'));
      await tester.pumpAndSettle();
      expect(fieldText(tester), '4 middagar vegetariskt');
      expect(
        tester.getSemantics(
          find.widgetWithText(ButleryFilterChip, 'Som förra veckan'),
        ),
        isSemantics(isSelected: true),
      );

      await tapGenerate(tester);
      expect(menuVm(tester).pantryFocusFor('4 middagar vegetariskt'), isTrue);
    });

    testWidgets('a saved wish chip fills its text without pantry focus', (
      tester,
    ) async {
      h.wishProfile.seed(wishes: const [_kids]);
      await open(tester);

      await tester.tap(find.text('Barnvänligt'));
      await tester.pumpAndSettle();
      expect(fieldText(tester), '5 barnvänliga');
      await tapGenerate(tester);

      expect(menuVm(tester).pantryFocusFor('5 barnvänliga'), isFalse);
    });

    testWidgets('a saved wish chip has a tap target of at least 48 dp', (
      tester,
    ) async {
      h.wishProfile.seed(wishes: const [_kids]);
      await open(tester);

      for (final label in ['Barnvänligt', 'Alla …']) {
        final box = tester.getSize(
          find.widgetWithText(ButleryFilterChip, label),
        );
        expect(box.height, greaterThanOrEqualTo(48), reason: label);
      }
    });

    testWidgets('"Alla …" opens the sheet', (tester) async {
      await open(tester);
      expect(find.byType(MenuWishesSheet), findsNothing);

      await openSheet(tester);

      expect(find.byType(MenuWishesSheet), findsOneWidget);
      expect(find.text('Mina önskemål'), findsOneWidget);
    });
  });

  group('sheet', () {
    testWidgets('an empty list says a wish can be saved after generating', (
      tester,
    ) async {
      await open(tester);
      await openSheet(tester);

      expect(find.byKey(const ValueKey('menu-wishes-empty')), findsOneWidget);
      expect(find.text('INBYGGDA'), findsOneWidget);
      Finder inSheet(String text) => find.descendant(
        of: find.byType(MenuWishesSheet),
        matching: find.text(text),
      );
      expect(inSheet('Snabb vecka'), findsOneWidget);
      expect(inSheet('Använd det jag har hemma'), findsOneWidget);
      expect(
        inSheet('Räknas fram för veckans återstående dagar varje gång.'),
        findsOneWidget,
      );
    });

    testWidgets('tapping a wish fills the field and closes the sheet', (
      tester,
    ) async {
      h.wishProfile.seed(wishes: const [_kids]);
      await open(tester);
      await openSheet(tester);

      await tester.tap(find.byKey(const ValueKey('menu-wish-a')));
      await tester.pumpAndSettle();

      expect(find.byType(MenuWishesSheet), findsNothing);
      expect(fieldText(tester), '5 barnvänliga');
      expect(
        tester
            .widget<ButleryFilterChip>(
              find.widgetWithText(ButleryFilterChip, 'Barnvänligt'),
            )
            .selected,
        isTrue,
      );
    });

    testWidgets('"Som förra veckan" in the sheet fills text and flag', (
      tester,
    ) async {
      h.wishProfile.seed(
        lastWish: const LastMenuWish(text: '2 middagar', pantryFocus: true),
      );
      await open(tester);
      await openSheet(tester);

      await tester.tap(find.byKey(const ValueKey('menu-wish-last')));
      await tester.pumpAndSettle();
      await tapGenerate(tester);

      expect(fieldText(tester), '2 middagar');
      expect(menuVm(tester).pantryFocusFor('2 middagar'), isTrue);
    });

    testWidgets('Döp om changes the stored name and the chip', (tester) async {
      h.wishProfile.seed(wishes: const [_kids, _fish]);
      await open(tester);
      await openSheet(tester);

      await tester.tap(find.text('Döp om').first);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('menu-wish-name')),
        'Lätt',
      );
      await tester.pump();
      await tester.tap(find.text('Spara'));
      await tester.pumpAndSettle();

      expect(stored().map((w) => w.name), ['Lätt', 'Fisk']);
      expect(stored().first.text, _kids.text);
      expect(find.text('Lätt'), findsWidgets);
    });

    testWidgets('the rename field stops at 40 characters', (tester) async {
      h.wishProfile.seed(wishes: const [_kids]);
      await open(tester);
      await openSheet(tester);
      await tester.tap(find.text('Döp om'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey('menu-wish-name')),
        'x' * 60,
      );
      await tester.pump();
      await tester.tap(find.text('Spara'));
      await tester.pumpAndSettle();

      expect(stored().single.name.length, MenuWishes.maxNameLength);
    });

    testWidgets('an empty name cannot be saved', (tester) async {
      h.wishProfile.seed(wishes: const [_kids]);
      await open(tester);
      await openSheet(tester);
      await tester.tap(find.text('Döp om'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey('menu-wish-name')),
        '  ',
      );
      await tester.pump();
      await tester.tap(find.text('Spara'));
      await tester.pumpAndSettle();

      expect(h.wishProfile.savedWrites, isEmpty);
      expect(find.byKey(const ValueKey('menu-wish-name')), findsOneWidget);
    });

    testWidgets('Ta bort removes at once and Ångra puts it back in place', (
      tester,
    ) async {
      h.wishProfile.seed(wishes: const [_kids, _fish, _veg]);
      await open(tester);
      await openSheet(tester);

      await tester.tap(find.text('Ta bort').at(1));
      await tester.pumpAndSettle();

      expect(stored().map((w) => w.id), ['a', 'c']);
      expect(find.byType(MenuWishesSheet), findsNothing);
      expect(find.text('Önskemålet togs bort'), findsOneWidget);
      expect(find.text('Fisk'), findsNothing);

      await tester.tap(find.text('Ångra'));
      await tester.pumpAndSettle();

      expect(stored().map((w) => w.id), ['a', 'b', 'c']);
      expect(find.text('Fisk'), findsOneWidget);
    });

    testWidgets('a refused remove puts the wish back and says so', (
      tester,
    ) async {
      h.wishProfile.seed(wishes: const [_kids]);
      h.wishProfile.failWrites = true;
      await open(tester);
      await openSheet(tester);

      await tester.tap(find.text('Ta bort'));
      await tester.pumpAndSettle();

      expect(stored(), [_kids]);
      expect(find.text('Barnvänligt'), findsOneWidget);
      expect(find.text('Önskemålet togs bort'), findsNothing);
      expect(find.text('Önskemålet kunde inte sparas'), findsOneWidget);
    });

    testWidgets('a refused rename keeps the dialog open and says why', (
      tester,
    ) async {
      h.wishProfile.seed(wishes: const [_kids]);
      h.wishProfile.failWrites = true;
      await open(tester);
      await openSheet(tester);
      await tester.tap(find.text('Döp om'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey('menu-wish-name')),
        'Lätt',
      );
      await tester.pump();
      await tester.tap(find.text('Spara'));
      await tester.pumpAndSettle();

      expect(stored().single.name, 'Barnvänligt');
      expect(find.byKey(const ValueKey('menu-wish-name')), findsOneWidget);
      expect(find.text('Önskemålet kunde inte sparas'), findsOneWidget);
    });
  });

  group('after a generation', () {
    testWidgets('typed text is remembered and offered for saving; Spara '
        'stores it', (tester) async {
      await open(tester);
      await h.generate(tester, '3 middagar med kyckling');
      await tester.pumpAndSettle();

      expect(h.wishProfile.lastWrites.single.text, '3 middagar med kyckling');
      expect(h.wishProfile.lastWrites.single.pantryFocus, isFalse);
      expect(find.text(savePrompt), findsOneWidget);
      expect(stored(), isEmpty);

      await tester.tap(find.text('Spara'));
      await tester.pumpAndSettle();

      expect(stored().single.text, '3 middagar med kyckling');
      expect(find.text('Önskemålet sparat'), findsOneWidget);
    });

    testWidgets('a refused save shows the model\'s message', (tester) async {
      await open(tester);
      await h.generate(tester, '3 middagar med kyckling');
      await tester.pumpAndSettle();
      h.wishProfile.failWrites = true;

      await tester.tap(find.text('Spara'));
      await tester.pumpAndSettle();

      expect(stored(), isEmpty);
      expect(find.text('Önskemålet kunde inte sparas'), findsOneWidget);
    });

    testWidgets('an unedited built-in is neither remembered nor offered', (
      tester,
    ) async {
      await open(tester);
      await tester.tap(find.text('Snabb vecka'));
      await tester.pumpAndSettle();
      await tapGenerate(tester);

      expect(h.menu.generations, 1);
      expect(h.wishProfile.lastWrites, isEmpty);
      expect(find.text(savePrompt), findsNothing);
    });

    testWidgets('an unedited pantry fill is neither remembered nor offered', (
      tester,
    ) async {
      await open(tester);
      await tester.tap(find.text('Använd det jag har hemma'));
      await tester.pumpAndSettle();
      await tapGenerate(tester);

      expect(h.wishProfile.lastWrites, isEmpty);
      expect(find.text(savePrompt), findsNothing);
    });

    testWidgets('an edited built-in is remembered and offered', (tester) async {
      await open(tester);
      await tester.tap(find.text('Snabb vecka'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, '7 middagar snabbt');
      await tester.pump();
      await tapGenerate(tester);

      expect(h.wishProfile.lastWrites.single.text, '7 middagar snabbt');
      expect(find.text(savePrompt), findsOneWidget);
    });

    testWidgets('a saved wish generated unedited is remembered, not offered', (
      tester,
    ) async {
      h.wishProfile.seed(wishes: const [_kids]);
      await open(tester);
      await tester.tap(find.text('Barnvänligt'));
      await tester.pumpAndSettle();
      await tapGenerate(tester);

      expect(h.wishProfile.lastWrites.single.text, '5 barnvänliga');
      expect(find.text(savePrompt), findsNothing);
    });

    testWidgets('the same wish as last time is not written again', (
      tester,
    ) async {
      h.wishProfile.seed(
        lastWish: const LastMenuWish(text: '3 middagar med kyckling'),
      );
      await open(tester);
      await h.generate(tester, '3 middagar med kyckling');
      await tester.pumpAndSettle();

      expect(h.wishProfile.lastWrites, isEmpty);
    });

    testWidgets('a full list is not offered more', (tester) async {
      h.wishProfile.seed(
        wishes: [
          for (var i = 0; i < MenuWishes.maxWishes; i++)
            MenuWish(id: 'w$i', name: 'Önskemål $i', text: 'text $i'),
        ],
      );
      await open(tester);
      await h.generate(tester, '3 middagar med kyckling');
      await tester.pumpAndSettle();

      expect(h.wishProfile.lastWrites, hasLength(1));
      expect(find.text(savePrompt), findsNothing);
    });

    testWidgets('a generation that matched nothing remembers and offers '
        'nothing', (tester) async {
      h.menu.next = const {};
      await open(tester);
      await h.generate(tester, '3 middagar med kyckling');
      await tester.pumpAndSettle();

      expect(h.menu.generations, 1);
      expect(menuVm(tester).hasMenu, isFalse);
      expect(h.wishProfile.lastWrites, isEmpty);
      expect(find.text(savePrompt), findsNothing);
    });
  });
}
