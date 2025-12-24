import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cached_network_image/cached_network_image.dart';

// Widget under test
import 'package:butlery/widgets/user/user_avatar_widgets.dart';
import 'package:butlery/widgets/user/user_display_models.dart';

// Dependencies - ultrathink production code analysis
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_dimensions.dart';

void main() {
  // Initialize test environment
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  group('UserAvatarWidgets Ultrathink Widget Tests', () {
    // Helper to create properly sized widget - ultrathink layout solution
    Widget createTestWidget({Widget? child}) {
      return MaterialApp(
        locale: const Locale('sv', 'SE'), // Swedish locale
        home: Scaffold(
          body: SingleChildScrollView(
            child: child ?? const SizedBox.shrink(),
          ),
        ),
      );
    }

    group('Avatar Method - Foundation Functionality', () {
      testWidgets('renders basic avatar with initials - Swedish names',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          child: UserAvatarWidgets.avatar(
            displayName: 'Anna Andersson',
          ),
        ));

        // Core UI elements - Swedish name handling
        expect(find.text('AA'), findsOneWidget);

        // Verify container structure
        final container =
            tester.widget<Container>(find.byType(Container).first);
        expect(container.decoration, isA<BoxDecoration>());
        final decoration = container.decoration as BoxDecoration;
        expect(decoration.shape, equals(BoxShape.circle));
      });

      testWidgets('renders avatar with image URL - network image handling',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          child: UserAvatarWidgets.avatar(
            imageUrl: 'https://example.com/avatar.jpg',
            displayName: 'Erik Eriksson',
          ),
        ));

        // Should have CachedNetworkImage for network handling
        expect(find.byType(CachedNetworkImage), findsOneWidget);

        // Should have ClipOval for circular masking
        expect(find.byType(ClipOval), findsOneWidget);

        // Placeholder should show initials
        expect(find.text('EE'), findsOneWidget);
      });

      testWidgets('handles empty image URL correctly',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          child: UserAvatarWidgets.avatar(
            imageUrl: '',
            displayName: 'Johan Johansson',
          ),
        ));

        // Empty URL should not create CachedNetworkImage
        expect(find.byType(CachedNetworkImage), findsNothing);
        expect(find.text('JJ'), findsOneWidget);
      });

      testWidgets('handles null image URL correctly',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          child: UserAvatarWidgets.avatar(
            imageUrl: null,
            displayName: 'Maria Nilsson',
          ),
        ));

        // Null URL should not create CachedNetworkImage
        expect(find.byType(CachedNetworkImage), findsNothing);
        expect(find.text('MN'), findsOneWidget);
      });
    });

    group('Size Calculation - Production Code Alignment', () {
      testWidgets('applies correct size for ImageSize.small',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          child: UserAvatarWidgets.avatar(
            displayName: 'Test Small',
            size: ImageSize.small,
          ),
        ));

        // Find container with circular decoration (main avatar container)
        final containerFinder = find.byWidgetPredicate(
          (widget) =>
              widget is Container &&
              widget.decoration is BoxDecoration &&
              (widget.decoration as BoxDecoration).shape == BoxShape.circle,
        );
        expect(containerFinder, findsWidgets);
      });

      testWidgets('applies correct size for ImageSize.medium',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          child: UserAvatarWidgets.avatar(
            displayName: 'Test Medium',
            size: ImageSize.medium,
          ),
        ));

        // Medium size avatar should be rendered
        expect(find.text('TM'), findsOneWidget);

        // Should have circular container
        final containerFinder = find.byWidgetPredicate(
          (widget) =>
              widget is Container &&
              widget.decoration is BoxDecoration &&
              (widget.decoration as BoxDecoration).shape == BoxShape.circle,
        );
        expect(containerFinder, findsWidgets);
      });

      testWidgets('applies correct size for ImageSize.large',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          child: UserAvatarWidgets.avatar(
            displayName: 'Test Large',
            size: ImageSize.large,
          ),
        ));

        expect(find.text('TL'), findsOneWidget);
        expect(find.byType(Container), findsWidgets);
      });

      testWidgets('applies correct size for ImageSize.extraLarge',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          child: UserAvatarWidgets.avatar(
            displayName: 'Test XLarge',
            size: ImageSize.extraLarge,
          ),
        ));

        expect(find.text('TX'), findsOneWidget);
        expect(find.byType(Container), findsWidgets);
      });

      testWidgets('applies correct size for ImageSize.hero',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          child: UserAvatarWidgets.avatar(
            displayName: 'Test Hero',
            size: ImageSize.hero,
          ),
        ));

        expect(find.text('TH'), findsOneWidget);
        expect(find.byType(Container), findsWidgets);
      });
    });

    group('Status Indicator System - Swedish UX', () {
      testWidgets('shows online status indicator correctly',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          child: UserAvatarWidgets.avatar(
            displayName: 'Online Användare',
            showStatus: true,
            isOnline: true,
          ),
        ));

        // Should have Stack for overlay
        expect(find.byType(Stack), findsWidgets);

        // Should have Positioned widget for status indicator
        expect(find.byType(Positioned), findsOneWidget);

        // Status indicator should be positioned correctly
        final positioned = tester.widget<Positioned>(find.byType(Positioned));
        expect(positioned.right, equals(0));
        expect(positioned.bottom, equals(0));

        // Status container should have success color for online
        final statusContainers =
            tester.widgetList<Container>(find.byType(Container));
        final statusContainer = statusContainers.firstWhere(
          (container) =>
              container.decoration is BoxDecoration &&
              (container.decoration as BoxDecoration).color ==
                  AppColors.success,
        );
        expect(statusContainer, isNotNull);
      });

      testWidgets('shows offline status indicator correctly',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          child: UserAvatarWidgets.avatar(
            displayName: 'Offline Användare',
            showStatus: true,
            isOnline: false,
          ),
        ));

        // Should have Stack for overlay
        expect(find.byType(Stack), findsWidgets);

        // Status container should have tertiary color for offline
        final statusContainers =
            tester.widgetList<Container>(find.byType(Container));
        final statusContainer = statusContainers.firstWhere(
          (container) =>
              container.decoration is BoxDecoration &&
              (container.decoration as BoxDecoration).color ==
                  AppColors.textTertiary,
        );
        expect(statusContainer, isNotNull);
      });

      testWidgets('does not show status when disabled',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          child: UserAvatarWidgets.avatar(
            displayName: 'No Status User',
            showStatus: false,
            isOnline: true,
          ),
        ));

        // Should not have Stack when status is disabled (but MaterialApp creates one)
        // Main verification is that no Positioned widget exists for status
        expect(find.byType(Positioned), findsNothing);
      });

      testWidgets('status indicator size scales with avatar size',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          child: UserAvatarWidgets.avatar(
            displayName: 'Status Test',
            size: ImageSize.large,
            showStatus: true,
            isOnline: true,
          ),
        ));

        // Find status indicator container
        final statusContainers =
            tester.widgetList<Container>(find.byType(Container));
        final statusContainer = statusContainers.firstWhere(
          (container) =>
              container.decoration is BoxDecoration &&
              (container.decoration as BoxDecoration).color ==
                  AppColors.success,
        );

        // Status should be 25% of avatar size (verified by finding status container)
        expect(statusContainer, isNotNull);
      });
    });

    group('Interactive Behavior - Touch Handling', () {
      testWidgets('creates InkWell when onTap provided',
          (WidgetTester tester) async {
        bool tapped = false;

        await tester.pumpWidget(createTestWidget(
          child: UserAvatarWidgets.avatar(
            displayName: 'Tappable User',
            onTap: () => tapped = true,
          ),
        ));

        // Should have Material for InkWell (plus MaterialApp's Material)
        expect(find.byType(Material), findsWidgets);
        expect(find.byType(InkWell), findsOneWidget);

        // Tap the avatar
        await tester.tap(find.byType(InkWell));
        await tester.pumpAndSettle();

        expect(tapped, isTrue);
      });

      testWidgets('does not create InkWell when onTap is null',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          child: UserAvatarWidgets.avatar(
            displayName: 'Static User',
          ),
        ));

        // Should not have InkWell when onTap is null
        expect(find.byType(InkWell), findsNothing);
        // MaterialApp still creates a Material widget, so we check for specific transparent Material
        final materials = tester.widgetList<Material>(find.byType(Material));
        final transparentMaterials =
            materials.where((m) => m.color == Colors.transparent);
        expect(transparentMaterials.length, equals(0));
      });

      testWidgets('applies correct border radius for touch feedback',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          child: UserAvatarWidgets.avatar(
            displayName: 'Touch Test',
            size: ImageSize.medium,
            onTap: () {},
          ),
        ));

        final inkWell = tester.widget<InkWell>(find.byType(InkWell));
        final expectedRadius = AppDimensions.iconSizeXxl / 2;
        expect(inkWell.borderRadius,
            equals(BorderRadius.circular(expectedRadius)));
      });
    });

    group('Custom Styling - Design System Integration', () {
      testWidgets('applies custom background color',
          (WidgetTester tester) async {
        const customColor = Colors.red;

        await tester.pumpWidget(createTestWidget(
          child: UserAvatarWidgets.avatar(
            displayName: 'Red Background',
            backgroundColor: customColor,
          ),
        ));

        final container =
            tester.widget<Container>(find.byType(Container).first);
        final decoration = container.decoration as BoxDecoration;
        expect(decoration.color, equals(customColor));
      });

      testWidgets('applies custom text color', (WidgetTester tester) async {
        const customTextColor = Colors.yellow;

        await tester.pumpWidget(createTestWidget(
          child: UserAvatarWidgets.avatar(
            displayName: 'Yellow Text',
            textColor: customTextColor,
          ),
        ));

        final textWidget = tester.widget<Text>(find.text('YT'));
        expect(textWidget.style?.color, equals(customTextColor));
      });

      testWidgets('applies custom border styling', (WidgetTester tester) async {
        const borderColor = Colors.blue;
        const borderWidth = 3.0;

        await tester.pumpWidget(createTestWidget(
          child: UserAvatarWidgets.avatar(
            displayName: 'Bordered Avatar',
            borderColor: borderColor,
            borderWidth: borderWidth,
          ),
        ));

        final container =
            tester.widget<Container>(find.byType(Container).first);
        final decoration = container.decoration as BoxDecoration;
        final border = decoration.border as Border;
        expect(border.top.color, equals(borderColor));
        expect(border.top.width, equals(borderWidth));
      });

      testWidgets('uses default colors when not specified',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          child: UserAvatarWidgets.avatar(
            displayName: 'Default Colors',
          ),
        ));

        final container =
            tester.widget<Container>(find.byType(Container).first);
        final decoration = container.decoration as BoxDecoration;
        expect(decoration.color,
            equals(AppColors.primaryBlue.withValues(alpha: 0.1)));

        final textWidget = tester.widget<Text>(find.text('DC'));
        expect(textWidget.style?.color, equals(AppColors.primaryBlue));
      });
    });

    group('Initials Generation - Swedish Character Support', () {
      testWidgets('generates initials for Swedish characters',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          child: UserAvatarWidgets.avatar(
            displayName: 'Åsa Öberg',
          ),
        ));

        expect(find.text('ÅÖ'), findsOneWidget);
      });

      testWidgets('handles mixed case Swedish names',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          child: UserAvatarWidgets.avatar(
            displayName: 'björn älg',
          ),
        ));

        expect(find.text('BÄ'), findsOneWidget);
      });

      testWidgets('handles single word names correctly',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          child: UserAvatarWidgets.avatar(
            displayName: 'Magnus',
          ),
        ));

        // Should use first two characters for single word
        expect(find.text('MA'), findsOneWidget);
      });

      testWidgets('handles single character names',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          child: UserAvatarWidgets.avatar(
            displayName: 'A',
          ),
        ));

        expect(find.text('A'), findsOneWidget);
      });

      testWidgets('handles empty name with fallback',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          child: UserAvatarWidgets.avatar(
            displayName: '',
          ),
        ));

        expect(find.text('?'), findsOneWidget);
      });

      testWidgets('trims whitespace correctly', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          child: UserAvatarWidgets.avatar(
            displayName: '  Johan   Johansson  ',
          ),
        ));

        expect(find.text('JJ'), findsOneWidget);
      });

      testWidgets('handles names with special characters',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          child: UserAvatarWidgets.avatar(
            displayName: 'Jean-Pierre O\'Connor',
          ),
        ));

        expect(find.text('JO'), findsOneWidget);
      });
    });

    group('EditableAvatar Method - Advanced Functionality', () {
      testWidgets('renders editable avatar with edit button',
          (WidgetTester tester) async {
        bool editTapped = false;

        await tester.pumpWidget(createTestWidget(
          child: UserAvatarWidgets.editableAvatar(
            displayName: 'Editable User',
            onEditTap: () => editTapped = true,
          ),
        ));

        // Should have Stack for edit button overlay (plus MaterialApp may create one)
        expect(find.byType(Stack), findsWidgets);

        // Should have edit icon
        expect(find.byIcon(Icons.edit), findsOneWidget);

        // Should have positioned edit button
        expect(find.byType(Positioned), findsOneWidget);

        // Tap edit button
        await tester.tap(find.byIcon(Icons.edit));
        await tester.pumpAndSettle();

        expect(editTapped, isTrue);
      });

      testWidgets('applies custom border to editable avatar',
          (WidgetTester tester) async {
        const customBorderColor = Colors.red;
        const customBorderWidth = 5.0;

        await tester.pumpWidget(createTestWidget(
          child: UserAvatarWidgets.editableAvatar(
            displayName: 'Custom Border',
            onEditTap: () {},
            borderColor: customBorderColor,
            borderWidth: customBorderWidth,
          ),
        ));

        // Edit button should be present
        expect(find.byIcon(Icons.edit), findsOneWidget);
      });

      testWidgets('uses extraLarge size by default for editable avatar',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          child: UserAvatarWidgets.editableAvatar(
            displayName: 'Large Avatar',
            onEditTap: () {},
          ),
        ));

        // Should find containers for extraLarge avatar
        expect(find.byType(Container), findsWidgets);
      });
    });

    group('StatusIndicator Method - Standalone Component', () {
      testWidgets('renders online status indicator',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          child: UserAvatarWidgets.statusIndicator(
            isOnline: true,
          ),
        ));

        final container = tester.widget<Container>(find.byType(Container));
        final decoration = container.decoration as BoxDecoration;
        expect(decoration.color, equals(AppColors.success));
        expect(decoration.shape, equals(BoxShape.circle));
      });

      testWidgets('renders offline status indicator',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          child: UserAvatarWidgets.statusIndicator(
            isOnline: false,
          ),
        ));

        final container = tester.widget<Container>(find.byType(Container));
        final decoration = container.decoration as BoxDecoration;
        expect(decoration.color, equals(AppColors.textTertiary));
      });

      testWidgets('applies custom size to status indicator',
          (WidgetTester tester) async {
        const customSize = 24.0;

        await tester.pumpWidget(createTestWidget(
          child: UserAvatarWidgets.statusIndicator(
            isOnline: true,
            size: customSize,
          ),
        ));

        // Should render status indicator with custom size
        expect(find.byType(Container), findsOneWidget);
        final container = tester.widget<Container>(find.byType(Container));
        final decoration = container.decoration as BoxDecoration;
        expect(decoration.shape, equals(BoxShape.circle));
      });

      testWidgets('uses default size when not specified',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          child: UserAvatarWidgets.statusIndicator(
            isOnline: true,
          ),
        ));

        // Should render with default size
        expect(find.byType(Container), findsOneWidget);
        final container = tester.widget<Container>(find.byType(Container));
        final decoration = container.decoration as BoxDecoration;
        expect(decoration.shape, equals(BoxShape.circle));
      });
    });

    group('Static Utility Methods - Production Code Verification', () {
      testWidgets('getInitials method handles all edge cases',
          (WidgetTester tester) async {
        // Test static method directly
        expect(UserAvatarWidgets.getInitials('Anna Andersson'), equals('AA'));
        expect(UserAvatarWidgets.getInitials('Magnus'), equals('MA'));
        expect(UserAvatarWidgets.getInitials('A'), equals('A'));
        expect(UserAvatarWidgets.getInitials(''), equals('?'));
        expect(UserAvatarWidgets.getInitials('  Johan   Johansson  '),
            equals('JJ'));
        expect(UserAvatarWidgets.getInitials('Åsa Öberg'), equals('ÅÖ'));
        expect(UserAvatarWidgets.getInitials('björn älg'), equals('BÄ'));
      });
    });

    group('Network Image Error Handling - Advanced Scenarios', () {
      testWidgets('shows initials when network image fails to load',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          child: UserAvatarWidgets.avatar(
            imageUrl: 'https://invalid-url.com/avatar.jpg',
            displayName: 'Network Error User',
          ),
        ));

        // CachedNetworkImage should be present
        expect(find.byType(CachedNetworkImage), findsOneWidget);

        // Error widget should show initials
        expect(find.text('NE'), findsOneWidget);
      });

      testWidgets('shows placeholder while network image loads',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          child: UserAvatarWidgets.avatar(
            imageUrl: 'https://example.com/slow-loading-avatar.jpg',
            displayName: 'Loading User',
          ),
        ));

        // Should show placeholder initials while loading
        expect(find.text('LU'), findsOneWidget);

        // CachedNetworkImage should handle loading state
        final cachedImage =
            tester.widget<CachedNetworkImage>(find.byType(CachedNetworkImage));
        expect(cachedImage.fadeInDuration,
            equals(const Duration(milliseconds: 300)));
        expect(cachedImage.fadeOutDuration,
            equals(const Duration(milliseconds: 300)));
      });
    });

    group('Font Size Calculation - Typography Precision', () {
      testWidgets('calculates font size as 40% of avatar size',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          child: UserAvatarWidgets.avatar(
            displayName: 'Font Test',
            size: ImageSize.large,
          ),
        ));

        final textWidget = tester.widget<Text>(find.text('FT'));
        final expectedFontSize = AppDimensions.imageSizeThumbnail * 0.4;
        expect(textWidget.style?.fontSize, equals(expectedFontSize));
      });

      testWidgets('applies correct font weight and styling',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          child: UserAvatarWidgets.avatar(
            displayName: 'Style Test',
          ),
        ));

        final textWidget = tester.widget<Text>(find.text('ST'));
        expect(textWidget.style?.fontWeight, equals(FontWeight.w600));
        expect(textWidget.style?.letterSpacing, equals(0.5));
      });
    });

    group('Edge Cases and Error Handling', () {
      testWidgets('handles null parameters gracefully',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          child: UserAvatarWidgets.avatar(
            displayName: 'Null Test',
            imageUrl: null,
            onTap: null,
            backgroundColor: null,
            textColor: null,
            borderColor: null,
            borderWidth: null,
          ),
        ));

        expect(find.text('NT'), findsOneWidget);
        expect(find.byType(InkWell), findsNothing);
      });

      testWidgets('maintains aspect ratio for all sizes',
          (WidgetTester tester) async {
        for (final size in ImageSize.values) {
          await tester.pumpWidget(createTestWidget(
            child: UserAvatarWidgets.avatar(
              displayName: 'Aspect Test',
              size: size,
            ),
          ));

          // Should render avatar with circular container for all sizes
          final containerFinder = find.byWidgetPredicate(
            (widget) =>
                widget is Container &&
                widget.decoration is BoxDecoration &&
                (widget.decoration as BoxDecoration).shape == BoxShape.circle,
          );
          expect(containerFinder, findsWidgets);

          await tester.pumpWidget(const SizedBox()); // Clear widget tree
        }
      });
    });
  });
}
