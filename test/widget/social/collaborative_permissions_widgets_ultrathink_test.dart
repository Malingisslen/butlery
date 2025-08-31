// test/widget/social/collaborative_permissions_widgets_ultrathink_test.dart
// ULTRATHINK TEST SUITE: CollaborativePermissionsWidgets - 69 lines of production code
// Testing 2 static methods for collaborative permissions UI components
// 
// ULTRATHINK FOCUS: EditMode integration, ViewModel pattern, banner styling, responsiveness

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

// Production imports - NEVER assume, always check production code first
import 'package:butlery/widgets/social/collaborative/components/collaborative_permissions_widgets.dart';
import 'package:butlery/models/permissions/edit_mode.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/widgets/permissions/edit_mode_ui_helper.dart';

// Test infrastructure imports - using centralized system
import '../../infrastructure/di/test_service_locator.dart';
import '../../infrastructure/helpers/base_widget_test.dart';
import '../../infrastructure/mocks/widget_mocks.dart';

void main() {
  group('CollaborativePermissionsWidgets Ultrathink Tests', () {
    setUpAll(() async {
      await BaseWidgetTest.setupWidget();
    });

    setUp(() async {
      await TestServiceLocator.initialize();
    });
    
    tearDown(() async {
      await BaseWidgetTest.teardownWidget();
    });

    // Helper to create test environment
    Widget createTestWidget({Widget? child}) {
      return BaseWidgetTest.createTestApp(
        locale: const Locale('en', 'US'),
        child: Scaffold(
          body: child ?? const SizedBox.shrink(),
        ),
      );
    }

    // Helper to get BuildContext from rendered widget
    BuildContext getContext(WidgetTester tester) {
      return tester.element(find.byType(Scaffold));
    }

    // Helper to create test widget with CollaborativePermissionsWidgets method
    Future<void> pumpPermissionsWidget(
      WidgetTester tester,
      Widget Function(BuildContext) builder,
    ) async {
      await tester.pumpWidget(createTestWidget());
      final context = getContext(tester);
      final widget = builder(context);
      await tester.pumpWidget(createTestWidget(child: widget));
    }

    group('permissionsBanner Method Tests', () {
      testWidgets('creates banner with correct structure for owner mode',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code banner structure from lines 13-56
        bool tapped = false;
        
        await pumpPermissionsWidget(
          tester,
          (context) => CollaborativePermissionsWidgets.permissionsBanner(
            context: context,
            editMode: EditMode.owner,
            onTap: () => tapped = true,
          ),
        );

        expect(tester.takeException(), isNull);
        
        // ULTRATHINK: Verify container structure (lines 20-55)
        expect(find.byType(Container), findsOneWidget);
        expect(find.byType(InkWell), findsOneWidget);
        expect(find.byType(Row), findsOneWidget);
        expect(find.byType(Icon), findsOneWidget);
        expect(find.byType(Text), findsOneWidget);
        
        // ULTRATHINK: Test tap functionality (line 32-34)
        await tester.tap(find.byType(InkWell));
        expect(tapped, isTrue);
      });

      testWidgets('applies correct styling and colors for different EditMode values',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code color integration from lines 18, 25, 28, 39
        for (final editMode in EditMode.values) {
          await pumpPermissionsWidget(
            tester,
            (context) => CollaborativePermissionsWidgets.permissionsBanner(
              context: context,
              editMode: editMode,
            ),
          );

            
          // ULTRATHINK: Each EditMode should have proper UI representation
          expect(find.byType(Container), findsOneWidget);
          expect(find.byType(Icon), findsOneWidget);
          expect(find.text(editMode.description), findsOneWidget);
          
          // ULTRATHINK: Verify EditModeUIHelper integration
          final icon = tester.widget<Icon>(find.byType(Icon));
          expect(icon.icon, equals(EditModeUIHelper.getIcon(editMode)));
        }
      });

      testWidgets('handles null onTap callback gracefully',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code null callback handling
        await pumpPermissionsWidget(
          tester,
          (context) => CollaborativePermissionsWidgets.permissionsBanner(
            context: context,
            editMode: EditMode.view,
            onTap: null, // Null callback
          ),
        );

        
        // ULTRATHINK: Should still render correctly without crash
        expect(find.byType(InkWell), findsOneWidget);
        
        // Should be able to tap without issues (no callback to trigger)
        await tester.tap(find.byType(InkWell));
      });

      testWidgets('uses correct AppDimensions constants',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code dimension usage from lines 22, 23, 26, 34, 40, 42
        await pumpPermissionsWidget(
          tester,
          (context) => CollaborativePermissionsWidgets.permissionsBanner(
            context: context,
            editMode: EditMode.owner,
          ),
        );

        
        // ULTRATHINK: Verify container uses correct dimensions
        final container = tester.widget<Container>(find.byType(Container));
        // Container width is set to double.infinity in production code (line 21)
        
        // Verify padding uses AppDimensions.spacingL (line 22)
        expect(container.padding, equals(const EdgeInsets.all(AppDimensions.spacingL)));
        
        // Verify margin uses AppDimensions.spacingS (line 23)
        expect(container.margin, equals(const EdgeInsets.all(AppDimensions.spacingS)));
      });

      testWidgets('applies correct text styling',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code text styling from lines 44-50
        await pumpPermissionsWidget(
          tester,
          (context) => CollaborativePermissionsWidgets.permissionsBanner(
            context: context,
            editMode: EditMode.collaborative,
          ),
        );

        
        // ULTRATHINK: Verify text uses AppTextStyles.bodyLarge as base (line 46)
        final text = tester.widget<Text>(find.byType(Text));
        expect(text.data, equals(EditMode.collaborative.description));
        
        // Style should be based on AppTextStyles.bodyLarge with modifications
        expect(text.style?.fontWeight, equals(FontWeight.w500)); // Line 48
      });

      testWidgets('uses proper border radius from AppDimensions',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code border radius usage from lines 26, 34
        await pumpPermissionsWidget(
          tester,
          (context) => CollaborativePermissionsWidgets.permissionsBanner(
            context: context,
            editMode: EditMode.view,
          ),
        );

        
        // ULTRATHINK: Container decoration should use AppDimensions.cardBorderRadius
        final container = tester.widget<Container>(find.byType(Container));
        final decoration = container.decoration as BoxDecoration;
        expect(decoration.borderRadius, 
          equals(BorderRadius.circular(AppDimensions.cardBorderRadius)));
        
        // InkWell should use same border radius
        final inkWell = tester.widget<InkWell>(find.byType(InkWell));
        expect(inkWell.borderRadius, 
          equals(BorderRadius.circular(AppDimensions.cardBorderRadius)));
      });

      testWidgets('handles all EditMode enum values correctly',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code comprehensive EditMode support
        final editModes = [
          EditMode.noAccess,
          EditMode.view,
          EditMode.collaborative,
          EditMode.owner,
        ];

        for (final mode in editModes) {
          await pumpPermissionsWidget(
            tester,
            (context) => CollaborativePermissionsWidgets.permissionsBanner(
              context: context,
              editMode: mode,
            ),
          );

            
          // ULTRATHINK: Each mode should render without issues
          expect(find.text(mode.description), findsOneWidget);
          expect(find.byType(Icon), findsOneWidget);
          
          // ULTRATHINK: Icon should match EditModeUIHelper.getIcon() result
          final icon = tester.widget<Icon>(find.byType(Icon));
          expect(icon.icon, equals(EditModeUIHelper.getIcon(mode)));
        }
      });
    });

    group('smartPermissionsBanner Method Tests', () {
      late MockRecipeFormViewModel mockViewModel;

      setUp(() {
        mockViewModel = MockRecipeFormViewModel();
        
        // Register fallback values for mocktail
        registerFallbackValue(EditMode.noAccess);
      });

      testWidgets('returns SizedBox.shrink when editMode is null',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code null check from line 63
        mockViewModel.setRecipeFormState(
          editMode: null,
          editModeEnum: null,
        );
        
        await pumpPermissionsWidget(
          tester,
          (context) => CollaborativePermissionsWidgets.smartPermissionsBanner(
            context: context,
            viewModel: mockViewModel,
          ),
        );

        
        // ULTRATHINK: Should return SizedBox.shrink for null editMode (line 63)
        expect(find.byType(SizedBox), findsOneWidget);
        
        // Should not find any banner components
        expect(find.byType(Container), findsNothing);
        expect(find.byType(InkWell), findsNothing);
      });

      testWidgets('delegates to permissionsBanner when editMode is provided',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code delegation from lines 65-68
        mockViewModel.setRecipeFormState(
          editMode: 'owner',
          editModeEnum: EditMode.owner,
        );
        
        await pumpPermissionsWidget(
          tester,
          (context) => CollaborativePermissionsWidgets.smartPermissionsBanner(
            context: context,
            viewModel: mockViewModel,
          ),
        );

        
        // ULTRATHINK: Should delegate to permissionsBanner (lines 65-68)
        expect(find.byType(Container), findsOneWidget);
        expect(find.byType(InkWell), findsOneWidget);
        expect(find.text(EditMode.owner.description), findsOneWidget);
        
        // ULTRATHINK: Verify ViewModel state is correct (centralized mock pattern)
        expect(mockViewModel.editMode, equals('owner'));
        expect(mockViewModel.editModeEnum, equals(EditMode.owner));
      });

      testWidgets('uses fallback EditMode.noAccess when editModeEnum is null',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code fallback logic from line 67
        mockViewModel.setRecipeFormState(
          editMode: 'some_mode',
          editModeEnum: null, // Null enum
        );
        
        await pumpPermissionsWidget(
          tester,
          (context) => CollaborativePermissionsWidgets.smartPermissionsBanner(
            context: context,
            viewModel: mockViewModel,
          ),
        );

        
        // ULTRATHINK: Should use fallback EditMode.noAccess (line 67)
        expect(find.byType(Container), findsOneWidget);
        expect(find.text(EditMode.noAccess.description), findsOneWidget);
      });

      testWidgets('handles different EditMode enum values from ViewModel',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code with various EditMode enum values
        final modes = [
          EditMode.view,
          EditMode.collaborative,
          EditMode.owner,
        ];

        for (final mode in modes) {
          mockViewModel.setRecipeFormState(
            editMode: mode.name,
            editModeEnum: mode,
          );
          
          await pumpPermissionsWidget(
            tester,
            (context) => CollaborativePermissionsWidgets.smartPermissionsBanner(
              context: context,
              viewModel: mockViewModel,
            ),
          );

            
          // ULTRATHINK: Each mode should render correctly via delegation
          expect(find.text(mode.description), findsOneWidget);
          expect(find.byType(Icon), findsOneWidget);
        }
      });
    });

    group('Edge Cases and Integration Tests', () {
      testWidgets('handles theme color variations correctly',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code theme integration
        await pumpPermissionsWidget(
          tester,
          (context) => Column(
            children: EditMode.values.map((mode) => 
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: CollaborativePermissionsWidgets.permissionsBanner(
                  context: context,
                  editMode: mode,
                ),
              )
            ).toList(),
          ),
        );

        
        // ULTRATHINK: All modes should render without theme conflicts
        expect(find.byType(Container), findsNWidgets(EditMode.values.length));
        expect(find.byType(Icon), findsNWidgets(EditMode.values.length));
      });

      testWidgets('respects widget constraints and layout',
          (WidgetTester tester) async {
        // ULTRATHINK: Test production code layout behavior
        await pumpPermissionsWidget(
          tester,
          (context) => SizedBox(
            width: 200,
            child: CollaborativePermissionsWidgets.permissionsBanner(
              context: context,
              editMode: EditMode.collaborative,
            ),
          ),
        );

        
        // ULTRATHINK: Container should respect width constraint (double.infinity becomes parent width)
        final container = tester.renderObject<RenderBox>(find.byType(Container));
        expect(container.size.width, lessThanOrEqualTo(200));
      });
    });
  });
}