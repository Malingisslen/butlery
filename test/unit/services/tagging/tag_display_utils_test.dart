/// Direct unit tests for [TagDisplayUtils] (BUT-1149 coverage burndown —
/// previously zero direct coverage).
///
/// Pure static tag-display helpers: smart top-N selection (user tags first,
/// then by searchability category, then alphabetical), tightest-time-bucket
/// collapse, and display-name formatting. No mocks, no l10n.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/services/tagging/tag_display_utils.dart';

void main() {
  group('getTopTags', () {
    test('empty effective tags → empty list', () {
      expect(TagDisplayUtils.getTopTags({}, {}), isEmpty);
    });

    test('user-added tags come before auto-generated ones', () {
      final top = TagDisplayUtils.getTopTags(
        {'kyckling', 'mytag'}, // kyckling is a priority-1 protein
        {'mytag'}, // user-added
      );
      expect(top.first, 'mytag');
      expect(top, contains('kyckling'));
    });

    test('auto tags ordered by category: protein before cuisine', () {
      final top = TagDisplayUtils.getTopTags(
        {'italiensk', 'kyckling'}, // cuisine (P3) + protein (P1)
        {},
      );
      expect(top, ['kyckling', 'italiensk']);
    });

    test('respects the limit', () {
      final top = TagDisplayUtils.getTopTags(
        {'kyckling', 'soppa', 'italiensk', 'enkel', 'helgmat'},
        {},
        limit: 2,
      );
      expect(top, hasLength(2));
    });

    test('collapses time buckets to the tightest present', () {
      // A 15-min recipe stores all the looser buckets too; only the tightest
      // should surface for display.
      final top = TagDisplayUtils.getTopTags(
        {'under-15-min', 'under-30-min', 'under-60-min'},
        {},
      );
      expect(top, ['under-15-min']);
    });

    test('unknown tags fall through to alphabetical order', () {
      final top = TagDisplayUtils.getTopTags({'zebra', 'apple'}, {});
      expect(top, ['apple', 'zebra']);
    });
  });

  group('getDisplayName', () {
    test('uses the friendly name for known tags', () {
      expect(TagDisplayUtils.getDisplayName('under-15-min'), 'Under 15 min');
      expect(TagDisplayUtils.getDisplayName('pasta-dish'), 'Pasta');
      expect(TagDisplayUtils.getDisplayName('italiensk'), 'Italienskt');
    });

    test('unknown tags: hyphens→spaces, first letter capitalized', () {
      expect(TagDisplayUtils.getDisplayName('something-new'), 'Something new');
      expect(TagDisplayUtils.getDisplayName('plain'), 'Plain');
    });

    test('empty tag returns empty', () {
      expect(TagDisplayUtils.getDisplayName(''), '');
    });
  });

  group('getDisplayNames', () {
    test('maps each tag through getDisplayName', () {
      expect(
        TagDisplayUtils.getDisplayNames(['under-30-min', 'foo-bar']),
        ['Under 30 min', 'Foo bar'],
      );
    });
  });

  group('isUserAddedTag', () {
    test('true only for members of the user-added set', () {
      expect(TagDisplayUtils.isUserAddedTag('x', {'x', 'y'}), isTrue);
      expect(TagDisplayUtils.isUserAddedTag('z', {'x', 'y'}), isFalse);
    });
  });
}
