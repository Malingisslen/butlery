/**
 * BUT-1451: llm-sample-capture unit tests.
 *
 * Proves the capture helper's load-bearing guarantees:
 *  1. Happy path writes one doc with the scrubbed input, mode, inputKind, an
 *     expireAt TTL field, and undefined→null coalescing.
 *  2. The OUTPUT is scrubbed before storage (no un-scrubbed PII persisted).
 *  3. The image path stores no image bytes (only the model's text).
 *  4. A `system/config.llmSampleCaptureEnabled: false` flag suppresses writes.
 *  5. A Firestore write error is swallowed — capture never throws.
 *
 * Run with: npx ts-node src/__tests__/llm-sample-capture.test.ts
 */

import * as admin from "firebase-admin";
import {
  captureLlmSample,
  domainFromUrl,
  resetSampleCaptureCacheForTest,
} from "../llm/llm-sample-capture";
import { assertEqual, runTests, UnitCase } from "./_unit-runner";

interface AddedDoc {
  [k: string]: unknown;
}

/** Minimal Firestore double — records collection().add() payloads. */
function fakeDb(opts: {
  configData?: Record<string, unknown>;
  throwOnAdd?: boolean;
}): { db: admin.firestore.Firestore; added: AddedDoc[] } {
  const added: AddedDoc[] = [];
  const db = {
    doc: (_path: string) => ({
      get: async () => ({
        exists: opts.configData !== undefined,
        data: () => opts.configData,
      }),
    }),
    collection: (_name: string) => ({
      add: async (payload: AddedDoc) => {
        if (opts.throwOnAdd) throw new Error("simulated firestore failure");
        added.push(payload);
        return { id: "fake-id" };
      },
    }),
  } as unknown as admin.firestore.Firestore;
  return { db, added };
}

const cases: UnitCase[] = [
  {
    name: "happy path → one doc with scrubbed input, mode, TTL, null coalescing",
    fn: async () => {
      resetSampleCaptureCacheForTest();
      const { db, added } = fakeDb({});
      await captureLlmSample(
        {
          mode: "extract",
          inputKind: "text",
          scrubbedInput: "500 g köttfärs",
          rawLlmResponse: '{"title":"köttbullar"}',
          promptVersion: "2.1.0",
          modelId: "gemini-x",
          // promptSource/experimentBucket/... intentionally omitted → null
        },
        db
      );
      assertEqual(added.length, 1, "exactly one doc written");
      const d = added[0];
      assertEqual(d.mode, "extract", "mode stored");
      assertEqual(d.inputKind, "text", "inputKind stored");
      assertEqual(d.scrubbedInput, "500 g köttfärs", "scrubbed input stored");
      assertEqual(d.scrubbedInputLength, 14, "input length stored");
      assertEqual(d.promptVersion, "2.1.0", "promptVersion stored");
      assertEqual(d.promptSource, null, "omitted field coalesced to null");
      assertEqual(d.experimentBucket, null, "omitted bucket coalesced to null");
      if (!(d.expireAt instanceof admin.firestore.Timestamp)) {
        throw new Error("expireAt must be a Firestore Timestamp (TTL field)");
      }
      // 30-day retention default, in the future.
      if (d.expireAt.toMillis() <= Date.now()) {
        throw new Error("expireAt must be in the future");
      }
    },
  },
  {
    name: "output is scrubbed before storage (no raw PII persisted)",
    fn: async () => {
      resetSampleCaptureCacheForTest();
      const { db, added } = fakeDb({});
      const email = "chef.private@example.com";
      await captureLlmSample(
        {
          mode: "extract",
          inputKind: "text",
          scrubbedInput: "x".repeat(30),
          rawLlmResponse: `Contact the author at ${email} for the recipe.`,
          modelId: "gemini-x",
        },
        db
      );
      assertEqual(added.length, 1, "one doc written");
      const stored = String(added[0].scrubbedOutput);
      if (stored.includes(email)) {
        throw new Error(
          `raw email leaked into stored output: ${stored}`
        );
      }
    },
  },
  {
    name: "image path stores no image bytes (only model text)",
    fn: async () => {
      resetSampleCaptureCacheForTest();
      const { db, added } = fakeDb({});
      await captureLlmSample(
        {
          mode: "ocr",
          inputKind: "image",
          // no scrubbedInput → image bytes are never passed in
          rawLlmResponse: "Pannkakor\n2 dl mjöl",
          modelId: "gemini-x",
        },
        db
      );
      assertEqual(added.length, 1, "one doc written");
      const d = added[0];
      assertEqual(d.inputKind, "image", "inputKind=image");
      assertEqual(d.scrubbedInput, null, "no input stored for image path");
      const keys = Object.keys(d);
      for (const k of keys) {
        if (/image|base64|bytes/i.test(k)) {
          throw new Error(`image bytes must not be stored; found key '${k}'`);
        }
      }
    },
  },
  {
    name: "disabled flag suppresses the write",
    fn: async () => {
      resetSampleCaptureCacheForTest();
      const { db, added } = fakeDb({
        configData: { llmSampleCaptureEnabled: false },
      });
      await captureLlmSample(
        {
          mode: "extract",
          inputKind: "text",
          scrubbedInput: "x".repeat(30),
          rawLlmResponse: "anything",
          modelId: "gemini-x",
        },
        db
      );
      assertEqual(added.length, 0, "no write when disabled");
    },
  },
  {
    name: "firestore write error is swallowed (never throws)",
    fn: async () => {
      resetSampleCaptureCacheForTest();
      const { db } = fakeDb({ throwOnAdd: true });
      // Must resolve without throwing — a capture failure can't fail an import.
      await captureLlmSample(
        {
          mode: "extract",
          inputKind: "text",
          scrubbedInput: "x".repeat(30),
          rawLlmResponse: "anything",
          modelId: "gemini-x",
        },
        db
      );
    },
  },
  {
    name: "domainFromUrl extracts hostname sans www; undefined on junk",
    fn: () => {
      assertEqual(
        domainFromUrl("https://www.ica.se/recept/x"),
        "ica.se",
        "strips www"
      );
      assertEqual(
        domainFromUrl("https://koket.se/a"),
        "koket.se",
        "bare host"
      );
      assertEqual(domainFromUrl(undefined), undefined, "undefined passes through");
      assertEqual(domainFromUrl("not a url"), undefined, "junk → undefined");
    },
  },
];

void runTests("llm-sample-capture (BUT-1451)", cases);
