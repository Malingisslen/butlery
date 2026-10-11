// Mer, omtänkt del 4: the group page has one home per action. The ⋯ sheet
// holds edit / report / leave / delete, "Lägg till medlemmar" is a single row
// at the end of the member list, and the empty-vote CTA opens a route that
// exists.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/core/constants/routes.dart';
import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart' as production;
import 'package:butlery/models/friend_category.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/viewmodels/social_group_detail_viewmodel.dart';
import 'package:butlery/views/social/group_detail/group_detail_app_bar.dart';
import 'package:butlery/views/social/group_detail/group_members_list.dart';
import 'package:butlery/views/social/group_detail/group_share_actions.dart';
import 'package:butlery/views/social/group_detail/group_share_section.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';

import '../../../infrastructure/helpers/widget_test_app.dart';

class _Permissions extends Fake implements PermissionService {
  _Permissions({required this.uid, this.admin = false});

  final String uid;
  final bool admin;

  @override
  String? get currentUserId => uid;

  @override
  bool isGroupAdmin(String groupId) => admin;

  @override
  bool canInviteToGroup(String groupId) => admin;

  @override
  bool isOwner(String ownerId) => ownerId == uid;
}

class _MockViewModel extends Mock implements SocialGroupDetailViewModel {}

FriendCategory _group() => FriendCategory(
  id: 'g1',
  ownerId: 'owner-uid',
  name: 'Familjen',
  friendUserIds: const ['owner-uid', 'me-uid'],
);

void _bootstrap(_Permissions permissions) {
  GetIt.instance.registerSingleton<PermissionService>(permissions);
  production.ServiceLocator.initialize(DIContainer());
}

class _VoteHost extends StatefulWidget {
  const _VoteHost({required this.vm});

  final SocialGroupDetailViewModel vm;

  @override
  State<_VoteHost> createState() => _VoteHostState();
}

class _VoteHostState extends State<_VoteHost>
    with GroupShareActions<_VoteHost> {
  @override
  SocialGroupDetailViewModel get viewModel => widget.vm;

  @override
  Widget build(BuildContext context) => TextButton(
    onPressed: () => startMealVotePoll(_group()),
    child: const Text('vote'),
  );
}

void main() {
  setUp(() {
    GetIt.instance.reset();
    production.ServiceLocator.reset();
  });

  tearDown(() {
    GetIt.instance.reset();
    production.ServiceLocator.reset();
  });

  Future<void> pumpBar(
    WidgetTester tester, {
    required void Function(String) onAction,
  }) async {
    await tester.pumpWidget(
      createLocalizedTestApp(
        wrapInScaffold: false,
        child: Builder(
          builder: (context) => Scaffold(
            appBar: GroupDetailAppBar.build(
              context,
              group: _group(),
              onMenuAction: onAction,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('the ⋯ sheet', () {
    testWidgets('admin: edit, leave and delete, titled with the group name', (
      tester,
    ) async {
      _bootstrap(_Permissions(uid: 'owner-uid', admin: true));
      String? action;
      await pumpBar(tester, onAction: (a) => action = a);

      expect(find.byTooltip('Fler val'), findsOneWidget);
      await tester.tap(find.byIcon(ButleryIcons.moreVertical));
      await tester.pumpAndSettle();

      expect(find.text('Redigera grupp'), findsOneWidget);
      expect(find.text('Lämna gruppen'), findsOneWidget);
      expect(find.text('Ta bort gruppen'), findsOneWidget);
      // The owner cannot report their own group.
      expect(find.text('Rapportera'), findsNothing);
      // Title in the sheet and in the top bar.
      expect(find.text('Familjen'), findsNWidgets(2));
      // Add members lives in the member list only.
      expect(find.text('Lägg till medlemmar'), findsNothing);

      await tester.tap(find.text('Ta bort gruppen'));
      await tester.pumpAndSettle();
      expect(action, 'delete');
      expect(find.text('Lämna gruppen'), findsNothing);
    });

    testWidgets('member: report and leave, no edit or delete', (tester) async {
      _bootstrap(_Permissions(uid: 'me-uid'));
      String? action;
      await pumpBar(tester, onAction: (a) => action = a);

      await tester.tap(find.byIcon(ButleryIcons.moreVertical));
      await tester.pumpAndSettle();

      expect(find.text('Rapportera'), findsOneWidget);
      expect(find.text('Redigera grupp'), findsNothing);
      expect(find.text('Ta bort gruppen'), findsNothing);

      await tester.tap(find.text('Lämna gruppen'));
      await tester.pumpAndSettle();
      expect(action, 'leave_group');
    });
  });

  group('GroupShareSection', () {
    testWidgets('has the three share rows and each fires its own callback', (
      tester,
    ) async {
      final taps = <String>[];
      await tester.pumpWidget(
        createLocalizedTestApp(
          child: GroupShareSection(
            onShareRecipe: () => taps.add('recipe'),
            onShareMenu: () => taps.add('menu'),
            onShareShoppingList: () => taps.add('list'),
          ),
        ),
      );

      expect(find.text('DELA MED GRUPPEN'), findsOneWidget);
      await tester.tap(find.text('Dela ett recept'));
      await tester.tap(find.text('Dela veckomenyn'));
      await tester.tap(find.text('Dela en inköpslista'));
      expect(taps, ['recipe', 'menu', 'list']);
    });
  });

  group('member list', () {
    UserProfile me() => UserProfile(
      uid: 'me-uid',
      displayName: 'Mig',
      email: 'me@example.com',
      joinedAt: DateTime(2025, 1, 1),
      lastActiveAt: DateTime(2025, 1, 1),
    );

    Future<void> pumpList(WidgetTester tester, VoidCallback onAdd) async {
      await tester.pumpWidget(
        createLocalizedTestApp(
          wrapInScrollView: true,
          child: Builder(
            builder: (context) => GroupMembersList.build(
              context,
              members: [me()],
              pendingInvitations: const [],
              group: _group(),
              onAddMembers: onAdd,
              onMemberRemoved: () {},
              onInvitationCancelled: () {},
            ),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('an admin gets exactly one "Lägg till medlemmar" row', (
      tester,
    ) async {
      _bootstrap(_Permissions(uid: 'me-uid', admin: true));
      var adds = 0;
      await pumpList(tester, () => adds++);

      expect(find.text('MEDLEMMAR · 1'), findsOneWidget);
      expect(find.text('Lägg till medlemmar'), findsOneWidget);
      await tester.tap(find.text('Lägg till medlemmar'));
      expect(adds, 1);
    });

    testWidgets('someone who cannot invite gets no add row', (tester) async {
      _bootstrap(_Permissions(uid: 'me-uid'));
      await pumpList(tester, () {});

      expect(find.text('Lägg till medlemmar'), findsNothing);
    });
  });

  testWidgets(
    'the empty-vote CTA opens Routes.addRecipe, a route that exists',
    (tester) async {
      final vm = _MockViewModel();
      when(vm.pickMealVoteSuggestions).thenAnswer((_) async => []);
      final opened = <String?>[];

      await tester.pumpWidget(
        createLocalizedTestApp(
          wrapInScaffold: false,
          child: _VoteHost(vm: vm),
          onGenerateRoute: (settings) {
            opened.add(settings.name);
            return MaterialPageRoute<void>(
              settings: settings,
              builder: (_) => const Scaffold(body: Text('add-recipe-page')),
            );
          },
        ),
      );
      await tester.tap(find.text('vote'));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();

      expect(opened, contains(Routes.addRecipe));
      expect(opened, isNot(contains('/add-recipe')));
      expect(find.text('add-recipe-page'), findsOneWidget);
    },
  );
}
