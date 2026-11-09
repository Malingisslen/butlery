/**
 * Admin-vy step D inside `createIngredientChangePr`: word-list proposals get
 * their own PR on `bot/occasion-changes` with both files in one commit; a
 * merged PR marks its proposals applied, a closed one hands them back; the
 * ingredient PR never sees a word-list proposal and a failing word-list run
 * never stops it.
 *
 * GitHub is an in-memory double of `RepoClient` that keeps files per commit;
 * Firestore is the shared `_fake-firestore.ts`.
 *
 * Run with: npx ts-node src/__tests__/occasion-change-pr.test.ts
 */

import * as fs from "fs";
import * as path from "path";
import * as admin from "firebase-admin";
import type { CallableRequest } from "firebase-functions/v2/https";
import { CSV_PATH, handleCreateIngredientChangePr, IngredientChangePrResult } from "../admin/create-ingredient-change-pr";
import { GITHUB_APP_BOT_LOGIN, INGREDIENT_BOT_BRANCH, OCCASION_BOT_BRANCH, PullRequest, RepoClient } from "../admin/github-app";
import { markAppliedProposals } from "../admin/mark-applied-core";
import { OCCASIONS_PATH, parseOccasions, readList, VOCABULARY_PATH } from "../admin/occasion-vocabulary";
import { csvRowToDoc, parseCsvFile } from "../admin/ingredient-csv-writer";
import { FakeFirestore } from "./_fake-firestore";
import { assertEqual, runTests, UnitCase } from "./_unit-runner";

const ROOT = path.resolve(__dirname, "../../..");
const CSV = fs.readFileSync(path.join(ROOT, CSV_PATH), "utf-8");
const JSON_TEXT = fs.readFileSync(path.join(ROOT, OCCASIONS_PATH), "utf-8");
const DART_TEXT = fs.readFileSync(path.join(ROOT, VOCABULARY_PATH), "utf-8");
const TITLE = "christmas.titleWords";
const TITLE_NOW = readList(parseOccasions(JSON_TEXT), TITLE)!;
const NOW = new Date("2026-11-04T12:00:00Z");
const ADMIN = "admin-uid-1234567890";
const COL = "ingredient_change_requests";
const DAY = 24 * 60 * 60 * 1000;

const FILE = parseCsvFile(CSV);
const ID = FILE.header.indexOf("id");
const ING = FILE.rows[0].values[ID];
const ING_NOTES = csvRowToDoc(FILE.header, FILE.rows[0].values).notesSv ?? "";

function assert(cond: boolean, msg: string): void {
  if (!cond) throw new Error(msg);
}

interface FakeCommit {
  parents: string[];
  tree: string;
  files: Record<string, string>;
  author: string;
  committer?: string;
  verified?: boolean;
}

type FakePull = PullRequest & { body: string; title: string; branch: string };

class FakeRepo implements RepoClient {
  botLogin = GITHUB_APP_BOT_LOGIN;
  refs = new Map<string, string>([["main", "m0"]]);
  commits = new Map<string, FakeCommit>([["m0", {
    parents: [], tree: "t-m0", author: "Malin",
    files: { [CSV_PATH]: CSV, [OCCASIONS_PATH]: JSON_TEXT, [VOCABULARY_PATH]: DART_TEXT },
  }]]);
  pulls: FakePull[] = [];
  log: string[] = [];
  failOn: string | null = null;
  private n = 0;

  private fail(op: string) {
    if (this.failOn === op) throw new Error(`staged failure in ${op}`);
  }
  async getRefSha(branch: string) {
    return this.refs.get(branch) ?? null;
  }
  async getCommitTree(sha: string) {
    const c = this.commits.get(sha)!;
    return { treeSha: c.tree, parents: c.parents };
  }
  async getFile(p: string, ref: string) {
    this.fail(`getFile:${p}`);
    const text = this.commits.get(this.refs.get(ref) ?? ref)!.files[p];
    if (text === undefined) throw new Error(`no ${p}`);
    return { text, blobSha: "b" };
  }
  async commitFile(args: { parent: string; baseTree: string; path: string; text: string; message: string }) {
    return this.commitFiles({ parent: args.parent, baseTree: args.baseTree, files: [{ path: args.path, text: args.text }], message: args.message });
  }
  async commitFiles(args: { parent: string; baseTree: string; files: Array<{ path: string; text: string }>; message: string }) {
    const sha = `c${++this.n}`;
    const files = { ...this.commits.get(args.parent)!.files };
    for (const f of args.files) files[f.path] = f.text;
    this.commits.set(sha, {
      parents: [args.parent], tree: `t-${sha}`, files,
      author: GITHUB_APP_BOT_LOGIN, committer: "web-flow", verified: true,
    });
    this.log.push(`commit:${args.files.map((f) => path.basename(f.path)).join("+")}`);
    return { commitSha: sha, treeSha: `t-${sha}` };
  }
  async createBotBranch(branch: string, sha: string) {
    this.refs.set(branch, sha);
    this.log.push(`create-branch:${branch}`);
  }
  async forceUpdateBotBranch(branch: string, sha: string) {
    this.refs.set(branch, sha);
    this.log.push(`force-update:${branch}`);
  }
  async branchCommits(branch: string) {
    const head = this.refs.get(branch);
    const c = head ? this.commits.get(head)! : null;
    return c
      ? [{ sha: head!, authorLogin: c.author, committerLogin: c.committer ?? c.author, verified: c.verified === true }]
      : [];
  }
  async findOpenPull(branch: string) {
    return this.pulls.find((p) => p.state === "open" && p.branch === branch) ?? null;
  }
  // An open PR's head follows its branch; a merged one keeps the head it was merged with.
  async getPull(n: number) {
    const pull = this.pulls.find((p) => p.number === n)!;
    return { ...pull, headSha: pull.headSha ?? this.refs.get(pull.branch) ?? null };
  }
  merge(n: number) {
    const pull = this.pulls.find((p) => p.number === n)!;
    pull.state = "closed";
    pull.merged = true;
    pull.headSha = this.refs.get(pull.branch)!;
    this.refs.set("main", pull.headSha);
  }
  async createPull(args: { branch: string; title: string; body: string }) {
    const pull: FakePull = { number: 200 + this.pulls.length, url: `https://github.com/x/pull/${200 + this.pulls.length}`, state: "open", merged: false, headSha: null, ...args };
    this.pulls.push(pull);
    this.log.push(`create-pull:${args.branch}`);
    return pull;
  }
  async updatePull(n: number, args: { title: string; body: string }) {
    const pull = this.pulls.find((p) => p.number === n)!;
    Object.assign(pull, args);
    this.log.push(`update-pull:${pull.branch}`);
    return pull;
  }
  async closePull(n: number) {
    const pull = this.pulls.find((p) => p.number === n)!;
    pull.state = "closed";
    this.log.push(`close-pull:${pull.branch}`);
  }
  head(branch: string): FakeCommit {
    return this.commits.get(this.refs.get(branch)!)!;
  }
}

function request(uid: string): CallableRequest<unknown> {
  return { auth: { uid, token: { admin: true } }, data: {} } as unknown as CallableRequest<unknown>;
}

function world() {
  const store = new FakeFirestore({ now: admin.firestore.Timestamp.fromDate(NOW) });
  store.seed(`admins/${ADMIN}`, { addedAt: 1 });
  const repo = new FakeRepo();
  let run = 0;
  const deps = {
    db: store.db,
    rateLimit: async () => undefined,
    connect: async () => repo,
    now: () => NOW,
    runId: () => `run-${++run}`,
  };
  const call = () => handleCreateIngredientChangePr(request(ADMIN), deps) as Promise<IngredientChangePrResult>;
  return { store, repo, call };
}

let seq = 0;
function seedWords(store: FakeFirestore, id: string, listKey: string, oldWords: string[], newWords: string[], extra: Record<string, unknown> = {}) {
  store.seed(`${COL}/${id}`, {
    kind: "occasionList", listKey, oldWords, newWords, status: "pending", createdBy: ADMIN, note: "privat anteckning",
    createdAt: admin.firestore.Timestamp.fromMillis(NOW.getTime() - DAY + ++seq), ...extra,
  });
}

function seedIngredient(store: FakeFirestore, id: string, next: string) {
  store.seed(`${COL}/${id}`, {
    ingredientId: ING, changes: { notes_sv: { old: ING_NOTES, new: next } }, status: "pending", createdBy: ADMIN,
    createdAt: admin.firestore.Timestamp.fromMillis(NOW.getTime() - DAY + ++seq),
  });
}

const status = (store: FakeFirestore, id: string) => store.read(`${COL}/${id}`)?.status;

const cases: UnitCase[] = [
  {
    name: "with no word-list proposal and no word-list branch, the word-list part makes no GitHub call",
    fn: async () => {
      const w = world();
      seedIngredient(w.store, "i1", "Ny anteckning.");
      const r = await w.call();
      assert(w.repo.log.every((l) => !l.includes(OCCASION_BOT_BRANCH)), w.repo.log.join());
      assertEqual(r.occasion?.prNumber ?? null, null, "no word-list PR");
      assertEqual(r.occasionError, null, "no error");
      assertEqual(status(w.store, "i1"), "inReview", "ingredient PR still built");
    },
  },
  {
    name: "word-list proposals get their own branch and PR, both files in one commit, separate from the ingredient PR",
    fn: async () => {
      const w = world();
      seedIngredient(w.store, "i1", "Ny anteckning.");
      seedWords(w.store, "o1", TITLE, TITLE_NOW, [...TITLE_NOW, "skinka"]);
      const r = await w.call();
      assertEqual(
        w.repo.log.join(","),
        [
          "commit:Butlery_Ingredients_INGREDIENTS.csv", `create-branch:${INGREDIENT_BOT_BRANCH}`, `create-pull:${INGREDIENT_BOT_BRANCH}`,
          "commit:occasions.json+occasion_vocabulary.g.dart", `create-branch:${OCCASION_BOT_BRANCH}`, `create-pull:${OCCASION_BOT_BRANCH}`,
        ].join(","),
        "calls",
      );
      const head = w.repo.head(OCCASION_BOT_BRANCH);
      assertEqual(head.files[CSV_PATH], CSV, "the word-list commit leaves the CSV alone");
      assert(head.files[OCCASIONS_PATH].includes('"skinka"'), "json");
      assert(head.files[VOCABULARY_PATH].includes("'skinka'"), "dart");
      assertEqual(w.repo.head(INGREDIENT_BOT_BRANCH).files[OCCASIONS_PATH], JSON_TEXT, "ingredient PR has no words");
      assertEqual(r.occasion?.applied, 1, "count");
      assertEqual(status(w.store, "o1"), "inReview", "status");
      assertEqual(w.store.read(`${COL}/o1`)?.prNumber, r.occasion?.prNumber, "pr number");
      assert(r.prNumber !== r.occasion?.prNumber, "two PRs");
      const pull = w.repo.pulls.find((p) => p.branch === OCCASION_BOT_BRANCH)!;
      assert(!pull.body.includes(ADMIN) && !pull.body.includes("privat anteckning"), "no uid or note in the PR");
    },
  },
  {
    name: "a conflict keeps main's words on the proposal; a rejected one gets a reason and a year's expiry",
    fn: async () => {
      const w = world();
      seedWords(w.store, "c1", TITLE, ["fel"], ["x"]);
      seedWords(w.store, "r1", "christmas.tag", ["jul"], ["påsk"]);
      await w.call();
      assertEqual(status(w.store, "c1"), "conflict", "conflict");
      assertEqual(JSON.stringify(w.store.read(`${COL}/c1`)?.csvValue), JSON.stringify({ [TITLE]: TITLE_NOW }), "main's words");
      assertEqual(status(w.store, "r1"), "rejected", "rejected");
      assertEqual(w.store.read(`${COL}/r1`)?.reason, "unknown-list", "reason");
      const exp = (w.store.read(`${COL}/r1`)?.expireAt as admin.firestore.Timestamp).toMillis() - NOW.getTime();
      assertEqual(exp, 365 * DAY, "expiry");
      assert(!w.repo.refs.has(OCCASION_BOT_BRANCH), "no branch for nothing applied");
    },
  },
  {
    name: "a merged word-list PR marks its proposals applied; a closed one hands them back to pending",
    fn: async () => {
      const w = world();
      seedWords(w.store, "m1", TITLE, TITLE_NOW, ["a"]);
      const first = await w.call();
      w.repo.merge(first.occasion!.prNumber!);
      const second = await w.call();
      assertEqual(status(w.store, "m1"), "applied", "applied after merge");
      assert(w.store.read(`${COL}/m1`)?.appliedAt !== undefined, "appliedAt");
      assertEqual(second.occasion?.merged, 1, "merged count");

      seedWords(w.store, "k1", TITLE, ["a"], ["b"]);
      const third = await w.call();
      w.repo.pulls.find((p) => p.number === third.occasion?.prNumber)!.state = "closed";
      seedWords(w.store, "k2", "lucia.titleWords", ["nej"], ["x"]);
      const fourth = await w.call();
      assertEqual(fourth.occasion?.reopened, 1, "reopened");
      assertEqual(status(w.store, "k1"), "inReview", "back in a new PR");
      assert(fourth.occasion?.prNumber !== third.occasion?.prNumber, "new PR");
    },
  },
  {
    name: "a proposal left out of the branch whose PR is then merged goes back to the queue, not to applied",
    fn: async () => {
      const w = world();
      seedWords(w.store, "s1", TITLE, TITLE_NOW, [...TITLE_NOW, "skinka"]);
      const first = await w.call();
      const stamped = w.store.read(`${COL}/s1`)?.prHeadSha;
      assertEqual(stamped, w.repo.refs.get(OCCASION_BOT_BRANCH), "stamped with the pushed head");
      // The branch moves on without s1 and its status write never lands.
      seedWords(w.store, "s2", "lucia.titleWords", readList(parseOccasions(JSON_TEXT), "lucia.titleWords")!, ["lucia"]);
      w.store.seed(`${COL}/s1`, { ...w.store.read(`${COL}/s1`), status: "withdrawn" });
      await w.call();
      w.store.seed(`${COL}/s1`, { ...w.store.read(`${COL}/s1`), status: "inReview" });
      w.repo.merge(first.occasion!.prNumber!);
      const third = await w.call();
      assertEqual(third.occasion?.merged, 1, "only s2 merged");
      assertEqual(status(w.store, "s2"), "applied", "s2 applied");
      assert(status(w.store, "s1") !== "applied", `s1 is ${status(w.store, "s1")}`);
      assertEqual(status(w.store, "s1"), "inReview", "s1 back in a new PR");
      assert(w.repo.head(OCCASION_BOT_BRANCH).files[OCCASIONS_PATH].includes('"skinka"'), "s1's words rebuilt");
    },
  },
  {
    name: "when every word-list proposal is withdrawn the open word-list PR is closed",
    fn: async () => {
      const w = world();
      seedWords(w.store, "w1", TITLE, TITLE_NOW, ["a"]);
      const r = await w.call();
      w.store.seed(`${COL}/w1`, { ...w.store.read(`${COL}/w1`), status: "withdrawn" });
      await w.call();
      assertEqual(w.repo.pulls.find((p) => p.number === r.occasion?.prNumber)?.state, "closed", "closed");
    },
  },
  {
    name: "a failing word-list part never stops the ingredient PR, and reports its error code",
    fn: async () => {
      const w = world();
      seedIngredient(w.store, "i1", "Ny anteckning.");
      seedWords(w.store, "o1", TITLE, TITLE_NOW, ["a"]);
      w.repo.failOn = `getFile:${OCCASIONS_PATH}`;
      const r = await w.call();
      assertEqual(status(w.store, "i1"), "inReview", "ingredient PR built");
      assertEqual(r.occasion, null, "no word-list result");
      assertEqual(r.occasionError, "internal-error", "error code");
      assertEqual(status(w.store, "o1"), "pending", "word-list proposal untouched");
    },
  },
  {
    name: "a failing ingredient part still records the word-list result on the failed run",
    fn: async () => {
      const w = world();
      seedIngredient(w.store, "i1", "Ny anteckning.");
      seedWords(w.store, "o1", TITLE, TITLE_NOW, ["a"]);
      w.repo.failOn = `getFile:${CSV_PATH}`;
      let code = "";
      await w.call().catch((err: { message: string }) => { code = err.message; });
      assertEqual(code, "internal-error", "ingredient failure surfaces");
      assertEqual(status(w.store, "o1"), "inReview", "word-list PR built");
      const run = w.store.childPaths("ingredient_change_runs").map((p) => w.store.read(p)!)[0];
      assertEqual(run.outcome, "failed", "outcome");
      assert(typeof run.occasionPrNumber === "number", JSON.stringify(run));
      assertEqual((run.occasionCounts as { applied: number }).applied, 1, "word-list counts");
    },
  },
  {
    name: "word-list proposals that fill the shared read make the ingredient part refuse, not truncate",
    fn: async () => {
      const w = world();
      for (let i = 0; i < 701; i++) seedWords(w.store, `f${i}`, TITLE, TITLE_NOW, [`w${i}`]);
      let code = "";
      await w.call().catch((err: { message: string }) => { code = err.message; });
      assertEqual(code, "too-many-proposals", "refused");
    },
  },
  {
    name: "word-list proposals do not count toward the ingredient cap",
    fn: async () => {
      const w = world();
      for (let i = 0; i < 200; i++) seedWords(w.store, `f${i}`, TITLE, TITLE_NOW, [`w${i}`]);
      for (let i = 0; i < 301; i++) seedIngredient(w.store, `i${i}`, `Anteckning ${i}.`);
      const r = await w.call();
      assert(r.prNumber !== null, "ingredient PR built with room left for word lists");
      assertEqual(r.occasionError, null, "word-list part ran");
    },
  },
  {
    name: "a drifted generated file stops the word-list part with its own code",
    fn: async () => {
      const w = world();
      w.repo.commits.get("m0")!.files[VOCABULARY_PATH] = DART_TEXT.replace("'julienne'", "'x'");
      seedWords(w.store, "o1", TITLE, TITLE_NOW, ["a"]);
      const r = await w.call();
      assertEqual(r.occasionError, "occasion-dart-drift", "code");
      assertEqual(status(w.store, "o1"), "pending", "untouched");
    },
  },
  {
    name: "the ingredient sync's applied step leaves word-list proposals alone",
    fn: async () => {
      const w = world();
      seedWords(w.store, "o1", TITLE, TITLE_NOW, ["a"], { status: "inReview", prNumber: 5 });
      const counts = await markAppliedProposals(w.store.db, NOW);
      assertEqual(counts.inReview, 0, "not counted");
      assertEqual(status(w.store, "o1"), "inReview", "untouched");
    },
  },
];

void runTests("occasion-change-pr (admin-vy D)", cases);
