/**
 * Every collection in firestore.rules, and every collection the functions
 * open with `.collection(...)`, is either reached by the account-deletion
 * code, has a TTL policy, or is named in UNREVIEWED below. The second source
 * is there because a collection only the Admin SDK writes may have no rules
 * block.
 *
 * erasure-export-coverage.test.ts reads the step labels of
 * request-account-deletion.ts, so a new collection holding a user's id that no
 * step touches passes it. This test starts from the collections instead.
 *
 * "Reached" means the collection's name (as a string literal, or through its
 * `Collections.<key>` constant) appears in the cascade, the auth-delete
 * trigger or the moderation code. That proves a mention, not that the mention
 * deletes the right rows.
 *
 * UNREVIEWED is a list of names nobody has yet decided on. An entry leaves it
 * by being handled in code or by being replaced with a recorded decision; it
 * must not be added to just to get green.
 *
 * Run with: npx ts-node src/__tests__/erasure-collection-coverage.test.ts
 */

import * as fs from "fs";
import * as path from "path";

const REPO = path.resolve(__dirname, "../../..");
const FUNCTIONS_SRC = path.resolve(__dirname, "..");

const UNREVIEWED: Record<string, string> = {
  _internal: "not looked at",
  admins: "admin accounts; holds the admin's own uid",
  audit: "not looked at",
  butlery_archive: "read-only catalog per the rules; not looked at for user ids",
  canonical_recipe_stats: "aggregate; not looked at for user ids",
  connectivity_test: "not looked at",
  ingredient_substitutions: "not looked at",
  menu_lexicon: "not looked at",
  menu_templates: "rules mention ownerId; no writer found in functions/src",
  metrics: "aggregate; not looked at for user ids",
  notification_metrics: "aggregate; not looked at for user ids",
  recipe_social_stats: "aggregate; not looked at for user ids",
  site_configs: "not looked at",
  admin_audit_logs: "adminUid field (bulk-retag.ts); an admin's own uid, like admins",
  admin_rate_limits: "admin uid in the document id and the adminUid field (bulk-retag.ts)",
  corrections: "analytics/parsing/corrections: per-domain counters, no user id field",
  group_invitations: "fromUserId; on-profile-updated.ts only renames, account deletion does not reach it",
  group_moves: "holds only movedAt per group id (hand-over-group.ts)",
  snapshots: "not looked at",
  summary: "not looked at",
  unmatched: "analytics/ingredients/unmatched: ingredient text and example recipe ids, no user id field",
  weekly: "not looked at",
};

function walk(dir: string, out: string[] = []): string[] {
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) walk(full, out);
    else if (entry.name.endsWith(".ts")) out.push(full);
  }
  return out;
}

function rulesCollections(): string[] {
  const rules = fs.readFileSync(path.join(REPO, "firestore.rules"), "utf8");
  const names = new Set<string>();
  for (const m of rules.matchAll(/^ {4}match \/([A-Za-z0-9_-]+)\/\{/gm)) {
    names.add(m[1]);
  }
  return [...names].sort();
}

/**
 * Names the functions pass to `.collection()` or `.collectionGroup()`: a
 * literal, a `Collections.<key>` constant, or an upper-case `const` holding a
 * literal (the file's own first, then one from any file). `.doc()`
 * names are not collections and are left out.
 */
function functionsCollections(keyToName: Map<string, string>): string[] {
  const CONST_RE =
    /\b(?:export\s+)?const\s+([A-Z][A-Z0-9_]*)(?:\s*:\s*string)?\s*=\s*["'`]([A-Za-z0-9_]+)["'`]/g;
  const texts = walk(FUNCTIONS_SRC)
    .filter((f) => !f.includes("__tests__"))
    .map((f) => fs.readFileSync(f, "utf8"));
  const anyFile = new Map<string, string>();
  for (const text of texts) {
    for (const m of text.matchAll(CONST_RE)) {
      if (!anyFile.has(m[1])) anyFile.set(m[1], m[2]);
    }
  }
  const names = new Set<string>();
  for (const text of texts) {
    const ownFile = new Map<string, string>(
      [...text.matchAll(CONST_RE)].map((m) => [m[1], m[2]] as [string, string])
    );
    for (const m of text.matchAll(/\.collection(?:Group)?\(\s*["'`]([A-Za-z0-9_]+)["'`]/g)) {
      names.add(m[1]);
    }
    for (const m of text.matchAll(/\.collection(?:Group)?\(\s*Collections\.([A-Za-z0-9_]+)\b/g)) {
      const name = keyToName.get(m[1]);
      if (name) names.add(name);
    }
    for (const m of text.matchAll(/\.collection(?:Group)?\(\s*([A-Z][A-Z0-9_]*)\s*[,)]/g)) {
      const name = ownFile.get(m[1]) ?? anyFile.get(m[1]);
      if (name) names.add(name);
    }
  }
  return [...names].sort();
}

function collectionKeys(): Map<string, string> {
  const src = fs.readFileSync(
    path.join(FUNCTIONS_SRC, "shared/collections.ts"),
    "utf8"
  );
  const keyOf = new Map<string, string>();
  for (const m of src.matchAll(/^ {2}([A-Za-z0-9_]+):\s*"([A-Za-z0-9_]+)"/gm)) {
    keyOf.set(m[2], m[1]);
  }
  return keyOf;
}

function deletionSource(): string {
  const roots = [
    path.join(FUNCTIONS_SRC, "account"),
    path.join(FUNCTIONS_SRC, "moderation"),
  ];
  const files = roots.flatMap((r) => walk(r));
  files.push(path.join(FUNCTIONS_SRC, "cleanup/on-user-deleted.ts"));
  return files.map((f) => fs.readFileSync(f, "utf8")).join("\n");
}

function ttlGroups(): Set<string> {
  const idx = JSON.parse(
    fs.readFileSync(path.join(REPO, "firestore.indexes.json"), "utf8")
  ) as { fieldOverrides?: Array<{ collectionGroup: string; ttl?: boolean }> };
  return new Set(
    (idx.fieldOverrides ?? [])
      .filter((o) => o.ttl === true)
      .map((o) => o.collectionGroup)
  );
}

function main(): void {
  const keyOf = collectionKeys();
  const keyToName = new Map([...keyOf].map(([name, key]) => [key, name]));
  const fromRules = rulesCollections();
  const fromFunctions = functionsCollections(keyToName);
  const cols = [...new Set([...fromRules, ...fromFunctions])].sort();
  const src = deletionSource();
  const ttl = ttlGroups();
  const failures: string[] = [];

  if (fromRules.length < 30) {
    failures.push(
      `only ${fromRules.length} collections read from firestore.rules; the pattern no longer matches the file`
    );
  }

  const functionsOnly = fromFunctions.filter((n) => !fromRules.includes(n));
  if (functionsOnly.length < 8) {
    failures.push(
      `only ${functionsOnly.length} collections found in functions/src that firestore.rules lacks; the patterns no longer match the source`
    );
  }

  const handled = (name: string): boolean => {
    if (ttl.has(name)) return true;
    if (new RegExp(`["'\`]${name}["'\`/]`).test(src)) return true;
    const key = keyOf.get(name);
    return key !== undefined && new RegExp(`Collections\\.${key}\\b`).test(src);
  };

  for (const name of cols) {
    const listed = name in UNREVIEWED;
    if (!handled(name) && !listed) {
      failures.push(
        `${name}: a collection in firestore.rules or functions/src, not reached by account deletion, not under a TTL policy, and not in UNREVIEWED. If its documents carry a user id, add the deletion; if they never can, say so in UNREVIEWED.`
      );
    }
    if (handled(name) && listed) {
      failures.push(
        `${name}: is now handled in code or under a TTL policy; remove it from UNREVIEWED`
      );
    }
  }
  for (const name of Object.keys(UNREVIEWED)) {
    if (!cols.includes(name)) {
      failures.push(`${name}: in UNREVIEWED but no longer in firestore.rules or functions/src`);
    }
  }

  if (failures.length > 0) {
    console.error(failures.join("\n"));
    process.exit(1);
  }
  console.log(
    `erasure-collection-coverage: ${cols.length} collections, ${Object.keys(UNREVIEWED).length} unreviewed`
  );
}

main();
