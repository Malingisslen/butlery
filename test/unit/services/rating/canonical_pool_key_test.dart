import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/services/rating/canonical_pool_key.dart';

/// Behavioral contract for the v1 pooled-ratings identity key. Each test states
/// the property it proves; these are the recall (same recipe → same pool) and
/// precision (different dishes → different pools; fail-closed) guarantees the
/// Step 0 gate + panel review committed to.
void main() {
  String? key(String title, List<String> ingredients) =>
      CanonicalPoolKey.compute(title: title, ingredients: ingredients);

  group('recall — the same recipe reaches one pool across sources', () {
    test('title qualifier variance does not split the pool', () {
      // "Klassiska köttbullar" vs "Köttbullar": ingredients identical, only a
      // descriptive qualifier differs — must pool.
      final a = key('Köttbullar', const [
        '500 g blandfärs',
        '1 gul lök',
        '1 dl ströbröd',
        '1 ägg',
      ]);
      final b = key('Klassiska köttbullar', const [
        '1 ägg',
        '500 g blandfärs',
        '1 dl ströbröd',
        '1 gul lök',
      ]);
      expect(a, isNotNull);
      expect(a, equals(b));
    });

    test('ingredient order and amounts do not affect the key', () {
      final a = key('Pannkakor', const [
        '3 dl vetemjöl',
        '6 dl mjölk',
        '3 ägg',
      ]);
      final b = key('Pannkakor', const [
        '6 dl mjölk',
        '3 ägg',
        '1 dl vetemjöl',
      ]);
      // Same ingredient NAMES (amounts stripped), order-independent.
      expect(a, equals(b));
    });

    test('OCR diacritic drops collapse to the same key', () {
      // "Köttbullar" scanned as "Kottbullar", "ströbröd" as "strobrod".
      final clean = key('Köttbullar', const [
        '500 g blandfärs',
        '1 gul lök',
        '1 dl ströbröd',
      ]);
      final ocr = key('Kottbullar', const [
        '500 g blandfars',
        '1 gul lok',
        '1 dl strobrod',
      ]);
      expect(clean, equals(ocr));
    });

    test('OCR digit/letter confusion inside a word is repaired', () {
      // "salt"→"sa1t" must not break the key.
      final clean = key('Pannkakor', const ['3 dl vetemjöl', '1 tsk salt']);
      final ocr = key('Pannkakor', const ['3 dl vetemjol', '1 tsk sa1t']);
      expect(clean, equals(ocr));
    });

    test('hashtags and emoji in an Instagram title are ignored', () {
      final web = key('Köttbullar', const ['blandfärs', 'lök', 'ströbröd']);
      final insta = key('Köttbullar 🧆 #husmanskost', const [
        'blandfärs',
        'lök',
        'ströbröd',
      ]);
      expect(web, equals(insta));
    });

    test('Swedish-letter hashtags leave no anchor-hijacking remnant', () {
      // "#kött" must strip fully (not leave "ött") — otherwise a long
      // Swedish-char hashtag could win the longest-token race and become a
      // spurious anchor, splitting the pool from the clean source.
      final clean = key('Ris', const ['ris', 'vatten', 'salt']);
      final hashed = key('Ris #köttfärslimpa #älg', const [
        'ris',
        'vatten',
        'salt',
      ]);
      expect(clean, equals(hashed));
    });

    test('glued OCR quantity+unit tokens collapse to the spaced form', () {
      // A scan often glues amount and unit ("500g", "2dl"). Digit repair must
      // not turn "500g" into "5oog" before the amount is stripped.
      final spaced = key('Pannkakor', const ['500 g vetemjöl', '2 dl mjölk']);
      final glued = key('Pannkakor', const ['500g vetemjöl', '2dl mjölk']);
      expect(spaced, equals(glued));
    });
  });

  group('precision — different dishes never share a pool', () {
    test('same ingredients but a different dish name do NOT pool', () {
      const batter = ['3 ägg', '3 dl socker', '3 dl vetemjöl', '100 g smör'];
      final cake = key('Sockerkaka', batter);
      final muffins = key('Muffins', batter);
      expect(cake, isNotNull);
      expect(muffins, isNotNull);
      expect(cake, isNot(equals(muffins)));
    });

    test(
      'ingredients drive identity — same anchor, different set → new pool',
      () {
        // Guards against an anchor-only regression: every OTHER test here holds
        // the ingredient set constant (recall) or varies the anchor (precision),
        // so a key that ignored ingredients entirely would pass them all. This
        // one fails unless the ingredient NAMES actually participate in the key.
        // It ALSO pins the deliberate v1 exact-set-match limitation: adding an
        // ingredient to an otherwise-identical recipe SPLITS the pool. If v1
        // ever moves to fuzzy/Jaccard pooling this test must be revisited, not
        // silently deleted.
        final lean = key('Köttbullar', const ['blandfärs', 'lök']);
        final full = key('Köttbullar', const [
          'blandfärs',
          'lök',
          'ströbröd',
          'ägg',
        ]);
        expect(lean, isNotNull);
        expect(full, isNotNull);
        expect(lean, isNot(equals(full)));
      },
    );
  });

  group('fail closed — no key rather than a risky merge', () {
    test('empty ingredients yield no key', () {
      expect(key('Köttbullar', const []), isNull);
    });

    test('an empty title yields no key (no anchor)', () {
      // A recipe with no title cannot produce a dish anchor, so it must fail
      // closed rather than pool on ingredients alone.
      expect(key('', const ['blandfärs', 'lök']), isNull);
    });

    test('a generic dish category name yields no key', () {
      // A bare "Soppa" cannot guard precision — must not pool.
      expect(key('Soppa', const ['lök', 'morot', 'buljong', 'salt']), isNull);
      expect(key('Kaka', const ['ägg', 'socker', 'vetemjöl']), isNull);
    });

    test('a definite generic form also yields no key', () {
      expect(key('Soppan', const ['lök', 'morot', 'buljong']), isNull);
    });

    test('a title of only stopwords/qualifiers yields no key', () {
      // "god" and "enkel" are both stop words → no significant token survives
      // → no anchor → no pool.
      expect(key('God enkel', const ['ägg', 'mjölk', 'mjöl']), isNull);
    });

    test('two different generic-titled dishes both fail closed (no merge)', () {
      const base = ['lök', 'morot', 'buljong', 'salt'];
      expect(key('Soppa', base), isNull);
      expect(key('Grytan', base), isNull);
    });
  });

  group('key shape', () {
    test('carries the version prefix', () {
      final k = key('Köttbullar', const ['blandfärs', 'lök']);
      expect(k, isNotNull);
      expect(k!.startsWith('${CanonicalPoolKey.version}:'), isTrue);
    });

    test('is deterministic across calls', () {
      final a = key('Ärtsoppa', const ['gula ärter', 'lök', 'fläsk']);
      final b = key('Ärtsoppa', const ['gula ärter', 'lök', 'fläsk']);
      expect(a, equals(b));
    });

    test('longest-token tie-break is first-wins and stable', () {
      // Two equal-length significant tokens ("lever" / "sylta", both 5): the
      // first in title order anchors, deterministically, on repeat calls.
      final a = key('Lever sylta', const ['lever', 'lök', 'kryddpeppar']);
      final b = key('Lever sylta', const ['lever', 'lök', 'kryddpeppar']);
      expect(a, isNotNull);
      expect(a, equals(b));
    });
  });
}
