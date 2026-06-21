/**
 * BUT-1167 (AI8): prompt-changelog drift guard.
 *
 * A CI gate that fails when an LLM prompt in `gemini-client.ts` changes
 * without a matching update to `PROMPT_CHANGELOG.md`. The changelog's own
 * rule (top of that file) is: "Bump PROMPT_VERSION in gemini-client.ts and
 * add an entry here in the same commit." Humans forget; this enforces it.
 *
 * This module is the PURE, unit-testable core. It takes the list of changed
 * files and the unified diff of `gemini-client.ts`, and returns an error
 * message (or null). It does no git / filesystem / process work — the CLI
 * wrapper (`prompt-changelog-guard-cli.ts`) computes the inputs and exits.
 *
 * Run the tests with:
 *   npx ts-node src/__tests__/prompt-changelog-guard.test.ts
 */

/** Path (repo-relative, forward slashes) of the file holding the prompts. */
export const GEMINI_CLIENT_PATH = "functions/src/llm/gemini-client.ts";

/** Path (repo-relative, forward slashes) of the changelog that must be updated. */
export const PROMPT_CHANGELOG_PATH = "functions/src/llm/PROMPT_CHANGELOG.md";

/**
 * Tokens that mark a line as "prompt-related". A changed (added or removed)
 * line in the gemini-client diff that mentions any of these is treated as a
 * prompt edit:
 *   - `PROMPT_VERSION` — the version constant.
 *   - `_SYSTEM_PROMPT` — matches every `*_SYSTEM_PROMPT` constant
 *     (RECIPE_EXTRACTION, RECIPE_ENHANCEMENT, IMAGE_OCR, SPOKEN_CONTENT,
 *     INGREDIENT_LINE) without enumerating them, so a new prompt constant
 *     is covered automatically.
 *   - `INJECTION_DEFENSE` — the shared anti-prompt-injection preamble that
 *     is interpolated into every system prompt; editing it changes all five.
 */
export const PROMPT_TOKENS = [
  "PROMPT_VERSION",
  "_SYSTEM_PROMPT",
  "INJECTION_DEFENSE",
] as const;

/**
 * Normalise a path to repo-relative, forward-slash form so callers can pass
 * Windows backslash paths or absolute paths and still match the constants.
 */
function normalize(p: string): string {
  return p.replace(/\\/g, "/");
}

function isPath(changedFiles: string[], target: string): boolean {
  return changedFiles.some((f) => normalize(f).endsWith(target));
}

/**
 * Scan a unified diff for added/removed lines that touch a prompt token.
 *
 * A unified-diff body line starts with `+` (added), `-` (removed), or ` `
 * (context). We only care about `+`/`-` lines — context lines are unchanged
 * and must NOT trip the guard (otherwise any edit near a prompt would
 * false-positive). The `+++`/`---` file headers are excluded explicitly so a
 * diff whose header path contains `gemini-client.ts` doesn't self-trigger.
 */
function hunkContext(line: string): string {
  const m = /^@@ .* @@(.*)$/.exec(line);
  return m ? m[1] : "";
}

function hasPromptToken(text: string): boolean {
  return PROMPT_TOKENS.some((tok) => text.includes(tok));
}

/**
 * Scan a unified diff for a prompt-related change. Two signals trip it:
 *
 *   1. A changed line (`+`/`-`, not a file header) mentions a prompt token —
 *      catches version bumps, constant declarations, and INJECTION_DEFENSE
 *      edits.
 *   2. A hunk whose enclosing-declaration context (the text git appends after
 *      `@@ ... @@`, e.g.
 *      `@@ -252,7 +252,7 @@ export const RECIPE_EXTRACTION_SYSTEM_PROMPT = ...`)
 *      mentions a prompt token AND that hunk changes a line — catches edits
 *      to the interior body text of a prompt template literal. That is the
 *      most important case (the proximate cause of parse-quality drift) yet
 *      the changed line itself carries no token.
 *
 * Context lines (` ` prefix) and the `+++`/`---` file headers never trip the
 * guard on their own, so an unrelated edit merely sitting near a prompt does
 * not false-positive.
 */
export function diffTouchesPrompt(geminiClientDiff: string): boolean {
  const lines = geminiClientDiff.split(/\r?\n/);
  let currentHunkContextHasToken = false;

  for (const line of lines) {
    if (line.startsWith("+++") || line.startsWith("---")) continue;

    if (line.startsWith("@@")) {
      currentHunkContextHasToken = hasPromptToken(hunkContext(line));
      continue;
    }

    const isAddedOrRemoved =
      (line.startsWith("+") || line.startsWith("-")) && line.length > 1;
    if (!isAddedOrRemoved) continue;

    // Signal 1: the changed line itself names a prompt token.
    if (hasPromptToken(line)) return true;
    // Signal 2: the changed line is inside a prompt declaration's hunk.
    if (currentHunkContextHasToken) return true;
  }
  return false;
}

/**
 * Core gate. Returns a human-readable violation message, or null if clean.
 *
 * Decision table:
 *   1. gemini-client.ts not in changedFiles            -> null (file untouched)
 *   2. gemini-client.ts touched, but diff has no prompt
 *      token on any +/- line (e.g. a token-count helper) -> null (non-prompt edit)
 *   3. prompt-related change present AND changelog NOT
 *      in changedFiles                                  -> VIOLATION
 *   4. prompt-related change present AND changelog updated -> null (ok)
 *
 * @param changedFiles repo-relative paths of every file in the diff/commit.
 * @param geminiClientDiff unified diff for gemini-client.ts (may be empty).
 */
export function promptChangelogViolation(
  changedFiles: string[],
  geminiClientDiff: string
): string | null {
  if (!isPath(changedFiles, GEMINI_CLIENT_PATH)) {
    return null;
  }

  if (!diffTouchesPrompt(geminiClientDiff)) {
    return null;
  }

  if (isPath(changedFiles, PROMPT_CHANGELOG_PATH)) {
    return null;
  }

  return [
    "Prompt-changelog gate failed (BUT-1167 / AI8).",
    "",
    `A prompt-related change was detected in ${GEMINI_CLIENT_PATH}`,
    "(PROMPT_VERSION, a *_SYSTEM_PROMPT constant, or INJECTION_DEFENSE),",
    `but ${PROMPT_CHANGELOG_PATH} was not updated in the same change.`,
    "",
    "Rule (see top of PROMPT_CHANGELOG.md): bump PROMPT_VERSION in",
    "gemini-client.ts AND add a matching entry to PROMPT_CHANGELOG.md in the",
    "same commit, so parse-quality regressions can be correlated to the exact",
    "prompt edit.",
    "",
    `Fix: add an entry to ${PROMPT_CHANGELOG_PATH} describing what changed,`,
    "why, and the expected metric impact.",
  ].join("\n");
}
