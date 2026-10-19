/**
 * BUT-1766 / BUT-1768: deletion cascade polls and message reactions scenarios, split out of
 * `account-deletion-cascade.test.ts` (BUT-2113). Shared fakes and seeds are
 * `_account-deletion-cascade-fake-firestore.ts` and `_account-deletion-cascade-test-seeds.ts`.
 *
 * Run with: npx ts-node src/__tests__/account-deletion-cascade-polls-reactions.test.ts
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
  emptyResult,
  finishSuite,
  probeAfter,
  sawResidual,
} from "./_account-deletion-cascade-test-seeds";

// eslint-disable-next-line @typescript-eslint/no-require-imports
const {
  deleteMessages,
} = require("../account/account-deletion-cascade");

/**
 * BUT-1835 — the erased user's poll votes and their authorship of polls.
 *
 * Two residues, and neither covers the other. The VOTE rows live at
 * `messages/{id}/poll_votes/{uid}` under messages this user may never have
 * sent, in conversations `deleteMessages` leaves standing, so no other leg of claim-lint:ok moved unchanged, BUT-2113
 * this cascade reaches them. The AUTHORSHIP lives at
 * `metadata.poll.creatorId` inside a message document; `deleteMessages`
 * anonymises `senderId` on their own messages and never looks inside
 * `metadata`, so on every surviving poll the raw uid stayed.
 *
 * Written against the SUBCOLLECTION shape BUT-1832 introduced, not the inline
 * `metadata.poll.options[].voterIds` array it replaced. That array is still
 * emitted (`Poll.toMap` writes it, `closePoll` rewrites the whole metadata map)
 * but no VOTER uid has landed in it since BUT-1832 — `closePoll` reads the raw
 * snapshot, not the hydrated model, so the display tally cannot round-trip.
 * A poll from the PRE-BUT-1832 client can still hold its author's own uid there;
 * dev-project data only, and the production comment on `deletePollVotes` carries
 * the full reasoning. Scrubbing the array instead of the subcollection would
 * chase a field no live writer fills while missing every vote made since.
 */
async function scenario_pollVotesAndAuthorshipAreErased(): Promise<void> {
  const db = new FakeFirestore();
  // A GROUP conversation, so `deleteMessages` scrubs membership and leaves the
  // conversation and its messages standing — which is what makes these rows
  // survivable in the first place.
  db.set("conversations/group-1", {
    participantIds: [UID, OTHER, "third-uid"],
    participantDisplayNames: { [UID]: "Raderad", [OTHER]: "Kvar" },
    isGroup: true,
  });
  // A poll SOMEBODY ELSE opened. The erased user only voted in it — nothing
  // else in the cascade would ever touch this message.
  db.set("messages/poll-theirs", {
    conversationId: "group-1",
    senderId: OTHER,
    content: "Vad ska vi äta?",
    metadata: {
      poll: {
        id: "p1",
        creatorId: OTHER,
        question: "Vad ska vi äta?",
        options: [{ id: "opt-a", text: "Tacos" }],
      },
    },
  });
  db.set("messages/poll-theirs/poll_votes/" + UID, {
    voterId: UID,
    optionIds: ["opt-a"],
  });
  db.set("messages/poll-theirs/poll_votes/" + OTHER, {
    voterId: OTHER,
    optionIds: ["opt-a"],
  });
  // A poll the erased user OPENED, in the same surviving conversation.
  db.set("messages/poll-mine", {
    conversationId: "group-1",
    senderId: UID,
    content: "Pizza på fredag?",
    metadata: {
      poll: {
        id: "p2",
        creatorId: UID,
        question: "Pizza på fredag?",
        options: [{ id: "opt-x", text: "Ja" }],
      },
    },
  });
  db.set("messages/poll-mine/poll_votes/" + OTHER, {
    voterId: OTHER,
    optionIds: ["opt-x"],
  });

  await deleteMessages(asDb(db), UID);

  check(
    "the erased user's vote is gone from a poll they did not open",
    !db.has(`messages/poll-theirs/poll_votes/${UID}`),
    `left: ${JSON.stringify(db.pathsUnder("messages/poll-theirs/poll_votes"))}`,
  );
  check(
    "another member's vote in the same poll is untouched",
    db.has(`messages/poll-theirs/poll_votes/${OTHER}`),
  );
  check(
    "another member's vote in the ERASED user's poll is untouched too",
    db.has(`messages/poll-mine/poll_votes/${OTHER}`),
  );

  const mine = (db.get("messages/poll-mine") ?? {}) as DocData;
  const poll = ((mine.metadata ?? {}) as DocData).poll as DocData | undefined;
  check(
    "the erased user's poll authorship is anonymised",
    poll?.creatorId === "deleted",
    `creatorId: ${JSON.stringify(poll?.creatorId)}`,
  );
  check(
    "…and the rest of the poll survives — the remaining members still use it",
    poll?.question === "Pizza på fredag?" &&
      Array.isArray(poll?.options) &&
      (poll?.options as unknown[]).length === 1,
    `poll: ${JSON.stringify(poll)}`,
  );

  const theirs = (db.get("messages/poll-theirs") ?? {}) as DocData;
  const theirPoll = ((theirs.metadata ?? {}) as DocData).poll as
    | DocData
    | undefined;
  check(
    "somebody else's poll keeps ITS creator — the scrub is keyed on the uid",
    theirPoll?.creatorId === OTHER,
    `creatorId: ${JSON.stringify(theirPoll?.creatorId)}`,
  );
}

/**
 * BUT-1801: the residual probe must SEE both poll residues.
 *
 * `deletePollVotes` deletes votes through `commitInChunks(strict:false)`, which
 * catches a whole failed chunk and lets the step return success anyway — only
 * the cap can falsify it. And the creator scrub, before BUT-1801, was one atomic
 * batch, so a single message deleted by a sibling step took the whole chunk with
 * it, silently. In both cases the step reports a clean erasure over rows that are
 * still there. The probe is the only thing that can contradict that, and it had claim-lint:ok moved unchanged, BUT-2113
 * no leg for either — the same shape as the `participants` gap BUT-1822 found.
 *
 * Two residues, asserted separately, because a probe that catches one and misses
 * the other still certifies a bad erasure clean.
 */
async function scenario_probeSeesLeftoverPollResidues(): Promise<void> {
  // eslint-disable-next-line @typescript-eslint/no-require-imports
  const { probeResidualData } = require("../account/account-deletion-cascade");

  const cleanCase = new FakeFirestore();
  // Somebody else's vote on somebody else's poll: neither leg may fire on it.
  cleanCase.set("messages/poll-theirs", {
    conversationId: "group-1",
    senderId: OTHER,
    metadata: { poll: { id: "p1", creatorId: OTHER, options: [] } },
  });
  cleanCase.set("messages/poll-theirs/poll_votes/" + OTHER, {
    voterId: OTHER,
    optionIds: ["opt-a"],
  });
  const cleanResult = {
    deletedCollections: [],
    failedCollections: [] as string[],
    errors: [],
    retained: [],
  };
  await probeResidualData(asDb(cleanCase), UID, cleanResult);
  check(
    "another member's poll vote and authorship do not read as this user's residual",
    !cleanResult.failedCollections.includes("residual_data_detected"),
    `failed: ${JSON.stringify(cleanResult.failedCollections)}`,
  );

  // Residue 1: a vote row the sweep failed to delete.
  const leftoverVote = new FakeFirestore();
  leftoverVote.set("messages/poll-theirs", {
    conversationId: "group-1",
    senderId: OTHER,
    metadata: { poll: { id: "p1", creatorId: OTHER, options: [] } },
  });
  leftoverVote.set("messages/poll-theirs/poll_votes/" + UID, {
    voterId: UID,
    optionIds: ["opt-a"],
  });
  const voteResult = {
    deletedCollections: [],
    failedCollections: [] as string[],
    errors: [],
    retained: [],
  };
  await probeResidualData(asDb(leftoverVote), UID, voteResult);
  check(
    "a poll vote the sweep failed to delete is reported as residual data",
    voteResult.failedCollections.includes("residual_data_detected"),
    `failed: ${JSON.stringify(voteResult.failedCollections)}`,
  );

  // Residue 2: authorship the scrub failed to anonymise. Distinct from residue
  // 1 — the message carries the raw uid in a FIELD, with no vote row at all.
  const leftoverAuthor = new FakeFirestore();
  leftoverAuthor.set("messages/poll-mine", {
    conversationId: "group-1",
    senderId: "deleted",
    metadata: { poll: { id: "p2", creatorId: UID, options: [] } },
  });
  const authorResult = {
    deletedCollections: [],
    failedCollections: [] as string[],
    errors: [],
    retained: [],
  };
  await probeResidualData(asDb(leftoverAuthor), UID, authorResult);
  check(
    "poll authorship the scrub failed to anonymise is reported as residual data",
    authorResult.failedCollections.includes("residual_data_detected"),
    `failed: ${JSON.stringify(authorResult.failedCollections)}`,
  );
}

/**
 * BUT-1801: the poll-creator scrub tolerates NOT_FOUND and ONLY NOT_FOUND.
 *
 * The scrub updates each authored message individually rather than in one batch,
 * because a sibling step (`deleteChatGroupMemberships` deleting an emptied
 * group's whole thread) can delete a message out from under it — and a batch is
 * atomic, so one NOT_FOUND would take the whole chunk down while
 * `commitInChunks(strict:false)` swallowed the error and the step still reported
 * success.
 *
 * So code 5 means "the message is already gone", which is the outcome the scrub
 * wanted: tolerate it, stay complete. Every OTHER code is a real failure and must
 * mark the step incomplete, or a half-erased account passes as `gdprCompliant`.
 *
 * Both directions are asserted here because the fake could not stage either one
 * until this ticket added the `updateFailures` seam: inverting the predicate —
 * tolerating everything except code 5, the exact opposite of the intent — left
 * the suite 110/110 green.
 */
async function scenario_pollCreatorScrubToleratesOnlyNotFound(): Promise<void> {
  // eslint-disable-next-line @typescript-eslint/no-require-imports
  const { deletePollVotes } = require("../account/account-deletion-cascade");

  const authoredPoll = (db: FakeFirestore, id: string): void => {
    db.set(`messages/${id}`, {
      conversationId: "group-1",
      senderId: UID,
      metadata: { poll: { id: `p-${id}`, creatorId: UID, options: [] } },
    });
  };

  // NOT_FOUND: the message was deleted by a sibling step mid-cascade.
  const vanished = new FakeFirestore();
  vanished.set("conversations/group-1", { participantIds: [UID, OTHER] });
  authoredPoll(vanished, "poll-gone");
  vanished.updateFailures.set("messages/poll-gone", 5);
  check(
    "a message deleted mid-cascade does NOT make the poll scrub incomplete",
    (await deletePollVotes(asDb(vanished), UID)) === true,
    "code 5 must be tolerated — the row is already gone",
  );

  // Any other code: a real write failure, and the step must own up to it.
  const broken = new FakeFirestore();
  broken.set("conversations/group-1", { participantIds: [UID, OTHER] });
  authoredPoll(broken, "poll-broken");
  broken.updateFailures.set("messages/poll-broken", 13); // INTERNAL
  check(
    "a real write failure DOES make the poll scrub report incomplete",
    (await deletePollVotes(asDb(broken), UID)) === false,
    "only NOT_FOUND may be tolerated",
  );
}

/**
 * BUT-1835 + BUT-1830: an implausibly large vote sweep DECLINES rather than
 * truncating, and says so.
 *
 * NOT because a peer can inflate the count — they cannot. `firestore.rules`
 * requires `request.auth.uid == voterId` on every write verb of
 * `poll_votes/{voterId}`, and posting a poll creates zero rows; a row exists
 * only when this user votes. That sentence stood here and in the constant's own
 * docstring until the BUT-1801 review disproved it (2026-08-17); it was borrowed
 * from the roster cap, where peer-seeding IS the threat.
 *
 * What the cap still guards: self-inflation, and a tampered or non-standard
 * Admin-SDK writer that rules never see. A truncated sweep would report a clean
 * erasure over rows it never looked at, which is the one outcome Art. 17 cannot
 * tolerate; declining lands the step in `failedCollections`, which is loud.
 */
async function scenario_implausiblePollVoteCountDeclines(): Promise<void> {
  const db = new FakeFirestore();
  db.set("conversations/group-2", {
    participantIds: [UID, OTHER],
    isGroup: true,
  });
  // 2000 is MAX_POLL_VOTE_SWEEP_ROWS; the read is `.limit(MAX + 1)`, so 2001
  // rows is the smallest sweep that refuses.
  for (let i = 0; i < 2001; i++) {
    db.set(`messages/poll-${i}/poll_votes/${UID}`, {
      voterId: UID,
      optionIds: ["opt-a"],
    });
  }

  const ok = await deleteMessages(asDb(db), UID);

  check(
    "an implausible poll-vote count is not swept",
    db.has(`messages/poll-0/poll_votes/${UID}`),
  );
  check(
    "…and the step reports INCOMPLETE, so the audit cannot say gdprCompliant",
    ok === false,
    `deleteMessages returned ${ok}`,
  );
}

/**
 * BUT-1801: poll AUTHORSHIP is capped too, and for a reason the vote sweep does
 * NOT share.
 *
 * A peer cannot seat a `poll_votes` row for someone else — the rules pin
 * `request.auth.uid == voterId` on every write verb — so that cap guards only
 * self-inflation. Authorship is the opposite: the `messages` create rule pins
 * required fields but carries no `hasOnly`, so `metadata` is unconstrained and
 * any participant can plant `metadata.poll.creatorId: <victimUid>` on a message
 * in their own DM. The row count is chosen by other people, which is exactly the
 * shape that lets somebody else size a victim's erasure bill.
 *
 * The scrub was briefly UNCAPPED, justified in a comment as "self-bounded — only
 * this user authors this user's polls". That claim was false. Declining beats truncating for the same reason as
 * every other cap here: a truncated scrub reports a clean erasure over rows it
 * never touched.
 *
 * What this pins is the DECLINE DECISION — mutation-proved: delete the
 * `authored.size > MAX` block and both checks below redden. It does NOT pin the
 * `.limit(MAX + 1)` on the query, and cannot: removing that limit leaves the
 * suite fully green, because the decision still sees 2001 rows and still
 * declines. The limit bounds the READ (cost), the check bounds the WRITE
 * (correctness), and only the second is observable from here. Do not read a
 * green suite as evidence the read stayed bounded.
 */
async function scenario_implausiblePollAuthorshipDeclines(): Promise<void> {
  // eslint-disable-next-line @typescript-eslint/no-require-imports
  const { deletePollVotes } = require("../account/account-deletion-cascade");

  const db = new FakeFirestore();
  db.set("conversations/group-3", { participantIds: [UID, OTHER] });
  // 2001 is the smallest count that trips a `.limit(MAX + 1)` read.
  for (let i = 0; i < 2001; i++) {
    db.set(`messages/planted-${i}`, {
      conversationId: "group-3",
      senderId: OTHER,
      metadata: { poll: { id: `p-${i}`, creatorId: UID, options: [] } },
    });
  }

  const ok = await deletePollVotes(asDb(db), UID);

  check(
    "an implausible poll-authorship count reports INCOMPLETE",
    ok === false,
    `deletePollVotes returned ${ok}`,
  );
  const planted = db.get("messages/planted-0") as
    | { metadata?: { poll?: { creatorId?: string } } }
    | undefined;
  check(
    "…and scrubs nothing rather than truncating",
    planted?.metadata?.poll?.creatorId === UID,
    `creatorId was ${planted?.metadata?.poll?.creatorId}`,
  );
}

/**
 * The collection-group index the sweep needs. Firestore's AUTOMATIC single-field
 * indexes are COLLECTION-scoped, so a `collectionGroup('poll_votes')` query
 * filtered on `voterId` fails with FAILED_PRECONDITION without an explicit
 * `COLLECTION_GROUP` fieldOverride — the erasure would go from working to
 * throwing on every account deletion. Pinned here because a `--force` index
 * deploy prunes anything absent from that file.
 */
async function scenario_pollVoteIndexIsDeclared(): Promise<void> {
  // eslint-disable-next-line @typescript-eslint/no-require-imports
  const fs = require("fs");
  // eslint-disable-next-line @typescript-eslint/no-require-imports
  const path = require("path");
  const indexes = JSON.parse(
    fs.readFileSync(
      path.join(__dirname, "..", "..", "..", "firestore.indexes.json"),
      "utf8",
    ),
  ) as {
    fieldOverrides?: {
      collectionGroup: string;
      fieldPath: string;
      indexes?: { order?: string; queryScope?: string }[];
    }[];
  };
  const override = (indexes.fieldOverrides ?? []).find(
    (o) => o.collectionGroup === "poll_votes" && o.fieldPath === "voterId",
  );
  check(
    "poll_votes.voterId has a COLLECTION_GROUP single-field index declared",
    (override?.indexes ?? []).some(
      (i) => i.queryScope === "COLLECTION_GROUP" && i.order === "ASCENDING",
    ),
    `override: ${JSON.stringify(override)}`,
  );
}

/**
 * BUT-2398: on chat messages the erased uid leaves every reaction list it is
 * in, every other reactor and the message itself stay, and the probe reads
 * zero afterwards.
 */
async function scenario_messageReactionsLoseOnlyTheErasedUid(): Promise<void> {
  const { scrubMessageReactions } = require("../account/account-deletion-cascade");
  const db = new FakeFirestore();
  db.set("messages/m1", {
    senderId: OTHER,
    content: "hej",
    reactions: { heart: [UID, THIRD], thinking: [UID], fire: [THIRD] },
  });
  db.set("messages/m2", { senderId: THIRD, reactions: { yum: [OTHER, UID] } });
  db.set("messages/m3", { senderId: OTHER, reactions: { heart: [THIRD] } });
  db.set("messages/m4", { senderId: OTHER });
  db.set("recipe_comments/c1", { authorId: OTHER, reactions: { heart: [UID] } });

  const ok = await scrubMessageReactions(asDb(db), UID);

  check("the message reaction scrub reports success", ok === true);
  check(
    "the erased uid leaves each message list and the other reactors stay",
    JSON.stringify(db.get("messages/m1")?.reactions) ===
      JSON.stringify({ heart: [THIRD], thinking: [], fire: [THIRD] }) &&
      JSON.stringify(db.get("messages/m2")?.reactions) ===
        JSON.stringify({ yum: [OTHER] }),
    JSON.stringify([db.get("messages/m1"), db.get("messages/m2")]),
  );
  check(
    "the message content and sender survive",
    db.get("messages/m1")?.content === "hej" &&
      db.get("messages/m1")?.senderId === OTHER,
  );
  check(
    "messages without the erased uid, and comments, are not written to",
    !db.updatedPaths.includes("messages/m3") &&
      !db.updatedPaths.includes("messages/m4") &&
      !db.updatedPaths.includes("recipe_comments/c1"),
    JSON.stringify(db.updatedPaths),
  );

  db.set("recipe_comments/c1", { authorId: OTHER });
  const residual = emptyResult();
  await probeAfter(db, residual);
  check(
    "after the message scrub the probe reads zero",
    !sawResidual(residual),
    `failed: ${JSON.stringify(residual.failedCollections)}`,
  );
}

/**
 * BUT-2398: over the cap on one key that key declines and writes nothing, the
 * other keys are still swept, and the step fails; a rejected write fails it too.
 */
async function scenario_implausibleMessageReactionSweepDeclines(): Promise<void> {
  const {
    scrubMessageReactions,
    MAX_MESSAGE_REACTION_SWEEP_ROWS,
  } = require("../account/account-deletion-cascade");

  const over = new FakeFirestore();
  for (let i = 0; i <= MAX_MESSAGE_REACTION_SWEEP_ROWS; i++) {
    over.set(`messages/h-${i}`, { senderId: `p-${i}`, reactions: { heart: [UID] } });
  }
  over.set("messages/f", { senderId: OTHER, reactions: { fire: [UID, THIRD] } });
  check(
    "the message reaction scrub fails the step when one key is over its cap",
    (await scrubMessageReactions(asDb(over), UID)) === false,
  );
  check(
    "the over-cap message key is not written to",
    !over.updatedPaths.some((p) => p.startsWith("messages/h-")),
  );
  check(
    "the other message keys are still swept",
    JSON.stringify(over.get("messages/f")?.reactions) ===
      JSON.stringify({ fire: [THIRD] }),
    JSON.stringify(over.get("messages/f")),
  );

  const atCap = new FakeFirestore();
  for (let i = 0; i < MAX_MESSAGE_REACTION_SWEEP_ROWS; i++) {
    atCap.set(`messages/h-${i}`, { senderId: `p-${i}`, reactions: { heart: [UID] } });
  }
  check(
    "the message reaction scrub runs at exactly its cap",
    (await scrubMessageReactions(asDb(atCap), UID)) === true &&
      atCap.updatedPaths.length === MAX_MESSAGE_REACTION_SWEEP_ROWS,
  );

  const fails = new FakeFirestore();
  fails.set("messages/x", { senderId: OTHER, reactions: { yum: [UID] } });
  fails.set("messages/y", { senderId: OTHER, reactions: { heart: [UID] } });
  fails.batchFailures.set("messages/x", 13);
  check(
    "a rejected message-scrub chunk fails the step and the other keys still run",
    (await scrubMessageReactions(asDb(fails), UID)) === false &&
      JSON.stringify(fails.get("messages/y")?.reactions) ===
        JSON.stringify({ heart: [] }),
    JSON.stringify(fails.get("messages/y")),
  );
}

/**
 * BUT-2398: each reaction key's message probe leg fires on its own residue,
 * and another person's reaction does not fire it.
 */
async function scenario_probeSeesLeftoverMessageReactions(): Promise<void> {
  const { COMMENT_REACTION_KEYS } = require("../account/account-deletion-cascade");
  const quiet: string[] = [];
  for (const key of COMMENT_REACTION_KEYS as readonly string[]) {
    const db = new FakeFirestore();
    db.set("messages/x", { senderId: OTHER, reactions: { [key]: [THIRD, UID] } });
    const r = emptyResult();
    await probeAfter(db, r);
    if (!sawResidual(r)) quiet.push(key);
  }
  check(
    "a surviving message reaction on every key is residual",
    quiet.length === 0,
    `keys the probe missed: ${quiet.join(", ")}`,
  );

  const clean = new FakeFirestore();
  clean.set("messages/x", { senderId: OTHER, reactions: { heart: [THIRD] } });
  const r = emptyResult();
  await probeAfter(clean, r);
  check("another person's message reaction does not fire the probe", !sawResidual(r));
}

async function main(): Promise<void> {
  await scenario_pollVotesAndAuthorshipAreErased();
  await scenario_probeSeesLeftoverPollResidues();
  await scenario_pollCreatorScrubToleratesOnlyNotFound();
  await scenario_implausiblePollVoteCountDeclines();
  await scenario_implausiblePollAuthorshipDeclines();
  await scenario_pollVoteIndexIsDeclared();
  await scenario_messageReactionsLoseOnlyTheErasedUid();
  await scenario_implausibleMessageReactionSweepDeclines();
  await scenario_probeSeesLeftoverMessageReactions();

  finishSuite("BUT-1766/BUT-1768 deletion cascade polls and message reactions");
}

main().catch((err) => {
  console.error("Test runner crashed:", err);
  process.exit(1);
});
