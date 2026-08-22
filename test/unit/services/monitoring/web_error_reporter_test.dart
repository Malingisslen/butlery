/// BUT-449: WebErrorReporter payload-shape tests.
///
/// We can't test the full pipeline (FlutterError.onError + callable)
/// without spinning up Firebase + a fake httpsCallable. The contract
/// that matters for this ticket is **PII scrubbing happens on every
/// text field before the payload leaves the device**. `buildPayload`
/// is exposed via `@visibleForTesting` so the assertion is direct.
///
/// The consent gate and the install() side-effects are covered by the
/// runtime — `kIsWeb` is the gate, and the consent check is identical
/// to the native Crashlytics gate in `main.dart` which is itself
/// covered by widget integration tests.
library;

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/services/account/consent_service.dart';
import 'package:butlery/services/monitoring/web_error_reporter.dart';

class _MockFunctions extends Mock implements FirebaseFunctions {}

class _MockConsentService extends Mock implements ConsentService {}

void main() {
  late WebErrorReporter reporter;

  setUp(() {
    // The mocks satisfy the type signatures; `buildPayload` is pure and
    // never reaches them. The constructor's `??` fallback would lazy
    // init a real FirebaseFunctions and crash without `Firebase.initializeApp()`.
    reporter = WebErrorReporter(
      consentService: _MockConsentService(),
      functions: _MockFunctions(),
    );
  });

  group('buildPayload', () {
    test('scrubs email from message', () {
      final payload = reporter.buildPayload(
        error: 'Failed: user alice@example.com hit 500',
        stack: null,
      );
      expect(payload['message'], contains('[EMAIL]'));
      expect(payload['message'], isNot(contains('alice@example.com')));
    });

    test('scrubs personnummer from stack', () {
      final payload = reporter.buildPayload(
        error: 'exception',
        stack: StackTrace.fromString(
          'Error at handler\npayload: 19900101-1234',
        ),
      );
      expect(payload['stack'], contains('[PERSONNUMMER]'));
      expect(payload['stack'], isNot(contains('19900101-1234')));
    });

    // BUT-1897. On web this reporter is the only sink there is — Crashlytics is
    // skipped entirely — so identifiers left in the payload reach Cloud Logging
    // in clear text. `scrubPii` knows free-text personal data and nothing about
    // identifiers, which is why a second scrubber runs beside it.
    group('identifiers (BUT-1897)', () {
      const uid = 'AbCdEfGhIjKlMnOpQrStUvWx1234';
      const otherUid = 'ZyXwVuTsRqPoNmLkJiHgFeDc9876';
      // MUST stay inside `maskIdentifiers`' 20-28 character window. That is the
      // whole point of the frame cases: a shorter name is not a candidate for
      // masking, so it survives a mask-everything mutant for a reason unrelated
      // to the split, and the assertion goes quietly vacuous. A real class
      // name, so a reader can check the length claim.
      const frameClass = 'AllergenPreferencesViewModel';

      test('a uid and a DM id are masked in the message', () {
        final payload = reporter.buildPayload(
          error: 'send failed in direct_${uid}_$otherUid for $uid',
          stack: null,
        );

        expect(payload['message'], isNot(contains(uid)));
        expect(payload['message'], isNot(contains(otherUid)));
        expect(payload['message'], contains('direct_#'));
      });

      test('the exception TYPE LABEL survives, in message and stack alike', () {
        // The whole-string mask ate it: `PermissionDeniedException` is 25
        // alphanumeric characters, the exact shape of a uid, so every report
        // here read `Perm***: ...`. The exception classes split the label off
        // for this reason and this sink was undoing it — on the one platform
        // whose only crash report this is.
        //
        final payload = reporter.buildPayload(
          error: 'PermissionDeniedException: denied, User: $uid',
          stack: StackTrace.fromString(
            'PermissionDeniedException: denied for $uid\n'
            '#0      $frameClass.build (file:///x.dart:1:2)',
          ),
        );

        expect(payload['message'], startsWith('PermissionDeniedException: '));
        expect(payload['message'], isNot(contains(uid)));
        expect(payload['stack'], contains('PermissionDeniedException: '));
        expect(payload['stack'], isNot(contains(uid)));
      });

      test('an identifier at the head is NOT exempted as a type label', () {
        // The label exemption is a hole in the control it sits inside unless it
        // is bounded: a string beginning with `<uid>: ` would otherwise have its
        // uid declared a type name and shipped raw, and `direct_<a>_<b>: `
        // would ship two. Nothing produces either shape today; the bound is
        // there so the exemption cannot swallow the secret.
        final bare = reporter.buildPayload(
          error: '$uid: went wrong',
          stack: null,
        );
        expect(bare['message'], isNot(contains(uid)));

        final dm = reporter.buildPayload(
          error: 'direct_${uid}_$otherUid: send failed',
          stack: null,
        );
        expect(dm['message'], isNot(contains(uid)));
        expect(dm['message'], isNot(contains(otherUid)));
      });

      test('a V8 head keeps the INNER type name too', () {
        // V8 nests labels: `Error: PermissionDeniedException: …`. Peeling only
        // the engine's own leaves ours inside the masked span, where it is 25
        // characters and gets eaten — the blocker this batch fixed, surviving
        // in the stack on Chrome and Edge while the message field was correct.
        final payload = reporter.buildPayload(
          error: 'boom',
          stack: StackTrace.fromString(
            'Error: PermissionDeniedException: denied for $uid\n'
            '    at $frameClass.build (main.dart.js:1:2)',
          ),
        );

        expect(payload['stack'], contains('PermissionDeniedException: '));
        expect(payload['stack'], isNot(contains(uid)));
        expect(payload['stack'], contains(frameClass));
      });

      test('the exemption stops after TWO label slots', () {
        // The upper bound was pinned by nothing: widening the peel loop to
        // three or four slots left the whole suite green, so the exemption
        // could creep outward silently — and the exemption is the one place
        // where an identifier is deliberately NOT masked.
        //
        // `Abcdefghijklmnopqrstuvwx` is 24 letters, digit-free and
        // capital-initial, so it satisfies the label shape. It sits one slot
        // past the last legitimate label, which is where a third peel would
        // reach it.
        final payload = reporter.buildPayload(
          error: 'boom',
          stack: StackTrace.fromString(
            'Error: SomeException: Abcdefghijklmnopqrstuvwx: boom\n'
            '    at $frameClass.build (main.dart.js:1:2)',
          ),
        );

        expect(payload['stack'], isNot(contains('Abcdefghijklmnopqrstuvwx')));
      });

      test('a stack keeps its FRAMES readable', () {
        // The identifier rule truncates any 20-28 character alphanumeric run,
        // and hundreds of class names are exactly that shape. Masking whole
        // frames would make a web crash report useless, which is the only
        // report web has.
        final payload = reporter.buildPayload(
          error: 'boom',
          stack: StackTrace.fromString(
            '#0      $frameClass.build (file:///x.dart:1:2)',
          ),
        );

        expect(payload['stack'], contains(frameClass));
      });

      test('a Firefox/Safari trace keeps its frames too', () {
        // Those engines emit `fn@url:line:col` and NO header line, so a splitter
        // that knows only Dart's `#0 ` and V8's `at ` matches nothing, treats
        // the whole trace as message head, and mangles every frame — on every
        // report from those browsers.
        final payload = reporter.buildPayload(
          error: 'boom',
          stack: StackTrace.fromString(
            '$frameClass@https://app.example/main.dart.js:1:2',
          ),
        );

        expect(payload['stack'], contains(frameClass));
      });

      test('a V8 (Chrome/Edge) trace keeps its frames too', () {
        // The majority browser, and the only one of the three frame spellings
        // whose alternative nothing else in this file reaches: a V8 frame line
        // carries no `#0 ` and no `@`, so deleting `at \S` from the splitter
        // leaves the whole trace looking like message head and mangles every
        // frame — measured, and reddened by nothing before this test existed.
        final payload = reporter.buildPayload(
          error: 'boom',
          stack: StackTrace.fromString(
            'Error: conversation direct_${uid}_$otherUid is gone\n'
            '    at AllergenPreferencesViewModel.build '
            '(http://app/main.dart.js:1:2)',
          ),
        );

        expect(payload['stack'], contains(frameClass));
        expect(payload['stack'], isNot(contains(uid)));
      });

      test('a stack with no recognisable frame is masked whole', () {
        // The fail-safe arm of the split, and nothing else reaches it: every
        // other case lands on a frame at index 0 or past it. Weakening this
        // branch to `scrubPii` alone left every other test in this group green
        // — an unpinned fail-safe in the one sink web has. Stated as a rule
        // rather than a count: the suite has grown since, so a number here
        // would already match nothing.
        final payload = reporter.buildPayload(
          error: 'boom',
          stack: StackTrace.fromString(
            'lost conversation direct_${uid}_$otherUid',
          ),
        );

        expect(payload['stack'], isNot(contains(uid)));
        expect(payload['stack'], isNot(contains(otherUid)));
      });

      test('but the stack HEAD is masked, because it repeats the message', () {
        // Under dart2js a thrown object is wrapped in a JS Error whose message
        // is the object's own toString(), and the engine formats `.stack` as
        // that message followed by the frames. So the first line of a web stack
        // is a verbatim copy of the string `message` was just masked from —
        // masking one and not the other exports it anyway.
        //
        // The frame identifier is 28 characters ON PURPOSE. `MessagingService`
        // stood here first and is 16, i.e. below the identifier rule's {20,28}
        // window — so it survived masking for a reason that has nothing to do
        // with the split, and this test's whole output was byte-identical under
        // a mutant that masked the entire stack. Its own `reason` line named
        // the one thing its fixture could not show.
        final payload = reporter.buildPayload(
          error: 'boom',
          stack: StackTrace.fromString(
            'StateError: conversation direct_${uid}_$otherUid is gone\n'
            '#0      AllergenPreferencesViewModel.build (file:///y.dart:3:4)',
          ),
        );

        expect(payload['stack'], isNot(contains(uid)));
        expect(payload['stack'], isNot(contains(otherUid)));
        expect(
          payload['stack'],
          contains('AllergenPreferencesViewModel.build'),
          reason: 'masking the head must not cost the frames',
        );
      });
    });

    test('scrubs PII from context field', () {
      final payload = reporter.buildPayload(
        error: 'boom',
        stack: null,
        context: 'Triggered by request from bob@host.com',
      );
      expect(payload['context'], contains('[EMAIL]'));
      expect(payload['context'], isNot(contains('bob@host.com')));
    });

    test('omits stack when null', () {
      final payload = reporter.buildPayload(error: 'boom', stack: null);
      expect(payload.containsKey('stack'), isFalse);
    });

    test('omits context when null', () {
      final payload = reporter.buildPayload(error: 'boom', stack: null);
      expect(payload.containsKey('context'), isFalse);
    });

    // BUT-1897: scrubbing runs BEFORE truncation, and nothing pinned that. The
    // two truncation cases below use runs of a single repeated character —
    // longer than 28, so the identifier rule never touches them — which means
    // swapping the two operations left the whole suite green.
    //
    // A uid straddling the 2000-char cut is what discriminates: truncate first
    // and the tail is severed below the 20-character window, so the head ships
    // RAW.
    //
    // Assert on the SURVIVING PREFIX, not on the whole uid. The first version of
    // this case checked `isNot(contains(uid))` and passed under both orders —
    // truncation removes the uid's tail either way, so the full string is absent
    // whether or not it was masked. Probed and caught.
    test('a uid straddling the truncation cut is still masked', () {
      const uid = 'AbCdEfGhIjKlMnOpQrStUvWx1234';
      // Filler that does NOT merge with the uid. A run of letters would join it
      // into one 2000-character token, which is outside the 20-28 window in
      // either order — the second way this case managed to pass for the wrong
      // reason before it was probed.
      final payload = reporter.buildPayload(
        error: '${'x ' * 995}$uid tail',
        stack: null,
      );

      expect(
        payload['message'],
        isNot(contains(uid.substring(0, 8))),
        reason:
            'scrub-then-truncate leaves AbCd***; truncate-then-scrub severs the '
            'uid at 10 characters — too short for the 20-28 window — so its raw '
            'head ships. Eight characters, because only ten survive the cut: a '
            'longer prefix is absent under BOTH orders and pins nothing.',
      );
    });

    test('truncates oversized message to 2000 chars', () {
      final big = 'A' * 5000;
      final payload = reporter.buildPayload(error: big, stack: null);
      expect((payload['message'] as String).length, equals(2000));
    });

    test('truncates oversized stack to 8000 chars', () {
      final stackText = 'S' * 20000;
      final payload = reporter.buildPayload(
        error: 'short',
        stack: StackTrace.fromString(stackText),
      );
      expect((payload['stack'] as String).length, equals(8000));
    });

    test('passes fatal flag through', () {
      final payload = reporter.buildPayload(
        error: 'crashed',
        stack: null,
        fatal: true,
      );
      expect(payload['fatal'], isTrue);
    });

    test('fatal defaults to false', () {
      final payload = reporter.buildPayload(error: 'boom', stack: null);
      expect(payload['fatal'], isFalse);
    });

    test('platform is always "web"', () {
      final payload = reporter.buildPayload(error: 'boom', stack: null);
      expect(payload['platform'], equals('web'));
    });

    test('occurredAt is ISO8601 UTC', () {
      final payload = reporter.buildPayload(error: 'boom', stack: null);
      final ts = payload['occurredAt'] as String;
      expect(ts, endsWith('Z'));
      expect(() => DateTime.parse(ts), returnsNormally);
    });
  });
}
