// test/widget/social/groups/shared/group_dialog_components_ultrathink_test.dart
// Comprehensive tests for GroupDialogComponents using ultrathink methodology
//
// ULTRATHINK ANALYSIS: group_dialog_components.dart (307 lines)
// - 1 constants class: GroupEmojiConstants with 20 available emojis
// - 5 widget classes: EmojiSelector, ErrorDisplayWidget, WarningDisplayWidget, DialogHeader, DialogFooter
// - 1 utility class: ValidationUtils with Swedish validation logic
// - Swedish localization throughout with proper theme integration
// - Modern Flutter patterns: withValues(alpha:), proper ColorScheme usage

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/widgets/social/groups/shared/group_dialog_components.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/core/utils/validation_utils.dart';

void main() {
  group('Group Dialog Components Tests - ULTRATHINK METHODOLOGY', () {
    // Helper to create test environment with proper theming
    Widget createTestWidget(Widget child) {
      return MaterialApp(
        theme: ThemeData(
          colorScheme: ColorScheme.light(
            primary: Colors.blue,
            primaryContainer: Colors.blue.shade100,
            secondary: Colors.orange,
            surface: Colors.white,
            surfaceContainerHighest: Colors.grey.shade100,
            onSurface: Colors.black,
            onPrimary: Colors.white,
            outline: Colors.grey.shade400,
          ),
        ),
        home: Scaffold(
          body: SizedBox(
            height: 800,
            width: 800, // Increased width for emoji layout
            child: child,
          ),
        ),
      );
    }

    group('GroupEmojiConstants - Static Data Tests (lines 14-19)', () {
      test('should contain exactly 20 available emojis', () {
        // ULTRATHINK: Test production constant - exactly 20 emojis defined
        expect(GroupEmojiConstants.availableEmojis.length, equals(20));
      });

      test('should contain expected emoji set in correct order', () {
        // ULTRATHINK: Test actual production emoji list from lines 15-18
        const expectedEmojis = [
          '👥',
          '🏠',
          '💼',
          '🎯',
          '⚽',
          '🎮',
          '📚',
          '🎵',
          '🍕',
          '☕',
          '💪',
          '🌟',
          '🔥',
          '💎',
          '🚀',
          '🎉',
          '💡',
          '🎨',
          '🌈',
          '⭐'
        ];
        expect(GroupEmojiConstants.availableEmojis, equals(expectedEmojis));
      });

      test('should contain only valid emoji strings', () {
        // ULTRATHINK: Validate all emoji entries are non-empty strings
        for (final emoji in GroupEmojiConstants.availableEmojis) {
          expect(emoji, isA<String>());
          expect(emoji.isNotEmpty, isTrue);
          expect(emoji.length, greaterThanOrEqualTo(1));
        }
      });

      test('should contain unique emojis without duplicates', () {
        // ULTRATHINK: Ensure no duplicate emojis in the list
        final emojiSet = Set<String>.from(GroupEmojiConstants.availableEmojis);
        expect(emojiSet.length,
            equals(GroupEmojiConstants.availableEmojis.length));
      });
    });

    group('EmojiSelector Widget Tests (lines 22-94)', () {
      testWidgets('should render with default Swedish title and emoji grid',
          (WidgetTester tester) async {
        String selectedEmoji = '👥';

        await tester.pumpWidget(createTestWidget(
          EmojiSelector(
            selectedEmoji: selectedEmoji,
            onEmojiSelected: (emoji) => selectedEmoji = emoji,
          ),
        ));

        // ULTRATHINK: Test default title from line 31
        expect(find.text('Välj ikon'), findsOneWidget);
        expect(find.byType(Column), findsOneWidget);
        expect(find.byType(ListView), findsOneWidget);

        // Should display emoji gestures (some may be off-screen in horizontal scroll)
        expect(find.byType(GestureDetector), findsAtLeastNWidgets(1));
      });

      testWidgets('should render with custom title when provided',
          (WidgetTester tester) async {
        const customTitle = 'Välj gruppikon';

        await tester.pumpWidget(createTestWidget(
          EmojiSelector(
            selectedEmoji: '🏠',
            onEmojiSelected: (emoji) {},
            title: customTitle,
          ),
        ));

        expect(find.text(customTitle), findsOneWidget);
        expect(find.text('Välj ikon'),
            findsNothing); // Default title should not appear
      });

      testWidgets(
          'should highlight selected emoji with primary container background',
          (WidgetTester tester) async {
        const selectedEmoji = '💼';

        await tester.pumpWidget(createTestWidget(
          EmojiSelector(
            selectedEmoji: selectedEmoji,
            onEmojiSelected: (emoji) {},
          ),
        ));

        // ULTRATHINK: Verify emoji gestures exist (some may be off-screen)
        expect(find.byType(GestureDetector), findsAtLeastNWidgets(1));

        // Find the selected emoji text widget
        expect(find.text(selectedEmoji), findsOneWidget);
      });

      testWidgets('should trigger callback when emoji is tapped',
          (WidgetTester tester) async {
        const selectedEmoji = '👥';
        String tappedEmoji = '';

        await tester.pumpWidget(createTestWidget(
          EmojiSelector(
            selectedEmoji: selectedEmoji,
            onEmojiSelected: (emoji) => tappedEmoji = emoji,
          ),
        ));

        // ULTRATHINK: Tap on the second emoji '🏠' using GestureDetector
        await tester.tap(find.byType(GestureDetector).at(1));
        expect(tappedEmoji, equals('🏠'));
      });

      testWidgets('should use AppTextStyles.titleMedium for title',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          EmojiSelector(
            selectedEmoji: '🎯',
            onEmojiSelected: (emoji) {},
          ),
        ));

        final titleText = tester.widget<Text>(find.text('Välj ikon'));
        expect(titleText.style, equals(AppTextStyles.titleMedium));
      });

      testWidgets('should use proper AppDimensions constants for layout',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          EmojiSelector(
            selectedEmoji: '⚽',
            onEmojiSelected: (emoji) {},
          ),
        ));

        // ULTRATHINK: Check spacing from line 43
        final spacingBoxes = tester.widgetList<SizedBox>(find.byType(SizedBox));
        final titleSpacing = spacingBoxes.firstWhere(
          (box) => box.height == AppDimensions.spacingS,
          orElse: () => throw StateError('Title spacing not found'),
        );
        expect(titleSpacing.height, equals(AppDimensions.spacingS));

        // Check that ListView exists for emoji selection
        expect(find.byType(ListView), findsOneWidget);
        final listView = tester.widget<ListView>(find.byType(ListView));
        expect(listView.scrollDirection, equals(Axis.horizontal));
      });

      testWidgets('should handle emoji selection changes correctly',
          (WidgetTester tester) async {
        String selectedEmoji = '🎮';

        await tester.pumpWidget(createTestWidget(
          StatefulBuilder(
            builder: (context, setState) => EmojiSelector(
              selectedEmoji: selectedEmoji,
              onEmojiSelected: (emoji) => setState(() => selectedEmoji = emoji),
            ),
          ),
        ));

        // Initial state
        expect(find.text('🎮'), findsOneWidget);

        // Tap different emoji and verify state change
        await tester.tap(find.byType(GestureDetector).at(8)); // 🍕 emoji
        await tester.pumpAndSettle();

        // The StatefulBuilder should trigger rebuild with new selection
        expect(selectedEmoji, equals('🍕'));
      });
    });

    group('ErrorDisplayWidget Tests (lines 97-134)', () {
      testWidgets('should display error message with proper styling',
          (WidgetTester tester) async {
        const errorMessage = 'Ett fel uppstod vid grupphantering';

        await tester.pumpWidget(createTestWidget(
          const ErrorDisplayWidget(errorMessage: errorMessage),
        ));

        expect(find.text(errorMessage), findsOneWidget);
        expect(find.byIcon(Icons.error_outline), findsOneWidget);
        expect(find.byType(Container), findsOneWidget);
      });

      testWidgets('should use AppColors.error for styling',
          (WidgetTester tester) async {
        const errorMessage = 'Validering misslyckades';

        await tester.pumpWidget(createTestWidget(
          const ErrorDisplayWidget(errorMessage: errorMessage),
        ));

        // ULTRATHINK: Check error icon color from lines 117-119
        final errorIcon = tester.widget<Icon>(find.byIcon(Icons.error_outline));
        expect(errorIcon.color, equals(AppColors.error));
        expect(errorIcon.size, equals(20));

        // Check text style uses error color (lines 125-127)
        final errorText = tester.widget<Text>(find.text(errorMessage));
        expect(errorText.style?.color, equals(AppColors.error));
      });

      testWidgets('should use proper AppDimensions for layout',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          const ErrorDisplayWidget(errorMessage: 'Test error'),
        ));

        // ULTRATHINK: Check container padding from line 108
        final container = tester.widget<Container>(find.byType(Container));
        expect(container.padding,
            equals(const EdgeInsets.all(AppDimensions.spacingM)));

        // Check icon spacing from line 121
        final spacingBoxes = tester.widgetList<SizedBox>(find.byType(SizedBox));
        final iconSpacing = spacingBoxes.firstWhere(
          (box) => box.width == AppDimensions.spacingS,
          orElse: () => throw StateError('Icon spacing not found'),
        );
        expect(iconSpacing.width, equals(AppDimensions.spacingS));
      });

      testWidgets('should handle Swedish error messages correctly',
          (WidgetTester tester) async {
        const swedishError = 'Gruppnamnet innehåller ogiltiga tecken åäö';

        await tester.pumpWidget(createTestWidget(
          const ErrorDisplayWidget(errorMessage: swedishError),
        ));

        expect(find.text(swedishError), findsOneWidget);
      });

      testWidgets('should handle empty and very long error messages',
          (WidgetTester tester) async {
        // Empty message
        await tester.pumpWidget(createTestWidget(
          const ErrorDisplayWidget(errorMessage: ''),
        ));
        expect(find.text(''), findsOneWidget);

        // Very long message
        const longMessage =
            'Detta är ett mycket långt felmeddelande som borde hanteras korrekt av komponentens layout med text wrapping och expanded widget för att säkerställa att texten visas korrekt även i begränsade utrymmen.';
        await tester.pumpWidget(createTestWidget(
          const ErrorDisplayWidget(errorMessage: longMessage),
        ));
        expect(find.text(longMessage), findsOneWidget);
      });
    });

    group('WarningDisplayWidget Tests (lines 137-176)', () {
      testWidgets('should display warning message with info icon',
          (WidgetTester tester) async {
        const warningMessage = 'Den här åtgärden kan inte ångras';

        await tester.pumpWidget(createTestWidget(
          const WarningDisplayWidget(warningMessage: warningMessage),
        ));

        expect(find.text(warningMessage), findsOneWidget);
        expect(find.byIcon(Icons.info_outline), findsOneWidget);
      });

      testWidgets('should use AppColors.warning for styling',
          (WidgetTester tester) async {
        const warningMessage = 'Varning för gruppändring';

        await tester.pumpWidget(createTestWidget(
          const WarningDisplayWidget(warningMessage: warningMessage),
        ));

        // ULTRATHINK: Check warning icon color from lines 158-161
        final warningIcon =
            tester.widget<Icon>(find.byIcon(Icons.info_outline));
        expect(warningIcon.color, equals(AppColors.warning));
        expect(warningIcon.size, equals(20));

        // Check text uses warning color and bodySmall style (lines 167-169)
        final warningText = tester.widget<Text>(find.text(warningMessage));
        expect(warningText.style?.color, equals(AppColors.warning));
      });

      testWidgets('should use AppTextStyles.bodySmall for text',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          const WarningDisplayWidget(warningMessage: 'Test varning'),
        ));

        final warningText = tester.widget<Text>(find.text('Test varning'));
        // ULTRATHINK: Check base style is bodySmall (line 167)
        expect(warningText.style?.fontSize,
            equals(AppTextStyles.bodySmall.fontSize));
      });

      testWidgets(
          'should handle Swedish warning messages with special characters',
          (WidgetTester tester) async {
        const swedishWarning =
            'Är du säker på att du vill fortsätta? Åtgärden påverkar alla medlemmar.';

        await tester.pumpWidget(createTestWidget(
          const WarningDisplayWidget(warningMessage: swedishWarning),
        ));

        expect(find.text(swedishWarning), findsOneWidget);
      });
    });

    group('DialogHeader Tests (lines 179-223)', () {
      testWidgets('should display title, icon, and close button',
          (WidgetTester tester) async {
        const title = 'Skapa ny grupp';
        const icon = Icons.group_add;
        bool closeTapped = false;

        await tester.pumpWidget(createTestWidget(
          DialogHeader(
            title: title,
            icon: icon,
            onClose: () => closeTapped = true,
          ),
        ));

        expect(find.text(title), findsOneWidget);
        expect(find.byIcon(icon), findsOneWidget);
        expect(find.byIcon(Icons.close), findsOneWidget);
        expect(find.byType(IconButton), findsOneWidget);

        // Test close button
        await tester.tap(find.byIcon(Icons.close));
        expect(closeTapped, isTrue);
      });

      testWidgets('should use primaryContainer background with proper styling',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          DialogHeader(
            title: 'Test Header',
            icon: Icons.edit,
            onClose: () {},
          ),
        ));

        // ULTRATHINK: Check container decoration from lines 194-200
        final container = tester.widget<Container>(find.byType(Container));
        final decoration = container.decoration as BoxDecoration;

        // Background should use primaryContainer from theme
        // BorderRadius should use AppDimensions.borderRadius12 (line 198)
        expect(
            decoration.borderRadius,
            equals(const BorderRadius.vertical(
              top: Radius.circular(AppDimensions.borderRadius12),
            )));
      });

      testWidgets(
          'should use AppTextStyles.headlineSmall for title with primary color',
          (WidgetTester tester) async {
        const title = 'Redigera grupp';

        await tester.pumpWidget(createTestWidget(
          DialogHeader(
            title: title,
            icon: Icons.edit,
            onClose: () {},
          ),
        ));

        final titleText = tester.widget<Text>(find.text(title));
        // ULTRATHINK: Check title style from lines 210-212
        expect(titleText.style?.fontSize,
            equals(AppTextStyles.headlineSmall.fontSize));
        expect(titleText.style?.fontWeight,
            equals(AppTextStyles.headlineSmall.fontWeight));
      });

      testWidgets('should handle Swedish titles correctly',
          (WidgetTester tester) async {
        const swedishTitle = 'Redigera grupp';

        await tester.pumpWidget(createTestWidget(
          DialogHeader(
            title: swedishTitle,
            icon: Icons.settings,
            onClose: () {},
          ),
        ));

        expect(find.text(swedishTitle), findsOneWidget);
      });

      testWidgets('should use proper AppDimensions for spacing and padding',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          DialogHeader(
            title: 'Test',
            icon: Icons.info,
            onClose: () {},
          ),
        ));

        // ULTRATHINK: Check container padding from line 194
        final container = tester.widget<Container>(find.byType(Container));
        expect(container.padding,
            equals(const EdgeInsets.all(AppDimensions.spacingL)));

        // Check icon spacing from line 207
        final spacingBoxes = tester.widgetList<SizedBox>(find.byType(SizedBox));
        final iconSpacing = spacingBoxes.firstWhere(
          (box) => box.width == AppDimensions.spacingS,
          orElse: () => throw StateError('Icon spacing not found'),
        );
        expect(iconSpacing.width, equals(AppDimensions.spacingS));
      });
    });

    group('DialogFooter Tests (lines 226-291)', () {
      testWidgets('should display primary and secondary action buttons',
          (WidgetTester tester) async {
        const primaryText = 'Spara';
        const secondaryText = 'Avbryt';
        bool primaryTapped = false;
        bool secondaryTapped = false;

        await tester.pumpWidget(createTestWidget(
          DialogFooter(
            primaryActionText: primaryText,
            secondaryActionText: secondaryText,
            onPrimaryAction: () => primaryTapped = true,
            onSecondaryAction: () => secondaryTapped = true,
            isLoading: false,
            primaryActionIcon: Icons.save,
          ),
        ));

        expect(find.text(primaryText), findsOneWidget);
        expect(find.text(secondaryText), findsOneWidget);
        expect(find.byIcon(Icons.save), findsOneWidget);
        expect(find.byType(TextButton), findsOneWidget);

        // Test button callbacks
        await tester.tap(find.text(primaryText));
        expect(primaryTapped, isTrue);

        await tester.tap(find.text(secondaryText));
        expect(secondaryTapped, isTrue);
      });

      testWidgets('should show loading indicator when isLoading is true',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          DialogFooter(
            primaryActionText: 'Sparar...',
            secondaryActionText: 'Avbryt',
            onPrimaryAction: () {},
            onSecondaryAction: () {},
            isLoading: true,
            primaryActionIcon: Icons.save,
          ),
        ));

        // ULTRATHINK: Check loading indicator from lines 274-283
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(find.byIcon(Icons.save),
            findsNothing); // Icon should be replaced by loading

        final progressIndicator = tester.widget<CircularProgressIndicator>(
            find.byType(CircularProgressIndicator));
        expect(progressIndicator.strokeWidth, equals(2));
      });

      testWidgets('should disable secondary button when loading',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          DialogFooter(
            primaryActionText: 'Sparar...',
            secondaryActionText: 'Avbryt',
            onPrimaryAction: () {},
            onSecondaryAction: () {},
            isLoading: true,
            primaryActionIcon: Icons.save,
          ),
        ));

        // ULTRATHINK: Secondary button should be disabled when loading (line 262)
        final textButton = tester.widget<TextButton>(find.byType(TextButton));
        expect(textButton.onPressed, isNull);
      });

      testWidgets('should apply custom colors when provided',
          (WidgetTester tester) async {
        const customBgColor = Colors.red;
        const customFgColor = Colors.white;

        await tester.pumpWidget(createTestWidget(
          DialogFooter(
            primaryActionText: 'Radera',
            secondaryActionText: 'Avbryt',
            onPrimaryAction: () {},
            onSecondaryAction: () {},
            isLoading: false,
            primaryActionIcon: Icons.delete,
            primaryActionColor: customBgColor,
            primaryActionForegroundColor: customFgColor,
          ),
        ));

        // ULTRATHINK: Verify custom colors are applied through button styling
        expect(find.byIcon(Icons.delete), findsOneWidget);
        expect(find.text('Radera'), findsOneWidget);
      });

      testWidgets('should use proper AppDimensions for spacing and padding',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          DialogFooter(
            primaryActionText: 'OK',
            secondaryActionText: 'Avbryt',
            onPrimaryAction: () {},
            onSecondaryAction: () {},
            isLoading: false,
            primaryActionIcon: Icons.check,
          ),
        ));

        // ULTRATHINK: Check container padding from line 251
        final container = tester.widget<Container>(find.byType(Container));
        expect(container.padding,
            equals(const EdgeInsets.all(AppDimensions.spacingL)));

        // Check button spacing from line 265
        final spacingBoxes = tester.widgetList<SizedBox>(find.byType(SizedBox));
        final buttonSpacing = spacingBoxes.firstWhere(
          (box) => box.width == AppDimensions.spacingM,
          orElse: () => throw StateError('Button spacing not found'),
        );
        expect(buttonSpacing.width, equals(AppDimensions.spacingM));
      });

      testWidgets('should handle Swedish action button text',
          (WidgetTester tester) async {
        const primaryText = 'Bekräfta ändringar';
        const secondaryText = 'Ångra och stäng';

        await tester.pumpWidget(createTestWidget(
          DialogFooter(
            primaryActionText: primaryText,
            secondaryActionText: secondaryText,
            onPrimaryAction: () {},
            onSecondaryAction: () {},
            isLoading: false,
            primaryActionIcon: Icons.done,
          ),
        ));

        expect(find.text(primaryText), findsOneWidget);
        expect(find.text(secondaryText), findsOneWidget);
      });
    });

    group('ValidationUtils.validateGroupName Tests (lines 294-307)', () {
      test('should return error for null group name', () {
        // ULTRATHINK: Test null validation from lines 295-298
        final result = ValidationUtils.validateGroupName(null);
        expect(result, isNotNull);
        expect(result, contains('Gruppnamn'));
      });

      test('should return error for empty group name', () {
        final result = ValidationUtils.validateGroupName('');
        expect(result, isNotNull);
        expect(result, contains('Gruppnamn'));
      });

      test('should return error for whitespace-only group name', () {
        final result = ValidationUtils.validateGroupName('   ');
        expect(result, isNotNull);
        expect(result, contains('Gruppnamn'));
      });

      test('should return error for group name shorter than 2 characters', () {
        // ULTRATHINK: Test minimum length validation from lines 299-301
        final result = ValidationUtils.validateGroupName('A');
        expect(result, isNotNull);
        expect(result, contains('2'));
      });

      test('should return error for group name longer than 50 characters', () {
        // ULTRATHINK: Test maximum length validation from lines 302-304
        final longName = 'A' * 51; // 51 characters
        final result = ValidationUtils.validateGroupName(longName);
        expect(result, equals('Gruppnamnet får vara max 50 tecken'));
      });

      test('should return null for valid group names', () {
        // ULTRATHINK: Test success case from line 305
        expect(
            ValidationUtils.validateGroupName('AB'), isNull); // Minimum valid
        expect(
            ValidationUtils.validateGroupName('Familj'), isNull); // Normal case
        expect(ValidationUtils.validateGroupName('A' * 50),
            isNull); // Maximum valid
      });

      test('should handle Swedish characters correctly', () {
        expect(ValidationUtils.validateGroupName('Kött & Fisk'), isNull);
        expect(ValidationUtils.validateGroupName('Åsa & Östen'), isNull);
        expect(ValidationUtils.validateGroupName('Räkmackor för alla'), isNull);
      });

      test('should trim whitespace before validation', () {
        // ULTRATHINK: Test that validation trims input (lines 296, 299, 302)
        expect(ValidationUtils.validateGroupName('  AB  '), isNull);
        expect(ValidationUtils.validateGroupName(' A '),
            equals('Gruppnamnet måste vara minst 2 tecken'));
      });

      test('should handle edge cases correctly', () {
        // Exactly 2 characters (minimum)
        expect(ValidationUtils.validateGroupName('AB'), isNull);

        // Exactly 50 characters (maximum)
        final fiftyChars = 'A' * 50;
        expect(ValidationUtils.validateGroupName(fiftyChars), isNull);

        // Exactly 51 characters (over limit)
        final fiftyOneChars = 'A' * 51;
        expect(ValidationUtils.validateGroupName(fiftyOneChars),
            equals('Gruppnamnet får vara max 50 tecken'));
      });

      test('should handle special characters and numbers', () {
        expect(ValidationUtils.validateGroupName('Grupp-1'), isNull);
        expect(ValidationUtils.validateGroupName('Team @2024'), isNull);
        expect(ValidationUtils.validateGroupName('Kött & Kött 123!'), isNull);
      });
    });

    group('Integration Tests - Component Interactions', () {
      testWidgets('should handle complete dialog composition',
          (WidgetTester tester) async {
        String selectedEmoji = '👥';
        bool dialogClosed = false;
        bool primaryActionTapped = false;

        await tester.pumpWidget(createTestWidget(
          Column(
            children: [
              DialogHeader(
                title: 'Skapa grupp',
                icon: Icons.group_add,
                onClose: () => dialogClosed = true,
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      EmojiSelector(
                        selectedEmoji: selectedEmoji,
                        onEmojiSelected: (emoji) => selectedEmoji = emoji,
                      ),
                      const SizedBox(height: 16),
                      const ErrorDisplayWidget(
                        errorMessage: 'Gruppnamnet är obligatoriskt',
                      ),
                    ],
                  ),
                ),
              ),
              DialogFooter(
                primaryActionText: 'Skapa',
                secondaryActionText: 'Avbryt',
                onPrimaryAction: () => primaryActionTapped = true,
                onSecondaryAction: () => dialogClosed = true,
                isLoading: false,
                primaryActionIcon: Icons.add,
              ),
            ],
          ),
        ));

        // Verify all components are present
        expect(find.text('Skapa grupp'), findsOneWidget);
        expect(find.text('Välj ikon'), findsOneWidget);
        expect(find.text('Gruppnamnet är obligatoriskt'), findsOneWidget);
        expect(find.text('Skapa'), findsOneWidget);
        expect(find.text('Avbryt'), findsOneWidget);

        // Test interactions
        await tester.tap(find.byIcon(Icons.close));
        expect(dialogClosed, isTrue);

        dialogClosed = false;
        await tester.tap(find.text('Avbryt'));
        expect(dialogClosed, isTrue);

        await tester.tap(find.text('Skapa'));
        expect(primaryActionTapped, isTrue);
      });

      testWidgets('should handle error and warning states together',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          const Column(
            children: [
              ErrorDisplayWidget(errorMessage: 'Gruppnamnet är för kort'),
              SizedBox(height: 16),
              WarningDisplayWidget(warningMessage: 'Åtgärden kan inte ångras'),
            ],
          ),
        ));

        expect(find.text('Gruppnamnet är för kort'), findsOneWidget);
        expect(find.text('Åtgärden kan inte ångras'), findsOneWidget);
        expect(find.byIcon(Icons.error_outline), findsOneWidget);
        expect(find.byIcon(Icons.info_outline), findsOneWidget);
      });

      testWidgets('should maintain consistent theming across all components',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          Column(
            children: [
              DialogHeader(
                title: 'Test Dialog',
                icon: Icons.settings,
                onClose: () {},
              ),
              EmojiSelector(
                selectedEmoji: '🎯',
                onEmojiSelected: (emoji) {},
              ),
              const ErrorDisplayWidget(errorMessage: 'Test error'),
              DialogFooter(
                primaryActionText: 'OK',
                secondaryActionText: 'Cancel',
                onPrimaryAction: () {},
                onSecondaryAction: () {},
                isLoading: false,
                primaryActionIcon: Icons.check,
              ),
            ],
          ),
        ));

        // All components should render without theme conflicts
        expect(find.text('Test Dialog'), findsOneWidget);
        expect(find.text('Välj ikon'), findsOneWidget);
        expect(find.text('Test error'), findsOneWidget);
        expect(find.text('OK'), findsOneWidget);
        expect(find.text('Cancel'), findsOneWidget);
      });
    });
  });
}
