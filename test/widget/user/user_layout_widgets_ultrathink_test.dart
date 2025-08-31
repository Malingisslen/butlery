// test/widget/user/user_layout_widgets_ultrathink_test.dart
// Comprehensive tests for UserLayoutWidgets using ultrathink methodology
// 
// ULTRATHINK ANALYSIS: UserLayoutWidgets static utility class (173 lines)
// - 5 static factory methods for user display layouts
// - Text components: userName, userEmail with AppTextStyles integration  
// - Layout components: userInfo (Column), userRow (InkWell>Row), userCard (Card>Column)
// - Dependency delegation to UserAvatarWidgets.avatar() 
// - Conditional rendering based on nullable parameters
// - Consistent spacing/styling via AppDimensions/AppTextStyles constants

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/widgets/user/user_layout_widgets.dart';
import 'package:butlery/widgets/user/user_display_models.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/app_dimensions.dart';

void main() {
  group('UserLayoutWidgets Static Utility Tests - ULTRATHINK METHODOLOGY', () {
    // Helper to create test environment for widget testing
    Widget createTestWidget(Widget child) {
      return MaterialApp(
        theme: ThemeData(
          colorScheme: const ColorScheme.light(
            primary: Colors.blue,
            surface: Colors.white,
            onSurface: Colors.black,
            secondary: Colors.orange,
          ),
          textTheme: const TextTheme(
            titleMedium: TextStyle(fontSize: 16, color: Colors.black),
            bodySmall: TextStyle(fontSize: 12, color: Colors.grey),
            bodyLarge: TextStyle(fontSize: 14, color: Colors.black87),
          ),
        ),
        home: Scaffold(
          body: SizedBox(
            height: 600,
            width: 400,
            child: child,
          ),
        ),
      );
    }

    group('userName() - Text Widget Tests (lines 13-24)', () {
      testWidgets('should create Text widget with displayName and default styling', (WidgetTester tester) async {
        // ULTRATHINK: Test core functionality - Text widget with AppTextStyles.titleMedium default
        await tester.pumpWidget(createTestWidget(
          UserLayoutWidgets.userName(displayName: 'Anna Lindberg'),
        ));

        final textWidget = tester.widget<Text>(find.byType(Text));
        expect(textWidget.data, equals('Anna Lindberg'));
        expect(textWidget.style, equals(AppTextStyles.titleMedium));
        expect(textWidget.overflow, equals(TextOverflow.ellipsis));
        expect(textWidget.maxLines, isNull);
      });

      testWidgets('should apply custom style when provided', (WidgetTester tester) async {
        const customStyle = TextStyle(fontSize: 20, color: Colors.red);
        
        await tester.pumpWidget(createTestWidget(
          UserLayoutWidgets.userName(
            displayName: 'Erik Johansson', 
            style: customStyle,
          ),
        ));

        final textWidget = tester.widget<Text>(find.byType(Text));
        expect(textWidget.style, equals(customStyle));
      });

      testWidgets('should apply custom maxLines and overflow when provided', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          UserLayoutWidgets.userName(
            displayName: 'Sofia Andersson', 
            maxLines: 2,
            overflow: TextOverflow.fade,
          ),
        ));

        final textWidget = tester.widget<Text>(find.byType(Text));
        expect(textWidget.maxLines, equals(2));
        expect(textWidget.overflow, equals(TextOverflow.fade));
      });

      testWidgets('should handle Swedish characters correctly', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          UserLayoutWidgets.userName(displayName: 'Åke Öström'),
        ));

        expect(find.text('Åke Öström'), findsOneWidget);
      });

      testWidgets('should handle empty displayName', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          UserLayoutWidgets.userName(displayName: ''),
        ));

        final textWidget = tester.widget<Text>(find.byType(Text));
        expect(textWidget.data, equals(''));
      });

      testWidgets('should handle very long displayName with ellipsis', (WidgetTester tester) async {
        const longName = 'Anna Sofia Margareta Elisabeth Kristina Johansson-Andersson';
        
        await tester.pumpWidget(createTestWidget(
          UserLayoutWidgets.userName(displayName: longName),
        ));

        final textWidget = tester.widget<Text>(find.byType(Text));
        expect(textWidget.data, equals(longName));
        expect(textWidget.overflow, equals(TextOverflow.ellipsis));
      });
    });

    group('userEmail() - Text Widget Tests (lines 27-38)', () {
      testWidgets('should create Text widget with email and default styling', (WidgetTester tester) async {
        // ULTRATHINK: Same structure as userName but for email addresses
        await tester.pumpWidget(createTestWidget(
          UserLayoutWidgets.userEmail(email: 'anna@example.se'),
        ));

        final textWidget = tester.widget<Text>(find.byType(Text));
        expect(textWidget.data, equals('anna@example.se'));
        expect(textWidget.style, equals(AppTextStyles.titleMedium));
        expect(textWidget.overflow, equals(TextOverflow.ellipsis));
        expect(textWidget.maxLines, isNull);
      });

      testWidgets('should apply custom style when provided', (WidgetTester tester) async {
        const customStyle = TextStyle(fontSize: 14, color: Colors.blue);
        
        await tester.pumpWidget(createTestWidget(
          UserLayoutWidgets.userEmail(
            email: 'erik@butlery.se', 
            style: customStyle,
          ),
        ));

        final textWidget = tester.widget<Text>(find.byType(Text));
        expect(textWidget.style, equals(customStyle));
      });

      testWidgets('should handle Swedish domain names', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          UserLayoutWidgets.userEmail(email: 'sofia@företag.se'),
        ));

        expect(find.text('sofia@företag.se'), findsOneWidget);
      });

      testWidgets('should handle very long email with ellipsis', (WidgetTester tester) async {
        const longEmail = 'anna.sofia.margareta.johansson@very-long-company-name-example.com';
        
        await tester.pumpWidget(createTestWidget(
          UserLayoutWidgets.userEmail(email: longEmail),
        ));

        final textWidget = tester.widget<Text>(find.byType(Text));
        expect(textWidget.data, equals(longEmail));
        expect(textWidget.overflow, equals(TextOverflow.ellipsis));
      });
    });

    group('userInfo() - Column Layout Tests (lines 41-58)', () {
      testWidgets('should create Column with displayName only when email is null', (WidgetTester tester) async {
        // ULTRATHINK: Test conditional rendering - email null case (lines 52-55)
        await tester.pumpWidget(createTestWidget(
          UserLayoutWidgets.userInfo(displayName: 'Anna Lindberg'),
        ));

        expect(find.byType(Column), findsOneWidget);
        expect(find.text('Anna Lindberg'), findsOneWidget);
        expect(find.byType(Text), findsOneWidget); // Only name, no email
        // Check no spacing SizedBox inside the userInfo widget (only test container exists)
        expect(find.byType(SizedBox), findsOneWidget); // Only test environment SizedBox
      });

      testWidgets('should create Column with displayName and email when email provided', (WidgetTester tester) async {
        // ULTRATHINK: Test conditional rendering - email present case (lines 52-55)
        await tester.pumpWidget(createTestWidget(
          UserLayoutWidgets.userInfo(
            displayName: 'Erik Johansson',
            email: 'erik@example.se',
          ),
        ));

        expect(find.byType(Column), findsOneWidget);
        expect(find.text('Erik Johansson'), findsOneWidget);
        expect(find.text('erik@example.se'), findsOneWidget);
        expect(find.byType(Text), findsNWidgets(2)); // Name and email
        expect(find.byType(SizedBox), findsNWidgets(2)); // Test environment SizedBox + spacing SizedBox
      });

      testWidgets('should apply custom CrossAxisAlignment', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          UserLayoutWidgets.userInfo(
            displayName: 'Sofia Andersson',
            alignment: CrossAxisAlignment.center,
          ),
        ));

        final column = tester.widget<Column>(find.byType(Column));
        expect(column.crossAxisAlignment, equals(CrossAxisAlignment.center));
      });

      testWidgets('should apply custom styles to name and email', (WidgetTester tester) async {
        const nameStyle = TextStyle(fontSize: 18, color: Colors.red);
        const emailStyle = TextStyle(fontSize: 14, color: Colors.blue);
        
        await tester.pumpWidget(createTestWidget(
          UserLayoutWidgets.userInfo(
            displayName: 'Lars Nilsson',
            email: 'lars@example.se',
            nameStyle: nameStyle,
            emailStyle: emailStyle,
          ),
        ));

        final textWidgets = tester.widgetList<Text>(find.byType(Text)).toList();
        expect(textWidgets[0].style, equals(nameStyle)); // Name style
        expect(textWidgets[1].style, equals(emailStyle)); // Email style
      });

      testWidgets('should use AppDimensions.spacingXs for spacing between name and email', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          UserLayoutWidgets.userInfo(
            displayName: 'Astrid Berg',
            email: 'astrid@example.se',
          ),
        ));

        final sizedBoxes = tester.widgetList<SizedBox>(find.byType(SizedBox)).toList();
        // Find the spacing SizedBox (not the test container)
        final spacingSizedBox = sizedBoxes.firstWhere(
          (box) => box.height == AppDimensions.spacingXs,
          orElse: () => throw StateError('Spacing SizedBox not found'),
        );
        expect(spacingSizedBox.height, equals(AppDimensions.spacingXs));
      });
    });

    group('userRow() - InkWell Row Layout Tests (lines 61-112)', () {
      testWidgets('should create InkWell with Row layout containing avatar and user info', (WidgetTester tester) async {
        // ULTRATHINK: Test core structure - InkWell > Padding > Row (lines 73-111)
        await tester.pumpWidget(createTestWidget(
          UserLayoutWidgets.userRow(
            imageUrl: 'https://example.com/avatar.jpg',
            displayName: 'Anna Svensson',
          ),
        ));

        expect(find.byType(InkWell), findsOneWidget);
        expect(find.byType(Row), findsOneWidget);
        expect(find.byType(Padding), findsAtLeastNWidgets(1));
        
        // Check avatar delegation to UserAvatarWidgets
        expect(find.text('AS'), findsOneWidget); // Avatar initials
        expect(find.text('Anna Svensson'), findsOneWidget);
      });

      testWidgets('should apply onTap callback to InkWell', (WidgetTester tester) async {
        bool tapped = false;
        
        await tester.pumpWidget(createTestWidget(
          UserLayoutWidgets.userRow(
            displayName: 'Erik Johansson',
            onTap: () => tapped = true,
          ),
        ));

        await tester.tap(find.byType(InkWell));
        expect(tapped, isTrue);
      });

      testWidgets('should use AppDimensions constants for spacing and padding', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          UserLayoutWidgets.userRow(displayName: 'Sofia Andersson'),
        ));

        final paddings = tester.widgetList<Padding>(find.byType(Padding)).toList();
        // Find the main content padding (not other paddings)
        final mainPadding = paddings.firstWhere(
          (p) => p.padding == const EdgeInsets.all(AppDimensions.paddingL),
          orElse: () => throw StateError('Main padding not found'),
        );
        expect(mainPadding.padding, equals(const EdgeInsets.all(AppDimensions.paddingL)));

        final spacingBoxes = tester.widgetList<SizedBox>(find.byType(SizedBox)).toList();
        final rowSpacing = spacingBoxes.firstWhere((box) => box.width == AppDimensions.spacingM);
        expect(rowSpacing.width, equals(AppDimensions.spacingM));
      });

      testWidgets('should show email when provided', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          UserLayoutWidgets.userRow(
            displayName: 'Lars Nilsson',
            email: 'lars@example.se',
          ),
        ));

        expect(find.text('Lars Nilsson'), findsOneWidget);
        expect(find.text('lars@example.se'), findsOneWidget);
      });

      testWidgets('should show subtitle when provided', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          UserLayoutWidgets.userRow(
            displayName: 'Astrid Berg',
            subtitle: 'Projektledare',
          ),
        ));

        expect(find.text('Astrid Berg'), findsOneWidget);
        expect(find.text('Projektledare'), findsOneWidget);
      });

      testWidgets('should show trailing widget when provided', (WidgetTester tester) async {
        const trailingWidget = Icon(Icons.arrow_forward);
        
        await tester.pumpWidget(createTestWidget(
          UserLayoutWidgets.userRow(
            displayName: 'Gunnar Holm',
            trailing: trailingWidget,
          ),
        ));

        expect(find.byType(Icon), findsOneWidget);
        expect(find.byIcon(Icons.arrow_forward), findsOneWidget);
      });

      testWidgets('should pass avatar parameters to UserAvatarWidgets.avatar', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          UserLayoutWidgets.userRow(
            imageUrl: 'https://example.com/avatar.jpg',
            displayName: 'Nils Petersson',
            avatarSize: ImageSize.large,
            showStatus: true,
            isOnline: true,
          ),
        ));

        // Verify avatar widget exists (UserAvatarWidgets creates initials)
        expect(find.text('NP'), findsOneWidget); // Initials for Nils Petersson
      });

      testWidgets('should apply custom padding when provided', (WidgetTester tester) async {
        const customPadding = EdgeInsets.all(20);
        
        await tester.pumpWidget(createTestWidget(
          UserLayoutWidgets.userRow(
            displayName: 'Birgit Svensson',
            padding: customPadding,
          ),
        ));

        final paddings = tester.widgetList<Padding>(find.byType(Padding)).toList();
        // Find the custom padding (should be 20px all around)
        final customPaddingWidget = paddings.firstWhere(
          (p) => p.padding == customPadding,
          orElse: () => throw StateError('Custom padding not found'),
        );
        expect(customPaddingWidget.padding, equals(customPadding));
      });

      testWidgets('should use borderRadius from AppDimensions.borderRadiusM for InkWell', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          UserLayoutWidgets.userRow(displayName: 'Carl Lindqvist'),
        ));

        final inkWell = tester.widget<InkWell>(find.byType(InkWell));
        final borderRadius = inkWell.borderRadius;
        expect(borderRadius?.topLeft.x, equals(AppDimensions.borderRadiusM));
      });
    });

    group('userCard() - Card Layout Tests (lines 115-172)', () {
      testWidgets('should create Card with InkWell and Column layout', (WidgetTester tester) async {
        // ULTRATHINK: Test core structure - Card > InkWell > Padding > Column (lines 129-170)
        await tester.pumpWidget(createTestWidget(
          UserLayoutWidgets.userCard(displayName: 'Anna Karlsson'),
        ));

        expect(find.byType(Card), findsOneWidget);
        expect(find.byType(InkWell), findsOneWidget);
        expect(find.byType(Column), findsAtLeastNWidgets(1)); // May have nested Columns from userInfo
        expect(find.text('Anna Karlsson'), findsOneWidget);
      });

      testWidgets('should apply Card styling with AppDimensions constants', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          UserLayoutWidgets.userCard(displayName: 'Erik Sundberg'),
        ));

        final card = tester.widget<Card>(find.byType(Card));
        expect(card.margin, equals(const EdgeInsets.all(AppDimensions.paddingL)));
        expect(card.elevation, equals(AppDimensions.elevationLow));
        
        final shape = card.shape as RoundedRectangleBorder;
        expect(shape.borderRadius, equals(BorderRadius.circular(AppDimensions.borderRadiusL)));
      });

      testWidgets('should create Row with avatar and userInfo in first section', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          UserLayoutWidgets.userCard(
            displayName: 'Sofia Engström',
            email: 'sofia@example.se',
          ),
        ));

        expect(find.byType(Row), findsOneWidget);
        expect(find.text('SE'), findsOneWidget); // Avatar initials  
        expect(find.text('Sofia Engström'), findsOneWidget);
        expect(find.text('sofia@example.se'), findsOneWidget);
      });

      testWidgets('should show subtitle with AppTextStyles.titleMedium when provided', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          UserLayoutWidgets.userCard(
            displayName: 'Lars Forsberg',
            subtitle: 'Senior utvecklare',
          ),
        ));

        expect(find.text('Senior utvecklare'), findsOneWidget);
        
        final subtitleTexts = tester.widgetList<Text>(find.byType(Text));
        final subtitleWidget = subtitleTexts.firstWhere(
          (text) => text.data == 'Senior utvecklare',
          orElse: () => throw StateError('Subtitle text not found'),
        );
        expect(subtitleWidget.style, equals(AppTextStyles.titleMedium));
      });

      testWidgets('should show description with AppTextStyles.bodyLarge when provided', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          UserLayoutWidgets.userCard(
            displayName: 'Astrid Blomberg',
            description: 'Specialist inom användarupplevelse och gränssnittsdesign.',
          ),
        ));

        expect(find.text('Specialist inom användarupplevelse och gränssnittsdesign.'), findsOneWidget);
        
        final descriptionTexts = tester.widgetList<Text>(find.byType(Text));
        final descriptionWidget = descriptionTexts.firstWhere(
          (text) => text.data == 'Specialist inom användarupplevelse och gränssnittsdesign.',
          orElse: () => throw StateError('Description text not found'),
        );
        expect(descriptionWidget.style, equals(AppTextStyles.bodyLarge));
      });

      testWidgets('should show actions widget when provided', (WidgetTester tester) async {
        const actionsWidget = Row(
          children: [
            Icon(Icons.edit),
            SizedBox(width: 8),
            Icon(Icons.delete),
          ],
        );
        
        await tester.pumpWidget(createTestWidget(
          UserLayoutWidgets.userCard(
            displayName: 'Gunnar Hedström',
            actions: actionsWidget,
          ),
        ));

        expect(find.byIcon(Icons.edit), findsOneWidget);
        expect(find.byIcon(Icons.delete), findsOneWidget);
      });

      testWidgets('should apply onTap callback to InkWell', (WidgetTester tester) async {
        bool tapped = false;
        
        await tester.pumpWidget(createTestWidget(
          UserLayoutWidgets.userCard(
            displayName: 'Nils Andersen',
            onTap: () => tapped = true,
          ),
        ));

        await tester.tap(find.byType(InkWell));
        expect(tapped, isTrue);
      });

      testWidgets('should pass avatar parameters to UserAvatarWidgets.avatar', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          UserLayoutWidgets.userCard(
            imageUrl: 'https://example.com/avatar.jpg',
            displayName: 'Birgit Lundgren',
            avatarSize: ImageSize.large,
            showStatus: true,
            isOnline: false,
          ),
        ));

        expect(find.text('BL'), findsOneWidget); // Avatar initials
      });

      testWidgets('should apply custom margin and padding when provided', (WidgetTester tester) async {
        const customMargin = EdgeInsets.all(16);
        const customPadding = EdgeInsets.all(24);
        
        await tester.pumpWidget(createTestWidget(
          UserLayoutWidgets.userCard(
            displayName: 'Carl Nordström',
            margin: customMargin,
            padding: customPadding,
          ),
        ));

        final card = tester.widget<Card>(find.byType(Card));
        expect(card.margin, equals(customMargin));

        final paddings = tester.widgetList<Padding>(find.byType(Padding)).toList();
        // Find the custom padding (should be 24px all around)
        final customPaddingWidget = paddings.firstWhere(
          (p) => p.padding == customPadding,
          orElse: () => throw StateError('Custom padding not found'),
        );
        expect(customPaddingWidget.padding, equals(customPadding));
      });

      testWidgets('should use correct spacing between sections', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          UserLayoutWidgets.userCard(
            displayName: 'Margareta Ström',
            subtitle: 'Administratör',
            description: 'Ansvarar för användarhantering.',
            actions: const Icon(Icons.settings),
          ),
        ));

        final spacingBoxes = tester.widgetList<SizedBox>(find.byType(SizedBox)).toList();
        
        // Find spacing elements
        final mediumSpacings = spacingBoxes.where((box) => box.height == AppDimensions.spacingM);
        final xlSpacings = spacingBoxes.where((box) => box.height == AppDimensions.spacingXl);
        
        expect(mediumSpacings.length, greaterThan(0)); // Between subtitle and description
        expect(xlSpacings.length, greaterThan(0)); // Before actions
      });
    });

    group('Edge Cases and Integration Tests', () {
      testWidgets('should handle null imageUrl in userRow and userCard', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          Column(
            children: [
              UserLayoutWidgets.userRow(displayName: 'Anna Nilsson'),
              UserLayoutWidgets.userCard(displayName: 'Erik Svensson'),
            ],
          ),
        ));

        expect(find.text('AN'), findsOneWidget); // userRow avatar initials
        expect(find.text('ES'), findsOneWidget); // userCard avatar initials
      });

      testWidgets('should handle special characters in all text fields', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          UserLayoutWidgets.userCard(
            displayName: 'Åsa Öhrström',
            email: 'åsa@företag.se',
            subtitle: 'VD & grundare',
            description: 'Specialist på åäö-hantering!',
          ),
        ));

        expect(find.text('Åsa Öhrström'), findsOneWidget);
        expect(find.text('åsa@företag.se'), findsOneWidget);
        expect(find.text('VD & grundare'), findsOneWidget);
        expect(find.text('Specialist på åäö-hantering!'), findsOneWidget);
      });

      testWidgets('should render in constrained layouts without overflow', (WidgetTester tester) async {
        await tester.pumpWidget(MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 200, // Very narrow constraint
              height: 400,
              child: ListView(
                children: [
                  UserLayoutWidgets.userRow(
                    displayName: 'Very Long Display Name That Should Be Truncated',
                    email: 'very.long.email.address@extremely-long-domain-name.se',
                  ),
                  UserLayoutWidgets.userCard(
                    displayName: 'Another Long Name',
                    description: 'A very long description that should wrap or truncate properly in narrow layouts.',
                  ),
                ],
              ),
            ),
          ),
        ));

        await tester.pumpAndSettle();
        
        // Should not throw overflow errors
        expect(tester.takeException(), isNull);
      });

      testWidgets('should work with all ImageSize values', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          Column(
            children: [
              UserLayoutWidgets.userRow(
                displayName: 'Small Avatar',
                avatarSize: ImageSize.small,
              ),
              UserLayoutWidgets.userRow(
                displayName: 'Medium Avatar',
                avatarSize: ImageSize.medium,
              ),
              UserLayoutWidgets.userRow(
                displayName: 'Large Avatar',
                avatarSize: ImageSize.large,
              ),
            ],
          ),
        ));

        expect(find.text('SA'), findsOneWidget);
        expect(find.text('MA'), findsOneWidget);  
        expect(find.text('LA'), findsOneWidget);
      });
    });
  });
}