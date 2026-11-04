import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/services/tagging/config/occasion_lists.dart';
import 'package:butlery/viewmodels/admin/tag_rules_viewmodel.dart';

import '../../../test_support/base_unit_test.dart';
import '../../../test_support/ingredient_review_fixtures.dart';

void main() {
  setUpAll(() async {
    await BaseUnitTest.setupUnit();
  });

  final list = kOccasionLists.firstWhere(
    (l) => l.key == 'christmas.titleWords',
  );

  TagRulesViewModel build(FakeChangeRequestRepository repo) =>
      TagRulesViewModel(
        tagConfigService: FakeTagConfigService(ingredientReviewConfig()),
        repository: repo,
      );

  group('proposeWordList', () {
    test('creates a word-list proposal with the old and new words', () async {
      final repo = FakeChangeRequestRepository();
      final vm = build(repo);
      final newWords = [...list.words, 'nytt ord'];

      final saved = await vm.proposeWordList(
        list,
        newWords,
        note: '  för att ...  ',
      );

      expect(saved, isTrue);
      expect(vm.error, isNull);
      final p = repo.created.single;
      expect(p.isWordList, isTrue);
      expect(p.listKey, 'christmas.titleWords');
      expect(p.oldWords, list.words);
      expect(p.newWords, newWords);
      expect(p.note, 'för att ...');
      expect(p.ingredientId, '');
      expect(p.changes, isEmpty);
    });

    test('writes nothing for unchanged, invalid or over-long input', () async {
      final repo = FakeChangeRequestRepository();
      final vm = build(repo);

      expect(await vm.proposeWordList(list, list.words), isFalse);
      expect(await vm.proposeWordList(list, const []), isFalse);
      expect(await vm.proposeWordList(list, const ['Stor Bokstav']), isFalse);
      expect(
        await vm.proposeWordList(list, ['ny', ...list.words], note: 'x' * 501),
        isFalse,
      );
      expect(repo.created, isEmpty);
    });

    test('a reordering counts as a change', () async {
      final repo = FakeChangeRequestRepository();
      final vm = build(repo);
      expect(
        await vm.proposeWordList(list, list.words.reversed.toList()),
        isTrue,
      );
      expect(repo.created.single.newWords, list.words.reversed.toList());
    });

    test('a failed write leaves a Swedish error and returns false', () async {
      final vm = build(FakeChangeRequestRepository(failWrites: true));
      expect(await vm.proposeWordList(list, [...list.words, 'ny']), isFalse);
      expect(vm.error, 'Kunde inte spara förslaget');
    });
  });

  test('sameWords compares order as well as content', () {
    expect(TagRulesViewModel.sameWords(['a', 'b'], ['a', 'b']), isTrue);
    expect(TagRulesViewModel.sameWords(['a', 'b'], ['b', 'a']), isFalse);
    expect(TagRulesViewModel.sameWords(['a'], ['a', 'b']), isFalse);
  });
}
