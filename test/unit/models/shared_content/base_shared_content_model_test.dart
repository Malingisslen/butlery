/// Unit tests for BaseSharedContentModel (abstract base + static parsers).
///
/// Concrete subclass impls (SharedMenu / SharedRecipe / SharedShoppingList)
/// are tested in their own files. Here we cover the base behaviors via a
/// minimal _Stub subclass, plus the two static parse helpers used by all
/// concrete content models on read.
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/models/shared_content/base_shared_content_model.dart';

class _Stub extends BaseSharedContentModel<String> {
  _Stub({
    required super.id,
    required super.sharedByUserId,
    required super.sharedByDisplayName,
    required super.sharedAt,
    super.shareMessage,
    super.viewCount = 0,
    super.engagementCount = 0,
    super.dismissalCount = 0,
  });

  @override
  String get contentTypeName => 'stub';

  @override
  String get contentSnapshot => 'snap';

  @override
  String getContentTitle() => 'Title';

  @override
  String getContentDescription() => 'Desc';

  @override
  BaseSharedContentModel<String> copyWithStatus({
    int? viewCount,
    int? engagementCount,
    int? dismissalCount,
  }) {
    return _Stub(
      id: id,
      sharedByUserId: sharedByUserId,
      sharedByDisplayName: sharedByDisplayName,
      sharedAt: sharedAt,
      shareMessage: shareMessage,
      viewCount: viewCount ?? this.viewCount,
      engagementCount: engagementCount ?? this.engagementCount,
      dismissalCount: dismissalCount ?? this.dismissalCount,
    );
  }
}

_Stub _stub({
  String id = 'x1',
  int viewCount = 0,
  int engagementCount = 0,
}) {
  return _Stub(
    id: id,
    sharedByUserId: 'alice',
    sharedByDisplayName: 'Alice',
    sharedAt: DateTime.utc(2026, 1, 1),
    viewCount: viewCount,
    engagementCount: engagementCount,
  );
}

void main() {
  group('conversionRate', () {
    test('returns 0.0 when viewCount is 0', () {
      expect(_stub().conversionRate, 0.0);
    });

    test('returns engagementCount / viewCount * 100', () {
      expect(_stub(viewCount: 10, engagementCount: 3).conversionRate, 30.0);
    });
  });

  test(
    'timeAgoText returns a non-empty string (delegates to TimeAgoFormatter)',
    () {
      expect(_stub().timeAgoText, isNotEmpty);
    },
  );

  group('getCommonFirestoreFields', () {
    test('includes the seven common fields', () {
      final fields = _stub().getCommonFirestoreFields();
      expect(fields.keys.toSet(), {
        'sharedByUserId',
        'sharedByDisplayName',
        'sharedAt',
        'shareMessage',
        'viewCount',
        'engagementCount',
        'dismissalCount',
      });
      expect(fields['sharedByUserId'], 'alice');
      expect(fields['viewCount'], 0);
    });
  });

  group('getCommonJsonFields', () {
    test('includes id and an ISO 8601 sharedAt string', () {
      final fields = _stub(id: 'sx').getCommonJsonFields();
      expect(fields['id'], 'sx');
      expect(fields['sharedAt'], '2026-01-01T00:00:00.000Z');
    });
  });

  group('parseCommonFieldsFromFirestore', () {
    test('parses all seven fields with safe defaults', () {
      final parsed = BaseSharedContentModel.parseCommonFieldsFromFirestore({
        'sharedByUserId': 'alice',
        'sharedByDisplayName': 'Alice',
        'sharedAt': Timestamp.fromDate(DateTime.utc(2026, 1, 1)),
        'shareMessage': 'hej',
        'viewCount': 5,
        'engagementCount': 2,
        'dismissalCount': 1,
      });
      expect(parsed['sharedByUserId'], 'alice');
      expect(parsed['sharedByDisplayName'], 'Alice');
      expect(
        (parsed['sharedAt'] as DateTime).toUtc(),
        DateTime.utc(2026, 1, 1),
      );
      expect(parsed['shareMessage'], 'hej');
      expect(parsed['viewCount'], 5);
      expect(parsed['engagementCount'], 2);
      expect(parsed['dismissalCount'], 1);
    });

    test('missing shareMessage → null; missing counts → 0', () {
      final parsed = BaseSharedContentModel.parseCommonFieldsFromFirestore({
        'sharedByUserId': 'alice',
        'sharedByDisplayName': 'Alice',
        'sharedAt': Timestamp.fromDate(DateTime.utc(2026, 1, 1)),
      });
      expect(parsed['shareMessage'], isNull);
      expect(parsed['viewCount'], 0);
      expect(parsed['engagementCount'], 0);
      expect(parsed['dismissalCount'], 0);
    });
  });

  group('parseCommonFieldsFromJson', () {
    test('parses id + sharedAt from ISO string + counts', () {
      final parsed = BaseSharedContentModel.parseCommonFieldsFromJson({
        'id': 'doc-1',
        'sharedByUserId': 'alice',
        'sharedByDisplayName': 'Alice',
        'sharedAt': '2026-01-01T00:00:00.000Z',
        'viewCount': 7,
      });
      expect(parsed['id'], 'doc-1');
      expect(parsed['sharedByUserId'], 'alice');
      expect(
        (parsed['sharedAt'] as DateTime).toUtc(),
        DateTime.utc(2026, 1, 1),
      );
      expect(parsed['viewCount'], 7);
    });
  });

  group('toString + equality', () {
    test('toString includes contentTypeName, id, title, sharedBy', () {
      final s = _stub(id: 'sx').toString();
      expect(s, contains('stub'));
      expect(s, contains('sx'));
      expect(s, contains('Title'));
      expect(s, contains('Alice'));
    });

    test('id-only equality across subclass instances', () {
      final a = _stub(id: 'same', viewCount: 1);
      final b = _stub(id: 'same', viewCount: 99);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('different id → unequal', () {
      expect(_stub(id: 'a'), isNot(_stub(id: 'b')));
    });

    test('identical short-circuit', () {
      final s = _stub();
      expect(s == s, isTrue);
    });
  });
}
