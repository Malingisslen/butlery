// Admin-vy D (tasks/admin-vy-cd-plan.md, condition 11): the tagging word
// lists are compiled into the app, and recipes are re-tagged only when
// kTagGeneratorVersion changes. The word-list PRs the admin view opens do not
// raise the version, so an app release must not ship a changed word list
// without it: this check refuses a ref whose occasions.json differs from the
// one at the last commit that changed kTagGeneratorVersion.
//
// Usage (repository root, full history):
//   node tools/release/check_tag_version_bump.mjs [<ref>]     default HEAD
// Exit 0: allowed. Exit 1: word lists changed since the last version change.
// Exit 2: the check could not run (no such ref, history too shallow).

import { execFileSync } from 'node:child_process';
import { pathToFileURL } from 'node:url';

export const WORD_LISTS = 'lib/services/tagging/config/data/occasions.json';
export const VERSION_FILE = 'lib/services/tagging/tag_generator.dart';
const VERSION_LINE = 'kTagGeneratorVersion = ';

function git(args, cwd) {
  return execFileSync('git', args, { cwd, encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'] }).trim();
}

/** Returns { ok, code, message }; never exits, so tests can call it. */
export function checkTagVersionBump(ref = 'HEAD', cwd = process.cwd()) {
  let target;
  try {
    target = git(['rev-parse', '--verify', `${ref}^{commit}`], cwd);
  } catch {
    return { ok: false, code: 2, message: `No commit named ${ref}.` };
  }
  const bump = git(['log', '-1', '--format=%H', `-G${VERSION_LINE}`, target, '--', VERSION_FILE], cwd);
  if (!bump) {
    return {
      ok: false,
      code: 2,
      message: `No commit changing ${VERSION_LINE.trim()} in the history of ${ref}. Fetch the full history.`,
    };
  }
  const changed = git(['diff', '--name-only', bump, target, '--', WORD_LISTS], cwd);
  if (changed) {
    return {
      ok: false,
      code: 1,
      message:
        `${WORD_LISTS} changed after the last kTagGeneratorVersion change (${bump.slice(0, 9)}). ` +
        `Raise kTagGeneratorVersion in ${VERSION_FILE} before releasing, so the app re-tags recipes ` +
        'with the new word lists.',
    };
  }
  return { ok: true, code: 0, message: `${WORD_LISTS} is unchanged since the last kTagGeneratorVersion change.` };
}

if (import.meta.url === pathToFileURL(process.argv[1]).href) {
  const result = checkTagVersionBump(process.argv[2] ?? 'HEAD');
  (result.ok ? console.log : console.error)(result.message);
  process.exit(result.code);
}
