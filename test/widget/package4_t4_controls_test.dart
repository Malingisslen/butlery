/// Package 4, track 4 (P4-U13, P4-U15, P4-U17): the controls the social,
/// account and admin views adopt.
///
/// - "Skicka anmälan" is the report dialog's one saffron action (Skarmar v12
///   etapp 9 #fbanmal), in light and dark mode alike (Komponentark
///   v1:370-371; the hero style is the same in both modes, Grafisk manual
///   v6:561), and its five reasons are 48 dp rows with the shared grip.
/// - The week choice for sharing a menu uses the same grip on its radios.
/// - The admin shell's six tabs ring on keyboard focus
///   (produktregler.md:626; block288 CSR::ROLE::tab::FOCUSED).
/// - A chosen row keeps its content text.primary in dark mode: paper on
///   surface.selected, never ink (tokens.json text.primary dark #F5F4ED).
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/models/social/content_type.dart';
import 'package:butlery/theme/app_mode_colors.dart';
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/viewmodels/onboarding_viewmodel.dart';
import 'package:butlery/views/admin/admin_shell.dart';
import 'package:butlery/views/onboarding/onboarding_dietary_page.dart';
import 'package:butlery/widgets/common/butlery_control_focus.dart';
import 'package:butlery/widgets/common/butlery_focus_ring.dart';
import 'package:butlery/widgets/common/dialogs/share_selection/menu_week_selection_dialog.dart';
import 'package:butlery/widgets/social/report_content_dialog.dart';

Widget _app(Widget home, {ThemeData? theme}) => MaterialApp(
  theme: theme ?? AppTheme.lightTheme,
  locale: const Locale('sv'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: home),
);

void main() {
  group('report dialog', () {
    Future<void> open(WidgetTester tester, ThemeData theme) async {
      await tester.pumpWidget(
        _app(
          Builder(
            builder: (context) => TextButton(
              onPressed: () => ReportContentDialog.show(
                context: context,
                contentType: ContentType.recipe,
                contentId: 'r-1',
              ),
              child: const Text('open'),
            ),
          ),
          theme: theme,
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }

    for (final (name, theme) in [
      ('light', AppTheme.lightTheme),
      ('dark', AppTheme.darkTheme),
    ]) {
      testWidgets('Skicka anmälan is the saffron hero ($name)', (tester) async {
        await open(tester, theme);

        final submit = find.byKey(const ValueKey('reportContent.submit'));
        expect(
          find.descendant(of: submit, matching: find.text('Skicka anmälan')),
          findsOneWidget,
        );

        // Choose a reason so the button is enabled.
        await tester.tap(find.text('Spam'));
        await tester.pumpAndSettle();

        final button = tester.widget<FilledButton>(submit);
        expect(button.onPressed, isNotNull);
        final fill = button.style!.backgroundColor!.resolve({});
        expect(fill, AppModeColors.actionPrimary(theme.brightness));
      });
    }

    testWidgets('the five reasons are rows with the shared focus grip', (
      tester,
    ) async {
      await open(tester, AppTheme.lightTheme);

      final rows = find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(ButleryControlFocus),
      );
      expect(rows, findsNWidgets(5));
      for (final row in tester.widgetList<ButleryControlFocus>(rows)) {
        expect(row.child, isA<RadioListTile<String>>());
      }
      for (final element in rows.evaluate()) {
        final size = (element.renderObject! as RenderBox).size;
        expect(size.height, greaterThanOrEqualTo(48));
      }
    });
  });

  testWidgets('the week choice radios sit in the shared focus grip', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        Builder(
          builder: (context) => TextButton(
            onPressed: () => showDialog<DateTime>(
              context: context,
              builder: (_) => const MenuWeekSelectionDialog(),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    final radios = find.byType(RadioListTile<DateTime>);
    expect(radios, findsWidgets);
    expect(
      find.ancestor(
        of: radios.first,
        matching: find.byType(ButleryControlFocus),
      ),
      findsOneWidget,
    );
    expect(
      find.byType(ButleryControlFocus),
      findsNWidgets(tester.widgetList(radios).length),
    );
  });

  group('admin tabs', () {
    setUp(() {
      FocusManager.instance.highlightStrategy =
          FocusHighlightStrategy.alwaysTraditional;
    });

    tearDown(() {
      FocusManager.instance.highlightStrategy =
          FocusHighlightStrategy.automatic;
    });

    testWidgets('each of the six tabs rings when it has keyboard focus', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          SizedBox(
            height: 700,
            child: AdminRail(selectedIndex: 0, onSelected: (_) {}),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final rings = find.byType(ButleryAncestorFocusRing);
      expect(rings, findsNWidgets(6));

      List<bool?> focused() => [
        for (final e in rings.evaluate())
          tester
              .widget<ButleryFocusRing>(
                find.descendant(
                  of: find.byWidget(e.widget),
                  matching: find.byType(ButleryFocusRing),
                ),
              )
              .focused,
      ];

      expect(focused().where((f) => f == true), isEmpty);

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      expect(focused().where((f) => f == true), hasLength(1));
      expect(focused().first, isTrue);

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      expect(focused()[1], isTrue);
      expect(focused().first, isFalse);
    });

    testWidgets('the rail draws no focus tint under the ring', (tester) async {
      await tester.pumpWidget(
        _app(AdminRail(selectedIndex: 0, onSelected: (_) {})),
      );
      final theme = Theme.of(
        tester.element(find.byType(NavigationRail)),
      );
      expect(theme.focusColor.a, 0);
    });
  });
  group('chosen row in dark mode', () {
    testWidgets('the icon and check stay text.primary, not ink', (
      tester,
    ) async {
      final vm = OnboardingViewModel()..toggleDietaryPref('vegetarisk');
      addTearDown(vm.dispose);
      await tester.pumpWidget(
        ChangeNotifierProvider<OnboardingViewModel>.value(
          value: vm,
          child: _app(
            const OnboardingDietaryPage(),
            theme: AppTheme.darkTheme,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final cs = AppTheme.darkTheme.colorScheme;
      expect(cs.onSurface, isNot(cs.primary));
      expect(
        tester.widget<Icon>(find.byIcon(Icons.check_circle)).color,
        cs.onSurface,
      );
      expect(tester.widget<Icon>(find.byIcon(Icons.eco)).color, cs.onSurface);
    });
  });
}
