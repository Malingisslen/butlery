/**
 * BUT-2243: the arithmetic of the weekly import tier job — the week window,
 * the per-channel counts, the two-proportion z and the alarm thresholds.
 * The Firestore half runs in `import-tier-weekly.integration.test.ts`.
 *
 * Run with: npx ts-node src/__tests__/import-tier-weekly.test.ts
 */

import {
  ChannelStats,
  COST_ALARM_USD,
  MIN_EVENTS,
  WeekStats,
  addEvent,
  findShifts,
  isoWeekStart,
  twoProportionZ,
} from "../analytics/import-tier-weekly";
import { assertEqual, runTests, UnitCase } from "./_unit-runner";

function channel(
  n: number,
  structuredHits: number,
  extra: Partial<ChannelStats> = {}
): ChannelStats {
  return {
    events: n,
    structured: { hits: structuredHits, n },
    ai: { hits: 0, n },
    failure: { hits: 0, n },
    costN: 0,
    costSumUsd: 0,
    ...extra,
  };
}

function week(byChannel: Record<string, ChannelStats>, truncated = false): WeekStats {
  return { isoWeek: "2026-W10", truncated, byChannel };
}

const cases: UnitCase[] = [
  {
    name: "isoWeekStart: Monday stays, Sunday goes back six days",
    fn: () => {
      assertEqual(isoWeekStart(new Date("2026-03-09T08:00:00Z")).toISOString(), "2026-03-09T00:00:00.000Z", "Monday");
      assertEqual(isoWeekStart(new Date("2026-03-15T23:59:00Z")).toISOString(), "2026-03-09T00:00:00.000Z", "Sunday");
    },
  },
  {
    name: "addEvent: null channel -> unknown; null outcome and usedLlm stay out of their denominators",
    fn: () => {
      const by: Record<string, ChannelStats> = {};
      addEvent(by, {});
      addEvent(by, { outcome: "failure", usedLlm: false });
      addEvent(by, { outcome: "recipe", successfulTier: "SiteConfig", usedLlm: true, estimatedCostUsd: 0.002 });
      const s = by.unknown;
      assertEqual(s.events, 3, "events");
      assertEqual(s.failure.n, 2, "failure n");
      assertEqual(s.failure.hits, 1, "failure hits");
      assertEqual(s.structured.n, 1, "structured counts recipes only");
      assertEqual(s.structured.hits, 1, "SiteConfig is structured");
      assertEqual(s.ai.n, 2, "ai n");
      assertEqual(s.costN, 1, "cost n");
    },
  },
  {
    name: "twoProportionZ: 40/40 vs 20/40 is about -5.16; identical shares give 0",
    fn: () => {
      const z = twoProportionZ({ hits: 40, n: 40 }, { hits: 20, n: 40 }) as number;
      assertEqual(Math.round(z * 100) / 100, -5.16, "z");
      assertEqual(twoProportionZ({ hits: 10, n: 40 }, { hits: 10, n: 40 }), 0, "same share");
      assertEqual(twoProportionZ({ hits: 0, n: 40 }, { hits: 0, n: 40 }), null, "pooled 0");
    },
  },
  {
    name: "a big move at n = MIN_EVENTS alarms, one below does not",
    fn: () => {
      const n = MIN_EVENTS;
      const alarm = findShifts(week({ link: channel(n, n) }), week({ link: channel(n, 0) }));
      assertEqual(alarm.length, 1, "at the floor");
      const quiet = findShifts(
        week({ link: channel(n - 1, n - 1) }),
        week({ link: channel(n - 1, 0) })
      );
      assertEqual(quiet.length, 0, "below the floor");
    },
  },
  {
    name: "a 15-point move that is noise at its n stays quiet; the same move at large n alarms",
    fn: () => {
      // 50% -> 35% at n = 40: |z| ~ 1.35.
      const small = findShifts(week({ link: channel(40, 20) }), week({ link: channel(40, 14) }));
      assertEqual(small.length, 0, "n = 40");
      // 50% -> 35% at n = 1000: |z| ~ 6.8.
      const large = findShifts(week({ link: channel(1000, 500) }), week({ link: channel(1000, 350) }));
      assertEqual(large.length, 1, "n = 1000");
      // 50% -> 36% at n = 1000: |z| ~ 6.3 but the move is under 15 points.
      const under = findShifts(week({ link: channel(1000, 500) }), week({ link: channel(1000, 360) }));
      assertEqual(under.length, 0, "14-point move");
    },
  },
  {
    name: "cost alarms above the ceiling at n >= MIN_EVENTS, with no previous week needed",
    fn: () => {
      const over = channel(MIN_EVENTS, 0, { costN: MIN_EVENTS, costSumUsd: MIN_EVENTS * COST_ALARM_USD * 1.01 });
      const at = channel(MIN_EVENTS, 0, { costN: MIN_EVENTS, costSumUsd: MIN_EVENTS * COST_ALARM_USD });
      const few = channel(MIN_EVENTS, 0, { costN: MIN_EVENTS - 1, costSumUsd: 1 });
      assertEqual(findShifts(week({}), week({ photo: over }))[0]?.kind, "cost", "over");
      assertEqual(findShifts(week({}), week({ photo: at })).length, 0, "at the ceiling");
      assertEqual(findShifts(week({}), week({ photo: few })).length, 0, "too few costed events");
    },
  },
  {
    name: "a truncated current week is not judged; a truncated previous week drops only the share rule",
    fn: () => {
      const costly = { costN: MIN_EVENTS * 2, costSumUsd: 1 };
      const prev = { link: channel(40, 40) };
      const cur = { link: channel(40, 0, costly) };
      const kinds = (s: ReturnType<typeof findShifts>) => s.map((x) => x.kind).sort().join(",");
      assertEqual(kinds(findShifts(week(prev), week(cur))), "cost,structured", "control");
      assertEqual(kinds(findShifts(week(prev, true), week(cur))), "cost", "previous truncated");
      assertEqual(findShifts(week(prev), week(cur, true)).length, 0, "current truncated");
    },
  },
];

runTests("BUT-2243: weekly import tier arithmetic", cases);
