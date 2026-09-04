import 'dart:async';

import 'package:butlery/viewmodels/collaborative_shopping/shopping_item_operations_manager.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../infrastructure/mocks/production_mocks.dart';

/// BUT-1641: the disposal guard, and why it is a no-op rather than a throw.
///
/// The reaching statement is this manager's OWN — `addItem`'s and
/// `toggleItemCompletion`'s `setError` after an await, and their
/// `finally { _setAddingItem(false); }`. The ViewModel returns
/// the manager's future directly and runs nothing after it, so guarding the
/// parent could never have covered this. `ChangeNotifier.notifyListeners`
/// asserts against a disposed receiver, and that assert is LIVE in debug and
/// test builds, so before the guard the symptom was a developer-visible crash
/// on a shopping list left mid-operation.
void main() {
  // The reachability test the synchronous one above cannot be. It disposes the
  // manager while its own `await` is genuinely in flight, then lets the future
  // land — which is the real sequence, and the one that shows the reaching
  // statement is `finally { _setAddingItem(false); }` inside THIS class rather
  // than anything the ViewModel runs afterwards.
  test(
    'an add that completes after dispose runs its finally without throwing',
    () async {
      final service = MockUnifiedShoppingService();
      final gate = Completer<bool>();
      when(
        () => service.addItemToActiveList(
          name: any(named: 'name'),
          amount: any(named: 'amount'),
          unit: any(named: 'unit'),
          category: any(named: 'category'),
        ),
      ).thenAnswer((_) => gate.future);

      final subject = ShoppingItemOperationsManager(service, 'list-1');
      var notifications = 0;
      subject.addListener(() => notifications++);

      final inFlight = subject.addItem('Mjölk', true, () async {}, (_, _) {});
      expect(subject.isAddingItem, isTrue);
      final duringFlight = notifications;

      // The screen closes mid-operation.
      subject.dispose();
      expect(subject.isDisposed, isTrue);

      // The service answers afterwards. Without the guard, the `finally`'s
      // `_setAddingItem(false)` throws a FlutterError out of the future.
      gate.complete(false);
      await expectLater(inFlight, completion(isFalse));
      expect(notifications, duringFlight);
    },
  );

  test(
    'a setter arriving after dispose notifies nobody and does not throw',
    () {
      final subject = ShoppingItemOperationsManager(
        MockUnifiedShoppingService(),
        'list-1',
      );
      var notifications = 0;
      subject.addListener(() => notifications++);

      subject.setError('varm');
      expect(
        notifications,
        1,
        reason: 'positive control: the listener is wired',
      );
      expect(subject.error, 'varm');

      subject.dispose();
      expect(subject.isDisposed, isTrue);

      // The late continuation. Without the guard this throws a FlutterError
      // from the assert inside notifyListeners.
      expect(() => subject.setError('sent'), returnsNormally);
    },
  );
}
