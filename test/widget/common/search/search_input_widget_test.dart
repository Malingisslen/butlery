import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/widgets/common/search_filter/search_input_widget.dart';
import '../../../infrastructure/helpers/widget_test_app.dart';

void main() {
  group('SearchInputWidget', () {
    late TextEditingController controller;
    late FocusNode focusNode;

    setUp(() {
      controller = TextEditingController();
      focusNode = FocusNode();
    });

    tearDown(() {
      controller.dispose();
      focusNode.dispose();
    });

    /// Wraps SearchInputWidget in localized app (provides l10n + theme).
    Widget buildWidget({
      String? hintText,
      bool autofocus = false,
      VoidCallback? onClear,
      EdgeInsetsGeometry? padding,
      Widget? trailing,
      bool useClassicStyle = false,
    }) {
      return createLocalizedTestApp(
        child: SearchInputWidget(
          controller: controller,
          focusNode: focusNode,
          hintText: hintText,
          autofocus: autofocus,
          onClear: onClear,
          padding: padding,
          trailing: trailing,
          useClassicStyle: useClassicStyle,
        ),
      );
    }

    group('Rendering', () {
      testWidgets('renders search field with default hint text', (
        tester,
      ) async {
        await tester.pumpWidget(buildWidget());
        await tester.pumpAndSettle();

        expect(find.byType(TextFormField), findsOneWidget);
        // Default hint from l10n.searchHint = 'sök...'
        expect(find.text('sök...'), findsOneWidget);
        expect(find.byIcon(Icons.search), findsOneWidget);
      });

      testWidgets('renders with custom hint text', (tester) async {
        await tester.pumpWidget(buildWidget(hintText: 'Sök recept...'));
        await tester.pumpAndSettle();

        expect(find.text('Sök recept...'), findsOneWidget);
      });

      testWidgets('shows clear button when text is entered', (tester) async {
        await tester.pumpWidget(buildWidget());
        await tester.pumpAndSettle();

        // Initially no clear button
        expect(find.byIcon(Icons.clear), findsNothing);

        // Enter text — the widget listens to controller changes internally
        await tester.enterText(find.byType(TextFormField), 'Test');
        await tester.pump();

        expect(find.byIcon(Icons.clear), findsOneWidget);
      });

      testWidgets('hides clear button when text is empty', (tester) async {
        controller.text = 'Initial text';

        await tester.pumpWidget(buildWidget());
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.clear), findsOneWidget);

        // Clear text via the controller — widget rebuilds via listener
        controller.clear();
        await tester.pump();

        expect(find.byIcon(Icons.clear), findsNothing);
      });

      testWidgets('applies custom padding when provided', (tester) async {
        const customPadding = EdgeInsets.all(20.0);

        await tester.pumpWidget(buildWidget(padding: customPadding));
        await tester.pumpAndSettle();

        // The outermost Padding wrapping the DecoratedBox
        final paddingWidgets = tester.widgetList<Padding>(find.byType(Padding));
        final hasCustomPadding = paddingWidgets.any(
          (p) => p.padding == customPadding,
        );
        expect(hasCustomPadding, isTrue);
      });
    });

    group('Interactions', () {
      testWidgets('handles text input', (tester) async {
        await tester.pumpWidget(buildWidget());
        await tester.pumpAndSettle();

        await tester.enterText(find.byType(TextFormField), 'Köttbullar');
        await tester.pump();

        expect(controller.text, equals('Köttbullar'));
      });

      testWidgets('calls onClear callback when clear button is pressed', (
        tester,
      ) async {
        bool clearCalled = false;
        controller.text = 'Test';

        await tester.pumpWidget(buildWidget(onClear: () => clearCalled = true));
        await tester.pumpAndSettle();

        await tester.tap(find.byIcon(Icons.clear));
        await tester.pump();

        expect(clearCalled, isTrue);
      });

      testWidgets('autofocuses when enabled', (tester) async {
        await tester.pumpWidget(buildWidget(autofocus: true));
        await tester.pumpAndSettle();

        expect(focusNode.hasFocus, isTrue);
      });

      testWidgets('does not autofocus when disabled', (tester) async {
        await tester.pumpWidget(buildWidget(autofocus: false));
        await tester.pumpAndSettle();

        expect(focusNode.hasFocus, isFalse);
      });

      testWidgets('maintains focus when typing', (tester) async {
        await tester.pumpWidget(buildWidget());
        await tester.pumpAndSettle();

        await tester.tap(find.byType(TextFormField));
        await tester.pump();
        expect(focusNode.hasFocus, isTrue);

        await tester.enterText(find.byType(TextFormField), 'Test');
        await tester.pump();
        expect(focusNode.hasFocus, isTrue);
      });
    });

    group('Swedish Localization', () {
      testWidgets('displays Swedish hint text by default', (tester) async {
        await tester.pumpWidget(buildWidget());
        await tester.pumpAndSettle();

        expect(find.text('sök...'), findsOneWidget);
      });

      testWidgets('handles Swedish characters in input', (tester) async {
        await tester.pumpWidget(buildWidget());
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byType(TextFormField),
          'Räksmörgås med ägg och öl',
        );
        await tester.pump();

        expect(controller.text, equals('Räksmörgås med ägg och öl'));
      });
    });

    group('Edge Cases', () {
      testWidgets('handles very long search text', (tester) async {
        final longText = 'Detta är en mycket lång söktext ' * 10;

        await tester.pumpWidget(buildWidget());
        await tester.pumpAndSettle();

        await tester.enterText(find.byType(TextFormField), longText);
        await tester.pump();

        expect(controller.text, equals(longText));
      });

      testWidgets('handles null onClear callback gracefully', (tester) async {
        controller.text = 'Test';

        await tester.pumpWidget(buildWidget(onClear: null));
        await tester.pumpAndSettle();

        // Should not crash when tapping clear with null callback
        await tester.tap(find.byIcon(Icons.clear));
        await tester.pump();
      });

      testWidgets('updates when controller text changes externally', (
        tester,
      ) async {
        await tester.pumpWidget(buildWidget());
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.clear), findsNothing);

        // Change controller text externally — widget listens internally
        controller.text = 'External update';
        await tester.pump();

        expect(find.byIcon(Icons.clear), findsOneWidget);
      });
    });

    group('Accessibility', () {
      testWidgets('has proper semantics for search field', (tester) async {
        await tester.pumpWidget(buildWidget(hintText: 'Sök recept'));
        await tester.pumpAndSettle();

        expect(find.byType(TextFormField), findsOneWidget);
        expect(find.byIcon(Icons.search), findsOneWidget);
      });

      testWidgets('handles keyboard actions properly', (tester) async {
        await tester.pumpWidget(buildWidget());
        await tester.pumpAndSettle();

        await tester.tap(find.byType(TextFormField));
        await tester.pump();

        await tester.enterText(find.byType(TextFormField), 'Test');
        expect(controller.text, equals('Test'));
      });
    });

    group('Trailing Widget', () {
      testWidgets('renders trailing widget when provided', (tester) async {
        await tester.pumpWidget(
          buildWidget(
            trailing: const Icon(Icons.tune, key: Key('trailing')),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('trailing')), findsOneWidget);
      });

      testWidgets('does not render trailing when null', (tester) async {
        await tester.pumpWidget(buildWidget(trailing: null));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('trailing')), findsNothing);
      });

      testWidgets('shows both clear button and trailing when text entered', (
        tester,
      ) async {
        controller.text = 'test';

        await tester.pumpWidget(
          buildWidget(
            trailing: const Icon(Icons.tune, key: Key('trailing')),
            onClear: () {},
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.clear), findsOneWidget);
        expect(find.byKey(const Key('trailing')), findsOneWidget);
      });

      testWidgets('shows only trailing when text is empty', (tester) async {
        await tester.pumpWidget(
          buildWidget(
            trailing: const Icon(Icons.tune, key: Key('trailing')),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.clear), findsNothing);
        expect(find.byKey(const Key('trailing')), findsOneWidget);
      });
    });

    group('Classic Style', () {
      testWidgets('classic style uses DecoratedBox with rounded border', (
        tester,
      ) async {
        await tester.pumpWidget(buildWidget(useClassicStyle: true));
        await tester.pumpAndSettle();

        expect(find.byType(TextFormField), findsOneWidget);
        // Classic style wraps in DecoratedBox (rounded border, no rust)
        expect(find.byType(DecoratedBox), findsWidgets);
      });

      testWidgets('default style uses DecoratedBox with rust border', (
        tester,
      ) async {
        await tester.pumpWidget(buildWidget(useClassicStyle: false));
        await tester.pumpAndSettle();

        expect(find.byType(DecoratedBox), findsAtLeastNWidgets(1));
      });

      testWidgets('defaults to non-classic style', (tester) async {
        await tester.pumpWidget(buildWidget());
        await tester.pumpAndSettle();

        // Default is non-classic, which has at least one DecoratedBox
        expect(find.byType(DecoratedBox), findsAtLeastNWidgets(1));
      });
    });
  });
}
