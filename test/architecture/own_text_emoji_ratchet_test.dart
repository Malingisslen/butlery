// B-44: Butlery's own texts carry no emoji. The ARB scan and the list of own
// text sources in decision_guards_b01_b55_rest_test.dart cannot see a string
// typed into a view or widget, so this pins every line in lib/views and
// lib/widgets that holds a pictograph. What is left is log output and group
// emoji the user picks (content, not Butlery's text); the number only falls.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _pinned = <String, int>{
  'lib/views/messaging/chat_view/chat_action_handler.dart': 14,
  'lib/views/messaging/chat_view/chat_input_section.dart': 8,
  'lib/views/mina_recept_view.dart': 7,
  'lib/views/skriv_sjalv_recept_view.dart': 5,
  'lib/views/social/friends_list/friends_list_cards.dart': 1,
  'lib/views/social/friends_list/group_invitation_card.dart': 7,
  'lib/views/social/user_profile_edit_view.dart': 6,
  'lib/widgets/common/dialogs/menu_selection_dialog.dart': 7,
  'lib/widgets/common/share_dialog/share_target_selection_enhanced.dart': 1,
  'lib/widgets/image/components/image_grid_widgets.dart': 4,
  'lib/widgets/image/image_components.dart': 2,
  'lib/widgets/image/image_picker_dialogs.dart': 6,
  'lib/widgets/image/universal_image_manager.dart': 1,
  'lib/widgets/social/groups/edit_group_dialog.dart': 1,
  'lib/widgets/social/groups/group_draft_codec.dart': 1,
  'lib/widgets/social/groups/shared/group_dialog_components.dart': 20,
};

// The dingbat and symbol blocks (check, cross, sparkles, warning) are
// included; the plain symbols U+2605, U+2610 and U+2611 are glyphs, as in
// the ARB scan.
final _pictograph = RegExp(
  '[\u{1F300}-\u{1FAFF}\u{1F000}-\u{1F2FF}\u2B50\u23F1\uFE0F]'
  '|(?![\u2605\u2610\u2611])[\u2600-\u27BF]',
  unicode: true,
);

String _code(String path) => File(path)
    .readAsStringSync()
    .replaceAll('\r\n', '\n')
    .replaceAll(RegExp(r'/\*[\s\S]*?\*/'), '')
    .replaceAll(RegExp(r'(?<!:)//[^\n]*'), '');

void main() {
  test('no view or widget gains a line with an emoji', () {
    final counts = <String, int>{};
    for (final root in ['lib/views', 'lib/widgets']) {
      for (final file in Directory(root).listSync(recursive: true)) {
        if (file is! File || !file.path.endsWith('.dart')) continue;
        final path = file.path.replaceAll(r'\', '/');
        final n = _code(path).split('\n').where(_pictograph.hasMatch).length;
        if (n > 0) counts[path] = n;
      }
    }
    expect(counts, _pinned);
  });
}
