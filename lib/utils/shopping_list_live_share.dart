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
  if (summary.notInvited.isEmpty) return null;
  return AppLocale.current.listInviteNotInvited(
    friends.friends
        .where((f) => summary.notInvited.contains(f.uid))
        .map((f) => f.displayName)
        .join(', '),
  );
}
