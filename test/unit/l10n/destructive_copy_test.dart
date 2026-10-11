/// BUT-2366: a destructive button names what disappears, with Radera when the
/// content stops existing and Ta bort when it is lifted out of a list or a
/// relation (content-style-guide.md, Knapptexter).
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/l10n/app_localizations_sv.dart';

void main() {
  final sv = AppLocalizationsSv();

  test('Radera: the content stops existing', () {
    expect(sv.recipeDelete, 'Radera receptet');
    expect(sv.bulkDeleteConfirmAction(1), 'Radera receptet');
    expect(sv.bulkDeleteConfirmAction(3), 'Radera 3 recept');
    expect(sv.commentDeleteConfirmAction, 'Radera kommentaren');
    expect(sv.cookSnapDelete, 'Radera bilden');
    expect(sv.groupDeleteTheGroup, 'Radera gruppen');
    expect(sv.chatDeleteMessage, 'Radera meddelandet');
    expect(sv.messagingDeleteConversationAction, 'Radera konversationen');
    expect(sv.shoppingDeleteList, 'Radera listan');
    expect(sv.tagDetailDeleteTagAction, 'Radera taggen');
    expect(sv.tagDetailRuleDeleteAction, 'Radera regeln');
    expect(sv.personalTagBulkDeleteAction(1), 'Radera taggen');
    expect(sv.personalTagBulkDeleteAction(3), 'Radera 3 taggar');
  });

  test('Ta bort: lifted out of a list or a relation', () {
    expect(sv.friendProfileRemoveFriend, 'Ta bort som vän');
    expect(sv.groupRemoveFromGroup, 'Ta bort ur gruppen');
    expect(sv.messagingRemoveMemberAction, 'Ta bort ur gruppen');
    expect(sv.ratingRemoveAction, 'Ta bort betyget');
    expect(sv.importHeirloomClearAction, 'Ta bort bilden');
    expect(sv.familyDeleteMember, 'Ta bort familjemedlem');
  });
}
