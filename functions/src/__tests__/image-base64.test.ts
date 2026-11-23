/**
 * A photo the app encoded with its old hand-written base64 encoder must reach
 * Vertex as canonical base64, and input that is not base64 must be refused
 * before any model call.
 *
 * Run: npx ts-node src/__tests__/image-base64.test.ts
 */

import { HttpsError } from "firebase-functions/v2/https";
import { runTests, UnitCase, assertEqual } from "./_unit-runner";
import { prepareImageBase64 } from "../llm/image-base64";
import { runOcrRecipeImage } from "../llm/ocr-recipe-image";

const ALPHABET =
  "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";

// Line-for-line port of `OcrRecipeImageRequest._encodeBase64` as shipped in
// the app before it switched to `base64Encode`.
function oldAppEncode(bytes: Buffer): string {
  let out = "";
  let i = 0;
  while (i < bytes.length) {
    const b1 = bytes[i++];
    const b2 = i < bytes.length ? bytes[i++] : 0;
    const b3 = i < bytes.length ? bytes[i++] : 0;
    out += ALPHABET[(b1 >> 2) & 0x3f];
    out += ALPHABET[((b1 << 4) | (b2 >> 4)) & 0x3f];
    out += i - 1 < bytes.length ? ALPHABET[((b2 << 2) | (b3 >> 6)) & 0x3f] : "=";
    out += i < bytes.length ? ALPHABET[b3 & 0x3f] : "=";
  }
  return out;
}

const CANONICAL = /^(?:[A-Za-z0-9+/]{4})*(?:[A-Za-z0-9+/]{2}==|[A-Za-z0-9+/]{3}=)?$/;

// Strict decode: re-encoding the decoded bytes gives back the same string
// only when the string was canonical.
function isCanonical(s: string): boolean {
  return CANONICAL.test(s) && Buffer.from(s, "base64").toString("base64") === s;
}

// A JPEG of a given length: SOI marker, filler, EOI marker.
function jpeg(length: number): Buffer {
  const b = Buffer.alloc(length, 0x41);
  b[0] = 0xff; b[1] = 0xd8; b[2] = 0xff;
  b[length - 2] = 0xff; b[length - 1] = 0xd9;
  return b;
}

function png(length: number, last: number): Buffer {
  const b = Buffer.alloc(length, 0x42);
  b.set([0x89, 0x50, 0x4e, 0x47], 0);
  b[length - 1] = last;
  return b;
}

const cases: UnitCase[] = [
  {
    name: "the old app encoder is wrong exactly when length % 3 is 0 or 1 (premise)",
    fn: () => {
      for (const n of [300, 301, 302]) {
        const b = jpeg(n);
        assertEqual(oldAppEncode(b) === b.toString("base64"), n % 3 === 2, `length ${n}`);
      }
    },
  },
  {
    name: "an old-app JPEG becomes canonical base64 of the original image, end marker included",
    fn: () => {
      for (const n of [300, 301, 302]) {
        const original = jpeg(n);
        const prepared = prepareImageBase64(oldAppEncode(original));
        if (prepared === null) throw new Error(`refused length ${n}`);
        assertEqual(isCanonical(prepared.base64), true, `canonical, length ${n}`);
        const decoded = Buffer.from(prepared.base64, "base64");
        // % 3 == 1 leaves one zero byte after the end marker; the image itself
        // is intact.
        const expected = n % 3 === 1 ? Buffer.concat([original, Buffer.from([0])]) : original;
        assertEqual(decoded.equals(expected), true, `bytes, length ${n}`);
        // At % 3 == 1 the old string is already canonical (for one byte too
        // many), so only % 3 == 0 changes.
        assertEqual(prepared.repaired, n % 3 === 0, `repaired flag, length ${n}`);
        assertEqual(prepared.jpegEndRestored, n % 3 === 0, `end restored, length ${n}`);
      }
    },
  },
  {
    name: "a correct string passes through unchanged and is not counted as repaired",
    fn: () => {
      const s = jpeg(300).toString("base64");
      const prepared = prepareImageBase64(s);
      assertEqual(prepared?.base64, s, "same string");
      assertEqual(prepared?.repaired, false, "repaired");
      assertEqual(prepareImageBase64(prepared!.base64)?.base64, s, "idempotent");
    },
  },
  {
    name: "a data-URL prefix and line breaks are removed",
    fn: () => {
      const s = jpeg(302).toString("base64");
      const wrapped = `data:image/jpeg;base64,${s.slice(0, 76)}\n${s.slice(76)}`;
      assertEqual(prepareImageBase64(wrapped)?.base64, s, "same image");
    },
  },
  {
    name: "a non-JPEG ending in 0xFF gets no byte added",
    fn: () => {
      const b = png(302, 0xff);
      const prepared = prepareImageBase64(b.toString("base64"));
      assertEqual(prepared?.base64, b.toString("base64"), "unchanged");
      assertEqual(prepared?.jpegEndRestored, false, "no end marker");
    },
  },
  {
    name: "empty, non-base64 and URL-safe strings are refused",
    fn: () => {
      for (const bad of ["", "====", "not base64!", "ab-_cd==", "<svg/>"]) {
        assertEqual(prepareImageBase64(bad), null, JSON.stringify(bad));
      }
    },
  },
  {
    name: "the photo call receives the canonical string, and garbage is refused before it",
    fn: async () => {
      const original = jpeg(300);
      let sent: string | undefined;
      await runOcrRecipeImage({
        data: { imageBase64: oldAppEncode(original), mimeType: "image/jpeg" },
        authUidHash: "image-base64-test",
        userId: "image-base64-test",
        performOcr: async (args) => {
          sent = args.imageBase64;
          return { content: "{}", cost: 0 };
        },
        isAiDisabled: async () => false,
        checkGlobalLimit: async () => true,
        checkUserLimit: async () => true,
        checkIngredientRetryUserLimit: async () => true,
        now: () => 0,
      });
      assertEqual(sent, original.toString("base64"), "string sent to the model");

      let calls = 0;
      let code: string | undefined;
      try {
        await runOcrRecipeImage({
          data: { imageBase64: "not base64!" },
          authUidHash: "image-base64-test",
          userId: "image-base64-test",
          performOcr: async () => {
            calls++;
            return { content: "{}", cost: 0 };
          },
          isAiDisabled: async () => false,
          now: () => 0,
        });
      } catch (e) {
        code = e instanceof HttpsError ? e.code : String(e);
      }
      assertEqual(code, "invalid-argument", "error code");
      assertEqual(calls, 0, "model calls");
    },
  },
];

runTests("image-base64", cases);
