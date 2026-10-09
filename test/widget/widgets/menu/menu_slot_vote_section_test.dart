/// What a person can do with the vote card under a dish of a live menu
/// (BUT-2118): who is offered which action, what a tap sends to the service,
/// and what is said when a write fails. The view model is the real one over a
/// mocked service whose ballot stream the test controls.
library;

import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart' as production;
import 'package:butlery/models/realtime/menu_slot_vote.dart';
import 'package:butlery/services/menu_voting_service.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/viewmodels/menu_viewmodel.dart';
import 'package:butlery/viewmodels/menu_voting_viewmodel.dart';
import 'package:butlery/widgets/menu/menu_slot_vote_section.dart';

import '../../../infrastructure/di/test_service_locator.dart';
import '../../../infrastructure/factories/mock_factory.dart';
import '../../../infrastructure/factories/recipe_factory.dart';
import '../../../infrastructure/helpers/widget_test_app.dart';
import '../../../test_support/base_unit_test.dart';

class _MockVotingService extends Mock implements MenuVotingService {}

class _FakeVote extends Fake implements MenuSlotVote {}

class _FakeMenu extends ChangeNotifier with Fake implements MenuViewModel {
  _FakeMenu({required this.canEditMenu});

  @override
  final bool canEditMenu;
}

final _now = DateTime.utc(2026, 10, 9, 12);
const _menuId = 'menu-1';
const _me = 'me';
const _everyone = {_me, 'anna', 'bo'};

VoteOption _opt(String id, String name) =>
    VoteOption(id: id, dish: {'id': 'recipe-$id', 'title': name});

StartedVote _started({required Duration untilDeadline}) => StartedVote(
  id: 'v1',
  options: [_opt('a', 'Pannkakor'), _opt('b', 'Pasta')],
  deadline: _now.add(untilDeadline),
  createdAt: _now.subtract(const Duration(hours: 2)),
);

MenuBallot _starterBallot({
  required Duration untilDeadline,
  Map<String, VoteOption> proposals = const {},
}) => MenuBallot(
  userId: _me,
  started: {'Middag#0': _started(untilDeadline: untilDeadline)},
  proposals: proposals,
);

const _annaVotedA = MenuBallot(userId: 'anna', ballots: {'v1': 'a'});

const _ranOut = Duration(hours: -1);
const _running = Duration(hours: 24);

Matcher _vote(String id) => isA<MenuSlotVote>().having((v) => v.id, 'id', id);

void main() {
  late _MockVotingService service;
  late StreamController<List<MenuBallot>> ballots;
  late List<String> written;
  late Object? applyError;
  late MenuVotingViewModel voting;

  setUpAll(() async {
    await BaseUnitTest.setupUnit();
    registerFallbackValue(_FakeVote());
    registerFallbackValue(RecipeFactory.build(id: 'fallback'));
  });

  setUp(() async {
    await TestServiceLocator.initialize();
    production.ServiceLocator.initialize(DIContainer());
    TestServiceLocator.registerMock<PermissionService>(
      MockFactory.createPermissionService(currentUserId: _me),
    );
    service = _MockVotingService();
    ballots = StreamController<List<MenuBallot>>.broadcast();
    when(() => service.watchBallots(_menuId)).thenAnswer((_) => ballots.stream);
    for (final call in [
      () => service.castVote(any(), any(), any()),
      () => service.recordWinner(any(), any(), any()),
      () => service.reopen(any(), any()),
      () => service.release(any(), any()),
    ]) {
      when(call).thenAnswer((_) async => true);
    }
    written = [];
    applyError = null;
    voting = MenuVotingViewModel(
      menuId: _menuId,
      votingService: service,
      applyDish: (category, slot, dish) async {
        if (applyError != null) throw applyError!;
        written.add('$category#$slot:${dish.id}');
      },
    );
  });

  tearDown(() async {
    voting.dispose();
    await ballots.close();
    await TestServiceLocator.reset();
    BaseUnitTest.resetMocks();
  });

  /// Runs [body] at a fixed moment, because the card's state turns on the
  /// vote's deadline.
  void inTest(
    String name,
    Future<void> Function(WidgetTester tester) body,
  ) => testWidgets(
    name,
    (tester) => withClock(Clock.fixed(_now), () => body(tester)),
  );

  Future<void> show(
    WidgetTester tester,
    List<MenuBallot> documents, {
    required bool canEdit,
  }) async {
    voting.subscribe();
    voting.setParticipants(_everyone);
    await tester.pumpWidget(
      createLocalizedTestApp(
        wrapInScrollView: true,
        child: MenuSlotVoteSection(
          voting: voting,
          menu: _FakeMenu(canEditMenu: canEdit),
          category: 'Middag',
          slotIndex: 0,
        ),
      ),
    );
    ballots.add(documents);
    await tester.pump();
  }

  final decideAnyway = find.text('Avgör ändå');
  final reopen = find.text('Öppna igen');
  final release = find.text('Släpp platsen');
  final proposeOther = find.text('Föreslå något annat');

  group('a vote that ran out with ballots', () {
    inTest('an editor can decide anyway, reopen or release, and each tap '
        'reaches the service for that vote', (tester) async {
      await show(tester, [
        _starterBallot(untilDeadline: _ranOut),
        _annaVotedA,
      ], canEdit: true);

      expect(find.text('Omröstningen har gått ut'), findsOneWidget);
      await tester.tap(decideAnyway);
      await tester.pump();
      await tester.tap(reopen);
      await tester.pump();
      await tester.tap(release);
      await tester.pump();

      verify(
        () => service.recordWinner(_menuId, any(that: _vote('v1')), 'a'),
      ).called(1);
      expect(written, ['Middag#0:recipe-a']);
      verify(() => service.reopen(_menuId, any(that: _vote('v1')))).called(1);
      verify(() => service.release(_menuId, any(that: _vote('v1')))).called(1);
    });

    inTest('a viewer is offered none of them', (tester) async {
      await show(tester, [
        _starterBallot(untilDeadline: _ranOut),
        _annaVotedA,
      ], canEdit: false);

      expect(
        find.text('Omröstningen har gått ut'),
        findsOneWidget,
        reason: 'the card is there, so its buttons are what is missing',
      );
      expect(decideAnyway, findsNothing);
      expect(reopen, findsNothing);
      expect(release, findsNothing);
    });
  });

  group('an open vote', () {
    inTest('an editor is offered to add a dish, until they have added one', (
      tester,
    ) async {
      await show(tester, [
        _starterBallot(untilDeadline: _running),
      ], canEdit: true);
      expect(proposeOther, findsOneWidget);

      ballots.add([
        _starterBallot(
          untilDeadline: _running,
          proposals: {'v1': _opt('c', 'Gryta')},
        ),
      ]);
      await tester.pump();

      expect(find.text('Gryta'), findsOneWidget);
      expect(proposeOther, findsNothing);
    });

    inTest('a viewer is never offered to add a dish', (tester) async {
      await show(tester, [
        _starterBallot(untilDeadline: _running),
      ], canEdit: false);

      expect(find.text('Pannkakor'), findsOneWidget);
      expect(proposeOther, findsNothing);
    });

    inTest('a viewer can still vote, and the choice reaches the service', (
      tester,
    ) async {
      await show(tester, [
        _starterBallot(untilDeadline: _running),
      ], canEdit: false);

      await tester.tap(find.text('Pasta'));
      await tester.pump();

      verify(
        () => service.castVote(_menuId, any(that: _vote('v1')), 'b'),
      ).called(1);
    });
  });

  group('when a write fails', () {
    inTest('says the vote could not be saved', (tester) async {
      when(
        () => service.castVote(any(), any(), any()),
      ).thenAnswer((_) async => false);
      await show(tester, [
        _starterBallot(untilDeadline: _running),
      ], canEdit: true);

      await tester.tap(find.text('Pasta'));
      await tester.pump();

      expect(find.text('Rösten kunde inte sparas'), findsOneWidget);
    });

    inTest('names the reason the view model gave, and clears it', (
      tester,
    ) async {
      applyError = StateError('menu write refused');
      await show(tester, [
        _starterBallot(untilDeadline: _ranOut),
        _annaVotedA,
      ], canEdit: true);

      await tester.tap(decideAnyway);
      await tester.pump();

      expect(
        find.text('Vinnaren kunde inte läggas in i menyn'),
        findsOneWidget,
      );
      expect(find.text('Rösten kunde inte sparas'), findsNothing);
      expect(voting.hasError, isFalse);
      expect(voting.error, isNull);
      verifyNever(() => service.recordWinner(any(), any(), any()));
    });

    inTest('a release the service refuses is reported too', (tester) async {
      when(
        () => service.release(any(), any()),
      ).thenAnswer((_) async => false);
      await show(tester, [
        _starterBallot(untilDeadline: _ranOut),
        _annaVotedA,
      ], canEdit: true);

      await tester.tap(release);
      await tester.pump();

      expect(find.text('Rösten kunde inte sparas'), findsOneWidget);
    });
  });
}
