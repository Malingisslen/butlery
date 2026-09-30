/// BUT-1308 (BUT-710 follow-up): pin that MenuCard mounts a HoverableCard
/// ancestor whose rest decoration uses design-system tokens (surface fill +
/// outline border) and whose hover variant deepens the shadow.
///
/// Intent: BUT-710 wrapped the custom cards in HoverableCard for a web/desktop
/// hover affordance. This render test guards against a refactor dropping the
/// wrapper or swapping the tokenised border/colour for ad-hoc values.
library;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/widgets/common/content_cards/menu_card.dart';
import 'package:butlery/widgets/common/hoverable_card.dart';

import '../../../infrastructure/factories/recipe_factory.dart';

Widget _wrap(Widget child) => MaterialApp(
  locale: const Locale('sv'),
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: const [
    AppLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  theme: AppTheme.lightTheme,
  home: Scaffold(body: child),
);

Map<String, List<Recipe>> _menu() => {
  'Middag': [
    RecipeFactory.build(
      id: 'm1',
      title: 'Köttbullar',
      imageUrls: const [],
      personalTagIds: const [],
    ),
  ],
};

/// Paints an ink highlight in [color]: any drawRRect whose paint is exactly
/// it. `paints..rrect` would stop at the first, transparent, rrect the
/// enclosing Material draws.
PaintPattern paintsRaisedHighlight(Color color) => paints
  ..something(
    (Symbol method, List<dynamic> arguments) =>
        method == #drawRRect &&
        (arguments[1] as Paint).color.toARGB32() == color.toARGB32(),
  );

void main() {
  group('MenuCard mounts HoverableCard (BUT-1308)', () {
    testWidgets('renders a HoverableCard ancestor', (tester) async {
      await tester.pumpWidget(
        _wrap(
          MenuCard(menu: _menu(), onTap: () {}),
        ),
      );

      expect(
        find.descendant(
          of: find.byType(MenuCard),
          matching: find.byType(HoverableCard),
        ),
        findsOneWidget,
      );
    });

    testWidgets('rest decoration uses surface fill + outline design tokens', (
      tester,
    ) async {
      late ColorScheme cs;
      await tester.pumpWidget(
        _wrap(
          Builder(
            builder: (context) {
              cs = Theme.of(context).colorScheme;
              return MenuCard(menu: _menu(), onTap: () {});
            },
          ),
        ),
      );

      final hoverable = tester.widget<HoverableCard>(
        find.descendant(
          of: find.byType(MenuCard),
          matching: find.byType(HoverableCard),
        ),
      );

      final rest = hoverable.restDecoration as BoxDecoration;
      expect(
        rest.color,
        cs.surface,
        reason: 'Menu card fill must use the surface token.',
      );
      final border = rest.border as Border;
      expect(
        border.top.color,
        cs.outline,
        reason: 'Menu card border must use the outline token.',
      );
      expect(border.top.width, AppDimensions.borderWidthThin);
      expect(
        rest.borderRadius,
        BorderRadius.circular(AppDimensions.radiusCard),
      );
    });

    testWidgets(
      'hover variant fills to surface.raised, keeps border + corners, '
      'deepens shadow (B83-1 = A, BUT-2183)',
      (tester) async {
        late ColorScheme cs;
        await tester.pumpWidget(
          _wrap(
            Builder(
              builder: (context) {
                cs = Theme.of(context).colorScheme;
                return MenuCard(menu: _menu(), onTap: () {});
              },
            ),
          ),
        );

        final hoverable = tester.widget<HoverableCard>(
          find.descendant(
            of: find.byType(MenuCard),
            matching: find.byType(HoverableCard),
          ),
        );

        final rest = hoverable.restDecoration as BoxDecoration;
        final hover = hoverable.hoverDecoration as BoxDecoration;

        expect(hover.border, equals(rest.border));
        expect(hover.borderRadius, equals(rest.borderRadius));
        expect(
          hover.color,
          cs.surfaceContainerHighest,
          reason:
              'Pressed/hover on rows, cards and icon buttons fills to '
              'surface.raised.',
        );
        expect(
          rest.color,
          cs.surface,
          reason: 'Rest keeps the plain surface fill.',
        );
        expect(
          hover.boxShadow,
          isNotNull,
          reason: 'Hover should add the reserved elevation shadow.',
        );
      },
    );

    // BUT-1308: drive a real mouse pointer over the card and assert the
    // RENDERED decoration lifts to the hover variant, then reverts on exit.
    // Exercises _HoverableCardState's onEnter/onExit wiring directly.
    testWidgets(
      'pointer enter lifts rendered decoration to hover variant (surface.raised), exit reverts',
      (tester) async {
        late ColorScheme cs;
        await tester.pumpWidget(
          _wrap(
            Builder(
              builder: (context) {
                cs = Theme.of(context).colorScheme;
                return MenuCard(menu: _menu(), onTap: () {});
              },
            ),
          ),
        );

        final hoverable = tester.widget<HoverableCard>(
          find.descendant(
            of: find.byType(MenuCard),
            matching: find.byType(HoverableCard),
          ),
        );
        final restDecoration = hoverable.restDecoration;
        final hoverDecoration = hoverable.hoverDecoration;

        Decoration? renderedDecoration() {
          final container = tester.widget<AnimatedContainer>(
            find.descendant(
              of: find.byType(HoverableCard),
              matching: find.byType(AnimatedContainer),
            ),
          );
          return container.decoration;
        }

        expect(renderedDecoration(), equals(restDecoration));

        final gesture = await tester.createGesture(
          kind: PointerDeviceKind.mouse,
        );
        await gesture.addPointer(location: Offset.zero);
        addTearDown(gesture.removePointer);

        await gesture.moveTo(tester.getCenter(find.byType(HoverableCard)));
        await tester.pumpAndSettle();
        expect(
          renderedDecoration(),
          equals(hoverDecoration),
          reason:
              'Pointer entering the card must lift the rendered decoration '
              'to the hover variant (BUT-710 hover feature).',
        );
        expect(
          (renderedDecoration() as BoxDecoration).color,
          cs.surfaceContainerHighest,
          reason:
              'A real mouse hover must paint surface.raised (B83-1 = A, BUT-2183).',
        );

        // Move to a point guaranteed outside the card's hit area (its MouseRegion
        // covers the margin, so Offset.zero is not reliably outside).
        final cardRect = tester.getRect(find.byType(HoverableCard));
        await gesture.moveTo(cardRect.bottomRight + const Offset(50, 50));
        await tester.pumpAndSettle();
        expect(
          renderedDecoration(),
          equals(restDecoration),
          reason:
              'Pointer leaving the card must revert to the rest '
              'decoration.',
        );
      },
    );

    testWidgets(
      'tappable card renders a click cursor; non-tappable defers the cursor',
      (tester) async {
        // Assert the RENDERED MouseRegion.cursor — the observable affordance —
        // rather than reading the enabled bool off the constructor.
        MouseCursor cursorOf() {
          final mouseRegion = tester.widget<MouseRegion>(
            find
                .descendant(
                  of: find.byType(HoverableCard),
                  matching: find.byType(MouseRegion),
                )
                .first,
          );
          return mouseRegion.cursor;
        }

        await tester.pumpWidget(
          _wrap(
            MenuCard(menu: _menu(), onTap: () {}),
          ),
        );
        expect(
          cursorOf(),
          SystemMouseCursors.click,
          reason: 'A card with an onTap must show the click cursor.',
        );

        await tester.pumpWidget(
          _wrap(
            MenuCard(menu: _menu()),
          ),
        );
        expect(
          cursorOf(),
          MouseCursor.defer,
          reason: 'A card with no onTap should not imply clickability.',
        );
      },
    );

    testWidgets(
      'pressing the card paints surface.raised as the ink highlight, '
      'not the default rust/grey tint (B83-1 = A, BUT-2183)',
      (tester) async {
        late ColorScheme cs;
        await tester.pumpWidget(
          _wrap(
            Builder(
              builder: (context) {
                cs = Theme.of(context).colorScheme;
                return MenuCard(menu: _menu(), onTap: () {});
              },
            ),
          ),
        );

        final ink = tester.renderObject(
          find
              .ancestor(
                of: find.descendant(
                  of: find.byType(MenuCard),
                  matching: find.byType(InkWell),
                ),
                matching: find.byType(Material),
              )
              .first,
        );
        expect(ink, isNot(paintsRaisedHighlight(cs.surfaceContainerHighest)));

        final gesture = await tester.startGesture(
          tester.getCenter(find.byType(InkWell).first),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(
          ink,
          paintsRaisedHighlight(cs.surfaceContainerHighest),
          reason: 'Pressed on a card fills to surface.raised.',
        );

        await gesture.up();
        await tester.pumpAndSettle();
      },
    );
  });
}
