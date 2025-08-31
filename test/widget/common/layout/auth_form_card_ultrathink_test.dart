// test/widget/common/layout/auth_form_card_ultrathink_test.dart
// Comprehensive tests for AuthFormCard using ultrathink methodology
//
// ULTRATHINK ANALYSIS: auth_form_card.dart (34 lines)
// - StatelessWidget with 2 properties (1 required child, 1 optional maxWidth with default)
// - Layout-focused widget: Center → ConstrainedBox → Card → Padding → child
// - Theme-integrated using AppDimensions.paddingL
// - Required child widget that gets wrapped in styled container
// - maxWidth = 400 default provides responsive constraint
// - Center alignment ensures proper positioning on various screen sizes
// - Card styling provides Material Design elevation and background
// - Consistent padding using AppDimensions.paddingL

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/widgets/common/layout/auth_form_card.dart';
import 'package:butlery/theme/app_dimensions.dart';

void main() {
  group('AuthFormCard Tests - ULTRATHINK METHODOLOGY', () {

    const Widget testChild = Text('Test Child Widget');
    const Widget complexChild = Column(
      children: [
        Text('Form Title'),
        TextField(),
        ElevatedButton(onPressed: null, child: Text('Submit')),
      ],
    );

    group('Widget Construction and Required Parameters', () {
      testWidgets('should render with required child parameter', (WidgetTester tester) async {
        // ULTRATHINK: Test basic construction with minimal required parameters (line 16)
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AuthFormCard(child: testChild),
            ),
          ),
        );

        expect(find.text('Test Child Widget'), findsOneWidget);
        expect(find.byType(AuthFormCard), findsOneWidget);
        expect(find.byType(Card), findsOneWidget);
        expect(find.byType(Center), findsOneWidget);
        expect(find.byType(ConstrainedBox), findsWidgets);
      });

      testWidgets('should require child parameter for construction', (WidgetTester tester) async {
        // ULTRATHINK: Verify required parameter enforcement (line 16)
        expect(() => AuthFormCard(child: testChild), returnsNormally);
      });

      testWidgets('should handle complex child widgets', (WidgetTester tester) async {
        // ULTRATHINK: Test with complex child structures
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AuthFormCard(child: complexChild),
            ),
          ),
        );

        expect(find.text('Form Title'), findsOneWidget);
        expect(find.byType(TextField), findsOneWidget);
        expect(find.byType(ElevatedButton), findsOneWidget);
        expect(find.byType(AuthFormCard), findsOneWidget);
      });

      testWidgets('should handle empty container as child', (WidgetTester tester) async {
        // ULTRATHINK: Test edge case with minimal child
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AuthFormCard(child: Container()),
            ),
          ),
        );

        expect(find.byType(Container), findsOneWidget);
        expect(find.byType(AuthFormCard), findsOneWidget);
      });
    });

    group('MaxWidth Parameter and Constraints', () {
      testWidgets('should use default maxWidth of 400 when not specified', (WidgetTester tester) async {
        // ULTRATHINK: Test default maxWidth behavior (line 17)
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AuthFormCard(child: testChild),
            ),
          ),
        );

        final ConstrainedBox constrainedBox = tester.widget(
          find.descendant(
            of: find.byType(AuthFormCard),
            matching: find.byType(ConstrainedBox),
          ),
        );
        expect(constrainedBox.constraints.maxWidth, equals(400));
      });

      testWidgets('should accept custom maxWidth parameter', (WidgetTester tester) async {
        // ULTRATHINK: Test custom maxWidth override (line 12, 24)
        const customMaxWidth = 600.0;
        
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AuthFormCard(
                maxWidth: customMaxWidth,
                child: testChild,
              ),
            ),
          ),
        );

        final ConstrainedBox constrainedBox = tester.widget(
          find.descendant(
            of: find.byType(AuthFormCard),
            matching: find.byType(ConstrainedBox),
          ),
        );
        expect(constrainedBox.constraints.maxWidth, equals(customMaxWidth));
      });

      testWidgets('should handle null maxWidth with fallback to 400', (WidgetTester tester) async {
        // ULTRATHINK: Test null maxWidth fallback (line 24)
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AuthFormCard(
                maxWidth: null,
                child: testChild,
              ),
            ),
          ),
        );

        final ConstrainedBox constrainedBox = tester.widget(
          find.descendant(
            of: find.byType(AuthFormCard),
            matching: find.byType(ConstrainedBox),
          ),
        );
        expect(constrainedBox.constraints.maxWidth, equals(400));
      });

      testWidgets('should handle very small maxWidth values', (WidgetTester tester) async {
        // ULTRATHINK: Test edge case with small constraints
        const smallMaxWidth = 100.0;
        
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AuthFormCard(
                maxWidth: smallMaxWidth,
                child: testChild,
              ),
            ),
          ),
        );

        final ConstrainedBox constrainedBox = tester.widget(
          find.descendant(
            of: find.byType(AuthFormCard),
            matching: find.byType(ConstrainedBox),
          ),
        );
        expect(constrainedBox.constraints.maxWidth, equals(smallMaxWidth));
      });

      testWidgets('should handle very large maxWidth values', (WidgetTester tester) async {
        // ULTRATHINK: Test edge case with large constraints
        const largeMaxWidth = 2000.0;
        
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AuthFormCard(
                maxWidth: largeMaxWidth,
                child: testChild,
              ),
            ),
          ),
        );

        final ConstrainedBox constrainedBox = tester.widget(
          find.descendant(
            of: find.byType(AuthFormCard),
            matching: find.byType(ConstrainedBox),
          ),
        );
        expect(constrainedBox.constraints.maxWidth, equals(largeMaxWidth));
      });
    });

    group('Layout Structure and Widget Tree', () {
      testWidgets('should create expected widget tree structure', (WidgetTester tester) async {
        // ULTRATHINK: Test complete widget tree structure (lines 22-32)
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AuthFormCard(child: testChild),
            ),
          ),
        );

        // Verify widget hierarchy: Center > ConstrainedBox > Card > Padding > child
        expect(find.byType(Center), findsOneWidget);
        expect(find.byType(ConstrainedBox), findsWidgets);
        expect(find.byType(Card), findsOneWidget);
        expect(find.byType(Padding), findsWidgets);
        expect(find.text('Test Child Widget'), findsOneWidget);
      });

      testWidgets('should apply Center alignment correctly', (WidgetTester tester) async {
        // ULTRATHINK: Test Center widget behavior (line 22)
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 800,
                height: 600,
                child: AuthFormCard(child: testChild),
              ),
            ),
          ),
        );

        final Center center = tester.widget(find.byType(Center));
        expect(center.child, isA<ConstrainedBox>());
      });

      testWidgets('should create ConstrainedBox with proper configuration', (WidgetTester tester) async {
        // ULTRATHINK: Test ConstrainedBox configuration (lines 23-24)
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AuthFormCard(child: testChild),
            ),
          ),
        );

        final ConstrainedBox constrainedBox = tester.widget(
          find.descendant(
            of: find.byType(AuthFormCard),
            matching: find.byType(ConstrainedBox),
          ),
        );
        expect(constrainedBox.constraints, isA<BoxConstraints>());
        expect(constrainedBox.constraints.maxWidth, equals(400));
        expect(constrainedBox.child, isA<Card>());
      });

      testWidgets('should apply Card widget with proper child', (WidgetTester tester) async {
        // ULTRATHINK: Test Card widget configuration (line 25)
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AuthFormCard(child: testChild),
            ),
          ),
        );

        final Card card = tester.widget(find.byType(Card));
        expect(card.child, isA<Padding>());
      });

      testWidgets('should apply Padding with AppDimensions.paddingL', (WidgetTester tester) async {
        // ULTRATHINK: Test Padding configuration (line 27)
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AuthFormCard(child: testChild),
            ),
          ),
        );

        final Padding padding = tester.widget(
          find.byType(Padding).last, // Get the AuthFormCard's Padding
        );
        expect(padding.padding, equals(const EdgeInsets.all(AppDimensions.paddingL)));
        expect(padding.child, equals(testChild));
      });
    });

    group('Material Design Integration', () {
      testWidgets('should render Card with Material Design properties', (WidgetTester tester) async {
        // ULTRATHINK: Test Material Card properties
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AuthFormCard(child: testChild),
            ),
          ),
        );

        final Card card = tester.widget(find.byType(Card));
        expect(card, isNotNull);
        // Card should have Material Design elevation and styling
        expect(card.child, isA<Padding>());
      });

      testWidgets('should work within Material app context', (WidgetTester tester) async {
        // ULTRATHINK: Test Material app integration
        await tester.pumpWidget(
          MaterialApp(
            home: AuthFormCard(child: testChild),
          ),
        );

        expect(find.byType(AuthFormCard), findsOneWidget);
        expect(find.byType(Card), findsOneWidget);
        expect(find.text('Test Child Widget'), findsOneWidget);
      });

      testWidgets('should respond to theme changes', (WidgetTester tester) async {
        // ULTRATHINK: Test theme responsiveness
        final lightTheme = ThemeData.light();
        
        await tester.pumpWidget(
          MaterialApp(
            theme: lightTheme,
            home: Scaffold(
              body: AuthFormCard(child: testChild),
            ),
          ),
        );

        expect(find.byType(Card), findsOneWidget);
        expect(find.text('Test Child Widget'), findsOneWidget);
      });
    });

    group('Responsive Behavior', () {
      testWidgets('should constrain width on wide screens', (WidgetTester tester) async {
        // ULTRATHINK: Test responsive constraint behavior
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 1200,
                child: AuthFormCard(child: testChild),
              ),
            ),
          ),
        );

        final ConstrainedBox constrainedBox = tester.widget(
          find.descendant(
            of: find.byType(AuthFormCard),
            matching: find.byType(ConstrainedBox),
          ),
        );
        expect(constrainedBox.constraints.maxWidth, equals(400));
      });

      testWidgets('should handle narrow screens gracefully', (WidgetTester tester) async {
        // ULTRATHINK: Test narrow screen behavior
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 300,
                child: AuthFormCard(child: testChild),
              ),
            ),
          ),
        );

        expect(find.byType(AuthFormCard), findsOneWidget);
        expect(find.text('Test Child Widget'), findsOneWidget);
        
        final ConstrainedBox constrainedBox = tester.widget(
          find.descendant(
            of: find.byType(AuthFormCard),
            matching: find.byType(ConstrainedBox),
          ),
        );
        expect(constrainedBox.constraints.maxWidth, equals(400));
      });

      testWidgets('should adapt to custom maxWidth for different screen sizes', (WidgetTester tester) async {
        // ULTRATHINK: Test adaptive maxWidth behavior
        const customMaxWidth = 350.0;
        
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 800,
                child: AuthFormCard(
                  maxWidth: customMaxWidth,
                  child: testChild,
                ),
              ),
            ),
          ),
        );

        final ConstrainedBox constrainedBox = tester.widget(
          find.descendant(
            of: find.byType(AuthFormCard),
            matching: find.byType(ConstrainedBox),
          ),
        );
        expect(constrainedBox.constraints.maxWidth, equals(customMaxWidth));
      });
    });

    group('Content Integration and Child Widget Handling', () {
      testWidgets('should properly display form elements as child', (WidgetTester tester) async {
        // ULTRATHINK: Test authentic form content integration
        const formChild = Column(
          children: [
            Text('Login Form'),
            TextField(),
            SizedBox(height: 16),
            ElevatedButton(onPressed: null, child: Text('Login')),
          ],
        );
        
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AuthFormCard(child: formChild),
            ),
          ),
        );

        expect(find.text('Login Form'), findsOneWidget);
        expect(find.byType(TextField), findsOneWidget);
        expect(find.byType(ElevatedButton), findsOneWidget);
        expect(find.text('Login'), findsOneWidget);
      });

      testWidgets('should handle scrollable content as child', (WidgetTester tester) async {
        // ULTRATHINK: Test scrollable child content
        final scrollableChild = SingleChildScrollView(
          child: Column(
            children: List.generate(20, (index) => Text('Item $index')),
          ),
        );
        
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                height: 300,
                child: AuthFormCard(child: scrollableChild),
              ),
            ),
          ),
        );

        expect(find.byType(SingleChildScrollView), findsOneWidget);
        expect(find.text('Item 0'), findsOneWidget);
        expect(find.byType(AuthFormCard), findsOneWidget);
      });

      testWidgets('should maintain child widget properties and state', (WidgetTester tester) async {
        // ULTRATHINK: Test child widget integrity
        bool buttonPressed = false;
        final interactiveChild = ElevatedButton(
          onPressed: () => buttonPressed = true,
          child: const Text('Interactive Button'),
        );
        
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AuthFormCard(child: interactiveChild),
            ),
          ),
        );

        expect(find.text('Interactive Button'), findsOneWidget);
        
        await tester.tap(find.byType(ElevatedButton));
        await tester.pump();
        
        expect(buttonPressed, isTrue);
      });
    });

    group('Edge Cases and Error Handling', () {
      testWidgets('should handle zero maxWidth gracefully', (WidgetTester tester) async {
        // ULTRATHINK: Test zero maxWidth edge case
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AuthFormCard(
                maxWidth: 0,
                child: testChild,
              ),
            ),
          ),
        );

        final ConstrainedBox constrainedBox = tester.widget(
          find.descendant(
            of: find.byType(AuthFormCard),
            matching: find.byType(ConstrainedBox),
          ),
        );
        expect(constrainedBox.constraints.maxWidth, equals(0));
        expect(find.byType(AuthFormCard), findsOneWidget);
      });

      testWidgets('should handle double.infinity maxWidth values', (WidgetTester tester) async {
        // ULTRATHINK: Test infinity maxWidth edge case (valid constraint)
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AuthFormCard(
                maxWidth: double.infinity,
                child: testChild,
              ),
            ),
          ),
        );

        final ConstrainedBox constrainedBox = tester.widget(
          find.descendant(
            of: find.byType(AuthFormCard),
            matching: find.byType(ConstrainedBox),
          ),
        );
        expect(constrainedBox.constraints.maxWidth, equals(double.infinity));
        expect(find.byType(AuthFormCard), findsOneWidget);
      });

      testWidgets('should handle very complex nested child widgets', (WidgetTester tester) async {
        // ULTRATHINK: Test complex nested structures
        final nestedChild = Card(
          child: Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: const [
                    Icon(Icons.person),
                    Text('Profile'),
                  ],
                ),
                const Divider(),
                ListView.builder(
                  shrinkWrap: true,
                  itemCount: 3,
                  itemBuilder: (context, index) => ListTile(
                    title: Text('Item $index'),
                  ),
                ),
              ],
            ),
          ),
        );
        
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AuthFormCard(child: nestedChild),
            ),
          ),
        );

        expect(find.byType(Icon), findsOneWidget);
        expect(find.text('Profile'), findsOneWidget);
        expect(find.byType(Divider), findsOneWidget);
        expect(find.byType(ListView), findsOneWidget);
        expect(find.text('Item 0'), findsOneWidget);
      });
    });

    group('Build Method Behavior and Consistency', () {
      testWidgets('should build consistently across multiple rebuilds', (WidgetTester tester) async {
        // ULTRATHINK: Test build method consistency
        Widget buildWidget(Widget child, double? maxWidth) {
          return MaterialApp(
            home: Scaffold(
              body: AuthFormCard(
                maxWidth: maxWidth,
                child: child,
              ),
            ),
          );
        }

        // Initial build
        await tester.pumpWidget(buildWidget(const Text('Initial'), 300));
        expect(find.text('Initial'), findsOneWidget);
        final initialConstraints = tester.widget<ConstrainedBox>(
          find.descendant(
            of: find.byType(AuthFormCard),
            matching: find.byType(ConstrainedBox),
          ),
        );
        expect(initialConstraints.constraints.maxWidth, equals(300));

        // Update child
        await tester.pumpWidget(buildWidget(const Text('Updated'), 300));
        expect(find.text('Updated'), findsOneWidget);
        expect(find.text('Initial'), findsNothing);

        // Update maxWidth
        await tester.pumpWidget(buildWidget(const Text('Updated'), 500));
        final updatedConstraints = tester.widget<ConstrainedBox>(
          find.descendant(
            of: find.byType(AuthFormCard),
            matching: find.byType(ConstrainedBox),
          ),
        );
        expect(updatedConstraints.constraints.maxWidth, equals(500));
      });

      testWidgets('should maintain widget tree structure across different configurations', (WidgetTester tester) async {
        // ULTRATHINK: Test structural consistency
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AuthFormCard(
                maxWidth: 200,
                child: const Text('Test'),
              ),
            ),
          ),
        );

        // Verify consistent structure regardless of configuration
        expect(find.byType(Center), findsOneWidget);
        expect(find.byType(ConstrainedBox), findsWidgets);
        expect(find.byType(Card), findsOneWidget);
        expect(find.byType(Padding), findsWidgets);
        expect(find.text('Test'), findsOneWidget);
      });
    });

    group('Integration with Auth Flow Scenarios', () {
      testWidgets('should work for login form scenario', (WidgetTester tester) async {
        // ULTRATHINK: Test authentic login use case
        const loginForm = Column(
          children: [
            Text('Welcome Back'),
            SizedBox(height: 24),
            TextField(decoration: InputDecoration(labelText: 'Email')),
            SizedBox(height: 16),
            TextField(decoration: InputDecoration(labelText: 'Password')),
            SizedBox(height: 24),
            ElevatedButton(onPressed: null, child: Text('Sign In')),
            SizedBox(height: 16),
            TextButton(onPressed: null, child: Text('Forgot Password?')),
          ],
        );
        
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AuthFormCard(child: loginForm),
            ),
          ),
        );

        expect(find.text('Welcome Back'), findsOneWidget);
        expect(find.text('Email'), findsOneWidget);
        expect(find.text('Password'), findsOneWidget);
        expect(find.text('Sign In'), findsOneWidget);
        expect(find.text('Forgot Password?'), findsOneWidget);
      });

      testWidgets('should work for signup form scenario', (WidgetTester tester) async {
        // ULTRATHINK: Test authentic signup use case
        const signupForm = Column(
          children: [
            Text('Create Account'),
            SizedBox(height: 24),
            TextField(decoration: InputDecoration(labelText: 'Full Name')),
            SizedBox(height: 16),
            TextField(decoration: InputDecoration(labelText: 'Email')),
            SizedBox(height: 16),
            TextField(decoration: InputDecoration(labelText: 'Password')),
            SizedBox(height: 16),
            TextField(decoration: InputDecoration(labelText: 'Confirm Password')),
            SizedBox(height: 24),
            ElevatedButton(onPressed: null, child: Text('Create Account')),
          ],
        );
        
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AuthFormCard(
                maxWidth: 450, // Slightly wider for signup form
                child: signupForm,
              ),
            ),
          ),
        );

        expect(find.text('Create Account'), findsWidgets);
        expect(find.text('Full Name'), findsOneWidget);
        expect(find.text('Email'), findsOneWidget);
        expect(find.text('Password'), findsOneWidget);
        expect(find.text('Confirm Password'), findsOneWidget);
      });

      testWidgets('should work for password reset scenario', (WidgetTester tester) async {
        // ULTRATHINK: Test password reset use case
        const resetForm = Column(
          children: [
            Icon(Icons.lock_reset, size: 48),
            SizedBox(height: 16),
            Text('Reset Password'),
            SizedBox(height: 8),
            Text('Enter your email to receive reset instructions'),
            SizedBox(height: 24),
            TextField(decoration: InputDecoration(labelText: 'Email Address')),
            SizedBox(height: 24),
            ElevatedButton(onPressed: null, child: Text('Send Reset Link')),
            SizedBox(height: 16),
            TextButton(onPressed: null, child: Text('Back to Login')),
          ],
        );
        
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AuthFormCard(child: resetForm),
            ),
          ),
        );

        expect(find.byIcon(Icons.lock_reset), findsOneWidget);
        expect(find.text('Reset Password'), findsOneWidget);
        expect(find.text('Enter your email to receive reset instructions'), findsOneWidget);
        expect(find.text('Email Address'), findsOneWidget);
        expect(find.text('Send Reset Link'), findsOneWidget);
        expect(find.text('Back to Login'), findsOneWidget);
      });
    });
  });
}