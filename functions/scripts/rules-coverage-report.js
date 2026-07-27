/**
 * BUT-1677: measure Firestore rules coverage and gate untested NEW match blocks.
 *
 * `test:rules:all` going green says every assertion we wrote passed. It says
 * nothing about the paths nobody wrote an assertion for — a brand-new
 * `match /foo/{id}` can ship completely unexercised and the rules job stays
 * green. This reads the emulator's own coverage report and fails the job when a
 * match block that did NOT exist on the base revision was never evaluated.
 *
 * Coverage source: the Firestore emulator exposes
 *   GET http://<host>/emulator/v1/projects/<projectId>:ruleCoverage
 * (raw JSON; the `.html` sibling is the browser view). Coverage is scoped PER
 * PROJECT ID, and every rules suite here uses its own — so a single fetch would
 * report one suite's slice as if it were the whole picture. We discover the
 * project ids from the suites themselves and union the reports.
 *
 * Payload shape (undocumented by Firebase; verified against the emulator on
 * 2026-07-26, firebase-tools 14.27 / 15.13):
 *
 *   { "rules": { "files": [ { "name": "...", "content": "<rules source>" } ] },
 *     "report": [ { "sourcePosition": { "line": 50, "column": 14,
 *                                       "currentOffset": .., "endOffset": .. },
 *                   "values": [ { "value": {..}, "count": 2 } ],
 *                   "children": [ ...same shape... ] } ] }
 *
 * Two traps worth naming, because both make a wrong reading look plausible:
 *   - there is NO `evaluationCount` field. A node's evaluation count is the sum
 *     of `values[].count`, and a node with NO `values` key was never evaluated.
 *     Reading a missing field as 0 would report every block untested; keying on
 *     it would collect nothing at all.
 *   - `sourcePosition` has no `endLine` — only `line`. Blocks are therefore
 *     attributed by start line, which is all that is needed.
 *
 * The walker is still shape-tolerant (any node with a `sourcePosition`, at any
 * depth, under any key), and if it collects nothing the script FAILS rather
 * than reporting 0% or 100% — a coverage gate that silently measures nothing is
 * worse than no gate.
 *
 * Usage:
 *   node scripts/rules-coverage-report.js --out <dir> [--base <git-sha>]
 *
 * --base is the revision to diff match blocks against (needs full history, i.e.
 * fetch-depth: 0). Omitted or unresolvable → the table is still produced and the
 * gate is skipped with a notice, never a false pass and never a false failure.
 */

const fs = require("fs");
const http = require("http");
const path = require("path");
const { execFileSync } = require("child_process");

const FUNCTIONS_DIR = path.resolve(__dirname, "..");
const REPO_ROOT = path.resolve(FUNCTIONS_DIR, "..");
const TESTS_DIR = path.join(FUNCTIONS_DIR, "src", "__tests__");
const RULES_FILE = path.join(REPO_ROOT, "firestore.rules");
const EMULATOR_HOST = process.env.FIRESTORE_EMULATOR_HOST ?? "127.0.0.1:8080";

function parseArgs(argv) {
  const args = { out: null, base: null };
  for (let i = 0; i < argv.length; i++) {
    if (argv[i] === "--out") args.out = argv[++i];
    else if (argv[i] === "--base") args.base = argv[++i];
    else {
      console.error(`rules-coverage-report: unknown argument "${argv[i]}"`);
      process.exit(2);
    }
  }
  if (!args.out) {
    console.error(
      "rules-coverage-report: --out <dir> is required (where the table and raw reports are written).",
    );
    process.exit(2);
  }
  return args;
}

/** CRLF/LF and trailing-whitespace differences must not read as a new ruleset. */
function normalize(source) {
  return source.replace(/\r\n/g, "\n").trim();
}

function stripComment(line) {
  const idx = line.indexOf("//");
  return idx === -1 ? line : line.slice(0, idx);
}

/**
 * Fully-qualified match blocks with their line span.
 *
 * Brace-depth scan rather than a flat regex: blocks nest, and the path segments
 * themselves contain braces (`/users/{userId}`) that a naive counter would
 * mistake for scopes. They are balanced, so only the LAST `{` on a `match ... {`
 * line opens the body.
 */
function parseMatchBlocks(source) {
  const lines = source.split(/\r?\n/);
  const stack = [];
  const blocks = [];
  let depth = 0;

  for (let i = 0; i < lines.length; i++) {
    const line = stripComment(lines[i]);
    const opener = /^\s*match\s+(.+?)\s*\{\s*$/.exec(line);
    let lastOpenIdx = -1;
    if (opener) lastOpenIdx = line.lastIndexOf("{");

    for (let c = 0; c < line.length; c++) {
      const ch = line[c];
      if (ch === "{") {
        depth++;
        if (opener && c === lastOpenIdx) {
          const parent = stack[stack.length - 1];
          const fullPath = (parent ? parent.path : "") + opener[1];
          stack.push({
            path: fullPath,
            segment: opener[1],
            startLine: i + 1,
            openDepth: depth,
            indent: stack.length,
          });
        }
      } else if (ch === "}") {
        const top = stack[stack.length - 1];
        if (top && top.openDepth === depth) {
          stack.pop();
          blocks.push({ ...top, endLine: i + 1 });
        }
        depth--;
      }
    }
  }

  for (const unclosed of stack) {
    blocks.push({ ...unclosed, endLine: lines.length });
  }
  return blocks.sort((a, b) => a.startLine - b.startLine);
}

/** Project ids used by the rules suites — coverage is scoped per project. */
function discoverProjectIds() {
  const ids = new Set();
  for (const name of fs.readdirSync(TESTS_DIR)) {
    if (!name.endsWith(".test.ts")) continue;
    const source = fs.readFileSync(path.join(TESTS_DIR, name), "utf8");
    if (!source.includes("initializeTestEnvironment")) continue;
    const constMatch = /\bPROJECT_ID\s*=\s*["']([^"']+)["']/.exec(source);
    if (constMatch) ids.add(constMatch[1]);
    for (const m of source.matchAll(/projectId:\s*["']([^"']+)["']/g)) {
      ids.add(m[1]);
    }
  }
  return [...ids].sort();
}

function fetchCoverage(projectId) {
  const [host, port] = EMULATOR_HOST.split(":");
  const requestPath = `/emulator/v1/projects/${encodeURIComponent(projectId)}:ruleCoverage`;
  return new Promise((resolve) => {
    const req = http.request(
      {
        host,
        port: Number(port),
        path: requestPath,
        method: "GET",
        timeout: 15000,
        headers: { Accept: "application/json" },
      },
      (res) => {
        let body = "";
        res.setEncoding("utf8");
        res.on("data", (chunk) => (body += chunk));
        res.on("end", () => {
          if (res.statusCode !== 200) {
            resolve({ ok: false, reason: `HTTP ${res.statusCode}` });
            return;
          }
          try {
            resolve({ ok: true, json: JSON.parse(body), raw: body });
          } catch (err) {
            resolve({ ok: false, reason: `unparseable JSON (${err.message})` });
          }
        });
      },
    );
    req.on("error", (err) => resolve({ ok: false, reason: err.message }));
    req.on("timeout", () => {
      req.destroy();
      resolve({ ok: false, reason: "timeout" });
    });
    req.end();
  });
}

/** Every expression node, wherever it lives in the tree. */
function collectExprNodes(value, out) {
  if (Array.isArray(value)) {
    for (const item of value) collectExprNodes(item, out);
    return;
  }
  if (!value || typeof value !== "object") return;

  const pos = value.sourcePosition;
  if (pos && typeof pos === "object" && Number.isFinite(Number(pos.line))) {
    // No `values` key at all == never evaluated. Present == sum the counts.
    let count = 0;
    if (Array.isArray(value.values)) {
      for (const entry of value.values) {
        const n = Number(entry?.count);
        if (Number.isFinite(n)) count += n;
      }
    }
    out.push({
      key: `${pos.line}:${pos.column ?? ""}:${pos.currentOffset ?? ""}:${pos.endOffset ?? ""}`,
      line: Number(pos.line),
      count,
    });
  }
  // `values` holds evaluated data, not expressions — descending into it would
  // invent nodes out of nested `sourcePosition`-less maps and inflate totals.
  for (const [key, child] of Object.entries(value)) {
    if (key === "values" || key === "sourcePosition") continue;
    collectExprNodes(child, out);
  }
}

/** Innermost block whose span contains the line. */
function innermostBlock(blocks, line) {
  let best = null;
  for (const block of blocks) {
    if (line < block.startLine || line > block.endLine) continue;
    if (!best || block.startLine > best.startLine) best = block;
  }
  return best;
}

function gitShow(rev, file) {
  try {
    return execFileSync("git", ["show", `${rev}:${file}`], {
      cwd: REPO_ROOT,
      encoding: "utf8",
      maxBuffer: 32 * 1024 * 1024,
      stdio: ["ignore", "pipe", "ignore"],
    });
  } catch {
    return null;
  }
}

async function main() {
  const args = parseArgs(process.argv.slice(2));
  const outDir = path.resolve(args.out);
  fs.mkdirSync(outDir, { recursive: true });

  const rulesSource = fs.readFileSync(RULES_FILE, "utf8");
  const blocks = parseMatchBlocks(rulesSource);
  if (blocks.length === 0) {
    console.error(
      "rules-coverage-report: parsed 0 match blocks from firestore.rules — refusing to report vacuous coverage.",
    );
    process.exit(1);
  }

  const projectIds = discoverProjectIds();
  const merged = new Map();
  const fetched = [];
  const skipped = [];

  for (const projectId of projectIds) {
    const result = await fetchCoverage(projectId);
    if (!result.ok) {
      skipped.push(`${projectId} (${result.reason})`);
      continue;
    }
    // A project whose ruleset is not firestore.rules (e.g. the storage-rules
    // suite) reports positions into a DIFFERENT source — folding it in would
    // attribute hits to unrelated line numbers.
    const files = result.json?.rules?.files;
    const source = Array.isArray(files) ? files[0]?.content : undefined;
    if (typeof source !== "string") {
      skipped.push(`${projectId} (no ruleset loaded)`);
      continue;
    }
    if (normalize(source) !== normalize(rulesSource)) {
      skipped.push(`${projectId} (ruleset is not firestore.rules)`);
      continue;
    }
    const nodes = [];
    collectExprNodes(result.json, nodes);
    if (nodes.length === 0) {
      skipped.push(`${projectId} (no expression nodes in report)`);
      continue;
    }
    fs.writeFileSync(
      path.join(outDir, `${projectId}.ruleCoverage.json`),
      result.raw,
    );
    fetched.push(projectId);
    for (const node of nodes) {
      const existing = merged.get(node.key);
      if (existing) existing.count += node.count;
      else merged.set(node.key, { ...node });
    }
  }

  if (merged.size === 0) {
    console.error(
      "rules-coverage-report: no coverage expressions collected from any project.",
    );
    console.error(
      `  emulator: ${EMULATOR_HOST}; projects probed: ${projectIds.length}`,
    );
    for (const reason of skipped) console.error(`  - skipped ${reason}`);
    console.error(
      "  Either the emulator was already stopped, or the :ruleCoverage payload changed shape. Fix the collector — do not let this pass as 'no coverage'.",
    );
    process.exit(1);
  }

  const stats = new Map(
    blocks.map((block) => [
      block,
      { exprTotal: 0, exprHit: 0, evaluations: 0 },
    ]),
  );
  for (const node of merged.values()) {
    const block = innermostBlock(blocks, node.line);
    if (!block) continue;
    const stat = stats.get(block);
    stat.exprTotal++;
    stat.evaluations += node.count;
    if (node.count > 0) stat.exprHit++;
  }

  // Newly-added blocks: set-diff of block PATHS against the base revision, so a
  // block that merely moved lines is not mistaken for a new one.
  let newPaths = null;
  let gateNote = "";
  if (args.base) {
    const baseSource = gitShow(args.base, "firestore.rules");
    if (baseSource === null) {
      gateNote = `Gate skipped: could not read firestore.rules at base \`${args.base}\` (shallow clone, or the file is new).`;
    } else {
      const basePaths = new Set(
        parseMatchBlocks(baseSource).map((block) => block.path),
      );
      newPaths = new Set(
        blocks.map((b) => b.path).filter((p) => !basePaths.has(p)),
      );
      gateNote = `Gate active against base \`${args.base}\`: ${newPaths.size} new match block(s).`;
    }
  } else {
    gateNote = "Gate skipped: no --base revision supplied.";
  }

  const totalExpr = merged.size;
  const hitExpr = [...merged.values()].filter((n) => n.count > 0).length;
  const percent = ((hitExpr / totalExpr) * 100).toFixed(1);

  const rows = [];
  for (const block of blocks) {
    const stat = stats.get(block);
    const isNew = newPaths ? newPaths.has(block.path) : false;
    const status =
      stat.exprTotal === 0
        ? "· constant body, nothing to measure"
        : stat.exprHit === 0
          ? "❌ untested"
          : stat.exprHit === stat.exprTotal
            ? "✅ full"
            : "⚠️ partial";
    rows.push(
      `| \`${block.path}\` | ${block.startLine}–${block.endLine} | ${stat.exprHit}/${stat.exprTotal} | ${stat.evaluations} | ${status} | ${isNew ? "yes" : ""} |`,
    );
  }

  const lines = [
    "## Firestore rules coverage",
    "",
    `Expressions evaluated at least once: **${hitExpr}/${totalExpr} (${percent}%)**, unioned over ${fetched.length} project report(s).`,
    "",
    gateNote,
    "",
    "| Match block | Lines | Expr hit | Evaluations | Status | New |",
    "| --- | --- | --- | --- | --- | --- |",
    ...rows,
    "",
  ];
  if (skipped.length > 0) {
    lines.push(
      "<details><summary>Projects skipped</summary>",
      "",
      ...skipped.map((reason) => `- ${reason}`),
      "",
      "</details>",
      "",
    );
  }

  const table = lines.join("\n");
  fs.writeFileSync(path.join(outDir, "coverage-table.md"), table);
  if (process.env.GITHUB_STEP_SUMMARY) {
    fs.appendFileSync(process.env.GITHUB_STEP_SUMMARY, `${table}\n`);
  }
  console.log(table);

  if (!newPaths) {
    console.log(`\nrules-coverage-report: ${gateNote}`);
    return;
  }

  // exprTotal === 0 means the emulator emitted no expression node for the block
  // at all — verified behaviour for a constant body like `allow read, write: if
  // false;`. That is unmeasurable, not untested, and failing it would block
  // every new deny-all block on evidence that cannot exist.
  const untestedNew = blocks.filter((block) => {
    const stat = stats.get(block);
    return newPaths.has(block.path) && stat.exprTotal > 0 && stat.exprHit === 0;
  });
  if (untestedNew.length > 0) {
    console.error(
      `\nrules-coverage-report: ${untestedNew.length} newly-added match block(s) were never evaluated by test:rules:all:\n`,
    );
    for (const block of untestedNew) {
      console.error(
        `  - ${block.path}  (firestore.rules:${block.startLine}–${block.endLine})`,
      );
    }
    console.error(
      "\nAdd a rules test that exercises each one — a new path with no assertions is an ungated hole, whatever the rule text says.\n",
    );
    process.exit(1);
  }

  console.log(
    `\nrules-coverage-report: OK — every one of the ${newPaths.size} new match block(s) was evaluated.`,
  );
}

// Exported so the parser and attribution can be exercised without an emulator.
module.exports = { parseMatchBlocks, collectExprNodes, innermostBlock };

if (require.main === module) {
  main().catch((err) => {
    console.error(`rules-coverage-report: ${err.stack ?? err}`);
    process.exit(1);
  });
}
