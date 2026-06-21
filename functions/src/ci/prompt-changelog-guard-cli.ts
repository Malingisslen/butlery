/**
 * BUT-1167 (AI8): CLI wrapper for the prompt-changelog gate.
 *
 * Computes the inputs from git, then calls the pure
 * `promptChangelogViolation` core. Exits 1 on violation (printing the
 * message), 0 otherwise.
 *
 * Diff base resolution:
 *   - The workflow passes the base ref as the first CLI arg (the PR base for
 *     pull_request events, `HEAD^` for push events). We compute the merge-base
 *     against that ref so the comparison is "what this branch/commit adds on
 *     top of the base", not a noisy three-dot range.
 *   - If no arg is given, falls back to `HEAD^` (last commit) — useful for a
 *     local pre-commit check.
 *
 * Paths from `git diff --name-only` are already repo-relative with forward
 * slashes, which is exactly what the core expects.
 *
 * Run after build as: node lib/ci/prompt-changelog-guard-cli.js <base-ref>
 * Or directly:        npx ts-node src/ci/prompt-changelog-guard-cli.ts <base-ref>
 */

import { execFileSync } from "child_process";
import {
  promptChangelogViolation,
  GEMINI_CLIENT_PATH,
} from "./prompt-changelog-guard";

function git(args: string[]): string {
  return execFileSync("git", args, { encoding: "utf8" });
}

/**
 * Resolve the commit to diff against. Prefer the merge-base with the provided
 * base ref so we only see this branch's own changes. Fall back to HEAD^.
 */
function resolveBase(baseArg: string | undefined): string {
  if (baseArg && baseArg.trim()) {
    const base = baseArg.trim();
    try {
      return git(["merge-base", base, "HEAD"]).trim();
    } catch {
      // base ref not fetched / unknown — fall through to HEAD^.
    }
  }
  return "HEAD^";
}

function main(): void {
  const base = resolveBase(process.argv[2]);

  let changedFiles: string[];
  try {
    changedFiles = git(["diff", "--name-only", base, "HEAD"])
      .split(/\r?\n/)
      .map((l) => l.trim())
      .filter((l) => l.length > 0);
  } catch (err) {
    console.error(
      `prompt-changelog-guard: failed to compute changed files against "${base}".`
    );
    console.error(err instanceof Error ? err.message : String(err));
    // Fail loud rather than silently passing — a broken gate is worse than red.
    process.exit(1);
    return;
  }

  // Only fetch the (potentially large) diff for the one file we care about.
  let geminiClientDiff = "";
  if (changedFiles.some((f) => f.endsWith(GEMINI_CLIENT_PATH))) {
    try {
      geminiClientDiff = git([
        "diff",
        base,
        "HEAD",
        "--",
        GEMINI_CLIENT_PATH,
      ]);
    } catch (err) {
      console.error(
        `prompt-changelog-guard: failed to diff ${GEMINI_CLIENT_PATH}.`
      );
      console.error(err instanceof Error ? err.message : String(err));
      process.exit(1);
      return;
    }
  }

  const violation = promptChangelogViolation(changedFiles, geminiClientDiff);
  if (violation) {
    console.error(violation);
    process.exit(1);
    return;
  }

  console.log("prompt-changelog-guard: OK (no un-logged prompt change).");
}

main();
