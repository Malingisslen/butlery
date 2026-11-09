/**
 * What the admin-vy's two rolling PRs share: the ingredient CSV PR on
 * `bot/ingredient-changes` (step C) and the word-list PR on
 * `bot/occasion-changes` (step D). Each PR has its own branch, so a red or
 * unmerged one never holds the other back.
 *
 * - The bot branch is rebuilt from main's current commit, and refused when
 *   it carries a commit the App did not make.
 * - Proposal status writes re-read each proposal and leave alone one whose
 *   status moved meanwhile (a withdrawal).
 */

import { HttpsError } from "firebase-functions/v2/https";
import * as admin from "firebase-admin";
import { Collections } from "../shared/collections";
import { BASE_BRANCH, BranchCommit, CommitFileSpec, GitHubError, PullRequest, RepoClient } from "./github-app";

const STATUS_CHUNK = 100;
const DAY_MS = 24 * 60 * 60 * 1000;
// A proposal in review or in conflict, refreshed at each rebuild.
export const REVIEW_RETENTION_MS = 90 * DAY_MS;
export const REJECTED_RETENTION_MS = 365 * DAY_MS;

// A commit the App makes through the API is authored by the App and
// committed by GitHub's `web-flow`, which signs it; only that signature tells
// it apart from a commit someone else pushed with the App named as author.
export const GITHUB_WEB_FLOW_LOGIN = "web-flow";

export function isAppCommit(c: BranchCommit, botLogin: string): boolean {
  if (c.authorLogin !== botLogin) return false;
  return (c.committerLogin === botLogin || c.committerLogin === GITHUB_WEB_FLOW_LOGIN) && c.verified;
}

export function refused(code: string): HttpsError {
  return new HttpsError("aborted", code);
}

export type PullState = "open" | "merged" | "closed";

/** Writes [data] on each doc whose status is still [expected]; returns how many were left alone. */
export async function writeIfStatus(
  db: admin.firestore.Firestore,
  writes: Array<{ id: string; expected: string; data: Record<string, unknown> }>,
): Promise<number> {
  let skipped = 0;
  const col = db.collection(Collections.ingredientChangeRequests);
  for (let i = 0; i < writes.length; i += STATUS_CHUNK) {
    const chunk = writes.slice(i, i + STATUS_CHUNK);
    skipped += await db.runTransaction(async (tx) => {
      const snaps = await Promise.all(chunk.map((w) => tx.get(col.doc(w.id))));
      let left = 0;
      chunk.forEach((w, j) => {
        if (snaps[j].exists && snaps[j].get("status") === w.expected) tx.update(col.doc(w.id), w.data);
        else left++;
      });
      return left;
    });
  }
  return skipped;
}

export const pullState = (pull: PullRequest): PullState =>
  pull.state === "open" ? "open" : pull.merged ? "merged" : "closed";

/** Every PR the given `inReview` proposals name, by number. */
export async function namedPulls(
  github: RepoClient,
  inReview: readonly admin.firestore.QueryDocumentSnapshot[],
): Promise<Map<number, PullRequest>> {
  const pulls = new Map<number, PullRequest>();
  const numbers = new Set(inReview.map((d) => d.get("prNumber")).filter((n): n is number => typeof n === "number"));
  for (const n of numbers) pulls.set(n, await github.getPull(n));
  return pulls;
}

/** The state of every PR the given `inReview` proposals name. */
export async function pullStates(
  github: RepoClient,
  inReview: readonly admin.firestore.QueryDocumentSnapshot[],
): Promise<Map<number, PullState>> {
  const pulls = await namedPulls(github, inReview);
  return new Map([...pulls].map(([n, pull]) => [n, pullState(pull)]));
}

export interface BotBranchState {
  mainSha: string;
  botSha: string | null;
  openPull: PullRequest | null;
}

/** Reads main, the bot branch and its open PR; refuses a branch with foreign commits. */
export async function readBotBranch(github: RepoClient, branch: string): Promise<BotBranchState> {
  const mainSha = await github.getRefSha(BASE_BRANCH);
  if (!mainSha) throw new GitHubError("no-main", null, "main has no ref");
  const botSha = await github.getRefSha(branch);
  if (botSha) {
    const foreign = (await github.branchCommits(branch)).some((c) => !isAppCommit(c, github.botLogin));
    if (foreign) throw refused("foreign-commits");
  }
  const openPull = await github.findOpenPull(branch);
  return { mainSha, botSha, openPull };
}

export interface PublishArgs {
  branch: string;
  state: BotBranchState;
  mainTreeSha: string;
  files: CommitFileSpec[];
  title: string;
  body: string;
  message: string;
}

/** True when the bot branch already is main plus exactly these files. */
async function branchHolds(github: RepoClient, botSha: string, mainSha: string, files: CommitFileSpec[]): Promise<boolean> {
  const bot = await github.getCommitTree(botSha);
  if (bot.parents.length !== 1 || bot.parents[0] !== mainSha) return false;
  for (const f of files) {
    if ((await github.getFile(f.path, botSha)).text !== f.text) return false;
  }
  return true;
}

/**
 * Points the bot branch at one commit on top of main that writes [files],
 * then opens or updates the branch's PR. The returned `headSha` is the commit
 * the branch was left on.
 */
export async function publishBotPull(github: RepoClient, args: PublishArgs): Promise<PullRequest> {
  const { branch, state, files } = args;
  const upToDate = state.botSha !== null && await branchHolds(github, state.botSha, state.mainSha, files);
  let headSha = state.botSha;
  if (!upToDate) {
    const commit = files.length === 1
      ? await github.commitFile({
        parent: state.mainSha, baseTree: args.mainTreeSha, path: files[0].path, text: files[0].text, message: args.message,
      })
      : await github.commitFiles({ parent: state.mainSha, baseTree: args.mainTreeSha, files, message: args.message });
    // GitHub's ref update has no compare-and-swap, so check right before it.
    if (await github.getRefSha(BASE_BRANCH) !== state.mainSha) throw refused("main-moved");
    if (await github.getRefSha(branch) !== state.botSha) throw refused("branch-moved");
    if (state.openPull && (await github.getPull(state.openPull.number)).merged) throw refused("pr-merged");
    if (state.botSha) await github.forceUpdateBotBranch(branch, commit.commitSha);
    else await github.createBotBranch(branch, commit.commitSha);
    headSha = commit.commitSha;
  }
  const pull = state.openPull
    ? await github.updatePull(state.openPull.number, { title: args.title, body: args.body })
    : await github.createPull({ branch, title: args.title, body: args.body });
  if (state.openPull && pull.merged) throw refused("pr-merged-during-rebuild");
  return { ...pull, headSha };
}
