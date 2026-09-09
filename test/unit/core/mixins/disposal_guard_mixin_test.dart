/// BUT-2015: the shared disposal guard, and the two managers that gained it.
///
/// The genuine async case — dispose while an `await` is in flight, via a
/// `Completer`, then let the future land — is asserted twice, in two places,
/// because they prove different things.
///
/// Here, against the MIXIN, using a purpose-built host: since BUT-2015 the
/// guard is one implementation, so the case proving the implementation works
/// belongs with it.
///
/// And in `test/unit/viewmodels/recipe_collaborative_manager_test.dart`,
/// against a REAL manager: its collaborators are constructor-injected, so a
/// `Completer` reaches a genuine await there.
///
/// `SocialEngagementManager` has no such case and cannot get one: its awaits
/// go through `CommentLikesSystem`, which is entirely static over a static
/// repository, so there is no seam to hold a `Completer` behind. Its case below
/// is synchronous and proves only that it CARRIES the guard.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/core/mixins/disposal_guard_mixin.dart';
import 'package:butlery/viewmodels/social_recipe/social_engagement_manager.dart';

/// A host of exactly the shape the guard exists for: it `await`s, then
/// notifies from its OWN continuation.
class _AwaitingHost extends ChangeNotifier with DisposalGuardMixin {
  final Completer<void> gate = Completer<void>();
  bool reachedContinuation = false;

  Future<void> run() async {
    await gate.future;
    reachedContinuation = true;
    notifyListeners();
  }
}

void main() {
  group('DisposalGuardMixin', () {
    test(
      'a continuation landing after dispose does not notify, and does not throw',
      () async {
        final host = _AwaitingHost();
        var notifications = 0;
        host.addListener(() => notifications++);

        final inFlight = host.run();
        expect(host.reachedContinuation, isFalse, reason: 'await is in flight');

        host.dispose();
        host.gate.complete();
        await inFlight;

        // The continuation DID run — this is not a test of cancellation.
        expect(host.reachedContinuation, isTrue);
        // What discriminates is that `await inFlight` above did not throw:
        // `notifyListeners` opens with `debugAssertNotDisposed`, and without
        // the guard that assert escapes the continuation.
        //
        // The count below is NOT a second proof. `ChangeNotifier.dispose()`
        // empties its listener list, so this reads 0 with the guard removed
        // too — it documents the outcome, it does not pin it.
        expect(notifications, 0);
      },
    );

    test('before dispose the same continuation notifies normally', () async {
      final host = _AwaitingHost();
      var notifications = 0;
      host.addListener(() => notifications++);

      final inFlight = host.run();
      host.gate.complete();
      await inFlight;

      expect(notifications, 1);
    });

    test('isDisposed reports both states', () {
      final host = _AwaitingHost();
      expect(host.isDisposed, isFalse);
      host.dispose();
      expect(host.isDisposed, isTrue);
    });
  });

  group('BUT-2015: the manager carries the guard', () {
    test('SocialEngagementManager', () {
      final manager = SocialEngagementManager();
      expect(manager.isDisposed, isFalse);
      manager.dispose();
      expect(manager.isDisposed, isTrue);
      // Post-dispose notification is swallowed rather than thrown. Without the
      // guard `ChangeNotifier.notifyListeners` asserts on a disposed notifier.
      expect(manager.notifyListeners, returnsNormally);
    });
  });
}
