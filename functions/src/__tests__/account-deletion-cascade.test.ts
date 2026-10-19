/**
 * BUT-1766 / BUT-1768: per-step semantics of the account-deletion cascade for
 * the two collections it silently skipped.
 *
 * `request-account-deletion.test.ts` covers ORCHESTRATION only — its fake makes
 * every query return an empty snapshot, so every step "succeeds" whatever it
 * queries. That is exactly the blind spot both defects lived in: `deleteMessages`
 * swept `conversations/{id}/messages`, a subcollection with no rule block and no
 * writer, and `realtime_menus` had no step at all. Neither showed up as a
 * failure anywhere — the cascade reported `messages` deleted and the audit row
 * said `gdprCompliant: true`.
 *
 * Tested against an in-memory Firestore stub, the same shape as
 * `but753-legacy-sharedwith-cascade.test.ts`.
 *
 * Run with: npx ts-node src/__tests__/account-deletion-cascade.test.ts
 */

import { Collections } from "../shared/collections";
import { assertGuardTriggersCoverItsDartInputs } from "./_dart-guard-triggers";
import {
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
 * Membership is the WRONG handle on its own (the BUT-1725 lesson): leave a group
 * and the conversation query stops finding you, while every message you wrote
 * keeps your name on a thread the others still read.
 */
async function scenario_messagesInLeftConversationsAreReached(): Promise<void> {
  const db = new FakeFirestore();
  db.set("conversations/c-left", { participantIds: [OTHER, THIRD] });
  seedMessage(db, "orphan", "c-left", UID);

  await deleteMessages(asDb(db), UID);

  const orphan = db.get("messages/orphan");
  check(
    "a message in a conversation the user LEFT is still anonymized",
    orphan?.senderId === "deleted" &&
      orphan?.senderDisplayName === "[Raderad användare]",
    `got ${JSON.stringify(orphan)}`,
  );
}

/**
 * The collection-group query the two legs above depend on needs a declared
 * index; Firestore's automatic single-field indexes cover COLLECTION scope only.
 * Nothing in a stub-backed suite can notice a missing or misspelled one — the
 * query would throw FAILED_PRECONDITION in production, land in the probe's own
 * catch, and be logged as a residual that isn't there.
 *
 * The COLLECTION entry is not optional either: a `fieldOverride` REPLACES the
 * automatic indexing for that field.
 */
async function scenario_rosterIndexIsDeclared(): Promise<void> {
  // eslint-disable-next-line @typescript-eslint/no-require-imports
  const fs = require("fs");
  // eslint-disable-next-line @typescript-eslint/no-require-imports
  const path = require("path");
  const config = JSON.parse(
    fs.readFileSync(
      path.join(__dirname, "..", "..", "..", "firestore.indexes.json"),
      "utf8",
    ),
  ) as {
    fieldOverrides?: {
      collectionGroup: string;
      fieldPath: string;
      indexes: { order?: string; queryScope: string }[];
    }[];
  };
  const entry = (config.fieldOverrides ?? []).find(
    (o) => o.collectionGroup === "participants" && o.fieldPath === "participantId",
  );
  check(
    "firestore.indexes.json declares the participants/participantId override",
    entry !== undefined,
  );
  const scopes = (entry?.indexes ?? [])
    .filter((i) => i.order === "ASCENDING")
    .map((i) => i.queryScope);
  check(
    "…for COLLECTION_GROUP scope, which the cascade's sweep and probe query",
    scopes.includes("COLLECTION_GROUP"),
    `scopes: ${JSON.stringify(scopes)}`,
  );
  check(
    "…and for COLLECTION scope, which the override would otherwise remove",
    scopes.includes("COLLECTION"),
    `scopes: ${JSON.stringify(scopes)}`,
  );
}

/**
 * BUT-2028: every Firestore collection this repo knows about is DECIDED —
 * deleted, kept, or deliberately untouched with a reason.
 *
 * `admin/reset-user-data.ts` promises a clean slate. Before this guard, a
 * collection was covered only if someone remembered to add it: top-level
 * collections appeared in neither list, several of them uid-keyed personal data
 * that Phase 1 orphans by deleting every Auth user first. Nothing reddened,
 * and the run printed CLEANUP COMPLETE regardless.
 *
 * **Two independent sources, because neither sees the whole picture.**
 * `firestore.rules` names every collection a CLIENT can touch but is blind to
 * server-only ones; the Cloud Functions source names every collection the
 * SERVER touches but is blind to the ones only the app writes. `system` — the
 * collection holding the app's kill switches — is invisible to the rules file
 * (it has no block, since only the Admin SDK reads it) and is reached through
 * `.doc("system/config")` rather than `.collection(...)`, which is why the
 * server scan reads document-path literals too. That was this ticket's own bug
 * hiding inside its own fix: a guard written without it would have been blind
 * to precisely the collection the kill switch lives in.
 */
async function scenario_everyCollectionIsDecided(): Promise<void> {
  // eslint-disable-next-line @typescript-eslint/no-require-imports
  const fs = require("fs");
  // eslint-disable-next-line @typescript-eslint/no-require-imports
  const path = require("path");
  // eslint-disable-next-line @typescript-eslint/no-require-imports
  const lists = require("../admin/reset-collection-lists");

  const repoRoot = path.join(__dirname, "..", "..", "..");
  const functionsSrc = path.join(__dirname, "..");

  // --- Source A: firestore.rules -----------------------------------------
  //
  // Comments are stripped BEFORE parsing. The rules file's comments contain
  // brace-carrying prose and map literals, and the brace counter below would
  // read those as real nesting.
  const rulesSource: string = fs.readFileSync(
    path.join(repoRoot, "firestore.rules"),
    "utf8",
  );
  const rulesLines: string[] = rulesSource
    .split("\n")
    .map((line: string) => line.replace(/\/\/.*$/, ""));

  // Two readings of the same thing, kept separate so they can disagree.
  // `byDepth` tracks brace nesting: a top-level collection is a `match` at
  // depth 2, inside `service … {` and `match /databases/{db}/documents {`.
  // `byIndent` only looks at four-space indentation. Neither is trustworthy
  // alone — a stray brace breaks the first, a reformat breaks the second — so
  // the guard asserts they agree and then uses the depth reading.
  const byDepth: string[] = [];
  const byIndent: string[] = [];
  let depth = 0;
  for (const line of rulesLines) {
    const m = line.match(/^(\s*)match\s+\/(\S+)\s*\{/);
    if (m) {
      if (depth === 2) byDepth.push(m[2]);
      if (m[1].length === 4) byIndent.push(m[2]);
    }
    for (const ch of line) {
      if (ch === "{") depth++;
      else if (ch === "}") depth--;
    }
  }

  check(
    "the two readings of firestore.rules agree on which matches are top-level",
    byDepth.length === byIndent.length &&
      byDepth.every((p, i) => p === byIndent[i]),
    `brace-depth found ${byDepth.length} top-level matches, indentation found ` +
      `${byIndent.length} — one of the two readings is wrong, so neither can ` +
      "be trusted to say what the rules file covers",
  );

  /** First path segment of a match, or null for a wildcard-rooted one. */
  function firstSegment(matchPath: string): string | null {
    const first = matchPath.split("/")[0];
    // `match /{path=**}/members/{id}` is a COLLECTION-GROUP rule and
    // `match /{document=**}` is the terminal catch-all. Neither names a
    // top-level collection, and taking their first segment would invent one.
    return first.startsWith("{") ? null : first;
  }

  const fromRules = new Set<string>();
  for (const p of byDepth) {
    const seg = firstSegment(p);
    if (seg) fromRules.add(seg);
  }

  // Positive anchors. A count would go stale on the next rules block; these
  // say what the parse must be CAPABLE of, which does not.
  check(
    "the rules parse reached collections at the top and the bottom of the file",
    // `users` opens the documents block; `parse_events` is the last named
    // match before the terminal catch-all. A parse that stops early keeps the
    // first and loses the second.
    fromRules.has("users") && fromRules.has("parse_events"),
    `parsed ${fromRules.size} top-level collections from firestore.rules ` +
      `(users: ${fromRules.has("users")}, parse_events: ` +
      `${fromRules.has("parse_events")})`,
  );
  check(
    "the rules parse rejects collection-group wildcards",
    // `members` has a `match /{path=**}/members/{memberId}` block and no
    // top-level one. If it appears here, `firstSegment` stopped rejecting
    // wildcard-rooted paths and the guard is inventing top-level collections
    // out of subcollection rules.
    !fromRules.has("members"),
    "`members` was read as a top-level collection — it is only ever a " +
      "subcollection, reached through a {path=**} collection-group rule",
  );

  // --- Source B: the Cloud Functions source ------------------------------
  const serverFiles: string[] = [];
  (function walk(dir: string) {
    for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
      if (entry.isDirectory()) {
        // Tests are excluded deliberately: their fixtures name collections
        // that exist only to be denied, and a fixture is not evidence that
        // production touches anything.
        if (entry.name === "__tests__") continue;
        walk(path.join(dir, entry.name));
      } else if (entry.name.endsWith(".ts")) {
        serverFiles.push(path.join(dir, entry.name));
      }
    }
  })(functionsSrc);

  // Resolves `Collections.x` to the string it stands for.
  const constants: Record<string, string> = {};
  {
    const source: string = fs.readFileSync(
      path.join(functionsSrc, "shared", "collections.ts"),
      "utf8",
    );
    for (const m of source.matchAll(/^\s+([A-Za-z0-9_]+):\s*"([^"]+)"/gm)) {
      constants[m[1]] = m[2];
    }
  }

  function stripTsComments(source: string): string {
    return source
      .replace(/\/\*[\s\S]*?\*\//g, "")
      .split("\n")
      .map((line: string) => line.replace(/\/\/.*$/, ""))
      .join("\n");
  }

  // One set per extraction branch, unioned at the end. Kept separate so each
  // branch gets an anchor that dies alone: a name discoverable by two routes
  // proves nothing about either.
  const fromCollectionLiteral = new Set<string>();
  const fromConstant = new Set<string>();
  const fromCollectionGroup = new Set<string>();
  const fromDocPath = new Set<string>();

  // A collection name is an identifier. This rejects the template fragments
  // and path shapes that string literals in this codebase also carry.
  const looksLikeCollection = /^[A-Za-z_][A-Za-z0-9_]*$/;
  function record(into: Set<string>, name: string | undefined): void {
    if (name && looksLikeCollection.test(name)) into.add(name);
  }

  for (const file of serverFiles) {
    const source: string = stripTsComments(fs.readFileSync(file, "utf8"));

    // A `const NAME = "collection"` declared in this file, exported or not.
    // Without it, a collection reached through such a constant is invisible
    // unless it also happens to have a rules block — `llm_response_samples`
    // (private) and `canonical_recipe_stats` (exported) are both that shape.
    // The `export` half is not decoration: the first version of this branch
    // omitted it and left the exported case relying on the same accident the
    // branch exists to stop relying on. An identifier IMPORTED from another
    // file stays unresolved, because this map is per-file.
    const localConstants: Record<string, string> = {};
    for (const m of source.matchAll(
      /^\s*(?:export\s+)?const\s+([A-Za-z_][A-Za-z0-9_]*)\s*(?::\s*string\s*)?=\s*"([^"]+)"\s*;/gm,
    )) {
      localConstants[m[1]] = m[2];
    }

    // `.collection(X)` — but only where X is the FIRST link of its chain.
    // `db.collection("users").doc(uid).collection("consent")` must yield
    // `users` alone; `consent` is a subcollection, and reporting it as
    // top-level would demand a list entry for something that does not exist
    // there. The collapse looks back to the nearest statement boundary and
    // skips the match if a `.doc(` stands between.
    //
    // The look-back is a heuristic in one direction only: two handles built
    // inside one expression, where an unrelated `.doc(` precedes a genuine
    // top-level `.collection(...)`, are skipped. That direction hides a
    // collection from the guard rather than inventing one.
    for (const m of source.matchAll(
      /\.collection\(\s*(?:"([^"]+)"|Collections\.([A-Za-z0-9_]+)|([A-Za-z_][A-Za-z0-9_]*))\s*\)/g,
    )) {
      const before = source.slice(Math.max(0, m.index - 400), m.index);
      const boundary = Math.max(
        before.lastIndexOf(";"),
        before.lastIndexOf("{"),
        before.lastIndexOf("}"),
      );
      if (before.slice(boundary + 1).includes(".doc(")) continue;
      if (m[1] !== undefined) record(fromCollectionLiteral, m[1]);
      else if (m[2] !== undefined) record(fromCollectionLiteral, constants[m[2]]);
      // An identifier that resolves to no local const is a runtime value
      // (a parameter, a config field) and is skipped rather than guessed.
      else record(fromConstant, localConstants[m[3]]);
    }

    for (const m of source.matchAll(
      /collectionGroup\(\s*(?:"([^"]+)"|Collections\.([A-Za-z0-9_]+))\s*\)/g,
    )) {
      record(fromCollectionGroup, m[1] ?? constants[m[2]]);
    }

    // Document-path literals: `.doc("system/config")`. Without this the guard
    // is blind to `system`, which is where BUT-2028's own kill switch lives —
    // it has no rules block and is never reached through `.collection(...)`.
    // The backtick form is read too, up to its first interpolation:
    // `` .doc(`pings/${groupId}/pings/${pingId}`) `` names `pings`.
    for (const m of source.matchAll(/\.doc\(\s*"([^"\s]+\/[^"\s]+)"\s*\)/g)) {
      record(fromDocPath, m[1].split("/")[0]);
    }
    for (const m of source.matchAll(
      /\.doc\(\s*`([A-Za-z_][A-Za-z0-9_]*)\//g,
    )) {
      record(fromDocPath, m[1]);
    }
  }

  const fromServer = new Set<string>([
    ...fromCollectionLiteral,
    ...fromConstant,
    ...fromCollectionGroup,
    ...fromDocPath,
  ]);

  check(
    "the server scan resolves collection constants declared in the file",
    // `llm/llm-sample-capture.ts` writes through `const COLLECTION = "…"`.
    // Only this branch can find it; without it the collection is visible to
    // the guard purely by accident of having a rules block.
    // `canonical_recipe_stats` is the EXPORTED case claim-lint:ok moved unchanged, BUT-2113
    // (`ratings/update-pooled-rating-stats.ts`), and it is the only thing that claim-lint:ok moved unchanged, BUT-2113
    // can fail if the `export` half of the pattern is dropped.
    fromConstant.has("llm_response_samples") &&
      fromConstant.has("canonical_recipe_stats"),
    // Both memberships are reported: the check is a conjunction, and a
    // failure message naming only one half points a reader at the wrong half.
    `the const branch found ${fromConstant.size} collections ` +
      `(llm_response_samples: ${fromConstant.has("llm_response_samples")}, ` +
      `canonical_recipe_stats: ${fromConstant.has("canonical_recipe_stats")})` +
      " — a collection named through a constant in its own file is invisible " +
      "to the guard again",
  );
  check(
    "the server scan reads backtick document paths",
    // `triggers/ping_onCreate.ts` builds `pings/${groupId}/pings/${pingId}`.
    fromDocPath.has("pings"),
    `the document-path branch found ${[...fromDocPath].join(", ")} — the ` +
      "backtick form stopped being read",
  );
  check(
    "the server scan sees collections firestore.rules cannot show",
    // Both are server-only and have no rules block at all, so source A is
    // blind to them by construction. `system` additionally proves the
    // document-literal branch runs.
    fromServer.has("system") && fromServer.has("system_ip_audit_caps"),
    `scanned ${serverFiles.length} server files and found ` +
      `${fromServer.size} collections (system: ${fromServer.has("system")}, ` +
      `system_ip_audit_caps: ${fromServer.has("system_ip_audit_caps")})`,
  );
  check(
    "the chain collapse keeps subcollections out of the server scan",
    // `consent` and `settings` are written by this repo's server code ONLY as
    // `db.collection("users").doc(uid).collection(...)` chains. If either
    // shows up here the collapse stopped working, and the guard would start
    // demanding a top-level list entry for a subcollection.
    !fromServer.has("consent") && !fromServer.has("settings"),
    "a users/{uid} subcollection was read as a top-level collection — the " +
      "`.doc(` look-back stopped collapsing chains",
  );

  // --- The union, and the three lists ------------------------------------
  const known = new Set<string>([...fromRules, ...fromServer]);
  const subNames: Set<string> = lists.KNOWN_SUBCOLLECTION_NAMES;

  const staleSubNames = [...subNames].filter((name) => !known.has(name));
  check(
    "every filtered subcollection name is still written somewhere",
    staleSubNames.length === 0,
    `${staleSubNames.join(", ")} is filtered out as a subcollection but no ` +
      "source names it any more — the filter is hiding nothing, and it would " +
      "hide a real top-level collection that later takes the name",
  );

  const discovered = [...known].filter((name) => !subNames.has(name)).sort();

  const toDelete = new Set(
    (lists.COLLECTIONS_TO_DELETE as { name: string }[]).map((t) => t.name),
  );
  const toKeep = new Set(lists.COLLECTIONS_TO_KEEP as string[]);
  const untouched: Record<string, string> =
    lists.COLLECTIONS_DELIBERATELY_UNTOUCHED;
  const untouchedNames = new Set(Object.keys(untouched));

  const undecided = discovered.filter(
    (name) =>
      !toDelete.has(name) && !toKeep.has(name) && !untouchedNames.has(name),
  );
  check(
    "every collection this repo knows about is decided",
    undecided.length === 0,
    `${undecided.length} collection(s) appear in firestore.rules or in ` +
      `functions/src but in none of the three lists: ${undecided.join(", ")}` +
      " — reset-user-data.ts neither deletes nor protects them, and Phase 1 " +
      "deletes every Auth user first, so anything uid-keyed is left orphaned " +
      "and unreachable by the account cascade",
  );

  const reasonless = Object.entries(untouched).filter(
    ([, reason]) => reason.trim().length < 20,
  );
  check(
    "every deliberately-untouched collection states a reason",
    reasonless.length === 0,
    `${reasonless.map(([name]) => name).join(", ")} has no real reason — the ` +
      "register exists so a skip is a decision someone wrote down, and a " +
      "one-word string reads as decided while recording nothing",
  );

  // BUT-2044: an entry naming a DATABASE-ONLY orphan is exempt. Source is not
  // the universe — that is the premise BUT-2043's report was built to work
  // around — so for those the "names nothing that exists" reading is inverted:
  // they exist, with rows, and are invisible to source because the code stopped
  // naming them. Every other entry is still held to it.
  const dbOnly: Set<string> = lists.DATABASE_ONLY_ORPHANS;
  const staleUntouched = [...untouchedNames].filter(
    (name) => !discovered.includes(name) && !dbOnly.has(name),
  );
  check(
    "no deliberately-untouched entry names a collection that is gone",
    staleUntouched.length === 0,
    `${staleUntouched.join(", ")} is registered as deliberately untouched but ` +
      "no source names it — the reason it carries describes something that no " +
      "longer exists, and a reader would trust it",
  );

  // Disjointness over all THREE pairs. The delete/keep pair had its own guard
  // (BUT-2010, the overlap that made the script inert for five months); a
  // third list makes two more pairs, and the script's own runtime guard covers
  // only the original one.
  const pairs: [string, Set<string>, string, Set<string>][] = [
    ["delete", toDelete, "keep", toKeep],
    ["delete", toDelete, "untouched", untouchedNames],
    ["keep", toKeep, "untouched", untouchedNames],
  ];
  for (const [leftName, left, rightName, right] of pairs) {
    const overlap = [...left].filter((name) => right.has(name));
    check(
      `the ${leftName} and ${rightName} lists are disjoint`,
      overlap.length === 0,
      `${overlap.join(", ")} is in both — a collection with two verdicts has ` +
        "no verdict, and which one wins depends on which list a reader opens",
    );
  }
}

/**
 * BUT-2018: the block mirror's export exemption and the absent `incoming_blocks`
 * section are two halves of one decision, and this is what stops them drifting.
 *
 * Malin decided on 2026-09-05 that an Art. 15 bundle must not tell a requester
 * who blocked them. `EXPORT_EXEMPT.block_mirror` withholds the server's
 * projection of that fact; `SocialExportManager.exportBlocks` withholds the
 * `blocks` rows it derives from. Either one shipping without the other hands
 * over the same disclosure through the other door.
 *
 * Bound by a test rather than by prose because prose is exactly what would stay
 * behind, still reading as a decided call, on the day the section returns.
 */
async function scenario_blockMirrorExemptionRestsOnTheSameDecision(): Promise<void> {
  // eslint-disable-next-line @typescript-eslint/no-require-imports
  const fs = require("fs");
  // eslint-disable-next-line @typescript-eslint/no-require-imports
  const path = require("path");
  const repoRoot = path.join(__dirname, "..", "..", "..");

  const exempt = (
    require("../account/account-deletion-cascade") as {
      EXPORT_EXEMPT: Record<string, string>;
    }
  ).EXPORT_EXEMPT;

  check(
    "the block mirror is exempt from the export",
    typeof exempt[Collections.blockMirror] === "string",
    `EXPORT_EXEMPT keys: ${JSON.stringify(Object.keys(exempt))}`,
  );

  check(
    "…and its reason is the decision, not redundancy with a live section",
    (exempt[Collections.blockMirror] ?? "").includes("BUT-2018"),
    "`EXPORT_EXEMPT.block_mirror` must argue the withholding on Malin's " +
      "2026-09-05 decision. A reason resting on `incoming_blocks` being " +
      "exported describes a bundle that no longer exists.",
  );

  const managerPath = path.join(
    repoRoot,
    "lib",
    "services",
    "account",
    "export",
    "social_export_manager.dart",
  );
  const manager = fs.readFileSync(managerPath, "utf8") as string;

  check(
    "…and the section the same decision removed has not come back",
    // Dart has no backtick literal, so a backticked mention in a doc comment
    // is deliberately NOT a match — that file's own comment names the token.
    !/['"]incoming_blocks['"]/.test(manager),
    "`social_export_manager.dart` names an `incoming_blocks` key again. That " +
      "is the half of BUT-2018 the exemption above assumes is gone, so the " +
      "bundle now discloses who blocked the requester while the exemption " +
      "claims the decision covers it. Revisit both, or neither. This reads " +
      "the source as text, so it sees the quoted key and not the behaviour: " +
      "a return under some other key name is caught by nothing here and by " +
      "nothing on the Dart side.",
  );

  // The guard is only as live as its CI trigger: it reads a Dart file, so the
  // workflow must re-run it when that file changes.
  assertGuardTriggersCoverItsDartInputs(repoRoot, [managerPath], check);
}

/**
 * BUT-1957 drift guard: no `users/{uid}` subcollection any writer in this repo
 * creates may be left unreached by the cascade.
 *
 * A one-time audit goes stale on the next feature — `notifications` and
 * `onboarding` are both cases of exactly that. So the universe here is DERIVED
 * from the sources on every run, not typed out: every
 * `.collection("users").doc(...).collection("<name>")` chain under
 * `functions/src` and `lib`. A new subcollection writer therefore enters this
 * fixture by itself and reddens this scenario until something erases it.
 *
 * Each name must land in exactly one of three buckets, and two of them are read
 * OUT OF THE PRODUCTION SOURCE rather than restated here (a restated copy is
 * what drifts):
 *  1. `USER_SUBCOLLECTIONS`, exported at module scope by the cascade;
 *  2. `TRIGGER_OWNED_SUBCOLLECTIONS`, exported beside it — owned by
 *     `onUserDeleted`, which runs after this cascade;
 *  3. `COVERED_BY_OWN_STEP` below, for the ones with a dedicated tier step.
 *
 * Bucket 3 cannot be filled in with a lie: each entry is EXERCISED — a row is
 * seeded under that subcollection, the named deleter is run, and the row must be
 * gone. A map entry naming a function that does not touch the collection fails
 * here.
 *
 * **What this does NOT cover, stated rather than implied.** The scan reads the
 * `collection(users).doc(...).collection(X)` chain and resolves `X` when it is a
 * literal, a `FirestoreCollections`/`Collections` member, or a file-local
 * `const`. Anything else — a path assembled in a helper, a name passed in as a
 * parameter, a getter — is invisible, and a subcollection written only that way
 * will NOT appear here.
 *
 * That gap is not hypothetical and this test has already been widened twice by
 * it: resolving the shared constants is what surfaced `ingredients`,
 * `rate_limits` and `counters`, and resolving file-local consts is what
 * surfaced `acquisition` — each of them a live writer with no deleter, and each
 * found by a reviewer rather than by this test.
 *
 * Do not write a COUNT of how many names come from `lib/` versus
 * `functions/src` here. Two such counts were written during this change and
 * both were wrong, one of them refuted by the very commit that added it.
 */
/**
 * Every `users/{uid}/<name>` subcollection named by a `.collection(users)
 * .doc(x).collection(name)` chain anywhere in `lib/` or `functions/src`, mapped
 * to the first file naming it.
 *
 * A chain is not proof of a WRITE — a read builds the same path — so a caller
 * asking "does anything write this?" is really asking "does anything touch it",
 * which is the conservative direction for both guards that use it.
 *
 * Shared by BOTH drift guards — the deletion half (DELETION ⊇ WRITERS) and the
 * export half (BUT-1992). One parser, because two scanners that must agree is
 * the shape this file exists to stop.
 */
function discoverUserSubcollectionWriters(
  repoRoot: string,
): Map<string, string> {
  // eslint-disable-next-line @typescript-eslint/no-require-imports
  const fs = require("fs");
  // eslint-disable-next-line @typescript-eslint/no-require-imports
  const path = require("path");

  // The second `collection(...)` may be a literal OR a constant reference.
  // Matching only literals is what made the first `subs` audit miss two live
  // Dart writers (BUT-1957): every Dart repository builds the path from a
  // `FirestoreCollections` constant, so a literal-only scan saw the server and
  // essentially none of the client. Resolve the constants first.
  const collectionConstants = new Map<string, string>();
  for (const constFile of [
    path.join(repoRoot, "lib", "core", "constants", "firestore_collections.dart"),
    path.join(repoRoot, "functions", "src", "shared", "collections.ts"),
  ]) {
    if (!fs.existsSync(constFile)) continue;
    const src = fs.readFileSync(constFile, "utf8") as string;
    for (const m of src.matchAll(
      /(?:static\s+const\s+String\s+|^\s*)([A-Za-z_]\w*)\s*[:=]\s*['"]([A-Za-z_]+)['"]/gm,
    )) {
      collectionConstants.set(m[1], m[2]);
    }
  }

  // `\w*` and not `[A-Za-z_]\w*` before `[Uu]sers`. BUT-1992 measured the
  // difference: the stricter form REQUIRES a character in front of "users", so
  // it matched `FirestoreCollections.usersCollection` and never the bare
  // `FirestoreCollections.users` that every Dart repository actually writes.
  // This scan saw 15 subcollections where there are 23 — blind to
  // category_preferences, conversation_memberships, counters, friend_categories,
  // ingredients, list_category_orders, rate_limits and report_throttle. All
  // eight were already in `subs`, so nothing was unerasable; what was wrong is
  // that this check has been ranging over two thirds of its subject while
  // reading as exhaustive, and the next Dart writer of a NEW subcollection
  // would have been invisible to it.
  const chain =
    /collection\(\s*(?:['"]users['"]|(?:[A-Za-z_]\w*\.)?\w*[Uu]sers\w*)\s*\)\s*\.\s*doc\(\s*[^)]*\)\s*\.\s*collection\(\s*([^)\s]+)\s*\)/gs;
  const discovered = new Map<string, string>();
  // Comments in this repo spell example chains out in prose — this very test
  // reddened on a `.collection("users").doc(x).collection("y")` written inside
  // a comment in the cascade. Same trap BUT-1941 records for the golden lint:
  // strip comments before matching, or the scanner reads documentation as code.
  const stripComments = (t: string): string =>
    t.replace(/\/\*[\s\S]*?\*\//g, "").replace(/\/\/[^\n]*/g, "");
  const walk = (dir: string, exts: string[]): void => {
    for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
      const full = path.join(dir, entry.name);
      if (entry.isDirectory()) {
        if (entry.name === "__tests__" || entry.name === "node_modules") continue;
        walk(full, exts);
        continue;
      }
      if (!exts.some((e: string) => entry.name.endsWith(e))) continue;
      const text = stripComments(fs.readFileSync(full, "utf8") as string);
      // File-LOCAL consts too. `firebase_acquisition_repository.dart` writes
      // `users/{uid}/acquisition` through a private `static const` and was
      // invisible to a scan that resolved only the shared constants file —
      // which is how `acquisition` reached production unerasable.
      const localConsts = new Map<string, string>();
      for (const c of text.matchAll(
        /(?:static\s+)?const\s+(?:String\s+)?([A-Za-z_]\w*)\s*=\s*['"]([A-Za-z_]+)['"]/g,
      )) {
        localConsts.set(c[1], c[2]);
      }
      for (const m of text.matchAll(chain)) {
        const raw = m[1].trim();
        const literal = /^['"]([A-Za-z_]+)['"]$/.exec(raw);
        const viaConst = /^(?:FirestoreCollections|Collections)\.(\w+)$/.exec(raw);
        const viaLocal = /^([A-Za-z_]\w*)$/.exec(raw);
        const name = literal
          ? literal[1]
          : viaConst
            ? collectionConstants.get(viaConst[1])
            : viaLocal
              ? localConsts.get(viaLocal[1])
              : undefined;
        // An unresolvable expression (a parameter, a getter) is skipped rather
        // than guessed — it would be a name no bucket can contain, and this
        // test must fail on real drift, not on its own parser.
        if (name && !discovered.has(name)) discovered.set(name, full);
      }
    }
  };
  walk(path.join(repoRoot, "functions", "src"), [".ts"]);
  walk(path.join(repoRoot, "lib"), [".dart"]);
  return discovered;
}

async function scenario_everyUserSubcollectionHasADeleter(): Promise<void> {
  // eslint-disable-next-line @typescript-eslint/no-require-imports
  const path = require("path");
  const cascade = require("../account/account-deletion-cascade");

  const repoRoot = path.join(__dirname, "..", "..", "..");
  // BUT-2043: the real values, imported. This used to bracket-match the array
  // literals out of the cascade SOURCE and pull quoted names with
  // `/"([A-Za-z_]+)"/` after stripping `//` comments — so a name carrying a
  // digit was invisible to this guard, and a
  // quoted name inside a `/* */` comment was read as a list entry. The checks
  // that lived here proved the PARSER still worked; with no parser they
  // assert nothing, so they went with it. A broken import throws on the first
  // property access rather than passing vacuously.
  const subs: string[] = cascade.USER_SUBCOLLECTIONS;
  const triggerOwned: string[] = [...cascade.TRIGGER_OWNED_SUBCOLLECTIONS];

  /** name -> [exported deleter, doc id to seed]. */
  const COVERED_BY_OWN_STEP: Record<string, [string, string]> = {
    recipes: ["deleteRecipes", "r1"],
    menus: ["deleteMenus", "m1"],
    pantry: ["deletePantryItems", "p1"],
    personal_tags: ["deletePersonalTags", "t1"],
    personal_tag_groups: ["deletePersonalTagGroups", "g1"],
    consent: ["deleteConsentRecords", "c1"],
    settings: ["deleteUserPreferences", "preferences"],
    // Surfaced the moment the scanner learned to resolve constants and to skip
    // comments: it is genuinely covered by its own tier step, it was simply
    // never visible to this map before.
    unified_shopping_lists: ["deleteShoppingLists", "l1"],
  };

  const discovered = discoverUserSubcollectionWriters(repoRoot);

  check(
    "the source scan found the writers it is supposed to range over",
    discovered.has("notifications") &&
      discovered.has("onboarding") &&
      discovered.has("recentContentHashes"),
    `discovered: ${JSON.stringify([...discovered.keys()].sort())}`,
  );

  const uncovered: string[] = [];
  for (const name of [...discovered.keys()].sort()) {
    if (subs.includes(name)) continue;
    if (triggerOwned.includes(name)) continue;
    if (name in COVERED_BY_OWN_STEP) continue;
    uncovered.push(`${name} (chained in ${discovered.get(name)})`);
  }
  check(
    "every users/{uid} subcollection any repo chain names is reached by the cascade",
    uncovered.length === 0,
    `unreached, so the probe will report them as residual forever: ${JSON.stringify(uncovered)}`,
  );

  for (const [name, [fnName, docId]] of Object.entries(COVERED_BY_OWN_STEP)) {
    const db = new FakeFirestore();
    db.set(`users/${UID}`, { displayName: "Raderad" });
    db.set(`users/${UID}/${name}/${docId}`, { v: 1 });
    db.set(`users/${OTHER}/${name}/${docId}`, { v: 1 });
    const fn = cascade[fnName];
    check(
      `${fnName} is exported, so the coverage map names something real`,
      typeof fn === "function",
      `cascade.${fnName} is ${typeof fn}`,
    );
    if (typeof fn !== "function") continue;
    await fn(asDb(db), UID);
    check(
      `${fnName} really erases users/{uid}/${name}`,
      !db.has(`users/${UID}/${name}/${docId}`),
      "the row survived the step the coverage map credits it to",
    );
    check(
      `…and leaves another user's ${name} alone`,
      db.has(`users/${OTHER}/${name}/${docId}`),
      "the step is not keyed on the uid",
    );
  }
}

/**
 * BUT-1992 — the invariant is EXPORT ⊇ DELETION.
 *
 * Anything in the cascade's `subs` list must have been obtainable by its
 * subject first, or it is destroyed having never been disclosable under
 * Art. 15. Collections erased by their own tier steps are outside what this
 * ranges over; the sibling scenario proves those have a DELETER, not an export. BUT-1957 gave
 * the DELETION half a source-derived guard; this is its counterpart, and the
 * ticket's own framing is that the missing guard — not any single gap — is the
 * defect. Every future widening of `subs` repeats the mistake otherwise, and
 * nothing reddens.
 *
 * The exported set is derived from SOURCE — parsed out of the export
 * repository's `.collection(users).doc(uid).collection(X)` chains, rather than
 * restated here, because two hand-kept lists that must agree is precisely how
 * BUT-1957's own two gaps were created.
 *
 * The anchor is the CHAIN, not `ExportResourceType`: that enum has fewer members
 * than the repository has export methods, the mapping is many-to-one, and its
 * values are log labels rather than paths — so a new section can reuse an
 * existing member and this guard would pass green (the DBA seat's finding).
 *
 * This scenario reads DART source, so its CI trigger has to reach Dart. It did
 * not: the workflow fired on `functions/**` only, and the change most likely to
 * break the invariant — a repository starting to write a new subcollection, or
 * an export section being deleted — is Dart-only, so the guard slept through
 * exactly its own case. `cloud-functions-unit.yml` now lists the `lib/` paths,
 * and `assertGuardTriggersCoverItsDartInputs` below derives what it must list
 * from the files this scenario actually opens, so the two cannot drift apart
 * silently in either direction. BUT-2002.
 */
async function scenario_exportCoversEveryDeletedSubcollection(): Promise<void> {
  // eslint-disable-next-line @typescript-eslint/no-require-imports
  const fs = require("fs");
  // eslint-disable-next-line @typescript-eslint/no-require-imports
  const path = require("path");
  const cascade = require("../account/account-deletion-cascade");

  const repoRoot = path.join(__dirname, "..", "..", "..");
  // BUT-2043: the real value, imported — see the deletion half's note. The
  // check that lived here proved the text parser still worked, and there is no
  // parser now.
  const subs: string[] = cascade.USER_SUBCOLLECTIONS;
  check(
    "USER_SUBCOLLECTIONS is imported and non-empty",
    Array.isArray(subs) && subs.includes("ingredients"),
    `USER_SUBCOLLECTIONS: ${JSON.stringify(subs)}`,
  );

  // The exempt map is imported from PRODUCTION source, not restated here. An
  // exemption added to a test file reads as bookkeeping and gets waved through;
  // one added to the cascade shows up in the diff a reviewer is already reading.
  const exempt = cascade.EXPORT_EXEMPT as Record<string, string>;
  check(
    "EXPORT_EXEMPT is exported from the cascade and is a real map",
    exempt && typeof exempt === "object" && Object.keys(exempt).length > 0,
    `EXPORT_EXEMPT is ${typeof exempt}`,
  );

  // An exemption with no stated reason is the rubber stamp this design exists to
  // prevent, so it fails as loudly as a missing one.
  const unreasoned = Object.entries(exempt)
    .filter(([, why]) => typeof why !== "string" || why.trim().length < 20)
    .map(([name]) => name);
  check(
    "every exemption states a reason",
    unreasoned.length === 0,
    `exempt without a written reason: ${JSON.stringify(unreasoned)}`,
  );

  // The exported set, read off the one file that performs user-scoped export
  // reads. Constants resolved, comments stripped — the repo writes example
  // chains in prose, and a scanner that reads documentation as code reddens on
  // its own docstrings.
  const collectionConstants = new Map<string, string>();
  const constFile = path.join(
    repoRoot,
    "lib",
    "core",
    "constants",
    "firestore_collections.dart",
  );
  if (fs.existsSync(constFile)) {
    const src = fs.readFileSync(constFile, "utf8") as string;
    for (const m of src.matchAll(
      /static\s+const\s+String\s+([A-Za-z_]\w*)\s*=\s*['"]([A-Za-z_]+)['"]/g,
    )) {
      collectionConstants.set(m[1], m[2]);
    }
  }

  const exportFile = path.join(
    repoRoot,
    "lib",
    "repositories",
    "firebase",
    "firebase_data_export_repository.dart",
  );
  const exportSource = (fs.readFileSync(exportFile, "utf8") as string)
    .replace(/\/\*[\s\S]*?\*\//g, "")
    .replace(/\/\/[^\n]*/g, "");

  // `\w*` and not `[A-Za-z_]\w*` before `[Uu]sers`: the latter REQUIRES a
  // character in front, so it matches `FirestoreCollections.usersCollection`
  // and never the bare `FirestoreCollections.users` every Dart repository
  // actually writes. Measured — with the stricter form this scan found zero
  // sections and the guard would have passed by ranging over nothing.
  const chain =
    /collection\(\s*(?:['"]users['"]|(?:[A-Za-z_]\w*\.)?\w*[Uu]sers\w*)\s*\)\s*\.\s*doc\(\s*[^)]*\)\s*\.\s*collection\(\s*([^)\s]+)\s*\)/gs;
  const exported = new Set<string>();
  for (const m of exportSource.matchAll(chain)) {
    const raw = m[1].trim();
    const literal = /^['"]([A-Za-z_]+)['"]$/.exec(raw);
    const viaConst = /^FirestoreCollections\.(\w+)$/.exec(raw);
    const name = literal
      ? literal[1]
      : viaConst
        ? collectionConstants.get(viaConst[1])
        : undefined;
    if (name) exported.add(name);
  }

  check(
    "the export scan found the sections it is supposed to range over",
    exported.has("ingredients") &&
      exported.has("onboarding") &&
      exported.has("acquisition") &&
      exported.has("settings"),
    `discovered export sections: ${JSON.stringify([...exported].sort())}`,
  );

  const gaps: string[] = [];
  for (const name of [...new Set(subs)].sort()) {
    if (exported.has(name)) continue;
    if (name in exempt) continue;
    gaps.push(name);
  }
  check(
    "every subcollection the cascade erases is either exported or exempted with a reason",
    gaps.length === 0,
    "erased but never obtainable under Art. 15, and not written down as a " +
      `decision: ${JSON.stringify(gaps)}`,
  );

  // An exemption for something the cascade no longer deletes is dead text that
  // outlives its subject, and a reader cannot tell it from a live decision.
  // Some exemptions are justified by the ABSENCE of a writer. That premise is
  // measured once, at the moment it is written — so
  // the day a feature starts writing one of those paths (`firestore.rules`
  // already permits the owner to write `users/{uid}/conversations`), the cascade
  // would erase rows the export never reproduced and this guard would still be
  // green, because `name in exempt` is unconditional. Reuses the SAME writer
  // scan the deletion half runs; the exemption text is the anchor, so a reason
  // rewritten away from "NO LIVE WRITER" is a deliberate act, not a silent one.
  const writers = discoverUserSubcollectionWriters(repoRoot);
  const revived = Object.entries(exempt)
    .filter(([name, why]) => why.startsWith("NO LIVE WRITER") && writers.has(name))
    .map(([name]) => `${name} (chained in ${writers.get(name)})`);
  check(
    "no legacy-only exemption has acquired a users/{uid} chain",
    revived.length === 0,
    "exempted as write-dead, but a `users/{uid}` chain names it — either a " +
      "writer appeared and the rows are now erased without ever being " +
      "exportable, or it is being exported and the exemption contradicts " +
      `that: ${JSON.stringify(revived)}`,
  );

  const stale = Object.keys(exempt).filter((n) => !subs.includes(n));
  check(
    "no exemption names a collection the cascade has stopped deleting",
    stale.length === 0,
    `exempt but absent from subs: ${JSON.stringify(stale)}`,
  );

  // BUT-2002. The two paths are the ones THIS scenario just opened, passed as
  // values rather than restated as literals — a hand-kept second copy of the
  // list is the drift this whole file exists to prevent.
  // NOT proven by this call: the workflow also lists `lib/services/account/**`,
  // which this scenario never reads. That glob is deliberate breadth, not a
  // derived input — the export MANAGERS and the service that builds them decide
  // which repository methods get called, so deleting a call there drops a
  // section from the bundle while the repository method survives and the
  // chain-scan above still finds it. This guard cannot see that case; the line
  // is there so CI at least runs on it.
  assertGuardTriggersCoverItsDartInputs(repoRoot, [constFile, exportFile], check);
}

/**
 * BUT-2046: the collection-group index the reporter sweep needs. Same reasoning
 * as `scenario_pollVoteIndexIsDeclared` above — automatic single-field indexes
 * are COLLECTION-scoped, so `collectionGroup('report_history').where('reporterId')`
 * throws FAILED_PRECONDITION without the override, and a `--force` index deploy
 * prunes anything absent from the file.
 *
 * The TTL half is pinned in the same place: it is what eventually removes a row
 * the late-trigger race writes after the sweep has run, which is the residual
 * the deleter's own docstring names.
 */
async function scenario_reportHistoryIndexAndTtlAreDeclared(): Promise<void> {
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
      ttl?: boolean;
      indexes?: { order?: string; queryScope?: string }[];
    }[];
  };
  const overrides = indexes.fieldOverrides ?? [];
  const reporter = overrides.find(
    (o) => o.collectionGroup === "report_history" && o.fieldPath === "reporterId",
  );
  check(
    "report_history.reporterId has a COLLECTION_GROUP single-field index declared",
    (reporter?.indexes ?? []).some(
      (i) => i.queryScope === "COLLECTION_GROUP" && i.order === "ASCENDING",
    ),
    `override: ${JSON.stringify(reporter)}`,
  );
  const ttl = overrides.find(
    (o) => o.collectionGroup === "report_history" && o.fieldPath === "expireAt",
  );
  check(
    "report_history.expireAt carries the 180-day TTL policy",
    ttl?.ttl === true,
    `override: ${JSON.stringify(ttl)}`,
  );
}

/**
 * BUT-2115: one reaction key list in three places — the rules' `reactionKeys()`,
 * the app's `kReactionEmojis` and the cascade's `COMMENT_REACTION_KEYS`. A key
 * the rules accept and the cascade does not sweep would survive an erasure; a
 * key the app offers and the rules refuse would fail on every tap.
 */
async function scenario_reactionKeysAgreeAcrossRulesAppAndCascade(): Promise<void> {
  // eslint-disable-next-line @typescript-eslint/no-require-imports
  const fs = require("fs");
  // eslint-disable-next-line @typescript-eslint/no-require-imports
  const path = require("path");
  const { COMMENT_REACTION_KEYS } = require("../account/account-deletion-cascade");
  const repoRoot = path.resolve(__dirname, "..", "..", "..");
  assertGuardTriggersCoverItsDartInputs(repoRoot, [
    path.join(repoRoot, "lib", "widgets", "common", "emoji_reaction_picker.dart"),
  ], check);
  const quoted = (body: string): string[] =>
    [...body.matchAll(/['"]([A-Za-z_]+)['"]\s*[,:\]]/g)].map((m) => m[1]);

  const rules = fs.readFileSync(path.join(repoRoot, "firestore.rules"), "utf8") as string;
  const rulesFn = rules.match(/function reactionKeys\(\)\s*\{\s*return\s*\[([^\]]*)\]/);
  const rulesKeys = rulesFn ? quoted(rulesFn[1] + "]") : [];

  const dart = fs.readFileSync(
    path.join(repoRoot, "lib", "widgets", "common", "emoji_reaction_picker.dart"),
    "utf8",
  ) as string;
  const dartMap = dart.match(/const Map<String, String> kReactionEmojis = \{([\s\S]*?)\n\};/);
  const dartKeys = dartMap ? quoted(dartMap[1]) : [];

  const cascade = JSON.stringify([...COMMENT_REACTION_KEYS]);
  check(
    "the rules' reactionKeys() equals COMMENT_REACTION_KEYS",
    rulesKeys.length > 0 && JSON.stringify(rulesKeys) === cascade,
    `rules ${JSON.stringify(rulesKeys)} vs cascade ${cascade}`,
  );
  check(
    "the app's kReactionEmojis keys equal COMMENT_REACTION_KEYS",
    dartKeys.length > 0 && JSON.stringify(dartKeys) === cascade,
    `app ${JSON.stringify(dartKeys)} vs cascade ${cascade}`,
  );
}

/**
 * BUT-2112: the collection-group index the like sweep and its probe leg need.
 * Same reasoning as `scenario_pollVoteIndexIsDeclared`.
 */
async function scenario_commentLikeIndexIsDeclared(): Promise<void> {
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
    (o) => o.collectionGroup === "likes" && o.fieldPath === "userId",
  );
  check(
    "likes.userId has a COLLECTION_GROUP single-field index declared",
    (override?.indexes ?? []).some(
      (i) => i.queryScope === "COLLECTION_GROUP" && i.order === "ASCENDING",
    ),
    `override: ${JSON.stringify(override)}`,
  );
}

/**
 * BUT-2118: the sweep and its probe are collection-group queries on `userId`,
 * which need a COLLECTION_GROUP single-field index or fail FAILED_PRECONDITION.
 */
async function scenario_liveMenuVoteIndexIsDeclared(): Promise<void> {
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
    (o) => o.collectionGroup === "votes" && o.fieldPath === "userId",
  );
  check(
    "votes.userId has a COLLECTION_GROUP single-field index declared",
    (override?.indexes ?? []).some(
      (i) => i.queryScope === "COLLECTION_GROUP" && i.order === "ASCENDING",
    ),
    `override: ${JSON.stringify(override)}`,
  );
}

async function main(): Promise<void> {
  await scenario_messagesInLeftConversationsAreReached();
  await scenario_rosterIndexIsDeclared();
  await scenario_blockMirrorExemptionRestsOnTheSameDecision();
  await scenario_reportHistoryIndexAndTtlAreDeclared();
  await scenario_everyCollectionIsDecided();
  await scenario_everyUserSubcollectionHasADeleter();
  await scenario_exportCoversEveryDeletedSubcollection();
  await scenario_reactionKeysAgreeAcrossRulesAppAndCascade();
  await scenario_commentLikeIndexIsDeclared();
  await scenario_liveMenuVoteIndexIsDeclared();

  finishSuite("BUT-1766/BUT-1768 deletion cascade guards");
}

main().catch((err) => {
  console.error("Test runner crashed:", err);
  process.exit(1);
});
