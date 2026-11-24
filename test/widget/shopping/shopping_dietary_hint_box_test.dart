// The allergy reminder under a shopping row (BUT-2494): what it says, that it
// can be dismissed and undone, and that tapping it never ticks the row.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/models/unified/unified_shopping_item.dart';
import 'package:butlery/services/shopping/shopping_dietary_hints.dart';
import 'package:butlery/services/tagging/config/allergen_config.dart';
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/viewmodels/shopping/shopping_dietary_hints_controller.dart';
import 'package:butlery/widgets/shopping/shopping_dietary_hint_box.dart';
import 'package:butlery/widgets/shopping/shopping_dietary_hints_scope.dart';
import 'package:butlery/widgets/shopping/shopping_row.dart';

import '../../infrastructure/helpers/widget_test_app.dart';

const _lactose = ShoppingDietaryHint(
  choiceKey: 'laktos',
  kind: ShoppingDietaryHintKind.chooseFreeVariant,
);
const _nuts = ShoppingDietaryHint(
  choiceKey: 'nötter',
  kind: ShoppingDietaryHintKind.checkContents,
);

const _disclaimer = 'Påminnelser kan saknas. Läs alltid innehållet.';

Widget _box(
  ShoppingDietaryHint hint, {
  VoidCallback? onDismiss,
  bool dark = false,
}) {
  final box = ShoppingDietaryHintBox(hint: hint, onDismiss: onDismiss ?? () {});
  return createLocalizedTestApp(
    child: dark ? Theme(data: AppTheme.darkTheme, child: box) : box,
  );
}

void main() {
  group('the box', () {
    testWidgets('a free-variant reminder reads as the lactose sentence', (
      tester,
    ) async {
      await tester.pumpWidget(_box(_lactose));

      expect(find.text('Laktos i hushållet, välj laktosfri'), findsOneWidget);
    });

    testWidgets(
      'a free-variant reminder for gluten names gluten, not lactose',
      (
        tester,
      ) async {
        await tester.pumpWidget(
          _box(
            const ShoppingDietaryHint(
              choiceKey: 'gluten',
              kind: ShoppingDietaryHintKind.chooseFreeVariant,
            ),
          ),
        );

        expect(find.text('Gluten i hushållet, välj glutenfri'), findsOneWidget);
        expect(find.text('Laktos i hushållet, välj laktosfri'), findsNothing);
      },
    );

    testWidgets('a check-contents reminder names the choice in lower case', (
      tester,
    ) async {
      await tester.pumpWidget(_box(_nuts));

      expect(
        find.text('Innehåller ofta nötter, kolla innehållet'),
        findsOneWidget,
      );
    });

    testWidgets(
      'the dismiss tick is named "Inte aktuellt", reachable and >= 48 dp',
      (tester) async {
        var dismissed = 0;
        await tester.pumpWidget(_box(_lactose, onDismiss: () => dismissed++));

        final tick = find.byTooltip('Inte aktuellt');
        expect(tick, findsOneWidget);
        final size = tester.getSize(
          find.descendant(of: tick, matching: find.byType(IconButton)).first,
        );
        expect(size.width, greaterThanOrEqualTo(48));
        expect(size.height, greaterThanOrEqualTo(48));

        await tester.tap(tick);
        expect(dismissed, 1);
      },
    );

    testWidgets('renders in the dark theme with its text and tick', (
      tester,
    ) async {
      await tester.pumpWidget(_box(_lactose, dark: true));

      expect(find.text('Laktos i hushållet, välj laktosfri'), findsOneWidget);
      expect(find.byTooltip('Inte aktuellt'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('no wording for any choice claims safety', (tester) async {
      late AppLocalizations l10n;
      await tester.pumpWidget(
        createLocalizedTestApp(
          child: Builder(
            builder: (context) {
              l10n = AppLocalizations.of(context);
              return const SizedBox();
            },
          ),
        ),
      );

      final texts = [
        for (final entry in AllergenConfig.all)
          for (final kind in ShoppingDietaryHintKind.values)
            ShoppingDietaryHintBox.textFor(
              l10n,
              ShoppingDietaryHint(choiceKey: entry.key, kind: kind),
            ),
        l10n.shoppingHintsDisclaimer,
      ];

      expect(texts, isNotEmpty);
      for (final text in texts) {
        expect(text.toLowerCase(), isNot(contains('säker')), reason: text);
      }
    });
  });

  group('on a shopping row', () {
    final butter = UnifiedShoppingItem(
      id: 'row-butter',
      name: 'Smör',
      amount: 1,
      unit: 'st',
      category: 'Mejeri',
      bought: false,
    );
    late ChangeNotifier source;
    late ShoppingDietaryHintsController controller;
    late int rowTaps;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      source = ChangeNotifier();
      rowTaps = 0;
      controller = ShoppingDietaryHintsController(
        loadChoices: () async => {'laktos'},
        lookup: (names) async => [
          for (final _ in names) {'contains-lactose', 'dairy'},
        ],
        currentUserId: () => 'alice',
      );
    });

    tearDown(() {
      controller.dispose();
      source.dispose();
    });

    Future<void> pumpList(WidgetTester tester) async {
      await tester.pumpWidget(
        createLocalizedTestApp(
          child: ShoppingDietaryHintsScope(
            source: source,
            rows: () => [butter],
            controller: controller,
            child: Column(
              children: [
                const ShoppingDietaryHintsNotice(),
                Builder(
                  builder: (context) => ShoppingRow(
                    name: butter.name,
                    checked: false,
                    onTap: () => rowTaps++,
                    below: shoppingDietaryHintsBelow(
                      context,
                      butter,
                      completed: false,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      // The scope feeds the controller after the first frame.
      await tester.pumpAndSettle();
    }

    testWidgets('the row shows the box and the list shows the notice', (
      tester,
    ) async {
      await pumpList(tester);

      expect(find.text('Laktos i hushållet, välj laktosfri'), findsOneWidget);
      expect(find.text(_disclaimer), findsOneWidget);
    });

    testWidgets('a row with no reminder gets neither box nor notice', (
      tester,
    ) async {
      controller.dispose();
      controller = ShoppingDietaryHintsController(
        loadChoices: () async => {},
        lookup: (names) async => [for (final _ in names) null],
        currentUserId: () => 'alice',
      );

      await pumpList(tester);

      expect(find.byType(ShoppingDietaryHintBox), findsNothing);
      expect(find.text(_disclaimer), findsNothing);
    });

    testWidgets('tapping the box leaves the row unticked', (tester) async {
      await pumpList(tester);

      await tester.tap(find.text('Laktos i hushållet, välj laktosfri'));
      await tester.pumpAndSettle();

      expect(rowTaps, 0);
      expect(find.text('Laktos i hushållet, välj laktosfri'), findsOneWidget);
    });

    testWidgets('the row itself still ticks when tapped', (tester) async {
      await pumpList(tester);

      await tester.tap(find.text('Smör'));

      expect(rowTaps, 1);
    });

    testWidgets('the tick hides box and notice, and "Ångra" brings both back', (
      tester,
    ) async {
      await pumpList(tester);

      await tester.tap(find.byTooltip('Inte aktuellt'));
      await tester.pumpAndSettle();

      expect(find.byType(ShoppingDietaryHintBox), findsNothing);
      expect(find.text(_disclaimer), findsNothing);
      expect(rowTaps, 0);
      expect(find.text('Påminnelsen dold för Smör'), findsOneWidget);

      await tester.tap(find.text('Ångra'));
      await tester.pumpAndSettle();

      expect(find.text('Laktos i hushållet, välj laktosfri'), findsOneWidget);
      expect(find.text(_disclaimer), findsOneWidget);
    });

    testWidgets('a ticked row gets no reminder', (tester) async {
      await tester.pumpWidget(
        createLocalizedTestApp(
          child: ShoppingDietaryHintsScope(
            source: source,
            rows: () => [butter],
            controller: controller,
            child: Builder(
              builder: (context) => ShoppingRow(
                name: butter.name,
                checked: true,
                below: shoppingDietaryHintsBelow(
                  context,
                  butter,
                  completed: true,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(ShoppingDietaryHintBox), findsNothing);
    });
  });
}
