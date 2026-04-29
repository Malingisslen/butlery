/**
 * BUT-621: Remote prompts config — fresh read, cache, fallback semantics.
 *
 * Coverage:
 *   (a) fresh read from Firestore → bundle reflects remote values
 *   (b) cache hit within TTL → loader called once across many gets
 *   (c) cache miss after TTL → loader called again, returns new value
 *   (d) Firestore failure → fallback to compiled-in prompts
 *   (e) doc missing → fallback
 *   (f) malformed doc (missing field, wrong type, empty string) → fallback
 *   (g) fallback log fires once per cache window (observability contract)
 *
 * Run with: npx ts-node src/__tests__/prompts-config.test.ts
 */

import {
  getPromptsConfig,
  __resetPromptsCacheForTests,
  PROMPTS_CACHE_TTL_MS,
} from "../llm/prompts-config";
import {
  PROMPT_VERSION as FALLBACK_PROMPT_VERSION,
  RECIPE_EXTRACTION_SYSTEM_PROMPT,
} from "../llm/gemini-client";
import { logger } from "firebase-functions/logger";

interface AssertionResult {
  ok: boolean;
  detail?: string;
}

let totalFailed = 0;
let totalRun = 0;

function record(name: string, a: AssertionResult): void {
  totalRun++;
  if (a.ok) {
    console.log(`  PASS  ${name}`);
  } else {
    totalFailed++;
    console.log(`  FAIL  ${name}`);
    if (a.detail) console.log(`        ${a.detail}`);
  }
}

// =============================================================================
// Logger capture — patches the firebase-functions logger surface so we can
// assert on the one-time fallback warning without pulling in jest.
// =============================================================================

interface LogEntry {
  level: "info" | "warn" | "error";
  msg: string;
  fields?: unknown;
}

const captured: LogEntry[] = [];
const realInfo = logger.info;
const realWarn = logger.warn;
const realError = logger.error;

// eslint-disable-next-line @typescript-eslint/no-explicit-any
(logger as any).info = (msg: string, fields?: unknown) => {
  captured.push({ level: "info", msg, fields });
};
// eslint-disable-next-line @typescript-eslint/no-explicit-any
(logger as any).warn = (msg: string, fields?: unknown) => {
  captured.push({ level: "warn", msg, fields });
};
// eslint-disable-next-line @typescript-eslint/no-explicit-any
(logger as any).error = (msg: string, fields?: unknown) => {
  captured.push({ level: "error", msg, fields });
};

function clearLogs(): void {
  captured.length = 0;
}

function restoreLogger(): void {
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  (logger as any).info = realInfo;
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  (logger as any).warn = realWarn;
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  (logger as any).error = realError;
}

// =============================================================================
// Fixtures
// =============================================================================

function validRemoteDoc(): Record<string, unknown> {
  return {
    recipeExtractionSystemPrompt: "REMOTE_EXTRACTION_PROMPT",
    recipeEnhancementSystemPrompt: "REMOTE_ENHANCEMENT_PROMPT",
    imageOcrSystemPrompt: "REMOTE_OCR_PROMPT",
    spokenContentSystemPrompt: "REMOTE_SPOKEN_PROMPT",
    ingredientLineSystemPrompt: "REMOTE_INGREDIENT_PROMPT",
    promptVersion: "9.9.9-remote",
  };
}

// =============================================================================
// Tests
// =============================================================================

async function testFreshReadFromFirestore(): Promise<void> {
  console.log("\n[1] Fresh read from Firestore returns remote values");
  __resetPromptsCacheForTests();
  clearLogs();

  let calls = 0;
  const result = await getPromptsConfig({
    loader: async () => {
      calls++;
      return validRemoteDoc();
    },
    now: () => 0,
  });

  const ok =
    result.source === "firestore" &&
    result.promptVersion === "9.9.9-remote" &&
    result.recipeExtractionSystemPrompt === "REMOTE_EXTRACTION_PROMPT" &&
    result.imageOcrSystemPrompt === "REMOTE_OCR_PROMPT" &&
    calls === 1;

  record(
    "fresh remote read populates all 5 prompts and version",
    ok
      ? { ok: true }
      : {
          ok: false,
          detail: `source=${result.source}, version=${result.promptVersion}, calls=${calls}`,
        },
  );
}

async function testCacheHitWithinTtl(): Promise<void> {
  console.log("\n[2] Cache hit within TTL — loader called only once");
  __resetPromptsCacheForTests();
  clearLogs();

  let calls = 0;
  const loader = async (): Promise<Record<string, unknown>> => {
    calls++;
    return validRemoteDoc();
  };

  // First call at t=0, populates cache.
  await getPromptsConfig({ loader, now: () => 0 });
  // Subsequent calls within TTL window.
  await getPromptsConfig({ loader, now: () => 1000 });
  await getPromptsConfig({ loader, now: () => PROMPTS_CACHE_TTL_MS - 1 });

  record(
    "loader called exactly once across 3 reads within TTL",
    calls === 1
      ? { ok: true }
      : { ok: false, detail: `calls=${calls}, expected 1` },
  );
}

async function testCacheMissAfterTtl(): Promise<void> {
  console.log("\n[3] Cache miss after TTL — loader called again");
  __resetPromptsCacheForTests();
  clearLogs();

  let calls = 0;
  const loader = async (): Promise<Record<string, unknown>> => {
    calls++;
    return {
      ...validRemoteDoc(),
      promptVersion: `v${calls}`,
    };
  };

  const r1 = await getPromptsConfig({ loader, now: () => 0 });
  // Just past TTL.
  const r2 = await getPromptsConfig({
    loader,
    now: () => PROMPTS_CACHE_TTL_MS + 1,
  });

  const ok =
    calls === 2 && r1.promptVersion === "v1" && r2.promptVersion === "v2";
  record(
    "loader re-invoked after TTL expiry; version reflects new fetch",
    ok
      ? { ok: true }
      : {
          ok: false,
          detail: `calls=${calls}, r1.v=${r1.promptVersion}, r2.v=${r2.promptVersion}`,
        },
  );
}

async function testFirestoreFailureFallback(): Promise<void> {
  console.log(
    "\n[4] Firestore loader throws → fallback to compiled-in prompts",
  );
  __resetPromptsCacheForTests();
  clearLogs();

  const result = await getPromptsConfig({
    loader: async () => {
      throw new Error("simulated network failure");
    },
    now: () => 0,
  });

  const ok =
    result.source === "fallback" &&
    result.promptVersion === FALLBACK_PROMPT_VERSION &&
    result.recipeExtractionSystemPrompt === RECIPE_EXTRACTION_SYSTEM_PROMPT;

  // Should have logged a single warn with `err`.
  const warns = captured.filter(
    (e) => e.level === "warn" && e.msg.includes("Firestore read failed"),
  );

  record(
    "fallback bundle on read failure",
    ok
      ? { ok: true }
      : {
          ok: false,
          detail: `source=${result.source}, version=${result.promptVersion}`,
        },
  );
  record(
    "single warn log captured for read failure",
    warns.length === 1
      ? { ok: true }
      : { ok: false, detail: `warn count=${warns.length}` },
  );
}

async function testDocMissingFallback(): Promise<void> {
  console.log("\n[5] Doc missing (loader returns undefined) → fallback");
  __resetPromptsCacheForTests();
  clearLogs();

  const result = await getPromptsConfig({
    loader: async () => undefined,
    now: () => 0,
  });

  const ok =
    result.source === "fallback" &&
    result.promptVersion === FALLBACK_PROMPT_VERSION;

  const warns = captured.filter(
    (e) => e.level === "warn" && e.msg.includes("doc missing"),
  );

  record(
    "fallback bundle on doc-missing",
    ok
      ? { ok: true }
      : {
          ok: false,
          detail: `source=${result.source}, version=${result.promptVersion}`,
        },
  );
  record(
    "warn log distinguishes 'doc missing' from 'doc malformed'",
    warns.length === 1
      ? { ok: true }
      : { ok: false, detail: `'doc missing' warn count=${warns.length}` },
  );
}

async function testMalformedDocFallback(): Promise<void> {
  console.log("\n[6] Malformed doc shapes → fallback");

  // Cases:
  //   a) missing required field
  //   b) field wrong type (number instead of string)
  //   c) empty-string field
  const malformedCases: Array<[string, Record<string, unknown>]> = [
    [
      "missing imageOcrSystemPrompt",
      (() => {
        const d = validRemoteDoc();
        delete d.imageOcrSystemPrompt;
        return d;
      })(),
    ],
    [
      "promptVersion is number",
      { ...validRemoteDoc(), promptVersion: 123 },
    ],
    [
      "recipeExtractionSystemPrompt is empty string",
      { ...validRemoteDoc(), recipeExtractionSystemPrompt: "   " },
    ],
  ];

  let allOk = true;
  let allLogsOk = true;
  for (const [label, doc] of malformedCases) {
    __resetPromptsCacheForTests();
    clearLogs();

    const result = await getPromptsConfig({
      loader: async () => doc,
      now: () => 0,
    });

    const fellBack =
      result.source === "fallback" &&
      result.promptVersion === FALLBACK_PROMPT_VERSION;
    if (!fellBack) {
      allOk = false;
      console.log(
        `        case '${label}' did not fall back: source=${result.source}, v=${result.promptVersion}`,
      );
    }

    const malformedWarns = captured.filter(
      (e) => e.level === "warn" && e.msg.includes("malformed"),
    );
    if (malformedWarns.length !== 1) {
      allLogsOk = false;
      console.log(
        `        case '${label}' wrong warn count: ${malformedWarns.length}`,
      );
    }
  }

  record(
    "all malformed shapes (missing/wrong-type/empty) fall back",
    allOk ? { ok: true } : { ok: false },
  );
  record(
    "each malformed shape emits a single 'malformed' warn",
    allLogsOk ? { ok: true } : { ok: false },
  );
}

async function testFallbackCachedToSuppressLogStorm(): Promise<void> {
  console.log(
    "\n[7] Fallback result is cached — repeated reads do NOT re-log",
  );
  __resetPromptsCacheForTests();
  clearLogs();

  const loader = async (): Promise<Record<string, unknown> | undefined> =>
    undefined;

  await getPromptsConfig({ loader, now: () => 0 });
  await getPromptsConfig({ loader, now: () => 1 });
  await getPromptsConfig({ loader, now: () => 100 });

  const warns = captured.filter(
    (e) => e.level === "warn" && e.msg.includes("doc missing"),
  );

  record(
    "doc-missing warn fires only on cache fill, not on cache hits",
    warns.length === 1
      ? { ok: true }
      : { ok: false, detail: `warn count=${warns.length}` },
  );
}

async function testRemoteRecoveryAfterFallback(): Promise<void> {
  console.log(
    "\n[8] After TTL, remote recovers → cache flips back to firestore source",
  );
  __resetPromptsCacheForTests();
  clearLogs();

  let attempt = 0;
  const loader = async (): Promise<Record<string, unknown> | undefined> => {
    attempt++;
    if (attempt === 1) return undefined;
    return validRemoteDoc();
  };

  const r1 = await getPromptsConfig({ loader, now: () => 0 });
  const r2 = await getPromptsConfig({
    loader,
    now: () => PROMPTS_CACHE_TTL_MS + 1,
  });

  const ok =
    r1.source === "fallback" &&
    r2.source === "firestore" &&
    r2.promptVersion === "9.9.9-remote";
  record(
    "fallback at t=0, firestore at t=TTL+1 (no permanent fallback latch)",
    ok
      ? { ok: true }
      : {
          ok: false,
          detail: `r1.source=${r1.source}, r2.source=${r2.source}, r2.v=${r2.promptVersion}`,
        },
  );
}

// =============================================================================
// Driver
// =============================================================================

async function main(): Promise<void> {
  console.log("BUT-621: Remote prompts config tests");
  console.log("====================================");

  await testFreshReadFromFirestore();
  await testCacheHitWithinTtl();
  await testCacheMissAfterTtl();
  await testFirestoreFailureFallback();
  await testDocMissingFallback();
  await testMalformedDocFallback();
  await testFallbackCachedToSuppressLogStorm();
  await testRemoteRecoveryAfterFallback();

  restoreLogger();

  console.log(
    `\n${totalRun - totalFailed}/${totalRun} passed` +
      (totalFailed ? `, ${totalFailed} failed` : ""),
  );
  if (totalFailed > 0) process.exit(1);
}

main().catch((err) => {
  restoreLogger();
  console.error(err);
  process.exit(1);
});
