/**
 * BUT-1511: onFamilyRatingUpdated recompute gate.
 *
 * Proves the public-aggregation recompute decision
 * (`shouldRecomputeOnFamilyRatingUpdate`) fires on a memberType-only flip —
 * not only on a star change. The regression the ticket fixes: a row promoted
 * INTO `profile` with unchanged stars used to skip recompute even though it
 * newly counts toward the public average.
 *
 * Run with: npx ts-node src/__tests__/family-rating-recompute.test.ts
 */

import { assertEqual, runTests, UnitCase } from "./_unit-runner";
import {
  shouldRecomputeOnFamilyRatingUpdate,
} from "../ratings/family-rating-recompute";

const row = (memberType: string, stars: number) => ({
  recipeId: "r1",
  memberId: "m1",
  memberType,
  stars,
});

const cases: UnitCase[] = [
  {
    name: "memberType-only flip INTO profile (stars unchanged) → recompute",
    fn: () =>
      assertEqual(
        shouldRecomputeOnFamilyRatingUpdate(row("user", 4), row("profile", 4)),
        true,
        "promotion to profile with same stars must recompute"
      ),
  },
  {
    name: "star-only change on a profile row → recompute (regression guard)",
    fn: () =>
      assertEqual(
        shouldRecomputeOnFamilyRatingUpdate(
          row("profile", 3),
          row("profile", 5)
        ),
        true,
        "star change on profile row must recompute"
      ),
  },
  {
    name: "no-op update on a profile row (nothing changed) → no recompute",
    fn: () =>
      assertEqual(
        shouldRecomputeOnFamilyRatingUpdate(
          row("profile", 4),
          row("profile", 4)
        ),
        false,
        "unchanged profile row must not spend a recompute"
      ),
  },
  {
    name: "adult/proxy (user) row edit → no recompute (after-is-profile gate)",
    fn: () =>
      assertEqual(
        shouldRecomputeOnFamilyRatingUpdate(row("user", 2), row("user", 5)),
        false,
        "user-type rows never touch the public counter"
      ),
  },
  {
    name: "demotion profile → user is gated out (documented residual, out of scope)",
    fn: () =>
      assertEqual(
        shouldRecomputeOnFamilyRatingUpdate(
          row("profile", 4),
          row("user", 4)
        ),
        false,
        "after-is-profile guard short-circuits demotion — BUT-1511 targets only the condition"
      ),
  },
];

runTests("BUT-1511: family-rating recompute gate", cases).catch((err) => {
  console.error(err);
  process.exit(1);
});
