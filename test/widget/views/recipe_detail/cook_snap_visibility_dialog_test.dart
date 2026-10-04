import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/theme/app_mode_colors.dart';
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/views/recipe_detail/cook_snap_visibility_dialog.dart';

import '../../../infrastructure/helpers/ink_fill.dart';
import '../../../infrastructure/helpers/widget_test_app.dart';

void main() {
  Future<void> open(WidgetTester tester, ThemeData theme) async {
    await tester.pumpWidget(
      createLocalizedTestApp(
        child: Theme(
          data: theme,
          child: Builder(
            builder: (context) => Center(
              child: ElevatedButton(
                onPressed: () =>
                    showCookSnapVisibilityDialog(context, message: 'm'),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  Finder label(String key) => find
      .descendant(of: find.byKey(ValueKey(key)), matching: find.byType(Text))
      .first;

  // BUT-2205: the option's own fill used to sit above the ink layer, so a
  // pressed option showed nothing.
  for (final theme in [AppTheme.lightTheme, AppTheme.darkTheme]) {
    testWidgets('a pressed option shows its surface\'s fill '
        '(${theme.brightness.name})', (tester) async {
      await open(tester, theme);

      final onlyMe = label('cook-snap-visibility-only-me');
      expect(pressIsCovered(tester, onlyMe), isFalse);
      expect(borderIsAbovePress(tester, onlyMe), isTrue);
      var gesture = await holdPress(tester, onlyMe);
      expect(
        paintsInkFill(
          tester,
          onlyMe,
          theme.colorScheme.surfaceContainerHighest,
        ),
        isTrue,
      );
      await gesture.cancel();
      await tester.pumpAndSettle();

      // The chosen option rests on raised and presses one step darker.
      final same = label('cook-snap-visibility-same');
      expect(pressIsCovered(tester, same), isFalse);
      expect(borderIsAbovePress(tester, same), isTrue);
      gesture = await holdPress(tester, same);
      expect(
        paintsInkFill(
          tester,
          same,
          ModeColors.of(theme.brightness).pressedOnRaised,
        ),
        isTrue,
      );
      await gesture.cancel();
    });
  }
}
