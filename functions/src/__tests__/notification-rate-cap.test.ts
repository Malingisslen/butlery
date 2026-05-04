/**
 * BUT-651: pure-decision tests for the global notification rate cap.
 *
 * Covers `evaluateCap` and `readCaps` — the parts of the gate that don't
 * need an emulator. Transactional increment behavior is exercised by an
 * integration test against the rules-unit-testing emulator (see
 * notification-rate-cap-integration.test.ts when emulator is available).
 *
 * Run: `npx ts-node src/__tests__/notification-rate-cap.test.ts`
 */

import {
  DEFAULT_NONCRITICAL_CAP,
  DEFAULT_TOTAL_CAP,
  evaluateCap,
  readCaps,
} from "../notifications/notification-rate-cap";
import { assertEqual, runTests, UnitCase } from "./_unit-runner";

const cases: UnitCase[] = [
  {
    name: "readCaps falls back to defaults when env unset",
    fn: () => {
      const caps = readCaps({});
      assertEqual(caps.total, DEFAULT_TOTAL_CAP, "total default");
      assertEqual(caps.noncritical, DEFAULT_NONCRITICAL_CAP, "noncritical default");
    },
  },
  {
    name: "readCaps honors numeric env values",
    fn: () => {
      const caps = readCaps({
        PUSH_CAP_TOTAL_PER_24H: "20",
        PUSH_CAP_NONCRITICAL_PER_24H: "8",
      });
      assertEqual(caps.total, 20, "total from env");
      assertEqual(caps.noncritical, 8, "noncritical from env");
    },
  },
  {
    name: "readCaps falls back when env is malformed",
    fn: () => {
      const caps = readCaps({
        PUSH_CAP_TOTAL_PER_24H: "abc",
        PUSH_CAP_NONCRITICAL_PER_24H: "-5",
      });
      assertEqual(caps.total, DEFAULT_TOTAL_CAP,
        "non-numeric falls back");
      assertEqual(caps.noncritical, DEFAULT_NONCRITICAL_CAP,
        "non-positive falls back");
    },
  },
  {
    name: "evaluateCap allows under both caps",
    fn: () => {
      const r = evaluateCap({
        totalCount: 3,
        noncriticalCount: 2,
        priority: "noncritical",
        caps: { total: 10, noncritical: 5 },
      });
      assertEqual(r.allowed, true, "under both caps → allowed");
      assertEqual(r.reason, "ok", "reason ok");
    },
  },
  {
    name: "evaluateCap blocks noncritical at noncritical cap",
    fn: () => {
      const r = evaluateCap({
        totalCount: 6,
        noncriticalCount: 5,
        priority: "noncritical",
        caps: { total: 10, noncritical: 5 },
      });
      assertEqual(r.allowed, false, "noncritical at noncritical cap → blocked");
      assertEqual(r.reason, "noncritical_cap", "reason noncritical_cap");
    },
  },
  {
    name: "evaluateCap allows critical past noncritical cap (under total cap)",
    fn: () => {
      const r = evaluateCap({
        totalCount: 6,
        noncriticalCount: 5,
        priority: "critical",
        caps: { total: 10, noncritical: 5 },
      });
      assertEqual(r.allowed, true, "critical bypasses noncritical cap");
    },
  },
  {
    name: "evaluateCap blocks critical at total cap",
    fn: () => {
      const r = evaluateCap({
        totalCount: 10,
        noncriticalCount: 5,
        priority: "critical",
        caps: { total: 10, noncritical: 5 },
      });
      assertEqual(r.allowed, false, "even critical respects total cap");
      assertEqual(r.reason, "total_cap", "reason total_cap");
    },
  },
  {
    name: "evaluateCap total cap takes precedence over noncritical cap",
    fn: () => {
      const r = evaluateCap({
        totalCount: 11,
        noncriticalCount: 6,
        priority: "noncritical",
        caps: { total: 10, noncritical: 5 },
      });
      // Both caps exceeded — total takes precedence (it's the harder rule).
      assertEqual(r.reason, "total_cap", "total cap wins when both exceeded");
    },
  },
];

void runTests("BUT-651 notification-rate-cap helpers", cases);
