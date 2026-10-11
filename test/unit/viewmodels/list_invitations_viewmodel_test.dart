/// ListInvitationsViewModel decides what stays listed after an answer: a
/// settled or void invitation goes, a transient failure keeps its card.
library;

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/models/social_request.dart';
import 'package:butlery/services/analytics/trackers/social_events_tracker.dart';
import 'package:butlery/services/analytics_service.dart';
import 'package:butlery/services/unified/operations/list_invitation_operations.dart';
import 'package:butlery/viewmodels/list_invitations_viewmodel.dart';

class _MockOps extends Mock implements ListInvitationOperations {}

class _MockAnalytics extends Mock implements AnalyticsService {}

class _MockSocial extends Mock implements SocialEventsTracker {}

SocialRequest _inv(String id, {String from = 'anna', DateTime? expiresAt}) =>
    SocialRequest(
      id: id,
      type: SocialRequestType.listInvitation,
      fromUserId: from,
      toUserId: 'bob',
      listId: 'l-$id',
      listName: 'Lista $id',
      permission: 'edit',
      fromUserName: 'Anna',
      expiresAt: expiresAt,
    );

void main() {
  late _MockOps ops;
  late _MockAnalytics analytics;
  late _MockSocial social;
  late StreamController<List<SocialRequest>> rows;
  late ListInvitationsViewModel vm;

  setUp(() {
    ops = _MockOps();
    analytics = _MockAnalytics();
    social = _MockSocial();
    rows = StreamController<List<SocialRequest>>.broadcast();
    when(() => ops.pendingReceived).thenAnswer((_) => rows.stream);
    when(() => analytics.social).thenReturn(social);
    when(() => social.logListInvitationAccepted()).thenAnswer((_) async {});
    when(() => social.logListInvitationDeclined()).thenAnswer((_) async {});
    vm = ListInvitationsViewModel(operations: ops, analytics: analytics);
  });

  tearDown(() async {
    vm.dispose();
    await rows.close();
  });

  Future<void> emit(List<SocialRequest> list) async {
    rows.add(list);
    await Future<void>.delayed(Duration.zero);
  }

  test('lists what the stream delivers and nothing when it is empty', () async {
    expect(vm.invitations, isEmpty);

    await emit([_inv('a'), _inv('b')]);
    expect(vm.invitations.map((r) => r.id), ['a', 'b']);

    await emit([]);
    expect(vm.invitations, isEmpty);
  });

  test('an invitation that has expired is not listed', () async {
    await emit([
      _inv('live'),
      _inv('dead', expiresAt: DateTime.now().subtract(const Duration(days: 1))),
    ]);

    expect(vm.invitations.map((r) => r.id), ['live']);
  });

  group('accept', () {
    test('success removes the card and logs one accepted event', () async {
      when(
        () => ops.acceptListInvitation('a'),
      ).thenAnswer((_) async => ListInvitationOutcome.accepted);
      await emit([_inv('a'), _inv('b')]);

      final outcome = await vm.accept('a');

      expect(outcome, ListInvitationOutcome.accepted);
      expect(vm.invitations.map((r) => r.id), ['b']);
      verify(() => social.logListInvitationAccepted()).called(1);
      verifyNever(() => social.logListInvitationDeclined());
    });

    test(
      'the server snapshot still showing the row does not bring it back',
      () async {
        when(
          () => ops.acceptListInvitation('a'),
        ).thenAnswer((_) async => ListInvitationOutcome.accepted);
        await emit([_inv('a')]);
        await vm.accept('a');

        await emit([_inv('a')]);

        expect(vm.invitations, isEmpty);
      },
    );

    test('alreadyMember removes the card but logs no accepted event', () async {
      when(
        () => ops.acceptListInvitation('a'),
      ).thenAnswer((_) async => ListInvitationOutcome.alreadyMember);
      await emit([_inv('a')]);

      await vm.accept('a');

      expect(vm.invitations, isEmpty);
      verifyNever(() => social.logListInvitationAccepted());
    });

    test('a refusal removes the card, since the invitation is void', () async {
      when(
        () => ops.acceptListInvitation('a'),
      ).thenAnswer((_) async => ListInvitationOutcome.notAvailable);
      await emit([_inv('a')]);

      final outcome = await vm.accept('a');

      expect(outcome, ListInvitationOutcome.notAvailable);
      expect(vm.invitations, isEmpty);
      verifyNever(() => social.logListInvitationAccepted());
    });

    for (final outcome in [
      ListInvitationOutcome.offline,
      ListInvitationOutcome.failed,
    ]) {
      test(
        '$outcome keeps the card for another try and logs nothing',
        () async {
          when(
            () => ops.acceptListInvitation('a'),
          ).thenAnswer((_) async => outcome);
          await emit([_inv('a')]);

          expect(await vm.accept('a'), outcome);

          expect(vm.invitations.map((r) => r.id), ['a']);
          expect(vm.isResponding('a'), isFalse);
          verifyNever(() => social.logListInvitationAccepted());
        },
      );
    }

    test('while the call runs the card is responding and a second tap is '
        'ignored', () async {
      final gate = Completer<ListInvitationOutcome>();
      when(() => ops.acceptListInvitation('a')).thenAnswer((_) => gate.future);
      await emit([_inv('a')]);

      final first = vm.accept('a');
      expect(vm.isResponding('a'), isTrue);
      await vm.accept('a');
      gate.complete(ListInvitationOutcome.accepted);
      await first;

      verify(() => ops.acceptListInvitation('a')).called(1);
      expect(vm.isResponding('a'), isFalse);
    });
  });

  group('decline', () {
    test('success removes the card and logs one declined event', () async {
      when(
        () => ops.declineListInvitation('a'),
      ).thenAnswer((_) async => ListInvitationOutcome.declined);
      await emit([_inv('a')]);

      expect(await vm.decline('a'), ListInvitationOutcome.declined);

      expect(vm.invitations, isEmpty);
      verify(() => social.logListInvitationDeclined()).called(1);
      verifyNever(() => social.logListInvitationAccepted());
    });

    test('offline keeps the card and logs nothing', () async {
      when(
        () => ops.declineListInvitation('a'),
      ).thenAnswer((_) async => ListInvitationOutcome.offline);
      await emit([_inv('a')]);

      await vm.decline('a');

      expect(vm.invitations.map((r) => r.id), ['a']);
      verifyNever(() => social.logListInvitationDeclined());
    });

    test(
      'a void invitation removes the card but logs no declined event',
      () async {
        when(
          () => ops.declineListInvitation('a'),
        ).thenAnswer((_) async => ListInvitationOutcome.notAvailable);
        await emit([_inv('a')]);

        expect(await vm.decline('a'), ListInvitationOutcome.notAvailable);

        expect(vm.invitations, isEmpty);
        verifyNever(() => social.logListInvitationDeclined());
      },
    );

    test('failed keeps the card and logs nothing', () async {
      when(
        () => ops.declineListInvitation('a'),
      ).thenAnswer((_) async => ListInvitationOutcome.failed);
      await emit([_inv('a')]);

      expect(await vm.decline('a'), ListInvitationOutcome.failed);

      expect(vm.invitations.map((r) => r.id), ['a']);
      verifyNever(() => social.logListInvitationDeclined());
    });
  });

  group('dispose', () {
    late StreamController<List<SocialRequest>> ownRows;
    late ListInvitationsViewModel own;

    setUp(() {
      ownRows = StreamController<List<SocialRequest>>.broadcast();
      final ownOps = _MockOps();
      when(() => ownOps.pendingReceived).thenAnswer((_) => ownRows.stream);
      when(() => ownOps.acceptListInvitation('a')).thenAnswer(
        (_) async => ListInvitationOutcome.accepted,
      );
      own = ListInvitationsViewModel(operations: ownOps, analytics: analytics);
    });

    tearDown(() => ownRows.close());

    test('stops listening to the invitations', () {
      expect(ownRows.hasListener, isTrue);

      own.dispose();

      expect(ownRows.hasListener, isFalse);
    });

    test(
      'an answer that lands after the section is gone does not throw',
      () async {
        final gate = Completer<ListInvitationOutcome>();
        final gatedOps = _MockOps();
        when(() => gatedOps.pendingReceived).thenAnswer((_) => ownRows.stream);
        when(
          () => gatedOps.acceptListInvitation('a'),
        ).thenAnswer((_) => gate.future);
        final gated = ListInvitationsViewModel(
          operations: gatedOps,
          analytics: analytics,
        );
        own.dispose();

        final pending = gated.accept('a');
        gated.dispose();
        gate.complete(ListInvitationOutcome.accepted);

        expect(await pending, ListInvitationOutcome.accepted);
      },
    );

    test('blocking after the section is gone does not throw', () {
      own.dispose();

      expect(() => own.dismissFrom('anna'), returnsNormally);
    });
  });

  test(
    'dismissFrom hides every invitation from a blocked sender only',
    () async {
      await emit([_inv('a'), _inv('b', from: 'carl'), _inv('c')]);

      vm.dismissFrom('anna');

      expect(vm.invitations.map((r) => r.id), ['b']);
      await emit([_inv('a'), _inv('b', from: 'carl'), _inv('c')]);
      expect(vm.invitations.map((r) => r.id), ['b']);
    },
  );

  test(
    'a failing stream leaves the section empty instead of throwing',
    () async {
      await emit([_inv('a')]);

      rows.addError(StateError('boom'));
      await Future<void>.delayed(Duration.zero);

      expect(vm.invitations, isEmpty);
      expect(vm.hasError, isTrue);
    },
  );
}
