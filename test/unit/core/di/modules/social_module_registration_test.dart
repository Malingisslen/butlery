/// BUT-1922: the block filter must actually be registered by the social module.
///
/// `MessagingService.closePoll` refuses to close a poll when
/// `ServiceLocator.tryGet<BlockedUserFilter>()` comes back null (BUT-1926) —
/// absence is "this build cannot tell", not "nobody is blocked". That refusal is
/// correct, and it is also the failure mode nobody would notice: move the
/// registration out of this module and every existing suite stays green, while
/// in production every poll close starts refusing.
///
/// So this pins the registration itself. It resolves nothing — the entries are
/// lazy singletons, so no factory runs and no Firebase is needed.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';

import 'package:butlery/core/di/modules/social_module.dart';
import 'package:butlery/repositories/firebase/firebase_block_repository.dart';
import 'package:butlery/services/social/blocking/blocked_user_filter.dart';

void main() {
  late GetIt container;

  setUp(() {
    container = GetIt.asNewInstance();
  });

  tearDown(() async {
    await container.reset();
  });

  test('SocialModule registers BlockedUserFilter', () async {
    await SocialModule().configure(container);

    expect(
      container.isRegistered<BlockedUserFilter>(),
      isTrue,
      reason:
          'closePoll refuses outright without it, so losing the registration '
          'takes the poll feature down rather than weakening it quietly',
    );
  });

  test(
    'SocialModule registers the repository the filter reads through',
    () async {
      // The filter resolves this lazily, so a missing repository registration
      // would surface only when a poll is closed or a chat is filtered — at which
      // point the filter throws and `closePoll` refuses for a reason that has
      // nothing to do with blocking.
      await SocialModule().configure(container);

      expect(container.isRegistered<FirebaseBlockRepository>(), isTrue);
    },
  );

  test('the module DECLARES both, so the health check can see them', () {
    // `provides` is what the container reports on; a registration missing
    // from it is invisible to that check even when it works.
    expect(SocialModule().provides, contains(BlockedUserFilter));
    expect(SocialModule().provides, contains(FirebaseBlockRepository));
  });
}
