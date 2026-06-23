/// Widget tests for UnifiedBadge + BadgeRow + AllergenBadge + TagBadge +
/// CategoryBadge.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/theme/butlery_colors_extension.dart';
import 'package:butlery/widgets/common/badges/unified_badge.dart';

Widget _wrap(Widget child) => MaterialApp(
  theme: AppTheme.lightTheme,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  locale: const Locale('sv'),
  home: Scaffold(body: child),
);

BoxDecoration _decoOf(WidgetTester tester, Type ancestor) {
  final container = tester.widget<Container>(
    find.descendant(
      of: find.byType(ancestor),
      matching: find.byType(Container),
    ),
  );
  return container.decoration! as BoxDecoration;
}

void main() {
  group('UnifiedBadge — rendering', () {
    testWidgets('renders the label text', (tester) async {
      await tester.pumpWidget(_wrap(const UnifiedBadge(label: 'Vegetariskt')));
      expect(find.text('Vegetariskt'), findsOneWidget);
    });

    testWidgets('no icon row when icon is null', (tester) async {
      await tester.pumpWidget(_wrap(const UnifiedBadge(label: 'Plain')));
      expect(find.byType(Icon), findsNothing);
    });

    testWidgets('renders icon before label when icon is set', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const UnifiedBadge(label: 'Tagged', icon: Icons.star),
        ),
      );
      expect(find.byIcon(Icons.star), findsOneWidget);
    });

    testWidgets('no remove button when onRemove is null', (tester) async {
      await tester.pumpWidget(_wrap(const UnifiedBadge(label: 'No-remove')));
      expect(find.byIcon(Icons.close), findsNothing);
    });

    testWidgets('renders X icon when onRemove is supplied', (tester) async {
      await tester.pumpWidget(
        _wrap(
          UnifiedBadge(label: 'Closable', onRemove: () {}),
        ),
      );
      expect(find.byIcon(Icons.close), findsOneWidget);
    });

    testWidgets('square corners (BorderRadius.zero) per design system', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(const UnifiedBadge(label: 'x')));
      expect(_decoOf(tester, UnifiedBadge).borderRadius, BorderRadius.zero);
    });
  });

  group('UnifiedBadge — variant + selection', () {
    testWidgets('filled variant: solid base color, no border', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const UnifiedBadge(
            label: 'F',
            type: BadgeType.tag,
            variant: BadgeVariant.filled,
          ),
        ),
      );
      final deco = _decoOf(tester, UnifiedBadge);
      expect(deco.color, isNotNull);
      expect(deco.color!.a, greaterThan(0.5));
      expect(deco.border, isNull);
    });

    testWidgets('outlined variant: transparent bg + border in base color', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const UnifiedBadge(
            label: 'O',
            variant: BadgeVariant.outlined,
            color: Colors.purple,
          ),
        ),
      );
      final deco = _decoOf(tester, UnifiedBadge);
      expect(deco.color, Colors.transparent);
      expect(deco.border, isA<Border>());
      expect((deco.border! as Border).top.color, Colors.purple);
    });

    testWidgets('subtle variant: bg is 10% alpha of base color', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const UnifiedBadge(
            label: 'S',
            variant: BadgeVariant.subtle,
            color: Colors.red,
          ),
        ),
      );
      final deco = _decoOf(tester, UnifiedBadge);
      expect(deco.color!.a, closeTo(0.1, 0.001));
      expect(deco.border, isNull);
    });

    testWidgets('isSelected overrides variant → filled-style result', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const UnifiedBadge(
            label: 'sel',
            variant: BadgeVariant.outlined,
            color: Colors.green,
            isSelected: true,
          ),
        ),
      );
      final deco = _decoOf(tester, UnifiedBadge);
      // Selected uses base color, opaque (not transparent like outlined would)
      expect(deco.color, Colors.green);
      expect(deco.border, isNull);
    });
  });

  group('UnifiedBadge — explicit color override', () {
    testWidgets('color override wins over type default', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const UnifiedBadge(
            label: 'O',
            type: BadgeType.allergen,
            variant: BadgeVariant.filled,
            color: Colors.cyan,
          ),
        ),
      );
      expect(_decoOf(tester, UnifiedBadge).color, Colors.cyan);
    });
  });

  group('UnifiedBadge — sizes', () {
    Future<EdgeInsetsGeometry> paddingFor(
      WidgetTester tester,
      BadgeSize size,
    ) async {
      await tester.pumpWidget(_wrap(UnifiedBadge(label: 's', size: size)));
      final container = tester.widget<Container>(
        find.descendant(
          of: find.byType(UnifiedBadge),
          matching: find.byType(Container),
        ),
      );
      return container.padding!;
    }

    testWidgets('padding scales monotonically with size', (tester) async {
      final small = (await paddingFor(
        tester,
        BadgeSize.small,
      )).resolve(TextDirection.ltr);
      final medium = (await paddingFor(
        tester,
        BadgeSize.medium,
      )).resolve(TextDirection.ltr);
      final large = (await paddingFor(
        tester,
        BadgeSize.large,
      )).resolve(TextDirection.ltr);
      expect(small.horizontal, lessThan(medium.horizontal));
      expect(medium.horizontal, lessThan(large.horizontal));
      expect(small.vertical, lessThan(medium.vertical));
      expect(medium.vertical, lessThan(large.vertical));
    });

    testWidgets('font size scales monotonically with size', (tester) async {
      double fontFor(WidgetTester t) =>
          t.widget<Text>(find.text('s')).style!.fontSize!;
      await tester.pumpWidget(
        _wrap(const UnifiedBadge(label: 's', size: BadgeSize.small)),
      );
      final smallFont = fontFor(tester);
      await tester.pumpWidget(
        _wrap(const UnifiedBadge(label: 's', size: BadgeSize.medium)),
      );
      final mediumFont = fontFor(tester);
      await tester.pumpWidget(
        _wrap(const UnifiedBadge(label: 's', size: BadgeSize.large)),
      );
      final largeFont = fontFor(tester);
      expect(smallFont, lessThan(mediumFont));
      expect(mediumFont, lessThan(largeFont));
    });
  });

  group('UnifiedBadge — interaction', () {
    testWidgets('onTap fires when badge is tapped', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        _wrap(
          UnifiedBadge(
            label: 'tap-me',
            onTap: () => taps++,
          ),
        ),
      );
      await tester.tap(find.text('tap-me'));
      expect(taps, 1);
    });

    testWidgets('onRemove fires when X is tapped (and NOT onTap)', (
      tester,
    ) async {
      var taps = 0;
      var removes = 0;
      await tester.pumpWidget(
        _wrap(
          UnifiedBadge(
            label: 'tap-me',
            onTap: () => taps++,
            onRemove: () => removes++,
          ),
        ),
      );
      await tester.tap(find.byIcon(Icons.close));
      expect(removes, 1);
      expect(taps, 0);
    });

    testWidgets('no GestureDetector when onTap is null and onRemove is null', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(const UnifiedBadge(label: 'static')));
      expect(find.byType(GestureDetector), findsNothing);
    });
  });

  group('BadgeRow', () {
    testWidgets('wraps children in a Wrap', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const BadgeRow(
            badges: [
              UnifiedBadge(label: 'a'),
              UnifiedBadge(label: 'b'),
            ],
          ),
        ),
      );
      expect(find.byType(Wrap), findsOneWidget);
      expect(find.byType(UnifiedBadge), findsNWidgets(2));
    });

    testWidgets('forwards spacing, runSpacing, alignment to Wrap', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const BadgeRow(
            badges: [UnifiedBadge(label: 'a')],
            spacing: 17,
            runSpacing: 9,
            alignment: WrapAlignment.center,
          ),
        ),
      );
      final wrap = tester.widget<Wrap>(find.byType(Wrap));
      expect(wrap.spacing, 17);
      expect(wrap.runSpacing, 9);
      expect(wrap.alignment, WrapAlignment.center);
    });
  });

  group('AllergenBadge', () {
    testWidgets('renders allergen text with warning icon', (tester) async {
      await tester.pumpWidget(_wrap(const AllergenBadge(allergen: 'Gluten')));
      expect(find.text('Gluten'), findsOneWidget);
      expect(find.byIcon(Icons.warning_amber_outlined), findsOneWidget);
    });

    testWidgets('uses warning color from theme extension', (tester) async {
      late ButleryColors bc;
      await tester.pumpWidget(
        _wrap(
          Builder(
            builder: (ctx) {
              bc = ctx.butleryColors;
              return const AllergenBadge(allergen: 'Mjölk');
            },
          ),
        ),
      );
      final deco = _decoOf(tester, AllergenBadge);
      // Subtle variant → 10% alpha of base. Compare RGB only.
      final base = bc.warning;
      expect(deco.color!.r, closeTo(base.r, 0.01));
      expect(deco.color!.g, closeTo(base.g, 0.01));
      expect(deco.color!.b, closeTo(base.b, 0.01));
      expect(deco.color!.a, closeTo(0.1, 0.001));
    });

    testWidgets('onTap fires through the AllergenBadge', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        _wrap(
          AllergenBadge(allergen: 'Nötter', onTap: () => taps++),
        ),
      );
      await tester.tap(find.text('Nötter'));
      expect(taps, 1);
    });
  });

  group('TagBadge', () {
    testWidgets('selected → filled variant; unselected → subtle', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const TagBadge(
            tag: 'Snabb',
            color: Colors.deepPurple,
            isSelected: true,
          ),
        ),
      );
      // Selected uses base color opaquely.
      expect(_decoOf(tester, TagBadge).color, Colors.deepPurple);

      await tester.pumpWidget(
        _wrap(
          const TagBadge(
            tag: 'Snabb',
            color: Colors.deepPurple,
          ),
        ),
      );
      final unselected = _decoOf(tester, TagBadge).color!;
      // Subtle: same RGB, ~10% alpha.
      expect(unselected.r, closeTo(Colors.deepPurple.r, 0.01));
      expect(unselected.a, closeTo(0.1, 0.001));
    });

    testWidgets('onRemove wired through to underlying close button', (
      tester,
    ) async {
      var removes = 0;
      await tester.pumpWidget(
        _wrap(
          TagBadge(
            tag: 'X',
            onRemove: () => removes++,
          ),
        ),
      );
      await tester.tap(find.byIcon(Icons.close));
      expect(removes, 1);
    });
  });

  group('CategoryBadge', () {
    testWidgets(
      'Swedish category prefixes resolve to category palette colors',
      (tester) async {
        late ButleryColors bc;
        await tester.pumpWidget(
          _wrap(
            Builder(
              builder: (ctx) {
                bc = ctx.butleryColors;
                return const CategoryBadge(category: 'Kött och fisk');
              },
            ),
          ),
        );
        expect(_decoOf(tester, CategoryBadge).color, bc.categoryMeatFish);

        await tester.pumpWidget(
          _wrap(
            const CategoryBadge(category: 'Mejeri och ägg'),
          ),
        );
        expect(_decoOf(tester, CategoryBadge).color, bc.categoryDairy);

        await tester.pumpWidget(
          _wrap(
            const CategoryBadge(category: 'Grönsaker'),
          ),
        );
        expect(_decoOf(tester, CategoryBadge).color, bc.categoryVegetables);

        await tester.pumpWidget(
          _wrap(
            const CategoryBadge(category: 'Frukt'),
          ),
        );
        expect(_decoOf(tester, CategoryBadge).color, bc.categoryFruit);

        await tester.pumpWidget(
          _wrap(
            const CategoryBadge(category: 'Bröd'),
          ),
        );
        expect(_decoOf(tester, CategoryBadge).color, bc.categoryBreadGrains);

        await tester.pumpWidget(
          _wrap(
            const CategoryBadge(category: 'Frysvaror'),
          ),
        );
        expect(_decoOf(tester, CategoryBadge).color, bc.categoryFrozen);

        await tester.pumpWidget(
          _wrap(
            const CategoryBadge(category: 'Torrvaror'),
          ),
        );
        expect(_decoOf(tester, CategoryBadge).color, bc.categoryDryGoods);
      },
    );

    testWidgets('explicit color override wins over category-prefix mapping', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const CategoryBadge(
            category: 'Kött och fisk',
            color: Colors.indigo,
          ),
        ),
      );
      expect(_decoOf(tester, CategoryBadge).color, Colors.indigo);
    });

    testWidgets(
      'unknown category resolves to *some* palette color (no crash)',
      (tester) async {
        await tester.pumpWidget(
          _wrap(
            const CategoryBadge(category: 'Helt påhittat'),
          ),
        );
        // Just assert it built without throwing and has a non-null color.
        expect(_decoOf(tester, CategoryBadge).color, isNotNull);
        expect(tester.takeException(), isNull);
      },
    );
  });
}
