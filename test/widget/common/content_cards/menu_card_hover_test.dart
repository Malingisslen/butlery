/// BUT-1308 (BUT-710 follow-up): pin that MenuCard mounts a HoverableCard
/// ancestor whose rest decoration uses design-system tokens (surface fill +
/// outline border) and whose hover variant only deepens the shadow.
///
/// Intent: BUT-710 wrapped the custom cards in HoverableCard for a web/desktop
/// hover affordance. This render test guards against a refactor dropping the
/// wrapper or swapping the tokenised border/colour for ad-hoc values.
library;

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

void main() {
  group('MenuCard mounts HoverableCard (BUT-1308)', () {
    testWidgets('renders a HoverableCard ancestor', (tester) async {
      await tester.pumpWidget(_wrap(
        MenuCard(menu: _menu(), onTap: () {}),
      ));

      expect(
        find.descendant(
          of: find.byType(MenuCard),
          matching: find.byType(HoverableCard),
        ),
        findsOneWidget,
      );
    });

    testWidgets('rest decoration uses surface fill + outline design tokens',
        (tester) async {
      late ColorScheme cs;
      await tester.pumpWidget(_wrap(
        Builder(builder: (context) {
          cs = Theme.of(context).colorScheme;
          return MenuCard(menu: _menu(), onTap: () {});
        }),
      ));

      final hoverable = tester.widget<HoverableCard>(
        find.descendant(
          of: find.byType(MenuCard),
          matching: find.byType(HoverableCard),
        ),
      );

      final rest = hoverable.restDecoration as BoxDecoration;
      expect(rest.color, cs.surface,
          reason: 'Menu card fill must use the surface token.');
      final border = rest.border as Border;
      expect(border.top.color, cs.outline,
          reason: 'Menu card border must use the outline token.');
      expect(border.top.width, AppDimensions.borderWidthThin);
      expect(
        rest.borderRadius,
        BorderRadius.circular(AppDimensions.borderRadiusM),
      );
    });

    testWidgets('hover variant keeps border + corners, only deepens shadow',
        (tester) async {
      await tester.pumpWidget(_wrap(
        MenuCard(menu: _menu(), onTap: () {}),
      ));

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
      expect(hover.color, equals(rest.color));
      expect(hover.boxShadow, isNotNull,
          reason: 'Hover should add the reserved elevation shadow.');
    });

    testWidgets('hover affordance disabled when card is not tappable',
        (tester) async {
      await tester.pumpWidget(_wrap(
        MenuCard(menu: _menu()),
      ));

      final hoverable = tester.widget<HoverableCard>(
        find.descendant(
          of: find.byType(MenuCard),
          matching: find.byType(HoverableCard),
        ),
      );
      expect(hoverable.enabled, isFalse);
    });
  });
}
