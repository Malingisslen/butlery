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

/**
 * BUT-1708 decision — the untested-block count is REPORT-ONLY.
 *
 * The number (how many match blocks nothing ever evaluates) is printed on every
 * run, written to `coverage-summary.json` beside the table, and uploaded with
 * the job's artifacts. It does NOT gate the build, and there is deliberately no
 * ratchet:
 *   - the ratchet's failure mode is the wrong one. A red build on a number that
 *     drifted while the author touched an unrelated rule teaches people to
 *     re-baseline the floor, which is how a ratchet becomes decoration.
 *   - the number is not yet stable: it moves with block-parsing changes (this
 *     ticket alone moved it) and with which suites the emulator managed to run.
 *     Ratcheting a metric whose definition is still settling ratchets noise.
 *   - the real hole was never the backlog of old untested blocks — it was NEW
 *     ones shipping unexercised, and that IS gated, per-block, above.
 * Revisit once the number has held steady across a few weeks of runs; a floor
 * would then be a one-line change here plus a stored baseline.
 */
const UNTESTED_BLOCK_POLICY = "report-only";

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

/**
 * Code-only view of [source], aligned with the original CHARACTER FOR
 * CHARACTER: every comment character, and every character inside a string
 * literal, becomes a space. Nothing is dropped and nothing shifts, so a line
 * and column here still point at the real file — which is what lets
 * [ownBodyText] subtract a nested block by offset instead of by whole lines.
 *
 * Comments must go before the character scan below. The block form is not
 * exotic — the Firebase console's own default `firestore.rules` ships with one
 * — and a comment such as `/* legacy: match /ghost/{id} was removed *\/`
 * otherwise reads as a real match header and swallows the block underneath it.
 *
 * BUT-1729: string CONTENTS go too. The scan is a character scan, and a rules
 * string may legally contain every character it keys on: `"https://x"` starts a
 * line comment, `"/*"` opens a block comment that silently deletes every match
 * block after it, and a `"}"` closes a block early — each of which makes a
 * brand-new world-open block disappear from the parse while the gate prints OK.
 * Blanking the contents (never the quotes) makes all three impossible, and
 * nothing downstream reads inside a string literal.
 */
function stripCommentsAndStrings(source) {
  const out = [];
  let inBlock = false;
  for (const raw of source.split(/\r?\n/)) {
    let line = "";
    // The rules language has no multi-line string, so an unterminated quote
    // dies with its own line rather than blanking the rest of the file.
    let quote = null;
    for (let c = 0; c < raw.length; c++) {
      const ch = raw[c];
      if (inBlock) {
        line += " ";
        if (ch === "*" && raw[c + 1] === "/") {
          line += " ";
          inBlock = false;
          c++;
        }
        continue;
      }
      if (quote) {
        if (ch === "\\" && c + 1 < raw.length) {
          line += "  ";
          c++;
          continue;
        }
        line += ch === quote ? ch : " ";
        if (ch === quote) quote = null;
        continue;
      }
      if (ch === '"' || ch === "'") {
        quote = ch;
        line += ch;
        continue;
      }
      if (ch === "/" && raw[c + 1] === "/") {
        line += " ".repeat(raw.length - c);
        break;
      }
      if (ch === "/" && raw[c + 1] === "*") {
        inBlock = true;
        line += "  ";
        c++;
        continue;
      }
      line += ch;
    }
    out.push(line);
  }
  return out;
}

/** Absolute offset of each line's first character in `lines.join("\n")`. */
function lineStartOffsets(lines) {
  const offsets = new Array(lines.length);
  let total = 0;
  for (let i = 0; i < lines.length; i++) {
    offsets[i] = total;
    total += lines[i].length + 1;
  }
  return offsets;
}

const WORD_CHAR = /[A-Za-z0-9_$]/;

/** A header may wrap, but never far — beyond this it is a stray `match` word. */
const MAX_HEADER_LINES = 3;

/**
 * Fully-qualified match blocks with their line span.
 *
 * Character scan rather than a line regex (BUT-1707): the earlier
 * `/^\s*match\s+(.+?)\s*\{\s*$/` only recognised a block whose line ENDED with
 * the opening brace, so a legal one-liner —
 * `match /leaky/{id} { allow read: if true; }` — parsed as no block at all.
 * It then never appeared in the new-block set and the gate waved it through: a
 * world-readable path could ship green. Braces are therefore tracked per
 * character, and a `match` header is read until the brace that opens its body.
 *
 * Path wildcards (`/users/{userId}`, `/{doc=**}`) are always introduced by `/`,
 * which is what separates a path brace from the body brace no matter how the
 * header is wrapped across lines.
 *
 * A character scan is looser than a line regex, so the token alone cannot be
 * the accept condition — `allow read: if resource.data.kind == "match";` would
 * otherwise start a header that runs on until the next non-path `{`, merging
 * the real block after it out of existence and taking the gate's coverage
 * attribution with it. Three constraints keep a started header honest:
 * comments are stripped first, the first non-space character after `match`
 * MUST be the `/` that opens a path, and a header is abandoned at `;`, at a
 * stray `}`, or once it has run past [MAX_HEADER_LINES].
 */
function parseMatchBlocks(source) {
  const lines = stripCommentsAndStrings(source);
  const stack = [];
  const blocks = [];
  let depth = 0;
  let pending = null;

  for (let i = 0; i < lines.length; i++) {
    const line = lines[i];
    for (let c = 0; c < line.length; c++) {
      const ch = line[c];

      if (!pending && ch === "m" && line.startsWith("match", c)) {
        const before = c === 0 ? "" : line[c - 1];
        const after = line[c + 5] ?? " ";
        if (!WORD_CHAR.test(before) && !WORD_CHAR.test(after)) {
          pending = {
            text: "",
            startLine: i + 1,
            startCol: c,
            pathDepth: 0,
            sawPath: false,
          };
          c += 4;
          continue;
        }
      }

      if (pending && !pending.sawPath) {
        // A real header's path starts here. Anything else means the `match`
        // token was a word in an expression, not a block opener.
        if (ch === " " || ch === "\t") continue;
        if (ch === "/") pending.sawPath = true;
        else pending = null;
      }

      if (pending && (ch === ";" || (ch === "}" && pending.pathDepth === 0))) {
        pending = null;
      }

      if (pending) {
        if (ch === "{") {
          const prev = c === 0 ? "" : line[c - 1];
          if (pending.pathDepth > 0 || prev === "/") {
            pending.pathDepth++;
            pending.text += ch;
            continue;
          }
          depth++;
          const parent = stack[stack.length - 1];
          const segment = pending.text.trim().replace(/\s+/g, " ");
          stack.push({
            path: (parent ? parent.path : "") + segment,
            segment,
            startLine: pending.startLine,
            startCol: pending.startCol,
            // Where the BODY starts, i.e. this very brace. Everything a block
            // owns lies between it and the matching close.
            bodyLine: i + 1,
            bodyCol: c,
            openDepth: depth,
            indent: stack.length,
          });
          pending = null;
          continue;
        }
        if (ch === "}" && pending.pathDepth > 0) {
          pending.pathDepth--;
          pending.text += ch;
          continue;
        }
        pending.text += ch;
        continue;
      }

      if (ch === "{") {
        depth++;
      } else if (ch === "}") {
        const top = stack[stack.length - 1];
        if (top && top.openDepth === depth) {
          stack.pop();
          blocks.push({ ...top, endLine: i + 1, endCol: c });
        }
        depth--;
      }
    }
    // A header may wrap, but only a little. Waiting until EOF to give up lets
    // one bad start consume the rest of the file.
    if (pending && i + 1 - pending.startLine >= MAX_HEADER_LINES) pending = null;
  }

  const lastLine = lines[lines.length - 1] ?? "";
  for (const unclosed of stack) {
    blocks.push({
      ...unclosed,
      endLine: Math.max(lines.length, 1),
      endCol: lastLine.length,
    });
  }
  return blocks.sort((a, b) => a.startLine - b.startLine);
}

/**
 * The block's OWN body text — nested match blocks blanked out, comments and
 * string contents already blank. A parent's `allow` statements are its own; a
 * child's belong to the child.
 *
 * BUT-1729: the subtraction is by CHARACTER OFFSET, not by whole lines. Rules
 * files are hand-formatted, and a parent's own allow may share a line with a
 * single-line child —
 *
 *   match /p/{id} { match /c/{cid} { allow read: if isOwner(); } allow read, write: if true; }
 *
 * Dropping every line the child touches took the parent's world-open grant with
 * it, demoted the parent to a harmless `container`, and the gate reported OK on
 * a path that grants everything to everyone. Offsets cut exactly the child.
 */
function ownBodyText(source, blocks, block) {
  const lines = stripCommentsAndStrings(source);
  const offsets = lineStartOffsets(lines);
  const at = (line, col) => offsets[line - 1] + col;

  const start = at(block.bodyLine, block.bodyCol) + 1; // just past the `{`
  const end = at(block.endLine, block.endCol); // just before the `}`
  if (!Number.isFinite(start) || !Number.isFinite(end) || end <= start) {
    return "";
  }

  const chars = lines.join("\n").slice(start, end).split("");
  for (const other of blocks) {
    if (other === block) continue;
    const otherStart = at(other.startLine, other.startCol);
    const otherEnd = at(other.endLine, other.endCol) + 1; // past its `}`
    if (!Number.isFinite(otherStart) || otherStart < start || otherEnd > end) {
      continue; // not nested inside this block's body
    }
    for (let i = otherStart; i < otherEnd; i++) chars[i - start] = " ";
  }
  return chars.join("");
}

/**
 * What the block grants when nobody tests it.
 *
 * BUT-1707: the gate used to exempt every block the emulator reported no
 * expression for ("constant body, nothing to measure"). That is true of
 * `allow read, write: if false;` — and equally true of `if true`, so a new
 * world-open block was exempted by the very rule written to spare deny-all
 * blocks. Constant ALLOW and constant DENY are now told apart from the rules
 * source, which is evidence that always exists, rather than from a coverage
 * payload that by definition has nothing to say about a constant.
 *
 *   container      — no `allow` of its own (a grouping block; children carry it)
 *   constant-deny  — every allow is `if false` (unmeasurable AND harmless)
 *   constant-allow — some allow is unconditional or `if true` (never exempt)
 *   conditional    — some allow has a real condition (must be exercised)
 */
function classifyBlockBody(source, blocks, block) {
  const body = ownBodyText(source, blocks, block);
  const allows = [];
  for (const match of body.matchAll(/\ballow\b([^;{}]*)(?:;|$)/g)) {
    const clause = match[1];
    const colon = clause.indexOf(":");
    const condition = colon === -1 ? "" : clause.slice(colon + 1).trim();
    const stripped = condition.replace(/^if\b/, "").trim();
    if (stripped === "" || /^\(*\s*true\s*\)*$/.test(stripped)) {
      allows.push({ effect: "open", condition: stripped });
    } else if (/^\(*\s*false\s*\)*$/.test(stripped)) {
      allows.push({ effect: "deny", condition: stripped });
    } else {
      allows.push({ effect: "conditional", condition: stripped });
    }
  }

  let kind = "container";
  if (allows.some((a) => a.effect === "open")) kind = "constant-allow";
  else if (allows.some((a) => a.effect === "conditional")) kind = "conditional";
  else if (allows.length > 0) kind = "constant-deny";
  return { kind, allows };
}

/**
 * The gate decision for one run, as data — so it can be exercised over fixtures
 * without an emulator, a git history or a CI runner.
 *
 * `statsByPath`: path -> { exprTotal, exprHit }. `newPaths`: Set of block paths
 * absent from the base revision, or null when the gate is skipped.
 */
function evaluateGate({ source, blocks, statsByPath, newPaths }) {
  const untestedAll = [];
  const failures = [];
  const exempt = [];

  for (const block of blocks) {
    const stat = statsByPath.get(block.path) ?? { exprTotal: 0, exprHit: 0 };
    const { kind } = classifyBlockBody(source, blocks, block);
    const measurable = kind === "constant-allow" || kind === "conditional";
    // BUT-1729: coverage can vouch for a CONDITIONAL block — some expression of
    // it ran. It can never vouch for a constant grant: `if true` has no
    // expression to hit, so any hit elsewhere in the block (a sibling
    // conditional allow, a helper call on the same line) would otherwise sign
    // off on the unconditional one. `match /leaky/{id} { allow read: if true;
    // allow write: if request.auth != null; }` with one test on the write rule
    // passed the gate. A constant-allow block is untested by definition,
    // whatever exprHit says.
    const untested =
      kind === "constant-allow" || (measurable && stat.exprHit === 0);
    if (untested) untestedAll.push({ path: block.path, kind, block });
    if (!newPaths || !newPaths.has(block.path)) continue;
    if (!untested) continue;

    const reason =
      kind === "constant-allow"
        ? "grants access unconditionally (`if true` / no condition) and no test asserts it"
        : stat.exprTotal === 0
          ? "the emulator reported no expression for it at all — the block was never reached"
          : "was never evaluated by test:rules:all";
    failures.push({ path: block.path, kind, reason, block });
  }

  for (const block of blocks) {
    if (!newPaths || !newPaths.has(block.path)) continue;
    if (failures.some((f) => f.path === block.path)) continue;
    exempt.push({ path: block.path });
  }

  return { failures, untestedAll, exempt };
}

/**
 * Which of HEAD's block paths did not exist at the base revision.
 *
 * BUT-1729: extracted from `main` so the diff the whole gate stands on can be
 * exercised without a git history. The comparison is a set-diff of fully
 * qualified block PATHS, so re-indenting a block, moving it, or reformatting
 * its header — the common shape of a rules edit — produces an EMPTY diff and
 * cannot fail the gate; only a genuinely new path is new.
 *
 * Returns `{ newPaths, note }`. A null `newPaths` means the gate is SKIPPED,
 * which is deliberately not the same value as an empty set: "nothing new" and
 * "could not tell" must never print the same.
 */
function newBlockPaths({ base, baseSource, blocks }) {
  if (!base) {
    return {
      newPaths: null,
      note: "Gate skipped: no --base revision supplied.",
    };
  }
  if (typeof baseSource !== "string") {
    return {
      newPaths: null,
      note: `Gate skipped: could not read firestore.rules at base \`${base}\` (shallow clone, or the file is new).`,
    };
  }
  const basePaths = new Set(
    parseMatchBlocks(baseSource).map((block) => block.path),
  );
  const newPaths = new Set(
    blocks.map((block) => block.path).filter((p) => !basePaths.has(p)),
  );
  return {
    newPaths,
    note: `Gate active against base \`${base}\`: ${newPaths.size} new match block(s).`,
  };
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

  const { newPaths, note: gateNote } = newBlockPaths({
    base: args.base,
    baseSource: args.base ? gitShow(args.base, "firestore.rules") : null,
    blocks,
  });

  const totalExpr = merged.size;
  const hitExpr = [...merged.values()].filter((n) => n.count > 0).length;
  const percent = ((hitExpr / totalExpr) * 100).toFixed(1);

  const statsByPath = new Map(
    blocks.map((block) => [block.path, stats.get(block)]),
  );
  const gate = evaluateGate({
    source: rulesSource,
    blocks,
    statsByPath,
    newPaths,
  });
  const untestedPaths = new Set(gate.untestedAll.map((entry) => entry.path));

  const rows = [];
  for (const block of blocks) {
    const stat = stats.get(block);
    const isNew = newPaths ? newPaths.has(block.path) : false;
    const { kind } = classifyBlockBody(rulesSource, blocks, block);
    const status = untestedPaths.has(block.path)
      ? kind === "constant-allow"
        ? "❌ untested — grants access unconditionally"
        : "❌ untested"
      : kind === "constant-deny"
        ? "· constant deny, nothing to measure"
        : kind === "container"
          ? "· grouping block, no allow of its own"
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
    // BUT-1708: the tracked number. Report-only by decision — see the header.
    `Untested match blocks: **${gate.untestedAll.length}** of ${blocks.length} (report-only — no floor is enforced on this number; the gate fails only on NEW untested blocks).`,
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

  // BUT-1708: persist the tracked numbers next to the table so a run's coverage
  // is a machine-readable artifact, not just prose in a job summary. Written
  // BEFORE the gate can exit(1) — the number is most interesting on a red run.
  const summary = {
    generatedAt: new Date().toISOString(),
    policy: UNTESTED_BLOCK_POLICY,
    totalBlocks: blocks.length,
    untestedBlocks: gate.untestedAll.length,
    untestedBlockPaths: gate.untestedAll.map((entry) => entry.path),
    expressions: { total: totalExpr, hit: hitExpr, percent: Number(percent) },
    newBlocks: newPaths ? newPaths.size : null,
    newUntestedBlocks: newPaths ? gate.failures.length : null,
    projects: { fetched, skipped },
  };
  fs.writeFileSync(
    path.join(outDir, "coverage-summary.json"),
    `${JSON.stringify(summary, null, 2)}\n`,
  );
  console.log(
    `\nrules-coverage-report: untested match blocks = ${gate.untestedAll.length}/${blocks.length} (policy: ${UNTESTED_BLOCK_POLICY}).`,
  );

  if (!newPaths) {
    console.log(`rules-coverage-report: ${gateNote}`);
    return;
  }

  if (gate.failures.length > 0) {
    console.error(
      `\nrules-coverage-report: ${gate.failures.length} newly-added match block(s) are not exercised by test:rules:all:\n`,
    );
    for (const failure of gate.failures) {
      console.error(
        `  - ${failure.path}  (firestore.rules:${failure.block.startLine}–${failure.block.endLine})\n      ${failure.reason}`,
      );
    }
    console.error(
      "\nAdd a rules test that exercises each one — a new path with no assertions is an ungated hole, whatever the rule text says.\n",
    );
    process.exit(1);
  }

  console.log(
    `rules-coverage-report: OK — every one of the ${newPaths.size} new match block(s) is either exercised or a constant deny.`,
  );
}

// Exported so the parser, the body classifier and the gate decision can be
// exercised over fixtures without an emulator (scripts/__tests__).
module.exports = {
  parseMatchBlocks,
  collectExprNodes,
  innermostBlock,
  classifyBlockBody,
  evaluateGate,
  newBlockPaths,
  ownBodyText,
  stripCommentsAndStrings,
  UNTESTED_BLOCK_POLICY,
};

if (require.main === module) {
  main().catch((err) => {
    console.error(`rules-coverage-report: ${err.stack ?? err}`);
    process.exit(1);
  });
}
