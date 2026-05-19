// BUT-871: Display-getter coverage for `NotificationHistoryEntry`.
//
// The BUT-841 migration switched `data['title'] as String? ?? category` to
// `SerializationUtils.safeString(data, 'title', defaultValue: category)`. The
// new path is permissive (coerces non-String via `.toString()`) where the old
// path would throw. Firestore writers always write Strings, so the new
// contract is fine — but it should be pinned by tests so a future refactor
// doesn't tighten it back.

import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/models/notification_history_entry.dart';

void main() {
  NotificationHistoryEntry build({Map<String, dynamic>? data}) {
    return NotificationHistoryEntry(
      id: 'n1',
      notificationId: 'nid1',
      category: 'recipe_shared',
      type: 'social',
      data: data ?? const {},
      sentAt: DateTime(2026, 5, 19, 12),
    );
  }

  group('displayTitle', () {
    test('returns the title when present', () {
      final entry = build(data: {'title': 'En kompis delade ett recept'});
      expect(entry.displayTitle, 'En kompis delade ett recept');
    });

    test('falls back to category when title is absent', () {
      final entry = build(data: const {});
      expect(entry.displayTitle, 'recipe_shared');
    });

    test('coerces non-String title via toString', () {
      // BUT-841 contract: `safeString` calls `.toString()` on non-null,
      // non-String values rather than throwing.
      final entry = build(data: {'title': 42});
      expect(entry.displayTitle, '42');
    });
  });

  group('displayBody', () {
    test('returns the body when present', () {
      final entry = build(data: {'body': 'Tryck för att se receptet'});
      expect(entry.displayBody, 'Tryck för att se receptet');
    });

    test('returns empty string when body is absent', () {
      final entry = build(data: const {});
      expect(entry.displayBody, '');
    });
  });
}
