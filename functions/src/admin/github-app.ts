/**
 * The admin-vy's GitHub client: an installation token from the "Butlery
 * admin-bot" GitHub App, and the handful of REST calls that rebuild a bot
 * branch and its pull request.
 *
 * The token is minted per run, scoped to this one repository and to
 * contents:write + pull_requests:write, and lives only in this module's
 * closures. It is never logged, returned or persisted, and every error this
 * module throws carries a method, a path template and an HTTP status only:
 * a response body or a fetch error message could echo a credential.
 */

import * as crypto from "crypto";

export const GITHUB_OWNER = "Malingisslen";
export const GITHUB_REPO = "butlery";
export const BASE_BRANCH = "main";
export const INGREDIENT_BOT_BRANCH = "bot/ingredient-changes";
export const OCCASION_BOT_BRANCH = "bot/occasion-changes";
const BOT_BRANCHES: readonly string[] = [INGREDIENT_BOT_BRANCH, OCCASION_BOT_BRANCH];

// The "Butlery admin-bot" App, installed on this repository only. None of
// these is a secret; the private key is (GITHUB_APP_PRIVATE_KEY).
export const GITHUB_APP_ID = "5602114";
export const GITHUB_APP_INSTALLATION_ID = 178342690;
export const GITHUB_APP_BOT_LOGIN = "butlery-admin-bot[bot]";

const API = "https://api.github.com";
const TOKEN_PERMISSIONS = { contents: "write", pull_requests: "write" } as const;
// `metadata: read` comes with every installation token.
const ALLOWED_GRANTED_PERMISSIONS = new Set(["contents", "pull_requests", "metadata"]);

export type FetchLike = (url: string, init: {
  method: string;
  headers: Record<string, string>;
  body?: string;
}) => Promise<{ status: number; json(): Promise<unknown> }>;

export class GitHubError extends Error {
  constructor(readonly code: string, readonly status: number | null, message: string) {
    super(message);
    this.name = "GitHubError";
  }
}

function base64url(input: Buffer | string): string {
  return Buffer.from(input).toString("base64").replace(/=+$/, "").replace(/\+/g, "-").replace(/\//g, "_");
}

/** Secret Manager values pasted through a shell often carry literal "\n". */
export function normalizePrivateKey(raw: string): string {
  return raw.includes("\\n") ? raw.replace(/\\n/g, "\n") : raw;
}

/** RS256 app JWT: issued 60 s in the past against clock skew, valid 9 minutes. */
export function createAppJwt(appId: string, privateKeyPem: string, nowMs: number): string {
  const now = Math.floor(nowMs / 1000);
  const header = base64url(JSON.stringify({ alg: "RS256", typ: "JWT" }));
  const payload = base64url(JSON.stringify({ iat: now - 60, exp: now + 540, iss: appId }));
  const signer = crypto.createSign("RSA-SHA256");
  signer.update(`${header}.${payload}`);
  let signature: Buffer;
  try {
    signature = signer.sign(normalizePrivateKey(privateKeyPem));
  } catch {
    throw new GitHubError("bad-private-key", null, "The GitHub App private key could not sign");
  }
  return `${header}.${payload}.${base64url(signature)}`;
}

export function assertBotBranch(branch: string): void {
  if (!BOT_BRANCHES.includes(branch)) {
    throw new GitHubError("not-bot-branch", null, "Refusing to force-update a branch other than a bot branch");
  }
}

interface Call {
  method: string;
  // A template for errors ("/git/refs/heads/{branch}"); the real path never
  // reaches a message.
  label: string;
  path: string;
  body?: unknown;
  // Statuses answered as `null` instead of thrown.
  allow?: number[];
}

async function call(
  fetchFn: FetchLike,
  credential: string,
  c: Call,
): Promise<{ status: number; data: Record<string, unknown> } | null> {
  let res: { status: number; json(): Promise<unknown> };
  try {
    res = await fetchFn(`${API}${c.path}`, {
      method: c.method,
      headers: {
        Accept: "application/vnd.github+json",
        Authorization: `Bearer ${credential}`,
        "X-GitHub-Api-Version": "2022-11-28",
        "User-Agent": "butlery-admin-bot",
        ...(c.body === undefined ? {} : { "Content-Type": "application/json" }),
      },
      body: c.body === undefined ? undefined : JSON.stringify(c.body),
    });
  } catch (err) {
    const name = err instanceof Error ? err.name : typeof err;
    throw new GitHubError("network", null, `${c.method} ${c.label} failed (${name})`);
  }
  if (c.allow?.includes(res.status)) return null;
  if (res.status < 200 || res.status >= 300) {
    throw new GitHubError("http", res.status, `${c.method} ${c.label} returned ${res.status}`);
  }
  let data: unknown = {};
  if (res.status !== 204) {
    try {
      data = await res.json();
    } catch {
      throw new GitHubError("bad-json", res.status, `${c.method} ${c.label} returned unreadable JSON`);
    }
  }
  return { status: res.status, data: (data ?? {}) as Record<string, unknown> };
}

function str(v: unknown, what: string): string {
  if (typeof v !== "string" || v === "") throw new GitHubError("bad-response", null, `Missing ${what}`);
  return v;
}

const repoPath = `/repos/${GITHUB_OWNER}/${GITHUB_REPO}`;

export interface BranchCommit {
  sha: string;
  authorLogin: string | null;
  committerLogin: string | null;
  // GitHub's own signature check on the commit (`commit.verification.verified`).
  verified: boolean;
}

export interface PullRequest {
  number: number;
  url: string;
  state: "open" | "closed";
  merged: boolean;
  // The PR's head commit; for a merged PR, the commit that was merged.
  headSha: string | null;
}

function toPull(d: Record<string, unknown>): PullRequest {
  if (typeof d.number !== "number") throw new GitHubError("bad-response", null, "Missing pull number");
  return {
    number: d.number,
    url: str(d.html_url, "pull url"),
    state: d.state === "open" ? "open" : "closed",
    merged: typeof d.merged_at === "string" && d.merged_at !== "",
    headSha: typeof (d.head as { sha?: unknown } | undefined)?.sha === "string" ? (d.head as { sha: string }).sha : null,
  };
}

export interface CommitFileSpec {
  path: string;
  text: string;
}

export interface RepoClient {
  /** The login the App's commits carry. */
  botLogin: string;
  getRefSha(branch: string): Promise<string | null>;
  getCommitTree(sha: string): Promise<{ treeSha: string; parents: string[] }>;
  getFile(path: string, ref: string): Promise<{ text: string; blobSha: string }>;
  commitFile(args: { parent: string; baseTree: string; path: string; text: string; message: string }):
    Promise<{ commitSha: string; treeSha: string }>;
  /** One commit that writes every file in [files]. */
  commitFiles(args: { parent: string; baseTree: string; files: CommitFileSpec[]; message: string }):
    Promise<{ commitSha: string; treeSha: string }>;
  createBotBranch(branch: string, sha: string): Promise<void>;
  forceUpdateBotBranch(branch: string, sha: string): Promise<void>;
  branchCommits(branch: string): Promise<BranchCommit[]>;
  findOpenPull(branch: string): Promise<PullRequest | null>;
  getPull(n: number): Promise<PullRequest>;
  createPull(args: { branch: string; title: string; body: string }): Promise<PullRequest>;
  updatePull(n: number, args: { title: string; body: string }): Promise<PullRequest>;
  closePull(n: number): Promise<void>;
}

/** Mints the installation token and returns a client bound to it. */
export async function connectRepo(deps: {
  fetch: FetchLike;
  privateKey: string;
  appId?: string;
  installationId?: number;
  now?: () => number;
}): Promise<RepoClient> {
  if (!deps.privateKey) throw new GitHubError("not-configured", null, "GitHub App private key is not set");
  const appId = deps.appId ?? GITHUB_APP_ID;
  const installationId = deps.installationId ?? GITHUB_APP_INSTALLATION_ID;
  const jwt = createAppJwt(appId, deps.privateKey, (deps.now ?? Date.now)());
  const f = deps.fetch;

  const minted = await call(f, jwt, {
    method: "POST",
    label: "/app/installations/{id}/access_tokens",
    path: `/app/installations/${installationId}/access_tokens`,
    body: { repositories: [GITHUB_REPO], permissions: TOKEN_PERMISSIONS },
  });
  const token = str(minted?.data.token, "installation token");
  const granted = Object.keys((minted?.data.permissions ?? {}) as Record<string, unknown>);
  if (granted.some((p) => !ALLOWED_GRANTED_PERMISSIONS.has(p))) {
    throw new GitHubError("over-privileged", null, "The installation token carries more than contents and pull requests");
  }

  const api = (c: Call) => call(f, token, c);

  async function commitFiles(args: { parent: string; baseTree: string; files: CommitFileSpec[]; message: string }) {
    if (args.files.length === 0) throw new GitHubError("empty-commit", null, "A commit needs at least one file");
    const entries = [];
    for (const file of args.files) {
      const blob = await api({
        method: "POST", label: "/git/blobs", path: `${repoPath}/git/blobs`,
        body: { content: Buffer.from(file.text, "utf8").toString("base64"), encoding: "base64" },
      });
      entries.push({ path: file.path, mode: "100644", type: "blob", sha: str(blob?.data.sha, "blob sha") });
    }
    const tree = await api({
      method: "POST", label: "/git/trees", path: `${repoPath}/git/trees`,
      body: { base_tree: args.baseTree, tree: entries },
    });
    const treeSha = str(tree?.data.sha, "tree sha");
    // No author or committer: GitHub stamps the App's own bot identity.
    const commit = await api({
      method: "POST", label: "/git/commits", path: `${repoPath}/git/commits`,
      body: { message: args.message, tree: treeSha, parents: [args.parent] },
    });
    return { commitSha: str(commit?.data.sha, "commit sha"), treeSha };
  }

  return {
    botLogin: GITHUB_APP_BOT_LOGIN,

    async getRefSha(branch) {
      const r = await api({
        method: "GET", label: "/git/ref/heads/{branch}",
        path: `${repoPath}/git/ref/heads/${branch}`, allow: [404],
      });
      if (!r) return null;
      return str((r.data.object as Record<string, unknown> | undefined)?.sha, "ref sha");
    },

    async getCommitTree(sha) {
      const r = await api({ method: "GET", label: "/git/commits/{sha}", path: `${repoPath}/git/commits/${sha}` });
      const tree = r?.data.tree as Record<string, unknown> | undefined;
      const parents = (r?.data.parents as Array<Record<string, unknown>> | undefined) ?? [];
      return { treeSha: str(tree?.sha, "tree sha"), parents: parents.map((p) => str(p.sha, "parent sha")) };
    },

    async getFile(path, ref) {
      const r = await api({
        method: "GET", label: "/contents/{path}",
        path: `${repoPath}/contents/${path}?ref=${encodeURIComponent(ref)}`,
      });
      const blobSha = str(r?.data.sha, "blob sha");
      let b64 = typeof r?.data.content === "string" ? r.data.content : "";
      // The contents API leaves `content` empty above 1 MB; the blob API does not.
      if (!b64) {
        const blob = await api({ method: "GET", label: "/git/blobs/{sha}", path: `${repoPath}/git/blobs/${blobSha}` });
        b64 = str(blob?.data.content, "blob content");
      }
      return { text: Buffer.from(b64.replace(/\n/g, ""), "base64").toString("utf8"), blobSha };
    },

    async commitFile({ parent, baseTree, path, text, message }) {
      return commitFiles({ parent, baseTree, files: [{ path, text }], message });
    },

    commitFiles,

    async createBotBranch(branch, sha) {
      assertBotBranch(branch);
      await api({
        method: "POST", label: "/git/refs", path: `${repoPath}/git/refs`,
        body: { ref: `refs/heads/${branch}`, sha },
      });
    },

    async forceUpdateBotBranch(branch, sha) {
      assertBotBranch(branch);
      await api({
        method: "PATCH", label: "/git/refs/heads/{branch}",
        path: `${repoPath}/git/refs/heads/${branch}`, body: { sha, force: true },
      });
    },

    async branchCommits(branch) {
      const r = await api({
        method: "GET", label: "/compare/{base}...{head}",
        path: `${repoPath}/compare/${BASE_BRANCH}...${encodeURIComponent(branch)}`,
      });
      const commits = (r?.data.commits as Array<Record<string, unknown>> | undefined) ?? [];
      const login = (u: unknown): string | null =>
        typeof (u as Record<string, unknown> | null)?.login === "string"
          ? ((u as Record<string, unknown>).login as string)
          : null;
      return commits.map((c) => {
        const verification = (c.commit as Record<string, unknown> | undefined)?.verification as
          Record<string, unknown> | undefined;
        return {
          sha: str(c.sha, "commit sha"),
          authorLogin: login(c.author),
          committerLogin: login(c.committer),
          verified: verification?.verified === true,
        };
      });
    },

    async findOpenPull(branch) {
      const r = await api({
        method: "GET", label: "/pulls?head={branch}",
        path: `${repoPath}/pulls?state=open&base=${BASE_BRANCH}&head=${encodeURIComponent(`${GITHUB_OWNER}:${branch}`)}`,
      });
      const list = Array.isArray(r?.data) ? (r?.data as unknown as Array<Record<string, unknown>>) : [];
      return list.length ? toPull(list[0]) : null;
    },

    async getPull(n) {
      const r = await api({ method: "GET", label: "/pulls/{n}", path: `${repoPath}/pulls/${n}` });
      return toPull(r?.data ?? {});
    },

    async createPull({ branch, title, body }) {
      const r = await api({
        method: "POST", label: "/pulls", path: `${repoPath}/pulls`,
        body: { title, body, head: branch, base: BASE_BRANCH, draft: false },
      });
      return toPull(r?.data ?? {});
    },

    async updatePull(n, { title, body }) {
      const r = await api({ method: "PATCH", label: "/pulls/{n}", path: `${repoPath}/pulls/${n}`, body: { title, body } });
      return toPull(r?.data ?? {});
    },

    async closePull(n) {
      await api({ method: "PATCH", label: "/pulls/{n}", path: `${repoPath}/pulls/${n}`, body: { state: "closed" } });
    },
  };
}
