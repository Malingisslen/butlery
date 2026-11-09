/**
 * The admin-vy GitHub client: the App JWT, the scoped installation token,
 * the bot-branch guard, and errors that never carry a credential.
 *
 * Run with: npx ts-node src/__tests__/github-app.test.ts
 */

import * as crypto from "crypto";
import {
  connectRepo,
  createAppJwt,
  FetchLike,
  GITHUB_APP_BOT_LOGIN,
  GITHUB_APP_ID,
  GITHUB_APP_INSTALLATION_ID,
  GitHubError,
  INGREDIENT_BOT_BRANCH,
  normalizePrivateKey,
} from "../admin/github-app";
import { assertEqual, runTests, UnitCase } from "./_unit-runner";

const { privateKey, publicKey } = crypto.generateKeyPairSync("rsa", { modulusLength: 2048 });
const PEM = privateKey.export({ type: "pkcs1", format: "pem" }).toString();
const TOKEN = "ghs_SECRET_installation_token_value";
const NOW = Date.UTC(2026, 10, 3, 12, 0, 0);

function assert(cond: boolean, msg: string): void {
  if (!cond) throw new Error(msg);
}

interface Recorded {
  url: string;
  method: string;
  headers: Record<string, string>;
  body?: unknown;
}

type Responder = (r: Recorded) => { status: number; body?: unknown } | Promise<never>;

function fakeFetch(respond: Responder, calls: Recorded[] = []): FetchLike {
  return async (url, init) => {
    const r: Recorded = {
      url, method: init.method, headers: init.headers,
      body: init.body === undefined ? undefined : JSON.parse(init.body),
    };
    calls.push(r);
    const out = await respond(r);
    return { status: out.status, json: async () => out.body ?? {} };
  };
}

function tokenOk(r: Recorded): { status: number; body?: unknown } | null {
  if (r.url.endsWith(`/app/installations/${GITHUB_APP_INSTALLATION_ID}/access_tokens`)) {
    return { status: 201, body: { token: TOKEN, permissions: { contents: "write", pull_requests: "write", metadata: "read" } } };
  }
  return null;
}

async function errorOf(fn: () => Promise<unknown>): Promise<Error> {
  try {
    await fn();
  } catch (err) {
    return err as Error;
  }
  throw new Error("expected a throw");
}

const cases: UnitCase[] = [
  {
    name: "the app JWT is RS256, issued 60 s back, valid under 10 minutes, issued by the App id, and verifies",
    fn: () => {
      const jwt = createAppJwt(GITHUB_APP_ID, PEM, NOW);
      const [h, p, s] = jwt.split(".");
      const header = JSON.parse(Buffer.from(h, "base64url").toString());
      const payload = JSON.parse(Buffer.from(p, "base64url").toString());
      assertEqual(header.alg, "RS256", "alg");
      assertEqual(payload.iat, NOW / 1000 - 60, "iat");
      assert(payload.exp - NOW / 1000 <= 600 && payload.exp > NOW / 1000, `exp ${payload.exp}`);
      assertEqual(payload.iss, "5602114", "iss");
      const ok = crypto.createVerify("RSA-SHA256").update(`${h}.${p}`).verify(publicKey, Buffer.from(s, "base64url"));
      assert(ok, "signature verifies with the public key");
    },
  },
  {
    name: "a key pasted with literal \\n escapes still signs",
    fn: () => {
      const escaped = PEM.replace(/\n/g, "\\n");
      assertEqual(normalizePrivateKey(escaped), PEM, "normalised");
      createAppJwt(GITHUB_APP_ID, escaped, NOW);
    },
  },
  {
    name: "the token is requested for this repository only, with contents and pull_requests write",
    fn: async () => {
      const calls: Recorded[] = [];
      const repo = await connectRepo({ fetch: fakeFetch((r) => tokenOk(r) ?? { status: 500 }, calls), privateKey: PEM, now: () => NOW });
      assertEqual(calls.length, 1, "one call");
      assertEqual(calls[0].method, "POST", "method");
      assertEqual(JSON.stringify(calls[0].body), '{"repositories":["butlery"],"permissions":{"contents":"write","pull_requests":"write"}}', "body");
      assert(calls[0].headers.Authorization.startsWith("Bearer ey"), "JWT bearer");
      assertEqual(repo.botLogin, GITHUB_APP_BOT_LOGIN, "bot login");
    },
  },
  {
    name: "later calls use the installation token, not the JWT",
    fn: async () => {
      const calls: Recorded[] = [];
      const repo = await connectRepo({
        fetch: fakeFetch((r) => tokenOk(r) ?? { status: 200, body: { object: { sha: "abc" } } }, calls),
        privateKey: PEM, now: () => NOW,
      });
      assertEqual(await repo.getRefSha("main"), "abc", "sha");
      assertEqual(calls[1].headers.Authorization, `Bearer ${TOKEN}`, "token bearer");
      assert(calls[1].url.endsWith("/repos/Malingisslen/butlery/git/ref/heads/main"), calls[1].url);
    },
  },
  {
    name: "a token granted more than contents and pull requests is refused",
    fn: async () => {
      const err = await errorOf(() => connectRepo({
        fetch: fakeFetch(() => ({ status: 201, body: { token: TOKEN, permissions: { contents: "write", workflows: "write" } } })),
        privateKey: PEM, now: () => NOW,
      }));
      assert(err instanceof GitHubError && err.code === "over-privileged", String(err));
    },
  },
  {
    name: "no key: refused before any request",
    fn: async () => {
      const calls: Recorded[] = [];
      const err = await errorOf(() => connectRepo({ fetch: fakeFetch(() => ({ status: 200 }), calls), privateKey: "" }));
      assert(err instanceof GitHubError && err.code === "not-configured", String(err));
      assertEqual(calls.length, 0, "no request");
    },
  },
  {
    name: "errors never carry the token: a failing fetch, a 401 echoing it",
    fn: async () => {
      const repo = await connectRepo({
        fetch: fakeFetch((r) => {
          const t = tokenOk(r);
          if (t) return t;
          if (r.url.includes("/git/ref/heads/main")) return Promise.reject(new Error(`socket hang up Bearer ${TOKEN}`));
          return { status: 401, body: { message: `Bad credentials ${TOKEN}`, documentation_url: r.headers.Authorization } };
        }),
        privateKey: PEM, now: () => NOW,
      });
      const network = await errorOf(() => repo.getRefSha("main"));
      const http = await errorOf(() => repo.getPull(3));
      for (const err of [network, http]) {
        assert(err instanceof GitHubError, `GitHubError: ${err}`);
        const text = `${err.message} ${err.stack} ${JSON.stringify(err)}`;
        assert(!text.includes(TOKEN) && !text.includes("ghs_"), `token leaked: ${text}`);
      }
      assertEqual((http as GitHubError).status, 401, "status kept");
      assert(http.message.includes("/pulls/{n}"), "path template, not the path");
    },
  },
  {
    name: "a bad private key fails without echoing it",
    fn: async () => {
      // A truncated copy of the generated key: PEM-shaped, unusable.
      const broken = PEM.slice(0, 60) + "FAKE_not_a_key" + PEM.slice(-40);
      const err = await errorOf(async () => createAppJwt(GITHUB_APP_ID, broken, NOW));
      assert(err instanceof GitHubError && err.code === "bad-private-key" && !err.message.includes("FAKE_not_a_key"), String(err));
    },
  },
  {
    name: "force update: only the bot branch, refused before any request otherwise, and sent with force",
    fn: async () => {
      const calls: Recorded[] = [];
      const repo = await connectRepo({ fetch: fakeFetch((r) => tokenOk(r) ?? { status: 200, body: {} }, calls), privateKey: PEM, now: () => NOW });
      for (const branch of ["main", "bot/ingredient-changes-x", "refs/heads/bot/ingredient-changes"]) {
        const err = await errorOf(() => repo.forceUpdateBotBranch(branch, "s"));
        assert(err instanceof GitHubError && err.code === "not-bot-branch", `${branch}: ${err}`);
        const err2 = await errorOf(() => repo.createBotBranch(branch, "s"));
        assert(err2 instanceof GitHubError && err2.code === "not-bot-branch", `${branch} create: ${err2}`);
      }
      assertEqual(calls.length, 1, "only the token call went out");
      await repo.forceUpdateBotBranch(INGREDIENT_BOT_BRANCH, "c1");
      const last = calls[calls.length - 1];
      assertEqual(last.method, "PATCH", "PATCH");
      assert(last.url.endsWith("/git/refs/heads/bot/ingredient-changes"), last.url);
      assertEqual(JSON.stringify(last.body), '{"sha":"c1","force":true}', "force body");
    },
  },
  {
    name: "a missing ref reads as null; a file above 1 MB is read through the blob API",
    fn: async () => {
      const text = "id,swedish\nx,ö\n";
      const repo = await connectRepo({
        fetch: fakeFetch((r) => {
          const t = tokenOk(r);
          if (t) return t;
          if (r.url.includes("/git/ref/")) return { status: 404 };
          if (r.url.includes("/contents/")) return { status: 200, body: { sha: "b1", content: "", encoding: "none" } };
          if (r.url.endsWith("/git/blobs/b1")) {
            return { status: 200, body: { content: Buffer.from(text).toString("base64").replace(/(.{8})/g, "$1\n") } };
          }
          return { status: 500 };
        }),
        privateKey: PEM, now: () => NOW,
      });
      assertEqual(await repo.getRefSha(INGREDIENT_BOT_BRANCH), null, "404 → null");
      const file = await repo.getFile("a.csv", "main");
      assertEqual(file.text, text, "decoded via blob");
      assertEqual(file.blobSha, "b1", "blob sha");
    },
  },
  {
    name: "a commit is created with no author, so GitHub stamps the App",
    fn: async () => {
      const calls: Recorded[] = [];
      const repo = await connectRepo({
        fetch: fakeFetch((r) => tokenOk(r) ?? { status: 201, body: { sha: `s${calls.length}` } }, calls),
        privateKey: PEM, now: () => NOW,
      });
      await repo.commitFile({ parent: "p", baseTree: "t", path: "a.csv", text: "x", message: "m" });
      const commit = calls.find((c) => c.url.endsWith("/git/commits"))!;
      assertEqual(JSON.stringify(Object.keys(commit.body as object).sort()), '["message","parents","tree"]', "no author keys");
    },
  },
];

runTests("github-app (admin-vy C2)", cases);
