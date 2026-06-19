/**
 * Bug-35: token-bucket refill must credit fractional-interval progress.
 *
 * What this proves: a user who requests faster than one refill interval still
 * accrues tokens proportionally (the old Math.floor logic credited 0 and, by
 * resetting lastRefill to `now` on every call, locked them out until a full
 * idle interval elapsed). We assert proportional refill, the persisted
 * lastRefill carries the sub-interval remainder forward, and the bucket caps
 * at maxTokens.
 *
 * Run with: npx ts-node src/__tests__/rate-limiter-refill.test.ts
 */

import { calculateCurrentTokens } from "../middleware/rate_limiter";
import { assertEqual, runTests, UnitCase } from "./_unit-runner";

// 10 tokens/min refill → 1 token every 6000ms.
const config = { maxTokens: 30, refillRate: 10, refillIntervalMs: 60000 };

function approx(actual: number, expected: number, tol: number, msg: string) {
  if (Math.abs(actual - expected) > tol) {
    throw new Error(`${msg}: expected ~${expected}, got ${actual}`);
  }
}

const cases: UnitCase[] = [
  {
    name: "half an interval credits half the refillRate (fractional, not floored to 0)",
    fn: async () => {
      const lastRefill = new Date(Date.now() - 30000); // 0.5 interval
      const { tokens } = calculateCurrentTokens(0, lastRefill, config);
      // 0.5 * 10 = 5 tokens. Old floored logic returned 0 here.
      approx(tokens, 5, 0.1, "half-interval refill");
    },
  },
  {
    name: "one sixth of an interval credits ~1 token",
    fn: async () => {
      const lastRefill = new Date(Date.now() - 6000); // 6000ms = 1 token
      const { tokens } = calculateCurrentTokens(2, lastRefill, config);
      approx(tokens, 3, 0.05, "one-token refill on top of stored 2");
    },
  },
  {
    name: "persisted lastRefill carries sub-interval remainder forward (no lockout)",
    fn: async () => {
      // 9000ms elapsed = 1.5 tokens. We credit 1.5 tokens; the effectiveRefill
      // anchor must advance by exactly the credited time, leaving NONE of the
      // elapsed time stranded — i.e. it should land back at the original
      // lastRefill + 9000ms (within rounding), not at `now` losing progress.
      const start = Date.now() - 9000;
      const lastRefill = new Date(start);
      const { tokens, effectiveRefill } = calculateCurrentTokens(
        0,
        lastRefill,
        config
      );
      approx(tokens, 1.5, 0.05, "1.5 token refill");
      // creditedMs = floor(1.5 / (10/60000)) = floor(9000) = 9000ms.
      approx(
        effectiveRefill.getTime() - start,
        9000,
        2,
        "anchor advanced by credited time, remainder preserved"
      );
    },
  },
  {
    name: "refill caps at maxTokens and anchors lastRefill at now",
    fn: async () => {
      const before = Date.now();
      const lastRefill = new Date(before - 10 * 60000); // way more than needed
      const { tokens, effectiveRefill } = calculateCurrentTokens(
        25,
        lastRefill,
        config
      );
      assertEqual(tokens, 30, "capped at maxTokens");
      // When capped, anchor is `now` (all elapsed time accounted for).
      if (effectiveRefill.getTime() < before) {
        throw new Error("capped bucket should anchor lastRefill at now");
      }
    },
  },
  {
    name: "zero elapsed time credits nothing",
    fn: async () => {
      const { tokens } = calculateCurrentTokens(7, new Date(), config);
      approx(tokens, 7, 0.01, "no refill at zero elapsed");
    },
  },
];

runTests("Bug-35: token-bucket fractional refill", cases);
