/// P4-U03: the shared grip on one control of each kind.
///
/// Checkbox, switch, radio, chip (filter chip and quick chip), navigation
/// tab, view tab (TabBar) and menu item each get the canonical ring 3 px
/// outside a box of at least 48 × 48 dp, ink on light and paper on dark,
/// only for keyboard focus, and no focus tint under the ring
/// (tokens.json:155-160, :485-492; Grafisk manual v6:209, :381;
/// Komponentark v1:657, :667; fas2/block288-uxfrysning.json
/// `CSR::ROLE::<roll>::FOCUSED`).
///
/// The ring is read back from rendered pixels, with the same method as
/// butlery_focus_ring_test.dart.
library;

import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/models/tagging/personal_tag.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_colors_dark.dart';
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/widgets/common/butlery_control_focus.dart';
import 'package:butlery/widgets/common/butlery_focus_ring.dart';
import 'package:butlery/widgets/common/input/adaptive_switch.dart';
import 'package:butlery/widgets/common/input/debounced_checkbox.dart';
import 'package:butlery/widgets/common/navigation/adaptive_navigation.dart';
import 'package:butlery/widgets/common/search_filter/filter_chips_widget.dart';
import 'package:butlery/widgets/common/search_filter/filter_models.dart';
import 'package:butlery/widgets/common/search_filter/personal_tag_filter_chips.dart';
import 'package:butlery/widgets/common/search_filter/quick_filter_chips.dart';
import 'package:butlery/widgets/common/state_widget.dart';

final _boundaryKey = GlobalKey();

Future<void> _pump(WidgetTester tester, Widget body, {ThemeData? theme}) async {
  await tester.pumpWidget(
    RepaintBoundary(
      key: _boundaryKey,
      child: MaterialApp(
        theme: theme ?? AppTheme.lightTheme,
        locale: const Locale('sv'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(40),
            child: Align(alignment: Alignment.topLeft, child: body),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<Color> _pixel(WidgetTester tester, Offset at) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(_boundaryKey),
  );
  final bytes = await tester.runAsync(() async {
    final image = await boundary.toImage();
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    final width = image.width;
    image.dispose();
    return (data!, width);
  });
  final (ByteData data, int width) = bytes!;
  final i = (at.dy.floor() * width + at.dx.floor()) * 4;
  return Color.fromARGB(
    data.getUint8(i + 3),
    data.getUint8(i),
    data.getUint8(i + 1),
    data.getUint8(i + 2),
  );
}

/// The middle of the ring's stroke above the top edge and left of the left
/// edge.
List<Offset> _ringPoints(Rect r) => [
  Offset(r.center.dx, r.top - ButleryFocusRing.inflate),
  Offset(r.left - ButleryFocusRing.inflate, r.center.dy),
];

Future<void> _tabInto(WidgetTester tester) async {
  await tester.sendKeyEvent(LogicalKeyboardKey.tab);
  await tester.pumpAndSettle();
}

class _Case {
  const _Case(this.build, this.box);

  /// The control, as a view would place it.
  final Widget Function() build;

  /// The box the ring goes around.
  final Finder Function() box;
}

final _cases = <String, _Case>{
  'checkbox': _Case(
    () => DebouncedCheckbox(value: false, onChanged: (_) {}),
    () => find.byType(ButleryControlFocus),
  ),
  'switch': _Case(
    () => AdaptiveSwitch(value: true, onChanged: (_) {}),
    () => find.byType(ButleryControlFocus),
  ),
  'radio': _Case(
    () => ButleryControlFocus(
      borderRadius: BorderRadius.circular(999),
      child: RadioGroup<int>(
        groupValue: 1,
        onChanged: (_) {},
        child: const Radio<int>(value: 1),
      ),
    ),
    () => find.byType(ButleryControlFocus),
  ),
  'filter chip': _Case(
    () => SizedBox(
      width: 320,
      child: FilterChipsWidget(
        title: 'Kost',
        options: const [FilterOption(id: 'veg', label: 'Vegetariskt')],
        activeFilters: const {},
        onToggle: (_) {},
      ),
    ),
    () => find.byType(ButleryControlFocus),
  ),
  'quick chip': _Case(
    () => SizedBox(
      width: 320,
      child: QuickFilterChips(
        options: const [],
        selectedIds: const {'x'},
        onFilterToggle: (_) {},
      ),
    ),
    () => find.byType(ButleryControlFocus),
  ),
  'navigation tab': _Case(
    () => SizedBox(
      width: 300,
      child: ButleryBottomNavigation(
        currentIndex: 0,
        onTap: (_) {},
        items: const [
          AdaptiveNavigationItem(
            icon: Icons.home_outlined,
            activeIcon: Icons.home,
            label: 'Hem',
            route: '/',
          ),
          AdaptiveNavigationItem(
            icon: Icons.menu_book_outlined,
            activeIcon: Icons.menu_book,
            label: 'Recept',
            route: '/recept',
          ),
        ],
      ),
    ),
    () => find.byType(ButleryControlFocus).first,
  ),
  'view tab': _Case(
    () => SizedBox(
      width: 300,
      child: DefaultTabController(
        length: 2,
        child: TabBar(
          overlayColor: ButleryControlFocus.withoutFocusTint(null),
          tabs: const [
            ButleryTab(text: 'Mina'),
            ButleryTab(text: 'Delade'),
          ],
        ),
      ),
    ),
    () => find.byType(ButleryAncestorFocusRing).first,
  ),
};

void main() {
  setUp(() {
    FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.alwaysTraditional;
  });

  tearDown(() {
    FocusManager.instance.highlightStrategy = FocusHighlightStrategy.automatic;
  });

  for (final entry in _cases.entries) {
    final name = entry.key;
    final c = entry.value;

    for (final (mode, theme, ring) in [
      ('light', AppTheme.lightTheme, AppColors.focusRing),
      ('dark', AppTheme.darkTheme, AppColorsDark.focusRing),
    ]) {
      testWidgets('$name: keyboard focus draws the $mode ring outside a '
          '48 dp box', (tester) async {
        await _pump(tester, c.build(), theme: theme);
        await _tabInto(tester);

        final rect = tester.getRect(c.box());
        expect(rect.width, greaterThanOrEqualTo(48), reason: 'hit width');
        expect(rect.height, greaterThanOrEqualTo(48), reason: 'hit height');
        for (final p in _ringPoints(rect)) {
          expect(await _pixel(tester, p), ring, reason: '$name at $p');
        }
      });
    }

    testWidgets('$name: touch focus draws no ring', (tester) async {
      FocusManager.instance.highlightStrategy =
          FocusHighlightStrategy.alwaysTouch;
      await _pump(tester, c.build());
      await _tabInto(tester);

      final rect = tester.getRect(c.box());
      for (final p in _ringPoints(rect)) {
        expect(
          await _pixel(tester, p),
          isNot(AppColors.focusRing),
          reason: '$name at $p',
        );
      }
    });
  }

  // A card rings only for its own focus: a heart or menu inside it rings
  // just that button (lib/widgets/recipe/recipe_card.dart).
  testWidgets('ancestor ring: focus on a control inside draws no ring '
      'around the whole', (tester) async {
    final cardNode = FocusNode(debugLabel: 'card');
    final heartNode = FocusNode(debugLabel: 'heart');
    addTearDown(cardNode.dispose);
    addTearDown(heartNode.dispose);
    await _pump(
      tester,
      InkWell(
        focusNode: cardNode,
        onTap: () {},
        child: ButleryAncestorFocusRing(
          child: SizedBox(
            width: 200,
            height: 100,
            child: Align(
              alignment: Alignment.topRight,
              child: IconButton(
                focusNode: heartNode,
                onPressed: () {},
                icon: const Icon(Icons.favorite_border),
              ),
            ),
          ),
        ),
      ),
    );

    bool? cardRing() => tester
        .widget<ButleryFocusRing>(
          find
              .descendant(
                of: find.byType(ButleryAncestorFocusRing),
                matching: find.byType(ButleryFocusRing),
              )
              .first,
        )
        .focused;

    heartNode.requestFocus();
    await tester.pumpAndSettle();
    expect(heartNode.hasPrimaryFocus, isTrue);
    expect(cardRing(), isFalse, reason: 'the heart has focus, not the card');

    cardNode.requestFocus();
    await tester.pumpAndSettle();
    expect(cardRing(), isTrue, reason: 'the card itself has focus');

    heartNode.requestFocus();
    await tester.pumpAndSettle();
    expect(cardRing(), isFalse, reason: 'focus moved back into the card');
  });

  testWidgets('menu item: keyboard focus draws the ring around the row', (
    tester,
  ) async {
    await _pump(
      tester,
      PopupMenuButton<int>(
        itemBuilder: (_) => const [
          ButleryMenuItem(value: 1, child: Text('Redigera')),
          ButleryMenuItem(value: 2, child: Text('Radera')),
        ],
      ),
    );
    await tester.tap(find.byType(PopupMenuButton<int>));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();

    final rect = tester.getRect(find.byType(ButleryMenuItem<int>).first);
    expect(rect.height, greaterThanOrEqualTo(48));
    // The row fills the menu's width, so read the ring above the row.
    expect(
      await _pixel(
        tester,
        Offset(rect.center.dx, rect.top - ButleryFocusRing.inflate),
      ),
      AppColors.focusRing,
    );
  });

  test('the grip removes every focus tint, saffron included', () {
    for (final base in [AppTheme.lightTheme, AppTheme.darkTheme]) {
      final t = ButleryControlFocus.themeWithoutFocusTint(base);
      const focused = {WidgetState.focused};
      expect(t.focusColor.a, 0);
      expect(t.checkboxTheme.overlayColor!.resolve(focused)!.a, 0);
      expect(t.switchTheme.overlayColor!.resolve(focused)!.a, 0);
      expect(t.radioTheme.overlayColor!.resolve(focused)!.a, 0);
      expect(t.tabBarTheme.overlayColor!.resolve(focused)!.a, 0);
      // A press keeps whatever the theme answers.
      expect(
        t.checkboxTheme.overlayColor!.resolve({WidgetState.pressed}),
        base.checkboxTheme.overlayColor?.resolve({WidgetState.pressed}),
      );
    }
  });

  testWidgets('personal tags: the empty state is the shared StateWidget', (
    tester,
  ) async {
    await _pump(
      tester,
      SizedBox(
        width: 360,
        child: PersonalTagFilterChipsWidget(
          tags: const <PersonalTag>[],
          selectedTagIds: const {},
          onToggle: (_) {},
          onManageTags: () {},
        ),
      ),
    );
    expect(find.byType(StateWidget), findsOneWidget);
    expect(find.text('Inga personliga taggar'), findsOneWidget);
    expect(find.text('Skapa personliga taggar'), findsOneWidget);
  });
}
