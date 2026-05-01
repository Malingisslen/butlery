/**
 * BUT-438: Preference-aware win-back push tests.
 * BUT-688: Win-back A/B variant + Remote Config integration tests.
 *
 * The detect-lapsed-users scheduled function used to call sendPushToUser
 * directly, bypassing the preference gate. The new contract:
 *   - Opted-out user (master toggle off OR reEngagement=false) → NOT pinged.
 *   - User inside quiet hours (Stockholm time) → NOT pinged.
 *   - User with no token / token failure → NOT counted as sent.
 *   - Normal user, awake, opted in → pinged.
 *
 * BUT-688 layer:
 *   - Variant resolution is deterministic (same uid → same variant).
 *   - User doc gets `lastWinBackVariant` + bridge fields after a send.
 *   - RC fetch failure falls back to baseline copy with no regression.
 *
 * We don't run the scheduler trigger end-to-end — that needs the emulator
 * suite. Instead we exercise the preference-aware helper directly with a
 * fake firestore + fake clock, which is the same surface the trigger now
 * funnels through. BUT-688 cases additionally exercise
 * `runDetectLapsedUsers` with an in-memory db + fake gate.
 *
 * Run with: npx ts-node src/__tests__/detect-lapsed-users.test.ts
 */

import {
  sendPushToUserRespectingPreferences,
  isInQuietWindow,
  stockholmHourMinute,
} from "../shared/preference-aware-push";
import { runDetectLapsedUsers } from "../analytics/detect-lapsed-users";
import {
  resolveWinbackVariant,
  BASELINE_COPY,
} from "../analytics/winback-variant";

interface SendCall {
  userId: string;
  title: string;
  body: string;
  data?: Record<string, string>;
}

interface Scenario {
  name: string;
  prefs: Record<string, unknown> | null;
  /** UTC time the test should pretend "now" is. */
  nowUtcIso: string;
  expectSent: boolean;
  expectReason: string;
}

function makeDeps(
  prefs: Record<string, unknown> | null,
  nowUtcIso: string,
  sends: SendCall[]
) {
  return {
    getPreferences: async (_userId: string) => prefs,
    getNow: () => new Date(nowUtcIso),
    send: async (
      userId: string,
      notification: { title: string; body: string },
      data?: Record<string, string>
    ) => {
      sends.push({
        userId,
        title: notification.title,
        body: notification.body,
        data,
      });
      return { successCount: 1, failureCount: 0 };
    },
  };
}

// 14:00 UTC on a non-DST winter day → 15:00 Europe/Stockholm (CET, UTC+1).
const WINTER_AFTERNOON_UTC = "2026-01-15T14:00:00Z";
// 23:30 UTC on a winter day → 00:30 Stockholm next day, inside 22:00-08:00.
const WINTER_LATE_NIGHT_UTC = "2026-01-15T23:30:00Z";

const scenarios: Scenario[] = [
  {
    name: "opted-out user (reEngagement=false) is NOT pinged",
    prefs: {
      enabled: true,
      reEngagement: false,
      quietHoursStart: { hour: 22, minute: 0 },
      quietHoursEnd: { hour: 8, minute: 0 },
    },
    nowUtcIso: WINTER_AFTERNOON_UTC,
    expectSent: false,
    expectReason: "opted_out",
  },
  {
    name: "master-disabled user is NOT pinged",
    prefs: {
      enabled: false,
      reEngagement: true,
    },
    nowUtcIso: WINTER_AFTERNOON_UTC,
    expectSent: false,
    expectReason: "master_disabled",
  },
  {
    name: "user inside quiet hours is NOT pinged",
    prefs: {
      enabled: true,
      reEngagement: true,
      quietHoursStart: { hour: 22, minute: 0 },
      quietHoursEnd: { hour: 8, minute: 0 },
    },
    nowUtcIso: WINTER_LATE_NIGHT_UTC,
    expectSent: false,
    expectReason: "quiet_hours",
  },
  {
    name: "normal opted-in user during the day IS pinged",
    prefs: {
      enabled: true,
      reEngagement: true,
      quietHoursStart: { hour: 22, minute: 0 },
      quietHoursEnd: { hour: 8, minute: 0 },
    },
    nowUtcIso: WINTER_AFTERNOON_UTC,
    expectSent: true,
    expectReason: "sent",
  },
  {
    name: "user with no preferences doc defaults to opted-in",
    prefs: null,
    nowUtcIso: WINTER_AFTERNOON_UTC,
    expectSent: true,
    expectReason: "sent",
  },
  {
    name: "fallback: explicit category opt-out via NotificationCategory.system",
    prefs: {
      enabled: true,
      // reEngagement field absent — falls back to categorySettings entry.
      categorySettings: { "NotificationCategory.system": false },
    },
    nowUtcIso: WINTER_AFTERNOON_UTC,
    expectSent: false,
    expectReason: "opted_out",
  },
];

interface UnitCase {
  name: string;
  fn: () => void;
}

const unitCases: UnitCase[] = [
  {
    name: "isInQuietWindow handles wrap-around 22:00-08:00 at 00:30",
    fn: () => {
      const inWindow = isInQuietWindow(
        { hour: 0, minute: 30 },
        { hour: 22, minute: 0 },
        { hour: 8, minute: 0 }
      );
      if (!inWindow) throw new Error("00:30 should be inside 22:00-08:00");
    },
  },
  {
    name: "isInQuietWindow excludes 15:00 from 22:00-08:00",
    fn: () => {
      const inWindow = isInQuietWindow(
        { hour: 15, minute: 0 },
        { hour: 22, minute: 0 },
        { hour: 8, minute: 0 }
      );
      if (inWindow) throw new Error("15:00 should NOT be inside 22:00-08:00");
    },
  },
  {
    name: "isInQuietWindow handles same-day 13:00-14:00 correctly",
    fn: () => {
      const inWindow = isInQuietWindow(
        { hour: 13, minute: 30 },
        { hour: 13, minute: 0 },
        { hour: 14, minute: 0 }
      );
      if (!inWindow) throw new Error("13:30 should be inside 13:00-14:00");
    },
  },
  {
    name: "isInQuietWindow with equal start/end is empty (never quiet)",
    fn: () => {
      const inWindow = isInQuietWindow(
        { hour: 12, minute: 0 },
        { hour: 12, minute: 0 },
        { hour: 12, minute: 0 }
      );
      if (inWindow) throw new Error("equal start/end should be never quiet");
    },
  },
  {
    name: "stockholmHourMinute converts 14:00 UTC winter to 15:00 CET",
    fn: () => {
      const out = stockholmHourMinute(new Date(WINTER_AFTERNOON_UTC));
      if (out.hour !== 15 || out.minute !== 0) {
        throw new Error(
          `expected 15:00 Europe/Stockholm, got ${out.hour}:${out.minute}`
        );
      }
    },
  },
  {
    name: "stockholmHourMinute converts 23:30 UTC winter to 00:30 next day CET",
    fn: () => {
      const out = stockholmHourMinute(new Date(WINTER_LATE_NIGHT_UTC));
      if (out.hour !== 0 || out.minute !== 30) {
        throw new Error(
          `expected 00:30 Europe/Stockholm, got ${out.hour}:${out.minute}`
        );
      }
    },
  },
];

// ----------------------------------------------------------------------
// BUT-688: integration tests for runDetectLapsedUsers
// ----------------------------------------------------------------------

interface FakeUserSeed {
  id: string;
  /** Days inactive (positive int). Sets lastActiveAt = now - days. */
  daysInactive: number;
}

interface FakeStore {
  /** Doc path → last-written data. */
  data: Map<string, Record<string, unknown>>;
  writeCount: number;
  commitCount: number;
}

const MS_PER_DAY = 24 * 60 * 60 * 1000;

function tsFromMillis(ms: number) {
  return {
    toMillis: () => ms,
    toDate: () => new Date(ms),
    _isTimestamp: true,
  };
}

function makeFakeDb(seeds: FakeUserSeed[], now: Date, store: FakeStore) {
  const nowMs = now.getTime();
  const userDocs = seeds.map((s) => ({
    id: s.id,
    data: () => ({
      lastActiveAt: tsFromMillis(nowMs - s.daysInactive * MS_PER_DAY),
    }),
  }));

  function makeUsersQuery(filter?: { startMs: number; endMs: number }) {
    return {
      where(_field: string, op: string, value: unknown) {
        const v = value as { toMillis: () => number };
        const ms = v.toMillis();
        const next = filter
          ? { ...filter }
          : { startMs: -Infinity, endMs: Infinity };
        if (op === ">=") next.startMs = ms;
        if (op === "<=") next.endMs = ms;
        return makeUsersQuery(next);
      },
      async get() {
        const docs = userDocs.filter((d) => {
          if (!filter) return true;
          const lam = (d.data().lastActiveAt as { toMillis: () => number }).toMillis();
          return lam >= filter.startMs && lam <= filter.endMs;
        });
        return { empty: docs.length === 0, docs };
      },
    };
  }

  const collection = (name: string): unknown => {
    if (name === "users") {
      return {
        ...makeUsersQuery(),
        doc(uid: string) {
          return makeUserDocRef(uid);
        },
      };
    }
    if (name === "analytics") {
      return makeAnalyticsRoot();
    }
    throw new Error(`unexpected collection: ${name}`);
  };

  function makeUserDocRef(uid: string) {
    return {
      _kind: "user" as const,
      uid,
      collection(sub: string) {
        if (sub === "notifications") {
          return {
            doc() {
              return {
                _kind: "notification" as const,
                path: `users/${uid}/notifications/auto_${store.writeCount}`,
              };
            },
          };
        }
        throw new Error(`unexpected user-subcollection: ${sub}`);
      },
    };
  }

  function makeAnalyticsRoot() {
    return {
      doc(docId: string) {
        return {
          collection(sub: string) {
            return {
              doc() {
                return {
                  _kind: "analyticsEvent" as const,
                  path: `analytics/${docId}/${sub}/auto_${store.writeCount}`,
                };
              },
            };
          },
        };
      },
    };
  }

  return {
    collection,
    batch() {
      const ops: { path: string; data: Record<string, unknown> }[] = [];
      return {
        set(
          ref: { _kind: string; uid?: string; path?: string },
          data: Record<string, unknown>,
          options?: { merge?: boolean },
        ) {
          let path: string;
          if (ref._kind === "user") {
            path = `users/${ref.uid}`;
          } else if (ref.path) {
            path = ref.path;
          } else {
            throw new Error("ref missing path");
          }
          const existing = options?.merge
            ? (store.data.get(path) ?? {})
            : {};
          ops.push({ path, data: { ...existing, ...data } });
        },
        async commit() {
          for (const op of ops) {
            store.data.set(op.path, op.data);
            store.writeCount++;
          }
          store.commitCount++;
          ops.length = 0;
        },
      };
    },
  };
}

/** Helper: deps that bypass RC + push so we can assert on writes alone. */
function makeRunDeps(
  fakeDb: ReturnType<typeof makeFakeDb>,
  now: Date,
  overrides: {
    fetchCopy?: (
      thresholdType: string,
      variant: string,
    ) => Promise<{ title: string; body: string }>;
    sendPush?: () => Promise<{ sent: boolean; reason: string }>;
    gate?: () => Promise<{ action: string; reason: string }>;
  } = {},
) {
  return {
    db: fakeDb as never,
    now,
    fetchCopy:
      overrides.fetchCopy ??
      (async (thresholdType: string, variant: string) => ({
        title: `T:${thresholdType}:${variant}`,
        body: `B:${thresholdType}:${variant}`,
      })),
    sendPush:
      (overrides.sendPush ??
        (async () =>
          ({ sent: true, reason: "sent" }) as const)) as never,
    gate:
      (overrides.gate ??
        (async () =>
          ({ action: "proceed", reason: "test" }) as const)) as never,
    recordEvent: (async () => undefined) as never,
  };
}

interface IntCase {
  name: string;
  fn: () => Promise<void>;
}

const integrationCases: IntCase[] = [
  {
    name: "user doc receives lastWinBackVariant + bridge fields after run",
    fn: async () => {
      const now = new Date("2026-04-30T05:00:00Z");
      const store: FakeStore = {
        data: new Map(),
        writeCount: 0,
        commitCount: 0,
      };
      const db = makeFakeDb(
        [{ id: "user-mild", daysInactive: 7 }],
        now,
        store,
      );
      await runDetectLapsedUsers(makeRunDeps(db, now));

      const userDoc = store.data.get("users/user-mild");
      if (!userDoc) {
        throw new Error("user doc not written");
      }
      if (userDoc.lastWinBackChannel !== "push") {
        throw new Error(
          `expected lastWinBackChannel=push, got ${userDoc.lastWinBackChannel}`,
        );
      }
      if (userDoc.lastWinBackBucket !== "win_back_mild") {
        throw new Error(
          `expected bucket=win_back_mild, got ${userDoc.lastWinBackBucket}`,
        );
      }
      if (typeof userDoc.lastWinBackVariant !== "string") {
        throw new Error("lastWinBackVariant missing");
      }
      if (
        userDoc.lastWinBackVariant !== "baseline" &&
        userDoc.lastWinBackVariant !== "curiosity"
      ) {
        throw new Error(
          `unexpected variant: ${userDoc.lastWinBackVariant}`,
        );
      }
      if (!userDoc.lastWinBackSentAt) {
        throw new Error("lastWinBackSentAt missing");
      }
    },
  },
  {
    name: "variant assignment is deterministic across re-runs",
    fn: async () => {
      const now = new Date("2026-04-30T05:00:00Z");
      const seeds: FakeUserSeed[] = [
        { id: "u-deterministic-1", daysInactive: 7 },
        { id: "u-deterministic-2", daysInactive: 7 },
        { id: "u-deterministic-3", daysInactive: 14 },
      ];
      const storeA: FakeStore = {
        data: new Map(),
        writeCount: 0,
        commitCount: 0,
      };
      await runDetectLapsedUsers(
        makeRunDeps(makeFakeDb(seeds, now, storeA), now),
      );
      const storeB: FakeStore = {
        data: new Map(),
        writeCount: 0,
        commitCount: 0,
      };
      await runDetectLapsedUsers(
        makeRunDeps(makeFakeDb(seeds, now, storeB), now),
      );

      for (const seed of seeds) {
        const a = storeA.data.get(`users/${seed.id}`);
        const b = storeB.data.get(`users/${seed.id}`);
        if (!a || !b) throw new Error(`missing user write for ${seed.id}`);
        if (a.lastWinBackVariant !== b.lastWinBackVariant) {
          throw new Error(
            `variant flipped across runs for ${seed.id}: ` +
              `${a.lastWinBackVariant} vs ${b.lastWinBackVariant}`,
          );
        }
        const expected = resolveWinbackVariant(
          seed.id,
          a.lastWinBackBucket as string,
        );
        if (a.lastWinBackVariant !== expected) {
          throw new Error(
            `variant mismatch with resolveWinbackVariant for ${seed.id}: ` +
              `stored=${a.lastWinBackVariant} expected=${expected}`,
          );
        }
      }
    },
  },
  {
    name: "RC fetch failure falls back to baseline body in notification doc",
    fn: async () => {
      const now = new Date("2026-04-30T05:00:00Z");
      const store: FakeStore = {
        data: new Map(),
        writeCount: 0,
        commitCount: 0,
      };
      const db = makeFakeDb(
        [{ id: "user-rc-fail", daysInactive: 30 }],
        now,
        store,
      );
      // Mimic the production fetchWinbackCopy fallback path: when RC is
      // unreachable, the real implementation returns BASELINE_COPY for
      // the threshold. We assert the integration writes baseline body.
      await runDetectLapsedUsers(
        makeRunDeps(db, now, {
          fetchCopy: async (thresholdType: string) =>
            BASELINE_COPY[thresholdType],
        }),
      );

      // Find the notification doc — its path includes the user id.
      let notif: Record<string, unknown> | undefined;
      for (const [path, data] of store.data.entries()) {
        if (path.startsWith("users/user-rc-fail/notifications/")) {
          notif = data;
          break;
        }
      }
      if (!notif) throw new Error("notification doc not written");
      const expectedBody = BASELINE_COPY.win_back_strong.body;
      if (notif.bodyShown !== expectedBody) {
        throw new Error(
          `expected baseline body "${expectedBody}", got "${notif.bodyShown}"`,
        );
      }
      if (notif.message !== expectedBody) {
        throw new Error(
          `expected message=${expectedBody}, got "${notif.message}"`,
        );
      }
    },
  },
  {
    name: "analytics event includes variant field",
    fn: async () => {
      const now = new Date("2026-04-30T05:00:00Z");
      const store: FakeStore = {
        data: new Map(),
        writeCount: 0,
        commitCount: 0,
      };
      const db = makeFakeDb(
        [{ id: "user-evt", daysInactive: 14 }],
        now,
        store,
      );
      await runDetectLapsedUsers(makeRunDeps(db, now));

      let evt: Record<string, unknown> | undefined;
      for (const [path, data] of store.data.entries()) {
        if (path.startsWith("analytics/lapsed_users/events/")) {
          evt = data;
          break;
        }
      }
      if (!evt) throw new Error("analytics event not written");
      if (typeof evt.variant !== "string" || !evt.variant.length) {
        throw new Error(`event missing variant: ${JSON.stringify(evt)}`);
      }
    },
  },
  {
    name: "gate=type_disabled skips push but still writes notification + bridge",
    fn: async () => {
      const now = new Date("2026-04-30T05:00:00Z");
      const store: FakeStore = {
        data: new Map(),
        writeCount: 0,
        commitCount: 0,
      };
      const db = makeFakeDb(
        [{ id: "user-gated", daysInactive: 7 }],
        now,
        store,
      );
      let pushCalls = 0;
      await runDetectLapsedUsers(
        makeRunDeps(db, now, {
          gate: async () => ({
            action: "type_disabled",
            reason: "rc_flag_disabled",
          }),
          sendPush: async () => {
            pushCalls++;
            return { sent: false, reason: "should-not-be-called" };
          },
        }),
      );
      if (pushCalls !== 0) {
        throw new Error(
          `gate dropped — push should not have been called, got ${pushCalls}`,
        );
      }
      const userDoc = store.data.get("users/user-gated");
      if (!userDoc || typeof userDoc.lastWinBackVariant !== "string") {
        throw new Error(
          "user bridge fields should still be written even when push is gated",
        );
      }
    },
  },
];

async function runTests(): Promise<void> {
  console.log("BUT-438 + BUT-688: Win-back push + variant tests\n");
  console.log("==============================================\n");

  let failed = 0;

  for (const c of unitCases) {
    try {
      c.fn();
      console.log(`  PASS  ${c.name}`);
    } catch (err) {
      failed++;
      console.log(`  FAIL  ${c.name}`);
      console.log(`        ${err instanceof Error ? err.message : err}`);
    }
  }

  for (const s of scenarios) {
    const sends: SendCall[] = [];
    const deps = makeDeps(s.prefs, s.nowUtcIso, sends);
    const result = await sendPushToUserRespectingPreferences(
      "user-123",
      { title: "Butlery", body: "Vi saknar dig!" },
      "reEngagement",
      { type: "win_back_mild" },
      deps
    );

    const sentMatch = result.sent === s.expectSent;
    const reasonMatch = result.reason === s.expectReason;
    const sendCountMatch = s.expectSent
      ? sends.length === 1
      : sends.length === 0;

    if (sentMatch && reasonMatch && sendCountMatch) {
      console.log(`  PASS  ${s.name}`);
    } else {
      failed++;
      console.log(`  FAIL  ${s.name}`);
      console.log(
        `        expected sent=${s.expectSent} reason=${s.expectReason}, ` +
          `got sent=${result.sent} reason=${result.reason}, ` +
          `send-call count=${sends.length}`
      );
    }
  }

  for (const c of integrationCases) {
    try {
      await c.fn();
      console.log(`  PASS  ${c.name}`);
    } catch (err) {
      failed++;
      console.log(`  FAIL  ${c.name}`);
      console.log(`        ${err instanceof Error ? err.message : err}`);
    }
  }

  const total = unitCases.length + scenarios.length + integrationCases.length;
  console.log(
    `\n${total - failed}/${total} passed` + (failed ? `, ${failed} failed` : "")
  );
  if (failed > 0) process.exit(1);
}

runTests().catch((err) => {
  console.error(err);
  process.exit(1);
});
