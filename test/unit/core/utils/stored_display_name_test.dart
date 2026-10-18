import 'package:butlery/core/utils/stored_display_name.dart';
import 'package:butlery/l10n/app_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('knownStoredName', () {
    test('null, empty and whitespace are unknown', () {
      expect(knownStoredName(null), isNull);
      expect(knownStoredName(''), isNull);
      expect(knownStoredName('   '), isNull);
    });

    test('a real name is returned trimmed', () {
      expect(knownStoredName('  Anna Berg '), 'Anna Berg');
    });

    test('both unknown-user labels read as unknown in every locale', () {
      for (final locale in AppLocalizations.supportedLocales) {
        final l10n = lookupAppLocalizations(locale);
        expect(knownStoredName(l10n.displayUnknownUser), isNull);
        expect(knownStoredName(l10n.shoppingUnknownUser), isNull);
      }
      expect(knownStoredName('Okänd användare'), isNull);
      expect(knownStoredName('Unknown user'), isNull);
    });

    test('the match ignores case and surrounding whitespace', () {
      expect(knownStoredName('  okänd ANVÄNDARE '), isNull);
      expect(knownStoredName('UNKNOWN USER'), isNull);
    });

    test('the deleted-account tombstone stays a name', () {
      expect(knownStoredName('[Raderad användare]'), '[Raderad användare]');
    });

    test('a name that merely contains the label stays a name', () {
      expect(knownStoredName('Okänd användare 2'), 'Okänd användare 2');
    });
  });

  group('storedNameOr', () {
    test('returns the stored name when known', () {
      expect(storedNameOr('Anna', 'Unknown user'), 'Anna');
    });

    test('resolves empty and legacy labels to the reader fallback', () {
      expect(storedNameOr('', 'Unknown user'), 'Unknown user');
      expect(storedNameOr(null, 'Unknown user'), 'Unknown user');
      expect(storedNameOr('Okänd användare', 'Unknown user'), 'Unknown user');
    });
  });
}
