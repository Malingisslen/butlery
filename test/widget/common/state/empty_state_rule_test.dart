/// One rule decides the leading visual of every empty state: the variant's
/// kind. An own collection that is empty draws a vegetable illustration; a
/// search/filter result or small section draws an icon.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/widgets/common/icons/butlery_glyph.dart';
import 'package:butlery/widgets/common/illustrations/vegetable_illustration.dart';
import 'package:butlery/widgets/common/state/empty_states.dart';
import 'package:butlery/widgets/common/state/state_enums.dart';

import '../../../infrastructure/helpers/widget_test_app.dart';

Widget _app(EmptyStateVariant variant) => createLocalizedTestApp(
  wrapInScaffold: true,
  child: Builder(
    builder: (context) =>
        EmptyStates.buildEmptyState(context, variant: variant),
  ),
);

void main() {
  for (final variant in EmptyStateVariant.values) {
    testWidgets('${variant.name} (${variant.kind.name}) follows the rule', (
      tester,
    ) async {
      await tester.pumpWidget(_app(variant));
      await tester.pumpAndSettle();

      switch (variant.kind) {
        case EmptyStateKind.ownCollection:
          expect(find.byType(VegetableIllustration), findsOneWidget);
          expect(find.byType(ButleryIcon), findsNothing);
        case EmptyStateKind.resultOrSection:
          expect(find.byType(ButleryIcon), findsOneWidget);
          expect(find.byType(VegetableIllustration), findsNothing);
      }
    });
  }

  testWidgets('useIllustration: false turns an own collection into an icon', (
    tester,
  ) async {
    await tester.pumpWidget(
      createLocalizedTestApp(
        wrapInScaffold: true,
        child: Builder(
          builder: (context) => EmptyStates.buildEmptyState(
            context,
            variant: EmptyStateVariant.noRecipes,
            useIllustration: false,
          ),
        ),
      ),
    );

    expect(find.byType(VegetableIllustration), findsNothing);
    expect(find.byType(ButleryIcon), findsOneWidget);
  });

  group('secondary action', () {
    Widget app({String? label, VoidCallback? onTap, VoidCallback? onPrimary}) =>
        createLocalizedTestApp(
          wrapInScaffold: true,
          child: Builder(
            builder: (context) => EmptyStates.buildEmptyState(
              context,
              variant: EmptyStateVariant.noFriends,
              actionLabel: 'Primär',
              onAction: onPrimary ?? () {},
              secondaryActionLabel: label,
              onSecondaryAction: onTap,
            ),
          ),
        );

    testWidgets('renders under the primary action and fires', (tester) async {
      var primary = 0;
      var secondary = 0;
      await tester.pumpWidget(
        app(
          label: 'Sekundär',
          onTap: () => secondary++,
          onPrimary: () => primary++,
        ),
      );

      expect(find.widgetWithText(TextButton, 'Sekundär'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('Sekundär')).dy,
        greaterThan(tester.getTopLeft(find.text('Primär')).dy),
      );

      await tester.tap(find.text('Sekundär'));
      expect(secondary, 1);
      expect(primary, 0);
    });

    testWidgets('is absent without a label', (tester) async {
      await tester.pumpWidget(app(onTap: () {}));

      expect(find.byType(TextButton), findsNothing);
    });
  });
}
