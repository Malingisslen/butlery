// The one card (BUT-2370): surface, edge, radius and the lack of a shadow
// come from the app theme's cardTheme, and StyledCard adds only padding,
// margin, tap and the chosen state.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_mode_colors.dart';
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/widgets/styled/styled_card.dart';

Widget _app(Widget child, {ThemeData? theme}) => MaterialApp(
  theme: theme ?? AppTheme.lightTheme,
  home: Scaffold(body: Center(child: child)),
);

void main() {
  final cs = AppTheme.lightTheme.colorScheme;

  group('StyledCard', () {
    testWidgets('renders its child', (tester) async {
      await tester.pumpWidget(
        _app(const StyledCard(child: Text('Innehåll'))),
      );
      expect(find.text('Innehåll'), findsOneWidget);
    });

    testWidgets('takes elevation, shape and fill from the theme', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(const StyledCard(child: Text('Innehåll'))),
      );
      final card = tester.widget<Card>(find.byType(Card));
      final themed = AppTheme.lightTheme.cardTheme;
      expect(card.elevation, isNull);
      expect(themed.elevation, 0);
      expect(card.shape, isNull);
      expect(card.color, isNull);
      final material = tester.widget<Material>(
        find.descendant(of: find.byType(Card), matching: find.byType(Material)),
      );
      expect(material.elevation, 0);
      expect(material.color, cs.surface);
      final shape = material.shape! as RoundedRectangleBorder;
      expect(
        shape.borderRadius,
        BorderRadius.circular(AppDimensions.radiusCard),
      );
      expect(shape.side.color, cs.outlineVariant);
    });

    testWidgets('applies padding around the child', (tester) async {
      await tester.pumpWidget(
        _app(
          const StyledCard(
            padding: EdgeInsets.all(20),
            child: SizedBox(key: Key('inner'), width: 50, height: 30),
          ),
        ),
      );
      final size = tester.getSize(find.byType(Card));
      expect(size.width, 90);
      expect(size.height, 70);
    });

    testWidgets('has no margin unless asked', (tester) async {
      await tester.pumpWidget(
        _app(const StyledCard(child: Text('Innehåll'))),
      );
      expect(tester.widget<Card>(find.byType(Card)).margin, EdgeInsets.zero);

      await tester.pumpWidget(
        _app(
          const StyledCard(margin: EdgeInsets.all(8), child: Text('Innehåll')),
        ),
      );
      expect(
        tester.widget<Card>(find.byType(Card)).margin,
        const EdgeInsets.all(8),
      );
    });

    testWidgets('without onTap it is not a button', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _app(const StyledCard(child: Text('Innehåll'))),
      );
      expect(find.byType(InkWell), findsNothing);
      expect(
        tester.getSemantics(find.text('Innehåll')),
        isNot(matchesSemantics(isButton: true)),
      );
      handle.dispose();
    });

    testWidgets('onTap makes a labelled button and fires on tap', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      var taps = 0;
      await tester.pumpWidget(
        _app(
          StyledCard(
            onTap: () => taps++,
            semanticLabel: 'Öppna kortet',
            child: const Text('Innehåll'),
          ),
        ),
      );
      expect(
        find.bySemanticsLabel(RegExp('Öppna kortet')),
        findsOneWidget,
      );
      expect(
        tester.getSemantics(find.bySemanticsLabel(RegExp('Öppna kortet'))),
        containsSemantics(
          label: 'Öppna kortet',
          isButton: true,
        ),
      );
      await tester.tap(find.text('Innehåll'));
      expect(taps, 1);
      handle.dispose();
    });

    testWidgets('selected draws an onSurface border and says so', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _app(
          StyledCard(
            selected: true,
            onTap: () {},
            semanticLabel: 'Kort',
            child: const Text('Innehåll'),
          ),
        ),
      );
      final material = tester.widget<Material>(
        find.descendant(of: find.byType(Card), matching: find.byType(Material)),
      );
      final shape = material.shape! as RoundedRectangleBorder;
      expect(shape.side.color, cs.onSurface);
      expect(shape.side.width, AppDimensions.borderWidthStandard);
      expect(material.color, cs.surfaceContainerHighest);
      expect(
        tester.getSemantics(find.bySemanticsLabel(RegExp('Kort'))),
        containsSemantics(
          label: 'Kort',
          isButton: true,
          isSelected: true,
          hasSelectedState: true,
        ),
      );
      handle.dispose();
    });
  });

  group('StyledCard decorations', () {
    Future<BuildContext> pumpContext(
      WidgetTester tester, {
      ThemeData? theme,
    }) async {
      late BuildContext captured;
      await tester.pumpWidget(
        _app(
          Builder(
            builder: (context) {
              captured = context;
              return const SizedBox();
            },
          ),
          theme: theme,
        ),
      );
      return captured;
    }

    testWidgets('decorationOf is the card theme at rest', (tester) async {
      final context = await pumpContext(tester);
      final deco = StyledCard.decorationOf(context);
      expect(deco.color, AppTheme.lightTheme.cardTheme.color);
      expect(deco.borderRadius, BorderRadius.circular(12));
      expect(deco.border, Border.all(color: cs.outlineVariant));
      expect(deco.boxShadow, isNull);
    });

    testWidgets('hoverDecorationOf fills to surface.raised, no shadow', (
      tester,
    ) async {
      final context = await pumpContext(tester);
      final deco = StyledCard.hoverDecorationOf(context);
      expect(deco.color, cs.surfaceContainerHighest);
      expect(deco.boxShadow, isNull);
      expect(deco.border, StyledCard.decorationOf(context).border);
    });

    testWidgets('the card theme clips, so a row fills to the rounded edge', (
      tester,
    ) async {
      expect(AppTheme.lightTheme.cardTheme.clipBehavior, Clip.antiAlias);
      expect(AppTheme.darkTheme.cardTheme.clipBehavior, Clip.antiAlias);
    });

    testWidgets('a press on a raised card theme fills to pressed.onRaised', (
      tester,
    ) async {
      final raised = AppTheme.lightTheme.copyWith(
        cardTheme: AppTheme.lightTheme.cardTheme.copyWith(
          color: cs.surfaceContainerHighest,
        ),
      );
      final context = await pumpContext(tester, theme: raised);
      expect(
        StyledCard.pressFillOf(context),
        context.modeColors.pressedOnRaised,
      );
      expect(
        StyledCard.pressFillOf(context),
        isNot(cs.surfaceContainerHighest),
      );
    });
  });

  group('StyledCard press overlay', () {
    Color? overlay(WidgetTester tester, Set<WidgetState> states) => tester
        .widget<InkWell>(find.byType(InkWell))
        .overlayColor!
        .resolve(states);

    testWidgets('a press on paper fills to surface.raised, a hover adds none', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(StyledCard(onTap: () {}, child: const Text('Kort'))),
      );
      expect(
        overlay(tester, {WidgetState.pressed}),
        cs.surfaceContainerHighest,
      );
      expect(overlay(tester, {WidgetState.hovered}), Colors.transparent);
      expect(overlay(tester, {}), isNull);
    });

    testWidgets('a press on a chosen card fills to pressed.onRaised', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          StyledCard(onTap: () {}, selected: true, child: const Text('Kort')),
        ),
      );
      final context = tester.element(find.text('Kort'));
      final onRaised = context.modeColors.pressedOnRaised;
      expect(onRaised, isNot(cs.surfaceContainerHighest));
      expect(overlay(tester, {WidgetState.pressed}), onRaised);
      expect(overlay(tester, {WidgetState.hovered}), Colors.transparent);
    });
  });
}
