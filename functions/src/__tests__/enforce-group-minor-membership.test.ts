/**
 * BUT-1626: unit tests for `isValidDocId` and `tryClearRoster`.
 *
 * The decision core these used to live beside moved to
 * `minor-membership-gate.test.ts` when BUT-1838 made the gate the primary
 * control and this trigger the backstop; the uid-safety and roster-clearing
 * cases stayed here, with the code they exercise.
 *
 * No emulator: these are the paths the emulator cannot reach — a uid the
 * backend would reject, and a Firestore read or delete that fails.
 *
 * Run: npx ts-node src/__tests__/enforce-group-minor-membership.test.ts
 */

import {
  MAX_ROSTER_ROWS,
  tryClearRoster,
} from "../messaging/enforce-group-minor-membership";
import { isValidDocId } from "../shared/valid-doc-id";

let run = 0;
let failed = 0;
function sameSet(a: string[], b: string[]): boolean {
  return (
    a.length === b.length && [...a].sort().join(",") === [...b].sort().join(",")
  );
}

function check(name: string, ok: boolean, detail?: string): void {
  run++;
  if (ok) {
    console.log(`  PASS  ${name}`);
  } else {
    failed++;
    console.log(`  FAIL  ${name}`);
    if (detail) console.log(`        ${detail}`);
  }
}

console.log("isValidDocId (hostile participantIds — BUT-1633)");

// A uid Firestore rejects as a doc id must be DROPPED, never passed to a
// `users/${uid}` path build. A throw there aborts before any minor is removed
// (fail-OPEN on a child-safety gate) and, under retry:true, repeats forever.
for (const bad of ["", "a/b", ".", "..", "__proto__", "__id__"]) {
  check(
    `rejects the malformed uid ${JSON.stringify(bad)}`,
    !isValidDocId(bad),
  );
}

// Note "..leading" is NOT here: it contains dots, so it is field-path-unsafe
// and correctly rejected — only the bare "." and ".." are doc-id-invalid.
for (const good of ["abc123", "__x", "x__", "aB9-_"]) {
  check(
    `accepts the ordinary uid ${JSON.stringify(good)}`,
    isValidDocId(good),
  );
}

check("rejects a non-string uid", !isValidDocId(42 as unknown));

// A uid that is a legal DOCUMENT ID but an illegal FIELD-PATH segment is the
// nastier case: update() rejects it with INVALID_ARGUMENT (grpc 3, not the
// NOT_FOUND 5 we catch), which retry:true replays forever while the minor is
// never removed. A dotted uid is wrong even when it does not throw —
// `participantDisplayNames.a.b` addresses a nested map, not the key "a.b".
for (const bad of ["a.b", "..leading", "u[0]", "u]", "wild*card", "back`tick"]) {
  check(
    `rejects the field-path-unsafe uid ${JSON.stringify(bad)}`,
    !isValidDocId(bad),
  );
}

check("rejects an over-length uid (1500-byte cap)", !isValidDocId("a".repeat(1501)));
check("rejects an over-length multibyte uid", !isValidDocId("ä".repeat(800)));
check("accepts a uid at the byte cap", isValidDocId("a".repeat(1500)));

// NOTE: the raw-vs-sanitised padding bypass this file used to point at is gone
// with the trigger's move to `chat_groups` (BUT-1838): no Firestore rule reads
// that document's membership, so there is no second layer for a padded list to
// slip between. The equivalent guard now lives at the gate, before the write.

/**
 * `tryClearRoster` — its READ- and DELETE-failure paths, which the emulator
 * cannot reach, plus the cap boundary, which it can.
 *
 * Against the emulator nothing can make a delete fail: the Admin SDK bypasses
 * rules, and deleting a document that does not exist RESOLVES. A fake `db` is
 * the only instrument that can. What it pins is not cosmetic — the caller
 * deletes the conversation ONLY on a true answer, and a wrong true would leave
 * roster rows readable under a destroyed parent, forever, with no probe and no
 * sweep to find them.
 */
type FakeRef = { id: string; delete: () => Promise<void> };

/**
 * Records every delete attempt. Throws on any collection path it was not told
 * about, and honours `.limit()` the way a real query does — a stub that ignored
 * the limit would hide the difference between a bounded and an unbounded read,
 * which is the property test 3 exists to pin.
 */
function fakeDb(
  path: string,
  refs: FakeRef[],
  attempts: string[],
  /** Records the limit the caller asked for, so a test can pin that it asked. */
  limits: number[] = [],
) {
  const wrap = (r: FakeRef) => ({
    ref: {
      id: r.id,
      delete: () => {
        attempts.push(r.id);
        return r.delete();
      },
    },
  });
  return {
    collection(p: string) {
      if (p !== path) {
        // An unsimulated call must be loud. A stub that quietly returned an
        // empty list would make every assertion below vacuous.
        throw new Error(`fakeDb: unexpected collection path ${p}`);
      }
      return {
        limit(n: number) {
          limits.push(n);
          const page = refs.slice(0, n).map(wrap);
          return { get: async () => ({ size: page.length, docs: page }) };
        },
      };
    },
  } as unknown as Parameters<typeof tryClearRoster>[0];
}

const ok = (id: string): FakeRef => ({ id, delete: async () => undefined });
const rejects = (id: string, code: number): FakeRef => ({
  id,
  delete: async () => {
    throw Object.assign(new Error("boom"), { code });
  },
});

async function rosterTests(): Promise<void> {
  console.log("\ntryClearRoster");
  const PATH = "conversations/c1/participants";

  // 1. Happy path: every row deleted, verdict true.
  {
    const attempts: string[] = [];
    const verdict = await tryClearRoster(
      fakeDb(PATH, [ok("uidA"), ok("uidB")], attempts),
      "c1",
    );
    check(
      "deletes every row and reports success",
      verdict === true && sameSet(attempts, ["uidA", "uidB"]),
      `verdict=${verdict} attempts=${attempts.join(",")}`,
    );
  }

  // 2. A failing delete reports FALSE and never throws — the caller must then
  //    leave the conversation standing rather than delete it over rows that
  //    survived. Throwing instead would hand a retry:true trigger a
  //    deterministic error to loop on.
  //
  //    150 rows with the rejection in the FIRST chunk, deliberately: an
  //    attempts count over a single chunk cannot tell accumulate-then-throw from
  //    a bare `Promise.all`, because `.map()` invokes every `delete()` eagerly
  //    and "attempted" is recorded at call time. Only a fixture that CROSSES a
  //    chunk boundary separates them: drop the per-delete `.catch` and chunk 2
  //    never runs — 100 attempts, and a throw. The chunk SIZE itself is a
  //    concurrency bound rather than a correctness one, and is left unpinned.
  {
    const attempts: string[] = [];
    const rows = Array.from({ length: 150 }, (_, i) =>
      i === 3 ? rejects(`u${i}`, 7) : ok(`u${i}`),
    );
    let threw = false;
    let verdict: boolean | null = null;
    try {
      verdict = await tryClearRoster(fakeDb(PATH, rows, attempts), "c1");
    } catch {
      threw = true;
    }
    check(
      "a failed delete reports false without throwing, after attempting EVERY row",
      threw === false && verdict === false && attempts.length === 150,
      `threw=${threw} verdict=${verdict} attempts=${attempts.length}`,
    );
  }

  // 3. An implausibly large roster is a SEEDED one: rules let any signed-in user
  //    write this path while the parent is absent, with no rate limit. The read
  //    itself must be bounded — a cap applied AFTER enumerating everything is
  //    not a cap — and refusing means deleting nothing, so the caller keeps the
  //    parent alive, which is what holds the read fallback shut.
  {
    const attempts: string[] = [];
    const limits: number[] = [];
    const many = Array.from({ length: MAX_ROSTER_ROWS * 20 }, (_, i) => ok(`u${i}`));
    const verdict = await tryClearRoster(
      fakeDb(PATH, many, attempts, limits),
      "c1",
    );
    check(
      "refuses an implausibly large roster without deleting anything",
      verdict === false && attempts.length === 0,
      `verdict=${verdict} attempts=${attempts.length}`,
    );
    // The verdict alone does NOT prove the read was bounded — measured: with
    // `.limit()` widened to a million the assertion above still passes, because
    // the size check catches it either way. What the cap has to prevent is the
    // READ, so the limit the caller asks for is the thing to assert. Without
    // this the guard would pass while enumerating an attacker-sized collection
    // inside a `retry:true` trigger, which is the whole finding it exists for.
    check(
      "the READ is bounded by the cap, not merely the delete",
      limits.length === 1 && limits[0] === MAX_ROSTER_ROWS + 1,
      `limits=${limits.join(",")} expected=${MAX_ROSTER_ROWS + 1}`,
    );
  }

  // 4. A failing READ reports false and does not throw. It is the one `await`
  //    not covered by a per-delete catch, and the code-5 branch's safety rests
  //    on this function never throwing — a rejection escaping from the read
  //    would turn a handled concurrent-delete into a retry loop.
  {
    const attempts: string[] = [];
    const hostile = {
      collection: () => ({
        limit: () => ({
          get: async () => {
            throw Object.assign(new Error("read failed"), { code: 8 });
          },
        }),
      }),
    } as unknown as Parameters<typeof tryClearRoster>[0];
    let threw = false;
    let verdict: boolean | null = null;
    try {
      verdict = await tryClearRoster(hostile, "c1");
    } catch {
      threw = true;
    }
    check(
      "a failing read reports false instead of throwing",
      threw === false && verdict === false && attempts.length === 0,
      `threw=${threw} verdict=${verdict}`,
    );
  }

  // 5. The boundary itself, so the cap cannot be loosened into a no-op.
  {
    const attempts: string[] = [];
    const atCap = Array.from({ length: MAX_ROSTER_ROWS }, (_, i) => ok(`u${i}`));
    const verdict = await tryClearRoster(fakeDb(PATH, atCap, attempts), "c1");
    check(
      "a roster exactly at the cap is still cleared",
      verdict === true && attempts.length === MAX_ROSTER_ROWS,
      `verdict=${verdict} attempts=${attempts.length}`,
    );
  }
}

void rosterTests().then(() => {
  console.log(`\n${run - failed}/${run} passed`);
  if (failed > 0) process.exit(1);
});
