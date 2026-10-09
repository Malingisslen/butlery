/// BUT-2328: the English trash strings that take a count say "recipe" for
/// one and "recipes" for more.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/l10n/app_localizations_en.dart';

void main() {
  final en = AppLocalizationsEn();

  test('the footer buttons count one recipe and several', () {
    expect(en.trashRestoreSelected(1), 'Restore 1 recipe');
    expect(en.trashRestoreSelected(3), 'Restore 3 recipes');
    expect(en.trashDeleteSelected(1), 'Delete 1 recipe');
    expect(en.trashDeleteSelected(3), 'Delete 3 recipes');
  });

  test('the partial-failure lines count one recipe and several', () {
    expect(
      en.trashFailOffline(1),
      '1 recipe was not done because you are offline.',
    );
    expect(
      en.trashFailOffline(2),
      '2 recipes were not done because you are offline.',
    );
    expect(en.trashFailExpired(1), '1 recipe had already expired.');
    expect(en.trashFailExpired(2), '2 recipes had already expired.');
    expect(en.trashFailGone(1), '1 recipe was no longer in the trash.');
    expect(en.trashFailGone(2), '2 recipes were no longer in the trash.');
    expect(en.trashFailFailed(1), '1 recipe could not be done. Try again.');
    expect(en.trashFailFailed(2), '2 recipes could not be done. Try again.');
  });

  test('a bulk delete from Mina recept counts one recipe and several', () {
    expect(en.bulkDeleteSuccess(1), '1 recipe moved to the trash for 30 days');
    expect(en.bulkDeleteSuccess(4), '4 recipes moved to the trash for 30 days');
  });
}
