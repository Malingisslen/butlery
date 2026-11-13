/**
 * BUT-1520 condition C8: the adversarial precision set for the pool key, run
 * against the TS authority. Reads the SAME fixture as
 * test/unit/services/rating/canonical_pool_key_adversarial_test.dart.
 *
 * A case marked `known_gap` is pinned to its measured behaviour, so fixing the
 * key turns it red and the fixture entry must drop `known_gap`.
 *
 * Run with: npx ts-node src/__tests__/pool-key-adversarial.test.ts
 */

import * as fs from "fs";
import * as path from "path";
import { computePoolKey } from "../ratings/canonical-pool-key";

interface Recipe {
  title: string;
  ingredients: string[];
}

interface DistinctCase {
  class: string;
  why: string;
  a: Recipe;
  b: Recipe;
  known_gap?: string;
}

interface NoPoolCase {
  class: string;
  why: string;
  recipe: Recipe;
  known_gap?: string;
}

interface SamePoolCase {
  class: string;
  why: string;
  a: Recipe;
  b: Recipe;
}

interface Fixture {
  classes: string[];
  distinct: DistinctCase[];
  must_not_pool: NoPoolCase[];
  must_pool: SamePoolCase[];
}

const key = (r: Recipe): string | null =>
  computePoolKey(r.title, r.ingredients);

function run(): void {
  const fixturePath = path.join(
    __dirname,
    "..",
    "..",
    "..",
    "test",
    "fixtures",
    "pool_key_adversarial.json",
  );
  const fixture: Fixture = JSON.parse(fs.readFileSync(fixturePath, "utf-8"));
  if (
    !fixture.classes?.length ||
    !fixture.distinct?.length ||
    !fixture.must_not_pool?.length ||
    !fixture.must_pool?.length
  ) {
    console.error(
      "pool_key_adversarial.json has an empty section; refusing to pass vacuously",
    );
    process.exit(1);
  }
  const failures: string[] = [];
  let checks = 0;
  const isGap = (c: { known_gap?: unknown }): boolean =>
    typeof c.known_gap === "string";

  const covered = new Set([
    ...[...fixture.distinct, ...fixture.must_not_pool]
      .filter((c) => !isGap(c))
      .map((c) => c.class),
    ...fixture.must_pool.map((c) => c.class),
  ]);
  checks++;
  for (const cls of fixture.classes) {
    if (!covered.has(cls))
      failures.push(`class ${cls} has no case outside the known gaps`);
  }
  for (const c of [
    ...fixture.distinct,
    ...fixture.must_not_pool,
    ...fixture.must_pool,
  ]) {
    if (!fixture.classes.includes(c.class))
      failures.push(`${c.why}: undeclared class ${c.class}`);
  }

  for (const c of fixture.distinct) {
    checks++;
    const a = key(c.a);
    const b = key(c.b);
    if (isGap(c)) {
      if (a === null || a !== b) {
        failures.push(`${c.class}: ${c.why}: gap fixed? drop known_gap`);
      }
    } else if (a !== null && a === b) {
      failures.push(`${c.class}: ${c.why}: false merge on ${a}`);
    }
  }

  for (const c of fixture.must_not_pool) {
    checks++;
    const k = key(c.recipe);
    if (isGap(c)) {
      if (k === null)
        failures.push(`${c.class}: ${c.why}: gap fixed? drop known_gap`);
    } else if (k !== null) {
      failures.push(`${c.class}: ${c.why}: pools as ${k}, must fail closed`);
    }
  }

  for (const c of fixture.must_pool) {
    checks++;
    const a = key(c.a);
    const b = key(c.b);
    if (a === null || a !== b) {
      failures.push(`${c.class}: ${c.why}: ${a} vs ${b}, must share a key`);
    }
  }

  if (failures.length > 0) {
    console.error("FAILURES:");
    failures.forEach((f) => console.error(`  ${f}`));
    process.exit(1);
  }
  console.log(`Pool-key adversarial set (C8): ${checks}/${checks} passed`);
}

run();
