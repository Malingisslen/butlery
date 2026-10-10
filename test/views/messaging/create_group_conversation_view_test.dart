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
const _cecilia = 'Cecilia Berg';

/// The one TAPPABLE semantics node whose label names [name]. Once a friend
/// is selected, the selected-members chip names them too, but it is not the
/// friend's tap target.
SemanticsNode _friendNode(String name) {
  final nodes = _friendFinder(name).evaluate().toList();
  expect(nodes, hasLength(1), reason: 'one control announces $name');
  return nodes.single;
}

FinderBase<SemanticsNode> _friendFinder(String name) =>
    find.semantics.byPredicate(
      (n) =>
          n.label.contains(name) &&
          n.getSemanticsData().hasAction(SemanticsAction.tap),
    );

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

  testWidgets('a friend is one control: the name, a tap, and the selected '
      'state the tap toggles', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpView(tester);

    // Before anyone is selected, nothing else on the screen names Anna.
    final all = find.semantics
        .byPredicate((n) => n.label.contains(_anna))
        .evaluate();
    expect(all, hasLength(1), reason: 'one node announces $_anna');

    var data = _friendNode(_anna).getSemanticsData();
    expect(data.label, _anna);
    expect(data.flagsCollection.isButton, isTrue);
    expect(data.flagsCollection.isSelected, Tristate.isFalse);

    // The screen reader's own activation, not a pointer tap.
    tester.semantics.tap(_friendFinder(_anna));
    await tester.pump();

    data = _friendNode(_anna).getSemanticsData();
    expect(data.flagsCollection.isSelected, Tristate.isTrue);
    expect(
      _friendNode(_cecilia).getSemanticsData().flagsCollection.isSelected,
      Tristate.isFalse,
    );

    tester.semantics.tap(_friendFinder(_anna));
    await tester.pump();

    expect(
      _friendNode(_anna).getSemanticsData().flagsCollection.isSelected,
      Tristate.isFalse,
    );
    handle.dispose();
  });

  // BUT-2264: an older public profile may still carry an address; it is
  // neither shown nor announced.
  testWidgets('a friend is announced by the name alone, never the address', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await pumpView(tester);

    expect(_friendNode(_anna).getSemanticsData().label, _anna);
    expect(find.text('anna@example.se'), findsNothing);
    expect(_friendNode(_cecilia).getSemanticsData().label, _cecilia);
    handle.dispose();
  });

  // BUT-2261: a chosen member's remove button names who it removes,
  // not Flutter's bare "Radera".
  testWidgets('a chosen member chip says whom its remove button removes', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await pumpView(tester);

    tester.semantics.tap(_friendFinder(_anna));
    await tester.pump();

    expect(find.byTooltip('Ta bort $_anna'), findsOneWidget);
    expect(find.byTooltip('Radera'), findsNothing);
    handle.dispose();
  });

  testWidgets('a chosen member chip says the name once, without the avatar '
      'label', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpView(tester);

    tester.semantics.tap(_friendFinder(_anna));
    await tester.pump();

    final chip = find.semantics.byPredicate(
      (n) =>
          n.label.contains(_anna) &&
          !n.getSemanticsData().hasAction(SemanticsAction.tap),
    );
    expect(chip.evaluate(), hasLength(1), reason: 'one chip node names Anna');
    final data = chip.evaluate().single.getSemanticsData();
    final lines = [data.label, data.value, data.tooltip]
        .expand((part) => part.split('\n'))
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
    expect(lines.where((l) => l.contains('Profilbild')), isEmpty);
    expect(
      lines.where((l) => l.contains(_anna)),
      hasLength(1),
      reason: '$lines',
    );
    handle.dispose();
  });
}
