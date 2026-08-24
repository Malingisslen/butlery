// lib/core/errors/message_send_error_mapper.dart

import 'package:clock/clock.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:butlery/core/utils/logger.dart';

/// Why a chat message send failed, as far as the client can tell (BUT-1903).
enum MessageSendFailure {
  /// The device clock runs far enough ahead that the messages create rule
  /// refuses the write. The user can fix this themselves.
  clockAhead,

  /// Anything else — a new account inside its maturity window, the rate
  /// limiter, a lost membership, a conversation that no longer exists, or a
  /// network fault. The batch-commit path swallows `UNAVAILABLE`/network and
  /// returns normally, but that swallow covers the COMMIT only; BUT-1831 left
  /// the conversation read as a second, unswallowed failure point on the same
  /// send. Either way the classification is the same — not `permission-denied`
  /// means `other` — so do not turn that into a claim about what offline does.
  other,
}

/// Turns a failed message send into something the sender can act on.
///
/// This exists because BUT-1903 tightened the create rule to refuse a `sentAt`
/// more than an hour ahead of the server, and `Message` stamps the DEVICE
/// clock. Without this, a phone whose clock is set wrong gets every send
/// refused forever behind a generic "kunde inte skicka", with no way to connect
/// the two. The rule and this mapper ship together; neither is defensible
/// alone.
///
/// The hard part is that **Firestore returns one opaque `permission-denied` for
/// every conjunct on that rule** — the clock bound, `rateLimitWrite`,
/// `isAccountMatured` (a brand-new unverified account cannot chat for 60
/// minutes), `isAgeCompliant`, and non-membership all look identical from here.
/// A blanket "check your clock" would be wrong for every new user. So the clock
/// message is EARNED, by measuring the device against a server-stamped value.
///
/// LOAD-BEARING: this only works because the denial arrives here UNWRAPPED.
/// FIVE links, in unwind order, all of which must stay transparent:
///
///   1. `MessageMutationModule.sendMessage` — rethrows any commit failure that
///      is not `UNAVAILABLE`/network (those it swallows as an offline queue).
///   2. `FirebaseMessagingRepository.sendMessage` — a bare delegate.
///   3. `MessageSendingOperations.sendTextMessage` — logs, rethrows.
///   4. `MessagingService.sendTextMessage` — a bare passthrough TODAY, and the
///      likeliest place for someone to add handling: `sendPollMessage`
///      elsewhere in the same class already wraps its send in try/catch, and
///      `ChatViewModel.sendTextMessage` calls this method and converts the
///      failure into its own error state, so there is a live precedent one
///      layer up.
///   5. `ChatActionHandler.handleSendMessage` — rethrows without touching it.
///
/// If ANY of the five wraps the failure in a domain exception, the type check
/// below stops matching and every affected user quietly returns to the generic
/// message. The widget tests cannot see it: they substitute `onSendMessage`
/// itself and bypass all five.
///
/// How much IS pinned, measured rather than assumed — an earlier draft of this
/// paragraph said "untested by anything", which a reader disproves in thirty
/// seconds and then stops trusting the rest. A BLANKET `catch (e) { throw ... }`
/// at links 1, 3 or 4 already reddens existing type-identity assertions
/// (`messaging_service_test.dart`'s "Message Sending Errors" group runs 3 and 4
/// together, because the service builds its own operations object;
/// `message_mutation_module_test.dart` covers 1).
///
/// The residual those suites cannot see is a TYPE-SELECTIVE wrap —
/// `on FirebaseException catch (e) { throw Domain(e); }` — which every existing
/// assertion survives, because each of them throws a non-Firebase exception.
/// It is not the only one: link 1 selects by `toString().contains('UNAVAILABLE')`,
/// so WIDENING that string queues a permission denial as "offline", the send
/// returns normally, `classify` never runs and the user sees nothing at all —
/// not even the generic message. The module suite's assertions sit above the
/// batch and never reach that inner catch.
///
/// Links 2 and 5 are unpinned by choice, and only link 2's reason is comfortable:
/// it is an arrow delegate with no catch block to grow. Link 5's likeliest drift
/// — losing its `rethrow` — is the WORST failure in this whole chain, and two
/// drafts of this sentence called it "loud". It is silent. `ChatActionHandler`
/// deliberately displays nothing, so if it swallows, `await onSendMessage(...)`
/// in `ChatInputSection` returns normally, the success path runs, the user's
/// TEXT IS CLEARED, and the catch that would classify and show a message is
/// never reached. Nothing was sent and nothing says so. Verified by reading
/// `chat_input_section.dart:130-145` rather than reasoned about.
///
/// Change a layer in that list, re-read this. The list was four links until the
/// code-review gate found the fifth — the one a grep of the other four misses.
class MessageSendErrorMapper {
  MessageSendErrorMapper._();

  /// Mirrors `request.resource.data.sentAt <= request.time + duration.value(1, 'h')`
  /// on the `messages` create rule in `firestore.rules`. Kept in sync by hand —
  /// the same convention `isAccountMatured` uses for `kAccountMaturityWindow`.
  ///
  /// The threshold is the rule's OWN bound and deliberately not smaller. A
  /// device ten minutes ahead is ALLOWED by the rule, so if it is refused it was
  /// refused by something else; classifying below the bound would blame the
  /// clock for the rate limiter's work.
  static const Duration maxSentAtLead = Duration(hours: 1);

  /// [readServerIssuedAt] must return a FRESHLY server-stamped instant — in
  /// production, `issuedAtTime` from `user.getIdTokenResult(true)`. Force-refresh
  /// matters: a cached token can be up to an hour old, which is exactly the
  /// magnitude being measured, so a stale one cannot tell skew from token age.
  static Future<MessageSendFailure> classify(
    Object error, {
    required Future<DateTime?> Function() readServerIssuedAt,
  }) async {
    if (error is! FirebaseException || error.code != 'permission-denied') {
      return MessageSendFailure.other;
    }

    final DateTime? issuedAt;
    try {
      issuedAt = await readServerIssuedAt();
    } catch (e) {
      // The probe is a diagnosis, never a second failure. If it cannot answer,
      // the user still gets the generic message rather than a wrong one.
      AppLogger.warning('Clock-skew probe failed; falling back to generic: $e');
      return MessageSendFailure.other;
    }

    // `IdTokenResult.issuedAtTime` is `DateTime?`. A null is an absence of
    // evidence, and must never be read as evidence about somebody's clock.
    if (issuedAt == null) return MessageSendFailure.other;

    final lead = clock.now().toUtc().difference(issuedAt.toUtc());
    return lead > maxSentAtLead
        ? MessageSendFailure.clockAhead
        : MessageSendFailure.other;
  }
}
