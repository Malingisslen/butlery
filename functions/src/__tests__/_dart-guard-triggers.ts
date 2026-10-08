/**
 * BUT-2002. A guard that reads Dart is only as live as its CI trigger, and that
 * trigger lived in a different file with nothing tying the two together.
 *
 * Ranges over the files the caller actually opened, so it answers "will CI run
 * this scenario when one of its own inputs changes" rather than "does the
 * workflow contain some strings someone once typed".
 *
 * Checks `push` AND `pull_request` separately: they are two independent lists in
 * that file, and a fix applied to one is the obvious half-miss.
 */
export function assertGuardTriggersCoverItsDartInputs(
  repoRoot: string,
  dartInputsAbsolute: string[],
  check: (name: string, condition: boolean, reason?: string) => void,
): void {
  // eslint-disable-next-line @typescript-eslint/no-require-imports
  const fs = require("fs");
  // eslint-disable-next-line @typescript-eslint/no-require-imports
  const path = require("path");

  const workflowRelative = ".github/workflows/cloud-functions-unit.yml";
  const workflowPath = path.join(repoRoot, workflowRelative);
  check(
    "the guard can find its own CI workflow",
    fs.existsSync(workflowPath),
    `missing: ${workflowRelative}`,
  );
  if (!fs.existsSync(workflowPath)) return;
  const workflow = fs.readFileSync(workflowPath, "utf8") as string;

  /** The quoted entries under one `paths:` block, comments stripped. */
  const pathsUnder = (trigger: string): string[] => {
    const at = workflow.indexOf(`  ${trigger}:`);
    if (at < 0) return [];
    const pathsAt = workflow.indexOf("paths:", at);
    if (pathsAt < 0) return [];
    // The block ends at the first line that is not a comment and not a `- `
    // entry — i.e. the next key at any indentation.
    const lines = workflow.slice(pathsAt).split("\n").slice(1);
    const entries: string[] = [];
    for (const line of lines) {
      const t = line.trim();
      if (t === "" || t.startsWith("#")) continue;
      if (!t.startsWith("- ")) break;
      entries.push(t.slice(2).trim().replace(/^["']|["']$/g, ""));
    }
    return entries;
  };

  // Only the two glob shapes this file actually uses: a literal path, and a
  // trailing `/**`. Deliberately not a general glob engine — an approximate
  // matcher that silently says "covered" is the failure mode being fixed.
  const covers = (pattern: string, file: string): boolean =>
    pattern.endsWith("/**")
      ? file.startsWith(pattern.slice(0, -2))
      : pattern === file;

  // A GitHub `!` exclusion is the one shape that would make this matcher say
  // "covered" while CI skipped the file: the negation reads as an unmatchable
  // literal here, and the positive glob beside it still matches. Refused for
  // the whole trigger rather than modelled, because getting exclusion ordering
  // subtly wrong is how an approximate matcher goes quiet again.
  const rejectsNegations = (trigger: string, patterns: string[]): void => {
    check(
      `the ${trigger} trigger uses no path exclusions this guard cannot read`,
      patterns.every((p) => !p.startsWith("!")),
      "a `!` entry excludes files from the trigger, and the positive globs " +
        "beside it would still report this guard's inputs as covered: " +
        JSON.stringify(patterns.filter((p) => p.startsWith("!"))),
    );
  };

  const relativeInputs = dartInputsAbsolute.map((p) =>
    path.relative(repoRoot, p).split(path.sep).join("/"),
  );
  check(
    "the guard's Dart inputs resolved to repo-relative paths",
    relativeInputs.every((p) => p.startsWith("lib/")),
    `expected lib/ paths, got ${JSON.stringify(relativeInputs)}`,
  );

  for (const trigger of ["push", "pull_request"]) {
    const patterns = pathsUnder(trigger);
    check(
      `the ${trigger} trigger's paths: block is readable`,
      patterns.length > 0,
      `parsed no entries under ${trigger}`,
    );
    rejectsNegations(trigger, patterns);
    const uncovered = relativeInputs.filter(
      (file) => !patterns.some((p) => covers(p, file)),
    );
    check(
      `every Dart file this guard reads re-runs it on ${trigger}`,
      uncovered.length === 0,
      "this scenario reads these files but CI would not run it when they " +
        `change, so the invariant is unguarded for exactly the edit most ` +
        `likely to break it: ${JSON.stringify(uncovered)}`,
    );
  }
}
