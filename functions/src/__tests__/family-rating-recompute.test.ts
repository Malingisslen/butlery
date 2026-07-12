/**
 * BUT-1511 / BUT-1592: onFamilyRatingUpdated recompute gate.
 *
 * Proves the public-aggregation recompute decision
 * (`shouldRecomputeOnFamilyRatingUpdate`) fires on a memberType flip in EITHER
 * direction — not only on a star change:
 *  - BUT-1511: a row promoted INTO `profile` with unchanged stars must
 *    recompute (it newly counts toward the public average);
 *  - BUT-1592: a row demoted OUT OF `profile` with unchanged stars must also
 *    recompute (it leaves the public average, which was left stale by the old
 *    `after`-only gate).
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
    name: "demotion profile → user (stars unchanged) → recompute (BUT-1592)",
    fn: () =>
      assertEqual(
        shouldRecomputeOnFamilyRatingUpdate(
          row("profile", 4),
          row("user", 4)
        ),
        true,
        "a row leaving profile must drop out of the public average"
      ),
  },
  {
    name: "both non-profile (user → guest) → no recompute",
    fn: () =>
      assertEqual(
        shouldRecomputeOnFamilyRatingUpdate(row("user", 2), row("guest", 5)),
        false,
        "neither side counts toward the public average"
      ),
  },
];

runTests("BUT-1511: family-rating recompute gate", cases).catch((err) => {
  console.error(err);
  process.exit(1);
});
