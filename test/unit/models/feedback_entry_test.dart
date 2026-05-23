/// Unit tests for FeedbackEntry.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/models/feedback_entry.dart';

FeedbackEntry _entry({
  FeedbackCategory category = FeedbackCategory.bug,
  String? email,
  String? screenshotUrl,
  List<Map<String, dynamic>> interactions = const [],
  String? deviceInfo,
}) {
  return FeedbackEntry(
    id: 'f1',
    userId: 'alice',
    category: category,
    description: 'crashed when tapping save',
    email: email,
    screenshotUrl: screenshotUrl,
    recentInteractions: interactions,
    createdAt: DateTime.utc(2026, 1, 1, 10),
    deviceInfo: deviceInfo,
  );
}

void main() {
  group('toMap', () {
    test('serializes category as enum name string', () {
      final m = _entry(category: FeedbackCategory.featureRequest).toMap();
      expect(m['category'], 'featureRequest');
    });

    test('serializes createdAt as ISO 8601 string', () {
      final m = _entry().toMap();
      expect(m['createdAt'], '2026-01-01T10:00:00.000Z');
    });

    test('preserves nullable email / screenshotUrl / deviceInfo as null', () {
      final m = _entry().toMap();
      expect(m['email'], isNull);
      expect(m['screenshotUrl'], isNull);
      expect(m['deviceInfo'], isNull);
    });

    test('preserves provided optionals', () {
      final m = _entry(
        email: 'u@example.com',
        screenshotUrl: 'https://s/x.png',
        deviceInfo: 'iPhone 15',
        interactions: const [
          {'event': 'tap', 'target': 'save'},
        ],
      ).toMap();
      expect(m['email'], 'u@example.com');
      expect(m['screenshotUrl'], 'https://s/x.png');
      expect(m['deviceInfo'], 'iPhone 15');
      expect(m['recentInteractions'], [
        {'event': 'tap', 'target': 'save'},
      ]);
    });
  });

  group('fromMap', () {
    test('round-trips a full entry via toMap', () {
      final original = _entry(
        category: FeedbackCategory.general,
        email: 'u@example.com',
        screenshotUrl: 'https://s/x.png',
        deviceInfo: 'Android 15',
        interactions: const [
          {'event': 'scroll'},
        ],
      );
      final restored = FeedbackEntry.fromMap(original.toMap());

      expect(restored.id, original.id);
      expect(restored.userId, original.userId);
      expect(restored.category, original.category);
      expect(restored.description, original.description);
      expect(restored.email, original.email);
      expect(restored.screenshotUrl, original.screenshotUrl);
      expect(restored.recentInteractions, original.recentInteractions);
      expect(restored.createdAt, original.createdAt);
      expect(restored.deviceInfo, original.deviceInfo);
    });

    test('maps "bug" string to FeedbackCategory.bug', () {
      final restored = FeedbackEntry.fromMap({
        'id': 'x',
        'userId': 'u',
        'category': 'bug',
        'description': 'd',
        'recentInteractions': <Map<String, dynamic>>[],
        'createdAt': DateTime.utc(2026, 1, 1).toIso8601String(),
      });
      expect(restored.category, FeedbackCategory.bug);
    });

    test('maps "featureRequest" string to FeedbackCategory.featureRequest', () {
      final restored = FeedbackEntry.fromMap({
        'id': 'x',
        'userId': 'u',
        'category': 'featureRequest',
        'description': 'd',
        'recentInteractions': <Map<String, dynamic>>[],
        'createdAt': DateTime.utc(2026, 1, 1).toIso8601String(),
      });
      expect(restored.category, FeedbackCategory.featureRequest);
    });

    test('unknown category string falls back to FeedbackCategory.general', () {
      final restored = FeedbackEntry.fromMap({
        'id': 'x',
        'userId': 'u',
        'category': 'something-completely-new',
        'description': 'd',
        'recentInteractions': <Map<String, dynamic>>[],
        'createdAt': DateTime.utc(2026, 1, 1).toIso8601String(),
      });
      expect(restored.category, FeedbackCategory.general);
    });

    test('missing category falls back to default ("general")', () {
      final restored = FeedbackEntry.fromMap({
        'id': 'x',
        'userId': 'u',
        'description': 'd',
        'recentInteractions': <Map<String, dynamic>>[],
        'createdAt': DateTime.utc(2026, 1, 1).toIso8601String(),
      });
      expect(restored.category, FeedbackCategory.general);
    });

    test('safely parses non-map interactions as empty maps', () {
      final restored = FeedbackEntry.fromMap({
        'id': 'x',
        'userId': 'u',
        'category': 'bug',
        'description': 'd',
        'recentInteractions': const ['not-a-map', 42],
        'createdAt': DateTime.utc(2026, 1, 1).toIso8601String(),
      });
      // Non-map entries collapse to empty maps but stay in the list.
      expect(restored.recentInteractions, hasLength(2));
      expect(restored.recentInteractions.every((m) => m.isEmpty), isTrue);
    });
  });
}
