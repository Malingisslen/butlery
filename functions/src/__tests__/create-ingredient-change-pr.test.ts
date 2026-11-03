/**
 * `createIngredientChangePr`: admin gate, lock, the closed-PR sweep, the
 * rolling rebuild, status writes that leave a concurrent withdrawal alone,
 * the run record, and that no uid reaches GitHub.
 *
 * GitHub is an in-memory double of `RepoClient`; Firestore is the shared
 * `_fake-firestore.ts`, which has no contention, so the withdrawal race is
 * staged inside the run, right before the status writes.
 *
 * Run with: npx ts-node src/__tests__/create-ingredient-change-pr.test.ts
 */

import * as fs from "fs";
import * as path from "path";
import * as admin from "firebase-admin";
import type { CallableRequest } from "firebase-functions/v2/https";
import {
  CSV_PATH,
  handleCreateIngredientChangePr,
  IngredientChangePrResult,
  LOCK_MS,
  REJECTED_RETENTION_MS,
  REVIEW_RETENTION_MS,
} from "../admin/create-ingredient-change-pr";
import { GITHUB_APP_BOT_LOGIN, INGREDIENT_BOT_BRANCH, PullRequest, RepoClient } from "../admin/github-app";
import { csvRowToDoc, parseCsvFile } from "../admin/ingredient-csv-writer";
import { hashUid } from "../shared/hash-uid";
import { RUN_UID_HASH_FIELD } from "../account/cascade/ingredient-change-requests";
import { FakeFirestore } from "./_fake-firestore";
import { assertEqual, runTests, UnitCase } from "./_unit-runner";

const REAL = fs.readFileSync(path.resolve(__dirname, "../../..", CSV_PATH), "utf-8");
const FILE = parseCsvFile(REAL);
const ID = FILE.header.indexOf("id");
const [A, B, C] = FILE.rows.slice(0, 3).map((r) => r.values[ID]);
const docOf = (id: string) => csvRowToDoc(FILE.header, FILE.rows.find((r) => r.values[ID] === id)!.values);
const NOW = new Date("2026-11-03T12:00:00Z");
const ADMIN = "admin-uid-1234567890";
const COL = "ingredient_change_requests";
const DAY = 24 * 60 * 60 * 1000;

function assert(cond: boolean, msg: string): void {
  if (!cond) throw new Error(msg);
}

interface FakeCommit {
  parents: string[];
  tree: string;
  text: string;
  author: string;
  committer?: string;
  verified?: boolean;
}

class FakeRepo implements RepoClient {
  botLogin = GITHUB_APP_BOT_LOGIN;
  refs = new Map<string, string>([["main", "m0"]]);
  commits = new Map<string, FakeCommit>([["m0", { parents: [], tree: "t-m0", text: REAL, author: "Malin" }]]);
  pulls: Array<PullRequest & { body: string; title: string }> = [];
  log: string[] = [];
  messages: string[] = [];
  beforePull: (() => void) | null = null;
  private n = 0;

  async getRefSha(branch: string) {
    return this.refs.get(branch) ?? null;
  }
  async getCommitTree(sha: string) {
    const c = this.commits.get(sha)!;
    return { treeSha: c.tree, parents: c.parents };
  }
  async getFile(_path: string, ref: string) {
    return { text: this.commits.get(this.refs.get(ref) ?? ref)!.text, blobSha: "b" };
  }
  async commitFile(args: { parent: string; baseTree: string; path: string; text: string; message: string }) {
    const sha = `c${++this.n}`;
    // What GitHub records for a commit made through the API by the App.
    this.commits.set(sha, {
      parents: [args.parent], tree: `t-${sha}`, text: args.text,
      author: GITHUB_APP_BOT_LOGIN, committer: "web-flow", verified: true,
    });
    this.messages.push(args.message);
    this.log.push("commit");
    return { commitSha: sha, treeSha: `t-${sha}` };
  }
  async createBotBranch(branch: string, sha: string) {
    this.refs.set(branch, sha);
    this.log.push("create-branch");
  }
  async forceUpdateBotBranch(branch: string, sha: string) {
    this.refs.set(branch, sha);
    this.log.push("force-update");
  }
  async branchCommits(branch: string) {
    const head = this.refs.get(branch);
    const c = head ? this.commits.get(head)! : null;
    return c
      ? [{ sha: head!, authorLogin: c.author, committerLogin: c.committer ?? c.author, verified: c.verified === true }]
      : [];
  }
  async findOpenPull() {
    return this.pulls.find((p) => p.state === "open") ?? null;
  }
  async getPull(n: number) {
    return this.pulls.find((p) => p.number === n)!;
  }
  async createPull(args: { branch: string; title: string; body: string }) {
    this.beforePull?.();
    const pull = { number: 100 + this.pulls.length, url: `https://github.com/x/pull/${100 + this.pulls.length}`, state: "open" as const, merged: false, ...args };
    this.pulls.push(pull);
    this.log.push("create-pull");
    return pull;
  }
  async updatePull(n: number, args: { title: string; body: string }) {
    this.beforePull?.();
    const pull = this.pulls.find((p) => p.number === n)!;
    Object.assign(pull, args);
    this.log.push("update-pull");
    return pull;
  }
  async closePull(n: number) {
    this.pulls.find((p) => p.number === n)!.state = "closed";
    this.log.push("close-pull");
  }
}

function request(uid: string | null, claims: Record<string, unknown> = { admin: true }): CallableRequest<unknown> {
  return { auth: uid ? { uid, token: claims } : undefined, data: {} } as unknown as CallableRequest<unknown>;
}

function world() {
  const store = new FakeFirestore({ now: admin.firestore.Timestamp.fromDate(NOW) });
  store.seed(`admins/${ADMIN}`, { addedAt: 1 });
  const repo = new FakeRepo();
  const limits: string[] = [];
  let run = 0;
  const deps = {
    db: store.db,
    rateLimit: async (subject: string, op: string) => void limits.push(`${subject}:${op}`),
    connect: async () => repo,
    now: () => NOW,
    runId: () => `run-${++run}`,
  };
  return { store, repo, limits, deps };
}

let seq = 0;
function seedProposal(store: FakeFirestore, id: string, ingredientId: string, changes: unknown, extra: Record<string, unknown> = {}) {
  store.seed(`${COL}/${id}`, {
    ingredientId, changes, status: "pending", createdBy: ADMIN, note: "privat anteckning",
    createdAt: admin.firestore.Timestamp.fromMillis(NOW.getTime() - DAY + ++seq), ...extra,
  });
}

const notes = (id: string, next: string) => ({ notes_sv: { old: docOf(id).notesSv ?? "", new: next } });

async function denied(fn: () => Promise<unknown>, code: string, message?: string): Promise<void> {
  try {
    await fn();
  } catch (err) {
    const e = err as { code?: string; message?: string };
    assertEqual(e.code, code, `code (${e.message})`);
    if (message) assertEqual(e.message, message, "message");
    return;
  }
  throw new Error(`expected ${code}`);
}

const expireMs = (store: FakeFirestore, id: string) =>
  (store.read(`${COL}/${id}`)?.expireAt as admin.firestore.Timestamp).toMillis() - NOW.getTime();

const cases: UnitCase[] = [
  {
    name: "a caller without the admin claim, or without an admins/{uid} doc, is refused before any limit or lock",
    fn: async () => {
      const w = world();
      await denied(() => handleCreateIngredientChangePr(request(null), w.deps), "unauthenticated");
      await denied(() => handleCreateIngredientChangePr(request("u1", {}), w.deps), "permission-denied");
      await denied(() => handleCreateIngredientChangePr(request("claim-only"), w.deps), "permission-denied");
      assertEqual(w.limits.length, 0, "no rate limit spent");
      assert(!w.store.has("ingredient_change_locks/singleton"), "no lock taken");
    },
  },
  {
    name: "the per-admin and the global rate limit are both charged",
    fn: async () => {
      const w = world();
      await handleCreateIngredientChangePr(request(ADMIN), w.deps);
      assertEqual(w.limits.join(","), `${ADMIN}:createIngredientChangePr,all-admins:createIngredientChangePrGlobal`, "limits");
    },
  },
  {
    name: "a live lock refuses the run; a stale one is taken over; the lock is gone afterwards, also after a failure",
    fn: async () => {
      const w = world();
      w.store.seed("ingredient_change_locks/singleton", {
        owner: "other", expiresAt: admin.firestore.Timestamp.fromMillis(NOW.getTime() + 60_000),
      });
      await denied(() => handleCreateIngredientChangePr(request(ADMIN), w.deps), "failed-precondition", "locked");
      assertEqual(w.store.read("ingredient_change_locks/singleton")?.owner, "other", "live lock kept");

      w.store.seed("ingredient_change_locks/singleton", {
        owner: "other", expiresAt: admin.firestore.Timestamp.fromMillis(NOW.getTime() - LOCK_MS - 1),
      });
      await handleCreateIngredientChangePr(request(ADMIN), w.deps);
      assert(!w.store.has("ingredient_change_locks/singleton"), "released after success");

      w.repo.refs.delete("main");
      await denied(() => handleCreateIngredientChangePr(request(ADMIN), w.deps), "unavailable", "github-no-main");
      assert(!w.store.has("ingredient_change_locks/singleton"), "released after failure");
    },
  },
  {
    name: "a run applies, conflicts and rejects; statuses, PR number, csvValue and expiry are written",
    fn: async () => {
      const w = world();
      seedProposal(w.store, "ok", A, notes(A, "Ny anteckning."));
      seedProposal(w.store, "stale", B, { status: { old: "not-the-csv-status", new: "verified" } });
      seedProposal(w.store, "bad", C, { notes_sv: { old: docOf(C).notesSv ?? "", new: "@cmd" } });
      seedProposal(w.store, "done", A, { swedish: { old: "x", new: "y" } }, { status: "withdrawn" });
      const r = await handleCreateIngredientChangePr(request(ADMIN), w.deps);
      assertEqual(JSON.stringify([r.applied, r.conflicts, r.rejected, r.prNumber]), "[1,1,1,100]", JSON.stringify(r));
      assertEqual(w.repo.log.join(","), "commit,create-branch,create-pull", "GitHub calls");
      const ok = w.store.read(`${COL}/ok`)!;
      assert(ok.status === "inReview" && ok.prNumber === 100, JSON.stringify(ok));
      assertEqual(expireMs(w.store, "ok"), REVIEW_RETENTION_MS, "inReview 90 d");
      const stale = w.store.read(`${COL}/stale`)!;
      assert(stale.status === "conflict" && stale.reason === "csv-mismatch" &&
        JSON.stringify(stale.csvValue) === JSON.stringify({ status: docOf(B).status }), JSON.stringify(stale));
      assertEqual(expireMs(w.store, "stale"), REVIEW_RETENTION_MS, "conflict 90 d");
      const bad = w.store.read(`${COL}/bad`)!;
      assert(bad.status === "rejected" && bad.reason === "formula-prefix", JSON.stringify(bad));
      assertEqual(expireMs(w.store, "bad"), REJECTED_RETENTION_MS, "rejected 365 d");
      assertEqual(w.store.read(`${COL}/done`)?.status, "withdrawn", "a withdrawn proposal is not read");
      const head = w.repo.commits.get(w.repo.refs.get(INGREDIENT_BOT_BRANCH)!)!;
      assertEqual(JSON.stringify(head.parents), '["m0"]', "built on main");
      assert(head.text.includes("Ny anteckning.") && !head.text.includes("@cmd"), "only the applied change");
    },
  },
  {
    name: "no uid, hashed uid or note reaches the commit, the PR title or the PR body",
    fn: async () => {
      const w = world();
      seedProposal(w.store, "ok", A, notes(A, "Anteckning."));
      seedProposal(w.store, "stale", B, { status: { old: "nope", new: "verified" } });
      await handleCreateIngredientChangePr(request(ADMIN), w.deps);
      const text = [...w.repo.messages, ...w.repo.pulls.map((p) => `${p.title}\n${p.body}`),
        w.repo.commits.get(w.repo.refs.get(INGREDIENT_BOT_BRANCH)!)!.text].join("\n");
      for (const needle of [ADMIN, hashUid(ADMIN), "privat anteckning"]) assert(!text.includes(needle), `leaked ${needle}`);
    },
  },
  {
    name: "the run record holds the hashed uid, PR number and counts, with a 365-day expiry",
    fn: async () => {
      const w = world();
      seedProposal(w.store, "ok", A, notes(A, "Anteckning."));
      await handleCreateIngredientChangePr(request(ADMIN), w.deps);
      const runs = w.store.childPaths("ingredient_change_runs").map((p) => w.store.read(p)!);
      assertEqual(runs.length, 1, "one record");
      const run = runs[0];
      assertEqual(run.adminUidHash, hashUid(ADMIN), "hashed uid");
      assert(!JSON.stringify(run).includes(ADMIN), "no raw uid");
      assertEqual(run.prNumber, 100, "pr number");
      assertEqual(JSON.stringify(run.counts), '{"applied":1,"conflicts":0,"rejected":0,"reopened":0,"skipped":0}', "counts");
      assertEqual((run.expireAt as admin.firestore.Timestamp).toMillis() - NOW.getTime(), 365 * DAY, "expiry");
    },
  },
  {
    name: "a second run on the same state pushes nothing new and updates the same PR",
    fn: async () => {
      const w = world();
      seedProposal(w.store, "ok", A, notes(A, "Anteckning."));
      await handleCreateIngredientChangePr(request(ADMIN), w.deps);
      const head = w.repo.refs.get(INGREDIENT_BOT_BRANCH);
      w.repo.log = [];
      const r = await handleCreateIngredientChangePr(request(ADMIN), w.deps);
      assertEqual(w.repo.log.join(","), "update-pull", "no commit, no ref update");
      assertEqual(w.repo.refs.get(INGREDIENT_BOT_BRANCH), head, "branch unchanged");
      assertEqual(r.prNumber, 100, "same PR");
      assertEqual(w.store.read(`${COL}/ok`)?.status, "inReview", "still in review");
    },
  },
  {
    name: "a proposal withdrawn during the run is left withdrawn",
    fn: async () => {
      const w = world();
      seedProposal(w.store, "ok", A, notes(A, "Anteckning."));
      seedProposal(w.store, "gone", B, notes(B, "Annan."));
      w.repo.beforePull = () => {
        const doc = w.store.read(`${COL}/gone`)!;
        w.store.seed(`${COL}/gone`, { ...doc, status: "withdrawn" });
      };
      const r = await handleCreateIngredientChangePr(request(ADMIN), w.deps);
      assertEqual(w.store.read(`${COL}/gone`)?.status, "withdrawn", "withdrawal kept");
      assertEqual(w.store.read(`${COL}/gone`)?.prNumber, undefined, "no PR number written");
      assertEqual(r.skipped, 1, "reported as skipped");
      assertEqual(w.store.read(`${COL}/ok`)?.status, "inReview", "the other one written");
    },
  },
  {
    name: "a withdrawn proposal drops out at the next rebuild",
    fn: async () => {
      const w = world();
      seedProposal(w.store, "ok", A, notes(A, "Kvar."));
      seedProposal(w.store, "later-out", B, notes(B, "Bort."));
      await handleCreateIngredientChangePr(request(ADMIN), w.deps);
      const doc = w.store.read(`${COL}/later-out`)!;
      w.store.seed(`${COL}/later-out`, { ...doc, status: "withdrawn" });
      await handleCreateIngredientChangePr(request(ADMIN), w.deps);
      const head = w.repo.commits.get(w.repo.refs.get(INGREDIENT_BOT_BRANCH)!)!;
      assert(head.text.includes("Kvar.") && !head.text.includes("Bort."), "rebuilt without it");
      assertEqual(w.repo.log.filter((l) => l === "force-update").length, 1, "force-updated once");
    },
  },
  {
    name: "sweep: a PR closed unmerged hands its proposals back; a merged one keeps them for the sync",
    fn: async () => {
      const w = world();
      w.repo.pulls.push({ number: 7, url: "u7", state: "closed", merged: false, title: "", body: "" });
      w.repo.pulls.push({ number: 8, url: "u8", state: "closed", merged: true, title: "", body: "" });
      seedProposal(w.store, "closed", A, notes(A, "Igen."), { status: "inReview", prNumber: 7 });
      seedProposal(w.store, "merged", B, notes(B, "Redan mergad."), { status: "inReview", prNumber: 8 });
      const r = await handleCreateIngredientChangePr(request(ADMIN), w.deps);
      assertEqual(r.reopened, 1, "one reopened");
      const closed = w.store.read(`${COL}/closed`)!;
      assert(closed.status === "inReview" && closed.prNumber === r.prNumber && r.prNumber !== 7, JSON.stringify(closed));
      const merged = w.store.read(`${COL}/merged`)!;
      assert(merged.status === "inReview" && merged.prNumber === 8, JSON.stringify(merged));
      const head = w.repo.commits.get(w.repo.refs.get(INGREDIENT_BOT_BRANCH)!)!;
      assert(!head.text.includes("Redan mergad."), "a merged PR's proposal is not rebuilt");
    },
  },
  {
    name: "nothing left to apply: the open bot PR is closed and nothing is pushed",
    fn: async () => {
      const w = world();
      seedProposal(w.store, "ok", A, notes(A, "Snart bort."));
      await handleCreateIngredientChangePr(request(ADMIN), w.deps);
      const doc = w.store.read(`${COL}/ok`)!;
      w.store.seed(`${COL}/ok`, { ...doc, status: "withdrawn" });
      w.repo.log = [];
      const r: IngredientChangePrResult = await handleCreateIngredientChangePr(request(ADMIN), w.deps);
      assertEqual(w.repo.log.join(","), "close-pull", "only the close");
      assertEqual(r.prNumber, null, "no PR");
    },
  },
  {
    name: "the bot branch is foreign unless the App authored every commit and GitHub verified it",
    fn: async () => {
      for (const [label, commit] of [
        ["someone else, committed by web-flow and verified", { author: "someone", committer: "web-flow", verified: true }],
        ["the App as author, not verified", { author: GITHUB_APP_BOT_LOGIN, committer: "web-flow", verified: false }],
        ["the App as author, committed by someone else", { author: GITHUB_APP_BOT_LOGIN, committer: "someone", verified: true }],
      ] as const) {
        const w = world();
        seedProposal(w.store, "ok", A, notes(A, "x."));
        w.repo.commits.set("h1", { parents: ["m0"], tree: "t", text: REAL, ...commit });
        w.repo.refs.set(INGREDIENT_BOT_BRANCH, "h1");
        await denied(() => handleCreateIngredientChangePr(request(ADMIN), w.deps), "aborted", "foreign-commits");
        assertEqual(w.repo.log.length, 0, `${label}: no GitHub write`);
        assertEqual(w.store.read(`${COL}/ok`)?.status, "pending", `${label}: no status write`);
      }
    },
  },
  {
    name: "the App's own API commit (web-flow, verified) is accepted on the next run",
    fn: async () => {
      const w = world();
      seedProposal(w.store, "ok", A, notes(A, "x."));
      await handleCreateIngredientChangePr(request(ADMIN), w.deps);
      seedProposal(w.store, "two", B, notes(B, "y."));
      const r = await handleCreateIngredientChangePr(request(ADMIN), w.deps);
      assertEqual(r.applied, 2, "rebuilt over the App's own commit");
    },
  },
  {
    name: "main moving during the rebuild aborts before the ref update",
    fn: async () => {
      const w = world();
      seedProposal(w.store, "ok", A, notes(A, "x."));
      const original = w.repo.commitFile.bind(w.repo);
      w.repo.commitFile = async (args) => {
        const out = await original(args);
        w.repo.refs.set("main", "m1");
        return out;
      };
      await denied(() => handleCreateIngredientChangePr(request(ADMIN), w.deps), "aborted", "main-moved");
      assert(!w.repo.refs.has(INGREDIENT_BOT_BRANCH), "branch not created");
      assertEqual(w.store.read(`${COL}/ok`)?.status, "pending", "no status write");
    },
  },
  {
    name: "the bot branch moving during the rebuild aborts before the ref update",
    fn: async () => {
      const w = world();
      seedProposal(w.store, "ok", A, notes(A, "x."));
      await handleCreateIngredientChangePr(request(ADMIN), w.deps);
      seedProposal(w.store, "two", B, notes(B, "y."));
      const head = w.repo.refs.get(INGREDIENT_BOT_BRANCH)!;
      const original = w.repo.commitFile.bind(w.repo);
      w.repo.commitFile = async (args) => {
        const out = await original(args);
        w.repo.refs.set(INGREDIENT_BOT_BRANCH, out.commitSha);
        return out;
      };
      w.repo.log = [];
      await denied(() => handleCreateIngredientChangePr(request(ADMIN), w.deps), "aborted", "branch-moved");
      assert(!w.repo.log.includes("force-update"), "no force update");
      assert(w.repo.refs.get(INGREDIENT_BOT_BRANCH) !== head, "the mover's ref is left as it is");
      assertEqual(w.store.read(`${COL}/two`)?.status, "pending", "no status write");
    },
  },
  {
    name: "the open PR merged before the push aborts before the ref update",
    fn: async () => {
      const w = world();
      seedProposal(w.store, "ok", A, notes(A, "x."));
      await handleCreateIngredientChangePr(request(ADMIN), w.deps);
      seedProposal(w.store, "two", B, notes(B, "y."));
      const original = w.repo.commitFile.bind(w.repo);
      w.repo.commitFile = async (args) => {
        const out = await original(args);
        w.repo.pulls[0].merged = true;
        return out;
      };
      w.repo.log = [];
      await denied(() => handleCreateIngredientChangePr(request(ADMIN), w.deps), "aborted", "pr-merged");
      assert(!w.repo.log.includes("force-update"), "no force update");
      assertEqual(w.store.read(`${COL}/two`)?.status, "pending", "no status write");
    },
  },
  {
    name: "the open PR merged between the push and the PR update aborts before any status write",
    fn: async () => {
      const w = world();
      seedProposal(w.store, "ok", A, notes(A, "x."));
      await handleCreateIngredientChangePr(request(ADMIN), w.deps);
      seedProposal(w.store, "two", B, notes(B, "y."));
      w.repo.beforePull = () => {
        w.repo.pulls[0].merged = true;
      };
      await denied(() => handleCreateIngredientChangePr(request(ADMIN), w.deps), "aborted", "pr-merged-during-rebuild");
      assertEqual(w.store.read(`${COL}/two`)?.status, "pending", "no status write");
    },
  },
  {
    name: "a failed run leaves a record with the outcome and the error code, no counts",
    fn: async () => {
      const w = world();
      w.repo.refs.delete("main");
      await denied(() => handleCreateIngredientChangePr(request(ADMIN), w.deps), "unavailable", "github-no-main");
      const runs = w.store.childPaths("ingredient_change_runs").map((p) => w.store.read(p)!);
      assertEqual(runs.length, 1, "one record");
      const run = runs[0];
      assert(run.outcome === "failed" && run.errorCode === "github-no-main" && run.counts === null, JSON.stringify(run));
      assertEqual(run[RUN_UID_HASH_FIELD], hashUid(ADMIN), "hashed uid");
      assertEqual((run.expireAt as admin.firestore.Timestamp).toMillis() - NOW.getTime(), 365 * DAY, "expiry");
    },
  },
  {
    name: "a run record that cannot be written never masks the result or the error",
    fn: async () => {
      const w = world();
      const db = w.store.db;
      const failing = new Proxy(db, {
        get(target, prop, receiver) {
          if (prop === "collection") {
            return (name: string) => {
              if (name === "ingredient_change_runs") {
                return { doc: () => ({ set: async () => { throw Object.assign(new Error("down"), { code: 14 }); } }) };
              }
              return target.collection(name);
            };
          }
          return Reflect.get(target, prop, receiver);
        },
      });
      seedProposal(w.store, "ok", A, notes(A, "x."));
      const r = await handleCreateIngredientChangePr(request(ADMIN), { ...w.deps, db: failing });
      assertEqual(r.applied, 1, "the result comes back");
      w.repo.refs.delete("main");
      await denied(() => handleCreateIngredientChangePr(request(ADMIN), { ...w.deps, db: failing }), "unavailable", "github-no-main");
    },
  },
  {
    name: "proposals that cancel out push nothing, close the PR and are rejected as no-change",
    fn: async () => {
      const w = world();
      const unit = docOf(A).typicalUnit ?? "";
      seedProposal(w.store, "keep", B, notes(B, "Kvar."));
      await handleCreateIngredientChangePr(request(ADMIN), w.deps);
      w.store.seed(`${COL}/keep`, { ...w.store.read(`${COL}/keep`)!, status: "withdrawn" });
      seedProposal(w.store, "there", A, { typical_unit: { old: unit, new: unit === "kg" ? "st" : "kg" } });
      seedProposal(w.store, "back", A, { typical_unit: { old: unit === "kg" ? "st" : "kg", new: unit } });
      w.repo.log = [];
      const r = await handleCreateIngredientChangePr(request(ADMIN), w.deps);
      assertEqual(w.repo.log.join(","), "close-pull", "only the close");
      assertEqual(r.prNumber, null, "no PR");
      for (const id of ["there", "back"]) {
        const d = w.store.read(`${COL}/${id}`)!;
        assert(d.status === "rejected" && d.reason === "no-change", `${id}: ${JSON.stringify(d)}`);
      }
    },
  },
  {
    name: "more queued proposals than the cap is refused rather than truncated",
    fn: async () => {
      const w = world();
      for (let i = 0; i < 501; i++) seedProposal(w.store, `q${i}`, A, notes(A, `n${i}`));
      await denied(() => handleCreateIngredientChangePr(request(ADMIN), w.deps), "failed-precondition", "too-many-proposals");
      assertEqual(w.repo.log.length, 0, "no GitHub write");
    },
  },
];

runTests("create-ingredient-change-pr (admin-vy C2)", cases);
