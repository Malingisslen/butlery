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
  /** BUT-1223: rate-cap seam outcome for this scenario (default allowed). */
  capAllowed?: boolean;
  expectSent: boolean;
  expectReason: string;
}

function makeDeps(
  prefs: Record<string, unknown> | null,
  nowUtcIso: string,
  sends: SendCall[],
  capAllowed = true
) {
  return {
    getPreferences: async (_userId: string) => prefs,
    getNow: () => new Date(nowUtcIso),
    // BUT-1223: stub the rate-cap seam — the real checkAndIncrement opens a
    // Firestore transaction via admin.firestore() (no app in unit env).
    checkRateCap: async () => ({
      allowed: capAllowed,
      count: capAllowed ? 0 : 10,
      cap: 10,
      reason: (capAllowed ? "ok" : "total_cap") as "ok" | "total_cap",
    }),
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
  {
    // BUT-1223: the rate-cap seam's decision must flow through — a capped
    // user is not pinged and the send() dep is never invoked.
    name: "rate-capped user (24h fatigue cap hit) is NOT pinged",
    prefs: {
      enabled: true,
      reEngagement: true,
    },
    nowUtcIso: WINTER_AFTERNOON_UTC,
    capAllowed: false,
    expectSent: false,
    expectReason: "rate_capped",
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
  /** BUT-1428: seed an existing `lastWinBackSentAt` (ms) to exercise the
   *  bridge-overwrite gate (a prior, possibly un-attributed, win-back send). */
  priorWinBackSentAtMs?: number;
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
      ...(s.priorWinBackSentAtMs != null
        ? { lastWinBackSentAt: tsFromMillis(s.priorWinBackSentAtMs) }
        : {}),
    }),
  }));

  function makeUsersQuery(filter?: {
    startMs: number;
    startExclusive: boolean;
    endMs: number;
  }) {
    return {
      where(_field: string, op: string, value: unknown) {
        const v = value as { toMillis: () => number };
        const ms = v.toMillis();
        const next = filter
          ? { ...filter }
          : { startMs: -Infinity, startExclusive: false, endMs: Infinity };
        // BUT-1567: the crossed-since-last-run window uses an exclusive
        // lower bound (`>`) and inclusive upper bound (`<=`).
        if (op === ">=") {
          next.startMs = ms;
          next.startExclusive = false;
        }
        if (op === ">") {
          next.startMs = ms;
          next.startExclusive = true;
        }
        if (op === "<=") next.endMs = ms;
        return makeUsersQuery(next);
      },
      async get() {
        const docs = userDocs.filter((d) => {
          if (!filter) return true;
          const lam = (
            d.data().lastActiveAt as { toMillis: () => number }
          ).toMillis();
          const aboveLower = filter.startExclusive
            ? lam > filter.startMs
            : lam >= filter.startMs;
          return aboveLower && lam <= filter.endMs;
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
        const docPath = `analytics/${docId}`;
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
          // BUT-1567: the last-run cursor lives on this doc as `lastRunAt`.
          async get() {
            const data = store.data.get(docPath);
            return {
              exists: data !== undefined,
              data: () => data,
            };
          },
          async set(
            data: Record<string, unknown>,
            options?: { merge?: boolean },
          ) {
            const existing = options?.merge
              ? (store.data.get(docPath) ?? {})
              : {};
            store.data.set(docPath, { ...existing, ...data });
            store.writeCount++;
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
    resolveContext?: (
      userId: string,
      userData: Record<string, unknown>,
    ) => Promise<{ title: string; body: string; contextKey: string } | null>;
  } = {},
) {
  return {
    db: fakeDb as never,
    now,
    // BUT-934: default the contextual layer OFF so these cases isolate the
    // variant / RC / gate orchestration. Contextual copy has its own suite
    // (winback-context.test.ts) plus a dedicated integration case below.
    resolveContext: (overrides.resolveContext ?? (async () => null)) as never,
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
    name: "BUT-1428: bridge NOT overwritten while an earlier send is still in the attribution window",
    fn: async () => {
      const now = new Date("2026-04-30T05:00:00Z");
      const nowMs = now.getTime();
      const store: FakeStore = {
        data: new Map(),
        writeCount: 0,
        commitCount: 0,
      };
      // Lapsed at 14d, but pinged only 2 days ago (still un-attributed, in window).
      const db = makeFakeDb(
        [
          {
            id: "user-pending",
            daysInactive: 14,
            priorWinBackSentAtMs: nowMs - 2 * MS_PER_DAY,
          },
        ],
        now,
        store,
      );
      await runDetectLapsedUsers(makeRunDeps(db, now));

      if (store.data.get("users/user-pending") !== undefined) {
        throw new Error(
          "bridge fields were overwritten despite a fresh un-attributed send — " +
            "the earlier send's attribution credit would be lost",
        );
      }
      const gotNotification = [...store.data.keys()].some((k) =>
        k.startsWith("users/user-pending/notifications/"),
      );
      if (!gotNotification) {
        throw new Error(
          "user should still receive the notification even when the bridge is preserved",
        );
      }
    },
  },
  {
    name: "BUT-1428: bridge IS overwritten when the earlier send is past the attribution window",
    fn: async () => {
      const now = new Date("2026-04-30T05:00:00Z");
      const nowMs = now.getTime();
      const store: FakeStore = {
        data: new Map(),
        writeCount: 0,
        commitCount: 0,
      };
      // Lapsed at 14d, last pinged 10 days ago (past the 7d window → safe to overwrite).
      const db = makeFakeDb(
        [
          {
            id: "user-stale",
            daysInactive: 14,
            priorWinBackSentAtMs: nowMs - 10 * MS_PER_DAY,
          },
        ],
        now,
        store,
      );
      await runDetectLapsedUsers(makeRunDeps(db, now));

      const userDoc = store.data.get("users/user-stale");
      if (!userDoc) {
        throw new Error("bridge fields should be overwritten for a stale prior send");
      }
      if (userDoc.lastWinBackBucket !== "win_back_moderate") {
        throw new Error(
          `expected bucket=win_back_moderate, got ${userDoc.lastWinBackBucket}`,
        );
      }
    },
  },
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
    name: "BUT-934: contextual copy flows to notification doc + analytics event",
    fn: async () => {
      const now = new Date("2026-04-30T05:00:00Z");
      const store: FakeStore = {
        data: new Map(),
        writeCount: 0,
        commitCount: 0,
      };
      const db = makeFakeDb(
        [{ id: "user-ctx", daysInactive: 14 }],
        now,
        store,
      );
      await runDetectLapsedUsers(
        makeRunDeps(db, now, {
          resolveContext: async () => ({
            title: "Butlery",
            body: "Anna delade ett recept med dig",
            contextKey: "ctx_friend_share",
          }),
        }),
      );

      let notif: Record<string, unknown> | undefined;
      let evt: Record<string, unknown> | undefined;
      for (const [path, data] of store.data.entries()) {
        if (path.startsWith("users/user-ctx/notifications/")) notif = data;
        if (path.startsWith("analytics/lapsed_users/events/")) evt = data;
      }
      if (!notif) throw new Error("notification doc not written");
      if (notif.bodyShown !== "Anna delade ett recept med dig") {
        throw new Error(`unexpected contextual body: ${notif.bodyShown}`);
      }
      if (notif.contextKey !== "ctx_friend_share") {
        throw new Error(`notif missing contextKey: ${JSON.stringify(notif)}`);
      }
      if (!evt || evt.contextKey !== "ctx_friend_share") {
        throw new Error(`event missing contextKey: ${JSON.stringify(evt)}`);
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
  {
    // BUT-1567: the crux. A run was skipped (cursor is 5 days stale); a user
    // crossed the 7-day threshold 2 days ago (lastActiveAt = now-9d), so
    // TODAY they sit outside the old ±12h band centred on now-7d and the
    // point-in-time predicate would miss them forever. The crossed-since-
    // last-run window (now-12d, now-7d] catches them.
    name: "BUT-1567: irregular user caught after a skipped run (wide catch-up window)",
    fn: async () => {
      const now = new Date("2026-04-30T05:00:00Z");
      const nowMs = now.getTime();
      const store: FakeStore = { data: new Map(), writeCount: 0, commitCount: 0 };
      // Cursor 5 days stale — the daily run was down for several days.
      store.data.set("analytics/lapsed_users", {
        lastRunAt: tsFromMillis(nowMs - 5 * MS_PER_DAY),
      });
      const db = makeFakeDb([{ id: "user-irregular", daysInactive: 9 }], now, store);
      await runDetectLapsedUsers(makeRunDeps(db, now));

      const userDoc = store.data.get("users/user-irregular");
      if (!userDoc) {
        throw new Error(
          "user who crossed the 7-day threshold during the outage was missed — " +
            "this is exactly the point-in-time gap BUT-1567 fixes",
        );
      }
      if (userDoc.lastWinBackBucket !== "win_back_mild") {
        throw new Error(
          `expected bucket=win_back_mild (crossed 7d), got ${userDoc.lastWinBackBucket}`,
        );
      }
    },
  },
  {
    // BUT-1567: no daily re-notification. A user already well past every
    // threshold at the last run must NOT be re-detected on subsequent runs —
    // they were handled when they first crossed. Window lower bound is
    // exclusive, so a long-dormant user produces zero writes.
    name: "BUT-1567: user already past thresholds at last run is NOT re-notified",
    fn: async () => {
      const now = new Date("2026-04-30T05:00:00Z");
      const nowMs = now.getTime();
      const store: FakeStore = { data: new Map(), writeCount: 0, commitCount: 0 };
      // Yesterday's run already covered up to now-1d minus each threshold.
      store.data.set("analytics/lapsed_users", {
        lastRunAt: tsFromMillis(nowMs - 1 * MS_PER_DAY),
      });
      // Inactive 20 days — was already 19 days inactive at the last run, so
      // it crossed 7/14 long ago and hasn't reached 30.
      const db = makeFakeDb([{ id: "user-dormant", daysInactive: 20 }], now, store);
      await runDetectLapsedUsers(makeRunDeps(db, now));

      const userWrites = [...store.data.keys()].filter(
        (k) => k === "users/user-dormant" || k.startsWith("users/user-dormant/"),
      );
      if (userWrites.length !== 0) {
        throw new Error(
          `long-dormant user should not be re-notified, got writes: ${userWrites.join(", ")}`,
        );
      }
    },
  },
  {
    // BUT-1567: first run (no cursor) uses a bounded one-day lookback, so it
    // does NOT backfill every historically-dormant user. A user who crossed
    // 7 days exactly is caught; one who crossed 3 days before that (now-10d)
    // is out of the first-run window.
    name: "BUT-1567: first run applies a bounded lookback (no giant backfill)",
    fn: async () => {
      const now = new Date("2026-04-30T05:00:00Z");
      const store: FakeStore = { data: new Map(), writeCount: 0, commitCount: 0 };
      const db = makeFakeDb(
        [
          { id: "user-just-crossed", daysInactive: 7 },
          { id: "user-old-crosser", daysInactive: 10 },
        ],
        now,
        store,
      );
      await runDetectLapsedUsers(makeRunDeps(db, now));

      if (!store.data.get("users/user-just-crossed")) {
        throw new Error("boundary crosser (7d exact) should be detected on first run");
      }
      if (store.data.get("users/user-old-crosser")) {
        throw new Error(
          "user who crossed 3 days before the run window should NOT be backfilled",
        );
      }
    },
  },
  {
    // BUT-1567: the cursor is advanced to `now` after a successful run so the
    // next run starts where this one ended.
    name: "BUT-1567: run persists the last-run cursor",
    fn: async () => {
      const now = new Date("2026-04-30T05:00:00Z");
      const store: FakeStore = { data: new Map(), writeCount: 0, commitCount: 0 };
      const db = makeFakeDb([{ id: "user-cursor", daysInactive: 7 }], now, store);
      await runDetectLapsedUsers(makeRunDeps(db, now));

      const cursor = store.data.get("analytics/lapsed_users") as
        | { lastRunAt?: { toMillis: () => number } }
        | undefined;
      if (!cursor?.lastRunAt) {
        throw new Error("cursor doc lastRunAt not persisted after run");
      }
      if (cursor.lastRunAt.toMillis() !== now.getTime()) {
        throw new Error(
          `cursor should equal run 'now' (${now.getTime()}), got ${cursor.lastRunAt.toMillis()}`,
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
    const deps = makeDeps(s.prefs, s.nowUtcIso, sends, s.capAllowed ?? true);
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
