/// BUT-2274: one roster across the households a user eats with.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/models/household_roster_member.dart';
import 'package:butlery/services/family/household_roster_service.dart';

class _MockHouseholdRosterService extends Mock
    implements HouseholdRosterService {}

HouseholdRosterMember _user(String id) =>
    HouseholdRosterMember.fromUser(userId: id, displayName: id);

void main() {
  late _MockHouseholdRosterService service;

  setUp(() {
    service = _MockHouseholdRosterService();
    when(
      () => service.tryGetRoster('joined'),
    ).thenAnswer((_) async => [_user('bertil'), _user('me')]);
    when(
      () => service.tryGetRoster('own'),
    ).thenAnswer((_) async => [_user('me'), _user('partner')]);
  });

  test('lists each member once, in household order', () async {
    final roster = await service.tryGetRosters(['joined', 'own']);

    expect(roster!.map((m) => m.memberId), ['bertil', 'me', 'partner']);
  });

  test('one unreadable household makes the whole roster unreadable', () async {
    when(() => service.tryGetRoster('own')).thenAnswer((_) async => null);

    expect(await service.tryGetRosters(['joined', 'own']), isNull);
  });
}
