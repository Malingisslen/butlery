// BUT-2205: pressable widgets whose own fill used to sit above the ink layer,
// so a press showed nothing. Each is pressed in both modes.

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/models/cooking/cooking_session.dart';
import 'package:butlery/theme/app_mode_colors.dart';
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/widgets/common/search_filter/quick_filter_chips.dart';
import 'package:butlery/widgets/common/share_dialog/share_mode_selection.dart';
import 'package:butlery/widgets/common/universal_share_dialog.dart';
import 'package:butlery/widgets/cooking/cooking_session_card.dart';
import 'package:butlery/widgets/user/user_avatar_widgets.dart';

import '../../infrastructure/helpers/ink_fill.dart';
import '../../infrastructure/helpers/widget_test_app.dart';

void main() {
  Future<void> pump(WidgetTester tester, ThemeData theme, Widget child) {
    return tester.pumpWidget(
      createLocalizedTestApp(
        child: Theme(
          data: theme,
          child: Scaffold(body: Center(child: child)),
        ),
      ),
    );
  }

  AppLocalizations l10n(WidgetTester tester) =>
      AppLocalizations.of(tester.element(find.byType(Scaffold).first));

  Future<void> expectPressFill(
    WidgetTester tester,
    Finder target,
    Color fill,
  ) async {
    expect(pressIsCovered(tester, target), isFalse);
    expect(borderIsAbovePress(tester, target), isTrue);
    final gesture = await holdPress(tester, target);
    expect(paintsInkFill(tester, target, fill), isTrue);
    await gesture.cancel();
    // The cooking card's dot pulses forever, so the press is let go by time.
    await tester.pump(const Duration(seconds: 1));
  }

  for (final theme in [AppTheme.lightTheme, AppTheme.darkTheme]) {
    final mode = theme.brightness.name;
    final modeColors = ModeColors.of(theme.brightness);
    final cs = theme.colorScheme;

    // The chip's grip is wider than the pill, so the pill itself takes the
    // pressed fill.
    testWidgets('a pressed quick filter chip fills the pill ($mode)', (
      tester,
    ) async {
      await pump(
        tester,
        theme,
        QuickFilterChips(
          options: const [
            QuickFilterOption(id: 'a', label: 'Favoriter'),
            QuickFilterOption(id: 'b', label: 'Snabbt'),
          ],
          selectedIds: const {'b'},
          onFilterToggle: (_) {},
          showAllOption: false,
        ),
      );
      Color pill(String label) {
        final box = tester.widget<AnimatedContainer>(
          find
              .ancestor(
                of: find.text(label),
                matching: find.byType(AnimatedContainer),
              )
              .first,
        );
        return (box.decoration! as BoxDecoration).color!;
      }

      expect(pill('Favoriter'), cs.surfaceContainerHighest);
      var gesture = await holdPress(tester, find.text('Favoriter'));
      expect(pill('Favoriter'), modeColors.pressedOnRaised);
      await gesture.up();
      await tester.pumpAndSettle();
      expect(pill('Favoriter'), cs.surfaceContainerHighest);

      gesture = await holdPress(tester, find.text('Snabbt'));
      expect(pill('Snabbt'), modeColors.pressedOnInk);
      await gesture.cancel();
      await tester.pumpAndSettle();

      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      addTearDown(mouse.removePointer);
      await mouse.moveTo(tester.getCenter(find.text('Favoriter')));
      await tester.pumpAndSettle();
      expect(pill('Favoriter'), modeColors.pressedOnRaised);
    });

    // The share dialog paints the page colour under its options.
    Widget share(ShareMode selected) => ColoredBox(
      color: cs.surface,
      child: Builder(
        builder: (context) => ShareModeSelection.build(
          context,
          selected,
          ShareContentType.recipe,
          true,
          (_) {},
        ),
      ),
    );

    testWidgets('a pressed share option shows its surface\'s fill ($mode)', (
      tester,
    ) async {
      await pump(
        tester,
        theme,
        share(ShareMode.staticCopy),
      );
      final staticCopy = find.text(l10n(tester).shareStaticCopy);
      final realtime = find.text(l10n(tester).shareRealtimeSharing);
      await expectPressFill(tester, staticCopy, modeColors.pressedOnRaised);
      await expectPressFill(tester, realtime, cs.surfaceContainerHighest);

      await pump(tester, theme, share(ShareMode.realtime));
      await expectPressFill(tester, realtime, modeColors.pressedOnRaised);
      await expectPressFill(tester, staticCopy, cs.surfaceContainerHighest);
    });

    testWidgets('a pressed cooking card shows the step on ink ($mode)', (
      tester,
    ) async {
      await pump(
        tester,
        theme,
        CookingSessionCard(
          sessions: [
            CookingSession(
              recipeId: 'r1',
              recipeTitle: 'Kycklinggryta',
              startedAt: DateTime(2026, 4, 20, 18),
              userId: 'u1',
              userName: 'Erik',
            ),
          ],
        ),
      );
      await expectPressFill(
        tester,
        find.textContaining('Kycklinggryta'),
        modeColors.pressedOnInk,
      );
    });

    testWidgets('a pressed avatar edit button shows the step on ink ($mode)', (
      tester,
    ) async {
      await pump(
        tester,
        theme,
        UserAvatarWidgets.editableAvatar(displayName: 'Anna', onEditTap: () {}),
      );
      final button = find.descendant(
        of: find.byWidgetPredicate((w) => w is InkWell && w.onTap != null),
        matching: find.byWidgetPredicate((w) => w is Icon),
      );
      // The button's own Material paints its ink circle.
      final material = tester.widget<Material>(
        find
            .ancestor(
              of: find.byWidgetPredicate(
                (w) => w is InkWell && w.onTap != null,
              ),
              matching: find.byType(Material),
            )
            .first,
      );
      expect(material.color, cs.primary);
      await expectPressFill(tester, button.first, modeColors.pressedOnInk);
    });
  }
}
