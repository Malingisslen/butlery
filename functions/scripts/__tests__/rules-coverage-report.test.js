/**
 * BUT-1707: tests for the Firestore rules-coverage gate.
 *
 * The gate is the only thing standing between a brand-new match block and
 * shipping unexercised, and it had no tests at all — so the two ways it could
 * wave a world-open block through (a single-line block the parser never saw,
 * and the constant-body exemption that could not tell `if true` from
 * `if false`) were invisible. Everything here runs over FIXTURE rules sources
 * and synthetic coverage payloads: no emulator, no git history, no CI.
 *
 * Plain Node + node:assert, run by `npm run test:script-coverage-report`, which
 * run-ci-unit-tests.js discovers and the CF unit-test job executes.
 */

const assert = require("assert");
const fs = require("fs");
const path = require("path");

const {
  parseMatchBlocks,
  classifyBlockBody,
  evaluateGate,
  collectExprNodes,
  innermostBlock,
  newBlockPaths,
  stripCommentsAndStrings,
  UNTESTED_BLOCK_POLICY,
} = require("../rules-coverage-report.js");

const REPO_ROOT = path.resolve(__dirname, "..", "..", "..");
const RULES_WORKFLOW = path.join(
  REPO_ROOT,
  ".github",
  "workflows",
  "firestore-rules.yml",
);

const results = [];
function test(name, fn) {
  try {
    fn();
    results.push({ name, ok: true });
  } catch (err) {
    results.push({ name, ok: false, err });
  }
}

const paths = (blocks) => blocks.map((b) => b.path);
const byPath = (blocks, suffix) => {
  const found = blocks.find((b) => b.path.endsWith(suffix));
  assert.ok(found, `no block ending in ${suffix} (parsed: ${paths(blocks)})`);
  return found;
};
const kindOf = (source, suffix) => {
  const blocks = parseMatchBlocks(source);
  return classifyBlockBody(source, blocks, byPath(blocks, suffix)).kind;
};

const wrap = (body) =>
  `rules_version = '2';\nservice cloud.firestore {\n  match /databases/{database}/documents {\n${body}\n  }\n}\n`;

// ── parseMatchBlocks ──────────────────────────────────────────────────────

test("parses nested multi-line blocks with fully-qualified paths and spans", () => {
  const source = wrap(
    [
      "    match /users/{userId} {",
      "      allow read: if request.auth.uid == userId;",
      "      match /recipes/{recipeId} {",
      "        allow write: if request.auth != null;",
      "      }",
      "    }",
    ].join("\n"),
  );
  const blocks = parseMatchBlocks(source);
  assert.deepStrictEqual(paths(blocks), [
    "/databases/{database}/documents",
    "/databases/{database}/documents/users/{userId}",
    "/databases/{database}/documents/users/{userId}/recipes/{recipeId}",
  ]);
  const recipes = byPath(blocks, "/recipes/{recipeId}");
  assert.strictEqual(recipes.startLine, 6);
  assert.strictEqual(recipes.endLine, 8);
});

test("parses a SINGLE-LINE match block (the BUT-1707 bypass)", () => {
  const source = wrap("    match /leaky/{id} { allow read, write: if true; }");
  const blocks = parseMatchBlocks(source);
  const leaky = byPath(blocks, "/leaky/{id}");
  assert.strictEqual(leaky.startLine, 4);
  assert.strictEqual(leaky.endLine, 4);
});

test("parses a match header wrapped across lines", () => {
  const source = wrap(
    ["    match", "      /wrapped/{id}", "    {", "      allow read: if false;", "    }"].join("\n"),
  );
  const blocks = parseMatchBlocks(source);
  const wrapped = byPath(blocks, "/wrapped/{id}");
  assert.strictEqual(wrapped.startLine, 4);
  assert.strictEqual(wrapped.endLine, 8);
});

test("does not mistake a recursive wildcard or a helper function for a block", () => {
  const source = wrap(
    [
      "    function matchesOwner(uid) {",
      "      return request.auth.uid == uid;",
      "    }",
      "    match /docs/{doc=**} {",
      "      allow read: if matchesOwner(request.auth.uid);",
      "    }",
    ].join("\n"),
  );
  const blocks = parseMatchBlocks(source);
  assert.deepStrictEqual(paths(blocks), [
    "/databases/{database}/documents",
    "/databases/{database}/documents/docs/{doc=**}",
  ]);
});

test("ignores a match block that only appears inside a comment", () => {
  const source = wrap(
    [
      "    // match /ghost/{id} { allow read: if true; }",
      "    match /real/{id} {",
      "      allow read: if request.auth != null;",
      "    }",
    ].join("\n"),
  );
  assert.deepStrictEqual(paths(parseMatchBlocks(source)), [
    "/databases/{database}/documents",
    "/databases/{database}/documents/real/{id}",
  ]);
});

test("ignores a match block hidden in a BLOCK comment", () => {
  // The Firebase console's own default firestore.rules ships with a `/* */`
  // header, so this is ordinary input. Before the fix the comment started a
  // header that ran on and ate `/real/{id}` — the surviving block was the
  // garbage path `/…/ghost/{id} was removed */ match /real/{id}`.
  const source = wrap(
    [
      "    /* legacy: match /ghost/{id} was removed */",
      "    match /real/{id} {",
      "      allow read: if request.auth != null;",
      "    }",
    ].join("\n"),
  );
  assert.deepStrictEqual(paths(parseMatchBlocks(source)), [
    "/databases/{database}/documents",
    "/databases/{database}/documents/real/{id}",
  ]);
});

test("ignores a multi-line block comment containing a match header", () => {
  const source = wrap(
    [
      "    /*",
      "     * match /ghost/{id} {",
      "     *   allow read, write: if true;",
      "     * }",
      "     */",
      "    match /real/{id} {",
      "      allow read: if request.auth != null;",
      "    }",
    ].join("\n"),
  );
  assert.deepStrictEqual(paths(parseMatchBlocks(source)), [
    "/databases/{database}/documents",
    "/databases/{database}/documents/real/{id}",
  ]);
});

test("a `match` WORD inside an expression does not start a header", () => {
  // The silent-pass hole the character scan re-opened: the stray token
  // started a header that swallowed everything up to the next non-path `{`,
  // so the world-open block below stopped existing as a path AND the garbage
  // block inherited /a's coverage — reporting the new hole as TESTED.
  const source = wrap(
    [
      "    match /a/{id} {",
      '      allow read: if resource.data.kind == "match";',
      "    }",
      "    match /b/{id} { allow read, write: if true; }",
    ].join("\n"),
  );
  const blocks = parseMatchBlocks(source);
  assert.deepStrictEqual(paths(blocks), [
    "/databases/{database}/documents",
    "/databases/{database}/documents/a/{id}",
    "/databases/{database}/documents/b/{id}",
  ]);
  // And the world-open block must still be seen for what it is.
  assert.strictEqual(kindOf(source, "/b/{id}"), "constant-allow");
});

test("a stray `match` word does not consume the rest of the file", () => {
  const source = wrap(
    [
      "    match /a/{id} {",
      "      allow read: if request.auth.token.match == true;",
      "      allow write: if false;",
      "    }",
      "    match /b/{id} {",
      "      allow read: if request.auth != null;",
      "    }",
    ].join("\n"),
  );
  assert.deepStrictEqual(paths(parseMatchBlocks(source)), [
    "/databases/{database}/documents",
    "/databases/{database}/documents/a/{id}",
    "/databases/{database}/documents/b/{id}",
  ]);
});

// ── string literals (BUT-1729) ────────────────────────────────────────────
//
// The scan keys on `/`, `*`, `{` and `}`, every one of which a rules string may
// legally contain. Each case below made the world-open block that follows it
// VANISH from the parse — so it was never in the new-block set, and the gate
// printed OK on a path that grants everything to everyone.

test("a `/*` inside a string literal does not swallow the rest of the file", () => {
  const source = wrap(
    [
      "    match /a/{id} {",
      '      allow read: if resource.data.pattern == "/*";',
      "    }",
      "    match /leaky/{id} { allow read, write: if true; }",
    ].join("\n"),
  );
  assert.deepStrictEqual(paths(parseMatchBlocks(source)), [
    "/databases/{database}/documents",
    "/databases/{database}/documents/a/{id}",
    "/databases/{database}/documents/leaky/{id}",
  ]);
  assert.strictEqual(kindOf(source, "/leaky/{id}"), "constant-allow");
});

test("a `//` inside a string literal does not blank the rest of the line", () => {
  const source = wrap(
    [
      '    match /a/{id} { allow read: if resource.data.url == "https://x"; }',
      "    match /leaky/{id} { allow read, write: if true; }",
    ].join("\n"),
  );
  assert.deepStrictEqual(paths(parseMatchBlocks(source)), [
    "/databases/{database}/documents",
    "/databases/{database}/documents/a/{id}",
    "/databases/{database}/documents/leaky/{id}",
  ]);
  assert.strictEqual(kindOf(source, "/a/{id}"), "conditional");
});

test("a brace inside a string literal does not close a block early", () => {
  const source = wrap(
    [
      "    match /a/{id} {",
      '      allow read: if resource.data.template == "}";',
      "    }",
      "    match /leaky/{id} { allow read, write: if true; }",
    ].join("\n"),
  );
  assert.deepStrictEqual(paths(parseMatchBlocks(source)), [
    "/databases/{database}/documents",
    "/databases/{database}/documents/a/{id}",
    "/databases/{database}/documents/leaky/{id}",
  ]);
});

test("the code-only view stays aligned with the source, line and column", () => {
  // ownBodyText subtracts a nested block by OFFSET, so a view that shifted by
  // even one character would cut the wrong text out of the parent's body.
  const source = [
    'let a = "x/*y"; // trailing',
    "/* block */ let b = 1;",
    "plain",
  ].join("\n");
  const view = stripCommentsAndStrings(source);
  const raw = source.split("\n");
  assert.strictEqual(view.length, raw.length);
  view.forEach((line, i) => assert.strictEqual(line.length, raw[i].length));
  assert.strictEqual(view[0], `let a = "    "; ${" ".repeat(11)}`);
  assert.strictEqual(view[1], "            let b = 1;");
  assert.strictEqual(view[2], "plain");
});

// ── classifyBlockBody ─────────────────────────────────────────────────────

test("classifies `if true` as constant-allow and `if false` as constant-deny", () => {
  const open = wrap("    match /leaky/{id} { allow read, write: if true; }");
  const shut = wrap("    match /locked/{id} { allow read, write: if false; }");
  assert.strictEqual(kindOf(open, "/leaky/{id}"), "constant-allow");
  assert.strictEqual(kindOf(shut, "/locked/{id}"), "constant-deny");
});

test("classifies an allow with no condition as constant-allow", () => {
  const source = wrap("    match /open/{id} {\n      allow read;\n    }");
  assert.strictEqual(kindOf(source, "/open/{id}"), "constant-allow");
});

test("classifies a real condition as conditional and a bare parent as container", () => {
  const source = wrap(
    [
      "    match /users/{userId} {",
      "      match /notes/{noteId} {",
      "        allow read: if request.auth.uid == userId;",
      "      }",
      "    }",
    ].join("\n"),
  );
  assert.strictEqual(kindOf(source, "/notes/{noteId}"), "conditional");
  assert.strictEqual(kindOf(source, "/users/{userId}"), "container");
});

test("a parent's own allow is not attributed to its child, or vice versa", () => {
  const source = wrap(
    [
      "    match /parent/{pid} {",
      "      allow read: if false;",
      "      match /child/{cid} {",
      "        allow read: if true;",
      "      }",
      "    }",
    ].join("\n"),
  );
  assert.strictEqual(kindOf(source, "/parent/{pid}"), "constant-deny");
  assert.strictEqual(kindOf(source, "/child/{cid}"), "constant-allow");
});

test("a parent's own allow survives a child that shares its line (BUT-1729)", () => {
  // Line-based subtraction dropped the whole line the child sat on, taking the
  // parent's `if true` with it: the parent read as a harmless `container` and
  // the gate reported OK on a world-open path.
  const source = wrap(
    [
      "    match /p/{pid} {",
      "      match /c/{cid} { allow read: if request.auth != null; } allow read, write: if true;",
      "    }",
    ].join("\n"),
  );
  assert.strictEqual(kindOf(source, "/p/{pid}"), "constant-allow");
  assert.strictEqual(kindOf(source, "/c/{cid}"), "conditional");
});

test("a child on the parent's own line does not donate its allow to the parent", () => {
  const source = wrap(
    "    match /p/{pid} { match /c/{cid} { allow read, write: if true; } }",
  );
  assert.strictEqual(kindOf(source, "/p/{pid}"), "container");
  assert.strictEqual(kindOf(source, "/c/{cid}"), "constant-allow");
});

// ── evaluateGate ──────────────────────────────────────────────────────────

function gateOver(source, statEntries, newSuffixes) {
  const blocks = parseMatchBlocks(source);
  const statsByPath = new Map(
    blocks.map((block) => [block.path, { exprTotal: 0, exprHit: 0 }]),
  );
  for (const [suffix, stat] of statEntries) {
    statsByPath.set(byPath(blocks, suffix).path, stat);
  }
  const newPaths =
    newSuffixes === null
      ? null
      : new Set(newSuffixes.map((suffix) => byPath(blocks, suffix).path));
  return evaluateGate({ source, blocks, statsByPath, newPaths });
}

test("a NEW world-open single-line block FAILS the gate (no coverage exists for a constant)", () => {
  const source = wrap("    match /leaky/{id} { allow read, write: if true; }");
  const gate = gateOver(source, [], ["/leaky/{id}"]);
  assert.strictEqual(gate.failures.length, 1);
  assert.match(gate.failures[0].path, /\/leaky\/\{id\}$/);
  assert.strictEqual(gate.failures[0].kind, "constant-allow");
  assert.match(gate.failures[0].reason, /unconditionally/);
});

test("a NEW constant-deny block passes — the exemption survives, narrowed", () => {
  const source = wrap("    match /locked/{id} { allow read, write: if false; }");
  const gate = gateOver(source, [], ["/locked/{id}"]);
  assert.deepStrictEqual(gate.failures, []);
});

test("a NEW conditional block fails when its expressions were never hit", () => {
  const source = wrap(
    "    match /guarded/{id} {\n      allow read: if request.auth != null;\n    }",
  );
  const gate = gateOver(
    source,
    [["/guarded/{id}", { exprTotal: 3, exprHit: 0 }]],
    ["/guarded/{id}"],
  );
  assert.strictEqual(gate.failures.length, 1);
  assert.match(gate.failures[0].reason, /never evaluated/);
});

test("a NEW conditional block passes once a test evaluates it", () => {
  const source = wrap(
    "    match /guarded/{id} {\n      allow read: if request.auth != null;\n    }",
  );
  const gate = gateOver(
    source,
    [["/guarded/{id}", { exprTotal: 3, exprHit: 2 }]],
    ["/guarded/{id}"],
  );
  assert.deepStrictEqual(gate.failures, []);
});

test("a NEW conditional block with NO expression nodes at all fails, not exempts", () => {
  const source = wrap(
    "    match /never-reached/{id} {\n      allow read: if request.auth != null;\n    }",
  );
  const gate = gateOver(source, [], ["/never-reached/{id}"]);
  assert.strictEqual(gate.failures.length, 1);
  assert.match(gate.failures[0].reason, /never reached/);
});

test("an OLD untested block does not fail the gate but is counted (BUT-1708)", () => {
  const source = wrap(
    [
      "    match /old/{id} {",
      "      allow read: if request.auth != null;",
      "    }",
      "    match /new/{id} {",
      "      allow read: if request.auth != null;",
      "    }",
    ].join("\n"),
  );
  const gate = gateOver(
    source,
    [
      ["/old/{id}", { exprTotal: 2, exprHit: 0 }],
      ["/new/{id}", { exprTotal: 2, exprHit: 1 }],
    ],
    ["/new/{id}"],
  );
  assert.deepStrictEqual(gate.failures, []);
  assert.strictEqual(gate.untestedAll.length, 1);
  assert.match(gate.untestedAll[0].path, /\/old\/\{id\}$/);
});

test("with no base revision (newPaths null) nothing fails but the count still lands", () => {
  const source = wrap(
    "    match /old/{id} {\n      allow read: if request.auth != null;\n    }",
  );
  const gate = gateOver(source, [["/old/{id}", { exprTotal: 2, exprHit: 0 }]], null);
  assert.deepStrictEqual(gate.failures, []);
  assert.strictEqual(gate.untestedAll.length, 1);
});

test("a NEW constant-allow block fails even when its expressions WERE hit (BUT-1729)", () => {
  // The world-open `read` has no expression of its own; the coverage the
  // emulator reports belongs to the sibling `write` condition. Requiring
  // exprHit === 0 let that sibling's single test sign off on the open grant.
  const source = wrap(
    "    match /leaky/{id} { allow read: if true; allow write: if request.auth != null; }",
  );
  const gate = gateOver(
    source,
    [["/leaky/{id}", { exprTotal: 3, exprHit: 2 }]],
    ["/leaky/{id}"],
  );
  assert.strictEqual(gate.failures.length, 1);
  assert.strictEqual(gate.failures[0].kind, "constant-allow");
  assert.match(gate.failures[0].reason, /unconditionally/);
  assert.strictEqual(gate.exempt.length, 0);
});

test("a NEW compact parent whose allow shares a line with a child fails the gate", () => {
  const source = wrap(
    [
      "    match /p/{pid} {",
      "      match /c/{cid} { allow read: if request.auth != null; } allow read, write: if true;",
      "    }",
    ].join("\n"),
  );
  const gate = gateOver(
    source,
    [["/p/{pid}", { exprTotal: 2, exprHit: 2 }]],
    ["/p/{pid}"],
  );
  assert.strictEqual(gate.failures.length, 1);
  assert.match(gate.failures[0].path, /\/p\/\{pid\}$/);
});

test("the untested-block number is report-only by decision (BUT-1708)", () => {
  assert.strictEqual(UNTESTED_BLOCK_POLICY, "report-only");
});

// ── newBlockPaths (the base-vs-head diff the whole gate stands on) ─────────
//
// Every gate test above hand-feeds `newPaths`. This is where that set is
// actually computed — and where a false positive would fail an author for a
// block they only re-indented, which is how a gate gets disabled.

const diffOver = (baseBody, headBody, base = "abc123") =>
  newBlockPaths({
    base,
    baseSource: baseBody === null ? null : wrap(baseBody),
    blocks: parseMatchBlocks(wrap(headBody)),
  });

test("a re-indented, moved and reformatted block is NOT new", () => {
  const before = [
    "    match /a/{id} {",
    "      allow read: if request.auth != null;",
    "    }",
    "    match /b/{id} {",
    "      allow read: if request.auth != null;",
    "    }",
  ].join("\n");
  const after = [
    "        match /b/{id} { allow read: if request.auth != null; }",
    "        match",
    "          /a/{id}",
    "        {",
    "          allow read: if request.auth != null;",
    "        }",
  ].join("\n");
  const { newPaths, note } = diffOver(before, after);
  assert.deepStrictEqual([...newPaths], []);
  assert.match(note, /Gate active against base `abc123`: 0 new match block\(s\)/);
});

test("a genuinely added block is the only entry in the diff", () => {
  const before = "    match /a/{id} { allow read: if request.auth != null; }";
  const after = [
    "    match /a/{id} { allow read: if request.auth != null; }",
    "    match /leaky/{id} { allow read, write: if true; }",
  ].join("\n");
  const { newPaths } = diffOver(before, after);
  assert.deepStrictEqual(
    [...newPaths],
    ["/databases/{database}/documents/leaky/{id}"],
  );
});

test("a renamed path counts as new (the old path simply disappears)", () => {
  const { newPaths } = diffOver(
    "    match /old/{id} { allow read: if request.auth != null; }",
    "    match /renamed/{id} { allow read: if request.auth != null; }",
  );
  assert.deepStrictEqual(
    [...newPaths],
    ["/databases/{database}/documents/renamed/{id}"],
  );
});

test("no base, and an unreadable base, SKIP the gate rather than diff against nothing", () => {
  const body = "    match /a/{id} { allow read: if request.auth != null; }";
  const noBase = newBlockPaths({
    base: null,
    baseSource: null,
    blocks: parseMatchBlocks(wrap(body)),
  });
  assert.strictEqual(noBase.newPaths, null);
  assert.match(noBase.note, /no --base revision supplied/);

  const unreadable = diffOver(null, body);
  assert.strictEqual(unreadable.newPaths, null, "null must not read as 'nothing new'");
  assert.match(unreadable.note, /could not read firestore\.rules at base/);
});

// ── coverage payload walker ───────────────────────────────────────────────

test("a node with no `values` key counts as never evaluated; counts otherwise sum", () => {
  const payload = {
    report: [
      { sourcePosition: { line: 10, column: 3 } },
      {
        sourcePosition: { line: 20, column: 5 },
        values: [{ count: 2 }, { count: 3 }],
      },
    ],
  };
  const nodes = [];
  collectExprNodes(payload, nodes);
  assert.strictEqual(nodes.length, 2);
  assert.strictEqual(nodes.find((n) => n.line === 10).count, 0);
  assert.strictEqual(nodes.find((n) => n.line === 20).count, 5);
});

test("the walker never invents nodes out of evaluated `values` payloads", () => {
  const payload = {
    report: [
      {
        sourcePosition: { line: 7, column: 1 },
        values: [{ value: { sourcePosition: { line: 999 } }, count: 1 }],
        children: [{ sourcePosition: { line: 8, column: 1 }, values: [{ count: 1 }] }],
      },
    ],
  };
  const nodes = [];
  collectExprNodes(payload, nodes);
  assert.deepStrictEqual(nodes.map((n) => n.line).sort((a, b) => a - b), [7, 8]);
});

test("attribution picks the innermost containing block", () => {
  const blocks = [
    { path: "/a", startLine: 1, endLine: 100 },
    { path: "/a/b", startLine: 10, endLine: 50 },
    { path: "/a/b/c", startLine: 20, endLine: 30 },
  ];
  assert.strictEqual(innermostBlock(blocks, 25).path, "/a/b/c");
  assert.strictEqual(innermostBlock(blocks, 40).path, "/a/b");
  assert.strictEqual(innermostBlock(blocks, 60).path, "/a");
  assert.strictEqual(innermostBlock(blocks, 200), null);
});

// ── CI wiring the gate depends on ─────────────────────────────────────────
//
// The gate is only as good as the base revision it diffs against: a shallow
// clone or a missing --base turns it into a no-op that still prints green.

const workflow = fs.readFileSync(RULES_WORKFLOW, "utf8");

test("the rules workflow checks out full history (fetch-depth: 0)", () => {
  assert.match(
    workflow,
    /uses:\s*actions\/checkout@[^\n]*\n\s*with:\s*\n\s*fetch-depth:\s*0/,
    "the coverage gate needs full history to resolve the base revision; a shallow clone silently skips it",
  );
});

test("the coverage step passes --base when a base SHA is available", () => {
  assert.match(workflow, /rules-coverage-report\.js[^\n]*--base "\$BASE_SHA"/);
  assert.match(
    workflow,
    /BASE_SHA:\s*\$\{\{[^}]*pull_request\.base\.sha[^}]*github\.event\.before[^}]*\}\}/,
    "BASE_SHA must come from the PR base on pull_request and from the previous tip on push",
  );
  assert.match(
    workflow,
    /BASE_SHA[\s\S]*?!=\s*"0{40}"/,
    "the all-zero SHA of a first push must fall through to the ungated invocation, not be passed as a base",
  );
});

test("coverage is read while the emulator is still up", () => {
  const coverageAt = workflow.indexOf("node scripts/rules-coverage-report.js");
  const stopAt = workflow.indexOf("- name: Stop emulator");
  assert.ok(coverageAt > 0 && stopAt > 0);
  assert.ok(
    coverageAt < stopAt,
    "the :ruleCoverage report dies with the emulator — the gate must run before it is stopped",
  );
});

// ── report ────────────────────────────────────────────────────────────────

const failed = results.filter((r) => !r.ok);
for (const result of results) {
  console.log(`${result.ok ? "PASS" : "FAIL"}  ${result.name}`);
  if (!result.ok) console.error(`      ${result.err.message}`);
}
console.log(
  `\nrules-coverage-report.test: ${results.length - failed.length}/${results.length} passed.`,
);
if (failed.length > 0) process.exit(1);
