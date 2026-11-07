import 'package:butlery/core/utils/stored_display_name.dart';
import 'package:butlery/core/l10n/app_locale.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/services/unified/unified_friends_service.dart';

/// Invites [userIds] to the live shopping list [listId] at [permission]
/// (BUT-2089); nobody is seated by the sharer, each friend joins by accepting.
///
/// Returns the one line to show when some could not be invited, or null when
/// there is nothing to add. Not a friend and a block share that line, so the
/// sharer never learns which it was. Throws when the invitation call did not go
/// through at all.
Future<String?> inviteToLiveShoppingList({
  required String listId,
  required List<String> userIds,
  required String permission,
}) async {
  final friends = ServiceLocator.get<UnifiedFriendsService>();
  final summary = await friends.invitations.listInvitations.invite(
    listId: listId,
    userIds: userIds,
    permission: permission,
  );
  if (summary.callFailed) {
    throw Exception(AppLocale.current.errorCouldNotSendInvitations);
  }
  return notInvitedNotice(summary.notInvited);
}

/// The one line for friends an invitation did not reach, or null when there
/// are none.
String? notInvitedNotice(List<String> notInvited) {
  if (notInvited.isEmpty) return null;
  final friends = ServiceLocator.get<UnifiedFriendsService>();
  // A group's members are invited too, and someone who is not a friend has
  // no name here; they are still counted in the line.
  final names = {for (final f in friends.friends) f.uid: f.displayName};
  return AppLocale.current.listInviteNotInvited(
    notInvited
        .map(
          (id) =>
              storedNameOr(names[id], AppLocale.current.shoppingUnknownUser),
        )
        .join(', '),
  );
}
