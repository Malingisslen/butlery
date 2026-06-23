// BUT-1360 item 6: RTDB-backed widgets blank out when the device drops
// offline because RTDB has no read cache and emits empty. This transform
// suppresses *empty* emissions while offline, replaying the last non-empty
// value — but trusts every emission (including empties) while online, so a
// legitimately-ended session/offline friend disappears once reconnected.

import 'dart:async';

import 'package:butlery/core/utils/retain_last_nonempty.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('retainLastNonEmptyWhileOffline', () {
    /// Drives a list<int> through the transform with a mutable offline flag,
    /// collecting downstream emissions.
    Future<List<List<int>>> run(
      List<List<int>> input, {
      required bool Function() isOffline,
    }) async {
      final controller = StreamController<List<int>>();
      final out = <List<int>>[];
      final sub = controller.stream
          .transform(
            retainLastNonEmptyWhileOffline<List<int>>(
              isEmpty: (v) => v.isEmpty,
              isOffline: isOffline,
            ),
          )
          .listen(out.add);
      for (final v in input) {
        controller.add(v);
      }
      await controller.close();
      await sub.cancel();
      return out;
    }

    test(
      'online: empty emissions pass straight through (live behaviour)',
      () async {
        final out = await run(
          [
            [1, 2],
            [], // legitimately empty while online — must pass through
            [3],
          ],
          isOffline: () => false,
        );
        expect(out, [
          [1, 2],
          [],
          [3],
        ]);
      },
    );

    test(
      'offline: an empty emission replays the last non-empty value',
      () async {
        // The core ticket assertion: non-empty then empty (offline) → still
        // shows the non-empty value instead of vanishing.
        final out = await run(
          [
            [7, 8],
            [], // offline empty — should be suppressed
          ],
          isOffline: () => true,
        );
        expect(out, [
          [7, 8],
          [7, 8], // retained, not blanked
        ]);
      },
    );

    test(
      'offline with no prior non-empty value: empty passes through',
      () async {
        // First load while offline → no last-known-good → render nothing (we
        // never invent data).
        final out = await run(
          [[]],
          isOffline: () => true,
        );
        expect(out, [<int>[]]);
      },
    );

    test('non-empty change always passes through, even offline', () async {
      // Erik+Sara online → Erik leaves, Sara stays: a non-empty shrink is a
      // real update, never suppressed.
      final out = await run(
        [
          [1, 2],
          [2],
        ],
        isOffline: () => true,
      );
      expect(out, [
        [1, 2],
        [2],
      ]);
    });

    test(
      'flips with connectivity: retain while offline, then trust on reconnect',
      () async {
        var offline = false;
        final controller = StreamController<List<int>>();
        final out = <List<int>>[];
        final sub = controller.stream
            .transform(
              retainLastNonEmptyWhileOffline<List<int>>(
                isEmpty: (v) => v.isEmpty,
                isOffline: () => offline,
              ),
            )
            .listen(out.add);

        controller.add([5]); // online, non-empty
        await Future<void>.delayed(Duration.zero);

        offline = true;
        controller.add([]); // offline empty → retained as [5]
        await Future<void>.delayed(Duration.zero);

        offline = false;
        controller.add([]); // back online, empty is authoritative → passes
        await Future<void>.delayed(Duration.zero);

        await controller.close();
        await sub.cancel();

        expect(out, [
          [5],
          [5], // retained while offline
          [], // trusted once reconnected — legitimately empty now shows
        ]);
      },
    );
  });
}
