/// What a screen reader meets on "Skapa gruppkonversation" (BUT-2195): each
/// friend is ONE control carrying the name (and the e-mail when there is
/// one), the selected state and the tap.
///
/// The twin of test/views/social/add_members_to_group_view_test.dart.
library;

import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/repositories/interfaces/chat_group_repository.dart';
import 'package:butlery/services/unified/unified_friends_service.dart';
import 'package:butlery/views/messaging/create_group_conversation_view.dart';

import '../../helpers/user_profile_factory.dart';
import '../../infrastructure/di/test_service_locator.dart';
import '../../infrastructure/mocks/service_mocks.dart'
    show MockChatGroupRepository;
import '../design_states/state_harness.dart';

class _MockFriends extends Mock implements UnifiedFriendsService {}

const _anna = 'Anna Lindqvist';
const _annaLabel = 'Anna Lindqvist, anna@example.se';
const _cecilia = 'Cecilia Berg';

/// The one TAPPABLE semantics node whose label names [name]. Once a friend
/// is selected, the selected-members chip names them too, but it is not the
/// friend's tap target.
SemanticsNode _friendNode(String name) {
  final nodes = find.semantics
      .byPredicate(
        (n) =>
            n.label.contains(name) &&
            n.getSemanticsData().hasAction(SemanticsAction.tap),
      )
      .evaluate()
      .toList();
  expect(nodes, hasLength(1), reason: 'one control announces $name');
  return nodes.single;
}

void main() {
  late StateEnvironment env;

  setUp(() async {
    env = await StateEnvironment.setUp(online: true);
    final friends = _MockFriends();
    when(() => friends.friends).thenReturn([
      testUserProfile(
        uid: 'u-anna',
        displayName: _anna,
        email: 'anna@example.se',
      ),
      testUserProfile(uid: 'u-cecilia', displayName: _cecilia, email: ''),
    ]);
    TestServiceLocator.registerMock<UnifiedFriendsService>(friends);
    TestServiceLocator.registerMock<ChatGroupRepository>(
      MockChatGroupRepository(),
    );
  });

  tearDown(() => env.tearDown());

  Future<void> pumpView(WidgetTester tester) async {
    await tester.pumpWidget(
      stateApp(
        mode: Brightness.light,
        home: const CreateGroupConversationView(),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  testWidgets('a friend is one control: the name and e-mail, a tap, and the '
      'selected state the tap toggles', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpView(tester);

    // Before anyone is selected, nothing else on the screen names Anna.
    final all = find.semantics
        .byPredicate((n) => n.label.contains(_anna))
        .evaluate();
    expect(all, hasLength(1), reason: 'one node announces $_anna');

    var data = _friendNode(_anna).getSemanticsData();
    expect(data.label, _annaLabel);
    expect(data.flagsCollection.isButton, isTrue);
    expect(data.flagsCollection.isSelected, Tristate.isFalse);

    // The screen reader's own activation, not a pointer tap.
    tester.semantics.tap(find.semantics.byLabel(_annaLabel));
    await tester.pump();

    data = _friendNode(_anna).getSemanticsData();
    expect(data.flagsCollection.isSelected, Tristate.isTrue);
    expect(
      _friendNode(_cecilia).getSemanticsData().flagsCollection.isSelected,
      Tristate.isFalse,
    );

    tester.semantics.tap(find.semantics.byLabel(_annaLabel));
    await tester.pump();

    expect(
      _friendNode(_anna).getSemanticsData().flagsCollection.isSelected,
      Tristate.isFalse,
    );
    handle.dispose();
  });

  testWidgets('a friend without an e-mail is announced by the name alone', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await pumpView(tester);

    expect(_friendNode(_cecilia).getSemanticsData().label, _cecilia);
    handle.dispose();
  });
}
