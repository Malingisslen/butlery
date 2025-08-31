// test/widget/common/indicators/emoji_avatar_test.dart
// Comprehensive tests for EmojiAvatar using ultrathink methodology

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/widgets/common/indicators/emoji_avatar.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_dimensions.dart';

void main() {
  group('EmojiAvatar Widget Tests', () {
    setUpAll(() {
      TestWidgetsFlutterBinding.ensureInitialized();
    });

    group('Default Constructor', () {
      testWidgets('should render with required emoji', (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: EmojiAvatar(emoji: '😀'),
            ),
          ),
        );

        expect(find.byType(EmojiAvatar), findsOneWidget);
        expect(find.text('😀'), findsOneWidget);
      });

      testWidgets('should use default size of 48', (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: EmojiAvatar(emoji: '😀'),
            ),
          ),
        );

        final renderBox = tester.renderObject<RenderBox>(
          find.byType(EmojiAvatar),
        );
        expect(renderBox.size.width, equals(48));
        expect(renderBox.size.height, equals(48));
      });

      testWidgets('should use default fontSize of 24', (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: EmojiAvatar(emoji: '😀'),
            ),
          ),
        );

        final text = tester.widget<Text>(find.text('😀'));
        expect(text.style?.fontSize, equals(24));
      });

      testWidgets('should use default blue background with alpha', (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: EmojiAvatar(emoji: '😀'),
            ),
          ),
        );

        final container = tester.widget<Container>(find.byType(Container));
        final decoration = container.decoration as BoxDecoration;
        expect(decoration.color, equals(AppColors.primaryBlue.withValues(alpha: 0.1)));
      });

      testWidgets('should apply custom size', (WidgetTester tester) async {
        const customSize = 64.0;
        
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: EmojiAvatar(
                emoji: '😀',
                size: customSize,
              ),
            ),
          ),
        );

        final renderBox = tester.renderObject<RenderBox>(
          find.byType(EmojiAvatar),
        );
        expect(renderBox.size.width, equals(customSize));
        expect(renderBox.size.height, equals(customSize));
      });

      testWidgets('should apply custom background color', (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: EmojiAvatar(
                emoji: '😀',
                backgroundColor: Colors.red,
              ),
            ),
          ),
        );

        final container = tester.widget<Container>(find.byType(Container));
        final decoration = container.decoration as BoxDecoration;
        expect(decoration.color, equals(Colors.red));
      });

      testWidgets('should apply custom font size', (WidgetTester tester) async {
        const customFontSize = 32.0;
        
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: EmojiAvatar(
                emoji: '😀',
                fontSize: customFontSize,
              ),
            ),
          ),
        );

        final text = tester.widget<Text>(find.text('😀'));
        expect(text.style?.fontSize, equals(customFontSize));
      });

      testWidgets('should have rounded corners', (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: EmojiAvatar(emoji: '😀'),
            ),
          ),
        );

        final container = tester.widget<Container>(find.byType(Container));
        final decoration = container.decoration as BoxDecoration;
        expect(
          decoration.borderRadius,
          equals(BorderRadius.circular(AppDimensions.borderRadiusM)),
        );
      });
    });

    group('Group Constructor', () {
      testWidgets('should render with group constructor', (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: EmojiAvatar.group(emoji: '👥'),
            ),
          ),
        );

        expect(find.byType(EmojiAvatar), findsOneWidget);
        expect(find.text('👥'), findsOneWidget);
      });

      testWidgets('should use size 48 for group', (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: EmojiAvatar.group(emoji: '👥'),
            ),
          ),
        );

        final renderBox = tester.renderObject<RenderBox>(
          find.byType(EmojiAvatar),
        );
        expect(renderBox.size.width, equals(48));
        expect(renderBox.size.height, equals(48));
      });

      testWidgets('should use fontSize 24 for group', (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: EmojiAvatar.group(emoji: '👥'),
            ),
          ),
        );

        final text = tester.widget<Text>(find.text('👥'));
        expect(text.style?.fontSize, equals(24));
      });
    });

    group('Different Emojis', () {
      testWidgets('should display face emojis', (WidgetTester tester) async {
        const emojis = ['😀', '😃', '😄', '😁', '😆'];
        
        for (final emoji in emojis) {
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: EmojiAvatar(emoji: emoji),
              ),
            ),
          );

          expect(find.text(emoji), findsOneWidget);
        }
      });

      testWidgets('should display object emojis', (WidgetTester tester) async {
        const emojis = ['🍎', '🍕', '🚗', '⚽', '🎨'];
        
        for (final emoji in emojis) {
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: EmojiAvatar(emoji: emoji),
              ),
            ),
          );

          expect(find.text(emoji), findsOneWidget);
        }
      });

      testWidgets('should display flag emojis', (WidgetTester tester) async {
        const emojis = ['🇸🇪', '🇺🇸', '🇬🇧', '🇩🇪', '🇫🇷'];
        
        for (final emoji in emojis) {
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: EmojiAvatar(emoji: emoji),
              ),
            ),
          );

          expect(find.text(emoji), findsOneWidget);
        }
      });

      testWidgets('should display multi-character emojis', (WidgetTester tester) async {
        const emojis = ['👨‍👩‍👧‍👦', '🏳️‍🌈', '👨‍💻', '👩‍🔬'];
        
        for (final emoji in emojis) {
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: EmojiAvatar(emoji: emoji),
              ),
            ),
          );

          expect(find.text(emoji), findsOneWidget);
        }
      });
    });

    group('Layout Integration', () {
      testWidgets('should work in Row layout', (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: Row(
                children: [
                  EmojiAvatar(emoji: '😀'),
                  EmojiAvatar(emoji: '😎'),
                  EmojiAvatar.group(emoji: '👥'),
                ],
              ),
            ),
          ),
        );

        expect(find.byType(EmojiAvatar), findsNWidgets(3));
        expect(find.text('😀'), findsOneWidget);
        expect(find.text('😎'), findsOneWidget);
        expect(find.text('👥'), findsOneWidget);
      });

      testWidgets('should work in Column layout', (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: Column(
                children: [
                  EmojiAvatar(emoji: '🎉'),
                  EmojiAvatar(emoji: '🎨'),
                ],
              ),
            ),
          ),
        );

        expect(find.byType(EmojiAvatar), findsNWidgets(2));
      });

      testWidgets('should work in Grid layout', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: GridView.count(
                crossAxisCount: 3,
                children: const [
                  EmojiAvatar(emoji: '😀'),
                  EmojiAvatar(emoji: '😎'),
                  EmojiAvatar(emoji: '🎉'),
                  EmojiAvatar(emoji: '🎨'),
                  EmojiAvatar(emoji: '🍕'),
                  EmojiAvatar(emoji: '⚽'),
                ],
              ),
            ),
          ),
        );

        expect(find.byType(EmojiAvatar), findsNWidgets(6));
      });
    });

    group('Visual Consistency', () {
      testWidgets('should center emoji in container', (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: EmojiAvatar(emoji: '😀'),
            ),
          ),
        );

        expect(find.byType(Center), findsOneWidget);
      });

      testWidgets('should maintain aspect ratio', (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: EmojiAvatar(emoji: '😀', size: 60),
            ),
          ),
        );

        final renderBox = tester.renderObject<RenderBox>(
          find.byType(EmojiAvatar),
        );
        expect(renderBox.size.width, equals(renderBox.size.height));
      });

      testWidgets('should scale font with avatar size', (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: Column(
                children: [
                  EmojiAvatar(emoji: '😀', size: 32, fontSize: 16),
                  EmojiAvatar(emoji: '😀', size: 64, fontSize: 32),
                  EmojiAvatar(emoji: '😀', size: 96, fontSize: 48),
                ],
              ),
            ),
          ),
        );

        expect(find.byType(EmojiAvatar), findsNWidgets(3));
      });
    });

    group('Theme Variations', () {
      testWidgets('should work with light theme', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.light(),
            home: const Scaffold(
              body: EmojiAvatar(emoji: '😀'),
            ),
          ),
        );

        expect(find.byType(EmojiAvatar), findsOneWidget);
      });

      testWidgets('should work with dark theme', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.dark(),
            home: const Scaffold(
              body: EmojiAvatar(emoji: '😀'),
            ),
          ),
        );

        expect(find.byType(EmojiAvatar), findsOneWidget);
      });
    });

    group('Edge Cases', () {
      testWidgets('should handle empty string', (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: EmojiAvatar(emoji: ''),
            ),
          ),
        );

        expect(find.text(''), findsOneWidget);
        expect(find.byType(EmojiAvatar), findsOneWidget);
      });

      testWidgets('should handle regular text', (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: EmojiAvatar(emoji: 'AB'),
            ),
          ),
        );

        expect(find.text('AB'), findsOneWidget);
      });

      testWidgets('should handle very small size', (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: EmojiAvatar(emoji: '😀', size: 16, fontSize: 8),
            ),
          ),
        );

        final renderBox = tester.renderObject<RenderBox>(
          find.byType(EmojiAvatar),
        );
        expect(renderBox.size.width, equals(16));
        expect(renderBox.size.height, equals(16));
      });

      testWidgets('should handle very large size', (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: EmojiAvatar(emoji: '😀', size: 200, fontSize: 100),
            ),
          ),
        );

        final renderBox = tester.renderObject<RenderBox>(
          find.byType(EmojiAvatar),
        );
        expect(renderBox.size.width, equals(200));
        expect(renderBox.size.height, equals(200));
      });

      testWidgets('should handle transparent background', (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: EmojiAvatar(
                emoji: '😀',
                backgroundColor: Colors.transparent,
              ),
            ),
          ),
        );

        final container = tester.widget<Container>(find.byType(Container));
        final decoration = container.decoration as BoxDecoration;
        expect(decoration.color, equals(Colors.transparent));
      });
    });

    group('Use Cases', () {
      testWidgets('should work as user avatar', (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: Row(
                children: [
                  EmojiAvatar(emoji: '😀', size: 40),
                  SizedBox(width: 8),
                  Text('User Name'),
                ],
              ),
            ),
          ),
        );

        expect(find.text('😀'), findsOneWidget);
        expect(find.text('User Name'), findsOneWidget);
      });

      testWidgets('should work as group icon', (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: Column(
                children: [
                  EmojiAvatar.group(emoji: '👥'),
                  Text('Group Chat'),
                ],
              ),
            ),
          ),
        );

        expect(find.text('👥'), findsOneWidget);
        expect(find.text('Group Chat'), findsOneWidget);
      });

      testWidgets('should work as category icon', (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: ListTile(
                leading: EmojiAvatar(emoji: '🍕', size: 40),
                title: Text('Food Category'),
              ),
            ),
          ),
        );

        expect(find.text('🍕'), findsOneWidget);
        expect(find.text('Food Category'), findsOneWidget);
      });
    });

    tearDownAll(() {
      // Clean up after all tests
    });
  });
}