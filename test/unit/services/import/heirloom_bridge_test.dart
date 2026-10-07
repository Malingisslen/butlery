import 'dart:typed_data';

import 'package:butlery/models/recipe/heirloom_draft.dart';
import 'package:butlery/services/import/heirloom_bridge.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late HeirloomBridge bridge;
  final draft = HeirloomDraft(imageBytes: Uint8List.fromList([1, 2, 3]));

  setUp(() => bridge = HeirloomBridge());

  group('BUT-2280: HeirloomBridge hands a draft only to its bound recipe', () {
    test('a bound draft is taken once by its recipe', () {
      bridge.setDraft(draft);
      bridge.bindTo('recipe-1');

      expect(bridge.takeFor('recipe-1'), same(draft));
      expect(bridge.hasPending, isFalse);
      expect(bridge.takeFor('recipe-1'), isNull);
    });

    test('another recipe gets nothing and leaves the draft pending', () {
      bridge.setDraft(draft);
      bridge.bindTo('recipe-1');

      expect(bridge.takeFor('recipe-2'), isNull);
      expect(bridge.hasPending, isTrue);
    });

    test('an unbound draft is handed to no recipe', () {
      bridge.setDraft(draft);

      expect(bridge.takeFor('recipe-1'), isNull);
      expect(bridge.takeFor(''), isNull);
    });

    test('a new draft drops the earlier binding', () {
      bridge.setDraft(draft);
      bridge.bindTo('recipe-1');
      bridge.setDraft(HeirloomDraft(imageBytes: Uint8List.fromList([9])));

      expect(bridge.takeFor('recipe-1'), isNull);
    });

    test('an empty recipe id binds nothing', () {
      bridge.setDraft(draft);
      bridge.bindTo('');

      expect(bridge.takeFor(''), isNull);
    });

    test('clear drops the draft and its binding', () {
      bridge.setDraft(draft);
      bridge.bindTo('recipe-1');
      bridge.clear();

      expect(bridge.hasPending, isFalse);
      expect(bridge.takeFor('recipe-1'), isNull);
    });
  });
}
