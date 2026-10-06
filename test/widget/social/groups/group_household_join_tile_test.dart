/// BUT-2267: the group-page row through which a member of a household-marked
/// group joins its household. Joining is the member's own act, behind a
/// confirmation, and it shares nothing — the joined state points to Settings,
/// where the consent lives.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/core/constants/routes.dart';
import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/l10n/app_localizations_sv.dart';
import 'package:butlery/models/friend_category.dart';
import 'package:butlery/models/household.dart';
import 'package:butlery/repositories/interfaces/household_repository.dart';
import 'package:butlery/services/feature_flags/feature_flag_service.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/views/social/group_detail/group_detail_header.dart';
import 'package:butlery/widgets/social/groups/group_household_join_tile.dart';

import '../../../infrastructure/helpers/widget_test_app.dart';

class _MockHouseholdRepository extends Mock implements HouseholdRepository {}

class _MockFeatureFlags extends Mock implements FeatureFlagService {}

class _MockPermissionService extends Mock implements PermissionService {}

const _owner = 'owner';
const _me = 'me';
const _groupId = 'fredagsmiddag';
final sv = AppLocalizationsSv();

FriendCategory _group({
  bool isHousehold = true,
  List<String> friendUserIds = const [_me],
}) => FriendCategory(
  id: _groupId,
  ownerId: _owner,
  name: 'Fredagsmiddag',
  friendUserIds: friendUserIds,
  isHousehold: isHousehold,
);

Household _household({String? sourceGroupId, String createdBy = _owner}) =>
    Household(
      id: 'hh-1',
      name: Household.defaultName,
      members: [
        HouseholdMember(
          userId: createdBy,
          permission: SharedListPermission.admin,
          addedAt: DateTime.utc(2026, 1, 1),
        ),
        HouseholdMember(
          userId: _me,
          permission: SharedListPermission.view,
          addedAt: DateTime.utc(2026, 1, 1),
        ),
      ],
      createdBy: createdBy,
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 1, 1),
      sourceGroupId: sourceGroupId,
      sourceGroupOwnerId: sourceGroupId == null ? null : _owner,
    );

void main() {
  late _MockHouseholdRepository households;

  tearDown(() async {
    ServiceLocator.reset();
    await GetIt.instance.reset();
  });

  void wire({
    bool enabled = true,
    String? userId = _me,
    List<Household> mine = const [],
  }) {
    households = _MockHouseholdRepository();
    final flags = _MockFeatureFlags();
    final permissions = _MockPermissionService();
    when(() => flags.isEnabled(any())).thenReturn(false);
    when(
      () => flags.isEnabled(FeatureFlags.enableHouseholdAllergenSharing),
    ).thenReturn(enabled);
    when(() => permissions.currentUserId).thenReturn(userId);
    // Any uid, so a hidden row is hidden by the eligibility check and not by
    // an unstubbed read failing.
    when(() => households.getForUser(any())).thenAnswer((_) async => mine);
    when(
      () => households.joinGroupHousehold(
        ownerId: any(named: 'ownerId'),
        groupId: any(named: 'groupId'),
      ),
    ).thenAnswer((_) async => 'hh-1');

    final container = DIContainer();
    container.container.registerSingleton<HouseholdRepository>(households);
    container.container.registerSingleton<FeatureFlagService>(flags);
    container.container.registerSingleton<PermissionService>(permissions);
    ServiceLocator.initialize(container);
  }

  final pushed = <String?>[];
  Future<void> pump(WidgetTester tester, FriendCategory group) async {
    pushed.clear();
    await tester.pumpWidget(
      createLocalizedTestApp(
        child: GroupHouseholdJoinTile(group: group),
        onGenerateRoute: (settings) {
          pushed.add(settings.name);
          return MaterialPageRoute<void>(builder: (_) => const SizedBox());
        },
      ),
    );
    await tester.pumpAndSettle();
  }

  group('hidden', () {
    testWidgets('for the group\'s owner', (tester) async {
      wire(userId: _owner);
      await pump(tester, _group(friendUserIds: const [_me, _owner]));
      expect(find.text(sv.householdJoinTitle), findsNothing);
    });

    testWidgets('for someone not in the group', (tester) async {
      wire();
      await pump(tester, _group(friendUserIds: const ['someone-else']));
      expect(find.text(sv.householdJoinTitle), findsNothing);
    });

    testWidgets('on a group not marked as household', (tester) async {
      wire();
      await pump(tester, _group(isHousehold: false));
      expect(find.text(sv.householdJoinTitle), findsNothing);
    });

    testWidgets('with the feature switched off', (tester) async {
      wire(enabled: false);
      await pump(tester, _group());
      expect(find.text(sv.householdJoinTitle), findsNothing);
      verifyNever(() => households.getForUser(any()));
    });

    testWidgets('while membership cannot be read', (tester) async {
      // Offering a join to someone who may already be in would be a guess.
      wire();
      when(() => households.getForUser(_me)).thenThrow(StateError('offline'));
      await pump(tester, _group());
      expect(find.text(sv.householdJoinTitle), findsNothing);
      expect(find.text(sv.householdJoinedTitle), findsNothing);
    });
  });

  testWidgets('the control: a member of a marked group is offered the join', (
    tester,
  ) async {
    wire();
    await pump(tester, _group());
    expect(find.text(sv.householdJoinTitle), findsOneWidget);
  });

  testWidgets('joining asks first, and cancelling joins nothing', (
    tester,
  ) async {
    wire();
    await pump(tester, _group());

    await tester.tap(find.widgetWithText(TextButton, sv.householdJoinAction));
    await tester.pumpAndSettle();
    expect(find.text(sv.householdJoinConfirmBody), findsOneWidget);

    await tester.tap(find.text(sv.commonCancel));
    await tester.pumpAndSettle();

    verifyNever(
      () => households.joinGroupHousehold(
        ownerId: any(named: 'ownerId'),
        groupId: any(named: 'groupId'),
      ),
    );
    expect(find.text(sv.householdJoinTitle), findsOneWidget);
  });

  testWidgets('confirming joins this group\'s household and shows the joined '
      'state', (tester) async {
    wire();
    await pump(tester, _group());

    await tester.tap(find.widgetWithText(TextButton, sv.householdJoinAction));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(Dialog),
        matching: find.text(sv.householdJoinAction),
      ),
    );
    await tester.pumpAndSettle();

    verify(
      () => households.joinGroupHousehold(ownerId: _owner, groupId: _groupId),
    ).called(1);
    expect(find.text(sv.householdJoinedTitle), findsOneWidget);
  });

  testWidgets('a failed join says so and stays unjoined', (tester) async {
    wire();
    when(
      () => households.joinGroupHousehold(
        ownerId: any(named: 'ownerId'),
        groupId: any(named: 'groupId'),
      ),
    ).thenThrow(StateError('refused'));
    await pump(tester, _group());

    await tester.tap(find.widgetWithText(TextButton, sv.householdJoinAction));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(Dialog),
        matching: find.text(sv.householdJoinAction),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(sv.householdJoinedTitle), findsNothing);
    expect(find.textContaining(sv.householdJoinFailed), findsOneWidget);
  });

  testWidgets('already joined: points to Settings, where sharing is chosen', (
    tester,
  ) async {
    wire(mine: [_household(sourceGroupId: _groupId)]);
    await pump(tester, _group());

    expect(find.text(sv.householdJoinedTitle), findsOneWidget);
    expect(find.text(sv.householdJoinTitle), findsNothing);

    await tester.tap(find.text(sv.householdOpenSettings));
    await tester.pumpAndSettle();
    expect(pushed, [Routes.settings]);
  });

  testWidgets('a household linked to another group is not this one', (
    tester,
  ) async {
    wire(mine: [_household(sourceGroupId: 'another-group')]);
    await pump(tester, _group());
    expect(find.text(sv.householdJoinTitle), findsOneWidget);
  });

  testWidgets('a forged link does not count as joined', (tester) async {
    // Created by someone other than the group's owner while naming the
    // owner's group: `isLinkedToGroup` is false, so the join is still offered.
    wire(
      mine: [_household(sourceGroupId: _groupId, createdBy: _me)],
    );
    await pump(tester, _group());
    expect(find.text(sv.householdJoinTitle), findsOneWidget);
  });

  testWidgets('the group page header carries the row', (tester) async {
    wire();
    await tester.pumpWidget(
      createLocalizedTestApp(
        wrapInScrollView: true,
        child: Builder(
          builder: (context) => GroupDetailHeader.build(context, _group()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text(sv.householdJoinTitle), findsOneWidget);
  });
}
