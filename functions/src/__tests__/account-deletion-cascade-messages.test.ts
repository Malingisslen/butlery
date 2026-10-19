/**
 * BUT-1766 / BUT-1768: deletion cascade messages scenarios, split out of
 * `account-deletion-cascade.test.ts` (BUT-2113). Shared fakes and seeds are
 * `_account-deletion-cascade-fake-firestore.ts` and `_account-deletion-cascade-test-seeds.ts`.
 *
 * Run with: npx ts-node src/__tests__/account-deletion-cascade-messages.test.ts
 */

import {
  DocData,
  FakeFirestore,
} from "./_account-deletion-cascade-fake-firestore";
import {
  OTHER,
  THIRD,
  UID,
  asDb,
  check,
  finishSuite,
  seedMessage,
} from "./_account-deletion-cascade-test-seeds";

// eslint-disable-next-line @typescript-eslint/no-require-imports
const {
  deleteMessages,
} = require("../account/account-deletion-cascade");

/**
 * A 1:1 thread goes entirely — including the counterparty's messages. Once the
 * conversation doc is gone the read rule
 * (`get(conversations/$(conversationId)).data.participantIds`) can never resolve
 * again, so anything left on that `conversationId` is unreachable PII that no
 * later erasure could even find.
 */
async function scenario_directConversationIsErasedWhole(): Promise<void> {
  const db = new FakeFirestore();
  db.set("conversations/c-direct", { participantIds: [UID, OTHER] });
  seedMessage(db, "m1", "c-direct", UID);
  seedMessage(db, "m2", "c-direct", OTHER);

  await deleteMessages(asDb(db), UID);

  check(
    "1:1 conversation document is deleted",
    !db.has("conversations/c-direct"),
  );
  check(
    "both directions of the 1:1 thread are deleted",
    db.idsIn("messages").length === 0,
    `left behind: ${JSON.stringify(db.idsIn("messages"))}`,
  );
}

/**
 * The regression guard for the actual defect: the old implementation read
 * `conversations/{id}/messages`, which this stub can hold but which nothing
 * writes. Seeding BOTH paths proves the step reads the live one — under the old
 * code the top-level message survives untouched and the subcollection doc is
 * what gets deleted.
 */
async function scenario_readsTopLevelNotSubcollection(): Promise<void> {
  const db = new FakeFirestore();
  db.set("conversations/c-direct", { participantIds: [UID, OTHER] });
  seedMessage(db, "live", "c-direct", UID);
  // The phantom path, spelled as a two-segment key this stub's queries can see.
  db.set("conversations/c-direct/messages/phantom", {
    senderId: UID,
    content: "never written in production",
  });

  await deleteMessages(asDb(db), UID);

  check(
    "the TOP-LEVEL message is the one that gets erased",
    !db.has("messages/live"),
    "the sweep still reads the phantom subcollection",
  );
}

/**
 * A surviving group thread keeps its structure — `replyToMessageId` points at
 * ids that would dangle — so the user's own rows are anonymized, the same
 * treatment `deleteCommentsAndRatings` gives `recipe_comments`, and everyone
 * else's rows are untouched.
 */
async function scenario_groupThreadIsAnonymizedNotGutted(): Promise<void> {
  const db = new FakeFirestore();
  db.set("conversations/c-group", { participantIds: [UID, OTHER, THIRD] });
  seedMessage(db, "mine", "c-group", UID);
  seedMessage(db, "theirs", "c-group", OTHER);

  await deleteMessages(asDb(db), UID);

  const mine = db.get("messages/mine");
  check(
    "own group message is kept as a tombstone, not deleted",
    mine !== undefined,
  );
  check(
    "own group message loses uid, name, avatar and content",
    mine?.senderId === "deleted" &&
      mine?.senderDisplayName === "[Raderad användare]" &&
      mine?.senderAvatarUrl === null &&
      mine?.content === "[Borttaget meddelande]",
    `got ${JSON.stringify(mine)}`,
  );

  const theirs = db.get("messages/theirs");
  check(
    "another member's message is untouched",
    theirs?.senderId === OTHER && theirs?.content === "content of theirs",
  );

  const convo = db.get("conversations/c-group");
  check(
    "the group continues with the deleted user removed",
    JSON.stringify(convo?.participantIds) === JSON.stringify([OTHER, THIRD]),
    `got ${JSON.stringify(convo?.participantIds)}`,
  );
}

/**
 * Anonymizing the message ROWS is not the whole erasure: the conversation
 * DOCUMENT carries uid-keyed maps and a full `lastMessage` copy, and every
 * remaining group member reads it. Nothing renames or erases those once the
 * account is gone — `on-profile-updated.ts`, which maintains
 * `participantDisplayNames` / `participantAvatarUrls`, stops firing.
 */
async function scenario_groupConversationDocumentIsScrubbed(): Promise<void> {
  const db = new FakeFirestore();
  db.set("conversations/c-group", {
    participantIds: [UID, OTHER, THIRD],
    participantDisplayNames: { [UID]: "Malin", [OTHER]: "Anna" },
    participantAvatarUrls: {
      [UID]: "https://example.test/malin.jpg",
      [OTHER]: "https://example.test/anna.jpg",
    },
    lastReadTimestamps: { [UID]: 1, [OTHER]: 2 },
    perUserSettings: { [UID]: { isMuted: true }, [OTHER]: { isPinned: true } },
    lastMessage: {
      senderId: UID,
      senderDisplayName: "Malin",
      senderAvatarUrl: "https://example.test/malin.jpg",
      content: "Vi ses klockan sex",
    },
  });
  seedMessage(db, "mine", "c-group", UID);

  await deleteMessages(asDb(db), UID);

  const convo = db.get("conversations/c-group") as Record<
    string,
    Record<string, unknown>
  >;
  check(
    "the deleted user's display name is gone from the conversation doc",
    !(UID in convo.participantDisplayNames),
    `got ${JSON.stringify(convo.participantDisplayNames)}`,
  );
  check(
    "the deleted user's avatar URL is gone from the conversation doc",
    !(UID in convo.participantAvatarUrls),
    `got ${JSON.stringify(convo.participantAvatarUrls)}`,
  );
  check(
    "their read receipts and per-user settings are gone",
    !(UID in convo.lastReadTimestamps) && !(UID in convo.perUserSettings),
    `got ${JSON.stringify({
      lastRead: convo.lastReadTimestamps,
      settings: convo.perUserSettings,
    })}`,
  );
  check(
    "the other members' entries in every map are untouched",
    convo.participantDisplayNames[OTHER] === "Anna" &&
      convo.participantAvatarUrls[OTHER] === "https://example.test/anna.jpg" &&
      convo.lastReadTimestamps[OTHER] === 2,
    `got ${JSON.stringify(convo.participantDisplayNames)}`,
  );
  check(
    "the embedded lastMessage copy is tombstoned like the message row",
    convo.lastMessage.senderId === "deleted" &&
      convo.lastMessage.senderDisplayName === "[Raderad användare]" &&
      convo.lastMessage.senderAvatarUrl === null &&
      convo.lastMessage.content === "[Borttaget meddelande]",
    `got ${JSON.stringify(convo.lastMessage)}`,
  );
}

/** A lastMessage written by someone else must survive the departure intact. */
async function scenario_anotherMembersLastMessageIsNotTombstoned(): Promise<void> {
  const db = new FakeFirestore();
  db.set("conversations/c-group", {
    participantIds: [UID, OTHER, THIRD],
    participantDisplayNames: { [UID]: "Malin", [OTHER]: "Anna" },
    lastMessage: {
      senderId: OTHER,
      senderDisplayName: "Anna",
      content: "Jag handlar imorgon",
    },
  });

  await deleteMessages(asDb(db), UID);

  const convo = db.get("conversations/c-group") as Record<
    string,
    Record<string, unknown>
  >;
  check(
    "another member's lastMessage preview is left alone",
    convo.lastMessage.senderId === OTHER &&
      convo.lastMessage.content === "Jag handlar imorgon",
    `got ${JSON.stringify(convo.lastMessage)}`,
  );
}

/**
 * BUT-1788. The departure callable writes "<Name> har lämnat gruppen" under
 * `senderId: "system"` into a group the user has since LEFT. Three separate
 * legs of this cascade miss it: the `senderId == uid` sweep (wrong author), the
 * `lastMessage` tombstone (only fires when the user is the SENDER), and the
 * `participantIds array-contains uid` query (they are no longer a participant,
 * so the conversation is never even visited). `metadata.subjectUserId` is the
 * only queryable handle on a name embedded in free text.
 */
async function scenario_systemMessageAboutDepartedUserIsScrubbed(): Promise<void> {
  const db = new FakeFirestore();
  // The user is NOT in participantIds — they left. This is the whole point:
  // every other leg of deleteMessages skips this conversation entirely.
  db.set("conversations/c-left", {
    participantIds: [OTHER, THIRD],
    lastMessage: {
      senderId: "system",
      senderDisplayName: "System",
      content: "Malin har lämnat gruppen",
    },
  });
  db.set("messages/sys-left", {
    conversationId: "c-left",
    senderId: "system",
    senderDisplayName: "System",
    content: "Malin har lämnat gruppen",
    metadata: { systemEvent: "participant_left", subjectUserId: UID },
  });
  // A system row about SOMEONE ELSE, in the same collection, must survive.
  db.set("messages/sys-other", {
    conversationId: "c-left",
    senderId: "system",
    senderDisplayName: "System",
    content: "Anna har lämnat gruppen",
    metadata: { systemEvent: "participant_left", subjectUserId: OTHER },
  });

  await deleteMessages(asDb(db), UID);

  const scrubbed = db.get("messages/sys-left");
  check(
    "the departure row about the deleted user is tombstoned",
    scrubbed?.content === "[Borttaget meddelande]",
    `content: ${String(scrubbed?.content)}`,
  );
  check(
    "the erasure handle itself is cleared so the probe reads zero",
    (scrubbed?.metadata as Record<string, unknown> | undefined)
      ?.subjectUserId === undefined,
    `metadata: ${JSON.stringify(scrubbed?.metadata)}`,
  );
  check(
    "the denormalized lastMessage copy is tombstoned too",
    (db.get("conversations/c-left")?.lastMessage as Record<string, unknown>)
      ?.content === "[Borttaget meddelande]",
  );
  check(
    "a departure row about ANOTHER user is untouched",
    db.get("messages/sys-other")?.content === "Anna har lämnat gruppen",
  );
}

/**
 * The mirror must only be rewritten when it is still SHOWING the row being
 * erased — a newer message may have replaced the preview, and blindly stamping
 * the tombstone would erase that message's copy instead.
 */
async function scenario_newerLastMessageSurvivesTheSystemScrub(): Promise<void> {
  const db = new FakeFirestore();
  db.set("conversations/c-left", {
    participantIds: [OTHER, THIRD],
    lastMessage: {
      senderId: OTHER,
      senderDisplayName: "Anna",
      content: "Vi ses på lördag",
    },
  });
  db.set("messages/sys-left", {
    conversationId: "c-left",
    senderId: "system",
    content: "Malin har lämnat gruppen",
    metadata: { systemEvent: "participant_left", subjectUserId: UID },
  });

  await deleteMessages(asDb(db), UID);

  check(
    "a newer preview from another member is left alone",
    (db.get("conversations/c-left")?.lastMessage as Record<string, unknown>)
      ?.content === "Vi ses på lördag",
  );
  check(
    "the system row is still tombstoned",
    db.get("messages/sys-left")?.content === "[Borttaget meddelande]",
  );
}

/**
 * A Firestore whose transaction on a NAMED conversation always throws — the
 * ordinary transient outcome on a live group (contention, DEADLINE_EXCEEDED).
 * Everything else behaves exactly like FakeFirestore.
 */
class FlakyMirrorFirestore extends FakeFirestore {
  constructor(private readonly failingPaths: Set<string>) {
    super();
  }

  async runTransaction<T>(
    handler: (tx: {
      get: (
        ref: { path: string },
      ) => Promise<{ exists: boolean; data: () => DocData | undefined }>;
      getAll: (
        ...refs: { path: string }[]
      ) => Promise<{ exists: boolean; data: () => DocData | undefined }[]>;
      set: (ref: { path: string }, data: DocData) => void;
      update: (ref: { path: string }, data: DocData) => void;
      delete: (ref: { path: string }) => void;
    }) => Promise<T>,
  ): Promise<T> {
    return super.runTransaction((tx) =>
      handler({
        ...tx,
        get: async (ref: { path: string }) => {
          if (this.failingPaths.has(ref.path)) {
            throw Object.assign(new Error("ABORTED: too much contention"), {
              code: 10,
            });
          }
          return tx.get(ref as never);
        },
      } as never),
    );
  }
}

/**
 * BUT-1788, the ordering half. `metadata.subjectUserId` is the ONLY handle that claim-lint:ok moved unchanged, BUT-2113
 * finds these rows again, and the mirror scrub's failure is swallowed on
 * purpose. Clearing the handle in the same write that tombstones the content —
 * i.e. BEFORE the mirror — made a transient mirror failure permanent and
 * quadruple-silent: the mirror keeps the deleted user's name, a re-run
 * early-exits on an empty query, `probeResidualData` (keyed on that same field)
 * counts zero and certifies a clean erasure, and the callable still answers
 * `success: true`. Nothing heals it later — `syncConversationLastMessage`
 * triggers on message create/delete, never on update.
 *
 * The codebase's own recorded rule: a cascade step keyed on a shared handle
 * must destroy that handle LAST.
 */
async function scenario_failedMirrorScrubKeepsTheRetryHandle(): Promise<void> {
  const db = new FlakyMirrorFirestore(new Set(["conversations/c-flaky"]));
  db.set("conversations/c-flaky", {
    participantIds: [OTHER, THIRD],
    lastMessage: {
      senderId: "system",
      senderDisplayName: "System",
      content: "Malin har lämnat gruppen",
    },
  });
  db.set("messages/sys-flaky", {
    conversationId: "c-flaky",
    senderId: "system",
    content: "Malin har lämnat gruppen",
    metadata: { systemEvent: "participant_left", subjectUserId: UID },
  });
  // A second conversation whose mirror scrub SUCCEEDS, in the same run: one bad
  // conversation must not hold back the rest.
  db.set("conversations/c-ok", {
    participantIds: [OTHER, THIRD],
    lastMessage: {
      senderId: "system",
      senderDisplayName: "System",
      content: "Malin har lämnat gruppen",
    },
  });
  db.set("messages/sys-ok", {
    conversationId: "c-ok",
    senderId: "system",
    content: "Malin har lämnat gruppen",
    metadata: { systemEvent: "participant_left", subjectUserId: UID },
  });

  await deleteMessages(asDb(db), UID);

  const flaky = db.get("messages/sys-flaky");
  check(
    "a row whose mirror scrub failed KEEPS its erasure handle",
    (flaky?.metadata as Record<string, unknown> | undefined)?.subjectUserId ===
      UID,
    `metadata: ${JSON.stringify(flaky?.metadata)}`,
  );
  check(
    "…and keeps its original content, so the retry can match the mirror again",
    flaky?.content === "Malin har lämnat gruppen",
    `content: ${String(flaky?.content)}`,
  );
  check(
    "a row whose mirror scrub SUCCEEDED is fully cleared in the same run",
    db.get("messages/sys-ok")?.content === "[Borttaget meddelande]" &&
      (db.get("messages/sys-ok")?.metadata as Record<string, unknown>)
        ?.subjectUserId === undefined,
    `sys-ok: ${JSON.stringify(db.get("messages/sys-ok"))}`,
  );

  // The retry: same data, mirror now healthy. It must converge — which is only
  // possible because the handle survived.
  const healthy = new FakeFirestore();
  for (const path of db.pathsUnder("conversations")) {
    healthy.set(path, db.get(path) as DocData);
  }
  for (const path of db.pathsUnder("messages")) {
    healthy.set(path, db.get(path) as DocData);
  }
  await deleteMessages(asDb(healthy), UID);

  check(
    "the re-run finds the missed row and scrubs the mirror it left behind",
    (healthy.get("conversations/c-flaky")?.lastMessage as Record<
      string,
      unknown
    >)?.content === "[Borttaget meddelande]",
    `lastMessage: ${JSON.stringify(healthy.get("conversations/c-flaky")?.lastMessage)}`,
  );
  check(
    "the re-run then clears the handle it was holding on to",
    (healthy.get("messages/sys-flaky")?.metadata as Record<string, unknown>)
      ?.subjectUserId === undefined &&
      healthy.get("messages/sys-flaky")?.content === "[Borttaget meddelande]",
    `sys-flaky: ${JSON.stringify(healthy.get("messages/sys-flaky"))}`,
  );
  check(
    "the already-clean conversation is not re-tombstoned by the re-run",
    (healthy.get("conversations/c-ok")?.lastMessage as Record<string, unknown>)
      ?.content === "[Borttaget meddelande]",
  );
}

async function main(): Promise<void> {
  await scenario_directConversationIsErasedWhole();
  await scenario_readsTopLevelNotSubcollection();
  await scenario_groupThreadIsAnonymizedNotGutted();
  await scenario_groupConversationDocumentIsScrubbed();
  await scenario_anotherMembersLastMessageIsNotTombstoned();
  await scenario_systemMessageAboutDepartedUserIsScrubbed();
  await scenario_newerLastMessageSurvivesTheSystemScrub();
  await scenario_failedMirrorScrubKeepsTheRetryHandle();

  finishSuite("BUT-1766/BUT-1768 deletion cascade messages");
}

main().catch((err) => {
  console.error("Test runner crashed:", err);
  process.exit(1);
});
