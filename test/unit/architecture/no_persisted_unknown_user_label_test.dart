import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// A localized "unknown user" label written into a document is shown in the
// WRITER's language to every reader. Writers store '' and readers resolve the
// label themselves (stored_display_name.dart), so the label may only appear in
// reader-side code and in push builders that render per language.
const _allowlist = <String, String>{
  'lib/core/utils/stored_display_name.dart':
      'the reader helper that recognises the labels of every locale',
  'lib/core/mixins/json_serializable_mixin.dart':
      'the literal only appears in a doc-comment example',
  'lib/models/messaging/conversation.dart':
      'reader: getDisplayTitle resolves the label when it is shown',
  'lib/models/shared_shopping_list.dart':
      'reader: shared-by and originally-shared-by lines',
  'lib/models/shared_menu.dart':
      'reader: builds the import note on the importing device',
  'lib/services/unified/unified_menu_service.dart':
      'reader: builds the attribution text on the importing device',
  'lib/services/messaging/message_sending_operations.dart':
      'push text built at send time; never stored on the message',
  'lib/services/notifications/fcm_service.dart':
      'reader: resolves the share-request sender in the recipient language',
  'lib/services/social/modules/recipe_share_request_module.dart':
      'push builder: each language slot uses its own localization',
  'lib/services/unified/operations/friends_management_operations.dart':
      'push builder: per-locale variables, nothing is persisted',
  'lib/services/unified/operations/modules/comment_notifications.dart':
      'push builder: per-locale variables and summary text, nothing is persisted',
  'lib/services/unified/operations/modules/rating_notifications.dart':
      'push builder: rater name resolved per language slot',
  'lib/services/unified/operations/modules/recipe_member_manager.dart':
      'push builder: per-locale variables, nothing is persisted',
  'lib/services/unified/operations/modules/recipe_sharing_manager.dart':
      'push builder: per-locale variables, nothing is persisted',
  'lib/views/social/collaborative_shopping/collaborative_shopping_header.dart':
      'reader: active shopper presence line',
  'lib/views/social/collaborative_shopping/collaborative_shopping_items.dart':
      'reader: assignee section title and claim conflict message',
  'lib/views/unified_shopping/widgets/dialogs/shopping_list_operations.dart':
      'reader: friend rows and not-invited summary',
  'lib/widgets/cooking/cooking_session_card.dart':
      'reader: cooking-together names',
  'lib/widgets/messaging/new_conversation_dialog.dart':
      'reader: friend rows and group chat title',
  'lib/utils/shopping_list_live_share.dart':
      'reader: builds the not-invited summary line shown to the inviter',
  'lib/viewmodels/group_detail_viewmodel.dart':
      'reader: member name in the group chat member list',
  'lib/viewmodels/realtime/participant_tracker.dart':
      'reader: in-memory display name for participants',
  'lib/viewmodels/social_recipe/social_profile_manager.dart':
      'reader: comment author name shown in the recipe view',
  'lib/views/realtime/recipe_suggestion_view.dart':
      'reader: suggester name in the suggestion sentence',
  'lib/views/social/menu_preview_view.dart': 'reader: shared-by line',
  'lib/views/social/shared_with_me/shared_content_actions.dart':
      'reader: hide-confirmation text',
  'lib/views/social/shared_with_me/shared_menu_card.dart':
      'reader: shared-from subtitle',
  'lib/views/social/shared_with_me/shared_recipe_card.dart':
      'reader: shared-from subtitle',
  'lib/views/social/shared_with_me/shared_shopping_list_card.dart':
      'reader: shared-from subtitle',
  'lib/views/unified_shopping/widgets/dialogs/shopping_member_management_dialog.dart':
      'reader: member rows',
  'lib/views/unified_shopping/widgets/dialogs/shopping_sharing_status_dialog.dart':
      'reader: owner and member rows',
  'lib/widgets/messaging/conversation_list_item.dart':
      'reader: last-message preview',
  'lib/widgets/messaging/message_bubble.dart':
      'reader: sender name and reply preview',
  'lib/widgets/messaging/reply_banner.dart': 'reader: replying-to line',
  'lib/widgets/social/groups/shared_content_card.dart':
      'reader: shared-by line',
};

final _label = RegExp(
  r'displayUnknownUser|shoppingUnknownUser|Okänd användare|Unknown user',
);

void main() {
  test('no writer persists the unknown-user label', () {
    final offenders = <String>[];
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final path = entity.path.replaceAll(r'\', '/');
      if (path.startsWith('lib/l10n/')) continue;
      if (_allowlist.containsKey(path)) continue;
      if (_label.hasMatch(entity.readAsStringSync())) offenders.add(path);
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'Store an empty name and resolve the label where it is shown '
          '(knownStoredName / storedNameOr). If the file is a reader or a '
          'push builder, add it to the allowlist with a reason.',
    );
  });

  test('every allowlist entry still uses a label', () {
    final stale = <String>[];
    for (final path in _allowlist.keys) {
      final file = File(path);
      if (!file.existsSync() || !_label.hasMatch(file.readAsStringSync())) {
        stale.add(path);
      }
    }
    expect(stale, isEmpty, reason: 'Remove entries that no longer apply.');
  });
}
