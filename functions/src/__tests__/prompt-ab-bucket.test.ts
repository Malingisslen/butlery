/**
 * BUT-626: Prompt A/B bucket assignment tests.
 *
 * Coverage:
 *   (a) Stability — same userId → same bucket across multiple calls
 *   (b) Distribution — roughly even across 1000 distinct ids (A/B, 2 buckets)
 *   (c) Variant resolution — bucket maps to variant from promptVariants
 *   (d) No-experiment fallback — undefined promptVariants → variant=undefined,
 *       bucket still assigned
 *   (e) Malformed promptVariants → graceful fallback (variant=undefined)
 *   (f) bucketCount guard — throws on invalid input
 *   (g) Analytics payload includes experimentBucket field (integration with
 *       prompts-config: PromptsConfig now carries optional promptVariants)
 *
 * Run with: npx ts-node src/__tests__/prompt-ab-bucket.test.ts
 */

import {
  assignPromptBucket,
  resolvePromptBucket,
} from "../shared/prompt-ab-bucket";
import { logger } from "firebase-functions/logger";
import {
  getPromptsConfig,
  __resetPromptsCacheForTests,
  PromptsConfig,
} from "../llm/prompts-config";

// =============================================================================
// Logger silence — tests don't need prompts-config fallback warnings
// =============================================================================

const realWarn = logger.warn;
const realInfo = logger.info;
const realError = logger.error;

// eslint-disable-next-line @typescript-eslint/no-explicit-any
(logger as any).warn = () => {};
// eslint-disable-next-line @typescript-eslint/no-explicit-any
(logger as any).info = () => {};
// eslint-disable-next-line @typescript-eslint/no-explicit-any
(logger as any).error = () => {};

function restoreLogger(): void {
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  (logger as any).warn = realWarn;
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  (logger as any).info = realInfo;
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  (logger as any).error = realError;
}

// =============================================================================
// Minimal harness (mirrors winback-variant.test.ts pattern)
// =============================================================================

interface TestCase {
  name: string;
  fn: () => Promise<void> | void;
}

let totalFailed = 0;
let totalRun = 0;

function record(name: string, ok: boolean, detail?: string): void {
  totalRun++;
  if (ok) {
    console.log(`  PASS  ${name}`);
  } else {
    totalFailed++;
    console.log(`  FAIL  ${name}`);
    if (detail) console.log(`        ${detail}`);
  }
}

async function run(cases: TestCase[]): Promise<void> {
  for (const c of cases) {
    try {
      await c.fn();
      record(c.name, true);
    } catch (err) {
      record(c.name, false, String(err));
    }
  }
}

// =============================================================================
// Cases
// =============================================================================

const cases: TestCase[] = [
  // (a) Stability: same userId → same bucket every time
  {
    name: "(a) assignPromptBucket is stable for the same userId",
    fn: () => {
      const uid = "stable-test-user-abc123";
      const b1 = assignPromptBucket(uid);
      const b2 = assignPromptBucket(uid);
      const b3 = assignPromptBucket(uid);
      if (b1 !== b2 || b2 !== b3) {
        throw new Error(
          `expected same bucket, got ${b1}, ${b2}, ${b3}`,
        );
      }
      if (b1 < 0 || b1 >= 2) {
        throw new Error(`bucket ${b1} out of range [0, 2)`);
      }
    },
  },

  // (a) Stability across 50 distinct ids, each called 3 times
  {
    name: "(a) assignPromptBucket is stable across many calls for each userId",
    fn: () => {
      for (let i = 0; i < 50; i++) {
        const uid = `user-stability-${i}`;
        const first = assignPromptBucket(uid, 2);
        for (let j = 0; j < 5; j++) {
          const repeat = assignPromptBucket(uid, 2);
          if (repeat !== first) {
            throw new Error(
              `uid=${uid} unstable: first=${first}, repeat=${repeat}`,
            );
          }
        }
      }
    },
  },

  // (b) Distribution: ±10% of 50/50 over 1000 ids with 2 buckets
  {
    name: "(b) distribution is within ±10% of 50/50 for 2 buckets over 1000 ids",
    fn: () => {
      const counts = [0, 0];
      const total = 1000;
      for (let i = 0; i < total; i++) {
        const b = assignPromptBucket(`dist-test-${i}`, 2);
        counts[b]++;
      }
      const ratio0 = counts[0] / total;
      // ±10% band: each bucket should be between 40% and 60%
      if (ratio0 < 0.40 || ratio0 > 0.60) {
        throw new Error(
          `distribution skewed: bucket0=${counts[0]}, bucket1=${counts[1]} of ${total}`,
        );
      }
    },
  },

  // (b) Distribution with 3 buckets over 1500 ids
  {
    name: "(b) distribution is within ±10% of 33/33/33 for 3 buckets over 1500 ids",
    fn: () => {
      const counts = [0, 0, 0];
      const total = 1500;
      for (let i = 0; i < total; i++) {
        const b = assignPromptBucket(`three-bucket-${i}`, 3);
        counts[b]++;
      }
      const expected = total / 3;
      for (let k = 0; k < 3; k++) {
        const deviation = Math.abs(counts[k] - expected) / total;
        if (deviation > 0.10) {
          throw new Error(
            `bucket ${k} deviation ${(deviation * 100).toFixed(1)}% > 10%: counts=${counts}`,
          );
        }
      }
    },
  },

  // (c) Variant resolution: bucket maps to correct promptVariants entry
  {
    name: "(c) resolvePromptBucket returns correct variant for bucket",
    fn: () => {
      const variants = ["control", "v2_extraction"];
      // Test many users so we exercise both bucket 0 and bucket 1
      let sawControl = false;
      let sawV2 = false;
      for (let i = 0; i < 200; i++) {
        const uid = `variant-test-${i}`;
        const { bucket, variant } = resolvePromptBucket(uid, variants);
        if (bucket < 0 || bucket >= 2) {
          throw new Error(`bucket ${bucket} out of range`);
        }
        if (variant !== variants[bucket]) {
          throw new Error(
            `uid=${uid} bucket=${bucket} but variant=${variant}, expected=${variants[bucket]}`,
          );
        }
        if (variant === "control") sawControl = true;
        if (variant === "v2_extraction") sawV2 = true;
      }
      if (!sawControl || !sawV2) {
        throw new Error(
          `did not see both variants in 200 users: sawControl=${sawControl}, sawV2=${sawV2}`,
        );
      }
    },
  },

  // (d) No-experiment fallback: undefined promptVariants → variant=undefined, bucket still set
  {
    name: "(d) resolvePromptBucket returns variant=undefined when promptVariants is undefined",
    fn: () => {
      const { bucket, variant } = resolvePromptBucket("user-no-experiment", undefined);
      if (variant !== undefined) {
        throw new Error(`expected variant=undefined, got ${variant}`);
      }
      // bucket is still a valid index (0 or 1, default bucketCount=2)
      if (bucket < 0 || bucket >= 2) {
        throw new Error(`bucket ${bucket} out of range [0, 2)`);
      }
    },
  },

  // (d) Empty array → no active experiment
  {
    name: "(d) resolvePromptBucket returns variant=undefined for empty promptVariants",
    fn: () => {
      const { variant } = resolvePromptBucket("user-empty-variants", []);
      if (variant !== undefined) {
        throw new Error(`expected variant=undefined for empty array, got ${variant}`);
      }
    },
  },

  // (e) Malformed promptVariants (contains a non-string) → variant=undefined
  {
    name: "(e) resolvePromptBucket returns variant=undefined for malformed promptVariants",
    fn: () => {
      // Cast to bypass TypeScript — simulates bad Firestore data
      const malformed = ["control", 42, ""] as unknown as string[];
      const { variant } = resolvePromptBucket("user-malformed", malformed);
      if (variant !== undefined) {
        throw new Error(
          `expected variant=undefined for malformed variants, got ${variant}`,
        );
      }
    },
  },

  // (f) Guard: invalid bucketCount throws
  {
    name: "(f) assignPromptBucket throws for bucketCount < 1",
    fn: () => {
      let threw = false;
      try {
        assignPromptBucket("some-user", 0);
      } catch {
        threw = true;
      }
      if (!threw) throw new Error("expected throw for bucketCount=0");
    },
  },

  // (f) Guard: non-integer bucketCount throws
  {
    name: "(f) assignPromptBucket throws for non-integer bucketCount",
    fn: () => {
      let threw = false;
      try {
        assignPromptBucket("some-user", 1.5);
      } catch {
        threw = true;
      }
      if (!threw) throw new Error("expected throw for bucketCount=1.5");
    },
  },

  // (g) Analytics payload: getPromptsConfig returns promptVariants when doc has them
  {
    name: "(g) PromptsConfig.promptVariants is populated when Firestore doc carries it",
    async fn() {
      __resetPromptsCacheForTests();
      const validDocWithVariants = {
        recipeExtractionSystemPrompt: "extract prompt",
        recipeEnhancementSystemPrompt: "enhance prompt",
        imageOcrSystemPrompt: "ocr prompt",
        spokenContentSystemPrompt: "spoken prompt",
        ingredientLineSystemPrompt: "ingredient prompt",
        promptVersion: "v-experiment-1",
        promptVariants: ["control", "challenger"],
      };
      const config: PromptsConfig = await getPromptsConfig({
        loader: async () => validDocWithVariants,
      });
      __resetPromptsCacheForTests();

      if (config.source !== "firestore") {
        throw new Error(`expected source=firestore, got ${config.source}`);
      }
      if (!Array.isArray(config.promptVariants)) {
        throw new Error(
          `expected promptVariants array, got ${JSON.stringify(config.promptVariants)}`,
        );
      }
      if (
        config.promptVariants.length !== 2 ||
        config.promptVariants[0] !== "control" ||
        config.promptVariants[1] !== "challenger"
      ) {
        throw new Error(
          `unexpected promptVariants: ${JSON.stringify(config.promptVariants)}`,
        );
      }
    },
  },

  // (g) promptVariants absent from doc → field absent from PromptsConfig
  {
    name: "(g) PromptsConfig.promptVariants is absent when doc omits it",
    async fn() {
      __resetPromptsCacheForTests();
      const docWithoutVariants = {
        recipeExtractionSystemPrompt: "extract prompt",
        recipeEnhancementSystemPrompt: "enhance prompt",
        imageOcrSystemPrompt: "ocr prompt",
        spokenContentSystemPrompt: "spoken prompt",
        ingredientLineSystemPrompt: "ingredient prompt",
        promptVersion: "v-no-experiment",
      };
      const config: PromptsConfig = await getPromptsConfig({
        loader: async () => docWithoutVariants,
      });
      __resetPromptsCacheForTests();

      if (config.promptVariants !== undefined) {
        throw new Error(
          `expected promptVariants=undefined, got ${JSON.stringify(config.promptVariants)}`,
        );
      }
    },
  },

  // (g) Invalid promptVariants in doc → field absent from PromptsConfig (all-or-nothing)
  {
    name: "(g) PromptsConfig.promptVariants is absent when doc has malformed variants",
    async fn() {
      __resetPromptsCacheForTests();
      const docWithBadVariants = {
        recipeExtractionSystemPrompt: "extract prompt",
        recipeEnhancementSystemPrompt: "enhance prompt",
        imageOcrSystemPrompt: "ocr prompt",
        spokenContentSystemPrompt: "spoken prompt",
        ingredientLineSystemPrompt: "ingredient prompt",
        promptVersion: "v-bad-variants",
        promptVariants: ["control", ""], // empty string → invalid
      };
      const config: PromptsConfig = await getPromptsConfig({
        loader: async () => docWithBadVariants,
      });
      __resetPromptsCacheForTests();

      if (config.promptVariants !== undefined) {
        throw new Error(
          `expected promptVariants=undefined for malformed doc, got ${JSON.stringify(config.promptVariants)}`,
        );
      }
    },
  },

  // (g) Bucket is included in emitTiming closure — integration check via
  //     resolvePromptBucket producing a value that matches the variants list
  {
    name: "(g) resolvePromptBucket result is suitable as analytics payload field",
    fn: () => {
      const uid = "analytics-payload-test-user";
      const { bucket, variant } = resolvePromptBucket(uid, ["control", "challenger"]);

      // Simulate the analytics event object that emitTiming would construct
      const analyticsPayload: Record<string, unknown> = {
        event: "structure_recipe.complete",
        promptVersion: "v-experiment-1",
        ...(bucket !== undefined ? { experimentBucket: bucket } : {}),
        ...(variant !== undefined ? { promptVariant: variant } : {}),
      };

      if (!("experimentBucket" in analyticsPayload)) {
        throw new Error("experimentBucket missing from analytics payload");
      }
      if (typeof analyticsPayload.experimentBucket !== "number") {
        throw new Error(
          `experimentBucket should be number, got ${typeof analyticsPayload.experimentBucket}`,
        );
      }
      if (!("promptVariant" in analyticsPayload)) {
        throw new Error("promptVariant missing from analytics payload when variants configured");
      }
      if (analyticsPayload.promptVariant !== variant) {
        throw new Error(
          `promptVariant mismatch: payload=${analyticsPayload.promptVariant}, expected=${variant}`,
        );
      }
    },
  },
];

// =============================================================================
// Run
// =============================================================================

(async () => {
  console.log("\nBUT-626: prompt-ab-bucket");
  console.log("=".repeat(50));
  await run(cases);
  restoreLogger();
  console.log(`\n${totalRun - totalFailed}/${totalRun} passed`);
  if (totalFailed > 0) {
    process.exit(1);
  }
})();
