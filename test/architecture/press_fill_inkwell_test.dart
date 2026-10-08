// Every InkWell under lib/ gives its press and hover the fill of the surface
// it rests on (BUT-2205): it sits directly inside a PressFill, or it sets
// its own overlayColor. The InkWells listed below do neither, each for a
// reason named beside it; the list may only shrink.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

final _inkWell = RegExp(r'(?<![\w.])(InkWell|InkResponse)\(');
final _fab = RegExp(r'(?<![\w.])FloatingActionButton(\.\w+)?\(');

/// InkWells per file that carry no fill of their own.
const _waiting = <String, int>{
  // Rests on surface.raised: the theme's default fill is the step on raised.
  'lib/views/admin/feedback_inbox_view.dart': 1,
  'lib/views/social/friend_requests/friend_request_card.dart': 2,
  'lib/views/social/public_profile_view.dart': 1,
  'lib/views/unified_shopping/widgets/shopping_item_tiles.dart': 1,
  'lib/widgets/common/cards/selection_card.dart': 1,
  'lib/widgets/common/dialogs/draft_recovery_dialog.dart': 1,
  'lib/widgets/common/friends/category_display_widgets.dart': 2,
  'lib/widgets/common/social_components/invitation_lists.dart': 2,
  'lib/widgets/common/social_components/social_builder_components.dart': 1,
  'lib/widgets/image/components/empty_image_state.dart': 1,
  'lib/widgets/image/image_gallery_widget.dart': 1,
  'lib/widgets/image/image_picker_widget.dart': 1,
  'lib/widgets/menu/menu_content_widgets.dart': 1,
  'lib/widgets/social/groups/shared_content_card.dart': 1,
  // A tab with its own drawn press (paper at the on-ink 0.18 step).
  'lib/widgets/common/navigation/butlery_bottom_navigation.dart': 1,
  // Raised, or cs.error when the action is destructive (BUT-2232).
  'lib/widgets/image/components/edit_actions_panel.dart': 1,
  // One on surface.raised.
  'lib/widgets/image/components/upload_progress_widgets.dart': 1,
  // A surface the rule does not cover, for the design session (BUT-2232):
  // the danger tint, a photo, and a send button
  // that is paper in dark mode.
  'lib/widgets/common/profile/builders/menu_item_builders.dart': 1,
  'lib/widgets/recipe/comment_form_widget.dart': 1,
  'lib/widgets/social/ping_compose_sheet.dart': 1,
  // Never pressed: onTap is null at every caller, or the widget has none.
  'lib/widgets/cooking/substitution_bottom_sheet.dart': 1,
  'lib/widgets/social/collaborative/components/collaborative_permissions_widgets.dart':
      1,
  'lib/widgets/social/collaborative/components/collaborative_status_widgets.dart':
      1,
  'lib/widgets/recipe/comment_item_widget.dart': 2,
  'lib/widgets/styled/styled_card.dart': 1,
  // Mixed: one on surface.raised and one with no live caller.
  'lib/widgets/user/user_layout_widgets.dart': 2,
};

String _call(String code, int open) {
  var depth = 0;
  for (var i = open; i < code.length; i++) {
    if ('([{'.contains(code[i])) depth++;
    if (')]}'.contains(code[i])) depth--;
    if (depth == 0) return code.substring(open, i + 1);
  }
  return code.substring(open);
}

/// The lines of the InkWells (or other [calls]) in [code] that sit in no
/// [wrapper] and set no overlayColor.
List<int> inkWellsWithoutFill(
  String code, {
  RegExp? calls,
  String wrapper = 'PressFill',
}) {
  final lines = <int>[];
  for (final m in (calls ?? _inkWell).allMatches(code)) {
    final before = code.substring(0, m.start);
    final call = _call(code, m.end - 1);
    var depth = 0;
    var ownOverlay = false;
    for (var i = 0; i < call.length; i++) {
      if ('([{'.contains(call[i])) depth++;
      if (')]}'.contains(call[i])) depth--;
      if (depth == 1 && call.startsWith('overlayColor:', i)) ownOverlay = true;
    }
    final open = before.lastIndexOf('$wrapper(');
    var pfDepth = 0;
    var closed = false;
    if (open >= 0) {
      for (final c in before.substring(open + wrapper.length).split('')) {
        if ('([{'.contains(c)) pfDepth++;
        if (')]}'.contains(c)) pfDepth--;
        if (pfDepth == 0) closed = true;
      }
    }
    final wrapped =
        open >= 0 &&
        !closed &&
        pfDepth == 1 &&
        RegExp(r'child:\s*$').hasMatch(before);
    if (!ownOverlay && !wrapped) {
      lines.add('\n'.allMatches(before).length + 1);
    }
  }
  return lines;
}

/// The lines of the FloatingActionButtons in [code] whose nearest PressFill
/// is not on ink.
List<int> fabsOffInk(String code) {
  final lines = <int>[];
  for (final m in _fab.allMatches(code)) {
    final before = code.substring(0, m.start);
    final open = before.lastIndexOf('PressFill(');
    final args = open < 0 ? '' : before.substring(open);
    if (!RegExp(r'surface:\s*PressSurface\.ink').hasMatch(args)) {
      lines.add('\n'.allMatches(before).length + 1);
    }
  }
  return lines;
}

void main() {
  test('every InkWell under lib/ carries its pressed fill, or is listed', () {
    final found = <String, List<int>>{};
    for (final f in Directory('lib').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      final code = f.readAsStringSync().replaceAll(
        RegExp(r'(?<!:)//[^\n]*'),
        '',
      );
      final lines = inkWellsWithoutFill(code);
      if (lines.isNotEmpty) found[f.path.replaceAll('\\', '/')] = lines;
    }
    final unexpected = <String>[
      for (final e in found.entries)
        if (e.value.length > (_waiting[e.key] ?? 0))
          '${e.key} ${e.value} (listed ${_waiting[e.key] ?? 0})',
    ];
    final stale = <String>[
      for (final e in _waiting.entries)
        if ((found[e.key]?.length ?? 0) < e.value)
          '${e.key} listed ${e.value}, found ${found[e.key]?.length ?? 0}',
    ];
    if (unexpected.isNotEmpty) {
      fail('Wrap these in PressFill:\n${unexpected.join('\n')}');
    }
    if (stale.isNotEmpty) {
      fail('Lower these counts in _waiting:\n${stale.join('\n')}');
    }
  });

  // The surfaces left to the design session keep their old press and hover
  // (BUT-2232). The destructive image action is pinned by a widget test,
  // since a condition picks its wrapper.
  test('the design-session surfaces sit in PressUnchanged', () {
    const unchanged = <String, int>{
      'lib/widgets/recipe/comment_form_widget.dart': 1,
    };
    final missing = <String>[];
    for (final e in unchanged.entries) {
      final code = File(e.key).readAsStringSync().replaceAll(
        RegExp(r'(?<!:)//[^\n]*'),
        '',
      );
      final all = _inkWell.allMatches(code).length;
      final bare = inkWellsWithoutFill(code, wrapper: 'PressUnchanged').length;
      if (all - bare < e.value) missing.add('${e.key}: ${all - bare}');
    }
    expect(missing, isEmpty, reason: 'Wrap these in PressUnchanged');
  });

  test('the scan reads the wrapper it is given', () {
    expect(
      inkWellsWithoutFill(
        'PressUnchanged(child: InkWell(onTap: t))',
        wrapper: 'PressUnchanged',
      ),
      isEmpty,
    );
    expect(inkWellsWithoutFill('PressUnchanged(child: InkWell(onTap: t))'), [
      1,
    ]);
  });

  // A FloatingActionButton takes the theme's highlight, and every one rests
  // on ink, so each sits in a PressFill on ink.
  test('every FloatingActionButton under lib/ sits in a PressFill', () {
    final found = <String>[];
    for (final f in Directory('lib').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      final code = f.readAsStringSync().replaceAll(
        RegExp(r'(?<!:)//[^\n]*'),
        '',
      );
      for (final line in inkWellsWithoutFill(code, calls: _fab)) {
        found.add('${f.path.replaceAll('\\', '/')}:$line');
      }
      for (final line in fabsOffInk(code)) {
        found.add('${f.path.replaceAll('\\', '/')}:$line not on ink');
      }
    }
    expect(found, isEmpty, reason: 'Wrap these in PressFill(ink)');
  });

  test('the scan tells a wrapped FloatingActionButton from a bare one', () {
    expect(
      inkWellsWithoutFill(
        'PressFill(surface: PressSurface.ink, child: '
        'FloatingActionButton.extended(onPressed: t))',
        calls: _fab,
      ),
      isEmpty,
    );
    expect(
      inkWellsWithoutFill('FloatingActionButton(onPressed: t)', calls: _fab),
      [1],
    );
    expect(
      fabsOffInk(
        'PressFill(surface: PressSurface.raised, child: '
        'FloatingActionButton(onPressed: t))',
      ),
      [1],
    );
    expect(
      fabsOffInk(
        'PressFill(surface: PressSurface.ink, child: '
        'FloatingActionButton(onPressed: t))',
      ),
      isEmpty,
    );
  });

  test('the scan tells a wrapped or overlaid InkWell from a bare one', () {
    expect(
      inkWellsWithoutFill(
        'PressFill(surface: PressSurface.base, child: InkWell(onTap: t))',
      ),
      isEmpty,
    );
    expect(
      inkWellsWithoutFill('InkWell(overlayColor: o, onTap: t)'),
      isEmpty,
    );
    expect(inkWellsWithoutFill('InkWell(onTap: t)'), [1]);
    expect(
      inkWellsWithoutFill(
        'PressFill(surface: s, child: a),\nPadding(child: InkWell(onTap: t))',
      ),
      [2],
    );
  });
}
