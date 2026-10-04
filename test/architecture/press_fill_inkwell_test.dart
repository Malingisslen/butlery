// Every InkWell under lib/ gives its press and hover the fill of the surface
// it rests on (BUT-2205): it sits directly inside a PressFill, or it sets
// its own overlayColor. The InkWells listed below do neither yet, each for
// a reason named beside it; the list may only shrink.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

final _inkWell = RegExp(r'(?<![\w.])(InkWell|InkResponse)\(');

/// InkWells per file that carry no fill of their own yet.
const _waiting = <String, int>{
  // Rests on surface.raised: the theme's default fill becomes the step on
  // raised in the last part of BUT-2205.
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
  // Hidden: a fill painted above the ink layer covers the press, so these
  // show no press today; BUT-2205 moves the fill under the ink.
  'lib/views/menu_placement/placement_widgets.dart': 4,
  'lib/views/pantry/add_pantry_item_sheet.dart': 1,
  'lib/views/pantry/pantry_item_card.dart': 1,
  'lib/widgets/common/profile/builders/menu_item_builders.dart': 1,
  'lib/widgets/common/search_filter/quick_filter_chips.dart': 1,
  'lib/widgets/common/share_dialog/share_mode_selection.dart': 2,
  'lib/widgets/cooking/cooking_session_card.dart': 1,
  'lib/widgets/import/voice_section_card.dart': 1,
  'lib/widgets/recipe/comment_form_widget.dart': 1,
  'lib/widgets/recipe/comment_image_attachments.dart': 1,
  'lib/widgets/social/ping_compose_sheet.dart': 2,
  'lib/widgets/styled/styled_card.dart': 1,
  'lib/widgets/user/user_avatar_widgets.dart': 2,
  // Mixed: a tab with its own drawn press (paper at the on-ink 0.18 step)
  // and the saffron add button, a surface the rule does not cover (BUT-2232).
  'lib/widgets/common/navigation/butlery_bottom_navigation.dart': 2,
  // Raised, or cs.error when the action is destructive (BUT-2232).
  'lib/widgets/image/components/edit_actions_panel.dart': 1,
  // Mixed: one on surface.raised and one hidden.
  'lib/widgets/image/components/upload_progress_widgets.dart': 2,
  // A surface the rule does not cover, for the design session (BUT-2232):
  // saffron, the warning tint, the recipe photo and the scanned page.
  'lib/views/lagg_till_recept_view.dart': 1,
  'lib/views/recipe_detail_view.dart': 1,
  'lib/widgets/common/layout/status_indicators.dart': 1,
  'lib/widgets/recipe/heirloom_section.dart': 1,
  // Never pressed: onTap is null at every caller, or the widget has none.
  'lib/widgets/cooking/substitution_bottom_sheet.dart': 1,
  'lib/widgets/social/collaborative/components/collaborative_permissions_widgets.dart':
      1,
  'lib/widgets/social/collaborative/components/collaborative_status_widgets.dart':
      1,
  'lib/widgets/recipe/comment_item_widget.dart': 2,
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

/// The lines of the InkWells in [code] that sit in no PressFill and set no
/// overlayColor.
List<int> inkWellsWithoutFill(String code) {
  final lines = <int>[];
  for (final m in _inkWell.allMatches(code)) {
    final before = code.substring(0, m.start);
    final call = _call(code, m.end - 1);
    var depth = 0;
    var ownOverlay = false;
    for (var i = 0; i < call.length; i++) {
      if ('([{'.contains(call[i])) depth++;
      if (')]}'.contains(call[i])) depth--;
      if (depth == 1 && call.startsWith('overlayColor:', i)) ownOverlay = true;
    }
    final open = before.lastIndexOf('PressFill(');
    var pfDepth = 0;
    var closed = false;
    if (open >= 0) {
      for (final c in before.substring(open + 'PressFill'.length).split('')) {
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
