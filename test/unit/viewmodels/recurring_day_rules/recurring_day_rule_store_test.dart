// Intention: the rule list's model works over a store. A member of a group
// reads the group's rules and every write is refused before it reaches the
// callable; an admin's write reaches `setRecurringDayRules`.
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/models/menu/recurring_day_rule.dart';
import 'package:butlery/models/menu/weekly_menu_plan.dart';
import 'package:butlery/models/messaging/chat_group.dart';
import 'package:butlery/viewmodels/recurring_day_rules/recurring_day_rule_store.dart';
import 'package:butlery/viewmodels/recurring_day_rules_viewmodel.dart';

import '../../../infrastructure/mocks/service_mocks.dart';

ChatGroup _group({List<RecurringDayRule> rules = const []}) => ChatGroup(
  id: 'cg1',
  name: 'Familjen',
  memberIds: const ['admin', 'member'],
  adminIds: const ['admin'],
  memberDisplayNames: const {},
  memberAvatarUrls: const {},
  conversationId: 'c1',
  createdBy: 'admin',
  createdAt: DateTime.utc(2026, 1, 1),
  updatedAt: DateTime.utc(2026, 1, 1),
  recurringDayRules: rules,
);

RecurringDayRule _tacos() => RecurringDayRule.create(
  day: DayOfWeek.fri,
  meal: MealSlot.middag,
  food: RecurringFood.tacos,
);

void main() {
  late MockChatGroupRepository repo;
  late StreamController<ChatGroup?> stream;

  setUpAll(() => registerFallbackValue(<RecurringDayRule>[]));

  setUp(() {
    repo = MockChatGroupRepository();
    stream = StreamController<ChatGroup?>.broadcast();
    when(() => repo.watchGroup('cg1')).thenAnswer((_) => stream.stream);
    when(
      () => repo.setRecurringDayRules(any(), any()),
    ).thenAnswer((_) async {});
  });

  tearDown(() => stream.close());

  RecurringDayRulesViewModel vmFor(String uid, {List<RecurringDayRule>? seed}) {
    final store = GroupRuleStore(
      chatGroupId: 'cg1',
      initial: _group(rules: seed ?? [_tacos()]),
      repository: repo,
      currentUserId: () => uid,
    );
    final vm = RecurringDayRulesViewModel(store: store);
    addTearDown(vm.dispose);
    return vm;
  }

  group('group scope', () {
    test('a member reads the rules and cannot save, pause or delete', () async {
      final vm = vmFor('member');

      expect(vm.canEdit, isFalse);
      expect(vm.rules, [_tacos()]);
      final soup = RecurringDayRule.create(
        day: DayOfWeek.sun,
        meal: MealSlot.middag,
        food: RecurringFood.soppa,
      );
      expect(await vm.save(soup), isFalse);
      expect(await vm.setPaused(_tacos(), true), isFalse);
      expect(await vm.delete(_tacos()), isFalse);

      verifyNever(() => repo.setRecurringDayRules(any(), any()));
    });

    test(
      'an admin saves through the callable, over the stored rules',
      () async {
        final vm = vmFor('admin');
        final soup = RecurringDayRule.create(
          day: DayOfWeek.sun,
          meal: MealSlot.middag,
          food: RecurringFood.soppa,
        );

        expect(vm.canEdit, isTrue);
        expect(await vm.save(soup), isTrue);

        verify(
          () => repo.setRecurringDayRules('cg1', [_tacos(), soup]),
        ).called(1);
        expect(vm.rules, [_tacos(), soup]);
      },
    );

    test('a failed callable is a failed save, shown as one', () async {
      when(
        () => repo.setRecurringDayRules(any(), any()),
      ).thenThrow(Exception('offline'));
      final vm = vmFor('admin');

      expect(await vm.delete(_tacos()), isFalse);
      expect(vm.error, isNotNull);
      expect(vm.rules, [_tacos()]);
    });

    test('the group document is followed after the first frame', () async {
      final vm = vmFor('admin', seed: const []);
      expect(vm.rules, isEmpty);

      stream.add(_group(rules: [_tacos()]));
      await Future<void>.delayed(Duration.zero);

      expect(vm.rules, [_tacos()]);
    });

    test('no group yet means nobody may edit', () {
      final store = GroupRuleStore(
        chatGroupId: 'cg1',
        repository: repo,
        currentUserId: () => 'admin',
      );
      addTearDown(store.dispose);

      expect(store.canEdit, isFalse);
      expect(store.rules, isEmpty);
    });
  });
}
