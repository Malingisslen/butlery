import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

/// Guards against the diacritic-stripping regression found in the pre-release
/// audit (2026-06-20), where a whole block of `app_sv.arb` lost every å/ä/ö
/// (e.g. "Valkommen", "Mjolk", "Skarmavbild") and shipped broken Swedish to
/// every new user's first screens.
///
/// Approach: a curated DENYLIST of stripped word-fragments that are not valid
/// Swedish words, rather than a generic "looks ASCII" heuristic. The generic
/// approach false-positives constantly (many correct Swedish words use a/o/e),
/// and several stripped forms collide with real words ("fortsatt" = continued,
/// "far" = gets/sheep, "sa" = so). The denylist only lists fragments that are
/// essentially never correct, so a hit is almost always a real regression.
///
/// To extend: when a new corruption slips through, add its stripped fragment
/// below. Keep entries lowercase; matching is case-insensitive on word starts.
void main() {
  // Stripped fragments that are not valid Swedish words. Matched as whole
  // words (or word-prefixes for the inflecting stems marked with a trailing
  // segment) inside ARB *values*.
  const strippedFragments = <String>[
    'valkommen', // välkommen
    'mjolk', // mjölk
    'notter', // nötter
    'skarmavbild', // skärmavbild
    'skarmen', // skärmen
    'fodelse', // födelse / födelseår
    'fodelsear', // födelseår
    'installning', // inställning(ar) — covers inställningar via prefix
    'borjan', // början
    'fran', // från
    'valj', // välj / välja imperative
    'lank', // länk
    'nasta', // nästa
    'slutfor', // slutför
    'oppna', // öppna
    'andra installningar', // ändra inställningar phrase
  ];

  test('app_sv.arb has no diacritic-stripped Swedish values', () {
    final file = File('lib/l10n/app_sv.arb');
    expect(file.existsSync(), isTrue, reason: 'lib/l10n/app_sv.arb must exist');

    final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    final offenders = <String>[];

    json.forEach((key, value) {
      if (key.startsWith('@')) return; // metadata entries, not user strings
      if (value is! String) return;
      final lower = value.toLowerCase();
      for (final frag in strippedFragments) {
        // Word-boundary-ish match: fragment preceded by start/non-letter.
        final pattern =
            RegExp('(^|[^a-zåäö])${RegExp.escape(frag)}', caseSensitive: false);
        if (pattern.hasMatch(lower)) {
          offenders.add('$key: "$value"  (contains "$frag")');
          break;
        }
      }
    });

    expect(
      offenders,
      isEmpty,
      reason: 'Diacritic-stripped Swedish found in app_sv.arb — restore '
          'å/ä/ö:\n${offenders.join('\n')}',
    );
  });
}
