/**
 * BUT-2044 — the one-time move of `users/{uid}/friendCategories` forward.
 *
 * These cases exercise the branch that decides whether a row is DELETED: the
 * one where the live spelling already holds that doc id. A production run
 * reaches it only when two rows share an id, so a test is the only thing that
 * does.
 */
import { migrateUser, MigrationOutcome } from "../admin/migrate-friend-categories";

let passed = 0;
let failed = 0;
function check(name: string, cond: boolean, detail = ""): void {
  if (cond) {
    passed++;
    console.log(`  PASS  ${name}`);
  } else {
    failed++;
    console.log(`  FAIL  ${name}\n        ${detail}`);
  }
}

/** The two collections one user owns, and nothing else. */
class FakeUserDoc {
  constructor(
    public legacy: Record<string, unknown>,
    public live: Record<string, unknown>,
  ) {}

  collection(name: string): any {
    // Keyed on BOTH literals, not "legacy or else live": with an else-branch,
    // mutating the destination constant to any other string still landed the
    // copy in `live` and every case stayed green — the fake would have proved
    // the ordering while proving nothing about WHERE the row goes.
    if (name !== "friendCategories" && name !== "friend_categories") {
      throw new Error(`unexpected collection: ${name}`);
    }
    const store = name === "friendCategories" ? this.legacy : this.live;
    const self = this;
    return {
      get: async () => ({
        size: Object.keys(store).length,
        docs: Object.keys(store).map((id) => ({
          id,
          data: () => store[id],
          ref: { delete: async () => { delete store[id]; } },
        })),
      }),
      doc: (id: string) => ({
        get: async () => ({ exists: id in store, data: () => store[id] }),
        set: async (v: unknown) => { store[id] = v; },
      }),
      _store: store,
      _self: self,
    };
  }
}

async function main(): Promise<void> {
  console.log("BUT-2044 friendCategories migration\n");

  // ── the normal path ──
  const plain = new FakeUserDoc({ g1: { name: "Familjen" } }, {});
  const r1: MigrationOutcome = await migrateUser(plain as any, true);
  check("a legacy row is copied to the live spelling", plain.live.g1 !== undefined,
    JSON.stringify(plain.live));
  check("…and the legacy row is then deleted", plain.legacy.g1 === undefined,
    JSON.stringify(plain.legacy));
  check("…and the outcome says so", r1.copied === 1 && r1.deleted === 1,
    JSON.stringify(r1));

  // ── the dry run writes nothing ──
  const dry = new FakeUserDoc({ g1: { name: "Familjen" } }, {});
  const r2 = await migrateUser(dry as any, false);
  check("a dry run copies nothing and deletes nothing",
    dry.live.g1 === undefined && dry.legacy.g1 !== undefined,
    JSON.stringify({ live: dry.live, legacy: dry.legacy }));
  check("…and still reports what it would move", r2.copied === 1 && r2.deleted === 0,
    JSON.stringify(r2));

  // ── THE DESTRUCTIVE BRANCH: the live spelling already holds that id ──
  //
  // The row must SURVIVE. Its contents were never copied anywhere, so deleting
  // it would discard data the script never read — the failure the copy-verify-
  // delete contract does not cover, and the one no production run could reach.
  const clash = new FakeUserDoc({ g1: { name: "gammal" } }, { g1: { name: "levande" } });
  const r3 = await migrateUser(clash as any, true);
  check("a colliding legacy row is NOT deleted",
    clash.legacy.g1 !== undefined, JSON.stringify(clash.legacy));
  check("…and the live row is NOT overwritten",
    (clash.live.g1 as { name: string }).name === "levande",
    JSON.stringify(clash.live));
  check("…and the collision is reported rather than counted as done",
    r3.skippedExisting === 1 && r3.deleted === 0 && r3.failures.length === 1,
    JSON.stringify(r3));

  console.log(`\nBUT-2044 friendCategories migration: ${passed}/${passed + failed} passing`);
  if (failed > 0) process.exitCode = 1;
}

main();
