/// Unit tests for [ChatGroupErrorMapper] (BUT-1838).
///
/// Every ViewModel that calls a chat-group callable routes its failures
/// through this one switch, so each branch here decides what a user is told
/// after that operation fails. The ViewModel suites drive some branches
/// indirectly; the ones that decide whether a specific message is shown AT
/// ALL — the details-shape guards and the `retryAfterSeconds` fallbacks — are
/// only reachable here.
///
/// Every test passes a SENTINEL fallback string that no ARB key could hold,
/// so "returned the fallback" can never coincide with a real message.
library;

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/core/errors/chat_group_error_mapper.dart';
import 'package:butlery/core/l10n/app_locale.dart';

const _fallback = '<<sentinel-fallback-no-arb-key-holds-this>>';

String _map(Object error) =>
    ChatGroupErrorMapper.map(error, genericFallback: _fallback);

void main() {
  group('permission-denied (the minor-membership gate)', () {
    test('names WHO was blocked and never WHY', () {
      final message = _map(
        FirebaseFunctionsException(
          code: 'permission-denied',
          message: 'Some people could not be added to this group.',
          details: const {
            'blockedUserIds': ['uid-teen'],
          },
        ),
      );

      expect(message, equals(AppLocale.current.chatGroupAddMembersBlocked));
      expect(message, isNot(equals(_fallback)));
      // The reason is a minor's age. It must not leak in any spelling, and
      // the blocked uid itself must not be echoed either.
      expect(message.toLowerCase(), isNot(contains('minderårig')));
      expect(message.toLowerCase(), isNot(contains('ålder')));
      expect(message.toLowerCase(), isNot(contains('barn')));
      expect(message, isNot(contains('uid-teen')));
    });

    test(
      'a permission-denied WITHOUT blockedUserIds falls back to generic',
      () {
        // An ordinary "you are not an admin" refusal shares the code but
        // carries no blocked list — telling that caller "some people could
        // not be added" would be plainly wrong.
        expect(
          _map(
            FirebaseFunctionsException(
              code: 'permission-denied',
              message: 'Only an admin may add members.',
            ),
          ),
          equals(_fallback),
        );
      },
    );

    test('details that are not a Map fall back to generic', () {
      expect(
        _map(
          FirebaseFunctionsException(
            code: 'permission-denied',
            message: 'Refused.',
            details: 'blockedUserIds',
          ),
        ),
        equals(_fallback),
      );
    });

    test('a null blockedUserIds value falls back to generic', () {
      expect(
        _map(
          FirebaseFunctionsException(
            code: 'permission-denied',
            message: 'Refused.',
            details: const {'blockedUserIds': null},
          ),
        ),
        equals(_fallback),
      );
    });
  });

  group('resource-exhausted (the rate limiter)', () {
    test('forwards an int retryAfterSeconds into the message', () {
      final message = _map(
        FirebaseFunctionsException(
          code: 'resource-exhausted',
          message: 'Slow down.',
          details: const {'retryAfterSeconds': 17},
        ),
      );

      expect(message, contains('17'));
      expect(message, equals(AppLocale.current.errorRateLimitExceeded(17)));
    });

    test('rounds a non-int num rather than dropping it', () {
      // The callable serialises JSON numbers, so a whole-second value can
      // arrive as a double. 12.6 rounds to 13 — a value that is neither the
      // input nor the 60s default, so no other branch can produce it.
      final message = _map(
        FirebaseFunctionsException(
          code: 'resource-exhausted',
          message: 'Slow down.',
          details: const {'retryAfterSeconds': 12.6},
        ),
      );

      expect(message, equals(AppLocale.current.errorRateLimitExceeded(13)));
      expect(message, isNot(contains('12.6')));
    });

    test('defaults to 60 seconds when details carry no hint', () {
      final noDetails = _map(
        FirebaseFunctionsException(
          code: 'resource-exhausted',
          message: 'Slow down.',
        ),
      );
      final wrongKey = _map(
        FirebaseFunctionsException(
          code: 'resource-exhausted',
          message: 'Slow down.',
          details: const {'retry_after': 5},
        ),
      );
      final unparseable = _map(
        FirebaseFunctionsException(
          code: 'resource-exhausted',
          message: 'Slow down.',
          details: const {'retryAfterSeconds': 'soon'},
        ),
      );

      final expected = AppLocale.current.errorRateLimitExceeded(60);
      expect(noDetails, equals(expected));
      expect(wrongKey, equals(expected));
      expect(unparseable, equals(expected));
      // Never the generic fallback: the user is still told to wait.
      expect(noDetails, isNot(equals(_fallback)));
    });
  });

  group('invalid-argument (the member cap)', () {
    test('a message mentioning members yields the cap wording', () {
      final message = _map(
        FirebaseFunctionsException(
          code: 'invalid-argument',
          message: 'A group can hold at most 100 members.',
        ),
      );

      expect(
        message,
        equals(
          AppLocale.current.chatGroupTooManyMembers(
            ChatGroupErrorMapper.maxMembers,
          ),
        ),
      );
      // The constant must actually reach the rendered string.
      expect(message, contains('100'));
    });

    test('the cap constant is 100', () {
      // One literal, deliberately. The ARB string takes the number as a
      // placeholder, so feeding `maxMembers` into it and reading it back is a
      // tautology. BUT-1960.
      expect(ChatGroupErrorMapper.maxMembers, 100);
    });

    test(
      'an invalid-argument about something else falls back to generic',
      () {
        // e.g. an empty group name. Telling that caller about a 100-member
        // cap would send them looking for a problem they do not have.
        expect(
          _map(
            FirebaseFunctionsException(
              code: 'invalid-argument',
              message: 'name must not be empty',
            ),
          ),
          equals(_fallback),
        );
      },
    );

    test('an empty message falls back to generic', () {
      // The `?? false` half of `error.message?.contains(...) ?? false` is
      // UNREACHABLE from here and deliberately has no test: `message` is a
      // required constructor parameter in cloud_functions_platform_interface,
      // so no caller can build the null case even though the getter's type
      // admits it. The empty string is the reachable neighbour.
      expect(
        _map(
          FirebaseFunctionsException(
            code: 'invalid-argument',
            message: '',
          ),
        ),
        equals(_fallback),
      );
    });
  });

  group('failed-precondition', () {
    test('a structured group-too-small reason gets its own message', () {
      final message = _map(
        FirebaseFunctionsException(
          code: 'failed-precondition',
          message: 'This group has no other members.',
          details: const {'reason': 'group-too-small'},
        ),
      );

      expect(message, equals(AppLocale.current.chatGroupNeedsAnotherMember));
      expect(message, isNot(equals(_fallback)));
    });

    test('a structured conversation-deleted reason gets its own message', () {
      // BUT-1929. The callable threw this case with no `reason` at all, so it
      // landed in the generic fallback.
      final message = _map(
        FirebaseFunctionsException(
          code: 'failed-precondition',
          message: 'Group conversation no longer exists.',
          details: const {'reason': 'conversation-deleted'},
        ),
      );

      expect(message, equals(AppLocale.current.messagingGroupNoLongerExists));
      expect(message, isNot(equals(_fallback)));
    });

    test(
      'a failed-precondition without a recognised reason falls back to generic',
      () {
        // The callables raise this code for other states too — "Group has no
        // conversation.", "Group no longer exists." — and telling that caller
        // to invite someone would be nonsense. Unlike the member cap above,
        // this branch reads a STRUCTURED detail rather than sniffing the
        // English message, which is why it can tell them apart at all.
        expect(
          _map(
            FirebaseFunctionsException(
              code: 'failed-precondition',
              message: 'Group no longer exists.',
            ),
          ),
          equals(_fallback),
        );
        expect(
          _map(
            FirebaseFunctionsException(
              code: 'failed-precondition',
              message: 'This group has no other members.',
              details: const {'reason': 'something-else'},
            ),
          ),
          equals(_fallback),
        );
      },
    );
  });

  group('everything else', () {
    test('an unhandled callable code falls back to generic', () {
      expect(
        _map(
          FirebaseFunctionsException(
            code: 'internal',
            message: 'boom',
          ),
        ),
        equals(_fallback),
      );
      expect(
        _map(
          FirebaseFunctionsException(
            code: 'unauthenticated',
            message: 'signed out',
          ),
        ),
        equals(_fallback),
      );
    });

    test('a plain Dart exception falls back to generic', () {
      expect(_map(Exception('network down')), equals(_fallback));
      expect(_map(StateError('no group')), equals(_fallback));
    });

    test(
      'the caller chooses the fallback — the mapper never substitutes one',
      () {
        // Each ViewModel passes its own operation-specific wording; the
        // mapper must hand back exactly that, not a message of its own.
        const otherFallback = '<<a-different-sentinel>>';
        expect(
          ChatGroupErrorMapper.map(
            Exception('network down'),
            genericFallback: otherFallback,
          ),
          equals(otherFallback),
        );
      },
    );
  });
}
