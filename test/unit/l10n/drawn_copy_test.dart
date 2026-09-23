/// P5-COPY-DRAWN: a visible label follows the drawing. Each value below is
/// the text drawn in Butlery Skarmar v12 del 3 (anchor and line cited), with
/// its English equivalent under the same key.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/l10n/app_localizations_en.dart';
import 'package:butlery/l10n/app_localizations_sv.dart';

void main() {
  final sv = AppLocalizationsSv();
  final en = AppLocalizationsEn();

  test('friend request rows decline with Avböj (#forfragningar:406)', () {
    expect(sv.socialDecline, 'Avböj');
    expect(sv.friendDecline, 'Avböj');
    expect(en.socialDecline, 'Decline');
    expect(en.friendDecline, 'Decline');
  });

  test(
    'the new group chat hero says Skapa konversation (#nygruppchatt:602)',
    () {
      expect(sv.messagingCreateConversation, 'Skapa konversation');
      expect(en.messagingCreateConversation, 'Create conversation');
    },
  );

  test('the invite hero counts the chosen (#laggtillmedlemmar:562)', () {
    expect(sv.groupSendInvitations(1), 'Bjud in 1 vald');
    expect(sv.groupSendInvitations(3), 'Bjud in 3 valda');
    expect(en.groupSendInvitations(1), 'Invite 1 selected');
    expect(en.groupSendInvitations(3), 'Invite 3 selected');
  });

  test('a shared menu is saved to my menus (#menyforhands:631)', () {
    expect(sv.menuImportAll, 'Spara till mina menyer');
    expect(en.menuImportAll, 'Save to my menus');
  });
}
