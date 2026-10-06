/// P8-U06: the 33 REQUIRED control states of fas2/block288-uxfrysning.json
/// interaktion (vendored as test/fixtures/design/block288-interaktion.json,
/// INTERACTION_SET_HASH pinned), in light and dark, reached through real
/// input.
///
/// For every row the app's control for that role is pumped under
/// AppTheme.lightTheme and AppTheme.darkTheme and brought into the state the
/// way a user would: Tab for FOCUSED, a held press for PRESSED, a tap for
/// SELECTED, EXPANDED and COLLAPSED, and a control built without a handler
/// for DISABLED. Then five checks:
///
/// - semantics: the flag of that state (isFocused, isSelected, isChecked,
///   isToggled, isExpanded, isEnabled false), or the role for DEFAULT. An
///   open combobox is the exception: its list is a modal route, which takes
///   the page and the combobox out of the semantics tree, so the check is
///   that a menu that names its route is in the tree with a focused item;
/// - hitbox: at least 48 x 48 dp (tokens.json touchTarget.min);
/// - visible: the state paints differently from the state it is told apart
///   from (DEFAULT, or EXPANDED for COLLAPSED), and among the changed pixels
///   is a colour of the generated palette (lib/theme/app_colors.dart,
///   app_colors_dark.dart). DEFAULT itself must paint a palette colour;
/// - contrast: a disabled label reads at least 3:1 against what it stands on
///   (tokens.json contrastPolicy.floors.disabled);
/// - reached: the state could be reached by that input at all;
/// - ring: FOCUSED paints the canonical focus ring colour, not a tint alone.
///
/// Which app widget stands for a role is the interpretation, recorded in
/// test/widget/design_states/interaction_census.json.
///
/// Checks that fail today are listed, with a ticket, in
/// known_interaction_findings.dart. The list only shrinks: a new failure
/// fails the test, and so does a listed failure that has been fixed.
///
/// Existing coverage is referenced, not repeated: the ring's geometry and
/// colour in test/widget/common/butlery_control_focus_test.dart, the disabled
/// colours in test/unit/theme/disabled_state_theme_test.dart.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/services/shopping/menu_shopping_list_generator.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_colors_dark.dart';
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/widgets/common/butlery_control_focus.dart';
import 'package:butlery/widgets/common/butlery_search_box.dart';
import 'package:butlery/widgets/common/buttons/hero_button.dart';
import 'package:butlery/widgets/common/input/debounced_checkbox.dart';
import 'package:butlery/widgets/common/linkified_text.dart';
import 'package:butlery/widgets/common/search_filter/filter_chips_widget.dart';
import 'package:butlery/widgets/common/search_filter/filter_models.dart';
import 'package:butlery/widgets/menu/shopping_merge_sheet.dart';

import 'known_interaction_findings.dart';

final _boundary = GlobalKey();

// ─── palette ────────────────────────────────────────────────────────────

/// The opaque colours of the generated palette, read from the generated
/// files themselves so the test never restates a value.
final Set<int> _palette = () {
  final hex = RegExp(r'Color\(0x([0-9A-Fa-f]{8})\)');
  final out = <int>{};
  for (final path in [
    'lib/theme/app_colors.dart',
    'lib/theme/app_colors_dark.dart',
  ]) {
    for (final m in hex.allMatches(File(path).readAsStringSync())) {
      final v = int.parse(m.group(1)!, radix: 16);
      if ((v >> 24) == 0xFF) out.add(v);
    }
  }
  return out;
}();

// ─── pixels ─────────────────────────────────────────────────────────────

class _Shot {
  _Shot(this.data, this.width, this.height);
  final ByteData data;
  final int width;
  final int height;

  int at(int x, int y) {
    final i = (y * width + x) * 4;
    return (data.getUint8(i + 3) << 24) |
        (data.getUint8(i) << 16) |
        (data.getUint8(i + 1) << 8) |
        data.getUint8(i + 2);
  }
}

Future<_Shot> _shoot(WidgetTester tester) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(_boundary),
  );
  final shot = await tester.runAsync(() async {
    final image = await boundary.toImage();
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    final result = _Shot(data!, image.width, image.height);
    image.dispose();
    return result;
  });
  return shot!;
}

Iterable<(int, int)> _pixels(_Shot s, Rect r) sync* {
  final left = math.max(0, r.left.floor());
  final top = math.max(0, r.top.floor());
  final right = math.min(s.width, r.right.ceil());
  final bottom = math.min(s.height, r.bottom.ceil());
  for (var y = top; y < bottom; y++) {
    for (var x = left; x < right; x++) {
      yield (x, y);
    }
  }
}

/// Palette colours among the pixels of [after] that differ from [before].
Set<int> _changedPalette(_Shot before, _Shot after, Rect r) => {
  for (final (x, y) in _pixels(after, r))
    if (before.at(x, y) != after.at(x, y) && _palette.contains(after.at(x, y)))
      after.at(x, y),
};

int _changedCount(_Shot before, _Shot after, Rect r) => _pixels(
  after,
  r,
).where((p) => before.at(p.$1, p.$2) != after.at(p.$1, p.$2)).length;

/// Palette colours painted in [r], other than the page behind the control.
Set<int> _paintedPalette(_Shot s, Rect r, int page) => {
  for (final (x, y) in _pixels(s, r))
    if (s.at(x, y) != page && _palette.contains(s.at(x, y))) s.at(x, y),
};

/// The colour behind a text: the most common one in a 6 px band around its
/// box, where the glyphs are not.
int _mostCommonAround(_Shot s, Rect inner) {
  final outer = inner.inflate(6);
  final counts = <int, int>{};
  for (final (x, y) in _pixels(s, outer)) {
    if (inner.contains(Offset(x + 0.5, y + 0.5))) continue;
    final c = s.at(x, y);
    counts[c] = (counts[c] ?? 0) + 1;
  }
  return counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
}

double _luminance(int argb) {
  double channel(int c) {
    final v = c / 255.0;
    return v <= 0.03928
        ? v / 12.92
        : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  }

  return 0.2126 * channel((argb >> 16) & 0xFF) +
      0.7152 * channel((argb >> 8) & 0xFF) +
      0.0722 * channel(argb & 0xFF);
}

double _contrast(int a, int b) {
  final la = _luminance(a);
  final lb = _luminance(b);
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

/// [fg] over the opaque [bg].
int _over(Color fg, int bg) {
  final a = fg.a;
  int mix(double f, int b) => ((f * 255.0) * a + b * (1 - a)).round();
  return 0xFF000000 |
      (mix(fg.r, (bg >> 16) & 0xFF) << 16) |
      (mix(fg.g, (bg >> 8) & 0xFF) << 8) |
      mix(fg.b, bg & 0xFF);
}

// ─── controls ───────────────────────────────────────────────────────────

/// The width a control is laid out in, a phone column.
const double _hostWidth = 320;

/// One app control standing for a role.
class _Control {
  const _Control({
    required this.build,
    required this.target,
    this.box,
    this.label,
    this.prepare,
    this.focusTarget,
    this.focusKey = LogicalKeyboardKey.tab,
  });

  /// Where keyboard focus lands for FOCUSED (defaults to [target]). In a
  /// radio group only the chosen radio is in the Tab order.
  final Finder Function()? focusTarget;

  /// The key a user presses to move focus there: Tab, or the arrow keys
  /// inside an open menu.
  final LogicalKeyboardKey focusKey;

  /// The control as a view places it. It keeps its own state, so a tap
  /// selects it as it would in the app.
  final Widget Function({required bool enabled}) build;

  /// The widget whose semantics node carries the role and the state.
  final Finder Function() target;

  /// The tap target measured for the 48 dp rule (defaults to [target]).
  final Finder Function()? box;

  /// The visible label read for the disabled contrast.
  final String? label;

  /// What a user does before the control is on screen (open a sheet or a
  /// menu).
  final Future<void> Function(WidgetTester tester)? prepare;
}

Widget _stateful<T>(
  T initial,
  Widget Function(T value, void Function(T) set) b,
) {
  var value = initial;
  return StatefulBuilder(
    builder: (context, setState) => b(value, (v) => setState(() => value = v)),
  );
}

final _mergeSource = MenuShoppingListGenerator.sourceForMenu({
  'Middag': [
    Recipe(
      core: RecipeCore(
        id: 'r1',
        title: 'r1',
        description: '',
        ingredients: const ['1 gul lök'],
        instructions: const ['x'],
        mealType: 'Middag',
      ),
      type: RecipeType.personal,
    ),
  ],
}, DateTime(2026, 6, 10));

final _controls = <String, _Control>{
  // The view's one saffron action (Komponentark v1:370-373, :843-844).
  'button': _Control(
    build: ({required enabled}) =>
        HeroButton(label: 'Spara', onPressed: enabled ? () {} : null),
    target: () => find.byType(HeroButton),
    label: 'Spara',
  ),
  // A filter chip: a button that can be selected (Komponentark v1:139-146).
  'button.selected': _Control(
    build: ({required enabled}) => _stateful<Set<String>>(
      const {},
      (value, set) => FilterChipsWidget(
        title: 'Kost',
        options: const [FilterOption(id: 'veg', label: 'Vegetariskt')],
        activeFilters: value,
        onToggle: (id) => set(value.contains(id) ? {} : {id}),
      ),
    ),
    target: () => find.text('Vegetariskt'),
    box: () => find.byType(ButleryControlFocus).first,
  ),
  // "Visa detaljer" in the merge sheet (#inkopmerge), the app's own
  // expanding button.
  'button.expand': _Control(
    build: ({required enabled}) => Builder(
      builder: (context) => TextButton(
        onPressed: () => showShoppingMergeSheet(
          context,
          source: _mergeSource,
          pantry: const MenuShoppingPantry.read([]),
          retryPantry: () async => const MenuShoppingPantry.read([]),
          canReplace: true,
        ),
        child: const Text('öppna'),
      ),
    ),
    prepare: (tester) async {
      await tester.tap(find.text('öppna'));
      await tester.pumpAndSettle();
    },
    target: () => find.byKey(ShoppingMergeSheet.detailsToggleKey),
  ),
  'checkbox': _Control(
    build: ({required enabled}) => _stateful<bool>(
      false,
      (value, set) =>
          DebouncedCheckbox(value: value, onChanged: (v) => set(v ?? false)),
    ),
    target: () => find.byType(Checkbox),
    box: () => find.byType(ButleryControlFocus).first,
  ),
  // The dropdowns of the recipe form and settings go through the theme.
  'combobox': _Control(
    build: ({required enabled}) => _stateful<String>(
      'Middag',
      (value, set) => DropdownButtonFormField<String>(
        initialValue: value,
        items: const [
          DropdownMenuItem(value: 'Lunch', child: Text('Lunch')),
          DropdownMenuItem(value: 'Middag', child: Text('Middag')),
        ],
        onChanged: enabled ? (v) => set(v ?? value) : null,
      ),
    ),
    target: () => find.byType(DropdownButton<String>),
  ),
  'link': _Control(
    build: ({required enabled}) =>
        LinkifiedText.from('Källa: https://example.com/recept'),
    target: () => find.text('https://example.com/recept'),
  ),
  'menuitem': _Control(
    build: ({required enabled}) => PopupMenuButton<int>(
      itemBuilder: (_) => const [
        ButleryMenuItem(value: 1, child: Text('Spara')),
        ButleryMenuItem(value: 2, child: Text('Rensa')),
      ],
      child: const Padding(padding: EdgeInsets.all(12), child: Text('Mer')),
    ),
    prepare: (tester) async {
      await tester.tap(find.text('Mer'));
      await tester.pumpAndSettle();
    },
    target: () => find.text('Spara'),
    box: () => find.byType(ButleryMenuItem<int>).first,
    focusKey: LogicalKeyboardKey.arrowDown,
  ),
  'radio': _Control(
    build: ({required enabled}) => _stateful<int>(
      1,
      (value, set) => RadioGroup<int>(
        groupValue: value,
        onChanged: (v) => set(v ?? value),
        child: Column(
          children: [
            RadioListTile<int>(
              value: 1,
              enabled: enabled,
              title: const Text('Den här veckan'),
            ),
            RadioListTile<int>(
              value: 2,
              enabled: enabled,
              title: const Text('Nästa vecka'),
            ),
          ],
        ),
      ),
    ),
    target: () => find.widgetWithText(RadioListTile<int>, 'Nästa vecka'),
    focusTarget: () =>
        find.widgetWithText(RadioListTile<int>, 'Den här veckan'),
    label: 'Nästa vecka',
  ),
  'searchbox': _Control(
    build: ({required enabled}) =>
        ButlerySearchBox(hintText: 'Sök recept', enabled: enabled),
    target: () => find.byType(EditableText),
    box: () => find.byType(TextField),
    label: 'Sök recept',
  ),
  'switch': _Control(
    build: ({required enabled}) => _stateful<bool>(
      false,
      (value, set) => SwitchListTile(
        value: value,
        onChanged: enabled ? set : null,
        title: const Text('Påminnelser'),
      ),
    ),
    target: () => find.byType(SwitchListTile),
    label: 'Påminnelser',
  ),
  'tab': _Control(
    build: ({required enabled}) => DefaultTabController(
      length: 2,
      child: TabBar(
        overlayColor: ButleryControlFocus.withoutFocusTint(null),
        tabs: const [
          ButleryTab(text: 'Mina'),
          ButleryTab(text: 'Delade'),
        ],
      ),
    ),
    target: () => find.widgetWithText(ButleryTab, 'Delade'),
  ),
  'textbox': _Control(
    build: ({required enabled}) => TextField(
      enabled: enabled,
      decoration: const InputDecoration(labelText: 'Titel'),
    ),
    target: () => find.byType(EditableText),
    box: () => find.byType(TextField),
    label: 'Titel',
  ),
};

String _controlFor(String role, String state) => switch ((role, state)) {
  ('button', 'SELECTED') => 'button.selected',
  ('button', 'EXPANDED' || 'COLLAPSED') => 'button.expand',
  _ => role,
};

// ─── semantics ──────────────────────────────────────────────────────────

bool _semantics(String role, String state, SemanticsData d) {
  final f = d.flagsCollection;
  switch (state) {
    case 'FOCUSED':
      return f.isFocused == ui.Tristate.isTrue;
    case 'DISABLED':
      return f.isEnabled == ui.Tristate.isFalse;
    case 'EXPANDED':
      return f.isExpanded == ui.Tristate.isTrue;
    case 'COLLAPSED':
      return f.isExpanded == ui.Tristate.isFalse;
    case 'PRESSED':
      return f.isButton && f.isEnabled == ui.Tristate.isTrue;
    case 'SELECTED':
      return switch (role) {
        'checkbox' || 'radio' => f.isChecked == ui.CheckedState.isTrue,
        'switch' => f.isToggled == ui.Tristate.isTrue,
        _ => f.isSelected == ui.Tristate.isTrue,
      };
  }
  // DEFAULT: the role, at rest.
  return switch (role) {
    'button' => f.isButton && f.isEnabled == ui.Tristate.isTrue,
    'checkbox' => f.isChecked == ui.CheckedState.isFalse,
    'combobox' => f.isExpanded == ui.Tristate.isFalse,
    'link' => f.isLink,
    'menuitem' => d.role == SemanticsRole.menuItem || f.isButton,
    'radio' => f.isInMutuallyExclusiveGroup,
    'searchbox' || 'textbox' => f.isTextField,
    'switch' => f.isToggled == ui.Tristate.isFalse,
    'tab' => d.role == SemanticsRole.tab || f.isSelected == ui.Tristate.isFalse,
    _ => false,
  };
}

/// The open list of [combobox] is where a screen reader is: the combobox has
/// left the tree, and a menu that names its route holds a focused item.
/// Reading the combobox's own node here would read a detached copy.
bool _menuAnnounced(WidgetTester tester, SemanticsNode combobox) {
  bool focusedItem(SemanticsNode n) {
    final d = n.getSemanticsData();
    if (d.role == SemanticsRole.menuItem &&
        d.flagsCollection.isFocused == ui.Tristate.isTrue) {
      return true;
    }
    var found = false;
    n.visitChildren((c) => !(found = focusedItem(c)));
    return found;
  }

  bool menu(SemanticsNode n) {
    final d = n.getSemanticsData();
    if (d.role == SemanticsRole.menu &&
        d.flagsCollection.namesRoute &&
        focusedItem(n)) {
      return true;
    }
    var found = false;
    n.visitChildren((c) => !(found = menu(c)));
    return found;
  }

  final view = tester.binding.renderViews.single;
  final root = view.owner!.semanticsOwner!.rootSemanticsNode!;
  return !combobox.attached && menu(root);
}

// ─── the run ────────────────────────────────────────────────────────────

Future<void> _pumpHost(
  WidgetTester tester,
  Widget control,
  ThemeData theme,
  double width,
) async {
  tester.view.physicalSize = const Size(480, 900);
  tester.view.devicePixelRatio = 1.0;
  await tester.pumpWidget(
    RepaintBoundary(
      key: _boundary,
      child: MaterialApp(
        theme: theme,
        locale: const Locale('sv'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(40),
            child: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(width: width, child: control),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<bool> _tabTo(
  WidgetTester tester,
  Finder target,
  LogicalKeyboardKey key,
) async {
  for (var i = 0; i < 8; i++) {
    await tester.sendKeyEvent(key);
    await tester.pumpAndSettle();
    final d = tester.getSemantics(target).getSemanticsData();
    if (d.flagsCollection.isFocused == ui.Tristate.isTrue) return true;
  }
  return false;
}

/// Runs one row in one mode and returns the checks that failed.
Future<Set<String>> _run(
  WidgetTester tester,
  String role,
  String state,
  ThemeData theme,
) async {
  final c = _controls[_controlFor(role, state)]!;
  final failed = <String>{};
  final target = state == 'FOCUSED' ? (c.focusTarget ?? c.target) : c.target;

  await _pumpHost(tester, c.build(enabled: true), theme, _hostWidth);
  if (c.prepare != null) await c.prepare!(tester);
  final page = theme.scaffoldBackgroundColor.toARGB32();
  final ring =
      (theme.brightness == Brightness.dark
              ? AppColorsDark.focusRing
              : AppColors.focusRing)
          .toARGB32();

  Rect region() => tester.getRect((c.box ?? c.target)()).inflate(8);
  var before = await _shoot(tester);
  var reached = true;
  TestGesture? held;

  switch (state) {
    case 'FOCUSED':
      reached = await _tabTo(tester, target(), c.focusKey);
    case 'PRESSED':
      held = await tester.startGesture(tester.getCenter(c.target()));
      await tester.pump(const Duration(milliseconds: 300));
    case 'SELECTED' || 'EXPANDED':
      await tester.tap(c.target());
      await tester.pumpAndSettle();
    case 'COLLAPSED':
      await tester.tap(c.target());
      await tester.pumpAndSettle();
      before = await _shoot(tester); // told apart from EXPANDED
      await tester.tap(c.target());
      await tester.pumpAndSettle();
    case 'DISABLED':
      await _pumpHost(tester, c.build(enabled: false), theme, _hostWidth);
  }

  final node = tester.getSemantics(target());
  if (!reached) failed.add('reached');
  final told = role == 'combobox' && state == 'EXPANDED'
      ? _menuAnnounced(tester, node)
      : _semantics(role, state, node.getSemanticsData());
  if (!told) failed.add('semantics');

  final box = tester.getSize((c.box ?? c.target)());
  if (box.width < 48 || box.height < 48) failed.add('hitbox');

  final after = await _shoot(tester);
  if (state == 'DEFAULT') {
    if (_paintedPalette(after, region(), page).isEmpty) failed.add('visible');
  } else if (_changedCount(before, after, region()) == 0 ||
      _changedPalette(before, after, region()).isEmpty) {
    failed.add('visible');
  } else if (state == 'FOCUSED' &&
      !_changedPalette(before, after, region()).contains(ring)) {
    // Focus is the canonical ring, ink on light and paper on dark
    // (tokens.json:155-160), never a tint alone.
    failed.add('ring');
  }

  if (state == 'DISABLED' && c.label != null) {
    final text = find.text(c.label!).last;
    final paragraph = tester.renderObject<RenderParagraph>(text);
    final fg = paragraph.text.style?.color;
    final bg = _mostCommonAround(after, tester.getRect(text));
    if (fg == null || _contrast(_over(fg, bg), bg) < 3.0) {
      failed.add('contrast');
    }
  }

  await held?.up();
  await tester.pumpAndSettle();
  return failed;
}

const _pinnedHash =
    '34ed0d011c8552877f4f823d8bf0092e5107583b944b0740b7c5403562fa59fd';

Map<String, dynamic> _json(String path) =>
    jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;

void main() {
  final fixture = _json('test/fixtures/design/block288-interaktion.json');
  final all = (fixture['interaktion'] as List).cast<Map<String, dynamic>>();
  final rows = [
    for (final r in all)
      if (r['STATUS'] == 'REQUIRED')
        (
          r['ROW_ID'] as String,
          r['CONTROL_TYPE'] as String,
          r['STATE'] as String,
        ),
  ];
  final census = _json('test/widget/design_states/interaction_census.json');
  final entries = (census['entries'] as List).cast<Map<String, dynamic>>();

  test('the vendored rows still hash to INTERACTION_SET_HASH', () {
    // As tools/block288/uxfrysning.mjs:153 computes it in the design repo.
    final lines = all.map((r) => '${r['ROW_ID']}=${r['STATUS']}').join('\n');
    expect(sha256.convert(utf8.encode(lines)).toString(), _pinnedHash);
    expect(fixture['INTERACTION_SET_HASH'], _pinnedHash);
    expect(census['INTERACTION_SET_HASH'], _pinnedHash);
    expect(all, hasLength(70));
  });

  test('the census is exactly the 33 REQUIRED rows, each with its test or '
      'its ticket', () {
    final ids = [for (final e in entries) e['row_id'] as String];
    expect(ids.toSet(), {for (final r in rows) r.$1});
    expect(ids, hasLength(33));
    final ticket = RegExp(r'^BUT-\d+$');
    bool named(String? t) => t != null && ticket.hasMatch(t);

    for (final e in entries) {
      final id = e['row_id'] as String;
      expect(
        {'TESTED', 'PARTIAL', 'MISSING'},
        contains(e['status']),
        reason: id,
      );
      expect((e['control'] as String?)?.trim(), isNotEmpty, reason: id);
      expect(
        e['test_file'],
        'test/widget/design_states/'
        'interaction_roles_test.dart',
      );
      expect(e['test_name'], '$id (light)');
      if (e['status'] == 'MISSING') {
        expect(
          named(e['ticket'] as String?),
          isTrue,
          reason: '$id is MISSING without a ticket',
        );
        expect((e['reason'] as String?)?.trim(), isNotEmpty, reason: id);
      }
      // A finding in the list is named in the census, and the other way.
      final listed = {
        for (final mode in ['light', 'dark'])
          ?knownInteractionFindings['$id ($mode)']?.ticket,
      };
      final said = e['known_finding'] ?? e['ticket'];
      expect(
        listed.isEmpty ? null : listed.single,
        said,
        reason: '$id: census and known_interaction_findings.dart disagree',
      );
      for (final t in listed) {
        expect(named(t), isTrue, reason: '$id: $t is not a BUT ticket');
      }
      // A row that fails a check today is PARTIAL, never TESTED: TESTED
      // means every check passes.
      if (e['status'] != 'MISSING') {
        expect(
          e['status'],
          listed.isEmpty ? 'TESTED' : 'PARTIAL',
          reason: '$id: a row with a known finding is PARTIAL',
        );
      }
      for (final ref in (e['also'] as List).cast<Map<String, dynamic>>()) {
        final path = ref['file'] as String;
        if (path.endsWith('interaction_roles_test.dart')) continue;
        final text = File(
          path,
        ).readAsStringSync().replaceAll(RegExp(r"'\s*\n\s*'"), '');
        expect(text, contains(ref['name']), reason: '$id cites $path');
      }
    }
    expect(census['unspecified'], hasLength(33));
    expect(census['not_required'], hasLength(4));
  });

  setUp(() {
    FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.alwaysTraditional;
  });
  tearDown(() {
    FocusManager.instance.highlightStrategy = FocusHighlightStrategy.automatic;
  });

  test('the palette is read from the generated files', () {
    expect(_palette.length, greaterThan(40));
  });

  test('33 REQUIRED rows are run', () {
    expect(rows, hasLength(33));
  });

  for (final (id, role, state) in rows) {
    for (final (mode, theme) in [
      ('light', AppTheme.lightTheme),
      ('dark', AppTheme.darkTheme),
    ]) {
      testWidgets('$id ($mode)', (tester) async {
        final handle = tester.ensureSemantics();
        addTearDown(tester.view.reset);
        final failed = await _run(tester, role, state, theme);
        handle.dispose();

        final known = knownInteractionFindings['$id ($mode)'];
        expect(
          failed,
          known?.checks ?? const <String>{},
          reason: known == null
              ? 'new failure: add it to known_interaction_findings.dart '
                    'with a ticket, or fix it'
              : 'the known finding changed (${known.ticket}): a fixed check '
                    'leaves the list, a new one needs its own entry',
        );
      });
    }
  }
}
