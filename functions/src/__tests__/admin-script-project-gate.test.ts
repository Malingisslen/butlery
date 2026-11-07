/**
 * BUT-2419 recurrence guard: a hand-run script that opens firebase-admin must
 * pass the project gate first, so a script written tomorrow cannot silently
 * inherit whichever project the operator's credentials point at.
 *
 * Reads the code (comments stripped) of every script file that opens
 * firebase-admin and requires the project id to come from `requireProject`.
 * The exceptions are named with the reason each is safe.
 *
 * Run: ts-node src/__tests__/admin-script-project-gate.test.ts
 */

import * as fs from "fs";
import * as path from "path";

const FUNCTIONS_ROOT = path.resolve(__dirname, "..", "..");

const EXEMPT: Readonly<Record<string, string>> = {
  "scripts/seed-emulator.js":
    "refuses unless FIRESTORE_EMULATOR_HOST is set and the project id is demo-*",
  "src/admin/golden-recipe-from-url.ts":
    "requires an explicit GOOGLE_CLOUD_PROJECT and only reads system/config next to its Vertex calls",
  "src/admin/reset-scheduler-pause.ts":
    "library, only constructed by reset-user-data.ts after its initializeAdminApp gate",
  "src/admin/admin-init.ts": "is the single initializer that calls the gate",
};

function stripComments(text: string): string {
  return text.replace(/\/\*[\s\S]*?\*\//g, "").replace(/(^|[^:"'`])\/\/.*$/gm, "$1");
}

function listSources(dir: string): string[] {
  const out: string[] = [];
  for (const entry of fs.readdirSync(path.join(FUNCTIONS_ROOT, dir), { withFileTypes: true })) {
    if (entry.name === "__tests__" || entry.name === "node_modules") continue;
    const rel = `${dir}/${entry.name}`;
    if (entry.isDirectory()) out.push(...listSources(rel));
    else if (/\.(js|cjs|mjs|ts)$/.test(entry.name)) out.push(rel);
  }
  return out;
}

const OPENS_ADMIN = /\binitializeApp\s*\(|\bnew\s+(Firestore|GoogleAuth)\s*\(/;

function readCode(rel: string): string {
  return stripComments(fs.readFileSync(path.join(FUNCTIONS_ROOT, rel), "utf8"));
}

/**
 * True when every init either calls the gate in its own arguments or follows
 * an earlier gate call, and hands the project id to the SDK.
 */
function initCalls(code: string): { at: number; args: string }[] {
  const calls: { at: number; args: string }[] = [];
  for (const m of code.matchAll(/\binitializeApp\s*\(/g)) {
    const open = (m.index ?? 0) + m[0].length;
    let depth = 1;
    let i = open;
    for (; i < code.length && depth > 0; i++) {
      if (code[i] === "(") depth++;
      else if (code[i] === ")") depth--;
    }
    calls.push({ at: m.index ?? 0, args: code.slice(open, i - 1) });
  }
  return calls;
}

export function gatedBeforeInit(code: string): boolean {
  const gateAt = code.search(/\brequireProject\s*\(/);
  const inits = initCalls(code);
  return (
    inits.length > 0 &&
    !/\bnew\s+(Firestore|GoogleAuth)\s*\(/.test(code) &&
    inits.every((call) => {
      const inline = /\brequireProject\s*\(/.test(call.args);
      const before = gateAt >= 0 && gateAt < call.at;
      if (!(inline || before)) return false;
      const value = /\bprojectId\s*:\s*([A-Za-z_$][\w$]*)\s*(\(|[,}\s]|$)/.exec(call.args);
      if (value === null) return false;
      if (value[1] === "requireProject") return true;
      const from = new RegExp(`\\b${value[1]}\\s*=\\s*requireProject\\s*\\(`);
      return from.test(code);
    })
  );
}

let failed = 0;
function assert(cond: boolean, msg: string): void {
  if (cond) {
    console.log(`  PASS  ${msg}`);
  } else {
    failed++;
    console.log(`  FAIL  ${msg}`);
  }
}

const GOOD = `const { requireProject } = require("x");\nadmin.initializeApp({ projectId: requireProject() });`;
assert(gatedBeforeInit(GOOD), "self-check: a gated init passes");
assert(!gatedBeforeInit(`admin.initializeApp();`), "self-check: a bare init fails");
assert(
  !gatedBeforeInit(`const { requireProject } = require("x");\nadmin.initializeApp();`),
  "self-check: the require without its use fails",
);
assert(
  !gatedBeforeInit(`// requireProject() is not needed\nadmin.initializeApp();`),
  "self-check: a comment naming the gate fails",
);
assert(
  !gatedBeforeInit(`requireProject();\nadmin.initializeApp({ projectId: "butlery-prod" });`),
  "self-check: a hardcoded project id fails",
);
assert(
  gatedBeforeInit(`const P = requireProject();\nadmin.initializeApp({ projectId: P });`),
  "self-check: an id taken from the gate passes",
);
assert(
  !gatedBeforeInit(`admin.initializeApp({ projectId: p });\nrequireProject();`),
  "self-check: a gate called after the init fails",
);

const initializers = [...listSources("scripts"), ...listSources(path.join("src", "admin"))]
  .map((rel) => rel.split(path.sep).join("/"))
  .filter((rel) => OPENS_ADMIN.test(readCode(rel)))
  .sort();
assert(initializers.length >= 8, `found the scripts that open firebase-admin (${initializers.length})`);

for (const rel of initializers) {
  if (rel in EXEMPT) continue;
  assert(gatedBeforeInit(readCode(rel)), `${rel} calls requireProject and passes it to initializeApp`);
}

for (const rel of Object.keys(EXEMPT)) {
  assert(initializers.includes(rel), `exemption ${rel} is still needed (it opens firebase-admin)`);
}

if (failed > 0) {
  console.log(`\n${failed} failed`);
  process.exit(1);
}
console.log("\nall passed");
