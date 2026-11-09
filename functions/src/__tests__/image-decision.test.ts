/**
 * BUT-818 step 2 — the stopped-image case: which report counts as one, how
 * concurrent images agree on a case, and its motivation.
 *
 * The emulator suite (`image-appeal.integration.test.ts`) proves the flow end
 * to end; it cannot prove the race below, because the Storage emulator ignores
 * `ifGenerationMatch: 0` on a save.
 *
 * Run: npx ts-node src/__tests__/image-decision.test.ts
 */

import { assertEqual, runTests, UnitCase } from "./_unit-runner";
import {
  casePointerPath,
  chooseReportId,
  isCasePointer,
  isImageReportId,
  newImageReportId,
} from "../storage/image-decision";
import { isAutomatedImageReport } from "../moderation/report-status";
import { resolveMotivation } from "../moderation/motivation";
import { sweepQuarantine } from "../storage/quarantine-restore";

const AUTOMATED = {
  reporterId: null,
  source: "safe_search",
  reason: "explicit_image",
  contentType: "image",
};

/** A bucket whose save honours `ifGenerationMatch: 0`, as real Storage does. */
function fakeBucket() {
  const objects = new Map<string, string>();
  return {
    objects,
    file(name: string) {
      return {
        name,
        async save(body: string, opts: { preconditionOpts?: { ifGenerationMatch?: number } }) {
          // Yield first, so two callers both pass their read before either writes.
          await new Promise((resolve) => setImmediate(resolve));
          if (opts.preconditionOpts?.ifGenerationMatch === 0 && objects.has(name)) {
            throw Object.assign(new Error("precondition"), { code: 412 });
          }
          objects.set(name, body);
        },
        async download() {
          if (!objects.has(name)) throw Object.assign(new Error("missing"), { code: 404 });
          return [Buffer.from(objects.get(name) as string, "utf8")];
        },
      };
    },
  };
}

function fakeDb(appealed: Set<string> = new Set()) {
  return {
    collection: () => ({
      doc: (id: string) => ({
        get: async () => ({ exists: appealed.has(id) }),
      }),
    }),
  };
}

const NOW = new Date(Date.UTC(2026, 10, 9, 8, 0, 0));

const cases: UnitCase[] = [
  {
    name: "only a server-filed image case counts as automated",
    fn: () => {
      assertEqual(isAutomatedImageReport(AUTOMATED), true, "server case");
      assertEqual(isAutomatedImageReport({ ...AUTOMATED, reporterId: "u1" }), false, "has a reporter");
      // A reporter erased later leaves `reporterId: null`; the reason and type a
      // client cannot write still keep such a report out.
      assertEqual(
        isAutomatedImageReport({ ...AUTOMATED, reason: "spam", contentType: "recipe" }),
        false,
        "client reason and type",
      );
      assertEqual(isAutomatedImageReport({ ...AUTOMATED, source: undefined }), false, "no source");
      assertEqual(isAutomatedImageReport(undefined), false, "missing");
    },
  },
  {
    name: "case ids are random and carry nothing of the uid",
    fn: () => {
      const a = newImageReportId();
      const b = newImageReportId();
      assertEqual(isImageReportId(a), true, "pattern");
      assertEqual(a === b, false, "random");
      assertEqual(isImageReportId("safesearch_abc"), false, "short id");
      assertEqual(isImageReportId("report-1"), false, "client id");
    },
  },
  {
    name: "the window pointer sits in the owner's quarantine prefix",
    fn: () => {
      const path = casePointerPath("u1", NOW);
      assertEqual(path.startsWith("quarantine/users/u1/.cases/"), true, path);
      assertEqual(isCasePointer({ name: path }), true, "pointer");
      assertEqual(isCasePointer({ name: "quarantine/users/u1/recipes/a.jpg" }), false, "image");
      // The owner may upload to `users/u1/.cases/x.jpg`; its quarantine copy is an image.
      const clientPath = { name: "quarantine/users/u1/.cases/x.jpg", metadata: { metadata: { reportId: "safesearch_x" } } };
      assertEqual(isCasePointer(clientPath), false, "client upload under .cases/");
    },
  },
  {
    name: "two images stopped at the same moment agree on one case",
    fn: async () => {
      const bucket = fakeBucket();
      const db = fakeDb();
      const [a, b] = await Promise.all([
        // eslint-disable-next-line @typescript-eslint/no-explicit-any
        chooseReportId(db as any, bucket as any, "u1", NOW),
        // eslint-disable-next-line @typescript-eslint/no-explicit-any
        chooseReportId(db as any, bucket as any, "u1", NOW),
      ]);
      assertEqual(a, b, "same case");
      assertEqual(bucket.objects.get(casePointerPath("u1", NOW)), a, "pointer names it");
    },
  },
  {
    name: "a new window, another owner, or an appealed case each get a new case",
    fn: async () => {
      const bucket = fakeBucket();
      // eslint-disable-next-line @typescript-eslint/no-explicit-any
      const first = await chooseReportId(fakeDb() as any, bucket as any, "u1", NOW);
      const later = new Date(NOW.getTime() + 11 * 60 * 1000);
      // eslint-disable-next-line @typescript-eslint/no-explicit-any
      const nextWindow = await chooseReportId(fakeDb() as any, bucket as any, "u1", later);
      // eslint-disable-next-line @typescript-eslint/no-explicit-any
      const otherOwner = await chooseReportId(fakeDb() as any, bucket as any, "u2", NOW);
      const appealed = new Set([`moderation_appeals/${first}_owner`, `${first}_owner`]);
      // eslint-disable-next-line @typescript-eslint/no-explicit-any
      const afterAppeal = await chooseReportId(fakeDb(appealed) as any, bucket as any, "u1", NOW);
      assertEqual(nextWindow === first, false, "next window");
      assertEqual(otherOwner === first, false, "other owner");
      assertEqual(afterAppeal === first, false, "after the owner appealed");
    },
  },
  {
    name: "the automated motivation is fixed, whatever the case carries",
    fn: () => {
      assertEqual(resolveMotivation("content_removed", "explicit_image", undefined), "removed_automated_image", "missing");
      assertEqual(resolveMotivation("content_removed", "explicit_image", "removed_spam"), "removed_automated_image", "other key");
      assertEqual(resolveMotivation("content_removed", "spam", "removed_automated_image"), "removed_other", "not a moderator choice");
    },
  },
  {
    name: "a sweep that reaches its deadline leaves the rest for next week",
    fn: async () => {
      const pointer = (i: number) => ({
        name: casePointerPath(`u${i}`, NOW),
        metadata: { timeCreated: NOW.toISOString() },
        delete: async () => undefined,
      });
      const files = [pointer(1), pointer(2), pointer(3)];
      const bucket = { getFiles: async () => [files] };
      const deps = { db: fakeDb(), bucket, push: async () => undefined, now: NOW };
      // eslint-disable-next-line @typescript-eslint/no-explicit-any
      const stopped = await sweepQuarantine({ ...deps, deadlineMs: -1 } as any);
      assertEqual(stopped.deferred, 3, "all deferred");
      // eslint-disable-next-line @typescript-eslint/no-explicit-any
      const full = await sweepQuarantine(deps as any);
      assertEqual(full.deferred, 0, "none deferred");
      assertEqual(full.failed, 0, "every pointer handled");
    },
  },
];

runTests("BUT-818 step 2: stopped-image case", cases);
