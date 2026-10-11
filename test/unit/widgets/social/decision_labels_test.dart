// BUT-2353: every motivation key has its Swedish and English text, the Swedish
// text is the contract's, and every appeal failure has a message.
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/l10n/app_localizations_en.dart';
import 'package:butlery/l10n/app_localizations_sv.dart';
import 'package:butlery/models/social/content_type.dart';
import 'package:butlery/models/social/moderation_motivation.dart';
import 'package:butlery/services/moderation/moderation_appeals_service.dart';
import 'package:butlery/widgets/social/decision_labels.dart';

void main() {
  final sv = AppLocalizationsSv();
  final en = AppLocalizationsEn();

  test('each motivation has distinct text in both languages', () {
    final svTexts = ModerationMotivation.values
        .map((m) => motivationText(sv, m))
        .toSet();
    final enTexts = ModerationMotivation.values
        .map((m) => motivationText(en, m))
        .toSet();
    expect(svTexts, hasLength(ModerationMotivation.values.length));
    expect(enTexts, hasLength(ModerationMotivation.values.length));
    expect(svTexts.every((t) => t.isNotEmpty), isTrue);
  });

  test('Swedish motivation texts are the contract texts', () {
    expect(
      motivationText(sv, ModerationMotivation.removedCopyright),
      'Innehållet var kopierat från någon annan utan tillstånd eller källa, '
      'vilket bryter mot reglerna om upphovsrätt.',
    );
    expect(
      motivationText(sv, ModerationMotivation.keptNoBreach),
      'Vi hittade inget brott mot gemenskapsreglerna, så innehållet ligger kvar.',
    );
    expect(
      motivationText(sv, ModerationMotivation.misattributionNameRemoved),
      'Ditt namn har tagits bort från rätten.',
    );
    expect(
      motivationText(sv, ModerationMotivation.hiddenSpam),
      'Profilen användes för reklam eller spam och visas inte längre för andra.',
    );
  });

  test('every content type has an owner and a reporter noun', () {
    for (final type in ContentType.values) {
      final owner = decisionSubject(sv, type, owner: true);
      final reporter = decisionSubject(sv, type, owner: false);
      expect(owner, isNotEmpty);
      expect(reporter, isNot(owner));
    }
    expect(decisionSubject(sv, ContentType.recipe, owner: true), 'Ditt recept');
  });

  test('every appeal failure has a message', () {
    final messages = AppealFailure.values
        .map((f) => appealFailureText(sv, f))
        .toSet();
    expect(messages, hasLength(AppealFailure.values.length));
  });

  test('the reversed-removal note drops the account-mark sentence', () {
    expect(
      sv.appealAnswerReversedOwnerRemoved,
      'Innehållet kunde inte återställas, men du får lägga upp det igen.',
    );
    expect(
      sv.moderatorAnswerNoteBody,
      'Det raderades när du tog bort det. Ägaren får veta att beslutet ändrats '
      'och att hen kan lägga upp det igen.',
    );
  });
}
