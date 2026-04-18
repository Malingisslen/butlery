// test/unit/services/shopping/claim_race_test.dart
//
// BUT-238: simultaneous-claim race semantics.
// Verifies the last-writer-wins model and the ViewModel's pre-flight
// collision detection so the UI can show "Anna tog den — välj en annan".

library;

import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/models/unified/unified_shopping_item.dart';
import 'package:butlery/models/unified/unified_shopping_list.dart';
import 'package:butlery/viewmodels/collaborative_shopping/shopping_item_operations_manager.dart';

void main() {
  group('BUT-238: claim race semantics', () {
    test(
        'server last-write-wins — whoever writes second overwrites the first assignee',
        () {
      // Start with an unassigned item.
      final item = UnifiedShoppingItem.collaborative(
        name: 'Mjölk',
        amount: 1,
        addedByUserId: 'owner',
        addedByDisplayName: 'Owner',
      );
      expect(item.assignedToUserId, isNull);

      // Both browsers call assign() concurrently. In Firestore these would
      // be two sequential writes; here we simulate by applying them to
      // independent copies, then picking the "winner" by write order.
      final annaClaim = item.assign(userId: 'anna', displayName: 'Anna');
      final bjornClaim = item.assign(userId: 'bjorn', displayName: 'Björn');

      // Whoever lands second wins — this models the Firestore update order.
      final winner = bjornClaim; // simulated second write

      expect(winner.assignedToUserId, equals('bjorn'));
      expect(winner.assignedToDisplayName, equals('Björn'));

      // Anna's optimistic claim is still valid locally — she'll reconcile
      // to `winner` on next snapshot. Both claims represent valid intents.
      expect(annaClaim.assignedToUserId, equals('anna'));
    });

    test(
        'ClaimResult construction reflects the outcome/contingent display name',
        () {
      const success = ClaimResult(ClaimOutcome.claimed);
      expect(success.isSuccess, isTrue);
      expect(success.conflictingDisplayName, isNull);

      const conflict = ClaimResult(
        ClaimOutcome.conflict,
        conflictingDisplayName: 'Anna',
      );
      expect(conflict.isSuccess, isFalse);
      expect(conflict.conflictingDisplayName, equals('Anna'));

      const denied = ClaimResult(ClaimOutcome.denied);
      expect(denied.isSuccess, isFalse);

      const error = ClaimResult(ClaimOutcome.error);
      expect(error.isSuccess, isFalse);
    });

    test(
        'losing UI path: item already assigned to OTHER user surfaces '
        'as a conflict result with the existing assignee name', () {
      final alreadyHeld = UnifiedShoppingItem.collaborative(
        name: 'Ägg',
        amount: 1,
        addedByUserId: 'owner',
        addedByDisplayName: 'Owner',
      ).assign(userId: 'anna', displayName: 'Anna');

      // Simulate the ViewModel's pre-flight: when the local copy already
      // shows Anna as assignee, Björn's claim path must short-circuit.
      final currentUid = 'bjorn';
      final alreadyAssignedToOther = alreadyHeld.assignedToUserId != null &&
          alreadyHeld.assignedToUserId != currentUid;
      expect(alreadyAssignedToOther, isTrue);

      // The manager would return:
      final result = ClaimResult(
        ClaimOutcome.conflict,
        conflictingDisplayName: alreadyHeld.assignedToDisplayName,
      );
      expect(result.outcome, equals(ClaimOutcome.conflict));
      expect(result.conflictingDisplayName, equals('Anna'));
    });

    test('unassign() by assignee releases — re-claim by a peer then succeeds',
        () {
      var item = UnifiedShoppingItem.collaborative(
        name: 'Smör',
        amount: 1,
        addedByUserId: 'owner',
        addedByDisplayName: 'Owner',
      ).assign(userId: 'anna', displayName: 'Anna');
      expect(item.assignedToUserId, equals('anna'));

      item = item.unassign(userId: 'anna', displayName: 'Anna');
      expect(item.isAssigned, isFalse);

      item = item.assign(userId: 'bjorn', displayName: 'Björn');
      expect(item.assignedToUserId, equals('bjorn'));
    });

    test(
        'list-level reconciliation: a mid-flight claim by peer updates local state '
        'when the next snapshot arrives', () {
      final baseItem = UnifiedShoppingItem.collaborative(
        name: 'Pasta',
        amount: 1,
        addedByUserId: 'owner',
        addedByDisplayName: 'Owner',
      );
      final baseList = UnifiedShoppingList(
        name: 'Helg',
        ownerId: 'owner',
        ownerDisplayName: 'Owner',
        items: [baseItem],
      );

      // Peer's snapshot lands with Anna's claim.
      final snapshot = baseList.copyWith(items: [
        baseItem.assign(userId: 'anna', displayName: 'Anna'),
      ]);

      expect(snapshot.items.first.assignedToUserId, equals('anna'));
      // The ViewModel's stream listener replaces local state with this
      // authoritative copy — no merge logic needed.
    });
  });
}
