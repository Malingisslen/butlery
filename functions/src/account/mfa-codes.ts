/**
 * P6-U09 — the backup codes themselves: drawing, hashing, matching, and which
 * enrollment a set belongs to. Split out of `mfa-backup-codes.ts` (500-line
 * rule); the callables and the recovery flow live there.
 */

import { randomBytes, randomInt, scrypt, timingSafeEqual } from "crypto";

/** Ten codes, as drawn and as §14.2 says. */
export const BACKUP_CODE_COUNT = 10;

/** No 0/O, 1/I/L: a code is read off paper. 31 symbols, 10 of them ≈ 49 bits. */
export const CODE_ALPHABET = "23456789ABCDEFGHJKMNPQRSTUVWXYZ";
export const CODE_LENGTH = 10;

/**
 * How long before a factor's enrollment its code set may have been created.
 * The app creates the set, shows it, and enrolls the factor right after.
 */
export const CODES_BEFORE_ENROLLMENT_MAX_MS = 24 * 60 * 60 * 1000;

/** Clock slack between Firestore's writer and the Auth server. */
const ENROLLMENT_CLOCK_SLACK_MS = 60 * 1000;

/**
 * Whether a set created at [createdAt] belongs to one of the factors enrolled
 * at [enrollmentTimes]. A set from an earlier enrollment that survived a
 * switch-off (for example one made outside the app, which never calls
 * `clearMfaBackupCodes`) is older than that window and does not count.
 */
export function codesBelongToEnrollment(
  createdAt: unknown,
  enrollmentTimes: number[],
): boolean {
  if (typeof createdAt !== "number") return false;
  return enrollmentTimes.some(
    (t) =>
      t >= createdAt - ENROLLMENT_CLOCK_SLACK_MS &&
      t - createdAt <= CODES_BEFORE_ENROLLMENT_MAX_MS,
  );
}

const SCRYPT_KEYLEN = 32;
const SCRYPT_OPTIONS = { N: 16384, r: 8, p: 1 };

export interface StoredCode {
  salt: string;
  hash: string;
  /** Epoch millis when the code was spent, or null. */
  usedAt: number | null;
}

// --- codes -------------------------------------------------------------------

/** Ten fresh codes from a CSPRNG. [rand] is replaceable in tests. */
export function generateCodes(
  count: number = BACKUP_CODE_COUNT,
  rand: (max: number) => number = randomInt,
): string[] {
  const codes = new Set<string>();
  while (codes.size < count) {
    let raw = "";
    for (let i = 0; i < CODE_LENGTH; i++) {
      raw += CODE_ALPHABET[rand(CODE_ALPHABET.length)];
    }
    codes.add(`${raw.slice(0, 5)}-${raw.slice(5)}`);
  }
  return [...codes];
}

/** What the user typed, as compared: upper case, no spaces or dashes. */
export function normalizeCode(input: string): string {
  return input.toUpperCase().replace(/[\s-]/g, "");
}

function scryptAsync(code: string, salt: Buffer): Promise<Buffer> {
  return new Promise((resolve, reject) =>
    scrypt(code, salt, SCRYPT_KEYLEN, SCRYPT_OPTIONS, (err, key) =>
      err ? reject(err) : resolve(key),
    ),
  );
}

/** A salted scrypt hash of one code. */
export async function hashCode(code: string, salt: Buffer): Promise<string> {
  return (await scryptAsync(normalizeCode(code), salt)).toString("base64");
}

export async function buildStoredCodes(codes: string[]): Promise<StoredCode[]> {
  return Promise.all(
    codes.map(async (code) => {
      const salt = randomBytes(16);
      return { salt: salt.toString("base64"), hash: await hashCode(code, salt), usedAt: null };
    }),
  );
}

/**
 * Index of the stored code [input] matches, and whether it was used.
 * Every hash is computed and compared; nothing returns early.
 */
export async function matchCode(
  stored: StoredCode[],
  input: string,
): Promise<{ index: number; used: boolean } | null> {
  const normalized = normalizeCode(input);
  let found: { index: number; used: boolean } | null = null;
  for (let i = 0; i < stored.length; i++) {
    const salt = Buffer.from(stored[i].salt, "base64");
    const expected = Buffer.from(stored[i].hash, "base64");
    const actual = await scryptAsync(normalized, salt);
    const same =
      expected.length === actual.length && timingSafeEqual(expected, actual);
    if (same && found === null) {
      found = { index: i, used: stored[i].usedAt !== null };
    }
  }
  return found;
}
