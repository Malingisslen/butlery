/// Malin's round-three decisions (fas2/produktbeslut-2026-09-27.json): the
/// words the user sees, with their English equivalent under the same key.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/l10n/app_localizations_en.dart';
import 'package:butlery/l10n/app_localizations_sv.dart';

void main() {
  final sv = AppLocalizationsSv();
  final en = AppLocalizationsEn();

  test('Q6-04 = C: the camera explanation says the photo is sent only to '
      'read the text, and never that it stays on the phone', () {
    // Skarmar v12 etapp 3 #behkamera draws "Bilden stannar på telefonen om
    // du inte själv delar den.", which is not true: the photo is sent to the
    // service that reads the text.
    expect(
      sv.permImportCameraBody,
      'Jag läser texten ur bilden och fyller i receptet åt dig. '
      'Bilden skickas bara för att läsa av texten.',
    );
    expect(sv.permImportCameraBody, isNot(contains('stannar')));
    expect(
      en.permImportCameraBody,
      'I read the text in the photo and fill in the recipe for you. '
      'The photo is sent only to read the text.',
    );
  });

  test('Q6-05 = C: the empty cooking mode on someone else\'s recipe says '
      'Spara min kopia', () {
    expect(sv.cookingNoStepsSaveCopy, 'Spara min kopia');
    expect(en.cookingNoStepsSaveCopy, 'Save my copy');
  });

  test('Q6-08 = A: a member suggests a change (produktregler.md:247)', () {
    expect(sv.recipeSuggestChange, 'Föreslå ändring');
    expect(en.recipeSuggestChange, 'Suggest a change');
  });

  test('the new texts follow the content style guide', () {
    final texts = [
      sv.permImportCameraBody,
      sv.cookingNoStepsSaveCopy,
      sv.cookingNoStepsBodyOthers,
      sv.cookingNoStepsBodyOthersNoIngredients,
      sv.recipeSuggestChange,
      sv.recipeSuggestionSend,
      sv.recipeSuggestionSending,
      sv.recipeSuggestionSent,
      sv.recipeSuggestionSendFailed,
      sv.recipeSuggestionReplaced,
      sv.recipeSuggestionChangedSinceOpened,
      sv.recipeSuggestionFromOneUpdated('Olle'),
      sv.recipeSuggestionFromManyUpdated(3, 1),
      sv.recipeSuggestionIntroOwnerUpdated('Olle', '3 okt'),
      sv.recipeSuggestionIntroMineUpdated('3 okt'),
      sv.conflictBannerBodySuggestionReplaced('Olle'),
      sv.recipeSuggestionCoversText,
      sv.conflictBannerBodyMemberNotSent('Olle'),
      sv.conflictBannerBodyMemberNotSentUnnamed,
    ];
    for (final t in texts) {
      expect(t, isNot(contains('!')), reason: t);
      expect(t.toLowerCase(), isNot(contains('tyvärr')), reason: t);
      expect(t.toLowerCase(), isNot(contains('något gick fel')), reason: t);
    }
  });
}
