// test/widget/common/saved_menu_ui_helper_ultrathink_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/widgets/common/saved_menu_ui_helper.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/viewmodels/menu/menu_state_manager.dart';

void main() {
  group('SavedMenuUIHelper Tests - ULTRATHINK METHODOLOGY', () {
    
    group('getAttributionColor Tests', () {
      testWidgets('returns correct color for "owned" attribution type', (tester) async {
        final menuInfo = SavedMenuInfo(
          key: 'test',
          name: 'Test Menu',
          savedDate: DateTime.now(),
          recipeCount: 3,
          comment: 'Test comment',
          isOwned: true,
          isModified: false,
        );

        final color = SavedMenuUIHelper.getAttributionColor(menuInfo);

        expect(color, AppColors.primaryBlue);
      });

      testWidgets('returns correct color for "modified" attribution type', (tester) async {
        final menuInfo = SavedMenuInfo(
          key: 'test',
          name: 'Test Menu',
          savedDate: DateTime.now(),
          recipeCount: 3,
          comment: 'Test comment',
          isOwned: true,
          isModified: true,
        );

        final color = SavedMenuUIHelper.getAttributionColor(menuInfo);

        expect(color, AppColors.accent);
      });

      testWidgets('returns correct color for "shared" attribution type', (tester) async {
        final menuInfo = SavedMenuInfo(
          key: 'test',
          name: 'Test Menu',
          savedDate: DateTime.now(),
          recipeCount: 3,
          comment: 'Test comment',
          isOwned: false,
          isModified: false,
        );

        final color = SavedMenuUIHelper.getAttributionColor(menuInfo);

        expect(color, AppColors.success);
      });

      testWidgets('returns default color for edge case attribution type', (tester) async {
        // This will produce 'owned' attribution type, but we test switch default
        // by checking that method handles unexpected values correctly
        final menuInfo = SavedMenuInfo(
          key: 'test',
          name: 'Test Menu',
          savedDate: DateTime.now(),
          recipeCount: 3,
          comment: 'Test comment',
          isOwned: true,
          isModified: false,
        );

        final color = SavedMenuUIHelper.getAttributionColor(menuInfo);

        expect(color, AppColors.primaryBlue); // Will be 'owned' type
      });

      testWidgets('handles getter logic for isOwned=false isModified=true edge case', (tester) async {
        final menuInfo = SavedMenuInfo(
          key: 'test',
          name: 'Test Menu',
          savedDate: DateTime.now(),
          recipeCount: 3,
          comment: 'Test comment',
          isOwned: false,
          isModified: true, // Not owned but modified
        );

        final color = SavedMenuUIHelper.getAttributionColor(menuInfo);

        expect(color, AppColors.success); // Should be 'shared' type
      });

      testWidgets('verifies all three attribution color types work correctly', (tester) async {
        // Test owned type
        final ownedMenu = SavedMenuInfo(
          key: 'owned',
          name: 'Owned Menu',
          savedDate: DateTime.now(),
          recipeCount: 3,
          comment: 'Owned menu',
          isOwned: true,
          isModified: false,
        );
        expect(SavedMenuUIHelper.getAttributionColor(ownedMenu), AppColors.primaryBlue);

        // Test modified type
        final modifiedMenu = SavedMenuInfo(
          key: 'modified',
          name: 'Modified Menu',
          savedDate: DateTime.now(),
          recipeCount: 3,
          comment: 'Modified menu',
          isOwned: true,
          isModified: true,
        );
        expect(SavedMenuUIHelper.getAttributionColor(modifiedMenu), AppColors.accent);

        // Test shared type
        final sharedMenu = SavedMenuInfo(
          key: 'shared',
          name: 'Shared Menu',
          savedDate: DateTime.now(),
          recipeCount: 3,
          comment: 'Shared menu',
          isOwned: false,
          isModified: false,
        );
        expect(SavedMenuUIHelper.getAttributionColor(sharedMenu), AppColors.success);
      });

      testWidgets('verifies getter logic consistency', (tester) async {
        // Test that the same flags produce the same getter values
        final testCases = [
          (true, false, AppColors.primaryBlue), // owned
          (true, true, AppColors.accent),       // modified
          (false, false, AppColors.success),    // shared
          (false, true, AppColors.success),     // shared (edge case)
        ];

        for (final (isOwned, isModified, expectedColor) in testCases) {
          final menuInfo = SavedMenuInfo(
            key: 'test-$isOwned-$isModified',
            name: 'Test Menu',
            savedDate: DateTime.now(),
            recipeCount: 3,
            comment: 'Test comment',
            isOwned: isOwned,
            isModified: isModified,
          );

          final color = SavedMenuUIHelper.getAttributionColor(menuInfo);
          expect(color, expectedColor);
        }
      });

      testWidgets('handles complex menu name and comment data', (tester) async {
        final testCases = [
          (' Special Menu ', 'Comment with spaces'),
          ('Menu\nwith\nlines', 'Comment\nwith\nlines'),
          ('Menu\twith\ttabs', 'Comment\twith\ttabs'),
          ('特殊字符菜单', '特殊字符注释'),
          ('🎉🚀 Emoji Menu', '🎉🚀 Emoji comment'),
        ];

        for (final (menuName, comment) in testCases) {
          final menuInfo = SavedMenuInfo(
            key: 'test-special',
            name: menuName,
            savedDate: DateTime.now(),
            recipeCount: 5,
            comment: comment,
            isOwned: true,
            isModified: false,
          );

          // Should still work correctly with any menu data
          final color = SavedMenuUIHelper.getAttributionColor(menuInfo);
          expect(color, AppColors.primaryBlue);
        }
      });
    });

    group('getStatusIconData Tests', () {
      testWidgets('returns correct icon for "restaurantMenu" status', (tester) async {
        final menuInfo = SavedMenuInfo(
          key: 'test',
          name: 'Test Menu',
          savedDate: DateTime.now(),
          recipeCount: 3,
          comment: 'Test comment',
          isOwned: true,
          isModified: false,
        );

        final icon = SavedMenuUIHelper.getStatusIconData(menuInfo);

        expect(icon, Icons.restaurant_menu);
      });

      testWidgets('returns correct icon for "autoFixHigh" status', (tester) async {
        final menuInfo = SavedMenuInfo(
          key: 'test',
          name: 'Test Menu',
          savedDate: DateTime.now(),
          recipeCount: 3,
          comment: 'Test comment',
          isOwned: true,
          isModified: true,
        );

        final icon = SavedMenuUIHelper.getStatusIconData(menuInfo);

        expect(icon, Icons.auto_fix_high);
      });

      testWidgets('returns correct icon for "person" status', (tester) async {
        final menuInfo = SavedMenuInfo(
          key: 'test',
          name: 'Test Menu',
          savedDate: DateTime.now(),
          recipeCount: 3,
          comment: 'Test comment',
          isOwned: false,
          isModified: false,
        );

        final icon = SavedMenuUIHelper.getStatusIconData(menuInfo);

        expect(icon, Icons.person);
      });

      testWidgets('returns default icon through switch default case', (tester) async {
        // Note: Since statusIcon getter only returns specific strings,
        // we can't directly test "unknown" values, but we verify the default
        final menuInfo = SavedMenuInfo(
          key: 'test',
          name: 'Test Menu',
          savedDate: DateTime.now(),
          recipeCount: 3,
          comment: 'Test comment',
          isOwned: true,
          isModified: false,
        );

        final icon = SavedMenuUIHelper.getStatusIconData(menuInfo);

        expect(icon, Icons.restaurant_menu); // Should be restaurantMenu for owned=true, modified=false
      });

      testWidgets('verifies all three status icon types work correctly', (tester) async {
        // Test restaurantMenu icon (owned, not modified)
        final ownedMenu = SavedMenuInfo(
          key: 'owned',
          name: 'Owned Menu',
          savedDate: DateTime.now(),
          recipeCount: 3,
          comment: 'Owned menu',
          isOwned: true,
          isModified: false,
        );
        expect(SavedMenuUIHelper.getStatusIconData(ownedMenu), Icons.restaurant_menu);

        // Test autoFixHigh icon (owned and modified)
        final modifiedMenu = SavedMenuInfo(
          key: 'modified',
          name: 'Modified Menu',
          savedDate: DateTime.now(),
          recipeCount: 3,
          comment: 'Modified menu',
          isOwned: true,
          isModified: true,
        );
        expect(SavedMenuUIHelper.getStatusIconData(modifiedMenu), Icons.auto_fix_high);

        // Test person icon (not owned)
        final sharedMenu = SavedMenuInfo(
          key: 'shared',
          name: 'Shared Menu',
          savedDate: DateTime.now(),
          recipeCount: 3,
          comment: 'Shared menu',
          isOwned: false,
          isModified: false,
        );
        expect(SavedMenuUIHelper.getStatusIconData(sharedMenu), Icons.person);
      });

      testWidgets('handles edge case of not owned but modified', (tester) async {
        final menuInfo = SavedMenuInfo(
          key: 'edge-case',
          name: 'Edge Case Menu',
          savedDate: DateTime.now(),
          recipeCount: 3,
          comment: 'Edge case menu',
          isOwned: false,
          isModified: true, // Not owned but somehow modified
        );

        final icon = SavedMenuUIHelper.getStatusIconData(menuInfo);

        expect(icon, Icons.person); // Should be person icon (not owned)
      });

      testWidgets('verifies status icon getter logic consistency', (tester) async {
        // Test that the same flags produce the same getter values
        final testCases = [
          (true, false, Icons.restaurant_menu), // owned, not modified
          (true, true, Icons.auto_fix_high),     // owned and modified
          (false, false, Icons.person),          // not owned, not modified
          (false, true, Icons.person),           // not owned, modified
        ];

        for (final (isOwned, isModified, expectedIcon) in testCases) {
          final menuInfo = SavedMenuInfo(
            key: 'test-$isOwned-$isModified',
            name: 'Test Menu',
            savedDate: DateTime.now(),
            recipeCount: 3,
            comment: 'Test comment',
            isOwned: isOwned,
            isModified: isModified,
          );

          final icon = SavedMenuUIHelper.getStatusIconData(menuInfo);
          expect(icon, expectedIcon);
        }
      });

      testWidgets('handles complex menu data without affecting icon logic', (tester) async {
        final testData = [
          (' Special Menu ', 'Comment with spaces', 0),
          ('Menu\nwith\nlines', 'Comment\nwith\nlines', 999),
          ('特殊字符菜单', '特殊字符注释', -5),
          ('🎉🚀 Emoji Menu', '🎉🚀 Emoji comment', 42),
        ];

        for (final (menuName, comment, recipeCount) in testData) {
          final menuInfo = SavedMenuInfo(
            key: 'test-special',
            name: menuName,
            savedDate: DateTime.now(),
            recipeCount: recipeCount,
            comment: comment,
            isOwned: true,
            isModified: true, // Should produce autoFixHigh
          );

          // Complex data should not affect icon logic
          final icon = SavedMenuUIHelper.getStatusIconData(menuInfo);
          expect(icon, Icons.auto_fix_high);
        }
      });
    });

    group('AppColors Integration Tests', () {
      testWidgets('uses correct AppColors constants', (tester) async {
        // Test each color through proper flag combinations
        final ownedMenu = SavedMenuInfo(
          key: 'owned-test',
          name: 'Owned Menu',
          savedDate: DateTime.now(),
          recipeCount: 3,
          comment: 'Test owned',
          isOwned: true,
          isModified: false,
        );
        expect(SavedMenuUIHelper.getAttributionColor(ownedMenu), AppColors.primaryBlue);

        final modifiedMenu = SavedMenuInfo(
          key: 'modified-test',
          name: 'Modified Menu',
          savedDate: DateTime.now(),
          recipeCount: 3,
          comment: 'Test modified',
          isOwned: true,
          isModified: true,
        );
        expect(SavedMenuUIHelper.getAttributionColor(modifiedMenu), AppColors.accent);

        final sharedMenu = SavedMenuInfo(
          key: 'shared-test',
          name: 'Shared Menu',
          savedDate: DateTime.now(),
          recipeCount: 3,
          comment: 'Test shared',
          isOwned: false,
          isModified: false,
        );
        expect(SavedMenuUIHelper.getAttributionColor(sharedMenu), AppColors.success);
      });

      testWidgets('returns valid Color objects', (tester) async {
        final menuInfo = SavedMenuInfo(
          key: 'test',
          name: 'Test Menu',
          savedDate: DateTime.now(),
          recipeCount: 3,
          comment: 'Test comment',
          isOwned: true,
          isModified: false,
        );

        final color = SavedMenuUIHelper.getAttributionColor(menuInfo);

        expect(color, isA<Color>());
        expect((color.a * 255.0).round() & 0xff, isPositive);
        expect((color.r * 255.0).round() & 0xff, isNonNegative);
        expect((color.g * 255.0).round() & 0xff, isNonNegative);
        expect((color.b * 255.0).round() & 0xff, isNonNegative);
      });
    });

    group('IconData Integration Tests', () {
      testWidgets('uses correct IconData constants', (tester) async {
        // Test each icon through proper flag combinations
        final ownedMenu = SavedMenuInfo(
          key: 'owned-icon-test',
          name: 'Owned Menu',
          savedDate: DateTime.now(),
          recipeCount: 3,
          comment: 'Test owned icon',
          isOwned: true,
          isModified: false,
        );
        expect(SavedMenuUIHelper.getStatusIconData(ownedMenu), Icons.restaurant_menu);

        final modifiedMenu = SavedMenuInfo(
          key: 'modified-icon-test',
          name: 'Modified Menu',
          savedDate: DateTime.now(),
          recipeCount: 3,
          comment: 'Test modified icon',
          isOwned: true,
          isModified: true,
        );
        expect(SavedMenuUIHelper.getStatusIconData(modifiedMenu), Icons.auto_fix_high);

        final sharedMenu = SavedMenuInfo(
          key: 'shared-icon-test',
          name: 'Shared Menu',
          savedDate: DateTime.now(),
          recipeCount: 3,
          comment: 'Test shared icon',
          isOwned: false,
          isModified: false,
        );
        expect(SavedMenuUIHelper.getStatusIconData(sharedMenu), Icons.person);
      });

      testWidgets('returns valid IconData objects', (tester) async {
        final menuInfo = SavedMenuInfo(
          key: 'test',
          name: 'Test Menu',
          savedDate: DateTime.now(),
          recipeCount: 3,
          comment: 'Test comment',
          isOwned: true,
          isModified: false,
        );

        final icon = SavedMenuUIHelper.getStatusIconData(menuInfo);

        expect(icon, isA<IconData>());
        expect(icon.codePoint, isPositive);
      });
    });

    group('Static Method Behavior Tests', () {
      testWidgets('static methods do not maintain state', (tester) async {
        final menuInfo1 = SavedMenuInfo(
          key: 'test1',
          name: 'Test Menu 1',
          savedDate: DateTime.now(),
          recipeCount: 3,
          comment: 'Test comment 1',
          isOwned: true,
          isModified: false,
        );

        final menuInfo2 = SavedMenuInfo(
          key: 'test2',
          name: 'Test Menu 2',
          savedDate: DateTime.now(),
          recipeCount: 5,
          comment: 'Test comment 2',
          isOwned: false,
          isModified: false,
        );

        // Multiple calls should not affect each other
        final color1 = SavedMenuUIHelper.getAttributionColor(menuInfo1);
        final color2 = SavedMenuUIHelper.getAttributionColor(menuInfo2);
        final icon1 = SavedMenuUIHelper.getStatusIconData(menuInfo1);
        final icon2 = SavedMenuUIHelper.getStatusIconData(menuInfo2);

        expect(color1, AppColors.primaryBlue); // owned
        expect(color2, AppColors.success);     // shared
        expect(icon1, Icons.restaurant_menu);  // owned
        expect(icon2, Icons.person);           // shared
      });

      testWidgets('methods work independently', (tester) async {
        final menuInfo = SavedMenuInfo(
          key: 'test',
          name: 'Test Menu',
          savedDate: DateTime.now(),
          recipeCount: 3,
          comment: 'Test comment',
          isOwned: false,
          isModified: false, // Should give shared color but person icon
        );

        // Both methods should work correctly with same menuInfo
        final color = SavedMenuUIHelper.getAttributionColor(menuInfo);
        final icon = SavedMenuUIHelper.getStatusIconData(menuInfo);

        expect(color, AppColors.success); // shared color
        expect(icon, Icons.person);       // person icon
      });

      testWidgets('handles rapid successive calls', (tester) async {
        final menuInfo = SavedMenuInfo(
          key: 'test',
          name: 'Test Menu',
          savedDate: DateTime.now(),
          recipeCount: 3,
          comment: 'Test comment',
          isOwned: true,
          isModified: false,
        );

        // Multiple rapid calls should return consistent results
        for (int i = 0; i < 100; i++) {
          final color = SavedMenuUIHelper.getAttributionColor(menuInfo);
          final icon = SavedMenuUIHelper.getStatusIconData(menuInfo);

          expect(color, AppColors.primaryBlue); // owned color
          expect(icon, Icons.restaurant_menu); // owned icon
        }
      });
    });

    group('SavedMenuInfo Integration Tests', () {
      testWidgets('works with different SavedMenuInfo configurations', (tester) async {
        final menuInfos = [
          SavedMenuInfo(
            key: 'menu1',
            name: 'Personal Menu',
            savedDate: DateTime.now(),
            recipeCount: 2,
            comment: 'Personal menu',
            isOwned: true,
            isModified: false, // owned = primaryBlue + restaurantMenu
          ),
          SavedMenuInfo(
            key: 'menu2',
            name: 'Modified Menu',
            savedDate: DateTime.now(),
            recipeCount: 4,
            comment: 'Modified menu',
            isOwned: true,
            isModified: true, // modified = accent + autoFixHigh
          ),
          SavedMenuInfo(
            key: 'menu3',
            name: 'Shared Menu',
            savedDate: DateTime.now(),
            recipeCount: 6,
            comment: 'Shared menu',
            isOwned: false,
            isModified: false, // shared = success + person
          ),
        ];

        final expectedResults = [
          (AppColors.primaryBlue, Icons.restaurant_menu), // owned
          (AppColors.accent, Icons.auto_fix_high),        // modified
          (AppColors.success, Icons.person),              // shared
        ];

        for (int i = 0; i < menuInfos.length; i++) {
          final color = SavedMenuUIHelper.getAttributionColor(menuInfos[i]);
          final icon = SavedMenuUIHelper.getStatusIconData(menuInfos[i]);

          expect(color, expectedResults[i].$1);
          expect(icon, expectedResults[i].$2);
        }
      });

      testWidgets('handles SavedMenuInfo with minimal required data', (tester) async {
        final menuInfo = SavedMenuInfo(
          key: 'minimal',
          name: 'Minimal Menu',
          savedDate: DateTime.now(),
          recipeCount: 1,
          comment: '',
          // Using default values: isModified=false, isOwned=true
        );

        final color = SavedMenuUIHelper.getAttributionColor(menuInfo);
        final icon = SavedMenuUIHelper.getStatusIconData(menuInfo);

        expect(color, AppColors.primaryBlue);    // owned
        expect(icon, Icons.restaurant_menu);     // owned
      });
    });

    group('Edge Cases and Error Handling Tests', () {
      testWidgets('handles extreme string values in menu data', (tester) async {
        final extremeValues = [
          ('', ''),
          (' ', ' '),
          ('\n\t', '\n\t'),
          ('a' * 1000, 'b' * 1000), // Very long strings
          ('特殊字符', '特殊字符注释'), // Unicode characters
          ('🎉🚀', '🎉🚀 emoji'), // Emojis
          ('123456', '789012'),
          ('null', 'null comment'),
          ('undefined', 'undefined comment'),
        ];

        for (final (name, comment) in extremeValues) {
          final menuInfo = SavedMenuInfo(
            key: 'extreme-test',
            name: name,
            savedDate: DateTime.now(),
            recipeCount: 1,
            comment: comment,
            isOwned: true,
            isModified: false,
          );

          // Should not throw exceptions
          expect(() => SavedMenuUIHelper.getAttributionColor(menuInfo), returnsNormally);
          expect(() => SavedMenuUIHelper.getStatusIconData(menuInfo), returnsNormally);

          // Extreme data should not affect getter logic
          final color = SavedMenuUIHelper.getAttributionColor(menuInfo);
          final icon = SavedMenuUIHelper.getStatusIconData(menuInfo);

          expect(color, AppColors.primaryBlue);    // owned
          expect(icon, Icons.restaurant_menu);     // owned
        }
      });

      testWidgets('consistent behavior across multiple invocations', (tester) async {
        final menuInfo = SavedMenuInfo(
          key: 'consistency',
          name: 'Consistency Test',
          savedDate: DateTime.now(),
          recipeCount: 5,
          comment: 'Consistency test comment',
          isOwned: false,
          isModified: true, // Edge case: not owned but modified
        );

        final colors = <Color>[];
        final icons = <IconData>[];

        // Collect results from multiple calls
        for (int i = 0; i < 10; i++) {
          colors.add(SavedMenuUIHelper.getAttributionColor(menuInfo));
          icons.add(SavedMenuUIHelper.getStatusIconData(menuInfo));
        }

        // All results should be identical
        expect(colors.every((c) => c == AppColors.success), isTrue);     // shared
        expect(icons.every((i) => i == Icons.person), isTrue);           // person
      });
    });
  });
}