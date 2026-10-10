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

  group('BUT-2286: HeirloomBridge binds one scan to several recipes', () {
    test('draftFor returns the draft and only the bound ids asked about', () {
      bridge.setDraft(draft);
      bridge.bindToAll(['r1', 'r2', 'r3']);

      final found = bridge.draftFor(['r1', 'r3', 'unrelated']);

      expect(found, isNotNull);
      expect(found!.draft, same(draft));
      expect(found.recipeIds, {'r1', 'r3'});
    });

    test('draftFor leaves the draft pending, so a failed save can retry', () {
      bridge.setDraft(draft);
      bridge.bindToAll(['r1', 'r2']);

      expect(bridge.draftFor(['r1', 'r2']), isNotNull);

      expect(bridge.hasPending, isTrue);
      expect(bridge.draftFor(['r1', 'r2'])?.recipeIds, {'r1', 'r2'});
    });

    test('an unbound id gets nothing from draftFor', () {
      bridge.setDraft(draft);
      bridge.bindToAll(['r1']);

      expect(bridge.draftFor(['other']), isNull);
      expect(bridge.draftFor(const []), isNull);
    });

    test('draftFor is null when no draft is pending', () {
      bridge.bindToAll(['r1']);

      expect(bridge.draftFor(['r1']), isNull);
    });

    test('a new draft drops every earlier binding', () {
      bridge.setDraft(draft);
      bridge.bindToAll(['r1', 'r2']);
      bridge.setDraft(HeirloomDraft(imageBytes: Uint8List.fromList([9])));

      expect(bridge.draftFor(['r1', 'r2']), isNull);
    });

    test('empty ids are not bound by bindToAll', () {
      bridge.setDraft(draft);
      bridge.bindToAll(['', 'r1']);

      expect(bridge.draftFor(['', 'r1'])?.recipeIds, {'r1'});
    });

    test('takeFor still hands the draft to one bound recipe and clears', () {
      bridge.setDraft(draft);
      bridge.bindToAll(['r1', 'r2']);

      expect(bridge.takeFor('r2'), same(draft));
      expect(bridge.hasPending, isFalse);
      expect(bridge.draftFor(['r1', 'r2']), isNull);
    });

    test('clear drops draft and bindings for draftFor too', () {
      bridge.setDraft(draft);
      bridge.bindToAll(['r1']);
      bridge.clear();

      expect(bridge.draftFor(['r1']), isNull);
    });
  });
}
